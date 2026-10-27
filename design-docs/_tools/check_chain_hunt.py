#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_chain_hunt.py — 사슬 사냥(ChainHunt) 계약을 Unity 없이 재현한다 (2026-10-22).

왜 있는가
─────────
`ChainHuntTests` 8건은 `GameObject` 를 하나도 안 만들고 `monsters.json` ·
`EcologyEncounter` · `ChainHunt` 만 쓴다. 그런데도 미대체(todo)로 남아, "먹이층이 없는 층에
사냥 미션을 주지 않는다" 같은 계약이 **한 번도 돌지 않았다**. 그 계약이 뒤집히면 컴파일도
되고 화면도 뜬다 — 사슬 태그만 붙고 잡을 먹이가 없는 층이 조용히 생긴다.

무엇을 하는가 — 두 겹
────────────────────
① **판정 재현**: 테스트와 같은 데이터(`monsters.json`)로 130층 전수를 다시 돌려, 8건이
   단언하는 것을 그대로 요구한다(먹이층만 대상 · 그 층 편성 풀 소속 · 먹이 없으면 비활성 ·
   대상 종만 진도 · 목표에서 포화 · 결정론 · 3역할 밖 태그 금지 · 활성층에 먹이 마커).
② **기전 고정**: 그 재현이 C# 과 갈라지지 않도록 규칙 줄을 소스에서 확인한다 —
   역할→사슬 매핑(prey/swarm · predator/hunter/ambusher/apex · decomposer/scavenger/corruptor),
   `return anyFood ? chains : null`(먹이 없으면 비활성), `party[i % party.Count]`(순환 배정),
   `foods[Mathf.Abs(floor) % foods.Count]`(층 시드 결정론), `RecordKill` 의 세 가드.

   ★ 편성 풀은 `sim_eco_encounter` 를 **그대로 부른다** — 규칙 사본을 두지 않는다.
     그 미러 자체는 `[1.50]`(`EcologyEncounterTests` 대체)이 본다.
   ★ `TargetKills` 값은 **판정하지 않는다** — 문서에 수치가 없어 상수로 격리된 값이고,
     테스트도 `a.targetKills` 를 참조한다. 값이 바뀌면 미러가 소스에서 다시 읽는다.

못 덮는 것 (정직하게)
────────────────────
  · `ExploreLayout.Plan` 이 마커를 **배치**하는 위치·개수 — 여기서는 배정된 `ChainRole`
    배열까지만 본다(`ChainHuntTests` 도 그 이상을 단언하지 않는다).
  · `DataLoader` 캐시·`SetUp`(`ResetCache`) — JSON 을 직접 읽으므로 캐시 수명은 안 본다.
  · 테스트 4·5 는 층 20 을 쓰는데 이 데이터에서 20층은 먹이층이 없어 C# 에서도
    `Assert.Ignore` 다. 같은 이유로 여기서도 SKIP 으로 남기고, **진도·포화 규칙은
    먹이가 있는 층(1)에서 따로 한 번 더** 확인한다(테스트를 바꾸지 않고 기전만 본다).

실행: python3 design-docs/_tools/check_chain_hunt.py [--selftest]
종료: 0 = 통과 · 1 = 위반 · 3 = 소스/데이터 없음
"""
from __future__ import annotations

import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(ROOT, "unity", "Assets", "Scripts")
DATA = os.path.join(ROOT, "unity", "Assets", "Resources", "Data")
sys.path.insert(0, TOOLS)

import check_progression_data as P          # noqa: E402 — 주석 제거·Viol 규약
import sim_eco_encounter as ECO             # noqa: E402 — 편성 풀(규칙 사본 금지)

CHAIN_HUNT = os.path.join(SCRIPTS, "Core", "ChainHunt.cs")
TESTS = os.path.join(ROOT, "unity", "Assets", "Tests", "Editor", "ChainHuntTests.cs")
MONSTERS = os.path.join(DATA, "monsters.json")

PORTED = [
    "Target_Is_Always_A_Food_Layer_Species",
    "Target_Belongs_To_That_Floors_Ecology_Pool",
    "No_Hunt_When_The_Floor_Has_No_Food_Layer",
    "Progress_Only_Advances_On_The_Target_Species",
    "Progress_Saturates_At_Target",
    "Assignment_Is_Deterministic_For_The_Same_Floor",
    "Marker_Chains_Use_Only_The_Three_Documented_Roles",
    "More_Than_One_Food_Marker_Exists_On_Active_Floors",
]

FLOORS = 130
FOOD_ROLES = ("prey", "swarm")
ROLE_TO_CHAIN = {
    "prey": "Food", "swarm": "Food",
    "predator": "Predator", "hunter": "Predator", "ambusher": "Predator", "apex": "Predator",
    "decomposer": "Decomposer", "scavenger": "Decomposer", "corruptor": "Decomposer",
}
CHAINS = ("None", "Food", "Predator", "Decomposer")

ANCHORS = [
    ("A_FOOD_ROLE", r'case "prey":\s*case "swarm":\s*return ExploreLayout\.ChainRole\.Food;'),
    ("A_PRED_ROLE", r'case "predator":\s*case "hunter":\s*case "ambusher":\s*case "apex":\s*'
                    r'return ExploreLayout\.ChainRole\.Predator;'),
    ("A_DEC_ROLE", r'case "decomposer":\s*case "scavenger":\s*case "corruptor":\s*'
                   r'return ExploreLayout\.ChainRole\.Decomposer;'),
    ("A_PARTY", r"var party = EcologyEncounter\.BuildParty\(DataLoader\.LoadMonsters\(\)\.monsters, floor\);"),
    ("A_NOFOOD_NULL", r"return anyFood \? chains : null;"),
    ("A_CYCLE", r"party\[i % party\.Count\]\.ecology\?\.role"),
    ("A_PICK", r"foods\[UnityEngine\.Mathf\.Abs\(floor\) % foods\.Count\]"),
    ("A_RECORD_GUARD", r"if \(a == null \|\| !a\.active \|\| a\.cleared\) return;"),
    ("A_RECORD_MATCH", r"if \(monsterId != a\.targetSpeciesId\) return;"),
    ("A_RECORD_INC", r"a\.kills\+\+;"),
]


class Viol:
    def __init__(self):
        self.bad: list[str] = []

    def need(self, cond, tag: str, detail: str = ""):
        if not cond:
            self.bad.append(f"{tag} {detail}".strip())
        return bool(cond)

    def eq(self, want, got, tag: str, what: str = ""):
        return self.need(want == got, tag, f"{what} 기대 {want!r} 실제 {got!r}".strip())


def _read(path: str) -> str:
    with io.open(path, encoding="utf-8-sig") as fh:
        return fh.read()


def load_monsters() -> list:
    with io.open(MONSTERS, encoding="utf-8") as fh:
        return json.load(fh)["monsters"]


def target_kills(src: str):
    """`public const int TargetKills = 3;` — 값은 판정하지 않고 미러가 읽는다."""
    m = re.search(r"public const int TargetKills\s*=\s*(\d+);", src)
    return int(m.group(1)) if m else None


# ── C# 체인헌트 미러 (규칙은 소스에서 읽은 값만 쓴다) ────────────────
def role_of(m: dict):
    return (m.get("ecology") or {}).get("role")


def chain_of(m: dict) -> str:
    return ROLE_TO_CHAIN.get(role_of(m), "None")


def party_for(monsters, by_block, floor) -> list:
    """`EcologyEncounter.BuildParty(monsters, floor)` — 미러를 그대로 부른다."""
    plan = ECO.for_floor(monsters, by_block, floor)
    cands = plan["candidates"]
    if not cands:
        return []
    return ECO.select_by_floor_center(floor, by_block, cands,
                                      ECO.party_size(len(cands)), 0)


def marker_chains(monsters, by_block, floor: int, mark_count: int):
    if mark_count <= 0:
        return None
    party = party_for(monsters, by_block, floor)
    if not party:
        return None
    chains, any_food = [], False
    for i in range(mark_count):
        chain = chain_of(party[i % len(party)])
        chains.append(chain)
        if chain == "Food":
            any_food = True
    return chains if any_food else None


def assign(monsters, by_block, floor: int, mark_count: int, target_kills_n: int) -> dict:
    a = {
        "floor": floor, "active": False, "markerChains": None,
        "targetSpeciesId": None, "targetSpeciesName": None,
        "targetKills": target_kills_n, "kills": 0,
    }
    a["markerChains"] = marker_chains(monsters, by_block, floor, mark_count)
    if a["markerChains"] is None:
        return a
    party = party_for(monsters, by_block, floor)
    foods = [m for m in party if chain_of(m) == "Food"]
    if not foods:
        return a
    pick = foods[abs(floor) % len(foods)]
    a["targetSpeciesId"] = pick["id"]
    a["targetSpeciesName"] = pick.get("name")
    a["active"] = True
    return a


def record_kill(a: dict, monster_id: str):
    if a is None or not a["active"] or a["kills"] >= a["targetKills"]:
        return
    if monster_id != a["targetSpeciesId"]:
        return
    a["kills"] += 1


# ── 판정 ─────────────────────────────────────────────────────────────
def anchors(src: str) -> list:
    v, clean = Viol(), P.strip_cs_comments(src)
    for tag, pattern in ANCHORS:
        v.need(re.search(pattern, clean) is not None, tag,
               f"규칙이 소스에서 사라졌다 — ChainHunt.cs `{pattern}`")
    return v.bad


def test_inventory(tests_src: str) -> list:
    v = Viol()
    names = re.findall(r"\[Test\]\s*\n\s*public void (\w+)\(", tests_src)
    v.eq(len(PORTED), len(names), "INV", "테스트 수 — 이 오라클이 덮는 수와 다르다")
    v.need(not [n for n in PORTED if n not in names], "INV",
           f"사라진 테스트(포트가 유령을 본다): {[n for n in PORTED if n not in names]}")
    v.need(not [n for n in names if n not in PORTED], "INV",
           f"새 테스트(아직 안 덮는다): {[n for n in names if n not in PORTED]}")
    return v.bad


def run(monsters: list | None = None, src: str | None = None,
        tests_src: str | None = None) -> list:
    src = src if src is not None else _read(CHAIN_HUNT)
    bad = anchors(src)
    bad += test_inventory(tests_src if tests_src is not None else _read(TESTS))
    kills_n = target_kills(src)
    if kills_n is None:
        bad.append("A_CONST TargetKills 를 소스에서 못 읽었다")
    if bad:
        return bad

    monsters = monsters if monsters is not None else load_monsters()
    _, _, by_block = ECO.load()
    all_ids = {m["id"]: m for m in monsters}
    v = Viol()

    # T1 — 대상은 언제나 먹이층(prey·swarm) 종.
    active_floors = []
    for f in range(1, FLOORS + 1, 3):
        a = assign(monsters, by_block, f, 4, kills_n)
        if not a["active"]:
            continue
        active_floors.append(f)
        m = all_ids.get(a["targetSpeciesId"])
        v.need(m is not None, "T1", f"{f}층 대상 {a['targetSpeciesId']} 가 monsters.json 에 없다")
        if m is not None:
            v.need(role_of(m) in FOOD_ROLES, "T1",
                   f"{f}층 대상 {m.get('name')} role '{role_of(m)}' — 먹이층이 아니다")

    # T2 — 대상은 그 층 편성 풀 소속.
    for f in range(1, FLOORS + 1, 7):
        a = assign(monsters, by_block, f, 4, kills_n)
        if not a["active"]:
            continue
        pool = {m["id"] for m in party_for(monsters, by_block, f)}
        v.need(a["targetSpeciesId"] in pool, "T2",
               f"{f}층 대상이 그 층 편성 풀에 없다")

    # T3 — 먹이층이 없는 층에는 미션이 없다(마커 태그도 없다).
    for f in range(1, FLOORS + 1):
        a = assign(monsters, by_block, f, 3, kills_n)
        if a["active"]:
            continue
        v.need(a["markerChains"] is None, "T3",
               f"{f}층 은 사냥 미션이 없는데 마커 사슬 태그가 붙었다")

    # T4·T5 — 테스트는 층 20 을 쓴다. 먹이가 없으면 C# 처럼 SKIP.
    a20 = assign(monsters, by_block, 20, 4, kills_n)
    skipped = []
    if not a20["active"]:
        skipped += ["T4", "T5"]
    else:
        other = next(m["id"] for m in monsters if m["id"] != a20["targetSpeciesId"])
        record_kill(a20, other)
        v.eq(0, a20["kills"], "T4", "다른 종을 잡고 진도가 올랐다")
        record_kill(a20, a20["targetSpeciesId"])
        v.eq(1, a20["kills"], "T4", "대상 종 처치가 반영되지 않았다")
        for _ in range(a20["targetKills"] + 5):
            record_kill(a20, a20["targetSpeciesId"])
        v.eq(a20["targetKills"], a20["kills"], "T5", "목표를 넘겨도 진도가 오른다")
        v.need(a20["kills"] >= a20["targetKills"], "T5", "cleared 가 아니다")

    # M1 — 진도·포화 규칙은 **먹이가 있는 층**에서 한 번 더 본다.
    #   (테스트를 바꾸지 않는다. 층 20 이 비활성이라 C# 도 이 두 규칙을 안 굴린다.)
    mfloor = next((f for f in range(1, FLOORS + 1)
                   if assign(monsters, by_block, f, 4, kills_n)["active"]), None)
    v.need(mfloor is not None, "M1", "130층 어디에도 먹이층이 없다")
    if mfloor is not None:
        am = assign(monsters, by_block, mfloor, 4, kills_n)
        other = next(m["id"] for m in monsters if m["id"] != am["targetSpeciesId"])
        record_kill(am, other)
        v.eq(0, am["kills"], "M1", "대상 아닌 종 처치가 진도를 올렸다")
        record_kill(am, am["targetSpeciesId"])
        v.eq(1, am["kills"], "M1", "대상 처치가 진도에 안 들어갔다")
        for _ in range(am["targetKills"] + 5):
            record_kill(am, am["targetSpeciesId"])
        v.eq(am["targetKills"], am["kills"], "M1", "목표에서 포화하지 않는다")

    # T6 — 같은 층은 같은 대상·같은 배치.
    for f in range(1, FLOORS + 1, 11):
        x = assign(monsters, by_block, f, 4, kills_n)
        y = assign(monsters, by_block, f, 4, kills_n)
        v.eq(x["targetSpeciesId"], y["targetSpeciesId"], "T6", f"{f}층 사냥 대상이 비결정론")
        v.eq(x["markerChains"], y["markerChains"], "T6", f"{f}층 마커 사슬 배치가 비결정론")

    # T7 — 마커 태그는 문서의 3역할(+None) 밖으로 나가지 않는다.
    for f in range(1, FLOORS + 1, 5):
        chains = marker_chains(monsters, by_block, f, 4)
        if chains is None:
            continue
        for c in chains:
            v.need(c in CHAINS, "T7", f"{f}층 사슬 태그 {c} 가 3역할 밖")

    # T8 — 활성층에는 먹이 마커가 실제로 있고, 130층 어딘가에는 걸린다.
    active = 0
    for f in range(1, FLOORS + 1):
        a = assign(monsters, by_block, f, 4, kills_n)
        if not a["active"]:
            continue
        active += 1
        v.need((a["markerChains"] or []).count("Food") > 0, "T8",
               f"{f}층 사냥이 걸렸는데 먹이 마커가 없다")
    v.need(active > 0, "T8", "130층 어디에도 사슬 사냥이 안 걸린다")

    if skipped:
        v.need(True, "SKIP", f"{', '.join(skipped)} — 층 20 에 먹이층이 없다(테스트도 Ignore)")
    return v.bad


# ── 자가진단 ─────────────────────────────────────────────────────────
MUTATIONS = [
    ("앵커 — 먹이 없어도 사슬 태그 반환", ("src", "return anyFood ? chains : null;", "return chains;")),
    ("앵커 — 대상 종 검사 제거", ("src", "if (monsterId != a.targetSpeciesId) return;",
                                  "if (false) return;")),
    ("앵커 — 순환 배정을 고정 인덱스로", ("src", "party[i % party.Count].ecology?.role",
                                          "party[0].ecology?.role")),
    ("앵커 — 층 시드 대신 첫 먹이", ("src", "foods[UnityEngine.Mathf.Abs(floor) % foods.Count]",
                                      "foods[0]")),
    ("데이터 — 먹이층 역할 전부 제거", ("data", None)),
]


def selftest() -> int:
    base = run()
    if base:
        print("  ✗ 원본에서도 실패한다 — 변이 전에 고쳐라:")
        for b in base[:6]:
            print("      · " + b)
        return 1
    src = _read(CHAIN_HUNT)
    ok = True
    for label, mut in MUTATIONS:
        if mut[0] == "src":
            _, old, new = mut
            if old not in src:
                print(f"  ✗ NOT-FOUND — {label}")
                ok = False
                continue
            bad = run(src=src.replace(old, new, 1))
        else:
            monsters = load_monsters()
            for m in monsters:
                if role_of(m) in FOOD_ROLES:
                    m.setdefault("ecology", {})["role"] = "producer"
            bad = run(monsters=monsters)
        if bad:
            print(f"  ✓ 잡음 — {label}  →  {bad[0]}")
        else:
            print(f"  ✗ 놓침 — {label}  (변이가 통과했다)")
            ok = False
    print(f"[chain_hunt] 자가진단 {len(MUTATIONS)}종 — {'전부 포착' if ok else '구멍 있음'}")
    return 0 if ok else 1


def main() -> int:
    for path in (CHAIN_HUNT, TESTS, MONSTERS):
        if not os.path.exists(path):
            print(f"  ✗ 없음 — {os.path.relpath(path, ROOT)}")
            return 3
    bad = run()
    if not bad:
        print("OK — 사슬 사냥 8건 재현 (먹이층 대상 · 편성 풀 소속 · 비활성 계약 · 진도·포화 · "
              "결정론 · 3역할 · 먹이 마커)")
        return 0
    print(f"FAIL — 사슬 사냥 위반 {len(bad)}건:")
    for b in bad[:12]:
        print("  · " + b)
    return 1


if __name__ == "__main__":
    if "--selftest" in sys.argv[1:]:
        sys.exit(selftest())
    sys.exit(main())
