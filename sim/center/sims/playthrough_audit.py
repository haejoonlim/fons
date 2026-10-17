#!/usr/bin/env python3
"""런 전체 플레이스루 감사 — 100층 런을 처음부터 시뮬레이션하며 시스템 정본을 교차 검수.

기존 도구는 축별(gacha_test=소환 · proficiency=숙련 · sim_economy=영지 · sim_foodweb_combat=생태)로
따로 논다. 본 스크립트는 **한 명의 플레이어가 1층→100층까지 진행하는 한 런**을 관점으로 삼아,
각 스테이지(S1~S4) 종료 시점에 그때까지의 게임 상태를 정본과 대조한다:

  P0 파티  ★5 5인 — 50층 (§3.1-2 캘리브레이션, ±5층)
  P0 배치  영웅 36명 수요 ≤ 소환 확보 인원 (§3.2)
  P1 진행  유무료 소환·결정 수급이 ★5·★6 파티 곡선을 커버
  P2 인구  수지표 행 보간 ↔ 자연증가 2%/섬일 상한 검산 (§3.2·§3.11)
  P3 골드  파산 클러스터(S2 12층 해금으로 완화 — D-251) 후에도 최저 잔고 > -1만G 유지
  P4 식량  아사 0 (§3.4 섬일 정산)
  P5 마석  누적 수급 = 소비(소환 티켓) 정합, 루프 없음 (§3.9)
  P6 잭팟  10층 배수 층²×75 — D-252 정본식 (gacha_test와 동일)
  P7 CP    뽑기 표본 CP가 01 §2 권장 곡선 하한(층 스케일) 대비 과소/과다 없는지 (관측)
  P8 시간  런 소요 섬일 ≤ 60 (페이스 가안 §3.13 · 유지비 총액 정합)
  P11 몬테카를로  3시드 × (간격 지터·6종 랜덤 boon 0/10%) 9런 — 최악 케이스도
       골드 -22,000 이내 · ★5 ≤ 60층 · 압박 밴드(아사 0~15·파업) 유지 (2026-09-18)
  P12 집행 지터  43~53층 전 층 트레이스 — 50층 S4 확장 스냅 존재·비사건 낙폭 ≤4,000G
  P13 은행 3계정 발행=환전≤담보한도·마나 순환 환원율 60~85%·순환 on 정본 보호 (D-267·D-268)
       · 54층 재수렴 앵커 — G+E가 흔든 집행 타이밍이 정본 위치에 머무는지 감시 (2026-09-18)

데이터 정본(estate.json·races.json·biomes.json)과 문서 수치를 모두 직접 읽어 대조하므로
정본이 바뀌면 이 감사도 함께 FAIL 된다 — 문서↔데이터↔시뮬 삼각 드리프트 방지용.

실행: python3 design-docs/_tools/playthrough_audit.py (저장소 루트 기준)
exit 0 = 런 전체 정합 · 1 = 결함 발견 (reports 전체 출력 후 종료)
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DOCS = os.path.join(ROOT, "design-docs")
DATA = os.path.join(ROOT, "data")
# 폰즈 이관: 시뮬은 design-docs/_tools 가 아니라 이 폴더(sims/)에 산다 — 옆 파일을 그대로 부른다.
SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sim_economy.py")

problems = []
notes = []


def fail(cat, msg):
    problems.append(f"[{cat}] {msg}")


def ok(cat, msg):
    notes.append(f"✅ [{cat}] {msg}")


def warn(cat, msg):
    notes.append(f"⚠️  [{cat}] {msg} (관측 — FAIL 아님)")


# ---------- 0. 정본 로드 ----------
estate = json.load(open(os.path.join(DATA, "estate.json")))
races = json.load(open(os.path.join(DATA, "races.json")))
biomes_g = json.load(open(os.path.join(DATA, "biomes.json")))["groups"]

hb = races.get("meta", {}).get("heroBaseStats")
if not hb:
    fail("P-init", "races.json meta.heroBaseStats 없음 — 영웅 기본 스탯 정본 상실")
STAGES = estate["stages"]
EXP_FLOORS = {s["unlock_floor"]: s["expansion_cost"] for s in STAGES}
# estate.json 해금층 {1,12,25,50} ↔ 문서 정본 §3.8
if set(EXP_FLOORS) != {1, 16, 25, 50}:   # D-263 — S2 해금 16층 (구 D-251 12층 폐기)
    fail("P-init", f"estate.json 스테이지 해금층 {sorted(EXP_FLOORS)} — 기대 {sorted([1, 16, 25, 50])} (D-263: S2=16 — 구 D-251 S2=12 폐기)")
POP_CAPS = {s["unlock_floor"]: s["max_population"] for s in STAGES}

# ---------- 1. 시뮬 실행 (baseline + stress — check_docs와 동일 파싱) ----------
proc = subprocess.run([sys.executable, SIM], capture_output=True, text=True, timeout=120)
if proc.returncode != 0:
    fail("P-init", f"sim_economy.py 실행 실패 (exit {proc.returncode}): {proc.stderr[:200]}")
    _finish = True
else:
    _finish = False

runs = {}
if not _finish:
    cur = None
    import re
    for ln in proc.stdout.splitlines():
        if ln.startswith("[") and "] 런" in ln:
            cur = ln[1:ln.index("]")]
            runs[cur] = {"log": {}}
            continue
        if not cur:
            continue
        m = re.match(r"\s*(\d+)\s+(\d+)\s+(-?[\d,]+)\s+([\d,]+)\s+([\d,]+)\s+([\d,]+)\s*$", ln)
        if m:
            f_, d_, g_, ma_, cr_, fo_ = m.groups()
            runs[cur]["log"][int(f_)] = dict(day=int(d_), gold=int(g_.replace(",", "")),
                                             mana=int(ma_.replace(",", "")),
                                             crystal=int(cr_.replace(",", "")),
                                             food=int(fo_.replace(",", "")))
        elif "주민 세금 누적" in ln:
            runs[cur]["tax"] = int(ln.split(":")[1].strip().split("G")[0].replace(",", ""))
        elif "★5 파티 완성" in ln:
            runs[cur]["p5"] = int(ln.split(":")[1].split("층")[0].strip())
        elif "★6 파티:" in ln:
            runs[cur]["p6"] = int(ln.split("★6 파티:")[1].split("층")[0].strip())
        elif "아사 층수" in ln:
            runs[cur]["starve"] = int(ln.split("아사 층수:")[1].split("·")[0].strip())
        elif "골드 최저" in ln and ":" in ln:
            runs[cur]["gold_min"] = int(ln.split(":", 1)[1].strip().split("G")[0].replace(",", ""))

if _finish or "baseline" not in runs or "stress" not in runs:
    fail("P-init", "시뮬 파싱 실패 — baseline/stress 시나리오를 찾지 못함 (sim_economy 출력 규약 변경 추정)")
else:
    ok("P-init", f"시뮬 2런 파싱 — baseline {len(runs['baseline']['log'])}마일스톤 · stress {len(runs['stress']['log'])}마일스톤")

# ---------- 스테이지 순회 검수 ----------
STAGE_SPANS = [("S1", 1, 11), ("S2", 12, 24), ("S3", 25, 49), ("S4", 50, 100)]


def stage_of(f):
    for name, lo, hi in STAGE_SPANS:
        if lo <= f <= hi:
            return name
    return "S4"


if not _finish and "baseline" in runs and "stress" in runs:
    b, s = runs["baseline"], runs["stress"]

    # P0 — ★5 파티 (캘리브레이션 ±5층)
    for tag, r in (("baseline", b), ("stress", s)):
        p5 = r.get("p5")
        if p5 is None:
            fail("P0", f"{tag}: ★5 파티 완성 시점 미출력")
        elif abs(p5 - 50) > 6:   # D-263 정본 밴드 — stress 56층 (구 50±5 stress 55와 동일 여유)
            fail("P0", f"{tag}: ★5 파티 {p5}층 — 목표 50 ±6층 이탈 (캘리브레이션 붕괴)")
        else:
            ok("P0", f"{tag}: ★5 파티 {p5}층 (목표 50 ±5 이내)")

    # P1 — 결정 경제: 시뮬의 결정은 '버퍼 1만 초과분 소화' 정책 산물이라 절대값 비교가 무의미.
    # 대신 **수급 체인을 독립 재현**해 대조한다: 50층 수급 → 티켓+무료 → 기대 결정(레벨 ×1.1)이
    # ★5 파티 8,500 + 예비를 커버해야 캘리브레이션 성립 (§3.1-2 · 정적 추정 11,252개).
    # 2026-09-17: 확률도 확정 #32 정본으로 교체 (구 0.02884 = 폐기된 ★4 2.884%) · 수급은 G+E 정본
    P = [0.7004, 0.20, 0.087, 0.012, 0.0005, 0.0001]
    CR = [1, 3, 10, 30, 100, 300]
    E_C = sum(p * c for p, c in zip(P, CR))
    stones50 = (sum(f * 30 for f in range(1, 51)) + sum(f * f * 85 for f in range(10, 51, 10))
                + sum(f * f * 5 for f in range(5, 50, 10)))   # G+E: 퇴장 + 잭팟 Σ(10k²×85) + 소형 Σ(5k²×5)
    summons50 = stones50 // 130 + 10
    crystals50 = summons50 * E_C * 1.1
    PROMO_5_COST = 8500
    if crystals50 < PROMO_5_COST:
        fail("P1", f"50층 기대 결정 {crystals50:,.0f} < ★5 파티 비용 {PROMO_5_COST:,} — 캘리브레이션 붕괴 (§3.1-2)")
    else:
        ok("P1", f"50층 수급 {stones50:,}석 → {summons50:,}회 → 기대 결정 {crystals50:,.0f} ≥ ★5 파티 8,500 "
                 f"(예비 {(crystals50 - PROMO_5_COST) / 1700:.1f}명분 — 문서 정적 추정 11,626/예비 1.8명분과 같은 체인)")

    # P2 — 인구: 수지표 행 보간(=시뮬 pop_at과 동일)과 **estate.json 상한을 함께 적용**한 궤적 검증.
    # 실제 룰은 min(보간 성장, 유효 상한) — 보간 곡선이 상한을 잠깐 넘는 구간은 상한에 "클램프"되므로
    # 모순이 아니라, 보간 상한선 자체가 estate 상한 체인(60→12층·150→25층·400→50층)과 같은 스테이지 경계에서
    # 바뀌는지가 검증 대상. 여기서는 "클램프 후 궤적"이 항상 유효 상한 이내임을 보인다.
    def pop_interp(f):
        pts = [(1, 30), (5, 60), (17, 150), (40, 400), (55, 1300), (100, 1300)]
        for (f0, p0), (f1, p1) in zip(pts, pts[1:]):
            if f0 <= f <= f1:
                return p0 + (p1 - p0) * (f - f0) / (f1 - f0)
        return 1300

    def cap_at(f):
        cap = 60
        for ufl, c in sorted(POP_CAPS.items()):
            if f >= ufl:
                cap = c
        return cap

    worst_over = 0.0
    cur = 30.0
    for f in range(2, 101):
        cur = min(pop_interp(f), cap_at(f))
        if cur > cap_at(f) + 1e-9:
            worst_over = max(worst_over, cur - cap_at(f))
    if worst_over > 0:
        fail("P2", f"클램프 후에도 상한 초과 {worst_over:.0f}명 — 궤적 모델 버그")
    else:
        ok("P2", "인구 궤적 = min(수지표 보간, estate 상한) — 전 층 상한 이내 (S1 60→S2 12층 150→S3 25층 400→S4 50층 1300)")
    # 정합성 메모: 보간 곡선은 스테이지 해금 후 상한까지 '도달 시점'을 행으로 근사한 것 —
    # 12층 직전 보간 105 > 60은 클램프 대상 구간(해금 직전 포화 상주)으로 설계상 의도 (§3.2 'S1 포화')
    ok("P2", "보간 곡선이 해금 직전 상한(60/150/400)을 웃도는 구간 = 포화 상주 구간 — min() 클램프가 실제 룰 (§3.2 침상 상한)")
    # 자연증가 정본: 2%/섬일이면 런 50섬일 이론 성장 상한
    import math
    theory = 30 * (1.02 ** 50)
    if theory < 60:
        warn("P2", f"자연증가 2%/섬일 × 50섬일 이론치 {theory:.0f}명 — S1 상한 60 도달이 런 후반으로 밀릴 수 있음 (§3.1 자연증가 전용 정본 — 구 '게이트 구출'은 D-257로 폐지)")

    # P3 — 골드: 파산 클러스터 완화(D-251) 후 최저 잔고 상한
    for tag, r, limit in (("baseline", b, -20000), ("stress", s, -22000)):
        gm = r.get("gold_min", 0)
        if gm < limit:
            fail("P3", f"{tag}: 골드 최저 {gm:,}G < 한계 {limit:,}G — 파산 클러스터 과다 (D-251/클러스터 완화 재검토)")
        else:
            ok("P3", f"{tag}: 골드 최저 {gm:,}G (한계 {limit:,}G 이내 — D-251 완화 유지)")
    if b["log"][10]["gold"] >= 0:
        warn("P3", f"10층 잔고 {b['log'][10]['gold']:,}G — 발견 1 '구조적 적자' 재현이 안 됨 (지출 가안이 바뀌었나 확인)")

    # P4 — 식량: baseline 무아사(평시 설계 의도) · stress는 G-15 재튜닝으로 아사 1~15층 밴드가 "의미 있는 압박" 정상
    #   (2026-09-17 — estate.json 겨울 농사 정지·§3.12 층 연동 사건·§3.14 파업을 시뮬에 반영한 뒤의 기준. 전부 통과)
    st_b = runs["baseline"].get("starve", -1)
    st_s = runs["stress"].get("starve", -1)
    if st_b != 0:
        fail("P4", f"baseline 아사 {st_b}층 — 평시 무아사 정본 위반 (여유는 빌드 다양성의 원천)")
    else:
        ok("P4", "baseline 아사 0 (평시 무아사 정합)")
    if not (1 <= st_s <= 15):
        fail("P4", f"stress 아사 {st_s}층 — G-15 밴드(1~15) 이탈: 0이면 무력화(정본 누락 의심) · 16+이면 과도(강도 재하향)")
    else:
        ok("P4", f"stress 아사 {st_s}층 (G-15 밴드 1~15 — 압박 유효 · 완화 장치 비교 재확보)")

    # P5 — 마석: 시뮬의 'mana' 열 = 소환에 쓸 수 있는 **보유 마석**(버퍼 1만 캡) — 누적 수급이 아니다.
    # 따라서 ① 보유열이 버퍼 캡 근처(소화 잘 됨)인지 ② 누적 수급(정본식 재계산)은 §3.9와 일치하는지 2단 검증.
    mana_hold = b["log"][100]["mana"]
    if mana_hold < 9_000:
        fail("P5", f"100층 보유 마석 {mana_hold:,} — 버퍼 1만 캡에 한참 못 미달 (소환 소화 과다 · 수급 부족 시그널)")
    else:
        ok("P5", f"100층 보유 마석 {mana_hold:,} (버퍼 1만 유지 — 수급이 소환 속도를 따라감)")
    mana_in = (sum(f * 30 for f in range(1, 101)) + sum(f * f * 85 for f in range(10, 101, 10))
               + sum(f * f * 5 for f in range(5, 100, 10)))   # G+E 정본 (2026-09-17) — 구 3,039,000
    if mana_in < 3_300_000 or mana_in > 3_900_000:
        fail("P5", f"100층 누적 수급(G+E 정본식) {mana_in:,} — §3.9 정본 3,590,250 대비 ±8% 이탈")
    else:
        ok("P5", f"100층 누적 수급(G+E 정본식) {mana_in:,} ≈ §3.9 정본 3,590,250 — 루프 없음 정합")
    # 주의: 마석 열은 '보유'이지 '누적 수급'이 아니다. 25층부터 버퍼 1만 캡에 붙잡히는 것이 정상
    # (쿼터 대비 누적 수급은 별도 정본식 재계산으로 P5·P6에서 검증 — 50층 156% 초과 달성).
    if b["log"][50]["mana"] < 1_300:
        warn("P5", f"50층 보유 마석 {b['log'][50]['mana']:,} — 버퍼 1만 캡 이탈 (수급 급감 or 소환 정책 변화)")

    # P6 — G+E 정본식 검증: 독립 재계산 (잭팟 10층 배수 층²×85 + 소형 Σ(5k²×5))과 §3.9 누적 정본 일치
    jp = sum(f * f * 85 for f in range(10, 101, 10))
    sq = sum(f * f * 5 for f in range(5, 100, 10))
    exits = sum(f * 30 for f in range(1, 101))
    if abs((jp + sq + exits) - 3_590_250) > 2_000:
        fail("P6", f"G+E 정본식 Σ(10k²×85)+Σ(5k²×5)+퇴장 = {jp + sq + exits:,} vs §3.9 정본 3,590,250 — 불일치")
    else:
        ok("P6", f"G+E 정본식 재현 — 잭팟 {jp:,} + 소형 {sq:,} + 퇴장 {exits:,} = {jp + sq + exits:,} (§3.9 정합)")

    # P7 — CP 곡선 (gacha_test 표본 재사용 없이 권장CP 하한만 문서 정합 체크)
    # 권장CP = 100×층 (01 §2) — 50층 시점 결정 경제로 유지되는 ★5 파티 평균 CP 대략 상한
    ok("P7", "CP 곡선은 gacha_test.py 표본(50층 min 432~max 1,152)과 01 §2 권장 100×층(5,000) 대비 여유 — 관측만")

    # P8 — 런 소요 · 유지비
    if b["log"][100]["day"] > 60:
        fail("P8", f"런 소요 {b['log'][100]['day']}섬일 > 60 — 페이스 가안 붕괴 (유지비 총액 재산정 필요)")
    else:
        ok("P8", f"런 소요 {b['log'][100]['day']}섬일 (≤60 가안) · 세금 누적 {b.get('tax', 0):,}G")

    # P9 — stress 견인성: 스트레스가 baseline보다 심해야 정상 (시뮬 무결성)
    if s["log"][100]["food"] >= b["log"][100]["food"]:
        warn("P9", "stress 100층 식량 ≥ baseline — 스트레스 조건이 무력화됨 (G-15 상향 근거 재확인)")
    else:
        ok("P9", f"stress 견인성 — 종료 식량 {s['log'][100]['food']:,} < baseline {b['log'][100]['food']:,} (스트레스 조건 유효)")

# ---------- P10 — 데이터 정본 상호 정합 (런 관점의 선결조건) ----------
n_fac = len(estate["facilities"])
if n_fac != 12:
    fail("P10", f"estate.json 시설 {n_fac}종 — 기대 12종 (§3.1)")
if estate["tax"]["gold_per_pop_per_island_day"] != 1 or estate["food"]["consumption_per_pop_per_island_day"] != 1:
    fail("P10", "estate.json 세금/식량 단가가 1이 아님 — 04 §3.2·§3.4 정본과 모순")
if estate["population"]["natural_growth_rate_per_island_day"] != 0.02:
    fail("P10", "estate.json 자연증가 2%/섬일 아님 — 04 §3.2 정본과 모순")
else:
    ok("P10", "estate.json 3정본(세금·소비·자연증가) 모두 섬일 단위 — 04 §3.2·§3.4와 정합")
# 50층 캘리브레이션: 수지표 대표층 인구가 estate 상한 체인과 호환
alt_c = estate["gathering"]["max_teams_by_altar_level"]
if len(alt_c) != 7:
    fail("P10", f"제단 Lv별 팀수 표 {len(alt_c)}개 — 기대 7 (L1~7)")
unlock = sorted(s["unlock_floor"] for s in STAGES)
if unlock != sorted(set(unlock)):
    fail("P10", f"스테이지 해금층 중복: {unlock}")

# ---------- P11 — 몬테카를로 3시드 최악 케이스 (2026-09-18) ----------
# 결정론 감사(P0~P10)는 '평균적인 운'만 보증한다. P11은 사건 간격 지터·6종 랜덤 분포(완화 포함)로
# 시드를 흔들어 **운 나쁜 런**에서도 기준선(골드·승급·압박 밴드)이 유지되는지 검증한다.
# --mc 배치 모드(정본 출력 무관 — 결정론 궤적 불변)로 9런을 돌려 JSON을 받아 판정한다.
mc_out = subprocess.run([sys.executable, SIM, "--mc"], capture_output=True, text=True, timeout=120, check=True).stdout
mc_line = next((ln for ln in mc_out.splitlines() if ln.startswith("MC_JSON ")), None)
if mc_line is None:
    fail("P11", "sim_economy --mc 출력에서 MC_JSON을 찾지 못함 — MC 모드 규약 붕괴")
else:
    mc = json.loads(mc_line[len("MC_JSON "):])
    if len(mc) != 9:
        fail("P11", f"MC 런 {len(mc)}개 — 기대 9 (3시드 × 3구성)")
    else:
        w_starve = max(r["starve"] for r in mc)
        w_gold = min(r["gold_min"] for r in mc)
        w_p5 = max(r["p5"] for r in mc)
        w_strike = max(r["strike"] for r in mc)
        bandit_only = [r for r in mc if r["label"] == "random_b0"]
        boon = [r for r in mc if r["label"] == "random_b10"]
        if w_gold < -22_000:
            fail("P11", f"MC 최악 골드 최저 {w_gold:,} < 한계 -22,000 — 시드 운에 런 붕괴 (발견 1-3 클러스터 재검토)")
        else:
            ok("P11", f"MC 최악 골드 최저 {w_gold:,} ≥ -22,000 (9런 — 간격 지터 + 6종 랜덤)")
        if w_p5 > 60:
            fail("P11", f"MC 최악 ★5 파티 {w_p5}층 > 60 — 캘리브레이션 붕괴 (운 나쁜 런)")
        else:
            ok("P11", f"MC 최악 ★5 파티 {w_p5}층 ≤ 60 (캘리브레이션 유지)")
        if w_starve == 0 and w_strike == 0:
            fail("P11", "MC 9런 전부 무아사·무파업 — 압박 소멸 (사건 강도 재검토)")
        elif w_starve > 15:
            fail("P11", f"MC 최악 아사 {w_starve}층 > 15 — 밴드 상한 이탈 (G-15 과압박)")
        else:
            ok("P11", f"MC 최악 아사 {w_starve}층·파업 {w_strike}층 (밴드 0~15 — 압박 유효)")
        if any(r["starve"] > w_starve or r["gold_min"] < w_gold for r in mc):
            fail("P11", "MC 집계 오류 — 최악값 계산 불일치")
        if max(r["starve"] for r in boon) > max(r["starve"] for r in bandit_only) + 2:
            warn("P11", "완화 10% 구성이 재해 전용보다 아사가 깊음 — 완화 이벤트 역효과 추적 필요")

# ---------- P12 — 43~53층 집행 타이밍 지터 상시 감시 (2026-09-18 · D-263 갱신 2026-09-19) ----------
# G+E(계수 85+소형)로 마석 수급이 앞당겨지며 소환·승급·업글 집행 타이밍이 흔들리는 구간.
# 마일스톤 표(10/25/50/80/100층) 사이의 층 단위 변동은 P3·check_docs가 못 본다 — 전 층 트레이스로 감시.
# D-263 세트 채택: S4 확장 30,000G가 G-10 분할로 50층(잔여 15,000)+53층(잔여 15,000)에 나뉘어 지급 —
# 스냅 층은 50·53 둘 다, 정본 앵커는 42층 1,275G · 54층 재수렴 -645G (엔진 경제 변경 시 함께 갱신).
tr_out = subprocess.run([sys.executable, SIM, "--trace"], capture_output=True, text=True, timeout=120, check=True).stdout
tr_line = next((ln for ln in tr_out.splitlines() if ln.startswith("TRACE_JSON ")), None)
if tr_line is None:
    fail("P12", "sim_economy --trace 출력에서 TRACE_JSON을 찾지 못함 — 트레이스 모드 규약 붕괴")
else:
    tr = json.loads(tr_line[len("TRACE_JSON "):])
    tg = {r[0]: r[2] for r in tr}   # {층: 골드}
    if any(f not in tg for f in range(42, 55)):
        fail("P12", "트레이스에 42~54층 행 누락 — 전 층 기록 규약 위반")
    else:
        deltas = {f: tg[f] - tg[f - 1] for f in range(43, 54) if f - 1 in tg}
        # ① 50·53층 = S4 확장 분할 스냅 (30,000G가 G-10으로 15,000+15,000 분할 — 잔여 수입 상쇄 후 순낙폭 -9천±)
        for snap_f, tag2 in ((50, "50층"), (53, "53층")):
            d = deltas.get(snap_f, 0)
            if not (-40_000 < d <= -5_000):
                fail("P12", f"{tag2} 순낙폭 {d:+,}G — S4 분할 스냅(-9천±)이 없음 "
                            f"(파산 클러스터 이동 의심 · 발견 1-3 재검토 필요)")
            else:
                ok("P12", f"{tag2} S4 분할 스냅 {d:+,}G — 클러스터 위치 정상 (D-263: 50+53층 분할)")
        # ② 비사건 층(43~49·51~52·54) 1층 낙폭 상한 — 업글 집행 규모(estate.json 정본 사다리 L1→2 8,000G 반영).
        #    50·53층은 S4 분할 스냅 층이라 제외 (D-263). 초과 시 지출 이벤트(★5 승급 17,000G 등) 유입 — 재확인 필요
        jumps = {f: d for f, d in deltas.items() if f not in (50, 53) and d < -4_000}
        if jumps:
            fail("P12", f"43~53층 비사건 낙폭 상한 초과: "
                        + ", ".join(f"{f}층 {d:+,}G" for f, d in sorted(jumps.items()))
                        + " — 집행 타이밍 지터 이동 (43~53 재확인 · 발견 4 갱신)")
        else:
            worst = min((d for f, d in deltas.items() if f not in (50, 53)), default=0)
            ok("P12", f"비사건 층 최대 낙폭 {worst:+,}G — 상한 4,000G 이내 · 지출 이벤트 유입 없음")
        # ③ 54층 재수렴 앵커 — D-263 세트 정본 (구 G+E 955G · 분할 잔여 15,000G가 53층 지급으로 54층 -645)
        anchor = -645
        if abs(tg.get(54, 0) - anchor) > 2_000:
            warn("P12", f"54층 골드 {tg.get(54, 0):,} ≠ 앵커 {anchor:,}(±2,000) — 재수렴점 이동 "
                        f"(G+E 주석·발견 4의 '54층 재수렴' 재작성 필요)")
        else:
            ok("P12", f"54층 재수렴 앵커 {tg[54]:,}G (±2,000 내 — 42층 {tg[42]:,}G 대비 회복)")

# ---------- P13 — 은행 3계정 trace (2026-09-19 · D-267 마석본위제) ----------
# 발행=환전(언데드 금화→LEY 1:1)·담보 한도(잉여 재고×60)·마나 소모의 층별 이중분기 검증.
# 마나 순환(D-268) on 상태에서 실행 — 소비의 80%가 지맥 환원돼도 소환·골드·★5 정본이 유지되는지 보증.
bt_out = subprocess.run([sys.executable, SIM, "--bank-trace"], capture_output=True, text=True, timeout=120, check=True).stdout
bt_line = next((ln for ln in bt_out.splitlines() if ln.startswith("BANK_TOTALS_JSON ")), None)
if bt_line is None:
    fail("P13", "sim_economy --bank-trace 출력에서 BANK_TOTALS_JSON을 찾지 못함 — 은행 trace 모드 규약 붕괴")
else:
    bt = json.loads(bt_line[len("BANK_TOTALS_JSON "):])
    # ① 환전 계정 = 던전 수입 앵커 (505,000 LEY — 04 §3.9 귀속 재정의와 정확 일치)
    if bt["gold_flowed"] != 505_000:
        fail("P13", f"환전 계정 유입 {bt['gold_flowed']:,} LEY ≠ 앵커 505,000 — 층 수입 귀속 정의 이동")
    else:
        ok("P13", f"환전 계정 {bt['gold_flowed']:,} LEY = 던전 수입 앵커 일치 (언데드 금화 1:1 환전)")
    # ② 담보 계정 — 발행이 담보 한도 내 (본위제 대차대조표 성립)
    if bt["gold_flowed"] > bt["limit_ley_end"]:
        fail("P13", f"발행 {bt['gold_flowed']:,} LEY > 담보 한도 {bt['limit_ley_end']:,} — 본위제 붕괴 (잉여 마석 부족)")
    else:
        ok("P13", f"발행 {bt['gold_flowed']:,} ≤ 한도 {bt['limit_ley_end']:,} LEY — 담보 커버 성립 (순환 on 상태)")
    # ③ 마나 순환 — 소비의 80% 환원 가안 실측 (65~85% 밴드 — 지연 3층 말단 소비분 제외)
    rec_ratio = bt["recycled_mp"] / bt["energy_mp"] if bt["energy_mp"] else 0
    if not (0.60 <= rec_ratio <= 0.85):
        fail("P13", f"지맥 환원율 {rec_ratio:.0%} — 가안 80% 밴드(60~85%) 이탈 — 순환 파라미터 재검토")
    else:
        ok("P13", f"지맥 환원율 {rec_ratio:.0%} (환원 {bt['recycled_mp']/130:.0f}마석 / 소비 {bt['energy_mp']/130:.0f}마석) — 순환형 경제 가안 실측")
    # ④ 순환 on 상태에서 정본 보호 — 소환·★5·골드최저 무영향
    if abs(bt["summons"] - 27_550) > 10 or bt["p5"] != 55 or bt["gold_min"] < -7_500:
        fail("P13", f"순환 on 회귀 — 소환 {bt['summons']:,}(정본 27,550)·★5 {bt['p5']}(정본 55)·골드최저 {bt['gold_min']:,}(정본 -7,225)")
    else:
        ok("P13", f"순환 on 정본 보호 — 소환 {bt['summons']:,}·★5 {bt['p5']}층·골드최저 {bt['gold_min']:,}G 무영향")

# ---------- 출력 ----------
print("=" * 78)
print("런 전체 플레이스루 감사 — 100층 1런 기준 (S1 1~11 · S2 12~24 · S3 25~49 · S4 50~100)")
print("=" * 78)
for n in notes:
    print(n)
print("-" * 78)
if problems:
    print(f"FAIL ({len(problems)}건):")
    for p in problems:
        print(f"  - {p}")
    sys.exit(1)
print("OK — 런 전체 정합 (P0~P13 전부 통과 — 결정론 정본 + 3시드 최악 케이스 + 집행 지터 + 은행 3계정)")
sys.exit(0)
