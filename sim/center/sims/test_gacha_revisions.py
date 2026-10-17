#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
test_gacha_revisions.py — 5대 개정 자동 검증 (pytest 스타일 · 2026-09-18)

정본 gacha.html의 "5대 개정 검증 시뮬" 버튼(2026-09-18)과 동일 계약을 gacha_test.py 엔진으로 수행:
  ① 등급별 희귀 적성 트리거 (★3 3% · ★4 7% · ★5 13% · ★6 보장 100% — 확정 #38)
  ② ★6 이중 특권 — 보장 희귀 티어 하한 장인(6): 숙련 0% · 장인 20%/명장 80%
  ③ 계열 전용 49종 가중 1.5 — 차지율 63.6% (±3%p), shaped 7종 데이터 전용
  ③b shaped 5% 소환 + legacy 20종 균등, 시작 풀 legacy-only, shaped 등급별 이름 풀 완비
  ④ MYTH∩DIVINE 원형 풀 상호배타 — 겹침 0건 (정적)
  ⑤ 몰입 등급별 가중 (0/1.5/2/3 — 명장 티어 곡선 정합 · 2026-09-18 D1)

실행:
  pytest 스타일:  pytest design-docs/_tools/test_gacha_revisions.py -q
  단독(check_docs): python3 design-docs/_tools/test_gacha_revisions.py [--quick]

  --quick : 표본 절반(통과 임계 동일 — CI 용 · check_docs 60초 예산 내)
  시드 고정 — FAIL 재현 가능. 밴드는 시드 변동 여유를 포함한 상하한 계약(문서 기대치 ± 여유).

반영 리비전: GDD 05 §6 8차 · §6-1-2 · §5 4차(D1) · §8 · 00 확정 #38
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gacha_test as gt
from gacha_test import (COMMON_RARE_APT, LINEAGE_RARE, RARE_APT_LIN_W,
                        RARE_APT_RATE_BY_GRADE, RARE_APT_BONUS_RATE)

FLOOR = 50
N = 1200 if '--quick' in sys.argv else 2400        # 등급별 표본 (★6 보장 판정용)
PERS_N = 6000                                       # 몰입 표본 (등급별)
SEED = 20260918                                     # gacha.html v5 시뮬 계열과 독립 — 파이썬 RNG 전용 시드

# 캐시 — 모듈 수준 1회 산출 (pytest로 개별 테스트 실행해도 재계산 없음)
_CACHE = {}


def _forced_grade_heroes(grade):
    """roll_grade를 강제 스텁해 특정 등급만 대량 생성 — (heroes, 원복)"""
    key = ('heroes', grade)
    if key in _CACHE:
        return _CACHE[key]
    orig = gt.roll_grade
    gt.roll_grade = lambda rng, p4, p5=0: (grade, 0, 0)
    try:
        rng = random.Random(SEED)
        counts = {'floor': FLOOR, 'owned': {}}
        heroes = []
        for i in range(N):
            if i % 10 == 0:
                counts['exclude_pers'] = set()
            heroes.append(gt.make_hero(rng, counts, FLOOR))
    finally:
        gt.roll_grade = orig
    _CACHE[key] = heroes
    return heroes


def _rare_names(hero):
    """영웅이 보유한 희귀 적성 (이름 → 계열 전용 여부 판정 포함)"""
    lin_set = set(LINEAGE_RARE[hero['계열']])
    return [(k, k in lin_set, v) for k, v in hero['적성'].items()
            if k in lin_set or k in COMMON_RARE_APT]


# ── ① 등급별 희귀 트리거 ──────────────────────────────────────────────
def test_rare_trigger_by_grade():
    """① 확정 #38 — 등급별 트리거 실측이 밴드 내 (재롤 유입으로 기대치 상단 여유)"""
    # 밴드 계약 — 트리거 3/7/13% + 재롤 밴드 + 희귀분기 롤 누적 기대 중심 ★4 ~10% · ★5 ~14.7%.
    # 재롤·분기가 rng 스트림에 섞여 시드간 편차가 이항보다 큼 (5시드 실측 ★4 9.2~12.2% · 평균 10.2%) → 상단 여유.
    bands = {'★3': (0.02, 0.06), '★4': (0.06, 0.14), '★5': (0.11, 0.19)}
    for grade, (lo, hi) in bands.items():
        heroes = _forced_grade_heroes(grade)
        rate = sum(1 for h in heroes if h.get('rare_apt')) / len(heroes)
        assert lo <= rate <= hi, \
            f"{grade} 희귀 보유율 {rate:.3f} — 밴드 [{lo},{hi}] 이탈 (기대 {RARE_APT_RATE_BY_GRADE[int(grade[1])]})"


def test_star6_guarantee():
    """① 확정 #38 — ★6은 트리거 롤 없이 특성 1개 보장 (100%) — 구칭 희귀 적성"""
    heroes = _forced_grade_heroes('★6')
    misses = [h['이름'] for h in heroes if not h.get('rare_apt')]
    assert not misses, f"★6 희귀 미보유 {len(misses)}/{len(heroes)} — 1차 특권 붕괴: {misses[:3]}"


def test_star6_second_rare_within_cap():
    """① 확정 #38 — ★6 두 번째·세 번째 희귀는 트리거(26%)·보너스(3%) 경로만 — 평균 1.0~1.6 · 3개율 <2% (이론 ≈0.8%)
    (gacha.html과 동일 구조 — 보장+트리거+보너스가 독립 판정이라 3개도 가능 · 상한 코드 없음)"""
    heroes = _forced_grade_heroes('★6')
    counts = [len(_rare_names(h)) for h in heroes]
    avg = sum(counts) / len(counts)
    three = sum(1 for c in counts if c >= 3)
    assert max(counts) <= 3, f"희귀 4개 보유 영웅 발생 — 경로 상한(보장+트리거+보너스) 위반"
    assert three / len(counts) < 0.02, f"★6 희귀 3개율 {three/len(counts)*100:.2f}% — 이론 ≈0.8% 이탈"
    assert 1.0 <= avg <= 1.6, f"★6 평균 희귀 {avg:.2f}개 — 기대 1.29 (보장+재롤) 이탈"


# ── ② ★6 티어 하한 ───────────────────────────────────────────────────
def test_star6_rare_tier_floor():
    """② 확정 #38 2차 특권 — ★6 보장 희귀 티어: 숙련(5) 0% · 장인 20%±10 · 명장 나머지
    (보장 1개 = rare_apt 필드 — 추가 트리거·보너스분은 일반 롤 45/35/20이 정상이라 제외)"""
    heroes = _forced_grade_heroes('★6')
    tiers = {}
    for h in heroes:
        first = h['rare_apt_names'][0]  # 보장분 = 배열 첫 원소 (트리거·보너스는 이후 덮어쓰지 않음)
        tiers[h['적성'][first]] = tiers.get(h['적성'][first], 0) + 1
    total = sum(tiers.values())
    assert tiers.get(5, 0) == 0, f"★6 보장 희귀에 숙련(5) {tiers.get(5)}건 — 하한 장인 위반"
    craftsman = tiers.get(6, 0) / total
    assert 0.10 <= craftsman <= 0.30, \
        f"★6 보장 티어 장인 비율 {craftsman:.2f} — 기대 0.20 (80/20 롤) 이탈"


# ── ③ 계열 전용 49종 가중 ────────────────────────────────────────────
def test_lineage_rare_share():
    """③ §6-1-2 — 전용 특성 49종 중 소유 계열 특성 차지 63.6% ±3%p (가중 1.0 vs 1.5)"""
    lin = com = 0
    for grade in ('★4', '★6'):   # ★4(트리거+재롤) · ★6(보장+재롤) — 경로 혼합 표본
        for h in _forced_grade_heroes(grade):
            for _, is_lin, _v in _rare_names(h):
                if is_lin:
                    lin += 1
                else:
                    com += 1
    share = lin / (lin + com)
    assert abs(share - 0.636) <= 0.03, \
        f"계열 전용 차지 {share:.3f} — 이론 0.636 ±0.03 이탈 (lin {lin} vs common {com})"


def test_lineage_rare_belongs_to_own_lineage():
    """③ §6-1-2 — 희귀 적성은 항상 공용 6 또는 '자기 계열' 전용 7에서만 나온다"""
    for grade in ('★4', '★6'):
        for h in _forced_grade_heroes(grade):
            own = set(LINEAGE_RARE[h['계열']])
            for name, is_lin, _v in _rare_names(h):
                assert (not is_lin) or name in own, \
                    f"타 계열 전용 희귀 누출: {name} on {h['계열']} ({h['이름']})"


# ── ③b shaped 소환률 및 legacy 종족 균등 ───────────────────────────────
def test_shaped_summon_rate_and_legacy_race_uniformity():
    """D-276 — 전체 소환 shaped 5%, 나머지 95%는 기존 20 race 각각 균등."""
    rng = random.Random(SEED + 276)
    counts = {'floor': FLOOR, 'owned': {}}
    shaped = 0
    race_counts = {}
    for _ in range(100_000):
        lineage, race, _branches = gt.select_race_for_summon(rng, counts)
        if lineage == '조형생명':
            shaped += 1
        else:
            race_counts[race] = race_counts.get(race, 0) + 1
    rate = shaped / 100_000
    assert abs(rate - 0.05) <= 0.003, f"shaped 소환 비율 {rate:.4%} — 5% ±0.3%p 이탈"
    assert len(race_counts) == 20, f"legacy race 종류 {len(race_counts)} — 20개여야 함"
    for race, count in race_counts.items():
        share = count / 100_000
        assert abs(share - 0.0475) <= 0.002, \
            f"legacy {race} 전체 소환 비율 {share:.3%} — 4.75% ±0.2%p 이탈"


def test_shaped_grade_name_pools_are_complete():
    """★5/★6/★7 이름 풀에 shaped 항목이 있고 기존 공통 등급 경로를 탄다."""
    # 폰즈 이관: gacha.html 은 sims/ 가 아니라 pages/(서버 루트)에 있다.
    html_path = os.path.join(os.path.dirname(os.path.abspath(gt.__file__)), '..', 'pages', 'gacha.html')
    with open(html_path, encoding='utf-8') as source_file:
        html = source_file.read()
    assert "'조형생명': ['석결','벽토','열맥','수정','각인']" in html
    assert "'조형생명': ['깨어난 형상','새겨진 의지','각성핵의 후계자'" in html
    assert "'조형생명': ['메이커','프로메테우스','탈로스','골렘의 왕'" in html
    assert "'조형생명': '초월한 완성형'" in html
    assert "const pool = DIVINE[lin]||MYTH[lin];" in html
    assert "let base = modMythElevated(MYTH[lin][rng.int(MYTH[lin].length)], rng);" in html


def test_shaped_traits_are_data_only_and_not_signatures():
    """D-276 — exactly seven 3.5-value shaped traits, none at signature value."""
    shaped_traits = {
        '층리 감각', '절벽 고정', '유연한 외피', '열제련', '핵 공명', '굴절막', '각인 기억'
    }
    assert set(gt.LINEAGE_RARE['조형생명']) == shaped_traits
    assert all(gt._FV[name] == 3.5 for name in shaped_traits)
    assert all(gt._FV[name] < gt.FEAT_SIG_VALUE for name in shaped_traits)


def test_starting_hero_pool_excludes_shaped():
    """D-276 — 신규 런 시작 영웅은 legacy pool에서만 종족을 선택한다."""
    rng = random.Random(SEED + 277)
    seen = set()
    for _ in range(10_000):
        lineage, race, _branches = gt.select_race_for_start(rng)
        assert lineage != '조형생명', f"시작 영웅에 shaped 종족 누출: {race}"
        seen.add(race)
    assert len(seen) == 20, f"시작 legacy 종족 다양성 {len(seen)} — 20개여야 함"


# ── ④ 원형 풀 상호배타 (정적 · 비용 0) ────────────────────────────────
# 폰즈 이관: 소환제단 정본(gacha.html)은 pages/ 에 있다 — 시뮬 폴더가 아니라 서버 루트다.
_GACHA_HTML = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'pages', 'gacha.html')


def _load_name_pools():
    """정본 gacha.html의 MYTH·DIVINE 풀을 정적 파싱 — 이름 체계의 파이썬 측 정본이 없어 HTML이 단일 소스"""
    key = 'pools'
    if key in _CACHE:
        return _CACHE[key]
    import re
    src = open(_GACHA_HTML, encoding='utf-8').read()
    def grab(const):
        m = re.search(r'const %s = \{(.*?)\n\};' % const, src, re.S)
        out = {}
        for lin, arr in re.findall(r"'([^']+)':\s*\[([^\]]+)\]", m.group(1)):
            out[lin] = re.findall(r"'([^']+)'", arr)
        return out
    pools = (grab('MYTH'), grab('DIVINE'))
    _CACHE[key] = pools
    return pools


def test_myth_divine_disjoint():
    """④ §8 — MYTH(★5 신화)와 DIVINE(★6 신격) 원형 풀 겹침 0건 — 페룬·아자젤 재유입 감시
    (이름 생성기는 정본 gacha.html 단일 소스 — 파이썬 테스트는 HTML을 파싱해 대조)"""
    myth, divine = _load_name_pools()
    assert set(myth) == set(divine), f"MYTH·DIVINE 계열 키 불일치: {set(myth) ^ set(divine)}"
    for lin, myths in myth.items():
        overlap = set(myths) & set(divine.get(lin, []))
        assert not overlap, f"{lin} 계열 MYTH∩DIVINE 겹침: {overlap}"
    legacy_divine_count = sum(len(divine[lin]) for lin in gt.LEGACY_LINEAGES)
    shaped_divine_count = len(divine['조형생명'])
    assert legacy_divine_count == 48, \
        f"legacy DIVINE 풀 {legacy_divine_count}종 — 기존 6계열×8신격 규격 이탈"
    assert shaped_divine_count == 8, \
        f"shaped DIVINE 풀 {shaped_divine_count}종 — 조형생명도 공통 ★6 이름 경로에 8신격 필요"
    assert sum(len(v) for v in divine.values()) == 56, \
        f"전체 DIVINE 풀 {sum(len(v) for v in divine.values())}종 — legacy 48 + shaped 8 규격 이탈"


# ── ⑤ 몰입 등급별 가중 ───────────────────────────────────────────────
def _cheonae_rate(grade):
    key = ('cheonae', grade)
    if key in _CACHE:
        return _CACHE[key]
    rng = random.Random(SEED + 13)
    exclude = set()
    hit = 0
    for i in range(PERS_N):
        if i % 10 == 0:
            exclude = set()
        if gt.roll_personality(rng, grade, exclude) == '몰입':
            hit += 1
    rate = hit / PERS_N * 100  # 순수 발생률 (%) — 배치 중복 방지는 exclude 세트로만 작동
    _CACHE[key] = rate
    return rate


def test_cheonae_grade_weights():
    """⑤ D1 — 몰입 실측: ★3 0% · ★4 ~1.5% · ★5 ~2% · ★6 ~3% (등급 간 단조 증가)"""
    r3, r4, r5, r6 = (_cheonae_rate(g) for g in ('★3', '★4', '★5', '★6'))
    assert r3 == 0.0, f"★3 몰입 {r3:.2f}% — 게이트 위반 (0이어야 함)"
    assert 0.8 <= r4 <= 2.4, f"★4 몰입 {r4:.2f}% — 기대 ~1.5% (가중 1.5) 이탈"
    assert 1.2 <= r5 <= 3.0, f"★5 몰입 {r5:.2f}% — 기대 ~2% (가중 2) 이탈"
    assert 2.0 <= r6 <= 4.2, f"★6 몰입 {r6:.2f}% — 기대 ~3% (가중 3) 이탈"
    assert r3 < r4 < r5 < r6, f"몰입 곡선 단조성 위반: {r3:.2f}→{r4:.2f}→{r5:.2f}→{r6:.2f}"


# ── 단독 실행 (pytest 부재 환경 — check_docs 연동 경로) ──────────────
def run_all(quick=False):
    """전체 테스트 수동 실행 — (통과 수, 전체 수, 실패 목록)"""
    global N
    old_n = N
    if quick:
        N = 1200
    tests = [(k, v) for k, v in sorted(globals().items()) if k.startswith('test_') and callable(v)]
    passed, failures = 0, []
    for name, fn in tests:
        try:
            fn()
            passed += 1
        except AssertionError as ex:
            failures.append(f"{name}: {ex}")
    N = old_n
    return passed, len(tests), failures


if __name__ == '__main__':
    quick = '--quick' in sys.argv
    passed, total, failures = run_all(quick=quick)
    mode = 'QUICK' if quick else 'FULL'
    print(f"[5대 개정 검증 {mode}] {passed}/{total} PASS — gacha_test.py 엔진 · 시드 {SEED}")
    for f in failures:
        print(f"  FAIL {f}")
    raise SystemExit(0 if not failures else 1)
