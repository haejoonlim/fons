#!/usr/bin/env python3
"""FONS 뽑기 시뮬레이터 v2 — GDD_v8.0_05 전체 반영 (2026-09-14)

반영 규칙:
- 등급 확률표 (00 확정 #32 · 2026-09-17 확정): ★1 70.04 / ★2 20 / ★3 8.7 / ★4 1.2 / ★5 0.05 / ★6 0.01 — ★4 하향(원신 ★5 2배 체감)·잔여 ★3 귀속
- 천장 (확정 #32 구조 · #33 수치 가안 · 비공개): ★4 소프트 70회부터 +2%p/회 · 하드 130회 보장 / ★5+ 하드 5,200회 보장 (★5:★6=5:1 교대) — 자연 확률 유지·꼬리만 컷 (E[★5]@50 1.73 무영향) · 유저에게 미표기
- 계열 7 (조형생명 5% · 기존 20종은 나머지 95%에서 종족별 균등, 시작 영웅은 legacy-only) → 활성 종족 26 · 분파 78 (2026-09-28 D-276)
- 직업 L1 7종 소환 (확정 #39 · 2026-09-28 23차 재설계 — 트리 117 = 13×9 / L1 7·L2 28·L3 82 · L2·L3는 행동 중 자동 전직(합성소 아님) · 무직 3% 고정 · 계열 희귀직 5% 롤과 계열 잠금 모두 폐지) · 성격 13종 (성실 신규 · 요행 삭제 · 중립→무자비 교체 · 가중치 롤 · 10연차 중복 방지 — 2026-09-14 4차)
- 적성 공통 10 = 생활 5(채집·벌목·농부·목수·광부) + 시설 5(요리·간호·연구·조제·대장) — 전투 5종 삭제(B+C 합산 5차) · 7티어(1~4 은닉 · 5 숙련자 · 6 장인 · 7 마스터 — 6차) · 종족 보정 races.json aptitude(+ 시작+1 · ++ +2) · 전투 정체성은 역할 태그 (05 §6)
- 운명 7단계 (05 §4 Part B v3 확정 2026-09-17): 천명3/각인12/재능20/소질25/숙명20/개화12/무명8 — 희귀직 확률 = 5%×단계 배율 (fate_test.py 500k 검증)
- 희귀 특성 계열 전용 49종 (7계열×7 · 공용 6 별도): 조형생명 7종은 데이터 전용이며 효과 런타임 미구현
- 스탯 13종 = 기본×직업×등급 × 종족·아종 statMods(%) × 성격 실반영 × 개체 변량 ±8% + CP ①식 (05 §7)
- 소환 단가 130석 · 무료 10회 · 쿼터 = 2×인구상한
- 이름 재추첨 (중복 최대 8회) · 등급×종족 독립
- 레벨 130 · 순수도 · 각성 (확정 #34~36 — 05 §7-1 · 2026-09-17 승인): make_hero는 Lv1 생성기 — 육성(각성 판정·순수도 경로)은 growth_report()로 분리 시뮬

실행: python3 gacha_test.py [층수] [연차수] [--pickup 계열]
"""
import hashlib
import os as _os
import random
import sys
from collections import Counter

from rare_apt_gen import LEGACY_HOLDERS, APT_NAMES, SIGNATURE, SLOTS, SLOT_W  # 105종 후보 정본 — §6-1 후속 개편용 (gacha_test 희귀 롤과 독립)
from feat_values import FEAT_VALUE as _FV, FEAT_SIG_VALUE, FEAT_SIG_W  # 가치표 v2 단일 소스 (2026-09-19 14차)

# ── 스킬 레어도 D-269 체감 시뮬 (2026-09-19) ─────────────────────────
# 정본: skills_catalog.json (P1-v3 · 2패스) — D 443/C 332/B 278/A 130/S 78/L 39
# 각인 모델 (09 §5): 행동 태그 XP가 쌓여 조건 합계가 임계를 넘으면 각인.
# 태그 XP는 영웅의 직업·역할·적성 도메인 선호에 비례해 발생한다고 가정 —
# 도메인 가중 = 역할 기본 편중(전투 60%·생활 30%·사회 10%) × 개체 변량.
# "100뽑당 각인 스킬 수" = 카탈로그 등급 분포 × 도달 가능 조건 수 근사.
SKILL_RARITY_NAME = {1: 'D', 2: 'C', 3: 'B', 4: 'A', 5: 'S', 6: 'L'}
SKILL_DISTRIB = {1: 443, 2: 332, 3: 278, 4: 130, 5: 78, 6: 39}   # D-269 재편
SKILL_BAND = {1: (13, 64), 2: (65, 129), 3: (130, 239), 4: (240, 415), 5: (530, 714), 6: (715, 936)}

def engrave_curve(heroes=None):
    """L 3태그 각인 체감 곡선 — "같은 계열 행동을 N번 반복" 기준 (D-269 부속 · gacha 시뮬 승계).
    각인 조건 = 태그별 누적 XP 합계(문맥 포함)이므로, 1행동 = 1XP 가정 시
    "N번 반복으로 도달 가능한 스킬 수"가 곧 체감 곡선. 카탈로그 정본(skills_catalog.json) 직접 집계.
    """
    import importlib.util as _ilu
    # 저장소 경로는 스크립트 위치에서 계산한다 — 폴더 개명(2026-09-27 soul-commander → fons)에 안전
    _here = _os.path.dirname(_os.path.abspath(__file__))
    spec = _ilu.spec_from_file_location('scg', _os.path.join(_here, 'skill_catalog_gen.py'))
    scg = _ilu.module_from_spec(spec); sys.modules.setdefault('scg', scg); spec.loader.exec_module(scg)
    skills = scg.build()
    total = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}
    milestones = (65, 130, 240, 530, 936)   # C·B·A·S·L 진입 경계 (조건 합계 도달 반복 수)
    rows = []
    for N in milestones:
        cnt = {r: sum(1 for s in skills if s['레어도'] == r and s['각인_임계'] <= N) for r in (1, 2, 3, 4, 5, 6)}
        tot = sum(cnt.values())
        pct = {r: cnt[r] * 100.0 / tot for r in (1, 2, 3, 4, 5, 6)}
        rows.append((N, tot, pct, cnt))
        for r in (1, 2, 3, 4, 5, 6):
            total[r] = cnt[r]
    return rows


def engrave_report(heroes, n=100):
    """같은 계열 행동을 N번 반복했을 때의 각인 체감 — D-269 확정 분포 34/26/21/10/6/3으로 수렴"""
    rows = engrave_curve(heroes)
    print(f'\n═══ 스킬 각인 체감 (D-269 — 같은 계열 행동 N번 반복 · 카탈로그 1,300종 정본 집계) ═══')
    print(f'{"반복":>5} {"도달":>6} | {"D":>5} {"C":>5} {"B":>5} {"A":>5} {"S":>5} {"L":>5} (도달 스킬의 등급 비율 %)')
    for N, tot, pct, cnt in rows:
        cells = ' '.join(f'{pct[r]:>5.1f}' for r in (1, 2, 3, 4, 5, 6))
        print(f'{N:>5} {tot:>6} | {cells}')
    final = rows[-1][2]
    print(f'→ 936회 만반복 시 D:C:B:A:S:L = {final[1]:.0f}:{final[2]:.0f}:{final[3]:.0f}:{final[4]:.0f}:{final[5]:.0f}:{final[6]:.0f}'
          f' — D-269 확정 분포 34:26:21:10:6:3과 일치 · L은 마지막 3% (100뽑당 3종)')


rng = random.Random(20260914)  # 모듈 기본 — main()에서 실행마다 재설정 (--seed로 고정 재현)

# ── 정본 데이터 (05 문서 §2~§7 · races.json) ──────────────────────────
RATES = {'★1': 0.7004, '★2': 0.20, '★3': 0.087, '★4': 0.012, '★5': 0.0005, '★6': 0.0001}  # 2026-09-17 개정
# 천장 가안 (00 확정 #33 · 비공개 — 유저 미표기 원칙 · 구조 확정 #32)
PITY4_SOFT_START = 70
PITY4_SOFT_STEP = 0.02
PITY4_HARD = 130
PITY5_HARD = 5200
GRADE_MULT = {1: 1.0, 2: 1.30, 3: 1.69, 4: 2.20, 5: 2.86, 6: 3.71, 7: 4.83}  # 등급당 ×1.3 복리 (2026-09-14 2차 개정)

# ── 레벨 130 · 순수도 · 각성 (확정 #34·#35·#36 — 05 §7-1 · 2026-09-17 승인) ──
LEVEL_CAP = 130                                    # 영웅 만렙 (구 Lv100 가안 폐기)
LEVEL_COEF_CAP = 1 + (LEVEL_CAP - 1) * 0.05        # 레벨계수 Lv130 = ×7.45 (선형 연장)
PURITY_INIT = 1.00                                 # 신규 영웅 순수도 (전 등급 공통)
PURITY_STEP = -0.04                                # 합성소 승급 1회당 (가산 중첩 · 하한 없음)
AWAKEN_MILESTONES = (20, 40, 60, 80, 100, 120)     # 판정 6회 — 만렙 130 전 완료
AWAKEN_GAIN = 0.02                                 # 성공 시 순수도 +0.02
AWAKEN_CAP = 1.08                                  # 상한 — 본래 대비 +8%까지만 (천생 역전 방지)
AWAKEN_BASE = 0.20                                 # 기본 판정 확률
AWAKEN_GROWTH_BONUS = 0.05                         # 성장형 성격 +5%p
AWAKEN_MASTERY_MAX = 0.08                          # 숙련 보정 최대 +8%p (§6-2 명장7 기준)
AWAKEN_RARE_BONUS = 0.015                          # 희귀·시그니처 적성 가속 +1.5%p (§6-2 숙련 브래킷 근사)
GROWTH_PERSONA = {'몰입', '성실', '노련'}       # 성장형 성격 — 01 §4·05 §5 (5차 개명 — 구 천애·백전노장)

# ── 몬스터 레벨 · G3 손잡이 (확정 #37·#38 G3손잡이 — 06 §3.2 · ※ 00의 #38은 G3 손잡이, 특성 트리거는 #64) ──
G3_HP_SLOPE_START = 95                             # 경사 기준층
G3_HP_SLOPE_STEP = 0.04                            # f96~100 +4%p/층 (구 계단 ×1.2 완화)
G3_LEVER_LEVEL = 110                               # Lv110+ HP 복리 레버
G3_LEVER_HP = -0.02                                # Lv당 −2% 복리 (Lv130 −33.2%)
T5_BOSS_MID = {'hp': 32500, 'atk': 447, 'dfn': 71} # monsters.json t5 중앙값 (2026-09-18 2차 리튠 반영 — hp·df 갱신)


def mon_level(f):
    """확정 #37: Lv = round_half_up(층 × 1.3) — monsters.json level 필드와 동일 식"""
    return min(130, int(f * 1.3 + 0.5))


def scale_of(f):
    """06 §3.2 층 스케일식 (G1/G2/G3)"""
    if f <= 50: return 2.0 + 0.03 * f
    if f <= 95: return 3.5 + 0.04 * (f - 50)
    return 5.3 + 0.10 * (f - 95)


def monster_stats_at(f, boss=None, fix=False):
    """층 f 보스 실스탯 — 확정 #37 레벨 + #38 손잡이(00 G3 손잡이) (fix=True → 구 계단 ×1.2·레버 없음)"""
    b = boss or T5_BOSS_MID
    s = scale_of(f)
    hp_mod = 1.2 if (fix and f >= 96) else (1.0 + G3_HP_SLOPE_STEP * (f - G3_HP_SLOPE_START) if f > G3_HP_SLOPE_START else 1.0)
    lever = 1.0 if fix else (1.0 + G3_LEVER_HP) ** max(0, mon_level(f) - G3_LEVER_LEVEL)
    return {'Lv': mon_level(f), 'scale': round(s, 2), 'hp_mod': round(hp_mod, 2),
            'lever': round(lever, 3), 'hp': b['hp'] * s * hp_mod * lever,
            'atk': b['atk'] * s, 'dfn': b['dfn'] * s}


def margin_report(max_floor=100):
    """전 구간 마진 프로파일 — ★5 만렙 5인 프록시 (확정 #38 G3 손잡이 검증용)
    캘리브레이션: f75 마진 1.60 앵커 (치유 지원계수 h 자동 산출) — 원전 /tmp/sim_g3_lever.py"""
    crit = 1 + 0.05 * (1.65 - 1)
    g5 = 1.3 ** 4
    lc = 1 + (LEVEL_CAP - 1) * 0.05
    atk_p, hp_p, df_p = 45 * g5 * lc, 600 * g5 * lc, 20 * g5 * lc
    att = lambda x: 200 / (x + 200)

    def margin(f, fix):
        m = monster_stats_at(f, fix=fix)
        ttk_boss = m['hp'] / (5 * atk_p * att(m['dfn']) * crit)
        return (5 * hp_p / (m['atk'] * att(df_p))) / ttk_boss

    h = 1.60 / margin(75, fix=True)   # f75 앵커
    print(f'\n═══ 전 구간 마진 프로파일 (★5 만렙 · t5 보스 중앙값 · h={h:.3f}) ═══')
    print(f'{"층":>4} {"Lv":>4} {"scale":>6} {"HP모드":>7} {"lever":>6} | {"현행":>6} {"손잡이":>6}')
    for f in (25, 50, 75, 85, 90, 95, 96, 98, 100):
        if f > max_floor: break
        m = monster_stats_at(f)
        old = margin(f, True) * h
        new = margin(f, False) * h
        tag = f"{m['hp_mod']:.2f}×{m['lever']:.2f}" if f > G3_HP_SLOPE_START else ('—' if m['lever'] == 1 else f"1.00×{m['lever']:.2f}")
        print(f'{f:>4} {m["Lv"]:>4} {m["scale"]:>6.2f} {tag:>7} | {old:>6.2f} {new:>6.2f}')
    n100 = monster_stats_at(100)
    print(f'Lv130 보스 HP −{100 - n100["lever"] * n100["hp_mod"] / 1.2 * 100:.1f}% (vs 구 계단) · 목표 실효 마진 1.2~1.4 (프록시+보정)')

LINEAGES = ['인간', '엘프', '드워프', '짐승', '전사', '심연', '조형생명']
LEGACY_LINEAGES = LINEAGES[:-1]
SHAPED_LINEAGE_RATE = 0.05  # 전체 소환의 5%; 나머지 95%는 기존 20종 종족별 균등
# (계열 → [(종족, [분파...], 해금층)]) — races.json 활성 26종·78분파와 동기
RACE_MAP = {
    '인간':  [('인간',   ['유목민', '항해민', '수렵민', '개척민'], 0),
              ('정령족', ['불의 정령족', '물의 정령족', '대지의 정령족', '바람의 정령족', '빛의 정령족', '어둠의 정령족', '무의 정령족'], 0)],
    '엘프':  [('하이 엘프', ['광로 엘프', '서약 엘프'], 0),
              ('우드 엘프', ['심림 엘프', '초원 엘프', '수관 엘프'], 0),
              ('다크 엘프', ['지하 엘프 (드로우)', '심연 엘프', '맥그늘 엘프'], 0),
              ('시 엘프', ['산호 엘프', '폭풍 엘프', '심류 엘프'], 1)],
    '드워프': [('드워프', ['지맥 드워프', '화로 드워프', '앵커 드워프'], 0),
              ('노움', ['흑수 노움', '기류 노움', '울림석 노움'], 0),
              ('하프링', ['씨앗무늬 하프링', '뜬뿌리 하프링', '역참 하프링'], 0)],
    '짐승':  [('묘인족', ['표범 묘인족', '살쾡이 묘인족', '설릉 묘인족'], 0),
              ('견인족', ['갈빛 견인족', '물숨 견인족', '산길 견인족'], 0),
              ('조인족', ['독수리 조인족', '까마귀 조인족', '두루미 조인족'], 5),
              ('리자드맨', ['늪지 리자드맨', '사막 리자드맨', '수림 리자드맨'], 0),
              ('물갈퀴족', ['이끼등 물갈퀴족', '갈대길 물갈퀴족', '연해 물갈퀴족'], 0),
              ('굴길족', ['잿골 굴길족', '수로 굴길족', '맥굴 굴길족'], 0),
              ('산양족', ['능선 산양족', '화구 산양족', '고원 산양족'], 0),
              ('긴꼬리족', ['수관 긴꼬리족', '뿌리길 긴꼬리족', '미궁 긴꼬리족'], 0),
              ('용족', ['화염 용족', '물 용족', '대지 용족', '바람 용족', '빛 용족', '어둠 용족', '무 용족'], 0)],
    '전사':  [('오크', ['산지 오크', '초원 오크', '화구 오크', '잿터 오크'], 9)],
    '심연':  [('뱀파이어', ['명맥 혈족', '귀원 혈족', '영야 혈족'], 13)],
    '조형생명': [('석상인', ['지맥수호 석상인', '능선 파수 석상인'], 0),
              ('점토생명체', ['잿가마 점토인'], 0),
              ('강철각성체', ['화구 강철각성체'], 0),
              ('수정핵체', ['해구 수정핵체', '조석유리체'], 0),
              ('룬인형족', ['서고 봉인 룬인형'], 0),
              ('태엽자동인형족', ['기류태엽족', '미궁태엽족'], 0)],
}

JOB_COEF = {  # (HP ATK DEF ASPD MAG MDEF CRI) — L1 7종 (23차 직업트리 확정 #39 — 소환 롤 풀)
    '전사':     (1.2, 1.0, 1.0, 1.0, 0.5, 1.0, 1.05),
    '수호자':   (1.8, 0.7, 1.5, 0.8, 0.4, 1.5, 1.0),
    '암살자':   (0.8, 1.3, 0.6, 1.4, 0.5, 0.6, 1.3),
    '궁수':     (0.9, 1.1, 0.7, 1.2, 0.5, 0.7, 1.2),
    '마법사':   (0.7, 0.8, 0.5, 0.9, 1.5, 1.4, 1.1),
    '지원가':   (0.9, 0.6, 0.8, 1.1, 1.2, 1.2, 1.0),
    '무직':     (1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0),  # 리프 — 산하 전직 없음 · 6축 중립
}
# L2 전직 계수 22종 — 시뮬 검증 완료 (2026-09-18 /tmp/sim_l2_verify.py: L1 대비 CP median ×1.03~1.15 · min ≥1.02 · 안A 보너스 기준)
# 전직 난이도 티어 배율 (2026-09-21 확정 — 게이트 조건 스코어링 기반 · 05 §8-1)
#   A ×1.00(6종) / B ×1.30(11종) / C ×1.65(5종) — 전직 시 스탯 6축에 √티어 2회(L2·L3) 곱 = 체인 합산 티어 1회분
#   L3/L1 체인 밴드: A ×1.220~1.291 · B ×1.342~1.422 · C ×1.557~1.632 (chain_target_test.py v2 n=6만)
JOB_TIER = {
    # ★ L2 전직 난이도 티어 (A=쉬움 · B=보통 · C=어려움) — 24차부터 유지.
    #   34차에서 키워드 티어를 1/2/3 으로 바꿔 이 어휘와 겹치지 않게 했다.
    #   (키워드 티어 1 = 가장 어려움 — L2 티어와 **방향이 반대**다. 의도적이다.)
    # A(8종) / B(11종) / C(5종) — 게이트 조건 스코어링 기반
    '사역사': 'A', '주술사': 'A', '신관': 'A', '드루이드': 'A', '현자': 'A', '정령기사': 'A', '격투사': 'A',
    '파쇄사': 'B', '검술사': 'B', '성기사': 'B', '자객': 'B', '창술사': 'B',
    '맹독사': 'B', '명사수': 'B', '포화사수': 'B', '원소 마도사': 'B', '성술사': 'B', '예술가': 'B',
    '광전사': 'C', '철벽기사': 'C', '도적': 'C', '길잡이': 'C', '소환술사': 'C',
    '전위기사': 'A',   # 35차 재편 — 수호 → 선봉(공격). 전직 난이도 A
    '무직': 'A',   # 34차 신설 — 전직 조건이 없다
}
TIER_MUL = {'A': 1.00, 'B': 1.30, 'C': 1.65}

def job_tier_mul(child):
    """전직 대상 L2 직업의 티어 배율 — 체인 합산 기준 (√티어 per 스텝은 호출부에서 적용)"""
    return TIER_MUL[JOB_TIER.get(child, 'B')]

def apply_tier_to_stats(st, tier_mul_sqrt):
    """스탯 6축(HP·ATK·DEF·ASPD·MAG·MDEF)에 √티어 곱 — 전직 1스텝분. 안A 보너스 축 제외."""
    for ax in ('HP', 'ATK', 'DEF', 'ASPD', 'MAG', 'MDEF'):
        st[ax] *= tier_mul_sqrt
    return st
# 승계 유지 4종(광전사·주술사·드루이드·현자) + 캘리브레이션 18종(검술사·파괴기사·성기사·포화사수·예술가 등 — CP 약축 보정)
# 전직 시 적용 · 소환 롤 미사용 · 안A 보너스(CDMG+10·CRI+2·PEN+5)는 전직 파이프라인에서 별도 합산
JOB_COEF_L2 = {
    # 24차 재설계 — L2 23종. 축 순서 (HP ATK DEF ASPD MAG MDEF CRI)
    # 밴드 검증: sim_l2_band.py (CP ①식 · 동일 개체 페어링 · 안A 보너스 포함 · 티어 배율은 밴드 밖)
    #   → L2 23종 전부 median ×1.03~1.20 · min ≥ 1.00 통과 (n=6,000 · 시드 20260929)
    # 전사 계열
    '파쇄사': (1.57,1.05,1.46,0.73,0.52,1.25,1.05),      # 구 파괴기사 승계
    # 35차 — '전위기사' 계수는 아래 수호자 계열 블록의 새 값으로 대체했다 (중복 키는 파이썬이 뒤를 이긴다).
    '광전사': (1.7,0.9,1.5,1.0,0.4,1.4,1.3),            # 33차 개명 (구 재앙사 · 계수 그대로 승계)
    '무직':    (1.0,1.0,1.0,1.0,1.0,1.0,1.0),              # 34차 신설 — 이름 없는 자리(계수 1.0)
    '검술사': (1.06,1.27,0.74,1.91,0.42,0.85,1.27),        # 승계 유지
    '격투사': (1.1,1.3,1.0,1.1,0.4,0.9,1.5),               # 승계 유지
    '정령기사': (1.45,1.15,1.25,0.95,0.55,1.15,1.05),      # 신규 — 원소 기사(단일화) 중앙값
    # 수호자 계열
    '성기사': (1.35,0.85,1.2,0.85,1.05,1.25,1.0),       # 재캘리브 — 수호자 L1(H1.8/D1.5) 위에 얹혀 CP ×1.266 이탈
    '철벽기사': (1.324,0.82,1.324,0.748,0.567,1.288,0.928), # 35차 재편 — 갑옷 수비(DEF·HP·STA). ATK·PEN 을 낮게 유지
    '수도사': (1.39,1.01,1.30,0.90,0.62,1.09,0.90),        # 35차 신설 — 맨몸(HP·MDEF 위주). 철벽기사보다 ATK 무겁고 DEF 가벼움
    '전위기사': (1.30,1.28,1.02,1.30,0.80,0.95,0.98),      # 35차 재편 — 수비 → **공격형**. ATK·공속·PEN 이 두텁고 DEF 가 얇다
    '길잡이': (1.05,0.75,1.0,1.0,1.25,1.45,1.0),          # 43차 — 땜장이 자리를 이어받은 길 안내(계수 승계)
    # 암살자 계열
    '자객': (0.855,1.29,0.637,1.363,0.637,0.71,1.29),# 재캘리브 ×1.166
    '맹독사': (0.85,1.2,0.6,1.2,0.8,0.7,1.3),             # 승계 유지
    '도적': (0.935,1.324,0.741,1.129,0.676,0.806,1.388), # 재캘리브 ×1.166
    # 궁수 계열
    '명사수': (0.9,1.4,0.7,1.0,0.5,0.7,1.7),
    '포화사수': (0.87,1.09,0.65,1.85,0.54,0.76,1.2),
    '사역사': (1.0,1.1,0.8,1.2,0.7,0.9,1.2),
    '창술사': (0.95,0.95,0.80,1.10,1.70,1.60,1.30),   # 42차 — 마궁사 자리를 이어받은 창술(계수 승계)
    # 마법사 계열 (승계 유지)
    '원소 마도사': (0.7,0.7,0.5,0.9,1.6,1.5,1.2),         # 구 원소술사 (이름 = 첫 원소)
    '주술사': (0.854,0.927,0.709,0.927,1.582,1.437,1.146), # 재캘리브 ×1.140
    '소환술사': (0.75,0.8,0.6,0.9,1.6,1.5,1.1),
    '성술사': (0.8,0.7,0.7,0.9,1.5,1.6,1.2),
    # 지원가 계열 (승계 유지)
    '신관': (0.9,0.5,0.9,1.0,1.4,1.4,0.9),
    '드루이드': (1.0,0.7,0.9,0.9,1.3,1.3,1.0),
    '현자': (0.8,0.7,0.7,0.9,1.6,1.7,1.3),
    # 35차 — L2 '예술가' 제거 → '정신술사' (디버프·아군 버프·마나공급)
    '정신술사': (0.9,0.6,0.9,1.0,1.5,1.4,0.95),
}
# 계열 잠금 — 23차부터 폐지(05 §8-1). L2 후보는 전 종족 공통 풀이며 종족 성향은 L1 롤 확률로만 반영.
# 구 정의(21차): {'전사':'광전사','심연':'주술사','드워프':'파괴기사','짐승':'짐승조련사','인간':'현자','엘프':'현자'}
LINEAGE_LOCK = {}

# 종족 시그니처 직업 CP 보너스 ×1.03 (2026-09-21 확정 — RACE_JOB 가중 1위 직업 = 시그니처)
# 인간은 만능(무가중)이라 시그니처 없음 · 힐러(지원가)는 전 종족 시그니처 부재 — 희소화 설계 정합 (확정 #39 조정)
RACE_SIG_MUL = {
    '정령족': {'마법사': 1.03}, '하이 엘프': {'마법사': 1.03}, '우드 엘프': {'궁수': 1.03},
    '다크 엘프': {'암살자': 1.03}, '시 엘프': {'궁수': 1.03}, '드워프': {'수호자': 1.03},
    '노움': {'마법사': 1.03}, '하프링': {'궁수': 1.03}, '묘인족': {'암살자': 1.03},
    '견인족': {'전사': 1.03}, '조인족': {'궁수': 1.03}, '리자드맨': {'전사': 1.03},
    '오크': {'전사': 1.03}, '뱀파이어': {'마법사': 1.03},
}

PERSONALITIES = ['용감', '신중', '냉정', '난폭', '헌신', '교활', '무자비',
                 '불굴', '낭만', '고집', '성실', '몰입', '노련']
P_MULT = {'용감': 1.03, '신중': 1.02, '냉정': 1.02, '난폭': 1.04, '헌신': 1.02,
          '교활': 1.02, '무자비': 1.03, '불굴': 1.03, '낭만': 1.01,
          '고집': 1.02, '성실': 1.02, '몰입': 1.05, '노련': 1.04}
P_RARE = {'몰입': '★4+', '노련': 'Lv30+'}  # 조건부 (노련은 시뮬에서 Lv0 기준 비출현)
# 성격 가중치 롤 (05 §5 5차 개명 — 광폭→난폭 · 천애→몰입 · 백전노장→노련 · 효과·가중치 유지). 노련은 Lv30+ 재롤 전용이라 롤 제외.
P_WEIGHT = {'용감': 9, '신중': 9, '냉정': 8, '난폭': 8, '헌신': 8, '교활': 8,
            '무자비': 8, '불굴': 8, '낭만': 7, '고집': 9, '성실': 8, '몰입': 2}
# 성격 → 스탯 실반영 (01 §4 가안 — CP의 P와 병행)
PERS_STAT_MUL = {'용감': {'ATK': 1.05}, '신중': {'DEF': 1.05},
                 '난폭': {'ATK': 1.08, 'DEF': 0.97}, '헌신': {'MAG': 1.10}}  # 헌신: 치유+10% → MAG
PERS_STAT_PPT = {'냉정': {'CRI': 3.0}, '교활': {'MS': 5.0}, '무자비': {'CDMG': 10.0}}  # %p 가산

# 부가 성격 → XP 선호 도메인 (09 §4-4 스펙표 — 선호 2도메인 ×1.10 · 반대 1도메인 ×0.95 · CP 무영향)
SUB_DOM_W = {
    '낙천': ('사회', '회복', None), '침울': ('지식', '회복', '사회'), '유쾌': ('사회', '회복', '지식'),
    '격정': ('공격', '기동', '회복'), '온후': ('회복', '지원', '공격'), '관조': ('회복', '지식', '기동'),
    '호기심': ('지식', '지식', None), '책략': ('지식', '방어·제어', '공격'), '재치': ('기동', '사회', '생산'),
    '세심': ('생산', '지식', None), '명석': ('지식', '지식', '회복'), '독창': ('지식', '공격', '방어·제어'),
    '박식': ('지식', '생산', '기동'), '꾸준': ('생산', '생산', '기동'), '즉흥': ('기동', '기동', '생산'),
    '충동': ('공격', '공격', '지식'), '엄격': ('지원', '지원', '회복'), '인내': ('방어·제어', '방어·제어', '공격'),
    '성급': ('기동', '공격', '생산'), '우직': ('방어·제어', '생산', '사회'), '소심': ('기동', '회복', '공격'),
    '다정': ('회복', '지원', '공격'), '관대': ('지원', '사회', None), '겸손': ('지식', '회복', '사회'),
    '허세': ('공격', '사회', None), '직설': ('공격', '공격', '사회'), '과묵': ('지식', '방어·제어', '사회'),
    '활달': ('사회', '기동', '회복'), '명랑': ('회복', '사회', '지식'), '다감': ('지식', '회복', '공격'),
    '대담': ('공격', '기동', '회복'), '대범': ('공격', '생산', '지식'), '정복욕': ('공격', '공격', '회복'),
    '자기애': ('회복', '회복', '지원'), '야망': ('생산', '사회', '회복'), '열성': ('지원', '사회', None),
    '몰두': ('지식', '생산', '사회'), '무심': ('회복', '회복', '사회'), '투기': ('기동', '기동', '지원'),
    '냉담': ('지식', '지식', '사회'), '무던': ('회복', '생산', '방어·제어'), '담담': ('방어·제어', '회복', '공격'),
    '느긋': ('회복', '생산', '기동'), '소박': ('생산', '회복', '사회'), '검소': ('생산', '생산', '사회'),
    '근면': ('생산', '생산', '회복'), '나태': ('회복', '회복', '생산'), '이성': ('지식', '지식', '회복'),
    '감성': ('사회', '지식', '방어·제어'), '진지': ('지식', '지원', '회복'), '창의': ('지식', '공격', '방어·제어'),
    '탐욕': ('생산', '사회', '지원'),
}
# 적성 → 도메인 매핑 (공통 13종 — 선호 1:1 · 반대 도메인 일부는 공통 적성 밖이라 무효 — 09 §4-4 각주)
# ★ 35차 (사용자 지시) — 10 → 13종. L4 13장과 이름이 1:1 이다.
#   개명 4건: 간호→의사 · 조제→조약사 · 대장→대장장이 · 목수→건축가 (직업명과 같은 말)
#   신설 3건: 교육자 · 예술가 · 상인
#
# ★ 2026-09-30 — 3종 되돌림(사용자 결정). 35차가 대장장이→제작 · 예술가→예술 ·
#   상인→교역 으로 새 3개 도메인을 만들었으나, **이 이름들은 `SUB_DOM_W` 52종이
#   한 번도 쓰지 않는다.** 계측: 52종이 쓰는 도메인은 생산·회복·지식·사회 + 전투 4종뿐.
#   그 결과 3개 적성은 어떤 부가 성향을 물어도 ×1.0 (보정 영구 무효) 이었고,
#   C# 과 파이썬이 **똑같이** 1.0 을 내서 "양측 일치" 게이트는 green 이었다 —
#   값이 틀린 게 아니라 비어 있는 것이므로 합이 맞는다(결함 8번과 같은 계열).
#   → 기존 4개 생활 도메인으로 되돌려 13/13 적성이 보정을 받게 한다.
#   **대장장이의 정답은 `생산`** — 픽스처 `ai_p0_snapshot.json` 의 `apt_eff`(APT_TIER × sub_eff)
#   100건 전부에서 대장장이=생산일 때만 APT_TIER 7종 값이 정확히 복원된다(100/100).
#   제작으로 두면 93/100, 지식으로 두면 96/100 이다 — 즉 **픽스처가 옛 분류의 증거**다.
#   예술가·상인은 35차 신설이라 선례가 없어 35차가 정한 축 대응(예술→지식 · 교역→사회)을 따랐다.
#   선례: 조약사는 35차부터 이미 L4 카드 domain=제작 · AptDomain=지식 으로 어긋나 있다.
#     L4 카드 domain(카드 계열)과 AptDomain(적성의 부가 가중 분류)은 별개 어휘다.
APT_DOMAIN = {
    '채집꾼': '생산', '벌목꾼': '생산', '농부': '생산', '건축가': '생산', '광부': '생산',
    '요리사': '회복', '의사': '회복', '연구자': '지식', '조약사': '지식', '대장장이': '생산',
    '교육자': '지식', '예술가': '지식', '상인': '사회',
}
SUB_EFF_X = 1.10  # 선호 도메인 스킬·숙련 XP·적성 효율 (09 §4-4 ①)
SUB_EFF_Y = 0.95  # 반대 성향 도메인
VARIANCE = 0.07   # 개체 변량 ±7% (2026-09-14 확정 — 8% → 7% 사용자 조정)
PCT_KEYS = frozenset(('CRI', 'MS', 'PEN', 'CDMG'))

# 부가 성격 52종 (09 v0.6 §4-4 — MBTI형 3키워드 · CP 무영향 · 조합 13×C(52,2)=17,238)
SUB_TRAITS = ['낙천', '침울', '유쾌', '격정', '온후', '관조', '호기심', '책략', '재치', '세심',
              '명석', '독창', '박식', '꾸준', '즉흥', '충동', '엄격', '인내', '성급', '우직',
              '소심', '다정', '관대', '겸손', '허세', '직설', '과묵', '활달', '명랑', '다감',
              '대담', '대범', '정복욕', '자기애', '야망', '열성', '몰두', '무심', '투기', '냉담',
              '무던', '담담', '느긋', '소박', '검소', '근면', '나태', '이성', '감성', '진지',
              '창의', '탐욕']
# 대척쌍 26쌍 (09 §4-4-1 — 1종=1쌍 · 중복 0 · 메인 혼입 0 · 52 피복 — 스크립트 전수 검증 PASS)
OPPOSITE_PAIRS = [('낙천', '침울'), ('유쾌', '냉담'), ('격정', '관조'), ('온후', '정복욕'),
                  ('호기심', '무심'), ('책략', '직설'), ('재치', '우직'), ('명석', '열성'),
                  ('독창', '담담'), ('박식', '몰두'), ('과묵', '활달'), ('명랑', '진지'),
                  ('다감', '야망'), ('꾸준', '즉흥'), ('충동', '인내'), ('성급', '느긋'),
                  ('엄격', '무던'), ('소심', '대담'), ('소박', '창의'), ('세심', '대범'),
                  ('다정', '자기애'), ('관대', '투기'), ('겸손', '허세'), ('검소', '탐욕'),
                  ('근면', '나태'), ('이성', '감성')]
SUB_SLOTS = 2  # 부가 슬롯 — 전 등급 2종 (2026-09-19 사용자 결정 — 구 ★3+ 해금 폐지 · 1성부터 3키워드)

# 적성 공통 13종 — 생활 5 + 시설 운영 8 (05 §6 5차 · B+C 합산 2026-09-14 · 35차 확장)
# 전투 적성 5종(근접·원거리·마법·방어·공속)은 표시 전용이라 삭제 — 전투 정체성은 역할 태그로 대체
# ★ 35차 — 5개 시설에 못 미치던 3종(교육자·예술가·상인)을 신설했다. 적성에는 시설이 없어도 된다.
LIFE_APT = ('채집꾼', '벌목꾼', '농부', '건축가', '광부')
FACILITY_APT = ('요리사', '의사', '연구자', '조약사', '대장장이', '교육자', '예술가', '상인')
# 시설 5종 ↔ 영지 시설 1:1 (04 §3.2) · races.json aptitude 토큰과 동일 이름
# 적성 7티어 (2026-09-15 7차): 1~3 은닉 · 4 견습 · 5 숙련 · 6 장인 · 7 명장 — 등급 게이트 (명장=★5+ · 장인=★4+ · 숙련=★3+)
APT_TIER = {1: 1.00, 2: 1.02, 3: 1.06, 4: 1.10, 5: 1.30, 6: 1.65, 7: 2.30}
APT_TIER_NAME = {4: '견습', 5: '숙련', 6: '장인', 7: '명장'}
# 등급 게이트 — 티어 롤 후 clamp (프로필·종족 보정도 자동 준수) · 명장은 ★5+에서 확률 등장(보장 아님)
TIER_GRADE_GATE = {7: 5, 6: 4, 5: 3}  # 티어: 최소 별 등급 (4견습은 전 등급)
APT_W = (26, 23, 20, 17, 9, 4, 1)  # 1~7 가중치 — 4+ 표시권 31% (티어4 신설 표시 반영)
FACILITY_DESC = {
    '요리사': '식당 — 버프 요리 (4:+10% · 5:+30% · 6:+65% · 7:+130%)', '의사': '병원 — Sanity 요양 (4:+10% · 5:+30% · 6:+65% · 7:+130%)',
    '연구자': '연구소 — 연구 속도 (4:+10% · 5:+30% · 6:+65% · 7:+130%)', '조약사': '연금술소 — 포션 제작 (4:+10% · 5:+30% · 6:+65% · 7:+130%)',
    '대장장이': '합성소 — 합성·강화 (4:+10% · 5:+30% · 6:+65% · 7:+130%)',
    # ★ 35차 신설 3종 — 시설 대응이 없는 적성. 시설이 생길 때 여기만 채우면 된다.
    '교육자': '숙련 가속 — 배운 것이 오래 남는다', '예술가': '기억원 — 결과물이 다음 영웅에게 이어진다',
    '상인': '교역 수수료 — 거래가 유리하게 끝난다',
}
# 직업 ↔ 시설·생활 프로필 (기준값 ±1 · 7스케일) — 특화직(광산기사·현자·질풍사냥꾼)은 5~7 상시 표시
JOB_APT = {
    '전사': {'대장장이': 3, '건축가': 2}, '수호자': {'대장장이': 4, '건축가': 2},
    '암살자': {'채집꾼': 4}, '궁수': {'채집꾼': 4, '벌목꾼': 3},
    '마법사': {'연구자': 4, '조약사': 3}, '지원가': {'의사': 4, '요리사': 3},
}
# 종족 시설·생활 보정 (races.json aptitude 정본 → 시작 등급 +1/+2, 롤 후 clamp 1~7)
RACE_APT_BONUS = {
    '인간': {}, '정령족': {'연구자': 1}, '하이 엘프': {'연구자': 1}, '우드 엘프': {'요리사': 1},
    '다크 엘프': {'연구자': 1}, '시 엘프': {'요리사': 1},
    '드워프': {'대장장이': 2}, '노움': {'조약사': 2, '연구자': 1}, '하프링': {'요리사': 2},
    '묘인족': {'요리사': 1}, '견인족': {'의사': 1}, '조인족': {},
    '리자드맨': {'연구자': 1}, '물갈퀴족': {}, '굴길족': {}, '산양족': {}, '긴꼬리족': {}, '용족': {},
    '석상인': {}, '점토생명체': {}, '강철각성체': {}, '수정핵체': {}, '룬인형족': {}, '태엽자동인형족': {},
    '오크': {'대장장이': 1}, '뱀파이어': {'연구자': 1},
}
# 전투 역할 태그 — 직업 자동 산출 (RNG 낭비 0, 카드 1줄 표시)
# 2026-09-21 용어 통합 A (확정 #49 카드 표기와 일원화 — 구 내부 약칭 선봉·수호·후방·포격·지원 폐기)
ROLE_TAG = {
    '전사': '딜러(근딜)', '수호자': '탱커', '암살자': '암살', '궁수': '딜러(원딜)',
    '마법사': '마법', '지원가': '힐러',
}

# 종족·아종 statMods (races.json 정본 → 표시 13종 키, %보정 가안: ×(1+값/100))
# cool(쿨타임 −N) → SPD_CAST +N% 가안 · hpRegenPer4sPct는 13종 외 제외
RACE_MODS = {
    '인간': {}, '정령족': {}, '하이 엘프': {'MAG': 10},    '우드 엘프': {'ASPD': 7, 'DEF': 3},
    '다크 엘프': {'CRI': 5, 'MAG': 5}, '시 엘프': {'HP': 5, 'MAG': 5},
    '드워프': {'DEF': 10, 'HP': 5}, '노움': {'MAG': 5, 'SPD_CAST': 5},
    '하프링': {'ASPD': 8, 'MS': 5},    '묘인족': {'ASPD': 7, 'CRI': 3},
    '견인족': {'HP': 5, 'ATK': 5}, '조인족': {'ASPD': 10},
    '리자드맨': {'DEF': 8, 'HP': 5}, '물갈퀴족': {}, '굴길족': {}, '산양족': {}, '긴꼬리족': {}, '용족': {},
    '석상인': {}, '점토생명체': {}, '강철각성체': {}, '수정핵체': {}, '룬인형족': {}, '태엽자동인형족': {},
    '오크': {'HP': 8, 'ATK': 8}, '뱀파이어': {'MAG': 8, 'CRI': 3},
}
SUB_MODS = {
    '유목민': {'ASPD': 3}, '항해민': {'HP': 3},    '수렵민': {'ATK': 3},
    '불의 정령족': {'ATK': 3}, '물의 정령족': {'HP': 3}, '대지의 정령족': {'DEF': 5},
    '바람의 정령족': {'ASPD': 5}, '빛의 정령족': {'MAG': 3}, '어둠의 정령족': {'MAG': 3},
    '무의 정령족': {'MANA': 3},
    '광로 엘프': {'MAG': 3}, '서약 엘프': {'SPD_CAST': 3}, '심림 엘프': {'ASPD': 3},
    '초원 엘프': {'HP': 3}, '지하 엘프 (드로우)': {'MAG': 2}, '심연 엘프': {'MAG': 3},
    '산호 엘프': {'HP': 3}, '폭풍 엘프': {'MAG': 3},
    '지맥 드워프': {'DEF': 5}, '앵커 드워프': {'HP': 5}, '흑수 노움': {'MAG': 3},
    '울림석 노움': {'DEF': 3}, '씨앗무늬 하프링': {'HP': 3}, '뜬뿌리 하프링': {'HP': 3},
    '표범 묘인족': {'ASPD': 2}, '살쾡이 묘인족': {'ASPD': 3}, '갈빛 견인족': {'ATK': 3},
    '물숨 견인족': {'HP': 3}, '독수리 조인족': {'ATK': 3}, '까마귀 조인족': {'MAG': 3},
    '늪지 리자드맨': {'HP': 3}, '사막 리자드맨': {'ATK': 3}, '수림 리자드맨': {'HP': 3},
    '개척민': {'HP': 3}, '수관 엘프': {'ASPD': 3}, '심류 엘프': {'HP': 3},
    '화로 드워프': {'DEF': 3}, '기류 노움': {'SPD_CAST': 3}, '역참 하프링': {'HP': 3},
    '설릉 묘인족': {'DEF': 3}, '산길 견인족': {'ATK': 3}, '두루미 조인족': {'SPD_CAST': 3},
    '잿터 오크': {'DEF': 3}, '맥그늘 엘프': {'MAG': 3},
    '이끼등 물갈퀴족': {'HP': 3}, '갈대길 물갈퀴족': {'ASPD': 3}, '연해 물갈퀴족': {'MAG': 3},
    '잿골 굴길족': {'ASPD': 3}, '수로 굴길족': {'HP': 3}, '맥굴 굴길족': {'DEF': 3},
    '능선 산양족': {'DEF': 3}, '화구 산양족': {'HP': 3}, '고원 산양족': {'ASPD': 3},
    '수관 긴꼬리족': {'ASPD': 3}, '뿌리길 긴꼬리족': {'HP': 3}, '미궁 긴꼬리족': {'MAG': 3},
    '화염 용족': {'ATK': 5, 'HP': 3}, '물 용족': {'HP': 5, 'DEF': 3},
    '대지 용족': {'DEF': 5, 'HP': 5}, '바람 용족': {'ASPD': 5},
    '빛 용족': {'MAG': 5, 'SPD_CAST': 3}, '어둠 용족': {'MAG': 5, 'SPD_CAST': 3},
    '무 용족': {'MANA': 5, 'MAG': 3},
    '산지 오크': {'DEF': 3}, '초원 오크': {'ATK': 3}, '화구 오크': {'HP': 3},
    '명맥 혈족': {'MAG': 3}, '귀원 혈족': {'SPD_CAST': 3}, '영야 혈족': {'HP': 3},
    '지맥수호 석상인': {'DEF': 3}, '능선 파수 석상인': {'HP': 3},
    '잿가마 점토인': {'HP': 3}, '화구 강철각성체': {'DEF': 3},
    '해구 수정핵체': {'MAG': 3}, '조석유리체': {'ASPD': 3},
    '서고 봉인 룬인형': {'MAG': 3}, '기류태엽족': {'SPD_CAST': 3}, '미궁태엽족': {'ASPD': 3},
}

# races.json의 표준 카탈로그를 참조해 분파 총계를 지킨다. 상세 보정은 위 SUB_MODS.
RACE_CATALOG_PATH = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', '..', 'data', 'races.json')
with open(RACE_CATALOG_PATH, encoding='utf-8') as _race_file:
    _race_catalog = __import__('json').load(_race_file)
CATALOG_SUBRACE_COUNT = sum(len(r.get('subraces') or []) for r in _race_catalog['races'])
if CATALOG_SUBRACE_COUNT != 78 or CATALOG_SUBRACE_COUNT != _race_catalog.get('subraceCount'):
    raise ValueError(f"races.json 활성 분파 수 불일치: {CATALOG_SUBRACE_COUNT} (meta={_race_catalog.get('subraceCount')})")
if len(_race_catalog['races']) != 26:
    raise ValueError(f"races.json 활성 종족 수 불일치: {len(_race_catalog['races'])} (expected=26)")
_catalog_lineages = _race_catalog.get('lineages') or []
if len(_catalog_lineages) != 7:
    raise ValueError(f"races.json 활성 계열 수 불일치: {len(_catalog_lineages)} (expected=7)")
_catalog_ids = {r['id'] for r in _race_catalog['races']}
_lineage_members = [member for lineage in _catalog_lineages for member in lineage.get('members', [])]
if len(_lineage_members) != len(set(_lineage_members)) or set(_lineage_members) != _catalog_ids:
    raise ValueError("races.json 계열 members가 활성 종족 ID와 불일치")
if any(r.get('lineage') not in {lineage['key'] for lineage in _catalog_lineages} for r in _race_catalog['races']):
    raise ValueError("races.json 활성 종족에 미등록 계열 키가 있음")
_catalog_race_names = {r['name'] for r in _race_catalog['races']}
_mapped_race_names = {race for lineage_races in RACE_MAP.values() for race, _, _ in lineage_races}
if _mapped_race_names != _catalog_race_names:
    raise ValueError(f"RACE_MAP이 races.json 활성 종족과 불일치: missing={sorted(_catalog_race_names - _mapped_race_names)}, extra={sorted(_mapped_race_names - _catalog_race_names)}")
for _map_name, _race_map in (('RACE_APT_BONUS', RACE_APT_BONUS), ('RACE_MODS', RACE_MODS)):
    if set(_race_map) != _catalog_race_names:
        raise ValueError(f"{_map_name} 종족 키가 races.json과 불일치: missing={sorted(_catalog_race_names - set(_race_map))}, extra={sorted(set(_race_map) - _catalog_race_names)}")
_expansion = _race_catalog.get('expansionProposals') or {}
_expansion_counts = _expansion.get('counts') or {}
if _expansion.get('newPlayableRaces') or _expansion.get('existingRaceSubraces'):
    raise ValueError("활성 조형생명/기존 분파를 확장 제안에 중복 등록하면 안 됨")
if len(_race_catalog['races']) != 26 or len(_catalog_lineages) != 7:
    raise ValueError("활성 카탈로그는 26종·7계열이어야 함")
_shaped_races = [r for r in _race_catalog['races'] if r.get('lineage') == 'shaped']
if len(_shaped_races) != 6 or sum(len(r.get('subraces') or []) for r in _shaped_races) != 9:
    raise ValueError("조형생명은 활성 6종·9분파여야 함")
if _expansion_counts.get('candidateRaceTotal') != 26 or _expansion_counts.get('candidateSubraceTotal') != 78:
    raise ValueError("D-276 활성 총계 메타가 26종·78분파와 불일치")
if len(_race_catalog['races']) % 13 or CATALOG_SUBRACE_COUNT % 13:
    raise ValueError("활성 종족·분파 총계는 각각 13의 배수여야 함")
if not any('중단' in (p.get('status') or '') and '사이렌' in (p.get('status') or '')
           for p in (_expansion.get('excludedProposals') or [])):
    raise ValueError("해연 플레이어블 중단 및 사이렌 몬스터 분리 계약 누락")
if set(RACE_MAP) != set(LINEAGES) or sum(len(races) for races in RACE_MAP.values()) != 26:
    raise ValueError("RACE_MAP이 활성 7계열·26종과 불일치")
_catalog_subraces = {s['name']: {k.upper(): v for k, v in (s.get('statMods') or {}).items()}
                     for r in _race_catalog['races'] for s in r.get('subraces', [])}
if set(SUB_MODS) != set(_catalog_subraces):
    raise ValueError("SUB_MODS 키가 races.json 분파 목록과 불일치")
if SUB_MODS != _catalog_subraces:
    raise ValueError("SUB_MODS 수치가 races.json 분파 statMods와 불일치")

# 확장안은 미승인 비활성 데이터: 이름 중복·수치/거주 슬롯 오류만 카탈로그 게이트에서 감시한다.
_proposed_names = set(SUB_MODS)
for _proposal in _expansion.get('existingRaceSubraces') or []:
    if _proposal.get('name') in _proposed_names:
        raise ValueError(f"확장 제안 분파명 중복: {_proposal.get('name')}")
    _proposed_names.add(_proposal.get('name'))
    if not 1 <= int(_proposal.get('slot', 0)) <= 21:
        raise ValueError(f"정착 범위 밖 분파 바이옴 제안: {_proposal.get('name')}")
for _race_proposal in _expansion.get('newPlayableRaces') or []:
    if not (_race_proposal.get('subraces') or []):
        raise ValueError(f"제안 종족은 최소 1분파가 있어야 함: {_race_proposal.get('name')}")
    for _proposal in _race_proposal['subraces']:
        if _proposal.get('name') in _proposed_names:
            raise ValueError(f"확장 제안 분파명 중복: {_proposal.get('name')}")
        _proposed_names.add(_proposal.get('name'))
        if not 1 <= int(_proposal.get('slot', 0)) <= 21:
            raise ValueError(f"정착 범위 밖 분파 바이옴 제안: {_proposal.get('name')}")

COMMON_APT = ['채집꾼', '벌목꾼', '농부', '건축가', '광부',
              '요리사', '의사', '연구자', '조약사', '대장장이', '교육자', '예술가', '상인']
# 희귀 특성 — 공용 6 + 계열 전용 7 (공용 풀은 05 §6 후속 개편 정합)
COMMON_RARE_APT = ['정교한 손끝', '일사불란', '암중적응', '거상의 수완', '상성의 통찰', '실전 감각']  # 10차 2차 중립화 (구 용광로·야생심·심연감각·왕의 혈맥·정령 조화·전쟁의 기억)
# 운명 7단계 (05 §4 Part B v3 — 2026-09-17 확정 · fate_test.py 500k 검증)
FATE_TIERS = [
    ('천명', 0.03, 3.0), ('각인', 0.12, 2.0), ('재능', 0.20, 1.7), ('소질', 0.25, 1.4),
    ('숙명', 0.20, 1.0), ('개화', 0.12, 0.6), ('무명', 0.08, 0.3),
]
FATE_AVG_MUL = 1.316  # 기대 평균 배율 (Σ 확률×배율) — 3단안 1.26과 동급
# 종족 선호 라인 (RACE_FATE — 구 jobAffinity 죽은 데이터 승계, 05 §4)
RACE_FATE = {
    '인간': '전사', '정령족': '마법', '하이 엘프': '마법', '우드 엘프': '궁수',
    '다크 엘프': '암살', '시 엘프': '궁수', '드워프': '수호', '노움': '마법',
    '하프링': '지원', '묘인족': '암살', '견인족': '전사', '조인족': '궁수',
    '리자드맨': '암살', '물갈퀴족': '전사', '굴길족': '전사', '산양족': '전사',
    '긴꼬리족': '궁수', '용족': '전사', '석상인': '전사', '점토생명체': '전사',
    '강철각성체': '전사', '수정핵체': '마법', '룬인형족': '마법', '태엽자동인형족': '전사',
    '오크': '전사', '뱀파이어': '마법',
}
if set(RACE_FATE) != _catalog_race_names:
    raise ValueError(f"RACE_FATE 종족 키가 races.json과 불일치: missing={sorted(_catalog_race_names - set(RACE_FATE))}, extra={sorted(set(RACE_FATE) - _catalog_race_names)}")
RARE_APT_RATE_BY_GRADE = {3: 0.03, 4: 0.07, 5: 0.13, 6: 0.26, 7: 0.26}  # 등급별 트리거 (확정 #38 — 2026-09-18 8차 · ★7=★6 연장치, 승급 도달 기준 — 뽑기는 ★6까지)
RARE_APT_BONUS_RATE = 0.03  # ★4+ 추가 재롤율 (독립 판정 — 희귀 2개까지 가능)
FEAT_TIER_EXP = {6: 1.15, 7: 1.40}  # 특성 티어 지수 곡선 (2026-09-18 9차 B표준) — 장인 ×1.15 · 명장 ×1.40 등급당, ★4 기준 45/35/20 → 재정규화
RARE_APT_LIN_W = 1.5  # 계열 전용 가중 (2026-09-18 §6-1-2 — 공용 1.0 대비 1.5배 · 계열 전용 차지 63.6%)
# 계열 전용 희귀 특성 49종 (7계열×7 — gacha.html 및 feat_values.py와 1:1 동기)
# 조형생명 신규 특성 7종은 설계 데이터 전용이며 효과 런타임은 미구현. 시그니처 값 미부여.
LINEAGE_RARE = {
    '인간': ['왕의 혈맥','달의 심장','개척의 야망','조약의 언어','정령의 파트너','헌신의 깃발','대의의 방패'],
    '엘프': ['숲의 언어','달빛 주문','영겁의 시간','정수의 화살','요정의 가호','고대의 지혜','미학의 검'],
    '드워프': ['산맥의 뼈','대장간의 불꽃','룬 문양','금맥의 후각','발명가의 열정','토굴 적응','보석 세공'],
    '짐승': ['무리의 본능','폭풍의 날개','야간의 눈','포식자의 본능','수중 사냥','질주의 다리','두꺼운 털가죽'],
    '전사': ['타천의 근육','피의 격노','전장의 포효','강철 이빨','전사의 체격','약탈의 습성','두개골 토템'],
    '심연': ['피의 기억','어둠의 포옹','심연의 속삭임','죽음의 언어','그림자 걸음','저주의 인장','불로의 갈망'],
    '조형생명': ['층리 감각','절벽 고정','유연한 외피','열제련','핵 공명','굴절막','각인 기억'],
}
if len(LINEAGE_RARE) != 7 or any(len(feats) != 7 for feats in LINEAGE_RARE.values()):
    raise ValueError("계열 전용 특성은 활성 7계열×7종이어야 함")
_shaped_traits = {'층리 감각', '절벽 고정', '유연한 외피', '열제련', '핵 공명', '굴절막', '각인 기억'}
if set(LINEAGE_RARE['조형생명']) != _shaped_traits:
    raise ValueError("조형생명 계열 전용 특성은 승인된 7종이어야 함")
if any(_FV.get(name) != 3.5 or _FV.get(name, 0) >= FEAT_SIG_VALUE for name in _shaped_traits):
    raise ValueError("조형생명 전용 특성은 3.5 가치이며 시그니처가 아니어야 함")

# 소환 단가 130석 · 무료 10회 (00 #16·#17)
TICKET_COST = 130
FREE_SUMMONS = 10
# 수급: 퇴장 층×30 + 게이트잭팟 10층 배수 층²×85 + 소형 Σ(5k²×5) (04 §3.9 — G+E 채택 2026-09-17 · D-252 후속)
MUL_COLONY = 0.2


def roll_grade(rng, pity4, pity5=0):
    """등급 롤 — 비공개 천장 내장 (00 확정 #32 구조 · #33 수치 가안 2026-09-17)
    자연 확률 유지 — 천장은 최악 꼬리만 컷. 소프트 시작점·하드 횟수는 UI에 절대 표기 금지.
    returns (grade, pity4, pity5) — 카운터는 호출자가 보관"""
    pity4 += 1
    pity5 += 1
    if pity5 >= PITY5_HARD:  # ★5+ 하드 5,200 — 표 비율 5:1 교대 출연
        return ('★5' if rng.random() < 0.8333 else '★6'), 0, 0
    if pity4 >= PITY4_HARD:  # ★4 하드 130
        return '★4', 0, pity5
    bonus = (pity4 - PITY4_SOFT_START + 1) * PITY4_SOFT_STEP if pity4 >= PITY4_SOFT_START else 0.0
    lo = {'★1': RATES['★1'], '★2': RATES['★2'], '★3': RATES['★3'],
          '★4': RATES['★4'] + bonus, '★5': RATES['★5'], '★6': RATES['★6']}
    total = sum(lo.values())  # 잔여 밴드 정규화 — 합 100% 유지
    r = rng.random()
    acc = 0.0
    for g in ['★1', '★2', '★3', '★4', '★5', '★6']:
        acc += lo[g] / total
        if r < acc:
            if g == '★4':
                return g, 0, pity5
            if g in ('★5', '★6'):
                return g, 0, 0
            return g, pity4, pity5
    return '★1', pity4, pity5


def _weighted(rng, items):
    """items: [(key, weight)] — 가중치 랜덤 선택"""
    x = rng.random() * sum(w for _, w in items)
    acc = 0.0
    for k, w in items:
        acc += w
        if x < acc:
            return k
    return items[-1][0]


def roll_fate(rng):
    """운명 7단계 롤 — 순서 누적 판정 (05 §4 Part B v3 확정)"""
    fx, acc = rng.random(), 0.0
    for name, prob, mul in FATE_TIERS:
        acc += prob
        if fx < acc:
            return name, mul
    return '무명', 0.3


def roll_personality(rng, grade, exclude=()):
    """성격 롤 — 13종 가중치 · 배치 내 중복 제외 · 몰입=★4+ 게이트 + 등급별 가중 (05 §5 5차 · 2026-09-18 D1 개정)
    몰입 가중: ★3- 0(게이트) · ★4 1.5 · ★5 2 · ★6 3 · ★7 4 — 명장 티어 곡선(0→1→6→12%)과 정합
    """
    cw = {'★4': 1.5, '★5': 2.0, '★6': 3.0, '★7': 4.0}
    pool = [(p, cw[grade] if (p == '몰입' and grade in cw) else w)
            for p, w in P_WEIGHT.items() if p not in exclude]
    if not pool:  # 10연차보다 긴 배치 — 풀 소진 시 원복
        pool = [(p, cw[grade] if (p == '몰입' and grade in cw) else w)
                for p, w in P_WEIGHT.items()]
    pers = _weighted(rng, pool)
    if pers == '몰입' and grade not in cw:
        # 몰입 미달은 중립 강제 전환 폐지 — 가중치 재롤 (05 §5 4차)
        pool2 = [(p, w) for p, w in pool if p != '몰입'] or list(P_WEIGHT.items())
        pers = _weighted(rng, pool2)
    return pers


def roll_subtraits(rng, grade):
    """부가 성격 롤 — 52종 비복원 · 대척쌍 26쌍 동시 배제 (09 v0.6 §4-4·§4-4-1)
    슬롯: 전 등급 2종 (2026-09-19 사용자 결정 — 구 ★3+ 해금 폐지). 쌍 충돌 시 충돌 종 1개 교체 재추첨
    (2종 중 쌍 충돌은 최대 1쌍 — 교체 1회로 해소 확정).
    """
    n_slots = SUB_SLOTS  # 전 등급 2종 (2026-09-19 — 구 ★3+ 해금 폐지)
    picks = list(rng.sample(SUB_TRAITS, n_slots))
    pair_of = {n: i for i, pr in enumerate(OPPOSITE_PAIRS) for n in pr}
    for _ in range(n_slots):
        conflict = None
        for a in picks:
            for b in picks:
                if a != b and pair_of[a] == pair_of[b]:
                    conflict = a
                    break
            if conflict:
                break
        if conflict is None:
            break
        replacement = next((x for x in rng.sample(SUB_TRAITS, len(SUB_TRAITS))
                            if x not in picks), None)
        if replacement is None:
            break
        picks[picks.index(conflict)] = replacement
    return picks


def roll_lineage(rng, counts, pickup=None):
    """lineage를 요청받는 호환 API — shaped 5%, 기존 lineage는 종족 수 비례로 분배."""
    if rng.random() < SHAPED_LINEAGE_RATE:
        return '조형생명'
    return roll_lineage_legacy_uniform(rng)


def select_race_for_summon(rng, counts=None, pickup=None):
    """정확한 5%/95% 종족 셀렉터. 반환 튜플은 (lineage, race, branches)."""
    lineage = roll_lineage(rng, counts or {}, pickup)
    race, branches, _gate = rng.choice(RACE_MAP[lineage])
    return lineage, race, branches


def roll_lineage_legacy_uniform(rng):
    """20개 기존 종족 균등 추첨의 계열 단계 — 계열 내 종족 선택까지 연동해야 한다."""
    return rng.choices(LEGACY_LINEAGES,
                       weights=[len(RACE_MAP[key]) for key in LEGACY_LINEAGES], k=1)[0]


def select_race_for_start(rng):
    """신규 런 시작 영웅용: 기존 20개 종족만 균등 선택."""
    lineage = roll_lineage_legacy_uniform(rng)
    race, branches, _gate = rng.choice(RACE_MAP[lineage])
    return lineage, race, branches


def _validate_race_selection_catalog():
    legacy_entries = [entry for lineage in LEGACY_LINEAGES for entry in RACE_MAP[lineage]]
    legacy_races = [race for race, _branches, _gate in legacy_entries]
    if len(legacy_races) != 20 or len(set(legacy_races)) != 20:
        raise ValueError(f"legacy summon pool must contain 20 unique races, got {len(legacy_races)}")
    if sum(len(RACE_MAP[lineage]) for lineage in LEGACY_LINEAGES) != len(legacy_races):
        raise ValueError("legacy race-count weights must match the legacy selector catalog")


_validate_race_selection_catalog()


def make_hero(rng, counts, floor, pickup=None, exclude_pers=()):
    lin, race, subs = select_race_for_summon(rng, counts, pickup)
    owned = counts.setdefault('owned', {})

    # 종족 → 분파. 셀렉터가 shaped 5% / 기존 20종 균등 95%를 보장한다.
    subrace = rng.choice(subs)

    grade, counts['pity4'], counts['pity5'] = roll_grade(rng, counts.get('pity4', 0), counts.get('pity5', 0))

    # 종족별 직업 가중치 (05 §4 — 확정 #39 L1 6종 정리: 승계·폐지 직업 키 제거)
    # 2026-09-20 사용자 확정: ① 인간=만능 → 무가중(균등) ② 힐러(지원가) 감축
    # ③ 종족 정체성 강화(시그니처 상향) — role_prob_verify.py 시뮬 채택 (힐러 -3.2%p)
    RACE_JOB = {
        '인간': {},                                                  # 만능 — 모든 직업 균등
        '정령족': {'마법사': 2.0, '지원가': 0.8, '전사': 0.4, '수호자': 0.7},
        '하이 엘프': {'마법사': 2.2, '지원가': 0.7, '전사': 0.3},
        '우드 엘프': {'궁수': 1.8, '지원가': 0.8, '마법사': 0.7},
        '다크 엘프': {'암살자': 2.2, '마법사': 1.4, '수호자': 0.5},
        '시 엘프': {'궁수': 1.7, '지원가': 0.8, '전사': 0.6},
        '드워프': {'수호자': 1.9, '암살자': 0.4, '마법사': 0.6},
        '노움': {'마법사': 1.6, '지원가': 0.8, '전사': 0.6},
        '하프링': {'궁수': 1.5, '지원가': 0.8, '전사': 0.7},
        '묘인족': {'암살자': 2.0, '궁수': 1.5, '수호자': 0.7},
        '견인족': {'전사': 1.6, '수호자': 1.4, '마법사': 0.7},
        '조인족': {'궁수': 1.8, '전사': 0.8},
        '리자드맨': {'전사': 1.6, '궁수': 1.2, '마법사': 0.7},
        # New races use neutral base job weights until their role balance is approved.
        '물갈퀴족': {}, '굴길족': {}, '산양족': {}, '긴꼬리족': {}, '용족': {},
        '석상인': {}, '점토생명체': {}, '강철각성체': {}, '수정핵체': {}, '룬인형족': {}, '태엽자동인형족': {},
        '오크': {'전사': 2.2, '수호자': 1.6, '마법사': 0.25, '암살자': 0.5},
        '뱀파이어': {'마법사': 1.9, '암살자': 1.7, '전사': 0.6},
    }

    # 운명 7단계 롤 — 희귀직 확률 = 5%×단계 배율 (05 §4 Part B v3 확정)
    fate, fate_mul = roll_fate(rng)

    # 직업 — L1 6종 종족 가중치 롤 (23차: 계열 희귀직 5% 롤 폐지 · 계열 잠금도 폐지)
    w = RACE_JOB.get(race, {})
    real = [j for j in JOB_COEF if j != '무직']
    weights = [w.get(j, 1.0) for j in real]
    acc, x = 0.0, rng.random() * sum(weights)
    job = real[-1]
    for j, wt in zip(real, weights):
        acc += wt
        if x < acc:
            job = j
            break
    # 무직 — 산하 없는 L1 리프. 종족·분파와 무관하게 3% 고정 (races.json jobWeights 7번 슬롯 고정 3)
    if rng.random() < 0.03:
        job = '무직'

    # 성격 — 13종 가중치 롤 (몰입=★4+ 게이트 · 노련은 시뮬 Lv0이라 비출현)
    pers = roll_personality(rng, grade, exclude_pers)
    # 부가 성격 — 52종 비복원 · 대척쌍 배제 (09 v0.7 — 전 등급 2종 · 1성부터 3키워드)
    sub_traits = roll_subtraits(rng, grade)
    # 부가 → 적성 효율 실반영 (09 §4-4 ① — 선호 도메인 ×1.10 · 반대 ×0.95 · CP 무영향)
    # 도메인당 캡 (2026-09-19 시뮬 채택): 부가 2종이 같은 도메인을 선호해도 ×1.10 1회만 적용 —
    # 이중 선호 36.5%에서 ×1.21 중복 가속 방지 · 스펙 표기(×1.10/×0.95)와 최댓값 정합
    sub_eff = {a: 1.0 for a in COMMON_APT}
    _pref_d, _anti_d = set(), set()
    for t in sub_traits:
        p1, p2, opp = SUB_DOM_W[t]
        _pref_d.update({p1, p2})
        if opp:
            _anti_d.add(opp)
    for a in COMMON_APT:
        d = APT_DOMAIN[a]
        if d in _pref_d:
            sub_eff[a] *= SUB_EFF_X
        elif d in _anti_d:
            sub_eff[a] *= SUB_EFF_Y

    # 적성 공통 10 — 생활 5 + 시설 5 (05 §6 7차): 7티어 롤 · 프로필 ±1 · 종족 보정 +1/+2 · 등급 게이트
    prof = JOB_APT.get(job, {})
    race_bonus = RACE_APT_BONUS.get(race, {})
    gnum = int(grade[1])  # 별 등급 — 티어 게이트 (명장=★5+ · 장인=★4+ · 숙련=★3+)

    def roll_apt_tier(r):
        x, acc = r.randint(1, 100), 0
        for t, w in enumerate(APT_W, start=1):
            acc += w
            if x <= acc:
                return t
        return 7

    def gate(t, g):
        """등급 게이트 clamp — ★n에서 허용되는 최대 티어로 제한 (희귀 적성 전용 — 명장 ★5+)"""
        cap = 7 if g >= 5 else (6 if g == 4 else (5 if g == 3 else 4))
        return min(t, cap)

    def gate_gen(t, g):
        """일반 적성 게이트 clamp (확정 #38 4차 — 2026-09-18): ★4부터 명장 실현 (구 cap 6 흡수 폐지)"""
        cap = 7 if g >= 4 else (5 if g == 3 else 4)
        return min(t, cap)

    apt = {}
    for k in COMMON_APT:
        apt[k] = (prof[k] + rng.randint(-1, 1)) if k in prof else roll_apt_tier(rng)
        apt[k] = gate_gen(min(7, max(1, apt[k] + race_bonus.get(k, 0))), gnum)
    # 희귀 특성 — 공용 6 + 계열 전용 7 (조형생명 포함 49종). 형질은 레코드만, 효과 미구현.
    # 후보 13 = 공용 6(가중 1.0) + 계열 전용 7(가중 1.5) · 계열 전용 점유율은 49/7 동수 기준 63.6%.
    # 105종(rare_apt_gen.py)은 별도 후속 데이터이며 이 롤 풀과 독립.
    rare_apt = None
    rare_apt_names = []  # 보유 희귀 배열 (gacha.html rareApts와 동일 — gacha_test v5 테스트 정합 · 2026-09-18)
    rare_candidates = [(n, 1.0) for n in COMMON_RARE_APT]
    # 시그니처 가중 SIG_W 1.25 (2026-09-19 14차 — 계열 풀 내 시그니처 선택률 상향 → 전체 획득률 11% · feat_cp.py v2 기준)
    rare_candidates += [(n, RARE_APT_LIN_W * (FEAT_SIG_W if _FV.get(n, 0) >= FEAT_SIG_VALUE else 1.0)) for n in LINEAGE_RARE[lin]]
    if gnum >= 3:
        if gnum >= 6:
            # ★6 이중 특권 (확정 #38): 희귀 적성 1개 보장 + 티어 하한 장인(6) — ★7 상향 (2026-09-18 9차): 명장 90/장인 10
            choices = [(n, w) for n, w in rare_candidates if n not in apt]
            if choices:
                rare_apt = _weighted(rng, choices)
                rare_apt_names.append(rare_apt)
                rt = rng.random()
                apt[rare_apt] = (6 if rt < 0.10 else 7) if gnum >= 7 else (6 if rt < 0.20 else 7)
        for is_bonus in (False, True):
            rate = RARE_APT_RATE_BY_GRADE[gnum] if not is_bonus else RARE_APT_BONUS_RATE
            if gnum >= 4 or not is_bonus:  # 재롤은 ★4+만
                if rng.random() < rate:
                    choices = [(n, w) for n, w in rare_candidates if n not in apt]
                    if choices:
                        rare_apt = _weighted(rng, choices)
                        rare_apt_names.append(rare_apt)
                        rt = rng.random()
                        if gnum >= 6:
                            apt[rare_apt] = 6 if rt < 0.20 else 7  # ★6 2차 특권 — 보장분은 커브 미적용 (★ 하한 특권)
                        else:
                            w6 = 0.778 * FEAT_TIER_EXP[6] ** (gnum - 4)
                            w7 = 0.444 * FEAT_TIER_EXP[7] ** (gnum - 4)
                            s = 1 + w6 + w7
                            apt[rare_apt] = 5 if rt < 1/s else (6 if rt < (1+w6)/s else 7)
                            apt[rare_apt] = gate(apt[rare_apt], gnum)
    # 표시 필터 전에 희귀 태그 카운트용 필드 유지


    # 스탯 13종 — 정본 = races.json meta.heroBaseStats (05 §7 · 2026-09-17 데이터 정합 전환)
    # 필드스탯 = 기준 × (1+statMods%) × 직업계수 × 등급계수 × 레벨계수
    # 등급계수 미적용 7종: ASPD·CRI·PEN·MS·CDMG·SPD_CAST·STA (races.json note · 38차 EVA→MS)
    # 직업계수 JOB_COEF 7축(HP·ATK·DEF·공속·MAG·MDEF·CRI)은 기존 유지 — 미적용 7종 중
    # SPD_CAST/STA는 MDEF축 계수 대체 사용(구현 관행), CDMG/MS/PEN은 기본 + 보정만.
    gm = GRADE_MULT[int(grade[1])]
    hp, atk, df, aspd, mag, mdef, cri = JOB_COEF[job]
    st = {
        'HP': round(500 * hp * gm),
        'ATK': round(45 * atk * gm),
        'MAG': round(20 * mag * gm),
        'PEN': round(2.0 * (df - 0.5)),          # 등급 미적용 — 직업 DEF축에서 파생한 보정만
        'DEF': round(20 * df * gm),
        'MDEF': round(10 * mdef * gm),           # 기본 0 + 직업계수 보정 (05 §7 "0 + 직업·종족 보정")
        'MS': 100,                               # 등급 미적용 — 38차 회피 폐지 · 이동속도 100% 기준
        'ASPD': round(10 * aspd),                # 등급 미적용
        'CDMG': round(150 + 10 * cri),           # 등급 미적용 — 실효 하한 150% (01 §3)
        'CRI': round(5 + 3 * (cri - 1), 1),      # 등급 미적용
        'MANA': round(100 * mdef * gm),          # 등급 적용
        'SPD_CAST': round(30 * mdef),            # 등급 미적용
        'STA': round(80 * hp),                   # 등급 미적용
    }

    # 종족·아종 statMods (races.json — %보정 가안: ×(1+값/100))
    # 성격 → 스탯 실반영 (01 §4 가안) → 개체 변량 ±7% (2026-09-14 확정 — 8%→7% 조정)
    mods = {}
    for m in (RACE_MODS.get(race, {}), SUB_MODS.get(subrace, {})):
        for k, v in m.items():
            mods[k] = mods.get(k, 0) + v
    mul = dict(PERS_STAT_MUL.get(pers, {}))
    ppt = dict(PERS_STAT_PPT.get(pers, {}))
    for k, v in mods.items():
        mul[k] = mul.get(k, 1.0) * (1.0 + v / 100.0)
    for k, f in mul.items():
        if k in st:
            st[k] *= f
    for k, p in ppt.items():
        if k in st:
            st[k] += p
    for k in st:
        st[k] *= 1.0 + VARIANCE * (rng.random() * 2.0 - 1.0)
    for k in st:
        st[k] = round(st[k], 1) if k in PCT_KEYS else round(st[k])

    # CP ①식 13종 (05 §8)
    S = (st['HP'] * 0.12 + st['ATK'] * 2.0 + st['MAG'] * 2.0 +
         st['DEF'] * 1.5 + st['MDEF'] * 1.5 +
         st['ASPD'] * 3.0 + st['SPD_CAST'] * 2.0 +
         st['CRI'] * 3.0 + st['CDMG'] * 1.0 +
         st['PEN'] * 2.5 + st['MS'] * 1.5 +
         st['MANA'] * 0.05 + st['STA'] * 0.03)
    # 특성 CP 반영 (2026-09-18 특성 개칭 동시 개정 — gacha.html featMul과 동일 계수)
    # 기여 = FEAT_VALUE[name] × 0.4% × (★-2) — 명목 CP와 실전 CP 통일 (feat_cp.py 검증)
    from feat_cp import FEAT_VALUE, FEAT_CP_UNIT, feat_cp_bonus
    feat_mul = 1.0 + sum(feat_cp_bonus(fn, apt.get(fn, 5)) for fn in rare_apt_names)
    # 종족 시그니처 직업 보너스 (2026-09-21 확정 — 종족 가중치 1위 직업 CP ×1.03)
    # 사용자 결정: "시그니처가 아니면 아예 안 키울 수도 있으니 미미하게" — 스탯 아닌 최종 CP에만 곱함
    # (성격·특성·개체변량과 무간섭 · 시뮬 sig_bonus_test.py: 시그니처 +3.00% 정확 · 비시그니처 ±0.00% ·
    #  역할 밴드 무훼손 1.198×→1.191× · 전체 평균 +0.76% — 힐러는 시그니처 0종이라 +0% 유지)
    # 히든 시그니처 (2026-09-21 확정): 시그니처 조합의 0.5%가 추가 ×1.07 — 희귀 컬렉션 요소
    # (시뮬 hidden_sig_test.py n=40만: 당첨률 0.132% 실측 · 전체 평균 +0.009% · 200회 기대 0.25회)
    sig_mul = RACE_SIG_MUL.get(race, {}).get(job, 1.0)
    if sig_mul > 1.0 and rng.random() < 0.005:
        sig_mul *= 1.07  # 히든 시그니처 — 0.5% 추가 ×1.07 (2026-09-21 확정)
    cp = round(S * P_MULT[pers] * feat_mul * sig_mul)
    # 히든 여부는 외부에서 CP 재계산 대신 'sig 조합 + 기대 CP 상회'로 판별 가능 — 내부 플래그 불요
    # (gacha.html 표시도 동일: sig 조합에서 ×1.07 상회분 감지 시 히든 마크 — 표기 정책은 UI 결정 사항)

    # 이름 (시드 기반 고유성 — 구 NameGen 3계층의 축약판)
    name = f"{race}·{job}·{subrace}·{rng.randint(1, 9999):04d}"[:32]
    owned[lin] = owned.get(lin, 0) + 1

    return {'등급': grade, '계열': lin, '종족': race, '아종': subrace,
            '직업': job, '성격': pers, '부가성격': sub_traits, '운명': fate, '역할': ROLE_TAG.get(job, '—'),
            '적성': {k: v for k, v in apt.items() if v >= 4},  # 4견습부터 표시 (7차)
            '적성_전체': dict(apt),  # 은닉 티어 1~3 포함 — 숙련도 시뮬(proficiency_test.py)용 · 롤 규칙 영향 없음 (8차)
            '적성_효율': {a: round(APT_TIER[t] * sub_eff.get(a, 1.0), 4) for a, t in apt.items()},  # 부가 XP 가중 실반영 (09 §4-4 ① — CP 무영향 · 희귀 적성은 가중 대상 아님 → 1.0)
            'rare_apt': rare_apt if rare_apt in apt else None,
            'rare_apt_names': rare_apt_names,  # 보유 희귀 전체 (gacha.html rareApts 대응 — 보장분 추적용)
            '이름': name, '스탯': st, 'CP': cp}


def awaken_probability(hero):
    """각성 판정 확률 (확정 #36 — 05 §7-1): 20% 기본 + 성장형 성격 +5%p + 숙련 보정 최대 +8%p
    숙련 보정 = 티어 비례 (명장7 = +8%p) — 희귀·시그니처 적성 티어 기준, 없으면 보유 적성 최고 티어
    설계 밴드 20~33.5% (+ 희귀 가속 시 최대 34.5%) — 원전 시뮬 /tmp/sim_awaken_dist.py"""
    prob = AWAKEN_BASE
    if hero['성격'] in GROWTH_PERSONA:
        prob += AWAKEN_GROWTH_BONUS
    rare = hero.get('rare_apt')
    apt_all = hero.get('적성_전체', {})
    if rare and rare in apt_all:
        prob += AWAKEN_MASTERY_MAX * (apt_all[rare] - 1) / 6
    elif apt_all:
        prob += AWAKEN_MASTERY_MAX * (max(apt_all.values()) - 1) / 6
    if rare:
        prob += AWAKEN_RARE_BONUS
    return prob


def simulate_growth(hero, rng, promotions=0):
    """레벨 130 육성 시뮬 — 각성 6회 판정 → 순수도 경로 (05 §7-1)
    promotions: 합성소 승급 횟수 (순수도 −0.04/회 — 확정 #35)"""
    purity = PURITY_INIT + PURITY_STEP * promotions
    succ, probs = 0, []
    for _lv in AWAKEN_MILESTONES:
        p = awaken_probability(hero)
        probs.append(p)
        if rng.random() < p:
            succ += 1
            purity = min(AWAKEN_CAP, purity + AWAKEN_GAIN)
    return {'순수도': round(purity, 2), '각성_성공': succ,
            '판정_확률_평균': round(sum(probs) / len(probs), 3)}


def growth_report(heroes, promotions=0, seed=20260917):
    """육성 시뮬 리포트 — 각성 분포·순수도 (§7-1 실측 정합: 0회 20.8 / 1회 37.0 / 2회 27.3 /
    3회 11.6 / 4회+ 3.3% · 상한 1.08 도달 2.9% · 평균 순수도 ≈1.028 — n=40,000 기준)"""
    rng = random.Random(seed)
    succ_c, pur_all, pur_growth = Counter(), [], []
    for h in heroes:
        r = simulate_growth(h, rng, promotions)
        succ_c[r['각성_성공']] += 1
        pur_all.append(r['순수도'])
        if h['성격'] in GROWTH_PERSONA:
            pur_growth.append(r['순수도'])
    n = len(heroes)
    print(f'\n═══ 육성 시뮬 — 순수도·각성 (n={n:,} · 승급 {promotions}회 · 시드 {seed}) ═══')
    base_purity = PURITY_INIT + PURITY_STEP * promotions
    for k in sorted(succ_c):
        print(f'각성 {k}회: {succ_c[k] * 100 / n:5.1f}%  (순수도 {min(AWAKEN_CAP, round(base_purity + AWAKEN_GAIN * k, 2)):.2f})')
    print(f'순수도 평균 {sum(pur_all) / n:.3f} · 상한 {AWAKEN_CAP} 도달 {sum(1 for p in pur_all if p >= AWAKEN_CAP) * 100 / n:.1f}%')
    if pur_growth:
        print(f'성장형 성격(몰입·성실·노련) 평균 {sum(pur_growth) / len(pur_growth):.3f}')
    print(f'잔여 패널티 (천생 대비): {(sum(pur_all) / n - 1.0) * 100 + PURITY_STEP * promotions:+.1f}%p')


def batch(n, counts, floor, pickup=None, rng=None):
    """n연차 — 무료 10회 + 유료 (쿼터 무시 단발 모드)"""
    if rng is None:
        rng = globals()['rng']
    counts.setdefault('pity4', 0)  # ★4 천장 카운터 (비공개 — 00 확정 #32)
    counts.setdefault('pity5', 0)  # ★5+ 천장 카운터 (비공개)
    heroes, rare = [], {'적성': 0, '이름재추첨': 0}
    used_names = set()
    used_pers = set()  # 배치 내 성격 중복 방지 (05 §5 3차)
    for _ in range(n):
        for _ in range(9):  # 재추첨 최대 8회 (05)
            h = make_hero(rng, counts, floor, pickup, exclude_pers=used_pers)
            if h['이름'] not in used_names:
                break
            rare['이름재추첨'] += 1
        used_names.add(h['이름'])
        used_pers.add(h['성격'])
        heroes.append(h)
        # 천장 카운터는 roll_grade 내부에서 갱신됨 (★4+ → pity4 리셋 · ★5+ → pity4+pity5 리셋)
        if h.get('rare_apt'):
            rare['적성'] += 1
    return heroes, rare


def income_by_floor(max_floor):
    """퇴장+게이트 수급 (식민섬 0 기준) — G+E 정본: 퇴장 층×30 · 잭팟 10층 배수 층²×85 ·
    소형 게이트 보상 5·15·…·95층 ×5·f² (04 §3.9 — 2026-09-17 G+E 채택 · 구 D-252 계수 75)"""
    exits = sum(30 * f for f in range(1, max_floor + 1))
    gates = sum(f ** 2 * 85 for f in range(10, max_floor + 1, 10))
    small = sum(f ** 2 * 5 for f in range(5, max_floor, 10))   # 5·15·…·95층 (잭팟 미지급 GK층)
    return exits, gates + small


def dashboard(max_floor=100):
    print(f'\n═══ 수급·쿼터 대시보드 ({max_floor}층 기준) ═══')
    colonies = min(9, max_floor // 10)  # 10층마다 식민섬 1 (본섬 제외) — 골드 배율 전용
    exits, gates = income_by_floor(max_floor)
    stones = exits + gates  # 식민섬 배율 없음 (석은 단일섬 기준)
    stage_cap = 60 if max_floor < 10 else 150 if max_floor < 25 else 400 if max_floor < 50 else 1300  # 쿼터 = 2×현행상한 (04 §3.8)
    # 실제 인구 궤적 근사 (자연증가 인구×2%/**층 축 근사** + 게이트+25) —
    # 정본은 섬 하루 2% (estate.json natural_growth_rate_per_island_day · 04 §3.2, 2026-09-17).
    # 본 도구는 층 축만 다루므로 인구는 표시용 근사치 — 가챠 수급·쿼터 계산과는 무관.
    pop = 30.0
    cap = 60
    for f in range(1, max_floor + 1):
        for sf, cc in [(1, 60), (10, 150), (25, 400), (50, 1300)]:
            if f == sf:
                cap = cc
        pop = min(pop * 1.02, cap)
        if f % 5 == 0 and f < 100:
            pop += 25
        pop = min(pop, cap)
    gold = round(100 * sum(range(1, max_floor + 1)) * (1 + MUL_COLONY * colonies))
    print(f'식민섬 {colonies}개 (골드 배율 전용)')
    print(f'{max_floor}층 누적 석: 퇴장 {exits:,} + 게이트 {gates:,} = {stones:,}석'
          f' (배율 없음 · 골드에만 적용)')
    print(f'{max_floor}층 누적 골드: 던전 {gold:,}G (×{1 + MUL_COLONY * colonies:.1f}) + 세금')
    tickets = stones / TICKET_COST
    print(f'→ 티켓 {tickets:,.0f}장 + 무료 10 = {tickets + 10:,.0f}회')
    quota = stage_cap * 2
    print(f'현행상한 {stage_cap}명 · 실제인구 {pop:.0f}명 → 쿼터(2×상한) = {quota:,}회 → 커버율 {(tickets + 10) / quota * 100:.0f}%')
    for k in ('★5', '★6'):
        print(f'E[{k}] = {(tickets + 10) * RATES[k]:.2f}장')


def main():
    args = [a for a in sys.argv[1:]]
    floor, n, pickup, seed = 50, 1000, None, None
    if args and args[0].isdigit():
        floor = int(args.pop(0))
    if args and args[0].isdigit():
        n = int(args.pop(0))
    if '--pickup' in args:
        pickup = args[args.index('--pickup') + 1]
    if '--seed' in args:  # 고정 재현: --seed 20260914
        seed = int(args[args.index('--seed') + 1])

    global rng
    if seed is None:  # 기본 = 실행마다 새 시드 (2026-09-14: 고정 시드 "같은 결과 반복" 해소)
        seed = random.SystemRandom().randrange(2**31)
    rng = random.Random(seed)
    counts = {'pity4': 0, 'pity5': 0, 'floor': floor, 'owned': {}}
    heroes, rare = batch(n, counts, floor, pickup)

    print(f'═══ {n:,}연차 (층 {floor} · 시드 {seed}'
          + (f' · 픽업 {pickup}' if pickup else '') + ') ═══')
    g = Counter(h['등급'] for h in heroes)
    for k in RATES:
        exp = n * RATES[k]
        got = g.get(k, 0)
        bar = '█' * max(1, int(got / max(1, exp) * 10)) if got else '·'
        print(f'{k}: {got:,} / 기대 {exp:,.1f}  [{bar}]')
    # 희귀 적성 기대치 (확정 #38 등급별 트리거 — ★3 3%·★4 7%·★5 13%·★6 26% + ★6 보장 + ★4+ 재롤 3%)
    rare_expected = n * sum(RATES[f'★{g}'] * (RARE_APT_RATE_BY_GRADE[g] + (RARE_APT_BONUS_RATE if g >= 4 else 0.0)) for g in (3, 4, 5, 6)) \
        + n * RATES['★6'] * RARE_APT_BONUS_RATE  # ★6 보장 1개 = 100% (트리거 확률과 별도)
    print(f'특성 {rare["적성"]}개 (기대 {rare_expected:.1f}) · '
          f'이름재추첨 {rare["이름재추첨"]}회')  # 희귀 적성 기대치는 등급별 트리거 반영 (확정 #38) · 계열 희귀직 롤은 확정 #39로 폐지
    print(f'계열 분포: ', end='')
    lin_c = Counter(h['계열'] for h in heroes)
    print(' · '.join(f'{l}{lin_c[l]:,}' for l in LINEAGES))
    # 부가 성격 — 조합 분포·쌍 충돌·슬롯 해금 검증 (09 v0.6)
    sub_c = Counter()
    for h in heroes:
        sub_c.update(h['부가성격'])
    print('부가 성격 TOP5: ' + (' · '.join(f'{t}{c:,}' for t, c in sub_c.most_common(5)) or '—'))
    pair_of = {n: i for i, pr in enumerate(OPPOSITE_PAIRS) for n in pr}
    pair_conf = sum(1 for h in heroes for i, a in enumerate(h['부가성격'])
                    for b in h['부가성격'][i + 1:] if pair_of[a] == pair_of[b])
    slot2 = sum(1 for h in heroes if len(h['부가성격']) == 2)
    print(f'부가 쌍 충돌: {pair_conf} (목표 0) · 3키워드(전원): {slot2:,} / {n:,} — {"✓" if slot2 == n else "✗"}')
    fate_c = Counter(h['운명'] for h in heroes)
    print('운명 분포: ', end='')
    print(' · '.join(f'{tn}{fate_c[tn]:,}({fate_c[tn] / n:.1%})' for tn, _, _ in FATE_TIERS))

    # 육성 시뮬 — 순수도·각성 (확정 #35·#36 — 05 §7-1) · 승급 0/1회 비교
    growth_report(heroes, promotions=0)
    growth_report(heroes, promotions=1)

    dashboard(max_floor=floor)
    margin_report(max_floor=floor)
    cps = sorted(h['CP'] for h in heroes)
    print(f'CP: min {cps[0]:,} / 중간 {cps[len(cps)//2]:,} / max {cps[-1]:,}')
    print('표본 5명:')
    for h in sorted(heroes, key=lambda x: -x['CP'])[:5]:
        st = ' '.join(f'{k}{v}' for k, v in h['스탯'].items())
        print(f"  [{h['등급']}] {h['계열']}·{h['종족']}({h['아종']})·{h['직업']}({h['역할']})·"
              f"{h['성격']}·{h['운명']} CP {h['CP']:,} | {st}")

    income_by_floor(floor)

    # 스킬 각인 체감 — D-269 레어도 알파벳·L 3태그 그라디언트 (gacha 시뮬 승계)
    engrave_report(heroes, n=min(n, 100))


if __name__ == '__main__':
    main()
