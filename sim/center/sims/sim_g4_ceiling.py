# -*- coding: utf-8 -*-
"""
G4 천정(101~130층) 밸런스 시뮬 — 확정 #51/#54 후속
노브:
  scale  = 5.8 + (f-100)*0.05        (개정안 §3 가안)
  hpLv   = Lv130 캡 + HP 복리 감쇠 (06 정본: (1-0.02)^(Lv-110)) — G4 확장: 복리 연속 적용
  파티   = ★5 파티(55층 정본) vs ★6 파티(100층 정본) 두 상태로 G4 등반 시뮬
  ★7 요건 = G4에서 각성 재료 획득 + G4 정점 보스 격파
출력: 정점 통과율 / 체감 마진(scale 대비 실효 전투력) / 경제(마석 수급 vs 소비)
판정 기준: 실효 마진 1.1~1.6 (01 정본 ★5 만렙 f100 실효 1.2~1.4와 동일 체감 밴드)
"""
import math, random

def monster_scale(f):
    if f <= 50:   return 2.0 + f * 0.03
    if f <= 95:   return 3.5 + (f - 50) * 0.04
    if f <= 100:  return 5.3 + (f - 95) * 0.10
    return 5.8 + (f - 100) * 0.05          # G4 가안 노브

def monster_power(f, g4_hp_relief):
    s = monster_scale(f)
    if f > 100 and g4_hp_relief > 0:
        s *= (1 - g4_hp_relief)            # G4 HP 완화 노브
    return s

def party_power(grade, awakening, gear_g4):
    # ★5 만렙 파티 실효 ~7.2 (f100 마진 1.2~1.4 역산 — 06 정본 감쇠 후) · ★6 파티 ~9.6
    base = 7.2 if grade == 5 else 9.6
    base *= (1 + 0.06 * awakening)         # 귀각(각성) 1회당 +6% (정본 각성 상한 1.08 계열)
    base *= (1 + 0.04 * gear_g4)           # G4 장비/서약 보정 노브
    return base

def g4_floor_clear(margin):
    # 마진 1.0 미만 = 돌파 불가 · 1.0~1.1 = 위험(50%) · 1.1+ = 안정
    if margin < 1.0: return 0.0
    if margin < 1.1: return 0.5
    return 1.0

def sim_g4(party_grade, awakening, gear_g4, g4_hp_relief, runs=20000):
    rng = random.Random(42)
    clears = 0; deepest_sum = 0; full_clears = 0
    pp = party_power(party_grade, awakening, gear_g4)
    for _ in range(runs):
        deepest = 100
        for f in range(101, 131):
            m = pp / monster_power(f, g4_hp_relief)
            if rng.random() < g4_floor_clear(m):
                deepest = f
            else:
                break
        deepest_sum += deepest
        if deepest >= 130: clears += 1
        if deepest == 130: full_clears += 1
    return clears / runs, deepest_sum / runs, full_clears / runs

def econ_g4(stone_rate_per_run=1.0):
    # 마석 수급(정본: 잭팟 f^2×85 · 퇴장 f×30) — G4 구간 수급 vs ★7 소비(가안 4,800석)
    income = 0
    for f in range(101, 131):
        income += 30 * f                          # 퇴장
        if f % 10 == 0: income += f * f * 85      # 잭팟
    return income, income / 4800

print(f"{'파티':<8}{'각성':>4}{'서약':>4}{'HP완화':>7} | {'130통과':>8}{'평균도달':>9}{'완주':>7} | 경제(마석/★7개수)")
for grade in (5, 6):
    for aw in (0, 1, 2):
        for relief in (0.0, 0.10, 0.18):
            c, d, full = sim_g4(grade, aw, 0, relief)
            inc, stars = econ_g4()
            print(f"★{grade} 파티 {aw:>3}   0   {relief:>6.0%} | {c:>8.1%}{d:>9.1f}{full:>7.1%} | {inc:>6,}석 = ★7 {stars:.1f}개분")

print()
print("── 권장 노브 후보 (체감 마진 1.1~1.6 밴드 내 진입) ──")
pp5 = party_power(5, 1, 0); pp6 = party_power(6, 1, 0)
for f in (101, 110, 120, 130):
    for relief in (0.10, 0.18):
        m5 = pp5 / monster_power(f, relief); m6 = pp6 / monster_power(f, relief)
        print(f"f{f} HP완화{relief:.0%}: ★5귀각1 마진 {m5:.2f} · ★6귀각1 마진 {m6:.2f}")
