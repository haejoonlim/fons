#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""직업별 영웅 몸통 대역 → `data/hero_assets.json` (+ `godot/data/` 사본).

무엇을 만드나
-------------
S5b — 34직업이 어느 몸통 대역(`guard` · `scout` · `mystic`)을 입는지 적는다.
메시는 만들지 않는다. `tools/gen_hero_glb.py` 가 대역 3벌을 굽고, 이 표가 직업을 대역에 잇는다.

| 항목 | 출처 |
|---|---|
| `id` · `name` · `stage` | `data/job_tree.json` `jobs[]` |
| `role` | 같은 파일의 `role` (선봉·수호·암살·포격·마법·지원·무직·생활) |
| `band` | 아래 역할 → 대역 표 |

    guard   선봉 · 수호            넓은 어깨 · 방패 — 앞에 서는 몸
    scout   암살 · 포격 · 무직     뼈대가 보이는 몸 · 두건 — 빠르거나 이름 없는 몸
    mystic  마법 · 지원 · 생활     로브 · 지팡이 — 뒤에서 부리는 몸

무직(무명자·무직)은 방패도 로브도 어울리지 않아 두건 쪽에 둔다. 생활직(l3_life)은
전투 직업이 아니라 지원 쪽 실루엣으로 둔다. 이 판단은 데이터가 아니라 이 표가 정한다 —
바꾸려면 여기 한 줄을 고치고 다시 뽑는다.

왜 생성기인가
-------------
직업 목록은 `job_tree.json` 정본이다. 표를 손으로 적으면 직업이 늘 때 조용히 빠지고,
빠진 직업은 화면에서 키 해시로 아무 몸통이나 입는다(판마다 같은 몸통이긴 하다).

키 규칙
-------
`hero:<job id>` — `field_state.gd` 가 영웅 엔티티에 붙이는 `asset` 문자열 그대로다.
키가 `hero:<번호>`(직업 없이 인덱스만)인 영웅은 표에 없으므로 런타임이 키 해시로 고른다.

실행
----
    ./.venv/bin/python tools/gen_hero_assets.py           # 생성 + 사본
    ./.venv/bin/python tools/gen_hero_assets.py --check   # 정본과 다르면 exit 1

`--check` 는 게이트 단계 `heroassets` 로 돈다. 손으로 고치면 exit 1 —
정본은 `job_tree.json` 과 이 스크립트의 역할 표다.
"""
import argparse
import json
import sys
from pathlib import Path

from gate_contract import run

HERE = Path(__file__).resolve().parent.parent
JOBS = HERE / "data" / "job_tree.json"
OUT = HERE / "data" / "hero_assets.json"
MIRROR = HERE / "godot" / "data" / "hero_assets.json"

BANDS = {
    "guard": ["선봉", "수호"],
    "scout": ["암살", "포격", "무직"],
    "mystic": ["마법", "지원", "생활"],
}

META = {
    "v80": "hero_assets v1 — S5b 직업별 영웅 몸통 대역 · 2026-10-27",
    "source": "data/job_tree.json — 직업 role 에서 파생한다. 손으로 고치지 않는다.",
    "generatedBy": "tools/gen_hero_assets.py",
    "keyRule": "hero:<job id> — field_state.gd 의 entity.asset 문자열 그대로",
    "bandRule": "역할 → 대역: " + " · ".join(
        "%s = %s" % (band, "·".join(roles)) for band, roles in BANDS.items()),
    "bands": BANDS,
}


def build() -> dict:
    jobs = json.loads(JOBS.read_text(encoding="utf-8")).get("jobs", [])
    if not jobs:
        raise SystemExit("FAIL — job_tree.json 에 jobs 가 없다")
    role_band = {role: band for band, roles in BANDS.items() for role in roles}
    rows = []
    for job in jobs:
        role = str(job.get("role", ""))
        band = role_band.get(role)
        if band is None:
            raise SystemExit("FAIL — %s: 역할 %s 가 대역 표에 없다" % (job.get("id", "?"), role))
        rows.append({
            "key": "hero:%s" % job["id"],
            "id": str(job["id"]),
            "name": str(job.get("name", "")),
            "stage": int(job.get("stage", 0)),
            "role": role,
            "band": band,
        })
    rows.sort(key=lambda row: (row["stage"], row["id"]))
    counts = {band: sum(1 for row in rows if row["band"] == band) for band in BANDS}
    if len(rows) != 34:
        raise SystemExit("FAIL — 직업이 34가 아니다: %d" % len(rows))
    if min(counts.values()) < 1:
        raise SystemExit("FAIL — 빈 대역이 있다: %s" % counts)
    return {"meta": META, "jobs": rows}


def encoded(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="파일이 생성물과 같은지만 본다")
    args = ap.parse_args()

    doc = build()
    text = encoded(doc)
    counts = {band: sum(1 for row in doc["jobs"] if row["band"] == band) for band in BANDS}
    print("hero_assets — 직업 %d · %s" % (
        len(doc["jobs"]), " · ".join("%s %d" % (band, n) for band, n in counts.items())))

    if args.check:
        for path in (OUT, MIRROR):
            if not path.exists():
                print("[ FAIL ] 없음 — %s" % path.relative_to(HERE))
                return 1
            if path.read_text(encoding="utf-8") != text:
                print("[ FAIL ] 다름 — %s (정본: job_tree.json, 생성기로 다시 뽑는다)"
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
    sys.exit(run("heroassets", main))
