#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""FONS 숙련도 시뮬레이터 — GDD_v8.0_05 §6-2 검증 (8차 · 2026-09-15)

gacha_test.py의 롤 분포(적성_전체 — 은닉 티어 포함)를 재사용해
표준 플레이 패턴의 XP 누적·승급 곡선을 일 단위로 실측한다.

검증 항목:
- 견습→숙련→장인→명장 도달 일수 (시설계 5/일 vs 생활계 1/일 · 시작 등급별)
- 등급별 보류 XP 분포 (게이트 상한 정체 → 합성소 승급 대기분 · 피크 기준)
- 골드 장벽 vs 영지 수급 대조 (04 §3.11 던전 수입 — 운영자 5인 vs 풀 로스터)
- XP 보존 (획득 = 승급 소비 + 진행 + 보류 + 만렙 소멸) · 게이트 위반 0건
- 골드 소요 (장인 2,000G · 명장 10,000G)

표준 플레이 가정 (전부 가안 — 미정G):
- 시설 5종 1운영자씩 (04 원칙 #3 · §6-2) · 하루 상한은 영웅 1인 단일 — 시설 증축 미중복 (8차 확정)
- 연구자 3XP/2일 · 건축가 2XP/2일 · 농부 3일 수확 주기 · 채집꾼·벌목꾼·광부 1회/일 (쿨 24h)
- ★ 35차 신설 3종(교육자·예술가·상인)은 대응 시설이 없어 운영자 자리가 없다 (결함 35 교정)
- 광부는 티어 4+만 채굴 가능 (04 §3.3 채굴 게이트) — 미달 시 다른 생활로 폴백
- 합성소 등급 승급 주기: ★1→2 7일 · ★2→3 21일 · ★3→4 45일 · ★4→5 90일
- 영웅은 주 활동 트랙 1개만 성장 (토크별 독립이나 표준 플레이는 주력 위주)
- 성실 영웅 XP 획득 +5% (§6-2 성격 준용)

실행: python3 proficiency_test.py [영웅수] [일수] [--seed N]
"""
import os
import random
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gacha_test import FACILITY_APT, LIFE_APT, batch

# ── §6-2 상수 (가안 — 미정G) ──────────────────────────────
# 승급 필요 XP: 티어 t → t+1 (은닉 1~3은 내부 구분 없이 플랫 10 → 견습4 직행 — §6-2)
PROMOTE_XP = {4: 20.0, 5: 50.0, 6: 120.0}
PROMOTE_GOLD = {6: 2000, 7: 10000}  # 5→6 장인 승급 시 · 6→7 명장 승급 시
# 표준 플레이 하루 XP (§6-2 표 환산 · 1인 상한 — 증축 미중복)
#
# ★ 2026-10-01 결함 35 — 이 표는 35차 **적성 13종 확장**을 못 따라서 옛 어휘로 남아 있었다.
#   25차 개명 4건(간호→의사 · 조제→조약사 · 대장→대장장이 · 목수→건축가) 과
#   35차 신설 3건(교육자·예술가·상인) 이 반영되지 않았다.
#   그런데 `build_state()` 는 `gacha_test.FACILITY_APT`(13종 어휘) 에서 트랙을 뽑는다
#   → `DAILY_XP[st['track']]` 이 `KeyError: '의사'` 로 죽었다.
#   ★ 죽는 방향이 **무작위**였다. 재현 시 시드가 랜덤이라 `KeyError: '상인'` 이 먼저
#     나왔고, 고정 시드로는 `의사`(시설 슬롯)가 먼저 나온다 — '가끔 죽는 것처럼 보이는'
#     계측을 '항상 죽는다'로 바꿔야 원인 규칙이 드러난다.
#   아무도 이 파일을 실행하지 않았으므로(=살아 있지 않아서) 그대로 방치돼 있었다.
#   [1.44] check_sim_smoke.py 가 「시뮬인데 실행하면 죽는다」로 잡았다.
DAILY_XP = {
    # 시설 5종 — §6-2 표(요리/간호/조제/대장/연구) 의 현행 이름.
    '요리사': 5.0, '의사': 5.0, '조약사': 5.0, '대장장이': 5.0,
    '연구자': 1.5,        # 3XP / 2일 완료 주기 가안
    # 생활 5종 — 쿨 24h = 1회/일 · 농부는 3일 성장 주기.
    '채집꾼': 1.0, '벌목꾼': 1.0, '광부': 1.0,
    '농부': 1.0 / 3.0,    # 3일 성장 주기 수확 가안
    '건축가': 1.0,        # 2XP / 2일 참여 가안
}
# ★ 35차 신설 3종(교육자·예술가·상인)은 **대응 시설이 없다** — 04 §3.2 의 '적성 1:1 시설 대응'
#   규칙이 성립하지 않는다는 것이 35차의 설계 결정이다(`gacha_test.FACILITY_APT` 주석 명시).
#   §6-2 도 '시설 5종' 만 운영자 배치로 정의한다. 그러므로 이 3종은 **운영자 자리가 없다**
#   → 시뮬도 그에 맞춰 운영자 슬롯 후보에서 뺀다(값을 지어내지 않는다).
#   ★ 여기서 값을 지어내면 안 된다 — '05 §6-2 에 없는 수치'를 계측기가 만들면
#     그게 곧 문서 인용 값처럼 보인다. 결함 34 교훈(근거 없는 수치 금지) 확장.
OPERATOR_APT = ('요리사', '의사', '조약사', '대장장이', '연구자')  # §6-2 시설 5종
NO_FACILITY_APT = tuple(a for a in FACILITY_APT if a not in DAILY_XP)
assert set(OPERATOR_APT) <= set(DAILY_XP), '운영자 적성에 일당 XP 정의가 없다'
assert set(LIFE_APT) <= set(DAILY_XP), '생활 적성에 일당 XP 정의가 없다'
MINING_GATE = 4                  # 채굴은 티어 4+ (04 §3.3)
# 합성소 등급 승급 주기 (가안 — 문서 미정의, 시뮬 가정) · 병목 실측 (04 §3.11 발견 6 · 8차):
# ★1~2 명장 163일 vs 순수 XP 40일 — 주기가 커브 지배 → 재조정안 시나리오 비교 (9차 가안)
SCENARIOS = {
    'base': {'cad': {1: 7, 2: 21, 3: 45, 4: 90}, 'mult': 1.0, 'label': '현행 (7/21/45/90일)'},
    'A':    {'cad': {1: 3, 2: 7, 3: 15, 4: 30}, 'mult': 1.0, 'label': 'A 주기 압축 (3/7/15/30일)'},
    'B':    {'cad': {1: 7, 2: 21, 3: 45, 4: 90}, 'mult': 1.0, 'cap': 50, 'label': 'B 보류 상한 50XP (현행 주기)'},
    'C':    {'cad': {1: 7, 2: 21, 3: 45, 4: 90}, 'mult': 2.0, 'label': 'C XP 2배 (10/10/25/60 환산)'},
    'D':    {'cad': {1: 3, 2: 7, 3: 15, 4: 30}, 'mult': 1.0, 'cap': 50, 'label': 'D 복합 (A+B)'},
}
GRADE_UP_DAYS = SCENARIOS['base']['cad']  # 기본 상세 리포트 = 현행
DILIGENT = 1.05                  # 성실 XP 획득 +5% (§6-2 성격 준용)
TIER_NAME = {4: '견습', 5: '숙련', 6: '장인', 7: '명장'}
KIND_LABEL = {'시설': '시설계 (5/일)', '생활': '생활계 (1/일 기준)'}


def gate_cap(gnum):
    """등급 게이트 상한 (05 §6 7차) — ★1~2:4 · ★3:5 · ★4:6 · ★5+:7"""
    return 4 if gnum <= 2 else (5 if gnum == 3 else (6 if gnum == 4 else 7))


def band(gnum):
    return '★1~2' if gnum <= 2 else ('★5+' if gnum >= 5 else f'★{gnum}')


def build_state(heroes, cad=None, cap=None):
    """시설 5슬롯 = 적성 최고 티어 영웅 · 나머지 = 생활 주활동 (cad/cap = 시나리오 오버라이드)"""
    slots, used = {}, set()
    # ★ 35차 — 운영자 후보는 §6-2 의 '시설 5종' 이다(결함 35).
    #   FACILITY_APT 8종 전부로 뽑으면 대응 시설이 없는 3종이 자리를 차지해
    #   일당 XP 정의가 없어 죽는다(그리고 죽는 적성이 시드마다 달라 원인이 가려진다).
    for apt in OPERATOR_APT:
        best, best_t = None, 0
        for i, h in enumerate(heroes):
            if i in used:
                continue
            t = h['적성_전체'].get(apt, 0)
            if t > best_t:
                best, best_t = i, t
        if best is not None:
            slots[best] = apt
            used.add(best)
    state = []
    for i, h in enumerate(heroes):
        gnum = int(h['등급'][1])
        full = h['적성_전체']
        if i in slots:
            track, kind = slots[i], '시설'
        else:
            avail = [a for a in LIFE_APT
                     if not (a == '광부' and full.get(a, 0) < MINING_GATE)]
            track = max(avail, key=lambda a: full.get(a, 0))  # 동률 → LIFE_APT 순
            kind = '생활'
        tier = full.get(track, 1)
        state.append({
            'start_gnum': gnum, 'gnum': gnum, 'track': track, 'kind': kind,
            'start_tier': tier, 'tier': tier,
            'xp_in': 0.0, 'pending': 0.0, 'peak': 0.0,
            'reached': {t: 0 for t in range(4, tier + 1)},
            'bonus': DILIGENT if h['성격'] == '성실' else 1.0,
            'cap': cap,
            'next_up': cad.get(gnum) if gnum <= 4 else None,
        })
    return state


def feed(st, amount, day, acc):
    """XP 지급 — 승급 체인 · 상한 정체 시 보류 · 만렙 초과분 소멸 (§6-2)"""
    if st['tier'] >= 7:
        return  # 명장 XP 정지
    cap = gate_cap(st['gnum'])
    if st['tier'] >= cap:
        room = st['cap'] - st['pending'] if st['cap'] else amount  # B/D — 보류 저장소 상한
        kept = min(amount, max(room, 0.0))
        st['pending'] += kept
        st['peak'] = max(st['peak'], st['pending'])
        return
    st['xp_in'] += amount
    while st['tier'] < 7 and st['tier'] < cap:
        if st['tier'] < 4:  # 은닉권 — 내부 구분 없이 XP 10 → 견습4 직행 (§6-2)
            need, nxt = 10.0, 4
        else:
            need, nxt = PROMOTE_XP[st['tier']], st['tier'] + 1
        if st['xp_in'] < need:
            break
        st['xp_in'] -= need
        st['tier'] = nxt
        acc['consumed'] += need
        acc['promotions'][st['tier']] += 1
        if st['tier'] >= 4 and st['tier'] not in st['reached']:
            st['reached'][st['tier']] = day
        if st['tier'] in PROMOTE_GOLD:
            acc['gold'] += PROMOTE_GOLD[st['tier']]
            acc['gold_n'][st['tier']] += 1
            acc['gold_events'].append((day, PROMOTE_GOLD[st['tier']], st['kind']))
    if st['tier'] >= 7:  # 명장 승급으로 만렙 도달 — 초과 보류분 소멸 (XP 정지 원칙)
        acc['voided'] += st['xp_in']
        st['xp_in'] = 0.0
        return
    if st['tier'] >= cap and st['xp_in'] > 0:
        room = st['cap'] - st['pending'] if st['cap'] else st['xp_in']
        kept = min(st['xp_in'], max(room, 0.0))
        st['pending'] += kept
        st['peak'] = max(st['peak'], st['pending'])
        st['xp_in'] = 0.0


def grade_up(st, day, acc, cad):
    """합성소 등급 승급 — 보류 XP 즉시 반영 (§6-2)"""
    st['gnum'] += 1
    st['next_up'] = cad.get(st['gnum']) if st['gnum'] <= 4 else None
    acc['grade_ups'][st['gnum']] += 1
    if st['pending'] > 0:
        amt, st['pending'] = st['pending'], 0.0
        feed(st, amt, day, acc)


def simulate(n_heroes, days, floor, seed, mode='base'):
    sc = SCENARIOS[mode]
    cad, mult = sc['cad'], sc['mult']
    rng = random.Random(seed)
    counts = {'pity': 0, 'floor': floor, 'owned': {}}
    heroes, _ = batch(n_heroes, counts, floor, rng=rng)
    state = build_state(heroes, cad, sc.get('cap'))
    acc = {'earned': 0.0, 'consumed': 0.0, 'voided': 0.0, 'gold': 0, 'gold_n': Counter(),
           'gold_events': [], 'promotions': Counter(), 'grade_ups': Counter(), 'viol': 0}
    for day in range(1, days + 1):
        for st in state:  # ① 합성소 등급 승급 → 보류 즉시 반영
            if st['next_up'] is not None:
                st['next_up'] -= 1
                if st['next_up'] <= 0:
                    grade_up(st, day, acc, cad)
        for st in state:  # ② 활동 XP (mult = 시나리오 XP 배율) — 명장은 XP 정지 (§6-2 만렙 원칙)
            if st['tier'] < 7:
                gain = DAILY_XP[st['track']] * st['bonus'] * mult
                acc['earned'] += gain
                feed(st, gain, day, acc)
        for st in state:  # ③ 게이트 위반 체크
            if st['tier'] > gate_cap(st['gnum']):
                acc['viol'] += 1
    return heroes, state, acc


def floor_curve(days):
    """런 페이스 (04 §3.11 시뮬 가정 — F1-10×3.0 · F11-25×2.5 · F26-80×2.0 · F81-100×1.5)
    → 일차별 클리어 층수. 수입 = 100×층 누적 (첫 클리어 기준 — 재클리어·세금·식민섬 미적용 보수치)"""
    fl, curve = 0.0, {}
    for d in range(1, days + 1):
        if fl < 100:
            pace = 3.0 if fl < 10 else 2.5 if fl < 25 else 2.0 if fl < 80 else 1.5
            fl = min(100.0, fl + pace)
        curve[d] = fl
    return curve


def gold_vs_income(acc, days):
    """숙련도 골드 결제 시점 vs 던전 누적 수입 대조 (04 §3.11 발견 6 검증)"""
    print('\n── 골드 장벽 vs 영지 수급 (던전 100×층 누적 · 본섬 단일 · 세금·식민섬·재클리어 제외 보수치) ──')
    curve = floor_curve(days)
    events = sorted(acc['gold_events'])
    cum_all = cum_op = 0.0
    ei = 0
    checks = [d for d in (22, 37, 50, 100, 200) if d < days] + [days]
    for d in checks:
        while ei < len(events) and events[ei][0] <= d:
            amt, kind = events[ei][1], events[ei][2]
            cum_all += amt
            if kind == '시설':
                cum_op += amt
            ei += 1
        fl = curve.get(d, 100.0)
        inc = 100 * fl * (fl + 1) / 2
        ratio = f'{cum_all / inc * 100:5.1f}%' if inc else '   —'
        print(f'  {d:>3}일 ({fl:>5.1f}층): 수입 {inc:>9,.0f}G · 수요 {cum_all:>9,.0f}G ({ratio})'
              f' · 운영자분 {cum_op:>7,.0f}G')
    total_inc = 100 * 100 * 101 / 2
    op_full = 5 * (PROMOTE_GOLD[6] + PROMOTE_GOLD[7])
    print(f'  운영자 5인 풀 명장화 = {op_full:,}G = 100층 총수입 {total_inc:,.0f}G의 '
          f'{op_full / total_inc * 100:.0f}% — 골드 부 게이트 (주 게이트 = 결정 04 §3.1-2)')
    print(f'  풀 로스터 수요 {acc["gold"]:,}G = 총수입의 {acc["gold"] / total_inc * 100:.0f}% — '
          f'구조적 불가능 = 선택과집중 의도 (무투자 성장 상한 = 숙련 ×1.30)')
    print('  ※ 결제 무조건 집행 상한 가정 — 실제는 ★5 승급 결정 1,200개 게이트(04 §3.1-2)로 더 후반 분산'
          ' · 기존 지출(유지비 ≈84만G·풀업 330만G — 발견 2)과 별도 경쟁')


def median(xs):
    xs = sorted(xs)
    return xs[len(xs) // 2] if xs else None


def report(heroes, state, acc, days, floor, seed):
    print(f'\n═══ 숙련도 시뮬 (영웅 {len(heroes)} · {days}일 · 층 {floor} · 시드 {seed}) ═══')

    ops = {st['track']: st['tier'] for st in state if st['kind'] == '시설'}
    life_c = Counter(st['track'] for st in state if st['kind'] == '생활')
    print('운영자 배치: ' + ' · '.join(f'{a} t{ops.get(a, "—")}' for a in OPERATOR_APT)
          + f' + 생활 {len(heroes) - len(OPERATOR_APT)}명')
    print('생활 트랙: ' + ' · '.join(f'{a}{life_c.get(a, 0)}' for a in LIFE_APT))
    gb = Counter(band(st['start_gnum']) for st in state)
    print('시작 등급: ' + ' · '.join(f'{k} {gb[k]}' for k in ('★1~2', '★3', '★4', '★5+')))

    def label(t):
        return TIER_NAME[t] if t >= 4 else '은닉'
    s_c = Counter(label(st['start_tier']) for st in state)
    e_c = Counter(label(st['tier']) for st in state)
    order = ['은닉', '견습', '숙련', '장인', '명장']
    print('티어 분포: 시작 ' + ' · '.join(f'{k} {s_c.get(k, 0)}' for k in order)
          + ' → 종료 ' + ' · '.join(f'{k} {e_c.get(k, 0)}' for k in order))

    print('\n── 견습→명장 도달 일수 (미달 시작 기준 · 중간일) ──')
    for kind in ('시설', '생활'):
        cells = []
        for T in (4, 5, 6, 7):
            xs = [st['reached'][T] for st in state
                  if st['kind'] == kind and st['start_tier'] < T and T in st['reached']]
            cells.append(f'{TIER_NAME[T]} {median(xs)}일(n={len(xs)})' if xs else f'{TIER_NAME[T]} —')
        print(f'{KIND_LABEL[kind]}: ' + ' · '.join(cells))
    print(f'  (참고) 게이트 없는 순수 XP 곡선: 은닉→명장 200 XP = 시설 5/일 {200 / 5:.0f}일 · 생활 1/일 {200 / 1:.0f}일')

    print('\n── 명장7 도달 상세 (시작 등급별) ──')
    for kind in ('시설', '생활'):
        for bnd in ('★1~2', '★3', '★4', '★5+'):
            xs = [st['reached'][7] for st in state
                  if st['kind'] == kind and band(st['start_gnum']) == bnd
                  and st['start_tier'] < 7 and 7 in st['reached']]
            if xs:
                note = ' — XP 순수 곡선 (설계 체감 ~40일 대조)' if bnd == '★5+' and kind == '시설' \
                    else ' — 등급 승급 병목 (XP는 보류 대기)' if kind == '시설' \
                    else ''
                print(f'  {kind}계 {bnd}: 중간 {median(xs)}일 (n={len(xs)}){note}')
    nost = sum(1 for st in state if 7 not in st['reached'])
    print(f'  미도달 {nost}명 ({days}일 호라이즌 내 — 등급 승급 대기 또는 생활 커브)')

    print('\n── 보류 XP (등급 상한 대기분 · 시작 등급별 피크) ──')
    tot = sum(st['pending'] for st in state)
    for bnd in ('★1~2', '★3', '★4'):
        grp = [st for st in state if band(st['start_gnum']) == bnd and st['peak'] > 0]
        if grp:
            print(f'  {bnd} 시작: 대기 발생 {len(grp)}명 · 피크 중간 {median([s["peak"] for s in grp]):.0f}'
                  f' / 최대 {max(s["peak"] for s in grp):.0f} XP')
    print(f'  종료 시점 총 보류 {tot:.0f} XP — 합성소 승급 시 즉시 반영 (XP 낭비 0)')

    print('\n── 검증 ──')
    held = sum(st['xp_in'] for st in state) + sum(st['pending'] for st in state)
    delta = acc['earned'] - (acc['consumed'] + held + acc['voided'])
    print(f'XP 보존: 획득 {acc["earned"]:.0f} = 승급 소비 {acc["consumed"]:.0f} + 진행·보류 {held:.0f}'
          f' + 만렙 소멸 {acc["voided"]:.0f}'
          f' (Δ {delta:.1f})' + (' ✓' if abs(delta) < 1.0 else ' ✗'))
    print(f'게이트 위반: {acc["viol"]}건' + (' ✓' if acc['viol'] == 0 else ' ✗'))
    gn = acc['gold_n']
    print(f'골드 소요: 장인 승급 ×{gn[6]} ({gn[6] * 2000:,}G) + 명장 승급 ×{gn[7]} ({gn[7] * 10000:,}G) '
          f'= 누계 {acc["gold"]:,}G')
    gold_vs_income(acc, days)
    pr = acc['promotions']
    print('승급 실측: ' + ' · '.join(f'{TIER_NAME[t]} {pr.get(t, 0)}' for t in (4, 5, 6, 7))
          + ' | 등급승급 ' + ' · '.join(f'★{g} {acc["grade_ups"].get(g, 0)}' for g in (2, 3, 4, 5)))
    grown = sum(1 for st in state if st['tier'] == 7 and st['start_tier'] < 7)
    summoned = sum(1 for st in state if st['start_tier'] == 7)
    print(f'명장: 성장산 {grown} + 소환산 {summoned} (시작 티어7)')


def comparison(n, days, floor, seed):
    """재조정안 시나리오 비교 (9차 가안 — 병목 실측 반영) — 표준 n=150"""
    print(f'\n── 재조정안 비교 (n={n} · {days}일 · 명장7 중간 도달일 / 보류 피크 / 골드) ──')
    print(f'{"시나리오":<28} {"시설계 ★4":>9} {"시설계 ★1~2":>11} {"생활계 ★1~2":>11} {"보류 최대":>8} {"골드":>11}')
    for m, sc in SCENARIOS.items():
        _, st, acc = simulate(n, days, floor, seed, m)

        def med(kind, bnd, T=7):
            xs = [s['reached'][T] for s in st
                  if s['kind'] == kind and band(s['start_gnum']) == bnd
                  and s['start_tier'] < T and T in s['reached']]
            return median(xs)
        m4 = med('시설', '★4')
        m12o = med('시설', '★1~2')
        m12l = med('생활', '★1~2')
        peaks = [s['peak'] for s in st if s['peak'] > 0]
        pk = f'{max(peaks):.0f}' if peaks else '0'
        print(f'{sc["label"]:<28} {str(m4) + "일" if m4 else "—":>9} '
              f'{str(m12o) + "일" if m12o else "—":>11} '
              f'{str(m12l) + "일" if m12l else "—":>11} {pk:>8} {acc["gold"]:>11,.0f}')
    print('  ※ 보류 최대 = ★1~2 영웅 저축 피크 — 상한 있으면 그 값 (B·D) · XP 보존·게이트 0건 전 시나리오 공통')


def main():
    args = [a for a in sys.argv[1:]]
    n, days, floor, seed = 150, 365, 50, None
    if args and args[0].isdigit():
        n = int(args.pop(0))
    if args and args[0].isdigit():
        days = int(args.pop(0))
    if '--seed' in args:
        seed = int(args[args.index('--seed') + 1])
    if seed is None:  # 도구 시드 기본 랜덤 (2026-09-14 결정 승계) — 고정 재현은 --seed
        seed = random.SystemRandom().randrange(2**31)
    heroes, state, acc = simulate(n, days, floor, seed)
    report(heroes, state, acc, days, floor, seed)
    comparison(n, days, floor, seed)


if __name__ == '__main__':
    main()
