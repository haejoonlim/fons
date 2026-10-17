#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_story_scenes.py — scenes.json 정본 게이트 (스토리 결선 · 2026-09-21).

검증의 축은 "유령 씬"이다 — 130층 설계 정본(#51)을 벗어난 트리거는 어떤 런타임 확장으로도
발화하지 않는 진짜 결함. 반면 MaxFloor 20(런타임 v1)~130(설계) 사이 씬은 **추적 부채**로
분류해 보고만 한다 — MaxFloor 확장 시 자동 발화되는 정상 데이터다.

검증:
  V1 triggerFloor ≤ 130(설계 정본) — 초과분만 FAIL · 20~130 = 추적 부채 카운트
  V2 같은 씬 내 선택지 중복 0 — (text·flag·relDelta·relLineage 세트 기준)
  V3 forced 씬 단 1건 + skipXp 0 (스킵 불가 계약)
  V4 minRun 일관 — 0 이상 정수 · 강제 씬은 0
  V5 id 규칙 + triggerFloor == id 층부 (StoryDirector.AuditScenes와 동일)
실행: python3 design-docs/_tools/check_story_scenes.py  → exit 0 = ALL PASS
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SCENES = os.path.join(ROOT, "data/scenes.json")
MAX_FLOOR = 20   # GameRules.MaxFloor (원본 구현/Core/GameRules.cs) — 순환 import 방지 상수 동결

# 설계 정본 130층(층체계_130_개정안 #51) 준거 씬 — 런타임 v1(20층) 도달 전까지 "추적 부채"로 분류.
# V1의 FAIL 대상이 아니라 부채 카운트로만 보고한다 (설계는 130층으로 완성돼 있고, 런타임이 따라올 구조).
PLANNED_CEILING = 130

d = json.load(open(SCENES, encoding="utf-8"))
scenes = d["scenes"]
fails = []

# V1 — 유령 씬 (MaxFloor 초과) vs 설계 부채 (130층 이내 · 런타임 미지원)
ghost = [s["id"] for s in scenes if s["triggerFloor"] > PLANNED_CEILING]
debt = [s["id"] for s in scenes if MAX_FLOOR < s["triggerFloor"] <= PLANNED_CEILING]
print(f"V1 유령 씬(>{PLANNED_CEILING}): {'OK' if not ghost else 'FAIL'} — {len(ghost)}건 {ghost}")
print(f"   추적 부채({MAX_FLOOR}<층≤{PLANNED_CEILING}): {len(debt)}건 — MaxFloor 20→130 확장 시 자동 발화 (데이터 재발주 불필요)")
if ghost:
    fails.append(f"유령 씬(설계 상한 초과): {ghost}")

# V2 — 선택지 중복
for s in scenes:
    seen = set()
    for c in s.get("choices") or []:
        key = (c.get("text"), c.get("flag"), c.get("relDelta"), c.get("relLineage"))
        if key in seen:
            fails.append(f"{s['id']}: 선택지 중복 {key}")
            print(f"V2 {s['id']}: FAIL — 중복 선택지 {key[0]}")
            break
        seen.add(key)
print("V2 선택지 중복: " + ("OK" if not any("선택지 중복" in f for f in fails) else "FAIL"))

# V3 — forced 1건 + skipXp 0
forced = [s for s in scenes if s.get("forced")]
ok3 = len(forced) == 1 and all((s.get("skipXp") or 0) == 0 for s in forced)
print(f"V3 forced 1건+skipXp 0: {'OK' if ok3 else 'FAIL'} — {[s['id'] for s in forced]}")
if not ok3:
    fails.append("forced 계약 위반")

# V4 — minRun 표기 (0 이상 정수, 강제 씬은 0)
bad_mr = [s["id"] for s in scenes if not isinstance(s.get("minRun", 0), int) or s.get("minRun", 0) < 0
          or (s.get("forced") and s.get("minRun", 0) != 0)]
print(f"V4 minRun 표기: {'OK' if not bad_mr else 'FAIL'}")
if bad_mr:
    fails.append(f"minRun 비정합: {bad_mr}")

# V5 — id 규칙 + 층부 일치
bad_id = []
for s in scenes:
    m = re.match(r"^sc_\d+_(\d+)_\d+$", s["id"])
    if not m or int(m.group(1)) != s["triggerFloor"]:
        bad_id.append(s["id"])
print(f"V5 id 규칙+층부 일치: {'OK' if not bad_id else 'FAIL'}")
if bad_id:
    fails.append(f"id 규칙 위반: {bad_id}")

print(f"\n종합: {'ALL PASS ✅' if not fails else 'FAIL ' + str(len(fails)) + '건'}")
for f in fails:
    print("  FAIL:", f)
sys.exit(1 if fails else 0)
