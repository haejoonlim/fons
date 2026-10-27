#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_manual_fields.py — 손으로 넣은 필드가 생성기 때문에 사라지는 것을 막는다.

왜 있나 (원본 이식, 원본 check_manual_fields.py):
  정본에는 생성기가 채우는 자리(id·stats·spawn)와 **사람이 직접 편집한 자리**
  (regions·gatekeeper·settlements·missionWeights·ecology)가 같이 산다. 파일 위에서는
  구분되지 않는다. 그래서 생성기를 한 번 다시 돌리면 손으로 넣은 필드가 **키째로**
  사라지거나 빈 값이 된다. 원본은 gen_expand_260.py 재실행으로 그 사고를 겪었다.

  폰즈는 `tools/sync_data.py` 가 원본 트리에서 23종을 통째로 복사하고,
  `tools/gen_personalities.py`·`gen_biome_assets.py` 가 전체 파일을 다시 쓴다.
  지금은 `data/` 가 유일한 정본 사본이므로 덮이면 되돌릴 원본이 없다.

무엇을 보나:
  파일마다 **모든 항목이 가져야 하는 키**를 선언하고, 하나라도 없으면 실패다.
  "빈 값"이 아니라 **키 자체의 부재**를 본다 — 생성기가 무엇을 하든 사람이 넣은
  자리는 남아 있어야 한다.

여백:
  모든 항목이 같을 수는 없다. `biome_idea_gate` 는 #59 「미션 없음 규칙」이라
  missionWeights 를 갖지 않는다. **이유를 적고** ALLOWED_MISSING 에 남긴다.
  이유 없는 예외는 넣지 않는다.

  `ambient.json` 에는 `level` 이 없다 — 비전투 개체라 레벨 개념이 없다(원본 대조).
  그래서 PROTECTED 목록이 monsters 와 다르다.

사용:
  ./.venv/bin/python tools/check_manual_fields.py
  ./.venv/bin/python tools/check_manual_fields.py --selftest
종료: 누락 1 · 깨끗 0 · 사용 오류 2
"""
import argparse
import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, "data")

sys.path.insert(0, HERE)
from gate_contract import run  # noqa: E402

# 손으로 편집한 필드 — 생성기가 만들어 넣는 id/name 과 달리 **없어지면 안 되는** 자리.
# 값 검사(tools/check_manual_values.py)가 이 목록을 그대로 가져간다 — 목록은 여기 한 곳에만.
PROTECTED = {
    "biomes.json": ["id", "name", "floors", "floorScale", "slots", "habitat", "difficulty",
                    "climate", "category", "regions", "gatekeeper", "settlements",
                    "topologyKit", "ecologyStatus", "missionWeights"],
    "monsters.json": ["id", "name", "category", "aiType", "tier", "level", "threatBase",
                      "element", "stats", "weakness", "resistance", "statusImmune",
                      "aiDecision", "pattern", "parts", "spawn", "loot", "ecology"],
    # 비전투 개체 — level 이 없다(원본 스키마).
    "ambient.json": ["id", "name", "category", "aiType", "tier", "threatBase", "element",
                     "stats", "weakness", "resistance", "statusImmune", "aiDecision",
                     "pattern", "parts", "spawn", "loot", "ecology"],
}

# (파일, 필드) → {id: 사유}
ALLOWED_MISSING = {
    ("biomes.json", "missionWeights"): {
        "biome_idea_gate": "엔딩 무대 — #59 「미션 없음 규칙」. 일반 조우가 없어 미션 배분도 없다. "
                           "누락이 아니라 규칙",
    },
}

# 2026-10-24 실측 403 (바이옴 26 · 전투 143 · 비전투 234). 스캔이 무너지면
# "누락 0건" 이 조용히 참이 되므로 하한을 둔다.
MIN_ENTITIES = 380


def entities(fname, data_dir=DATA):
    """파일별 항목 목록 — 바이옴은 groups[].biomes[] 로 한 겹 들어간다."""
    with open(os.path.join(data_dir, fname), encoding="utf-8") as fh:
        doc = json.load(fh)
    if fname == "biomes.json":
        return [b for g in doc["groups"] for b in g["biomes"]]
    return doc.get(fname.split(".")[0], [])


def check(data_dir=DATA):
    """(위반 목록, 검사 항목 수)."""
    bad = []
    total = 0
    for fname, keys in PROTECTED.items():
        try:
            items = entities(fname, data_dir)
        except (OSError, ValueError, KeyError) as exc:
            bad.append("%s 을 읽을 수 없음: %s" % (fname, exc))
            continue
        total += len(items)
        allowed = {key: ALLOWED_MISSING.get((fname, key), {}) for key in keys}
        for it in items:
            eid = it.get("id", "?")
            for key in keys:
                if key in it:
                    continue
                if allowed.get(key, {}).get(eid):
                    continue
                bad.append("%s · %s 에 손으로 넣은 필드 %r 가 없다" % (fname, eid, key))
    return bad, total


def _except_and_drop(b):
    """의도된 예외 id 로 바꾸되 다른 손 필드를 지운다 — 예외가 모든 누락을 덮지 않는지 본다."""
    b["id"] = "biome_idea_gate"
    b.pop("gatekeeper", None)


def _selftest():
    """임시 정본에서 **진짜 check()** 를 돌린다 — 하네스만 통과하는 상태를 막는다."""
    fails = []
    full = {k: 1 for k in PROTECTED["biomes.json"]}

    def _biomes(tweak=None):
        b = dict(full)
        b["id"] = "biome_a"          # id 를 나중에 둔다 — 가도가 id 를 덮으면 예외가 조용히 통과한다
        if tweak:
            tweak(b)
        return {"groups": [{"id": "g1", "biomes": [b]}]}

    def _other(name):
        key = name.split(".")[0]
        it = {k: 1 for k in PROTECTED[name]}
        it["id"] = "x1"
        return {key: [it]}

    def run_check(tweak=None, raw=None):
        td = tempfile.mkdtemp(prefix="manual-fields-")
        try:
            docs = raw if raw is not None else {
                "biomes.json": _biomes(tweak),
                "monsters.json": _other("monsters.json"),
                "ambient.json": _other("ambient.json"),
            }
            for name, doc in docs.items():
                with open(os.path.join(td, name), "w", encoding="utf-8") as fh:
                    fh.write(doc if isinstance(doc, str) else json.dumps(doc))
            return check(td)
        finally:
            shutil.rmtree(td, ignore_errors=True)

    def drop(field):
        return lambda b: b.pop(field, None)

    cases = [
        ("정상: 모든 필드 있음", None, 0),
        ("missionWeights 소실 → 잡음", drop("missionWeights"), 1),
        ("regions 소실 → 잡음", drop("regions"), 1),
        ("gatekeeper 소실 → 잡음", drop("gatekeeper"), 1),
        ("의도된 예외(#59 biome_idea_gate) 는 통과",
         lambda b: b.__setitem__("id", "biome_idea_gate"), 0),
        ("예외 id 라도 다른 손 필드가 사라지면 잡음", _except_and_drop, 1),
    ]
    for label, tweak, want in cases:
        bad, _total = run_check(tweak)
        got = 1 if bad else 0
        if got != want:
            fails.append("%s (기대 %d, 실제 %d)%s" % (label, want, got,
                                                     "  ← " + bad[0] if bad else ""))

    _bad, total = run_check()
    if total < 3:
        fails.append("검사가 실제로 항목을 보지 않는다: %d개" % total)

    corrupt = run_check(raw={"biomes.json": "{oops", "monsters.json": "{}", "ambient.json": "{}"})
    if not corrupt[0]:
        fails.append("깨진 정본이 조용히 통과한다")

    for f in fails:
        print("[manfields] 자가진단 실패 — " + f)
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--data-dir", default=DATA)
    args = ap.parse_args()
    if args.selftest:
        return _selftest()

    bad, total = check(args.data_dir)
    if total < MIN_ENTITIES:
        print("[manfields] FAIL — 검사 항목 %d개 < 하한 %d개. 범위가 깨졌다(파일 경로·구조 변경). "
              "'누락 0건' 은 참이 아니다." % (total, MIN_ENTITIES))
        return 1
    if bad:
        print("[manfields] 손으로 넣은 필드 누락 %d건" % len(bad))
        for b in bad[:40]:
            print("  · " + b)
        if len(bad) > 40:
            print("  … 외 %d건" % (len(bad) - 40))
        print("  생성기 재실행이 수동 편집을 덮었을 수 있다. 없애도 되는 필드라면 "
              "ALLOWED_MISSING 에 **사유**를 적고 추가한다.")
        return 1
    n_fields = sum(len(v) for v in PROTECTED.values())
    print("[manfields] OK — 항목 %d개 · 수동 필드 %d종 전부 존재 (의도된 예외 %d건)"
          % (total, n_fields, sum(len(v) for v in ALLOWED_MISSING.values())))
    return 0


if __name__ == "__main__":
    sys.exit(run("manfields", main))
