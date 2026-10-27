#!/usr/bin/env python3
"""바이옴 에셋 키 정본 → `data/biome_assets.json` (+ `godot/data/` 사본).

무엇을 만드나
-------------
`data/biomes.json` 의 26바이옴에서 **키만** 뽑는다. 메시는 만들지 않는다.

| 항목 | 출처 |
|---|---|
| `id` · `slot` | `biomes.json` `biomes[].id` · `slots[0]` |
| `kit` | `biomes.json` `biomes[].topologyKit` |
| `ground` | `ground:<kit>` — 같은 키트는 같은 바닥 묶음을 쓴다 |
| `lighting` | `lit:<id>` — 바이옴당 프리셋 1 (계획 L2 = 26개) |
| `ambient` | `ambient:<id>` — 바이옴당 환경 이펙트 1 |
| `props` | `prop:<kit>:<part>` + 개수 — 아래 규칙으로 파생 (S4) |

프롭 배분 규칙 (S4)
-------------------
같은 키트를 쓰는 바이옴(예: 서고·미궁도시·폐허·침전수로)이 화면에서 갈라지려면
**어떤 프롭이 얼마나 서는가**가 달라야 한다. 손으로 26개를 적지 않고 이미 정본에
있는 세 축에서 파생한다 — 계획 §4 와 같은 원칙이다.

  1. **성향** — `habitat` 낱말이 프롭 역할(식생·암석·인공)에 무게를 준다.
     `difficulty.mods` 도 같은 축을 민다 (`waterTile`→식생, `lavaTile`→암석, `maze`→인공).
     기후도 한 축이다: 25℃ 이상은 마른 땅이라 암석 +1, −20℃ 이하는 눈·얼음이라 암석 +0.5.
  2. **총량** — `category` 가 정한다 (평온 20 · 물가 24 · 혼돈 28 · 어둠 18 · 극한 22).
     `allPrev` +6 · `maze` +2 · `cover` +2 · `light:dark` −2. 12~36 으로 자른다.
  3. **한 성향 안의 순서** — 같은 역할 부품이 여럿이면 `biome_id` 해시로 순서를 돌려
     우세 부품을 바꾼다. 서고는 책장, 침전수로는 통이 많이 서는 식이다.

부품 이름은 `tools/gen_kit_glb.py` 의 `KITS` 에서 읽는다 — 생성기 두 개가 같은
이름을 각자 적으면 한쪽만 고쳤을 때 조용히 어긋난다.

실행
----
    ./.venv/bin/python tools/gen_biome_assets.py           # 생성 + 사본
    ./.venv/bin/python tools/gen_biome_assets.py --check   # 정본과 다르면 exit 1

`--check` 는 게이트 단계 `biomeassets` 로 돈다. 손으로 고치면 exit 1 — 정본은 `biomes.json` 이다.
"""
import argparse
import json
import sys
import zlib
from pathlib import Path

from gate_contract import run
from gen_kit_glb import KITS

HERE = Path(__file__).resolve().parent.parent
BIOMES = HERE / "data" / "biomes.json"
OUT = HERE / "data" / "biome_assets.json"
MIRROR = HERE / "godot" / "data" / "biome_assets.json"

META = {
    "v80": "biome_assets v2 — data/biomes.json v1.3 파생 · 2026-10-26",
    "source": "data/biomes.json — kit = topologyKit, slot = slots[0]. 값은 전부 파생이며 손으로 고치지 않는다.",
    "generatedBy": "tools/gen_biome_assets.py",
    "keyRule": "ground:<kit> · lit:<biome_id> · ambient:<biome_id> · prop:<kit>:<part>",
    "propsRule": "props = [{key, part, n}] — habitat·difficulty.mods·climate·category 에서 파생. "
                 "같은 키트를 쓰는 바이옴이 갈라지도록 부품 배분과 총량을 바이옴마다 다르게 뽑는다 "
                 "(규칙은 tools/gen_biome_assets.py 머리말).",
    "lightingRule": "lit:<biome_id> 는 키다. 수치(태양·채움광·안개)는 godot/core/biome_palette.gd 가 "
                    "같은 정본에서 파생한다 — 여기에 손 수치를 두지 않는다.",
}

# --- 프롭 배분 규칙 (계획 §4 와 같은 '정본에서 파생' 원칙) -----------------

## 부품 이름 → 역할. 이름은 gen_kit_glb.py 의 KITS 와 대조해 검증한다.
PROP_ROLE = {
    "plant": {
        "bush", "flower", "cattail", "lily", "kelp", "anemone", "mushroom",
        "snow_bush", "dead_shrub",
    },
    "rock": {
        "rock", "pebble", "slab", "crystal", "ember_rock", "frozen_rock",
        "icicle", "spire_small",
    },
    "made": {
        "stump", "driftwood", "shell", "crate", "barrel", "post", "shelf",
        "candle", "urn", "grave", "offering", "banner", "tube", "bone",
        "charred_stump", "ice_floe", "feather",
    },
}

## habitat 낱말 → 역할. 모르는 낱말은 무시한다 (지어내지 않는다).
HABITAT_ROLE = {
    "grassland": "plant", "plains": "plant", "meadow": "plant", "forest": "plant",
    "jungle": "plant", "swamp": "plant", "river": "plant", "coral": "plant",
    "fungus": "plant", "ocean": "plant", "deep_ocean": "plant", "deep": "plant",
    "trench": "plant",
    "mountain": "rock", "cave": "rock", "mine": "rock", "underground": "rock",
    "tundra": "rock", "ice_cave": "rock", "desert": "rock", "glassdesert": "rock",
    "abyss": "rock", "windless": "rock", "volcano": "rock", "lava": "rock",
    "hellscape": "rock", "frostsea": "rock", "skylapse": "rock",
    "crystalgrove": "rock", "storm": "rock", "ideagate": "rock",
    "library": "made", "city": "made", "castle": "made", "tower": "made",
    "dungeon": "made", "sewer": "made", "ruins": "made", "temple": "made",
    "shrine": "made", "graveyard": "made", "fortress": "made", "lair": "made",
    "dragon_lair": "made", "sky": "made",
}

## habitat 낱말 → 그 바이옴에서 더 자주 서는 부품. 같은 역할·같은 총량인 짝(폐허↔침전수로,
## 원천연안↔이끼늪, 얼음 바다↔찢긴 천창, 수정 군락↔유리 사막)을 부품 이름으로 가른다.
## 규칙이 없으면 역할 무게만 남아 그 짝들이 같은 배분이 된다 (2026-10-26 실측).
HABITAT_PART = {
    "grassland": "flower", "plains": "flower", "meadow": "flower",
    "forest": "bush", "jungle": "bush",
    "swamp": "cattail", "river": "cattail",
    "ocean": "shell", "coral": "shell", "deep_ocean": "tube", "deep": "tube",
    "trench": "anemone",
    "mountain": "slab", "cave": "pebble", "mine": "pebble", "underground": "mushroom",
    "tundra": "snow_bush", "ice_cave": "icicle",
    "desert": "dead_shrub", "glassdesert": "slab", "volcano": "ember_rock",
    "lava": "ember_rock", "hellscape": "bone", "abyss": "crystal",
    "windless": "icicle", "frostsea": "ice_floe", "skylapse": "feather",
    "crystalgrove": "crystal", "storm": "spire_small", "ideagate": "crystal",
    "library": "shelf", "sewer": "barrel", "ruins": "crate",
    "city": "post", "castle": "post", "tower": "post", "dungeon": "post",
    "temple": "offering", "shrine": "offering", "graveyard": "grave",
    "fortress": "banner", "lair": "bone", "dragon_lair": "bone", "sky": "banner",
}
HABITAT_PART_GAIN = 1.6

## difficulty.mods 키 → 역할. 없는 모드는 무시한다.
MOD_ROLE = {
    "waterTile": "plant",
    "poison": "plant",
    "cover": "plant",
    "ambush": "plant",
    "lavaTile": "rock",
    "highGround": "rock",
    "hideRate": "rock",
    "sanityDrain": "rock",
    "maze": "made",
    "mdefAura": "made",
    "holyAura": "made",
}

## category → 프롭 총량. 필드 40×28 에서 20~28 이 무리로 읽힌다 (2026-10-26 렌더).
PROP_TOTAL = {
    "calm": 20,
    "waterside": 24,
    "chaos": 28,
    "dark": 18,
    "extreme": 22,
}
DEFAULT_PROP_TOTAL = 22
## 같은 역할 안에서 우세 부품을 돌리는 배율. 첫 부품이 가장 많고 넷째가 가장 적다.
ROLE_RANK_MULT = (2.0, 1.4, 1.0, 0.8)
PROP_MIN, PROP_MAX = 12, 36


def prop_parts(kit: str) -> list:
    """키트의 프롭 부품 접미사 목록 — 생성기 정본에서 읽는다."""
    return [name[len("prop_"):] for name, _ in KITS[kit] if name.startswith("prop_")]


def _role(part: str) -> str:
    for role, names in PROP_ROLE.items():
        if part in names:
            return role
    raise SystemExit("FAIL — 프롭 역할이 등록되지 않았다: %s" % part)


def _weights(biome: dict) -> dict:
    """habitat·mods·기후 → 역할별 무게. 기본 1.0 이라 네 부품이 모두 한 번은 선다."""
    weights = {"plant": 1.0, "rock": 1.0, "made": 1.0}
    for word in biome.get("habitat") or []:
        role = HABITAT_ROLE.get(str(word))
        if role:
            weights[role] += 1.0
    for mod in (biome.get("difficulty") or {}).get("mods") or {}:
        role = MOD_ROLE.get(str(mod))
        if role:
            weights[role] += 1.0
        elif str(mod) == "allPrev":
            for role in weights:
                weights[role] += 1.0
    ambient = float(((biome.get("climate") or {}).get("ambient", 15.0)))
    if ambient >= 25.0:
        weights["rock"] += 1.0
    if ambient <= -20.0:
        weights["rock"] += 0.5
    return weights


def _total(biome: dict) -> int:
    """category 총량 + 모드 보정. 12~36 밖으로 나가면 필드가 프롭으로 덮이거나 빈다."""
    total = PROP_TOTAL.get(str(biome.get("category", "")), DEFAULT_PROP_TOTAL)
    mods = (biome.get("difficulty") or {}).get("mods") or {}
    if "allPrev" in mods:
        total += 6
    if "maze" in mods:
        total += 2
    if "cover" in mods:
        total += 2
    if (mods.get("light") or "") == "dark":
        total -= 2
    return max(PROP_MIN, min(PROP_MAX, total))


def prop_plan(biome: dict) -> list:
    """{key, part, n} 목록. 같은 키트·다른 바이옴이면 배분이 달라진다."""
    kit = str(biome["topologyKit"])
    parts = prop_parts(kit)
    if len(parts) != 4:
        raise SystemExit("FAIL — %s 프롭 부품이 4개가 아니다: %s" % (kit, parts))
    weights = _weights(biome)
    total = _total(biome)
    # 역할 안 순서를 바이옴 해시로 돌린다 — 같은 역할만 다른 두 바이옴도 우세 부품이 갈린다.
    shift = zlib.crc32(str(biome["id"]).encode("utf-8")) % 4
    favored = {HABITAT_PART[str(word)] for word in (biome.get("habitat") or [])
               if str(word) in HABITAT_PART}
    scores = {}
    for part in parts:
        role = _role(part)
        rank = parts.index(part)
        score = weights[role] * ROLE_RANK_MULT[(rank + shift) % 4]
        if part in favored:
            score *= HABITAT_PART_GAIN
        scores[part] = score
    weight_sum = sum(scores.values())
    counts = {part: max(1, int(round(total * score / weight_sum))) for part, score in scores.items()}
    # 반올림 오차를 점수 순서대로 몰아 총량을 정확히 맞춘다.
    drift = total - sum(counts.values())
    order = sorted(parts, key=lambda p: (-scores[p], parts.index(p)))
    for i in range(abs(drift)):
        part = order[i % len(order)]
        counts[part] += 1 if drift > 0 else -1
        counts[part] = max(1, counts[part])
    if sum(counts.values()) != total:
        raise SystemExit("FAIL — %s 프롭 총량이 안 맞는다: %d ≠ %d"
                         % (biome["id"], sum(counts.values()), total))
    return [{"key": "prop:%s:%s" % (kit, part), "part": part, "n": counts[part]}
            for part in parts]


def build() -> dict:
    """biomes.json → 키 문서. 정본에 없는 값을 만들지 않는다."""
    doc = json.loads(BIOMES.read_text(encoding="utf-8"))
    rows, kits = [], set()
    for group in doc.get("groups", []):
        for biome in group.get("biomes", []):
            biome_id = str(biome.get("id", ""))
            kit = str(biome.get("topologyKit", ""))
            slots = biome.get("slots") or []
            if not biome_id or not kit or not slots:
                raise SystemExit("FAIL — %s: id/topologyKit/slots 중 빈 값" % (biome_id or "?"))
            if kit not in KITS:
                raise SystemExit("FAIL — %s: 생성기에 없는 키트 %s" % (biome_id, kit))
            kits.add(kit)
            rows.append({
                "id": biome_id,
                "slot": int(slots[0]),
                "kit": kit,
                "ground": "ground:%s" % kit,
                "lighting": "lit:%s" % biome_id,
                "ambient": "ambient:%s" % biome_id,
                "props": prop_plan(biome),
            })
    if not rows:
        raise SystemExit("FAIL — biomes.json 에 바이옴이 없다")
    ids = [r["id"] for r in rows]
    slots = [r["slot"] for r in rows]
    if len(set(ids)) != len(ids):
        raise SystemExit("FAIL — 바이옴 id 중복")
    if len(set(slots)) != len(slots):
        raise SystemExit("FAIL — 블록 slot 중복")
    rows.sort(key=lambda r: (r["slot"], r["id"]))
    return {"meta": META, "kits": sorted(kits), "biomes": rows}


def encoded(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="파일이 생성물과 같은지만 본다")
    args = ap.parse_args()

    doc = build()
    text = encoded(doc)
    props = sum(sum(p["n"] for p in row["props"]) for row in doc["biomes"])
    print("biome_assets — 바이옴 %d · 키트 %d · 프롭 %d (바이옴당 %d~%d)"
          % (len(doc["biomes"]), len(doc["kits"]), props,
             min(sum(p["n"] for p in r["props"]) for r in doc["biomes"]),
             max(sum(p["n"] for p in r["props"]) for r in doc["biomes"])))

    if args.check:
        for path in (OUT, MIRROR):
            if not path.exists():
                print("[ FAIL ] 없음 — %s" % path.relative_to(HERE))
                return 1
            if path.read_text(encoding="utf-8") != text:
                print("[ FAIL ] 다름 — %s (정본: biomes.json, 생성기로 다시 뽑는다)" % path.relative_to(HERE))
                return 1
        print("정본 = 생성물 · 사본 = 정본")
        return 0

    OUT.write_text(text, encoding="utf-8")
    MIRROR.parent.mkdir(parents=True, exist_ok=True)
    MIRROR.write_text(text, encoding="utf-8")
    print("씀 — %s · %s" % (OUT.relative_to(HERE), MIRROR.relative_to(HERE)))
    return 0


if __name__ == "__main__":
    sys.exit(run("biomeassets", main))
