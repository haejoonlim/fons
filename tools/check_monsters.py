#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_monsters.py — 전투 몬스터 138종의 구조·참조 무결성 검사 (exit 0 = 통과).

왜 있나:
  `data/monsters.json` 은 게임이 전투를 만들 때 쓰는 유일한 정본인데, 지금까지 이 파일의
  **모양**을 보는 게이트가 없었다. `check_gdd_names.py` 는 이름만, `check_data_text.py` 는
  글자만 본다. 그래서 이런 것이 전부 조용히 통과한다.
    - `aiDecision` 이 빠진 개체 → AI 가 기본값으로 돌고, 화면에는 정상 몬스터가 뜬다
    - `pattern[].telegraph` 가 빈 개체 → 예고 없는 공격. 유저는 "왜 맞았는지" 모른다
    - `ecology.habitat` 오타 → 바이옴 편성(habitat 교집합)에서 그 종이 사라진다
    - `prey`/`predators` 의 `mon_*` 참조가 없는 id → 먹이사슬 간선이 끊긴다
  셋 다 게임이 **빈 채로 도는** 실패라 화면에 오류가 안 뜬다.

무엇을 보는가:
  M-1  파일 구조 — monsters 배열 · id 고유 · name 비어 있지 않음 · missions 블록
  M-2  필수 블록 18종이 138종 전부에 있다
  M-3  패턴 계약 — name/effect/telegraph/counter 가 비지 않고 cd 는 0 이상 정수
       (telehgraph + counter 는 "예고하고, 답이 있다"는 전투 계약이다. cd 0 은 상시 오라)
  M-4  aiDecision — specialSkill 비지 않음 · enrageHp 0~1(0 = 격노 없음) ·
       patternCooldown 은 [lo, hi] 정수 · crowdAoeRadius 0 이상
  M-5  전리품 — soul 은 하/중/상/최상 · gold·exp 는 0 이상 정수
  M-6  출현 — floors 는 비지 않은 1~130 오름차순 정수 · mode 는 넷 중 하나 ·
       elite 는 bool 이거나 없음 (null 허용) · bossScaleRefFloor 는 정수
  M-7  생태 — 14키 전부 · habitat 은 비지 않고 biomes.json 의 habitat 태그 안에 있다 ·
       activity 넷 중 하나 · 0~1 수치 6종 · temperature.min ≤ max
  M-8  먹이사슬 — prey/predators 의 `mon_*` 참조가 monsters ∪ ecology_codex 에 있다 ·
       relationTypes 의 키가 prey ∪ predators 안에 있다 (관계만 적고 목록을 안 고친 경우)
  M-9  도감 미러 — 138종 id 가 ecology_codex 에 다 있고 habitat 집합·diet·role 이 같다
       (도감 meta.source 가 "monsters.json ecology + biomes.json climate" 이므로 계약이다)
  M-10 층 미션 (D-265) — types 의 id 가 고유하고 name/clear/reward 가 비지 않으며
       param·encounter 수치가 양수 정수 · 주1+부6 = 층당 7개 · 부 목표 풀 6개 · gateFloors 정렬

정본 관계:
  data/monsters.json  >  data/ecology_codex.json (habitat·diet·role 은 몬스터를 따른다)
  data/biomes.json    >  monsters[].ecology.habitat (서식 태그 집합)

값은 고치지 않는다. 고치는 곳은 생성기·정본 문서다 (docs/gdd 는 원본 문면이라 손대지 않는다).

사용법:
  ./.venv/bin/python tools/check_monsters.py
"""
import json
import os
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, "data")

sys.path.insert(0, HERE)
from gate_contract import run  # noqa: E402

MONSTERS = os.path.join(DATA, "monsters.json")
BIOMES = os.path.join(DATA, "biomes.json")
CODEX = os.path.join(DATA, "ecology_codex.json")

# 필수 블록 — 하나라도 없으면 그 개체는 전투에 쓸 수 없다.
REQUIRED = ("id", "name", "category", "aiType", "tier", "level", "threatBase", "element",
            "stats", "weakness", "resistance", "statusImmune", "aiDecision", "pattern",
            "parts", "spawn", "loot", "ecology")
ECOLOGY_REQUIRED = ("activity", "aggression", "diet", "food_need", "habitat", "predators",
                    "prey", "relationTypes", "reproduction", "role", "sociality",
                    "temperature", "territoriality", "water_need")
ECOLOGY_NUM = ("aggression", "food_need", "sociality", "reproduction", "territoriality",
               "water_need")
PATTERN_TEXT = ("name", "effect", "telegraph", "counter")
SOUL_GRADES = {"하", "중", "상", "최상"}
SPAWN_MODES = {"encounter", "boss", "elite", "world"}
ACTIVITIES = {"always", "nocturnal", "diurnal", "crepuscular"}
FLOOR_MIN, FLOOR_MAX = 1, 130   # 확정 #52 — 탑은 130층이다
MISSIONS_PER_FLOOR = 7          # D-265 2차 확정 — 주 1 + 부 6


def load(path, label):
    """필수 정본 읽기 — 없거나 깨졌으면 traceback 이 아니라 (None, 실패 문구)."""
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh), None
    except OSError as e:
        return None, "%s 읽기 실패: %s" % (label, e)
    except json.JSONDecodeError as e:
        return None, "%s JSON 깨짐: %s" % (label, e)


def is_num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def habitat_tags(biomes):
    """biomes.json 의 모든 biome.habitat 태그 — 몬스터 서식 태그가 여기 안에 있어야 한다."""
    tags = set()
    for group in biomes.get("groups") or []:
        for biome in group.get("biomes") or []:
            tags |= {t for t in biome.get("habitat") or [] if isinstance(t, str)}
    return tags


def main():
    monsters_doc, err = load(MONSTERS, "data/monsters.json")
    if err:
        print("FAIL — " + err)
        return 1
    biomes, err = load(BIOMES, "data/biomes.json")
    if err:
        print("FAIL — " + err)
        return 1
    codex_doc, err = load(CODEX, "data/ecology_codex.json")
    if err:
        print("FAIL — " + err)
        return 1

    monsters = monsters_doc.get("monsters")
    if not isinstance(monsters, list) or not all(isinstance(m, dict) for m in monsters):
        print("FAIL — monsters 가 객체 배열이 아니다")
        return 1
    if not monsters:
        print("FAIL — monsters 가 비었다")
        return 1

    fails = []

    # M-1 — 파일 구조 (id 가 없거나 중복이면 뒤 검사가 전부 어긋나므로 먼저 끝낸다)
    no_id = [m for m in monsters if not isinstance(m.get("id"), str) or not m["id"]]
    if no_id:
        print("FAIL — id 없는 개체 %d건" % len(no_id))
        return 1
    dup = sorted(k for k, n in Counter(m["id"] for m in monsters).items() if n > 1)
    if dup:
        print("FAIL — id 중복 %d건: %s" % (len(dup), ", ".join(dup[:10])))
        return 1
    for m in monsters:
        if not isinstance(m.get("name"), str) or not m["name"].strip():
            fails.append("M-1 %s — name 이 비었다" % m["id"])
    missions = monsters_doc.get("missions")
    if not isinstance(missions, dict) or not missions.get("types"):
        fails.append("M-1 missions 블록이 없다 (D-265 층 미션)")
        missions = None

    tags = habitat_tags(biomes)
    if not tags:
        print("FAIL — biomes.json 에 habitat 태그가 없음 (검사 기준이 사라진다)")
        return 1

    codex_entries = codex_doc.get("entries")
    if not isinstance(codex_entries, list):
        print("FAIL — ecology_codex.entries 가 배열이 아니다")
        return 1
    codex = {e["id"]: e for e in codex_entries if isinstance(e, dict) and isinstance(e.get("id"), str)}
    known = set(m["id"] for m in monsters) | set(codex)

    for m in monsters:
        mid = m["id"]

        # M-2 — 필수 블록
        missing = [k for k in REQUIRED if k not in m]
        if missing:
            fails.append("M-2 %s — 필수 키 없음: %s" % (mid, ", ".join(missing)))
            continue          # 나머지 검사는 그 키를 전제한다

        # M-3 — 패턴 계약
        patterns = m["pattern"]
        if not isinstance(patterns, list) or not patterns:
            fails.append("M-3 %s — pattern 이 비었다 (예고 없는 개체)" % mid)
        else:
            for i, p in enumerate(patterns, 1):
                if not isinstance(p, dict):
                    fails.append("M-3 %s — pattern[%d] 가 객체가 아니다" % (mid, i))
                    continue
                for key in PATTERN_TEXT:
                    if not isinstance(p.get(key), str) or not p[key].strip():
                        fails.append("M-3 %s — pattern[%d].%s 가 비었다" % (mid, i, key))
                cd = p.get("cd")
                if not is_int(cd) or cd < 0:
                    fails.append("M-3 %s — pattern[%d] cd %r (0 이상 정수)" % (mid, i, cd))

        # M-4 — AI 결정
        ai = m["aiDecision"]
        if not isinstance(ai, dict):
            fails.append("M-4 %s — aiDecision 이 객체가 아니다" % mid)
        else:
            skill = ai.get("specialSkill")
            if not isinstance(skill, str) or not skill.strip():
                fails.append("M-4 %s — specialSkill 이 비었다" % mid)
            enrage = ai.get("enrageHp")
            if not is_num(enrage) or not 0 <= enrage <= 1:
                fails.append("M-4 %s — enrageHp %r (0~1, 0 = 격노 없음)" % (mid, enrage))
            pc = ai.get("patternCooldown")
            if not (isinstance(pc, list) and len(pc) == 2 and all(is_int(v) for v in pc)
                    and pc[0] <= pc[1]):
                fails.append("M-4 %s — patternCooldown %r ([lo, hi] 정수)" % (mid, pc))
            radius = ai.get("crowdAoeRadius")
            if not is_num(radius) or radius < 0:
                fails.append("M-4 %s — crowdAoeRadius %r (0 이상)" % (mid, radius))

        # M-5 — 전리품
        loot = m["loot"]
        if not isinstance(loot, dict):
            fails.append("M-5 %s — loot 이 객체가 아니다" % mid)
        else:
            soul = loot.get("soul")
            if not isinstance(soul, list) or not all(isinstance(s, str) for s in soul):
                fails.append("M-5 %s — soul 이 문자열 배열이 아니다" % mid)
            else:
                odd = sorted(set(soul) - SOUL_GRADES)
                if odd:
                    fails.append("M-5 %s — soul 등급 %s (하/중/상/최상)" % (mid, ", ".join(odd)))
            for key in ("gold", "exp"):
                v = loot.get(key)
                if not is_num(v) or v < 0:
                    fails.append("M-5 %s — loot.%s %r (0 이상)" % (mid, key, v))

        # M-6 — 출현
        spawn = m["spawn"]
        if not isinstance(spawn, dict):
            fails.append("M-6 %s — spawn 이 객체가 아니다" % mid)
        else:
            floors = spawn.get("floors")
            if not isinstance(floors, list) or not floors:
                fails.append("M-6 %s — spawn.floors 가 비었다 (어느 층에도 안 나온다)" % mid)
            else:
                bad = [f for f in floors if not is_int(f) or not FLOOR_MIN <= f <= FLOOR_MAX]
                if bad:
                    fails.append("M-6 %s — spawn.floors %r (%d~%d 정수)"
                                 % (mid, bad, FLOOR_MIN, FLOOR_MAX))
                elif floors != sorted(floors):
                    fails.append("M-6 %s — spawn.floors 가 오름차순이 아니다: %r" % (mid, floors))
            mode = spawn.get("mode")
            if mode not in SPAWN_MODES:
                fails.append("M-6 %s — spawn.mode %r (%s)"
                             % (mid, mode, "/".join(sorted(SPAWN_MODES))))
            if "elite" in spawn and not isinstance(spawn["elite"], bool):
                fails.append("M-6 %s — spawn.elite %r (bool 또는 생략)" % (mid, spawn["elite"]))
            if "bossScaleRefFloor" in spawn and not is_int(spawn["bossScaleRefFloor"]):
                fails.append("M-6 %s — bossScaleRefFloor %r (정수)"
                             % (mid, spawn["bossScaleRefFloor"]))

        # M-7 — 생태
        eco = m["ecology"]
        if not isinstance(eco, dict):
            fails.append("M-7 %s — ecology 가 객체가 아니다" % mid)
            continue
        eco_missing = [k for k in ECOLOGY_REQUIRED if k not in eco]
        if eco_missing:
            fails.append("M-7 %s — ecology 키 없음: %s" % (mid, ", ".join(eco_missing)))
        else:
            hab = eco["habitat"]
            if not isinstance(hab, list) or not hab:
                fails.append("M-7 %s — ecology.habitat 이 비었다 (편성 후보 0)" % mid)
            else:
                unknown = sorted({h for h in hab if h not in tags})
                if unknown:
                    fails.append("M-7 %s — habitat 태그가 biomes 에 없다: %s"
                                 % (mid, ", ".join(unknown)))
            if eco["activity"] not in ACTIVITIES:
                fails.append("M-7 %s — activity %r (%s)"
                             % (mid, eco["activity"], "/".join(sorted(ACTIVITIES))))
            for key in ECOLOGY_NUM:
                v = eco[key]
                if not is_num(v) or not 0 <= v <= 1:
                    fails.append("M-7 %s — ecology.%s %r (0~1)" % (mid, key, v))
            temp = eco["temperature"]
            if not (isinstance(temp, dict) and is_num(temp.get("min")) and is_num(temp.get("max"))
                    and temp["min"] <= temp["max"]):
                fails.append("M-7 %s — temperature %r ({min, max} · min ≤ max)" % (mid, temp))

            # M-8 — 먹이사슬 참조
            prey = eco["prey"]
            preds = eco["predators"]
            if not (isinstance(prey, list) and isinstance(preds, list)
                    and all(isinstance(p, str) for p in prey)
                    and all(isinstance(p, str) for p in preds)):
                fails.append("M-8 %s — prey/predators 가 문자열 배열이 아니다" % mid)
            else:
                for field, refs in (("prey", prey), ("predators", preds)):
                    dangling = sorted({r for r in refs if r.startswith("mon_") and r not in known})
                    if dangling:
                        fails.append("M-8 %s — %s 가 없는 id 를 가리킨다: %s"
                                     % (mid, field, ", ".join(dangling)))
                rel = eco["relationTypes"]
                if not isinstance(rel, dict):
                    fails.append("M-8 %s — relationTypes 가 객체가 아니다" % mid)
                else:
                    outside = sorted(set(rel) - set(prey) - set(preds))
                    if outside:
                        fails.append("M-8 %s — relationTypes 키가 prey/predators 에 없다: %s"
                                     % (mid, ", ".join(outside)))

        # M-9 — 도감 미러 (도감은 몬스터 생태에서 파생된다)
        entry = codex.get(mid)
        if entry is None:
            fails.append("M-9 %s — ecology_codex 에 없다" % mid)
        else:
            if isinstance(eco.get("habitat"), list) and set(entry.get("habitat") or []) != set(eco["habitat"]):
                fails.append("M-9 %s — 도감 habitat %r ≠ 몬스터 %r"
                             % (mid, entry.get("habitat"), eco["habitat"]))
            for key in ("diet", "role"):
                if entry.get(key) != eco.get(key):
                    fails.append("M-9 %s — 도감 %s %r ≠ 몬스터 %r"
                                 % (mid, key, entry.get(key), eco.get(key)))

    # M-10 — 층 미션 (D-265). 타입 정의가 깨지면 그 층의 주 미션이 배정되지 않는다.
    if missions:
        types = missions.get("types")
        if not isinstance(types, list) or not types:
            fails.append("M-10 missions.types 가 비었다")
        else:
            ids = [t.get("id") for t in types if isinstance(t, dict)]
            dup_ids = sorted(k for k, n in Counter(ids).items() if n > 1)
            if dup_ids:
                fails.append("M-10 missions.types id 중복: %s" % ", ".join(dup_ids))
            for t in types:
                if not isinstance(t, dict):
                    fails.append("M-10 missions.types 원소가 객체가 아니다")
                    continue
                tid = t.get("id") or "?"
                for key in ("name", "clear", "reward"):
                    if not isinstance(t.get(key), str) or not t[key].strip():
                        fails.append("M-10 missions.types[%s].%s 가 비었다" % (tid, key))
                param = t.get("param")
                if not isinstance(param, dict) or not param:
                    fails.append("M-10 missions.types[%s] param 이 비었다" % tid)
                else:
                    for k, v in param.items():
                        if not is_int(v) or v <= 0:
                            fails.append("M-10 missions.types[%s].param.%s %r (양수 정수)"
                                         % (tid, k, v))
                enc = t.get("encounter")
                if not isinstance(enc, dict) or not enc:
                    fails.append("M-10 missions.types[%s] encounter 가 비었다" % tid)
                else:
                    for k, v in enc.items():
                        if k not in SPAWN_MODES:
                            fails.append("M-10 missions.types[%s].encounter 키 %r (%s)"
                                         % (tid, k, "/".join(sorted(SPAWN_MODES))))
                        if not is_int(v) or v <= 0:
                            fails.append("M-10 missions.types[%s].encounter.%s %r (양수 정수)"
                                         % (tid, k, v))

        structure = missions.get("perFloorStructure")
        if not isinstance(structure, dict):
            fails.append("M-10 missions.perFloorStructure 가 없다")
        else:
            main = structure.get("main") if isinstance(structure.get("main"), dict) else {}
            sub = structure.get("sub") if isinstance(structure.get("sub"), dict) else {}
            total = (main.get("count") or 0) + (sub.get("count") or 0)
            if total != MISSIONS_PER_FLOOR:
                fails.append("M-10 주 %r + 부 %r = %r (D-265 층당 %d개)"
                             % (main.get("count"), sub.get("count"), total, MISSIONS_PER_FLOOR))
            pool = sub.get("pool")
            if not isinstance(pool, dict) or len(pool) != sub.get("count"):
                fails.append("M-10 부 목표 풀 %r ≠ count %r"
                             % (len(pool) if isinstance(pool, dict) else pool, sub.get("count")))

        assignment = missions.get("assignment")
        gates = assignment.get("gateFloors") if isinstance(assignment, dict) else None
        if not isinstance(gates, list) or not gates:
            fails.append("M-10 missions.assignment.gateFloors 가 비었다")
        else:
            bad_gates = [f for f in gates if not is_int(f) or not FLOOR_MIN <= f <= FLOOR_MAX]
            if bad_gates:
                fails.append("M-10 gateFloors %r (%d~%d 정수)"
                             % (bad_gates, FLOOR_MIN, FLOOR_MAX))
            elif gates != sorted(gates):
                fails.append("M-10 gateFloors 가 오름차순이 아니다: %r" % (gates,))

    modes = Counter(m.get("spawn", {}).get("mode") for m in monsters)
    print("check_monsters — M-1~M-10")
    print("  몬스터 %d · 도감 %d · 서식 태그 %d · 출현 %s"
          % (len(monsters), len(codex), len(tags),
             " ".join("%s %d" % (k, n) for k, n in sorted(modes.items(), key=lambda x: -x[1]))))
    for f in fails:
        print("  [FAIL] " + f)
    print("  → %s" % ("통과" if not fails else "실패 %d건" % len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(run("monsters", main))
