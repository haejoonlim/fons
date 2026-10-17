#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_telegraph_data.py — TelegraphEngine 데이터 게이트 (D-253 시트 불변식 · 2026-09-21).

monsters.json의 패턴(castSec/warnSec/phase·enrageHp)이 D-253 시트·G4보스_텔레그래프시트 정본을
따르는지 데이터 단계에서 잡는다 (Unity EditMode 없이 상시 스냅샷에서 검증).

판정 범위(정본 준수 — 중요): D-253 시트·"보스당 무예고 ≤1" 계약의 대상은 **G4 신규 보스 6종**이다.
구형 126+종의 패턴은 타이밍 필드가 없는 것이 정본(H9는 스탯·aiDecision만 감사) — 전수 무예고 판정은 오탐.

검증:
  V1 [G4 6종] 무예고 패턴(cast=0·warn=0, cd>0) = 정확히 1건 (무풍 임금 침묵 낙하 — D-174 예외) · 보스당 ≤1
  V2 [G4 6종] cd>0 패턴 중 예고 보유 비율 ≥ 60% — 텔레그래프 전투의 최소 가시성
  V3 전 종족 phase 창 정합 — lo ≤ hi · [0,1] 범위 내
  V4 광폭 보유 몬스터(aiDecision.enrageHp>0)의 광폭 창 패턴 [enrageHp, 1] 존재 (WARN — 스탯배율형 광폭도 있음)
  V5 전 종족 castSec·warnSec ≥ 0 — 음수 예고 금지
실행: python3 design-docs/_tools/check_telegraph_data.py → exit 0 = ALL PASS
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
M = json.load(open(os.path.join(ROOT, "data/monsters.json"), encoding="utf-8"))
monsters = M["monsters"] if isinstance(M, dict) else M
fails = []

# G4 신규 보스 6종 — D-253 시트·"보스당 무예고 ≤1" 계약의 정본 범위 (#64)
G4_BOSSES = {"mon_frostwhale_01", "mon_crystalking_01", "mon_silenceking_01",
             "mon_glasscutter_01", "mon_debtavatar_01", "mon_nullsentinel_01"}

# V1 — [G4 6종] 무예고 정확히 1건 (cd>0 · cast=0 · warn=0)
nowarn = []
for m in monsters:
    if m["id"] not in G4_BOSSES:
        continue
    for p in m.get("pattern") or []:
        if p.get("cd", 0) > 0 and p.get("castSec", 0) == 0 and p.get("warnSec", 0) == 0:
            nowarn.append((m["id"], p.get("name")))
print(f"V1 [G4 6종] 무예고 패턴 {len(nowarn)}건 — {'OK (침묵 낙하 단 1건)' if len(nowarn) == 1 else 'FAIL'}")
for n in nowarn:
    print("   ", n)
if len(nowarn) != 1:
    fails.append(f"G4 무예고 {len(nowarn)}건 — 정본 1건(침묵 낙하)")

# V2 — [G4 6종] 예고 보유 비율 ≥ 60% (cd>0 실기동 패턴 한정)
total = tele = 0
for m in monsters:
    if m["id"] not in G4_BOSSES:
        continue
    for p in m.get("pattern") or []:
        if p.get("cd", 0) > 0:
            total += 1
            if p.get("castSec", 0) > 0 or p.get("warnSec", 0) > 0:
                tele += 1
ratio = tele / total if total else 0
print(f"V2 [G4 6종] 예고 보유율 {tele}/{total} = {ratio:.0%} — {'OK' if ratio >= 0.6 else 'FAIL'} (하한 60%)")
if ratio < 0.6:
    fails.append(f"예고 보유율 {ratio:.0%} < 60%")

# V3 — phase 창 정합
bad_ph = []
for m in monsters:
    for p in m.get("pattern") or []:
        ph = p.get("phase")
        if ph is None:
            continue
        if not (isinstance(ph, list) and len(ph) == 2 and 0 <= ph[0] <= ph[1] <= 1):
            bad_ph.append((m["id"], p.get("name"), ph))
print(f"V3 phase 창 정합: {'OK' if not bad_ph else 'FAIL'} — {len(bad_ph)}건")
for b in bad_ph[:5]:
    print("   ", b)
if bad_ph:
    fails.append(f"phase 비정합 {len(bad_ph)}건")

# V4 — 광폭 보유자의 [enrageHp, 1] 패턴 존재
missing_enrage = []
for m in monsters:
    ad = m.get("aiDecision") or {}
    eh = ad.get("enrageHp") or 0
    if eh <= 0:
        continue
    has = any(
        (p.get("phase") and abs(p["phase"][0] - eh) < 1e-6 and abs(p["phase"][1] - 1.0) < 1e-6)
        for p in m.get("pattern") or []
    )
    if not has:
        missing_enrage.append(m["id"])
print(f"V4 광폭 창 패턴: {'OK' if not missing_enrage else 'WARN'} — 누락 {len(missing_enrage)}종 {missing_enrage[:5]}")
# 광폭 창 패턴 미보유는 강화 패턴이 아닌 광폭(스탯배율)형도 있어 WARN — 하한은 무예고 1건 계약(V1)이 지킨다.

# V5 — 음수 예고 금지
neg = []
for m in monsters:
    for p in m.get("pattern") or []:
        if p.get("castSec", 0) < 0 or p.get("warnSec", 0) < 0:
            neg.append((m["id"], p.get("name")))
print(f"V5 음수 예고: {'OK' if not neg else 'FAIL'} — {len(neg)}건")
if neg:
    fails.append(f"음수 예고 {len(neg)}건")

print(f"\n종합: {'ALL PASS ✅' if not fails else 'FAIL ' + str(len(fails)) + '건'}")
for f in fails:
    print("  FAIL:", f)
sys.exit(1 if fails else 0)
