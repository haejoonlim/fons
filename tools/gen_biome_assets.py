#!/usr/bin/env python3
"""바이옴 에셋 키 정본 → `data/biome_assets.json` (+ `godot/data/` 사본).

무엇을 만드나
-------------
`data/biomes.json` 의 26바이옴에서 **키만** 뽑는다. 메시·프롭 개수는 만들지 않는다.

| 항목 | 출처 |
|---|---|
| `id` · `slot` | `biomes.json` `biomes[].id` · `slots[0]` |
| `kit` | `biomes.json` `biomes[].topologyKit` |
| `ground` | `ground:<kit>` — 같은 키트는 같은 바닥 묶음을 쓴다 |
| `lighting` | `lit:<id>` — 바이옴당 프리셋 1 (계획 L2 = 26개) |
| `ambient` | `ambient:<id>` — 바이옴당 환경 이펙트 1 |
| `props` | **비어 있다** — 스타일 확정 뒤 S2 에서 채운다 (개수를 지어내지 않는다) |

키만 담는 이유: 지금 정해진 것은 "어느 세계가 어느 키트를 쓰는가"뿐이다. 프롭 수·폴리곤
예산은 아트 스타일이 정한 뒤 채운다 ([docs/design/바이옴_에셋_계획.md] §7).

실행
----
    ./.venv/bin/python tools/gen_biome_assets.py           # 생성 + 사본
    ./.venv/bin/python tools/gen_biome_assets.py --check   # 정본과 다르면 exit 1

`--check` 는 게이트 단계 `biomeassets` 로 돈다. 손으로 고치면 exit 1 — 정본은 `biomes.json` 이다.
"""
import argparse
import json
import sys
from pathlib import Path

from gate_contract import run

HERE = Path(__file__).resolve().parent.parent
BIOMES = HERE / "data" / "biomes.json"
OUT = HERE / "data" / "biome_assets.json"
MIRROR = HERE / "godot" / "data" / "biome_assets.json"

META = {
    "v80": "biome_assets v1 — data/biomes.json v1.3 파생 · 2026-10-23",
    "source": "data/biomes.json — kit = topologyKit, slot = slots[0]. 값은 전부 파생이며 손으로 고치지 않는다.",
    "generatedBy": "tools/gen_biome_assets.py",
    "keyRule": "ground:<kit> · lit:<biome_id> · ambient:<biome_id> · prop:<kit>:<n>",
    "propsRule": "프롭은 아트 스타일 확정 뒤 S4 에서 채운다 — 지금은 빈 배열 (개수를 지어내지 않는다).",
}


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
            kits.add(kit)
            rows.append({
                "id": biome_id,
                "slot": int(slots[0]),
                "kit": kit,
                "ground": "ground:%s" % kit,
                "lighting": "lit:%s" % biome_id,
                "ambient": "ambient:%s" % biome_id,
                "props": [],
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
    print("biome_assets — 바이옴 %d · 키트 %d · 프롭 0 (S2 대기)"
          % (len(doc["biomes"]), len(doc["kits"])))

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
