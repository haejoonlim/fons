#!/usr/bin/env python3
"""바이옴별 생물 3종 키 정본 → `data/monster_assets.json` (+ `godot/data/` 사본).

무엇을 만드나
-------------
S5 — 바이옴마다 **그 바이옴에 사는 전투종 3종**을 골라 에셋 키로 적는다.
메시는 만들지 않는다. 78칸(26 × 3)의 생산 목록이 이 단계의 산출물이다.

| 항목 | 출처 |
|---|---|
| `id` · `slot` | `biomes.json` `biomes[].id` · `slots[0]` |
| 후보 | `monsters.json` 중 `spawn.mode` 가 `encounter`·`elite` 인 종 |
| 1차 | `ecology.habitat ∩ biome.habitat` — 게임 조우 편성과 같은 규칙 (`FonsEncounter`) |
| 우선 | `ecology_codex.json` 의 `spawnBlock` 이 그 블록이면 +2, 이웃 블록이면 +1 |
| 우선 | `ecology.temperature` 가 바이옴 `climate.band` 와 겹치면 +2 (면역 역할은 통과) |
| 3종 | 몸집 대역 하나씩 — heavy · small · odd. 대역이 비면 다음 후보로 채운다 |

몸집 대역은 **역할 이름**에서 나온다. 손으로 78종을 고르지 않는다:

    heavy  apex · predator · hunter · guardian · elemental
    small  prey · swarm · scavenger · decomposer
    odd    ambusher · undead · corruptor · mimic

같은 바이옴의 세 종이 같은 대역에 몰리면 화면에서 같은 몸집 셋이 되어
"생물 3종"이 아니라 "한 종류 3마리"로 읽힌다. 그래서 대역을 먼저 채운다.

키 규칙
-------
`monster:<mon_id>` — `run_state.gd` 가 전투 유닛에 붙이는 `asset` 문자열 그대로다.
뷰는 이 키를 `register_asset` 으로 찾고, 없으면 지금의 폴백 도형을 쓴다.

실행
----
    ./.venv/bin/python tools/gen_monster_assets.py           # 생성 + 사본
    ./.venv/bin/python tools/gen_monster_assets.py --check   # 정본과 다르면 exit 1

`--check` 는 게이트 단계 `monsterassets` 로 돈다. 손으로 고치면 exit 1 —
정본은 `monsters.json`·`ecology_codex.json`·`biomes.json` 이다.
"""
import argparse
import json
import sys
from pathlib import Path

from gate_contract import run

HERE = Path(__file__).resolve().parent.parent
MONSTERS = HERE / "data" / "monsters.json"
CODEX = HERE / "data" / "ecology_codex.json"
BIOMES = HERE / "data" / "biomes.json"
OUT = HERE / "data" / "monster_assets.json"
MIRROR = HERE / "godot" / "data" / "monster_assets.json"

COMBAT_MODES = ("encounter", "elite")
IMMUNE_ROLES = {"elemental", "guardian", "undead"}
PICKS_PER_BIOME = 3

BANDS = {
    "heavy": {"apex", "predator", "hunter", "guardian", "elemental"},
    "small": {"prey", "swarm", "scavenger", "decomposer"},
    "odd": {"ambusher", "undead", "corruptor", "mimic"},
}

META = {
    "v80": "monster_assets v1 — S5 바이옴별 생물 3종 · 2026-10-26",
    "source": "data/monsters.json · data/ecology_codex.json · data/biomes.json — 값은 전부 파생이며 손으로 고치지 않는다.",
    "generatedBy": "tools/gen_monster_assets.py",
    "keyRule": "monster:<mon_id> — run_state.gd 의 entity.asset 문자열 그대로",
    "pickRule": "habitat 교집합(encounter·elite) → spawnBlock 우선 → 온도 적합 우선 → "
                "몸집 대역 heavy·small·odd 하나씩. 규칙은 tools/gen_monster_assets.py 머리말.",
    "bands": {name: sorted(roles) for name, roles in BANDS.items()},
}


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _biomes() -> list:
    rows = []
    for group in _load(BIOMES).get("groups", []):
        for biome in group.get("biomes", []):
            rows.append(biome)
    rows.sort(key=lambda b: int((b.get("slots") or [0])[0]))
    return rows


def _monsters() -> dict:
    return {str(m["id"]): m for m in _load(MONSTERS).get("monsters", [])}


def _blocks() -> dict:
    """mon_id → spawnBlock. 코드덱스에 없는 종은 블록 없음."""
    out = {}
    for entry in _load(CODEX).get("entries", []):
        block = entry.get("spawnBlock")
        if isinstance(block, int):
            out[str(entry["id"])] = block
    return out


def _temperature_fits(monster: dict, biome: dict) -> bool:
    """`FonsEncounter.temperature_fits` 와 같은 규칙 — 근거가 없으면 통과."""
    if str(monster.get("ecology", {}).get("role", "")) in IMMUNE_ROLES:
        return True
    band = biome.get("climate", {}).get("band", [])
    if len(band) < 2:
        return True
    temp = monster.get("ecology", {}).get("temperature", {})
    if not temp:
        return True
    return not (float(temp.get("max", 0)) < float(band[0])
                or float(temp.get("min", 0)) > float(band[1]))


def _band(monster: dict) -> str:
    role = str(monster.get("ecology", {}).get("role", ""))
    for name, roles in BANDS.items():
        if role in roles:
            return name
    return ""


def _candidates(biome: dict, monsters: dict, blocks: dict) -> list:
    habitat = set(biome.get("habitat") or [])
    slot = int((biome.get("slots") or [0])[0])
    out = []
    for mon in monsters.values():
        if str(mon.get("spawn", {}).get("mode", "")) not in COMBAT_MODES:
            continue
        if not habitat & set(mon.get("ecology", {}).get("habitat") or []):
            continue
        block = blocks.get(str(mon["id"]))
        priority = 0
        if block == slot:
            priority += 2
        elif block is not None and abs(block - slot) == 1:
            priority += 1
        if _temperature_fits(mon, biome):
            priority += 2
        out.append({
            "mon": mon,
            "source": "block" if block == slot else "neighbour" if block is not None
            and abs(block - slot) == 1 else "habitat",
            "priority": priority,
        })
    out.sort(key=lambda row: (-row["priority"],
                              -int(bool(row["mon"]["spawn"].get("elite", False))),
                              -int(row["mon"].get("tier", 1)),
                              -float(row["mon"].get("threatBase", 0)),
                              str(row["mon"]["id"])))
    return out


def pick(biome: dict, monsters: dict, blocks: dict) -> list:
    pool = _candidates(biome, monsters, blocks)
    if len(pool) < PICKS_PER_BIOME:
        raise SystemExit("FAIL — %s: 후보가 %d종뿐이다 (3종 필요)"
                         % (biome.get("id", "?"), len(pool)))
    chosen, seen = [], set()
    for band in BANDS:
        for row in pool:
            if row["mon"]["id"] in seen:
                continue
            if _band(row["mon"]) == band:
                chosen.append(row)
                seen.add(row["mon"]["id"])
                break
    for row in pool:
        if len(chosen) >= PICKS_PER_BIOME:
            break
        if row["mon"]["id"] in seen:
            continue
        chosen.append(row)
        seen.add(row["mon"]["id"])
    picked = []
    for row in chosen[:PICKS_PER_BIOME]:
        mon = row["mon"]
        picked.append({
            "key": "monster:%s" % mon["id"],
            "id": str(mon["id"]),
            "name": str(mon.get("name", "")),
            "role": str(mon.get("ecology", {}).get("role", "")),
            "band": _band(mon),
            "mode": str(mon.get("spawn", {}).get("mode", "")),
            "tier": int(mon.get("tier", 1)),
            "source": row["source"],
        })
    if len(picked) != PICKS_PER_BIOME:
        raise SystemExit("FAIL — %s: %d종만 골랐다" % (biome.get("id", "?"), len(picked)))
    return picked


def build() -> dict:
    monsters, blocks = _monsters(), _blocks()
    rows = []
    for biome in _biomes():
        slot = int((biome.get("slots") or [0])[0])
        if slot < 1:
            raise SystemExit("FAIL — %s: slots[0] 없음" % biome.get("id", "?"))
        rows.append({"id": str(biome["id"]), "slot": slot,
                     "monsters": pick(biome, monsters, blocks)})
    if len(rows) != 26:
        raise SystemExit("FAIL — 바이옴이 26이 아니다: %d" % len(rows))
    keys = [m["key"] for row in rows for m in row["monsters"]]
    if len(keys) != 78:
        raise SystemExit("FAIL — 생물 키가 78이 아니다: %d" % len(keys))
    for row in rows:
        ids = [m["id"] for m in row["monsters"]]
        if len(set(ids)) != PICKS_PER_BIOME:
            raise SystemExit("FAIL — %s: 같은 종이 두 번 들어갔다" % row["id"])
    return {"meta": META, "biomes": rows}


def encoded(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="파일이 생성물과 같은지만 본다")
    args = ap.parse_args()

    doc = build()
    text = encoded(doc)
    unique = len({m["id"] for row in doc["biomes"] for m in row["monsters"]})
    print("monster_assets — 바이옴 %d · 키 %d · 고유 종 %d"
          % (len(doc["biomes"]), sum(len(r["monsters"]) for r in doc["biomes"]), unique))

    if args.check:
        for path in (OUT, MIRROR):
            if not path.exists():
                print("[ FAIL ] 없음 — %s" % path.relative_to(HERE))
                return 1
            if path.read_text(encoding="utf-8") != text:
                print("[ FAIL ] 다름 — %s (정본: monsters.json, 생성기로 다시 뽑는다)"
                      % path.relative_to(HERE))
                return 1
        print("정본 = 생성물 · 사본 = 정본")
        return 0

    OUT.write_text(text, encoding="utf-8")
    MIRROR.parent.mkdir(parents=True, exist_ok=True)
    MIRROR.write_text(text, encoding="utf-8")
    print("씀 — %s · %s" % (OUT.relative_to(HERE), MIRROR.relative_to(HERE)))
    return 0


if __name__ == "__main__":
    sys.exit(run("monsterassets", main))
