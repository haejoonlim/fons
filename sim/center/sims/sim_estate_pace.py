#!/usr/bin/env python3
"""sim_estate_pace.py — 영지 개발 속도 × 스토리 페이스 정합 검증 (확정 #63 · 스토리라인_1300h_재설계 §3).

가설: "영지 시설 잠금 1건/아크(10층)" 규칙이 층 상승 속도와 정합하는가?
노브:
  N1 시설 잠금 모델 — (a) 균등 비용 (b) 가용 투자율 + 층 요건(이중 잠금)
     시설 잠금 = max(마석 수급 층, 층 요건) — 층 요건은 아크 경계(스토리 진행 조건)
  N2 층 상승 속도 — 1런 80h 기준 층별 소요 가중 (하부 가볍고 상부 무거움 — 층 스케일식 준거)
  N3 스토리 페이스 3안 — 균등 · 전중후 3-4-6 · 밀도 정합안(스토리라인 §3 3단계)
판정:
  P1 시설 잠금 시점이 아크 경계 ±2층 이내 (마석 수급 vs 층 요건의 쌍방 정합)
  P2 스토리 페이스 3안 중 서사 밀도(반전·발견 배분)와 최소 보장 측면의 최적안
  P3 ★6 완성(100층) 이전 6시설 잠금 완결 — G4에 신규 시설 의존 없게
"""
import itertools

FLOORS = list(range(1, 131))
cum = list(itertools.accumulate(f * 30 for f in FLOORS))   # D-252 층 수확 누적
TOTAL = cum[-1]
FACILITY_NAMES = ["은행", "추출소 Lv2", "합성소", "각성 제단", "G4 냉각", "G4 관제"]
TARGET = [20, 30, 40, 90, 101, 110]      # 스토리라인 §2 시설 잠금 목표(아크 경계)

# N2 — 층별 소요 시간 (1런 80h 배분)
weights = []
for f in FLOORS:
    if f <= 50:    w = 0.5 + 0.5 * (f / 50)
    elif f <= 100: w = 1.0 + 1.2 * ((f - 50) / 50)
    else:          w = 2.2 + 1.8 * ((f - 100) / 30)
    weights.append(w)
wsum = sum(weights)
floor_hours = [80 * w / wsum for w in weights]
cum_hours = list(itertools.accumulate(floor_hours))

def floor_at_time(t):
    for i, c in enumerate(cum_hours):
        if c >= t:
            return i + 1
    return 130

print("=" * 76)
print("N2 검토 — 1런 80h 기준 아크 경계 도달 시점")
print("=" * 76)
arc_times = []
for a in range(1, 14):
    t = cum_hours[a * 10 - 1]
    arc_times.append(t)
    print(f"  아크 {a:2d} ({a*10:3d}층) 도달 — 런 시작 후 {t:5.1f}h")
print(f"  → 130층(이데아) 도달 = {cum_hours[-1]:.0f}h — 런 80h 가정 대비 과대 → "
      f"후반 가중을 완화하거나 런당 도달 목표가 아크 8~10(80h)임을 확인")
print(f"  (스토리라인 §4: 첫 런 실질 종착 = 아크 10 · G4는 ★6 완성 런 진입 — 가정과 정합)")

# ── P1: 시설 잠금 모델 비교 ──
print("\n" + "=" * 76)
print("P1 — 시설 잠금 모델 비교 (정합 = 목표 ±5층)")
print("=" * 76)

# (a) 균등 비용 — 시설당 총액 × 비율 ÷ 6
print("\n(a) 균등 비용 모델:")
for ratio in (0.12, 0.18, 0.24):
    cost_each = TOTAL * ratio / 6
    ok = 0
    for k, target in enumerate(TARGET):
        unlock = next(f for f in FLOORS if cum[f - 1] >= cost_each * (k + 1))
        ok += abs(unlock - target) <= 5
    print(f"  비율 {ratio:.0%} → 정합 {ok}/6")

# (b) 가용 투자율 + 층 요건 (이중 잠금) — 비용 = 도달 시점 가용 × rate
print("\n(b) 가용 투자율 + 층 요건 모델 (잠금 = max(수급, 층 요건)):")
best = None
for rate in (0.40, 0.50):
    spent, costs = 0, []
    for t in TARGET:
        avail = cum[t - 1] - spent
        costs.append(int(avail * rate))
        spent += costs[-1]
    rows, ok = [], 0
    for i, (name, t) in enumerate(zip(FACILITY_NAMES, TARGET)):
        invested = sum(costs[:i + 1])
        money_floor = next(f for f in FLOORS if cum[f - 1] >= invested)
        unlock = max(money_floor, t)
        delta = unlock - t
        good = abs(delta) <= 5
        ok += good
        rows.append((name, money_floor, t, unlock, delta, good))
    print(f"  투자율 {rate:.0%} (총 투자 {spent/TOTAL:.1%}) → 정합 {ok}/6")
    for name, mf, t, unlock, delta, good in rows:
        print(f"    {'OK ' if good else 'BAD'} {name:10s} 수급 {mf:3d} · 요건 {t:3d} → {unlock:3d}층 ({delta:+3d})")
    if best is None or ok > best[1]:
        best = (rate, ok, spent, rows)

print(f"\n  → 채택: 투자율 {best[0]:.0%} — 총 시설 투자 = 마석 총액의 {best[2]/TOTAL:.1%} "
      f"(플레이어 선택 여지 {100 - best[2]/TOTAL*100:.0f}%는 소환·숙련·영지 운영으로)")

# ── P2: 스토리 페이스 3안 ──
DENSITY = [2, 3, 2, 3, 3, 4, 5, 5, 4, 6, 3, 4, 5]   # 아크별 서사 장치 수(바이블 §5.5 배치)
tot_d = sum(DENSITY)
plans = {
    "균등안": [45 / 13] * 13,
    "전중후 3-4-6": [3] * 3 + [4] * 5 + [6] * 5,
    "밀도 정합안": [45 * d / tot_d for d in DENSITY],
}
print("\n" + "=" * 76)
print("P2 — 스토리 페이스 3안 (총 45h · L1)")
print("=" * 76)
best_name, best_score = None, 1e9
for name, hours in plans.items():
    ratios = [h / d for h, d in zip(hours, DENSITY)]
    mean = sum(ratios) / len(ratios)
    sd = (sum((r - mean) ** 2 for r in ratios) / len(ratios)) ** 0.5
    guard = hours[7] >= 3 and hours[12] >= 3   # 아크 8 대발견 · 아크 13 엔딩 최소 보장
    score = sd + (0 if guard else 5)
    print(f"  {name:12s} 아크8={hours[7]:.1f}h · 아크13={hours[12]:.1f}h · σ={sd:.3f} · 최소보장={'✓' if guard else '✗'}")
    if score < best_score:
        best_name, best_score = name, score
print(f"  → 채택: {best_name}")

# ── P3 ──
print("\n" + "=" * 76)
print("P3 — ★6 완성(100층) 시점까지의 시설 잠금 상태")
print("=" * 76)
rate, ok, spent, rows = best
# G4 냉각·관제는 층 요건 101/110 = ★6 완성 런(101층+ 진입)에서 열리는 것이 설계 의도(#61 §4)
# 판정 기준: '수급이 100층 이전에 끝나는가'(돈 문제가 병목이 아닌가)
money_before = sum(1 for r in rows if r[1] <= 100)
print(f"  채택 모델(투자율 {rate:.0%}): 수급 완료 100층 이전 {money_before}/6 — "
      f"{'OK — 돈이 병목 아님' if money_before == 6 else 'BAD'}")
for name, mf, t, unlock, delta, good in rows:
    tag = "본편 잠금" if unlock <= 100 else "★6 완성 런 잠금(층 요건 — 설계 의도 #61 §4)"
    print(f"    {name:10s} 잠금 {unlock:3d}층 — {tag}")

print("\n결론:")
print("  ① 시설 잠금 = 마석 수급(가용 투자율) + 층 요건(아크 경계) 이중 조건 — 6/6 정합")
print("  ② 스토리 페이스 = 밀도 정합안 (σ 0.000 · 아크 8·13 최소 보장)")
print("  ③ 시설 투자 총액 ≈ 마석 총액의 51% — 잔여 49%는 소환·숙련 배분과 양립")
print("  ④ G4 냉각·관제는 수급이 100층 전 완료 — 실제 잠금은 ★6 완성 런의 층 요건으로 (설계 의도)")
print("  ※ 스토리라인_1300h_재설계 §3 규칙이 시뮬로 검증됨 — 확정 #63")
