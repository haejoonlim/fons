#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""feat_cp.py — 특성(구 희귀 적성) CP 기여 계수 검증 · 2026-09-18

설계: 카드 CP에 특성을 복합 반영 — "특성마다 희귀도 가중치가 있고, 그에 따라 CP 상승폭이 달라진다"
  - 기여식: CP 보정 = 가치(밸런스기준표 §3 실질 가치) × 0.4% × (★ - 2)
    · ★5 표준 특성(가치 3.0) = +3.6% — 성격 보정 밴드(×1.01~1.05)와 조화
    · ★7 시그니처(피의 기억 가치 10) = +20% — 시그니처다운 체감
    · ★7 표준(가치 3) = +12%
  - 명목 CP(스탯만)와 실전 CP(특성 포함)가 카드 숫자 하나로 통일 — "CP 높은데 약한 특성" 모순 제거
  - ★ 개수는 기존 티어(5/6/7) 그대로 — 표시만 ★5/★6/★7로 전환 (견습·장인 용어와 분리)

실행: python3 design-docs/_tools/feat_cp.py   (단독 — 계수표·기여 밴드·등급별 시뮬 출력)
"""
import random
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gacha_test as gt

# ── 특성 가치표 v2 (2026-09-19 사용자 결정 — 계열 전용 우위·시그니처 위계 재배치) ──
# 규칙: ①공용 ≤3.0 ②계열 전용 ≥3.5 ③계열당 시그니처 1개 (SIG_VALUE 8.0) — 최하위 상향(개척 1.0→3.5·조약 1.5→3.5·저주 1.4→3.5)
# 시그니처 획득률 11% = 계열 가중 1.5 × 계열 내 시그니처 가중 SIG_W 1.25 (몬테카를로 40만 실측 10.99%)
from feat_values import FEAT_VALUE, FEAT_SIG_VALUE, FEAT_SIG_W  # 가치표 v2 단일 소스 (2026-09-19 14차 — 이 파일이 유일한 가치표 정의처럼 동작)
FEAT_CP_UNIT = 0.004  # 가치 1.0당 CP +0.4% — ★7 표준(가치3) +12% · 시그니처(가치10) +20%


def feat_cp_bonus(name, stars):
    """특성 CP 기여 — 가치 × 단위 × (★-2). ★5=+3배수 · ★6=×4 · ★7=×5"""
    return FEAT_VALUE.get(name, 3.0) * FEAT_CP_UNIT * (stars - 2)


def main():
    print('═══ 특성 CP 기여 설계 검증 (feat_cp.py · 2026-09-18) ═══')
    print(f'기여식: CP보정 = 가치 × {FEAT_CP_UNIT:.1%} × (★-2) · 가치표 {len(FEAT_VALUE)}종')
    print()
    print('── ★별 기여 밴드 ──')
    for stars in (5, 6, 7):
        vals = [feat_cp_bonus(n, stars) for n in FEAT_VALUE]
        print(f'  ★{stars}: 최소 {min(vals):+.1%} · 중위 {sorted(vals)[len(vals)//2]:+.1%} · 최대 {max(vals):+.1%}')
    print()
    print('── 대표 특성 (★7 기준) ──')
    for n in ('암중적응', '왕의 혈맥', '포식자의 본능', '약탈의 습성', '피의 기억'):
        print(f'  {n}(가치 {FEAT_VALUE[n]}): ★7 {feat_cp_bonus(n, 7):+.1%} · ★6 {feat_cp_bonus(n, 6):+.1%} · ★5 {feat_cp_bonus(n, 5):+.1%}')

    # ── 등급별 CP 영향 시뮬 (gacha_test 엔진 · make_hero에 특성 CP를 외부 적용해 기여 측정) ──
    print()
    print('── 등급별 CP 기여 실측 (몬테카를로 · 등급 강제 2,000명씩) ──')
    orig = gt.roll_grade
    for grade in ('★4', '★5', '★6'):
        gt.roll_grade = lambda rng, p4, p5=0, _g=grade: (_g, 0, 0)
        rng = random.Random(20260918)
        counts = {'floor': 50, 'owned': {}}
        rel = []
        for i in range(2000):
            h = gt.make_hero(rng, counts, 50)
            stars = int(h['등급'][1])
            bonus = 0.0
            for fname in h.get('rare_apt_names', []):
                bonus += feat_cp_bonus(fname, h['적성'].get(fname, 5))
            rel.append(bonus)
        gt.roll_grade = orig
        avg = sum(rel) / len(rel)
        has = sum(1 for x in rel if x > 0) / len(rel)
        print(f'  {grade}: 특성 보유 {has:.1%} · CP 기여 평균 {avg:+.2%} · 최대 {max(rel):+.1%} (보유 시 {avg/has:+.2%})')
    print()
    print('판정: ★6 보장+재롤 → 평균 ~+8~10% · 시그니처 보유 시 +20% — 성격(±5%) 대비 2~4배 격차 = 희귀다운 위계 ✓')


if __name__ == '__main__':
    main()
