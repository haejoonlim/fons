#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sim_economy.py — FONS 영지 재화 흐름 시뮬레이터 (가안 검증용)
GDD_v8.0_04_영지.md §3 상수 기준 · 미정G 튜닝 시 재실행 목적

시나리오:
- baseline: 평시 — 계절·사건·민심 보정 없음 (§3.11 수지표와 동일 조건 · 사건 미발생 근사 —
    사건의 골드 기대효과는 ±가변이라 평시 곡선에 미반영. check_docs가 첫 시나리오를
    baseline으로 파싱하므로 반드시 첫 시나리오 · 궤적 변경 시 04 §3.11 표 동시 갱신)
- stress  : 최악 중첩 (2026-09-17 G-15 재튜닝 — §3.12 층 연동 사건 엔진 + estate.json 겨울 정본 반영)
    · 겨울 전 기간: 식량 수확 ×0.70 (§3.13·estate.json winter.food_yield_mul)
      **+ 농사 성장 정지 (estate.json winter.growth_mul=0.0 — 이전 시뮬에서 누락된 정본)**
    · 흉작 10섬일 주기 3일간 (식량 ×0.70 — §3.12 사건 '흉작'의 지속 발생형 근사)
    · 사건·재해 층 연동 (§3.12 확정 — 25층마다 확정 1회): 화재(구 도적 — 금고-10%+차출 2일 — D-256) →
      폭풍(시설 1동 파괴 → 수리비 건설비 50% 가안 2,500G) → 역병(방치 인구 -5%) → 민심 패널티 순환 ·
      발동 시 민심 -2 (가안). 사건 층 연동 자체는 압박 축(2026-09-17 확정)이고,
      강도(겨울·흉작 계수·사건 흉작 비율)는 G-15 튜닝 노브
    · 민심 25 시작 → 사건 -2 누적으로 20 미달 시 **파업 (§3.14 — 전 생산 정지 5층)**
    · 아사 룰 (§3.14): 식량 0 3섬일 지속 → 인구 -2%/섬일
    최악 순간 생산 배율 = 0.70(채집)×0.70(흉작)×0.90(민심)×(팀-1)/팀 · 농사 0

강도 노브 (G-15 — 시나리오 dict 키):
- winter_mul        겨울 채집·식량수확 계수 (정본 0.70 — estate.json winter.food_yield_mul)
- farm_stop_winter  겨울 농사 성장 정지 (정본 True — estate.json winter.growth_mul=0.0)
- famine_every      흉작 주기 (섬일 · 0=없음)
- famine_mul        흉작 식량 계수 (정본 0.70 — §3.12 사건 '흉작' -30%)
- ev_on             층 연동 사건 엔진 ON/OFF (§3.12 확정 — stress·완화 검증 시나리오만 ON)
- ev_famine_ratio   사건 4회(25·50·75·100층) 중 흉작 사건 비율 (0=없음 · 0.5=반반 · 1.0=전부)
- ev_winter_penalty 겨울 인구 자연감소 (분/섬일 — 역병·한파 상시 압박 가안 · 0=없음)
- ev_every           사건 층 연동 상수 (D-253 정본 25 · G-15 민감도 스윕 — 15/35)
- ev_jitter          사건 발동 간격 지터 (MC — ev_every±x 층 균등 · 정본 None=정확 주기 · ev_mode=cycle에서도 작동)
- ev_mode            "cycle"=D-253 고정 순환(화재→폭풍→역병→민심, 정본 — D-256 기원 제약) · "random"=확률 분포 추첨 (G-15 잔여 검증)
- ev_boon_weight     random 모드 완화 이벤트(풍년·축제 합산 — D-256: 생존자 합류 교체) 비중 — 0=재해 전용 · 재해 4종은 균등 분할
- mc_seed            몬테카를로 시드 (None=결정론 — 정본 시나리오 전부 None이라 궤적 불변)
- pace_jitter        클리어 페이스 지터 (일당 층수 균등 ±x — MC)
- famine_jitter      흉작 주기 지터 (섬일 균등 ±x — MC)
- front_maint        전선 유지비 (G/층/섬일 × max(최고도달-50,0) — 유지비 런기간 의존 재설계 비교 B안 · 정본 off)
- tripwire_maint     전선 유지비 대안 C안 — 최고도달 50층 초과 시 고정 G/섬일 (골드 트립와이어 · 정본 off)
- speed_fee          속공 수수료 (D안 비교 전용 — 층 클리어당 표준 페이스 초과분 × G 부과 · 정본 off)
- pace               페이스 고정 (비교 전용 — 구간별 표준 곡선 대신 층/일 고정 · 정본 off)

가정 (전부 가안 — 문서에 명시된 값 우선, 미정의 값은 §3.11 수지표와 정합되게 보간):
- 런 페이스: 층/일 구간별 (F1-10: 3.0, F11-25: 2.5, F26-80: 2.0, F81-100: 1.5)
- 인구: 수지표 행 정합 보간 (F1:30 → F5:60 → F17:150 → F40:400 → F55:1300)
- 채집팀: 해금층 1/15/35/45/60 (§3.11 가정) · 팀당 150 × (1+층/50) · L6 +15% / L7 +30%
- 농사: 필지 = 인구÷20 × 15식량 · 식당 ×1.2 (10층+)
- 건설비 (미정 → 누적 골드 10~20%선 가안): 전술소 1,000(확정) · F10 3종 각 1,000 ·
  F20 2종 각 3,000 · F30 2종 각 5,000 · 주택 동당 800 + 업글 1,000×Lv
- 업글비 (미정 → 기하급수 가안): L→L+1 = 3,000×2^(L-1) (L1→2 = 3,000 — 10층 밀집 메모와 정합)
- 정책: 우선순위 시설 [소환제단·식당·훈련장] L7 우선, 잉여금으로 순차 업글 · 골드 버퍼 20% 유지
- 소환: 마석 버퍼 10,000 초과분 전량 소환 (티켓 130) · 초회 10 무료 (무료분도 추출 대상) · 배치 36명 제외 전량 추출
- 주민 세금: 플랫 +1G/명·**섬 하루** (estate.json `tax.gold_per_pop_per_island_day` — 2026-09-17 섬일 단위 통일) · 일 단위 정산
- 식량 소비: 주민 1명당 1/**섬 하루** (estate.json `food.consumption_per_pop_per_island_day`) — 클리어 속도 무관
- 식량 생산: 채집(쿨 24섬시간)·농사 둘 다 **일 단위 정산** (§3.3·§3.3-2 — 클리어마다 호출하지 않음) · 필지 = max(초기 3동, 인구//20)
- 승급: 결정·골드 즉시 집행 (★5 파티 5인 → F50 캘리브레이션 목표 · ★6 완성 시점은 설계 목표 아님 — 100층까지 가능하면 충분, 2026-09-15 사용자 결정 — 관측 지표로만 출력)
- 미적용 (의도적 제외): 합성비 할인 -5×(Lv-1)%·추출환원 +10×(Lv-1)% (§3.10) — §3.1-2 캘리브레이션 기준 유지 (시설 보너스는 상향 여유분) · 식민섬 보너스 (§3.8-2 미결) · 재료 매각 · 칙령(채집장려 완화 미적용 — 순수 최악) · 전당의 은혜 (100층 이벤트 — N 미정I)
"""
import sys
from math import floor as fl

# ---------- 상수 (04 §3) ----------
TICKET = 130                    # 소환 티켓 마석
P_GRADE = [0.7004, 0.20, 0.087, 0.012, 0.0005, 0.0001]     # ★1~★6 (확정 #32 · 2026-09-17 — ★4 1.2% + ★3 8.7%)
CRYSTAL = [1, 3, 10, 30, 100, 300]                        # 등급별 영혼 결정
E_CRYSTAL = sum(p*c for p, c in zip(P_GRADE, CRYSTAL))    # 소환 1회 기대 결정
STAFF = 36                      # 배치 수요 상한 (§3.2)
FREE_SUMMONS = 10               # 무료 소환 (00 #17)
PROMO = {                       # 승급 비용 (결정, 골드) — §3.1-2
    (1, 2): (25, 50), (2, 3): (100, 200), (3, 4): (375, 750),
    (4, 5): (1200, 2400), (5, 6): (3000, 5000),
}
PROMO_TOTAL_5 = sum(PROMO[(s, s+1)][0] for s in range(1, 5))   # ★1→★5
PROMO_TOTAL_6 = PROMO_TOTAL_5 + PROMO[(5, 6)][0]               # ★1→★6
GOLD_TOTAL_5 = sum(PROMO[(s, s+1)][1] for s in range(1, 5))
GOLD_TOTAL_6 = GOLD_TOTAL_5 + PROMO[(5, 6)][1]

FACILITIES = 10                 # 유지비 대상 시설 수 (주택·전당 제외)
MP_PER_CRYSTAL = 130            # D-267 §3 단위 앵커 — 1마석 = 130 MP (2026-09-19 사용자 결정)
LEY_RATE = 60                   # D-267 §4 환율 — 1마석 = 60 LEY (담보 발행 배율)
# D-267 §6b 시설별 마나 소비 표 (가안 · MP/섬 하루/시설 1개) — 주택·전당·소환제단 면제
ENERGY_RATE = {"병원": 100, "전술소": 50, "식당": 100, "훈련장": 200, "숙소": 100,
               "연구소": 300, "연금술소": 300, "합성소": 400, "추출소": 400}
MAINT_PER_LV = 10               # G/Lv/섬 하루 (§3.12)
EXPANSION = {10: 3000, 25: 10000, 50: 30000}   # S2/S3/S4 (§3.8)
BUILD = {4: 1000, 12: 3000, 14: 3000, 20: 6000, 30: 6000}  # 시점: 총액 — estate.json build_cost·unlock_floor 정본 (D-263 채택 2026-09-19: 10층 시설 3종 분산 → 12층 훈련장·14층 숙소 — 10층 파산점 해소 · 20층 2동 6,000·30층 2동 6,000 무변경)
UP_LADDER = (3000, 8000, 20000, 40000, 80000, 150000)   # L1→7 사다리 — estate.json upgrade_cost_per_level 정본 (2026-09-18 대조)
UP_COST = lambda l: UP_LADDER[l - 1]            # L→L+1 (estate.json — 구 3000×2^(l-1) 가안 폐기 · 풀업 10시설 318.9만)
PRIORITY = ["소환제단", "식당", "훈련장"]       # L7 우선 정책
GOLD_BUFFER = 0.20

MILESTONES = (10, 17, 25, 50, 55, 60, 80, 95, 100)

# ---------- 시나리오 (§3.5·§3.12·§3.13·§3.14 · G-15 노브 — docstring 참조) ----------
# baseline은 반드시 첫 시나리오 (check_docs.py가 첫 블록을 baseline으로 파싱 — 궤적 불변 계약)
# G+E 채택 (2026-09-17 사용자 결정 — D-252 후속): 잭팟 계수 85 + 게이트 소형 ×5·f² 정본화 —
#   100층 총수급 3,590,250 (퇴장 151,500 + 잭팟 3,272,500 + 소형 166,250) = 티켓 27,617회 (쿼터 106%)
#   50층 586,375석 = 3,956회 (쿼터 156%) · E[★5]@50 1.98 — 아래 후처리 루프로 전 시나리오 기본 적용
#   (jp_* 역사 비교 시나리오만 당시 정본 75 유지)
# G-10 확장비 분할 — D-263 세트 채택 (2026-09-19 사용자 결정): 건설 3층 분산+S2 16층과 병용해야
# 12/14층 지연 지출로 깊어지는 50층 트로프가 P11 한계 내로 유지됨 (미반영 시 stress 최저 -23,306 → 한계 초과)
_SPLIT_G10 = dict(split_expansion=True)
_STRESS_BASE = dict(winter_mul=0.70, farm_stop_winter=True, famine_every=10, famine_mul=0.70,
                    ev_on=True, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=25, **_SPLIT_G10)
SCENARIOS = {
    "baseline": dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                     ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, **_SPLIT_G10),
    "stress":   dict(_STRESS_BASE),
    # 10층 파산점 해결안 3종 (§3.11 발견 1 — 2026-09-15 비교 검증)
    "fixA":     dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                     ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, start_gold=5000),   # A안: 시작 골드 5,000
    "fixB":     dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                     ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, s2_floor=12),        # B안: S2 확장 12층 지연
    "fixB13":   dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                     ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, s2_floor=13),        # B안 변형: S2 확장 13층 지연
    "fixC":     dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                     ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, build_discount=0.5), # C안: 10층 건설비 3종만 50% 감면
    # 완화 장치 검증 (스트레스 동일 조건 + 완화 1개씩 — 2026-09-15 · G-15 재튜닝 시 stress 조건 동기화)
    "mitig_decree": dict(_STRESS_BASE, decree_harvest=True),    # 채집장려 칙령
    "mitig_stock":  dict(_STRESS_BASE, stockpile=True, stockpile_target=500),   # 재고 운영 (저속 클리어)
    "mitig_both":   dict(_STRESS_BASE, decree_harvest=True, stockpile=True, stockpile_target=500),  # 둘 다
    # 클러스터 재설계안 (역사 비교 전용 — 전부 D-251 B안 s2_floor=12 기반 2026-09-15 · D-263 정본 전환 후 기본값은 16)
    "cluster_S1": dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                       ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, s2_floor=12, s3_floor=28),            # S3 확장 28층 지연
    "cluster_S2": dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                       ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, s2_floor=12, split_expansion=True),    # 확장비 분할 50%+3층후 50%
    "cluster_S3": dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                       ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, s2_floor=12, start_gold=2000),         # 시작 골드 2,000 (소액 보완)
    "cluster_S4": dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                       ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, s2_floor=12, split_expansion=True, start_gold=2000),  # 분할+소액 조합
    # 게이트잭팟 주기 비교 (§3.9 — 10층 단위 vs 5층 GK — 2026-09-15)
    "jp_A10":      dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                        ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, jp_every=10, jp_coeff=75),  # 현행: 10층 단위 ×75
    "jp_B5_naive": dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                        ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, jp_every=5,  jp_coeff=75),  # 5층 GK 전면 (계수 무보정)
    "jp_B5_rebal": dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                        ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, jp_every=5,  jp_coeff=40),  # 5층 GK + 계수 40 (총액 보정 — 71,750×40=287만)
    # 5→10층 공백 소형 보상 검증 (D-252 후속 — 2026-09-15): 잭팟 미지급 GK층(5·15·25…)에 소형 지급
    "jp_small_lin": dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                         ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, gate_small=("lin", 5)),  # 게이트층 ×5·f (제안 원안 — 총 2,500)
    "jp_small_sq":  dict(winter_mul=1.0, farm_stop_winter=False, famine_every=0, famine_mul=1.0,
                         ev_on=False, ev_famine_ratio=0.0, ev_winter_penalty=0.0, morale=50, gate_small=("sq", 5)),   # 게이트층 ×5·f² (잭팟 동일 곡선족 — 총 33,250)
    # ── G-15 강도 스윕 (2026-09-17 — 정본 반영 후에도 무력하면 단계적 강화 · 채택 후 stress에 이식) ──
    "g15_B": dict(_STRESS_BASE, winter_mul=0.60, famine_mul=0.60, ev_famine_ratio=0.5),          # 계수 강화 + 사건 흉작 절반
    "g15_C": dict(_STRESS_BASE, winter_mul=0.50, famine_mul=0.50, ev_famine_ratio=0.5),          # 계수 0.5 강화
    "g15_D": dict(_STRESS_BASE, ev_famine_ratio=1.0),                                            # 사건 4회 전부 흉작
    "g15_E": dict(_STRESS_BASE, ev_famine_ratio=0.5, ev_winter_penalty=0.002),                   # +겨울 인구 -0.2%/섬일
}

# G+E 정본 후처리 (2026-09-17 사용자 결정 — D-252 후속): 계수 85 + 소형 ×5·f² 기본 적용
for _k, _v in SCENARIOS.items():
    if _k.startswith("jp_"):
        _v.setdefault("jp_coeff", 75)          # D-252 당시 정본 — 역사 비교 보존
        continue
    _v.setdefault("jp_coeff", 85)              # G+E 정본
    _v.setdefault("gate_small", ("sq", 5))     # 게이트 소형 ×5·f² — 5·15·…·95층
def pop_at(f):
    """수지표 행 정합 보간"""
    if f <= 1: return 30
    if f <= 5: return fl(30 + (60 - 30) * (f - 1) / 4)
    if f <= 17: return fl(60 + (150 - 60) * (f - 5) / 12)
    if f <= 40: return fl(150 + (400 - 150) * (f - 17) / 23)
    if f <= 55: return fl(400 + (1300 - 400) * (f - 40) / 15)
    return 1300

def teams_at(f):
    if f < 15: return 1
    if f < 35: return 2
    if f < 45: return 3
    if f < 60: return 4
    return 5

def pace_at(f):
    if f <= 10: return 3.0
    if f <= 25: return 2.5
    if f <= 80: return 2.0
    return 1.5

# ---------- 시뮬 본체 ----------
def run_sim(name, scn):
    gold, mana, crystal, food = scn.get("start_gold", 200.0), 0.0, 0.0, scn.get("start_food", 100.0)
    energy_spent_mp = 0.0   # D-267 가안 — 은행 에너지 계정 배급량 (MP 누적 · 1마석=130MP · 정본 0=off)
    # ── D-267 은행 3계정 trace (--bank-trace · P13 — 발행·상환·마나 소모의 층별 총장부 검증) ──
    bank_trace = {}
    if scn.get("bank_trace"):
        bank_trace[0] = dict(gold_flowed=0.0, issued=0.0, repaid=0.0, energy_mp=0.0,
                             reserve_cry=0.0, limit_ley=0.0)
    bank_gold_flowed = 0.0   # 은행 환전 계정 총 유입 (층 수입 100f = 언데드 금화 — D-267 §5)
    # ── D-268 마나 순환 (가안 · 정본 미설정 = 무영향): 소비한 마나의 지맥 환원 → 마석 회복 ──
    rec = scn.get("mana_recycle") or {}
    rec_return_ratio = rec.get("return_ratio", 0.0)       # 소비 MP → 지맥 환원 비율 (가안 0.80)
    rec_delay = rec.get("delay_floors", 3)               # 지맥 응축 지연 (층) — 소비 후 지연 회수
    rec_eff_loss = rec.get("eff_loss", 0.20)             # 응축 손실 (가안 20% = 1-0.80)
    rec_queue = []   # [(회수 층, 환원 MP)] FIFO
    rec_returned_mp = 0.0
    lv = {n: 1 for n in ["소환제단", "병원", "전술소", "훈련장", "식당", "숙소",
                         "연구소", "연금술소", "합성소", "추출소"]}
    lv["소환제단"] = 0   # 제단은 채집팀 +1/Lv — 초기 1팀은 기본 제공으로 모델링
    build_done, expansions_done = set(), set()
    pending_split = {}   # 확장비 분할 (split_expansion) — 잔여 50% 지급 예정 {층: 금액}
    summons_total, summons_free_left = 0, FREE_SUMMONS
    staffed = 0
    crystal_earned = crystal_spent = 0
    promoted = {}
    party5_done_floor = party6_done_floor = None
    maint_total = 0.0
    tax_total = 0.0
    cur_floor, day = 0, 0
    log = {}
    trace = {}   # 전 층 기록 (--trace · playthrough_audit P12 — 43~53층 집행 지터 감시)
    pop_loss, starve_run, starve_floors = 1.0, 0, 0
    food_zero_floor = gold_neg_floor = None
    food_min, food_min_f = food, 0
    gold_min, gold_min_f = gold, 0
    famine_days = bandit_hits = seized_days = 0
    extra_plagues = 0             # 위생 체인 추가 역병 (기대 포함 — san_chain 노브 · 정본 0)
    worst_mult, worst_mult_f = 1.0, 0
    gold_spent_mitigation = 0.0   # 화재 물자 소실(구 도적) + 폭풍 수리비 합계
    # --- G-15 사건 엔진 상태 (§3.12 층 연동 · §3.14 파업) ---
    ev_hits, ev_haz = 0, 0        # 사건 총횟수 / 재해(비흉작) 순환 인덱스
    events = []                   # 기록용 [(층, 종류)]
    famine_burst = 0              # 사건 흉작 잔여일 (3일)
    strike_left = strike_floors = 0
    # --- 몬테카를로 노브 (2026-09-18 — 정본 시나리오는 전부 미설정 = 결정론 그대로) ---
    import random
    _ms = scn.get("mc_seed")
    rng = random.Random(_ms) if _ms is not None else None   # None = 결정론 (정본 궤적 불변)
    pace_jit = scn.get("pace_jitter")
    ev_jit = scn.get("ev_jitter")
    fam_jit = scn.get("famine_jitter")
    front_maint = scn.get("front_maint")     # 전선 유지비 비교 프로브 (§3.11 발견 2 재설계 — 정본 off)
    tripwire_maint = scn.get("tripwire_maint")
    speed_fee = scn.get("speed_fee", 0)      # 속공 수수료 (D안 비교 전용 — 정본 0)
    san_chain = scn.get("san_chain")         # 위생 체인 (D-256 후속 — 위생 결핍 시 역병 추가 발동 · 정본 미설정 = 무영향)
    # ── D-268 지맥 건강도 (가안 · 정본 미설정 = 무영향): 플레이 스타일이 층 지맥 농도를 바꾼다 ──
    ley = scn.get("ley_health") or {}
    ley_mode = ley.get("mode")               # None(정본 off) | "slaughter" | "conservation"
    ley_per_floor = {}                       # 층별 지맥 건강도 0~1 (1 = 완전 건강)
    _ley = ley.get("harvest_mul_max", 0.70)  # 메말라릿 층의 수확 배율 하한 (30f × 이 값)
    _ley_recovery = ley.get("recovery", 0.10)  # 층당 자연 회복 (휴경 효과)
    _ley_penalty = ley.get("penalty", 0.06)  # 학살 1회당 건강도 감소 (층당 intensity회 발생)
    _ley_bonus = ley.get("bonus", 0.03)      # 보존층(월드 조우 소극 처치)당 회복 가산
    _ley_kills = ley.get("kills_per_floor", 1)  # 층당 학살 강도 프록시 (토벌형 2·강 3+·보존 0)

    def _plague_chain():
        # 위생 체인 — 역병 1차 피해 + 연쇄 (2026-09-18 방어 모델 개선):
        #  ① 위생 투자 (quarantine_eff, 미설정 시 병원 Lv 기반 가안 Lv당 연쇄율 -15%p·상한 80%) = 연쇄율 자체 절하
        #  ② 격리비 (quarantine_cost — §3.12 '500G 격리 시 -1%' 룰 연동) = 1차 피해 완화 (0.95 → 0.99)
        # 두 방어 모두 피해를 줄이는 방향만 — 최악 보증(무방어 = 정본 계수) 유지
        nonlocal pop_loss, gold, extra_plagues, gold_spent_mitigation
        pop_loss *= 0.95                                      # 1차 피해 (정본 — 방치 -5%)
        if san_chain is None:
            return
        _qeff = san_chain.get("quarantine_eff")
        if _qeff is None:
            _qeff = min(0.8, 0.15 * max(0, lv["병원"] - 1))   # 병원 Lv 기반 위생 방어 (가안 — 시뮬 정본 경로엔 미적용)
        _pmul = san_chain.get("plague_mul", 0.95)
        _qcost = san_chain.get("quarantine_cost", 0)
        if _qcost > 0 and gold >= _qcost:                     # 격리비 지불 가능 시 — 1차 피해 완화
            gold -= _qcost; gold_spent_mitigation += _qcost
            _pmul = san_chain.get("quarantine_plague_mul", 0.99)
        _p = san_chain.get("extra_p", 0.3) * (1 - _qeff)      # 위생 투자 = 연쇄율 절하
        if _p > 0:
            if rng is not None:
                while rng.random() < _p:
                    pop_loss *= _pmul; extra_plagues += 1
            else:
                _e = _p / (1 - _p)                            # 결정론 = 기댓값 프레이밍 (기하분포)
                pop_loss *= _pmul ** _e; extra_plagues += _e
    pace_fix = scn.get("pace")               # 페이스 고정 (비교 전용)
    _next_ev = scn.get("ev_every", 25)       # 다음 사건 예정층 (스케줄 지터 모드 — 진짜 간격 지터)
    ev_mode = scn.get("ev_mode", "cycle")    # cycle = D-253 고정 순환 (정본) · random = 확률 분포 (G-15 잔여)
    morale = scn.get("morale", 50)
    ev_on = scn.get("ev_on", False)
    winter = scn.get("winter_mul", 1.0) < 1.0
    winter_mul = scn.get("winter_mul", 1.0)
    farm_stop = winter and scn.get("farm_stop_winter", False)   # estate.json winter.growth_mul=0.0
    ev_ratio = scn.get("ev_famine_ratio", 0.0)
    ev_period = round(1 / ev_ratio) if ev_ratio > 0 else 0      # 0.5→2번에 1번 흉작 · 1/3→3번에 1번
    HAZ = ["화재", "폭풍", "역병", "민심"]                        # 재해 순환 (구 도적→화재 — D-256 기원 제약 · 풍년·축제는 완화 — 최악 시뮬 제외)

    def food_parts(f, pop, t, seized):
        eff_t = max(t - (1 if seized else 0), 0)
        gather = eff_t * 150 * (1 + f / 50) * (1 + (0.15 if lv["소환제단"] >= 6 else 0) + (0.15 if lv["소환제단"] >= 7 else 0))
        farm = max(3, pop // 20) * 15   # §3.3-2 초기 3필지(주택 3동) — 가안
        rest = 1.2 if f >= 10 else 1.0
        return gather * rest, farm * rest

    while cur_floor < 100:
        day += 1
        pace = pace_fix if pace_fix else pace_at(max(cur_floor, 1))
        _jit = (rng.uniform(-pace_jit, pace_jit) if (rng is not None and pace_jit) else 0.0)   # 페이스 지터 (MC — 균등 ±x · 정본 None)
        clears = min(int(pace + (0.5 if (day % 2) else 0) + _jit), 100 - cur_floor) or 1
        # --- 계절 (§3.13) — 겨울 = 식량수확 ×winter_mul + 농사 성장 정지 (estate.json growth_mul=0.0) ---
        morale_mult = 1 + (morale - 50) / 50 * 0.20                # §3.5 수치화식
        decree_mult = 1.20 if scn.get("decree_harvest", False) else 1.0   # 채집·농사 +20% — §3.7
        # 흉작: 주기형(10섬일) ∪ 사건 흉작 버스트 — 합쳐서 계수 적용 (중첩 시 최악)
        _fe = scn.get("famine_every", 0)
        _fd = 3
        if fam_jit is not None and rng is not None and _fe > 0:
            _fd = max(2, int(round(_fe + rng.uniform(-fam_jit, fam_jit))))   # 흉작 주기 지터 (MC)
        periodic_famine = _fe > 0 and (day % _fe) < max(1, min(3, _fd))   # 정본 창 = 잔여 {0,1,2} — _fd=3에서 구식과 완전 동일
        famine = periodic_famine or famine_burst > 0
        if famine_burst > 0: famine_burst -= 1
        if periodic_famine: famine_days += 3
        famine_mult = scn.get("famine_mul", 0.70) if famine else 1.0
        bandit = seized = False
        if winter and scn.get("ev_winter_penalty", 0) > 0:
            pop_loss *= (1 - scn["ev_winter_penalty"])   # 겨울 인구 자연감소 (역병·한파 상시 압박 — G-15 노브)
        # ── 일 단위 정산 (섬 하루): 주민 세금 (estate.json — 2026-09-17 단위 통일) ──
        tax_today = pop_at(max(cur_floor, 1)) * pop_loss
        gold += tax_today; tax_total += tax_today
        for _ in range(clears):
            cur_floor += 1
            f = cur_floor
            # --- 사건·재해 (§3.12 층 연동 — 25층마다 확정 1회 · 발동 민심 -2) ---
            ev_every = scn.get("ev_every", 25)   # 층 연동 상수 (D-253 정본 25 · G-15 민감도 스윕 노브 — 15/35)
            if ev_jit is not None and rng is not None:
                _ev_hit = ev_on and ev_every > 0 and f >= _next_ev   # 스케줄 지터 (MC — 다음 사건 = 직전 발동 + ev_every±x)
            else:
                _ev_hit = ev_on and ev_every > 0 and f % ev_every == 0   # 정본 — 정확 주기
            if _ev_hit:
                ev_hits += 1
                if ev_mode == "random":
                    # 확률 분포 모드 (G-15 잔여 — 랜덤 체감 · 완화 이벤트 포함): 재해 4종 균등 + 완화 2종
                    p_boon = scn.get("ev_boon_weight", 0.0)
                    z = 1.0 - p_boon
                    pool = [("화재", 0.25 * z), ("폭풍", 0.25 * z), ("역병", 0.25 * z), ("민심", 0.25 * z),
                            ("풍년", p_boon / 2), ("축제", p_boon / 2)]
                    x, acc, kind = rng.random(), 0.0, pool[-1][0]
                    for k2, w2 in pool:
                        acc += w2
                        if x <= acc:
                            kind = k2; break
                    events.append((f, kind))
                    if kind == "풍년":       # 완화 — 당일 식량 수확 ×1.5 (3섬일 지속)
                        famine_burst = -3    # 음수 = 완화 버프 잔여일
                    elif kind == "축제":     # 완화 — 민심 +3 (D-256: 구 생존자 합류 교체 — 인구 유입은 자연증가·뽑기만)
                        morale = min(morale + 3, 100)
                    elif kind == "화재":
                        bandit = True; seized = True; seized_days += 2
                        damage = gold * 0.10
                        gold -= damage; gold_spent_mitigation += damage
                        bandit_hits += 1
                    elif kind == "폭풍":
                        gold -= 2500; gold_spent_mitigation += 2500
                    elif kind == "역병":
                        _plague_chain()
                    if kind not in ("풍년", "축제"):
                        morale = max(morale - 2, 0)   # 재해만 민심 -2 (완화 이벤트는 패널티 없음)
                else:
                    # D-253 고정 순환 모드 (정본) — ev_jitter로 발동 간격만 흔들 수 있음 (MC)
                    if ev_period and (ev_hits - 1) % ev_period == 0:
                        famine_burst = 3
                        events.append((f, f"흉작×{scn.get('famine_mul', 0.70):.2f}(3일)"))
                    else:
                        ev_haz += 1
                        kind = HAZ[(ev_haz - 1 + scn.get("haz_offset", 0)) % len(HAZ)]   # haz_offset = 순환 시작점 회전 (G-15 배치 민감도 노브 — 정본 0)
                        events.append((f, kind))
                        if kind == "화재":    # 물자 소실 -10% + 진화 인력 1팀 2일 차출 (구 도적 — D-256 · 최악 = 둘 다)
                            bandit = True; seized = True; seized_days += 2
                            damage = gold * 0.10
                            gold -= damage; gold_spent_mitigation += damage
                            bandit_hits += 1
                        elif kind == "폭풍":  # 시설 1동 파괴 → 수리비 = 건설비 50% (가안 평균 건설비 5,000G → 2,500G)
                            gold -= 2500; gold_spent_mitigation += 2500
                        elif kind == "역병":  # 방치 인구 -5% (최악 = 방치) + 위생 체인 (san_chain 노브)
                            _plague_chain()
                        # 민심: 발동 패널티 -2만 (아래 공통)
                    morale = max(morale - 2, 0)   # 발동 시 민심 -2 (§3.12 가안)
                if morale < 20 and strike_left == 0:
                    strike_left = 5           # §3.14 파업 — 전 생산 정지 5층
                if ev_jit is not None and rng is not None:
                    _next_ev = f + max(5, ev_every + rng.randint(-ev_jit, ev_jit))   # 다음 사건 예약 (간격 ±x · 최소 5층)
            # 수입
            bank_gold_flowed += 100 * f   # 언데드 폐허 금화 수확 (은행 1:1 환전 → LEY · D-267 §5)
            gold += 100 * f
            jp_every = scn.get("jp_every", 10)   # 게이트잭팟 주기 (10 = 문서 현행 · 5 = GK 전면 후보)
            jp_coeff = scn.get("jp_coeff", 85)   # 게이트층² 계수 (§3.9 — 85 = 2026-09-17 G+E 채택 · 구 75)
            # ── D-268 지맥 건강도 — 층 수확 배율 (정본 off = 1.0 고정) ──
            # 모델: 층은 1회 수확 — 건강도 h_f = max(하한, 1 − penalty × 층내 학살 강도).
            # 학살 강도(kills) = 그 층에서 토벌·처치한 횟수 (보존형 0 · 학살형 2 · 강 3+)
            if ley_mode is not None:
                if ley_mode == "slaughter":
                    h = max(_ley, 1.0 - _ley_penalty * _ley_kills)   # 학살 누적 — 층내 처치 횟수만큼 메달림
                else:
                    h = min(1.0, 1.0 + _ley_recovery + _ley_bonus)   # 보존적 탐험 — 완전 건강 유지
                ley_per_floor[f] = h
                m_ley = h if h < 1.0 else 1.0
            else:
                m_ley = 1.0
            mana += (30 * f + (jp_coeff * f * f if f % jp_every == 0 and f >= jp_every else 0)) * m_ley
            gs = scn.get("gate_small")           # 소형 게이트 보상 (D-252 5→10층 공백 검증) — ("lin",계수)·f | ("sq",계수)·f² · 5·15·25…층(잭팟 미지급층)만
            if gs and f % 10 == 5:
                mana += gs[1] * f * f * m_ley if gs[0] == "sq" else gs[1] * f * m_ley
            # 확장 (해금 층수·분할 지급 시나리오별 — B안 지연·클러스터 완화 검증용)
            s2f = scn.get("s2_floor", 16)   # D-263 정본 (구 12 — D-251 fixB) — S2 해금은 16층
            s3f = scn.get("s3_floor", 25)
            s4f = scn.get("s4_floor", 50)
            split = 0.5 if scn.get("split_expansion", False) else 1.0   # 해금 시 50% + 3층 후 잔여
            for ef, ec in ((s2f, 3000), (s3f, 10000), (s4f, 30000)):
                if f == ef and ef not in expansions_done:
                    expansions_done.add(ef); gold -= ec * split
                    if split < 1.0:
                        pending_split[ef + 3] = pending_split.get(ef + 3, 0) + ec * (1 - split)
            if f in pending_split:
                gold -= pending_split.pop(f)
            # 건설 (C안 감면 검증용 — 10층 3종에만 적용 · 전술소 1,000G는 확정 수치라 제외)
            if f in BUILD and f not in build_done:
                build_done.add(f)
                disc = scn.get("build_discount", 1.0) if f == 10 else 1.0
                gold -= BUILD[f] * disc
            for n in ["훈련장", "식당", "숙소"]:
                if f == 10 and n not in build_done: build_done.add(n)  # 비용은 BUILD[10]에 포함
            # 소환 + 추출 (무료 10회 포함 — 무료분도 추출 대상)
            while summons_total < 30000:
                if summons_free_left > 0:
                    summons_free_left -= 1
                elif (mana - (10000 if f > 10 else 0)) >= TICKET:
                    mana -= TICKET
                else:
                    break
                summons_total += 1
                if staffed < STAFF: staffed += 1
                else:
                    got = E_CRYSTAL * 1.1   # 레벨 보정 ×1.1 (§3.1-2 캘리브레이션 기준)
                    crystal += got; crystal_earned += got
            # 승급 집행 (합성소 30층+)
            if f >= 30:
                # ★5 파티
                p5 = promoted.get(5, 0)
                while p5 < 5 and crystal >= PROMO_TOTAL_5 and gold >= GOLD_TOTAL_5:
                    crystal -= PROMO_TOTAL_5; crystal_spent += PROMO_TOTAL_5
                    gold -= GOLD_TOTAL_5; promoted[5] = p5 = p5 + 1
                    if p5 == 5 and party5_done_floor is None: party5_done_floor = f
                p6 = promoted.get(6, 0)
                while p6 < 5 and crystal >= PROMO_TOTAL_6 and gold >= GOLD_TOTAL_6:
                    crystal -= PROMO_TOTAL_6; crystal_spent += PROMO_TOTAL_6
                    gold -= GOLD_TOTAL_6; promoted[6] = p6 = p6 + 1
                    if p6 == 5 and party6_done_floor is None: party6_done_floor = f
            # 업글 정책 (버퍼 20% 유지)
            order = sorted(lv, key=lambda n: (n not in PRIORITY, UP_COST(lv[n])))
            for n in order:
                if lv[n] >= 7: continue
                c = UP_COST(lv[n])
                if gold - c >= GOLD_BUFFER * (100 * 50):  # 버퍼 = 누적 기대 수입 20%
                    gold -= c; lv[n] += 1
            drain = 0
            if front_maint:
                drain = front_maint * max(f - 50, 0)      # B안 — S4 초과 전선 유지비 (비교 전용 · maint_total 미가산 = A안 bypass 유효성 검증 분리)
            elif tripwire_maint:
                drain = tripwire_maint                    # C안 — 골드 트립와이어 (비교 전용 · 정본 off)
            drain += speed_fee * max(0, pace - pace_at(f))   # D안 — 표준 페이스 초과분 수수료 (급공 1.5·속공 1.0/일 부과)
            if drain:
                gold -= drain
            if gold < gold_min: gold_min, gold_min_f = gold, f
            if gold < 0 and gold_neg_floor is None: gold_neg_floor = f
            maint_total += MAINT_PER_LV * sum(lv.values())
            if strike_left > 0:
                strike_left -= 1; strike_floors += 1   # 파업 5층 카운트 — §3.14
            if f in MILESTONES:
                log[f] = (day, int(gold), int(mana), int(crystal), int(food))
            trace[f] = (day, int(gold), int(mana), int(crystal), int(food))   # 전 층 — --trace·P12 지터 감시

        # ── 일 단위 정산 (섬 하루): 식량 소비·아사 (estate.json — 2026-09-17 단위 통일) ──
        pop = pop_at(f) * pop_loss
        t = teams_at(f)
        gather_r, farm_r = food_parts(f, pop, t, seized)
        farm_eff = 0.0 if farm_stop else farm_r            # 겨울 농사 성장 정지 (estate.json growth_mul=0.0)
        if strike_left > 0 or (strike_left == 0 and strike_floors > 0 and morale < 20 and events and f % 25 == 0):
            prod = 0.0   # 파업 중 — 전 생산 정지 (§3.14)
        else:
            prod = (gather_r * winter_mul * decree_mult + farm_eff * winter_mul * decree_mult) * famine_mult * morale_mult
        if famine or seized or winter or strike_floors > 0:
            m = winter_mul * famine_mult * morale_mult * ((max(t - 1, 0) / t) if seized else 1.0)
            if m < worst_mult: worst_mult, worst_mult_f = m, f   # 배율 지표 — 절대량(gather+farm) 아님
        cons = pop                                    # 1식/주민/섬 하루 (§3.4 — 클리어 속도 무관)
        push = scn.get("harvest_push", 1.0)
        if scn.get("stockpile", False) and food < scn.get("stockpile_target", 500):
            cons *= 0.5   # 재고 운영: 재고 목표 미만이면 저속 클리어 (재고 비축 우선)
        food += prod * push - cons
        if food < 0:
            starve_run += 1; starve_floors += 1
            if starve_run >= 3: pop_loss *= 0.98   # §3.14 아사 — 3섬일 지속 시 -2%/섬일
            if food_zero_floor is None: food_zero_floor = f
            food = 0
        else:
            starve_run = 0
        if food < food_min: food_min, food_min_f = food, f

        # ── D-267 §6b — 은행 에너지 계정: 시설별 마나 배급 (스로틀: 소환 버퍼 침식 금지) ──
        energy_scale = scn.get("energy_rate_mp", 0.0)  # 전체 배율 (정본 0 = off · 1.0 = §6b 표 그대로)
        if energy_scale > 0:
            need_mp = sum(ENERGY_RATE[n] * v for n, v in lv.items() if n in ENERGY_RATE)
            need_mp *= energy_scale                    # 시설별 표 × 배율 노브 (튜닝용)
            bank = mana - (TICKET if mana >= TICKET else 0) # 소환 티켓 1장분은 항상 보호
            grant = min(need_mp, max(0.0, bank))            # 침식 금지 — 보호분 초과 배급 불가
            mana -= grant / MP_PER_CRYSTAL                  # 130MP = 마석 1개 환산 소모
            energy_spent_mp += grant
            # ── D-268 마나 순환: 소비 마나 → 지맥 환원 → 응축 지연 후 마석 회수 ──
            if grant > 0 and rec_return_ratio > 0:
                rec_queue.append((f + rec_delay, grant * rec_return_ratio))
        # 지맥 응축 회수 — 지연 도래분 마석화 (손실 eff_loss 반영은 환원 시 이미 차감)
        while rec_queue and rec_queue[0][0] <= f:
            _, mp_back = rec_queue.pop(0)
            mana += mp_back / MP_PER_CRYSTAL
            rec_returned_mp += mp_back
        # ── D-267 은행 3계정 층별 장부 (P13 — 이중분기 검증용) ──
        if bank_trace is not None:
            reserve = max(0.0, mana - TICKET)              # 담보 = 티켓 보호분 제외 잉여 재고
            bank_trace[f] = dict(gold_flowed=round(bank_gold_flowed),
                                 issued=round(bank_gold_flowed), repaid=0.0,
                                 energy_mp=round(energy_spent_mp),
                                 reserve_cry=round(reserve), limit_ley=round(reserve * LEY_RATE))

    return dict(name=name, day=day, log=log, trace=trace, gold=gold, mana=mana, crystal=crystal,
                food=food, summons=summons_total, crystal_earned=crystal_earned,
                energy_spent_mp=energy_spent_mp, mana_recycled_mp=rec_returned_mp,
                bank_trace=bank_trace, ley_worst=min(ley_per_floor.values()) if ley_per_floor else 1.0,
                crystal_spent=crystal_spent, maint=maint_total, tax_total=tax_total,
                p5=party5_done_floor, p6=party6_done_floor, staffed=staffed, lv=lv,
                pop_loss=pop_loss, starve_floors=starve_floors,
                food_zero_floor=food_zero_floor, gold_neg_floor=gold_neg_floor,
                food_min=food_min, food_min_f=food_min_f,
                gold_min=gold_min, gold_min_f=gold_min_f,
                famine_days=famine_days, bandit_hits=bandit_hits,
                seized_days=seized_days, worst_mult=worst_mult, worst_mult_f=worst_mult_f, extra_plagues=extra_plagues,
                bandit_damage=gold_spent_mitigation,
                events=events, strike_floors=strike_floors, morale_end=morale)

# ---------- 몬테카를로 배치 모드 (playthrough_audit P11 — --mc) ----------
# 정상 실행 경로(아래 results/출력)를 완전히 우회하고 MC 9런 결과를 MC_JSON 한 줄로 출력한다.
# 결정론 정본 출력은 무관 — check_docs.py의 baseline 파싱 계약은 그대로 유지.
if "--mc" in sys.argv:
    import json as _json
    _mc = []
    for _seed in (101, 202, 303):
        for _lbl, _kw in [
            ("cycle_jit", dict(ev_jitter=3)),                              # D-253 순환 + 간격 지터 ±3층
            ("random_b0", dict(ev_mode="random", ev_boon_weight=0.0)),     # 6종 랜덤 — 재해 전용
            ("random_b10", dict(ev_mode="random", ev_boon_weight=0.10)),   # 6종 랜덤 — 완화 10%
        ]:
            _s = dict(_STRESS_BASE, ev_on=True, gate_small=("sq", 5), mc_seed=_seed, **_kw)
            _r = run_sim(f"mc_{_lbl}_{_seed}", _s)
            _mc.append(dict(seed=_seed, label=_lbl, starve=_r["starve_floors"], strike=_r["strike_floors"],
                            gold_min=int(_r["gold_min"]), p5=_r["p5"], pop_loss=1 - _r["pop_loss"],
                            food_end=int(_r["food"])))
    print("MC_JSON " + _json.dumps(_mc))
    sys.exit(0)

# ---------- 전 층 트레이스 (playthrough_audit P12 — --trace) ----------
# baseline의 층별 (일, 골드, 마석, 결정)을 JSON 한 줄로 출력 — 43~53층 집행 지터 상시 감시용.
# 결정론 출력과 무관 (기본 실행은 여전히 표 형식 — check_docs 계약 유지).
if "--bank-trace" in sys.argv:
    # ---------- 은행 3계정 층별 장부 (playthrough_audit P13 — D-267) ----------
    # 정식 baseline + 에너지 계정 on + 순환 on — 발행·마나 소모·환원의 층별 이중분기 검증용
    import json as _json
    _bt = dict(SCENARIOS["baseline"], energy_rate_mp=1.0, bank_trace=True, mana_recycle={"return_ratio": 0.80, "delay_floors": 3})
    _r = run_sim("banktrace", _bt)
    print("BANK_TRACE_JSON " + _json.dumps(
        [[f, b["gold_flowed"], b["issued"], b["energy_mp"], b["reserve_cry"], b["limit_ley"]] for f, b in sorted(_r["bank_trace"].items())]))
    print("BANK_TOTALS_JSON " + _json.dumps(
        dict(energy_mp=_r["energy_spent_mp"], recycled_mp=_r["mana_recycled_mp"],
             mana_end=int(_r["mana"]), summons=_r["summons"], p5=_r["p5"],
             gold_min=int(_r["gold_min"]), gold_flowed=int(_r["bank_trace"][100]["gold_flowed"]),
             limit_ley_end=int(_r["bank_trace"][100]["limit_ley"]))))
    sys.exit(0)
if "--trace" in sys.argv:
    import json as _json
    _b = run_sim("baseline", dict(SCENARIOS["baseline"]))
    print("TRACE_JSON " + _json.dumps([[f, t[0], t[1], t[2], t[3]] for f, t in sorted(_b["trace"].items())]))
    sys.exit(0)

# ---------- 출력 ----------
results = [run_sim(n, dict(s)) for n, s in SCENARIOS.items()]
for r in results:
    print("=" * 76)
    scn = SCENARIOS[r["name"]]
    tag = []
    if scn.get("winter_mul", 1.0) < 1.0:
        tag.append(f"전 기간 겨울 ×{scn['winter_mul']:.2f}" + (" + 농사성장정지" if scn.get("farm_stop_winter") else ""))
    if scn.get("famine_every"):
        tag.append(f"흉작 {scn['famine_every']}일 주기 ×{scn.get('famine_mul', 0.70):.2f}")
    if scn.get("ev_on"):
        tag.append(f"사건 층연동(25층·1회·민심-2 · 흉작비율 {scn.get('ev_famine_ratio', 0.0):.0%})")
    if scn.get("ev_winter_penalty"):
        tag.append(f"겨울 인구 -{scn['ev_winter_penalty'] * 100:.1f}%/섬일")
    if scn.get("morale", 50) < 50:
        tag.append(f"민심 {scn.get('morale', 50)} (×{1 + (scn.get('morale', 50) - 50) / 50 * 0.20:.2f})")
    print(f"[{r['name']}] 런 {r['day']}일" + (" — " + " · ".join(tag) if tag else " — 평시"))
    print("=" * 76)
    print(f"{'층':>4} {'일':>4} {'골드':>10} {'마석':>9} {'결정':>8} {'식량':>8}")
    for f, (d, g, m, c, fd) in sorted(r["log"].items()):
        print(f"{f:>4} {d:>4} {g:>10,} {m:>9,} {c:>8,} {fd:>8,}")
    print("-" * 76)
    print(f"유지비 총액            : {int(r['maint']):>12,} G")
    print(f"주민 세금 누적          : {int(r['tax_total']):>12,} G  (1G/명·섬 하루 — dungeon 누적 {100 * sum(range(1, 101)):,}G 대비 {r['tax_total'] / (100 * sum(range(1, 101))) * 100:.1f}%)")
    print(f"소환 총횟수            : {r['summons']:>12,} 회")
    print(f"결정 획득/지출         : {int(r['crystal_earned']):,} / {int(r['crystal_spent']):,}")
    print(f"★5 파티 완성          : {r['p5']}층 (목표 50) · ★6 파티: {r['p6']}층 (참고값 — 설계 목표 아님)")
    print(f"식량 최저 재고         : {int(r['food_min']):,} ({r['food_min_f']}층) · 아사 층수: {r['starve_floors']}"
          + (f" · 최초 식량 0: {r['food_zero_floor']}층" if r["food_zero_floor"] else ""))
    print(f"골드 최저              : {int(r['gold_min']):,} G ({r['gold_min_f']}층)"
          + (f" · 최초 골드 <0: {r['gold_neg_floor']}층" if r["gold_neg_floor"] else " · 파산 없음"))
    if r["events"]:
        print(f"사건 기록              : " + " · ".join(f"{f}층 {k}" for f, k in r["events"]))
    if r["starve_floors"] > 0 or r["name"] == "stress":
        print(f"흉작/화재/차출         : {r['famine_days']}일 / {r['bandit_hits']}회 / {r['seized_days']}일 · 재해 비용 합계 {int(r['bandit_damage']):,}G")
        print(f"최악 생산 배율         : ×{r['worst_mult']:.2f} ({r['worst_mult_f']}층 시점)")
        print(f"인구 손실 (아사·역병 누적): -{(1 - r['pop_loss']) * 100:.1f}%"
              + (f" · 파업 {r['strike_floors']}층" if r["strike_floors"] else ""))
        print(f"종료 민심              : {r['morale_end']}")

# ---------- 비교 요약 ----------
b, s = results[0], results[1]
print()
print("#" * 76)
print("# 무너지는 지점 요약 (baseline vs stress)")
print("#" * 76)
rows = [
    ("최초 식량 0 (아사 시작)", f"{b['food_zero_floor']}층" if b["food_zero_floor"] else "없음",
     f"{s['food_zero_floor']}층" if s["food_zero_floor"] else "없음"),
    ("아사 누적 층수", f"{b['starve_floors']}", f"{s['starve_floors']}"),
    ("인구 손실", f"-{(1 - b['pop_loss']) * 100:.1f}%", f"-{(1 - s['pop_loss']) * 100:.1f}%"),
    ("최초 골드 <0", f"{b['gold_neg_floor']}층" if b["gold_neg_floor"] else "없음",
     f"{s['gold_neg_floor']}층" if s["gold_neg_floor"] else "없음"),
    ("골드 최저", f"{int(b['gold_min']):,} G ({b['gold_min_f']}층)", f"{int(s['gold_min']):,} G ({s['gold_min_f']}층)"),
    ("★5 파티 (목표 50)", f"{b['p5']}층", f"{s['p5']}층"),
    ("★6 파티 (참고값 — 목표 아님)", f"{b['p6']}층", f"{s['p6']}층"),
    ("런 소요", f"{b['day']}일", f"{s['day']}일"),
]
w = max(len(x) for x, _, _ in rows) + 2
print(f"{'지표':<{w}}{'baseline':>28}{'stress(최악)':>28}")
for label, bv, sv in rows:
    print(f"{label:<{w}}{bv:>28}{sv:>28}")

# ---------- 파산점 해결안 비교 (fixA/B/C) ----------
fixes = [r for r in results if r["name"].startswith("fix")]
if fixes:
    print()
    print("#" * 76)
    print("# 10층 파산점 해결안 비교 (§3.11 발견 1 — greedy 업글 정책 하)")
    print("#" * 76)
    print(f"{'안':<8}{'10층 골드':>14}{'최초 <0':>10}{'골드 최저':>16}{'★5':>6}{'★6':>6}{'100층 골드':>14}")
    for r in fixes:
        g10 = r["log"].get(10, (0, 0, 0, 0, 0))[1]
        g100 = r["log"].get(100, (0, 0, 0, 0, 0))[1]
        neg = f"{r['gold_neg_floor']}층" if r["gold_neg_floor"] else "없음"
        print(f"{r['name']:<8}{g10:>14,}{neg:>10}{int(r['gold_min']):>13,} G{r['p5']:>5}층{r['p6']:>5}층{g100:>14,}")
    g10b = b["log"].get(10, (0, 0, 0, 0, 0))[1]
    print(f"{'baseline':<8}{g10b:>14,}{('' if not b['gold_neg_floor'] else str(b['gold_neg_floor'])+'층'):>10}{int(b['gold_min']):>13,} G{b['p5']:>5}층{b['p6']:>5}층{b['log'][100][1]:>14,}")

# ---------- 클러스터 재설계안 비교 (cluster_*) ----------
clusters = [r for r in results if r["name"].startswith("cluster")]
if clusters:
    print()
    print("#" * 76)
    print("# 지출 클러스터 재설계안 비교 (25·50층 — 전부 D-251 기반)")
    print("#" * 76)
    print(f"{'안':<12}{'25층 잔고':>12}{'50층 잔고':>12}{'최초 <0':>10}{'골드 최저':>15}{'★5':>6}{'★6':>6}")
    for r in clusters:
        g25 = r["log"].get(25, (0, 0, 0, 0, 0))[1]
        g50 = r["log"].get(50, (0, 0, 0, 0, 0))[1]
        neg = f"{r['gold_neg_floor']}층" if r["gold_neg_floor"] else "없음"
        print(f"{r['name']:<12}{g25:>12,}{g50:>12,}{neg:>10}{int(r['gold_min']):>13,} G{r['p5']:>5}층{r['p6']:>5}층")

# ---------- G-15 강도 스윕 요약 (2026-09-17 — 채택 후 미채택 스윕 행은 시나리오에서 제거) ----------
sweeps = [r for r in results if r["name"].startswith("g15_") or r["name"] == "stress"]
if sweeps:
    print()
    print("#" * 76)
    print("# G-15 강도 스윕 (정본 반영 stress = 기준 · 채택 기준: 아사>0 · ★5 지연 ≤10층 · 골드 한계 내)")
    print("#" * 76)
    print(f"{'안':<10}{'아사':>5}{'인구손실':>9}{'식량최저':>10}{'★5':>5}{'골드최저':>12}{'파업':>5}")
    for r in sweeps:
        print(f"{r['name']:<10}{r['starve_floors']:>5}{(1 - r['pop_loss']) * 100:>8.1f}%{int(r['food_min']):>10,}{r['p5']:>4}층{int(r['gold_min']):>11,} G{r['strike_floors']:>5}")
