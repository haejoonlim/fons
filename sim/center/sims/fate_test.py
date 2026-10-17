#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fate_test.py — 운명 7단계 체계 (05 §4 Part B v3 · 12차 재설계 · 2026-09-17) 균형 검증
**채택 확정 (2026-09-17 사용자 승인)** — gacha_test.py 반영 완료 (FATE_TIERS·roll_fate).
이 파일은 검증 기록 보존용으로 유지한다.

운명 7단계 (3단 각인/소질/무관의 확장 — "왜 3단만이냐" 문제 해결):
  1. 천명  3%  ×3.0 — 타고난 신의 선택. 카드 골드 각인 표시
  2. 각인 12%  ×2.0 — 혈통에 새겨진 천직
  3. 재능 20%  ×1.7 — 타고난 소천부
  4. 소질 25%  ×1.4 — 길러지면 쓸만함
  5. 숙명 20%  ×1.0 — 이 라인이 아니어도 이 계열에서 큰다 (기본 계열 보정)
  6. 개화 12%  ×0.6 — 다른 라인에서 빛난다 (반전 운명)
  7. 무명  8%  ×0.3 — 이 몸은 아무것도 타고나지 못했다
합계 100% · 순서대로 누적 판정 · 전 단계 카드 표시(무명 제외).

기대 평균 배율 = 3%×3.0 + 12%×2.0 + 20%×1.7 + 25%×1.4 + 20%×1.0 + 12%×0.6 + 8%×0.3
             = 0.09 + 0.24 + 0.34 + 0.35 + 0.20 + 0.072 + 0.024 = 1.316
→ 전체 희귀직(→L2 분기) 평균 도달율 = 5% × 1.316 = 6.58% (3단안의 6.3%와 동급)
"""

import random
from collections import Counter

import gacha_test as G  # 정본 · 결함 32 (2026-09-30) — 아래 사본 참조에서 전환

# ── gacha_test.py 정밀 롤 규칙 ──────────────────────────────────────────
# ★ 2026-09-30 결함 32 교정 — 이 블록은 원래 gacha_test 의 **사본**이었다.
#   사본은 15종족 / 6계열에 멈췄는데 gacha_test 가 26종 / 7계열로 가면 이 파일은
#   조용히 옛날 게임을 계속 시뮬 했다. 그 상태로 출력된 `종족 격차` 수치가
#   GDD_v8.0_05:238 에 26종짜리 게임의 균형 증거로 인용되고 있었다.
#   사본이 길어지면 어떤 게이트도 그 차이를 보지 못한다 — 지금은 [1.39] 이 본다.
#   그래도 진실원 참조로 바꿔 사본 자체를 없앤다.
G_RACE_MAP = G.RACE_MAP          # 7계열 26종 (원본은 6계열 15종)
G_LINEAGES = G.LINEAGES
G_SHAPED_LINEAGE_RATE = G.SHAPED_LINEAGE_RATE  # 조형생명 5%

# 계열 가중치는 gacha_test 에 없다 — 그쪽은 계층별 수치를 두지 않고 종족 수 비례로
# 뽑는다(roll_lineage_legacy_uniform). 여기서도 **같은 규칙**을 쓴다.
def _lineage_weights():
    """5%: 조형생명 / 95%: 기존 6계열을 계열 내 종족 수에 비례해 분배."""
    legacy = [k for k in G.LINEAGES if k != '조형생명']
    n = sum(len(G.RACE_MAP[k]) for k in legacy)
    w = {k: (1 - G.SHAPED_LINEAGE_RATE) * len(G.RACE_MAP[k]) / n for k in legacy}
    w['조형생명'] = G.SHAPED_LINEAGE_RATE
    return w


LINEAGE_W = _lineage_weights()
RARE_JOBS = {'전사': '광전사', '심연': '심연술사', '드워프': '광산기사',
             '짐승': '질풍사냥꾼', '인간': '현자', '엘프': '현자',
             '조형생명': '형상술사'}  # 조형생명 분은 2026-09-28 D-276 으로 추가
GRADES = ['★1', '★2', '★3', '★4', '★5']
GRADE_W = (46, 22, 26, 4.5, 0.6)

# ── 운명 7단계 (12차 가안 — 검증 대상) ─────────────────────────────────
FATE_TIERS = list(G.FATE_TIERS)   # 정본 참조 (사본 아님)
RARE_JOB_RATE = 0.05

RACE_FATE = dict(G.RACE_FATE)     # 정본 26종 (사본 15종이었다)


def roll_lineage(rng):
    return rng.choices(list(LINEAGE_W), weights=list(LINEAGE_W.values()), k=1)[0]


def roll_race(rng, lin):
    # gacha_test.RACE_MAP 원소는 (종족, [분파], 해금층) 3-튜플이다 — 첫 칸이 종족명.
    return rng.choice(G_RACE_MAP[lin])[0]


def roll_grade(rng):
    x, acc = rng.random() * sum(GRADE_W), 0.0
    for g, w in zip(GRADES, GRADE_W):
        acc += w
        if x < acc:
            return g
    return '★1'


def roll_fate(rng):
    fx = rng.random()
    acc = 0.0
    for name, prob, mul in FATE_TIERS:
        acc += prob
        if fx < acc:
            return name, mul
    return '무명', 0.3


def simulate(n, seed):
    rng = random.Random(seed)
    counts = Counter()
    tier_stats = {}      # 운명 → [n, rare]
    race_stats = {}      # 종족|운명 → [n, rare]
    grade_by_tier = {}   # 운명 → Counter(등급)

    for _ in range(n):
        lin = roll_lineage(rng)
        race = roll_race(rng, lin)
        grade = roll_grade(rng)
        fate, mul = roll_fate(rng)
        counts['fate_' + fate] += 1
        counts['grade_' + grade] += 1
        counts['total'] += 1
        t = tier_stats.setdefault(fate, [0, 0])
        t[0] += 1
        r = lin in RARE_JOBS and rng.random() < RARE_JOB_RATE * mul
        t[1] += r
        counts['rare_total'] += r
        rs = race_stats.setdefault(f'{race}|{fate}', [0, 0])
        rs[0] += 1
        rs[1] += r
        grade_by_tier.setdefault(fate, Counter())[grade] += 1
    return counts, tier_stats, race_stats, grade_by_tier


def report():
    print('=' * 66)
    print('운명 7단계 (Part B v3) 균형 검증 — fate_test.py 12차')
    print('  천명3×3.0 · 각인12×2.0 · 재능20×1.7 · 소질25×1.4 · 숙명20×1.0 · 개화12×0.6 · 무명8×0.3')
    print('  기대 평균 배율 1.316 → 전체 도달율 6.58% (3단안 6.3%와 동급)')
    print(f'  ※ gacha_test.py 정본 참조 — 계열 {len(LINEAGE_W)} · 종족 '
          f'{sum(len(v) for v in G_RACE_MAP.values())} (2026-09-30 결함 32 교정)')
    print('=' * 66)

    N = 30000
    for seed in (20260917, 424242):
        counts, tier_stats, race_stats, grade_by_tier = simulate(N, seed)
        total = counts['total']
        print(f'\n── 시드 {seed} · n={N:,} ──')

        # ① 분포 검증
        for name, prob, _ in FATE_TIERS:
            got = counts[f'fate_{name}'] / total
            print(f'  {name}: {got:.2%} (설정 {prob:.0%})  {"✓" if abs(got - prob) < 0.01 else "✗"}')

        # ② 배율 추종
        print('\n  ② 희귀직 도달율 — 운명 단계별:')
        for name, prob, mul in FATE_TIERS:
            n_, r_ = tier_stats[name]
            rate = r_ / n_ if n_ else 0.0
            target = RARE_JOB_RATE * mul
            line = f'    {name}: {rate:.3%} (목표 {target:.2%})  n={n_:,}'
            if mul != 1.0:
                line += f'  · 추종 {rate / target:.2f}×'
            print(line)
        avg = counts['rare_total'] / total
        print(f'    전체 평균: {avg:.3%} (기대 6.58%)  · 추종 {avg / (RARE_JOB_RATE * 1.316):.2f}×')

        # ③ 종족 격차
        per_race = {}
        for key, (n_, r_) in race_stats.items():
            race = key.split('|')[0]
            a, b = per_race.get(race, (0, 0))
            per_race[race] = (a + n_, b + r_)
        # ★ 표본 최소 500 (2026-09-30 · 결함 32 교정 후 드러남)
        #   종족이 15→26, 조형생명 계열이 5%로 들어오면서 가장 드문 종족(룬인형족)의
        #   표본이 30k 기준 약 250건까지 내려갔다. 임계 200 은 이 표본을 통과시켜
        #   변동 ±15% 를 '균형' 처럼 보여줬고, 시드 424242 에서 격차 2.06× 를 만들어
        #   '✗ 과도' 로 튀었다. 500 미만은 TOP/BOTTOM 과 격차 계산에서 **제외**한다.
        #   (제외된 종족은 아래에 명시해 조용히 사라지지 않게 한다.)
        MIN_N = 500
        rows = sorted(((r, b / a) for r, (a, b) in per_race.items() if a >= MIN_N),
                      key=lambda t: -t[1])
        thin = sorted((r, a) for r, (a, _b) in per_race.items() if a < MIN_N)
        print(f'\n  ③ 종족별 도달율 TOP3 / BOTTOM3 (평균 {avg:.2%} · '
              f'표본 ≥{MIN_N} 인 {len(rows)}/{len(per_race)}종):')
        for r, rt in rows[:3]:
            print(f'    {r:6s} {rt:.3%}')
        print('    …')
        for r, rt in rows[-3:]:
            print(f'    {r:6s} {rt:.3%}')
        gap = rows[0][1] / rows[-1][1]
        print(f'    최대 격차: {gap:.2f}× ({"✓ 2배 이하" if gap < 2.0 else "✗ 과도"})')
        if thin:
            print(f'    (표본 {MIN_N} 미만이라 격차 계산에서 뺀 종족: '
                  + " ".join(f"{r}({a:,})" for r, a in thin) + ")")

        # ④ 운명 ↔ 등급 독립성
        s5_all = counts['grade_★5'] / total
        print('\n  ④ ★5 비율 — 운명 단계별 (독립이면 유사해야 함):')
        ok = True
        for name, prob, _ in FATE_TIERS:
            gc = grade_by_tier.get(name, Counter())
            gsum = sum(gc.values())
            if gsum < 50:
                continue
            s5 = gc['★5'] / gsum
            mark = '✓' if abs(s5 - s5_all) < 0.008 else '✗'
            ok = ok and abs(s5 - s5_all) < 0.008
            print(f'    {name}: {s5:.2%} (전체 {s5_all:.2%}) {mark}')
        if ok:
            print('    → 독립성 유지 ✓ (운명 표시가 등급 롤을 왜곡하지 않음)')

    print('\n' + '─' * 66)
    print('  3단안 대비 개선점:')
    print('   · 단계 이름이 게임적 직관을 갖는다 (무관→무명·개화·천명)')
    print('   · 개화(반전)·무명(하한)으로 희소 양단이 더 뚜렷해진다')
    print('   · 평균 배율 1.316 — 기존 3단안(1.26)과 유사해 밸런스 연속성 유지')
    print('  → 채택 확정 (2026-09-17) — §4 운명 조항 7단계 전환 + gacha_test.py 반영 완료')


if __name__ == '__main__':
    report()
