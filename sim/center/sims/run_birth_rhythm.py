#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
run_birth_rhythm.py — 신생아·가족 연출 리듬 실측 (D-258 · 스크래치 · 문서 무변경)

질문:
  1) S1 침상 포화 구간에서 신생아 연출이 얼마나 자주 막히는가?
  2) 차단은 실제로 어느 층·몇 섬일 동안 발생하는가?

모델 (전부 04 §3.1·§3.2 + estate.json 정본):
  - 시작 인구 30 (배치 5 + 일반 25) · 자연증가 = 인구×2%/섬 하루 (복리 · estate.json 0.02)
  - 침상 = 주택 1동당 20 (가안) · 시작 주택 3동 = 60침상 (04 §3.2)
  - 유효 상한 = min(스테이지 상한, 침상수) · 자연증가(=신생아 연출)는 빈 침상 있을 때만
  - 스테이지 상한 60/150/400/1300 (S1/S2/S3/S4) · 경계 12/30/50층 (§3.8 · s2_floor=12 D-251)
  - 페이스 = §3.13 기준 (F1-10 ×3.0 · F11-25 ×2.5 · F26-80 ×2.0 · F81-100 ×1.5)

시나리오:
  H0 주택 증축 없음 (침상 60 고정)
  H1 단계 상한 추격 증축 (침상 = 스테이지 상한 유지 — 비용 무시 가안)
  H2 절충 (S2 진입 시 +2동·S3 진입 시 +13동 — 70/220침상)
"""
import math

GROWTH = 0.02
BEDS_PER_HOUSE = 20
STAGE_CAP = [(1, 11, 60), (12, 29, 150), (30, 49, 400), (50, 100, 1300)]
PACE = [(1, 10, 3.0), (11, 25, 2.5), (26, 80, 2.0), (81, 100, 1.5)]

def stage_cap(f):
    for lo, hi, c in STAGE_CAP:
        if lo <= f <= hi:
            return c
    return 1300

def floors_per_day(f):
    for lo, hi, p in PACE:
        if lo <= f <= hi:
            return p
    return 1.5

def run(beds_fn, label):
    """beds_fn(f, pop) -> 침상수. 일 단위 적분 — 100층(≈50섬일) 와주."""
    pop = 30.0
    frac = 0.0            # 미달 신생아 누적 (연출은 정수 발생 시)
    f = 1.0
    day = 0.0
    blocked_days = 0
    block_start = None
    blocks = []           # (시작 층, 끝 층, 섬일 수)
    births = 0.0
    s1_blocked = 0
    trace = []
    while f <= 100:
        day += 1
        fpd = floors_per_day(int(f))
        beds = beds_fn(int(math.ceil(f)), pop)
        cap = min(stage_cap(int(math.ceil(f))), beds)
        if pop < cap:
            g = pop * GROWTH
            frac += g
            births += g
            whole = int(frac)
            if whole > 0:
                frac -= whole
                trace.append(whole)
            pop += g
        else:
            blocked_days += 1
            if block_start is None:
                block_start = int(math.ceil(f))
            if int(math.ceil(f)) <= 11:
                s1_blocked += 1
        # 구간 종료 감지 (층 경계에서 블록 마감)
        nxt = f + fpd
        if int(math.ceil(nxt)) != int(math.ceil(f)) and block_start is not None:
            blocks.append((block_start, int(math.ceil(f)), day))
            block_start = None
        f = nxt
    if block_start is not None:
        blocks.append((block_start, 100, day))
    end_pop = pop
    return dict(label=label, end_pop=end_pop, blocked_days=blocked_days,
                s1_blocked=s1_blocked, blocks=blocks, births=int(births), trace=trace)

h0 = run(lambda f, p: 60, "H0 증축 없음 (침상 60 고정)")
h1 = run(lambda f, p: stage_cap(f), "H1 상한 추격 증축")
h2 = run(lambda f, p: 70 if f >= 12 else 60 if f < 12 else (220 if f >= 30 else 70),
         "H2 절충 (S2 +2동·S3 +13동)")

print("=" * 78)
print("신생아·가족 연출 리듬 실측 — 자연증가 2%/섬일 · 침상 20/동 · 페이스 §3.13")
print("=" * 78)
for r in (h0, h1, h2):
    print(f"\n[{r['label']}]")
    print(f"  종료 인구(50섬일)     : {r['end_pop']:.0f}")
    print(f"  신생아 총 연출 횟수   : {r['births']}회 (런 전체)")
    print(f"  신생아 차단 섬일      : {r['blocked_days']}일 / 50일 ({r['blocked_days']*2}%)")
    print(f"  S1(1~11층) 차단 섬일  : {r['s1_blocked']}일")
    for s, e, d in r['blocks']:
        print(f"    차단 구간: {s}~{e}층")

# S1 시점 인구 상세
print("\n" + "-" * 78)
print("S1 시점별 인구 (H0 기준 — 증축 무관, S1에선 상한 미도달)")
pop = 30.0
f = 1.0
day = 0
marks = {}
while f <= 100:
    day += 1
    if pop < min(stage_cap(int(math.ceil(f))), 60):
        pop *= 1 + GROWTH
    marks[int(math.ceil(f))] = (day, pop)
    f += floors_per_day(int(f))
for fl in (1, 5, 10, 11, 12, 15, 20, 30, 50, 70, 89, 100):
    if fl in marks:
        d, p = marks[fl]
        print(f"  {fl:>3}층 (day {d:>2}): 인구 {p:.1f}")
print(f"\n  → 상한 60 도달 시점: day {next(d for d in range(1, 200) if 30*(1.02**d) >= 60)} "
      f"(= 인구 30×1.02^d ≥ 60 해) · baseline 페이스 기준 약 {(10 + (35.0-3.33)*2.5):.0f}층 부근 = S3 말")
