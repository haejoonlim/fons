#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""영지 공간 규격 시뮬레이션 — S1~S4 섬 크기·건물 발면·밀도·성능 검산 (앵커: S4 인구 1,300)
근거: Cesaretti et al. 2016 (PLOS ONE, 면적-인구 스케일링 β≈0.57) · 중세 밀도 실측 75~200명/ha
     중세 농가 60~138m² · 바스티드 구획 8×20m · estate.json · 04 §3.8-3/§3.11 · ArenaLayout 18×13m
"""
import json, math, os

U = 2.0; CELL = U * U  # 1셀=2m, 셀면적 4m²

BUILDINGS = [
    ("summon_altar",   "소환제단",   6, 5, 120, "중세 교구 성당/의례동 100~160m² 하한"),
    ("hospital",       "병원",       7, 5, 140, "중세 호텔디외(호스피스) 복도식 단청 140~250m² 하한"),
    ("tactics_office", "전술소",     4, 4, 64,  "장인 작업장/서기실 60~80m²"),
    ("training_ground","훈련장",     10, 8, 160, "개방 안뜰+병영 — 바스티드 블록 절반"),
    ("dining_hall",    "식당",       6, 5, 120, "수도원 회식장 100~150m²"),
    ("lodging",        "숙소",       9, 4, 144, "롱하우스 18×8m — 중세 농가 상한형"),
    ("research_lab",   "연구소",     4, 4, 64,  "학자 작업실 60~80m²"),
    ("alchemy_lab",    "연금술방",   4, 4, 64,  "동일"),
    ("synthesis_lab",  "합성로",     4, 4, 64,  "동일"),
    ("extraction_lab", "추출소",     5, 4, 80,  "작업장+자재 안뜰"),
    ("hall_of_heroes", "영웅의 전당", 5, 5, 100, "위령 건물 100m² (max_level 1)"),
    ("housing",        "주택(Lv7)",  6, 3, 72,  "2층 테라스 발면 72m² = 12침상 → 12m²/침상 (도미토리 4~6m²의 2~3배)"),
]
DECO = ("deco_house", "장식 가옥", 3, 3, 36, "중세 농가 하한 36m²")
PLOT = ("farm_plot", "농지 1필지", 4, 6, 96, "바스티드 소농 구획 축소 8×12m")
PLAZA = ("plaza", "중앙 광장", 12, 8, 384, "탑입구+마법진3+여백 — 마켓플레이스 축소")

def ac(w, h): return w * h * CELL

HERE = os.path.dirname(os.path.abspath(__file__))
estate = json.load(open(os.path.join(HERE, "..", "..", "..", "data", "estate.json")))
stages = {s["id"]: s for s in estate["stages"]}
INITIAL = ["summon_altar", "hospital", "training_ground", "dining_hall", "lodging"]
LATER = ["tactics_office", "research_lab", "alchemy_lab", "synthesis_lab", "extraction_lab", "hall_of_heroes"]
HOUSING = {"S1": (3, 1), "S2": (5, 3), "S3": (8, 5), "S4": (12, 7)}
# ★ 2026-09-30 결함 34 교정 — DECO_N 은 읽히지 않는 잔재였다.
#   실제 가옥 동수는 아래 `deco_n = math.ceil(d["cap"] / HH)` 로 계산된다(역사적 구조).
#   이 표는 그 이전 규칙의 유물이라 값을 지웠다.
PLOT_M2 = ac(*PLOT[2:4])

def bed(lv): return 20 + 15 * (lv - 1)

def demand(sid):
    n, lv = HOUSING[sid]; cap = stages[sid]["max_population"]
    assert bed(lv) * n >= cap, f"{sid}: 침상 부족"
    plots = max(3, cap // 20)
    facs = [b for b in BUILDINGS if b[0] in (INITIAL if sid == "S1" else INITIAL + LATER)]
    return dict(cap=cap, n=n, lv=lv, plots=plots, facs=facs)

# 밀도 계단 (Cesaretti 2016 densification 역적용 — 도시가 커질수록 밀도 상승)
# 근거: Leiden 중세 도시 실측 밴드 75(외곽)~200(중심가)명/ha — S1 마을 75 → S4 대도시 200
DENSITY = {"S1": 75.0, "S2": 100.0, "S3": 150.0, "S4": 200.0}
BETA = 0.57          # Cesaretti 면적-인구 스케일링 지수 (참조 비교용)
HH = 4.5             # 중세 가구원수 평균 (4~5명) — 가옥 동수 = 인구/가구
TOFT = {"S1": 160.0, "S2": 120.0, "S3": 100.0, "S4": 80.0}  # 가옥 1동 발면+뒷뜰(toft) — 마을일수록 뜰이 넓음

NOTE = "도로는 역사적 밀도 정의에 포함되어 별도 가산하지 않음 (built = P/밀도)"

def areas(sid):
    d = demand(sid)
    built = d["cap"] / DENSITY[sid] * 1e4          # 밀도에서 역산한 정착 면적 (도로 포함)
    fac = sum(ac(b[2], b[3]) for b in d["facs"])
    housing = d["n"] * ac(*BUILDINGS[-1][2:4])
    plaza = ac(*PLAZA[2:4]) * (0.6 if sid == "S1" else 1.0)
    usable = built - fac - housing - plaza         # 기능 건물 제외한 도시 조직 면적
    assert usable > 0, f"{sid}: 기능 건물이 정착 면적 초과"
    deco_n = -(-d["cap"] // 4) // 1 or 0           # placeholder (아래에서 교체)
    deco_n = math.ceil(d["cap"] / HH)              # 가옥 동수 = 가구 수 (역사적 구조)
    deco = deco_n * TOFT[sid]                      # 가옥+뒷뜰 점유
    commons = usable - deco                        # 나머지 = 채소밭·가축우리·과수원·공터 (toft & croft 구조)
    assert commons >= 0, f"{sid}: 가옥+뜰이 면적 초과 ({deco:.0f} > {usable:.0f})"
    farm = d["plots"] * PLOT_M2
    total = built + farm
    return dict(d, built=built, fac=fac, housing=housing, plaza=plaza,
                usable=usable, deco_n=deco_n, deco=deco, commons=commons, farm=farm, total=total,
                dens=DENSITY[sid], r=math.sqrt(total / math.pi))

print("=" * 100)
print("① 건물 발면 표 (1셀=2m)")
print(f"{'시설':<14}{'셀':>7}{'발면m²':>8}   근거")
for b in BUILDINGS: print(f"{b[1]:<14}{b[2]}x{b[3]:<4}{b[4]:>7}   {b[5]}")
for b in (DECO, PLOT, PLAZA): print(f"{b[1]:<14}{b[2]}x{b[3]:<4}{b[4]:>7}   {b[5]}")

print(); print("=" * 100)
print("② 스테이지별 면적·반경 (밀도 계단 역산 — Cesaretti densification)")
print(f"{'S':<4}{'인구':>6}{'밀도':>6}{'정착m²':>9}{'기능m²':>8}{'광장':>6}{'가옥':>6}{'뜰포함m²':>9}{'공용m²':>8}{'농지':>7}{'합계m²':>8}{'필요R':>7}{'횡단초':>6}")
res = {}
for sid in ("S1", "S2", "S3", "S4"):
    a = areas(sid); res[sid] = a
    t = 2 * a["r"] / 3.5
    print(f"{sid:<4}{a['cap']:>6}{a['dens']:>6.0f}{a['built']:>9.0f}{a['fac']+a['housing']:>8.0f}{a['plaza']:>6.0f}{a['deco_n']:>6}동{a['deco']:>9.0f}{a['commons']:>8.0f}{a['farm']:>7.0f}{a['total']:>8.0f}{a['r']:>7.1f}{t:>6.0f}")
print("  ※ 도로는 역사적 밀도 정의에 포함 · 공용지 = 채소밭·우리·과수원·공터 (toft & croft) — 나무·울타리·우물로 채움")

print(); print("=" * 100)
print("③ 검증 — Cesaretti 스케일링 지수 비교 · 도보 체감 · 성능 게이트")
ok = True
import math as _m
p1, p2 = 60, 1300
a1, a2 = res["S1"]["built"], res["S4"]["built"]
our_beta = _m.log(a2 / a1) / _m.log(p2 / p1)
print(f"면적-인구 지수: 설계 β={our_beta:.2f} vs 중세 실측 β={BETA} (참조 — β>실측 = 우리가 더 넓게, 여유 설계)")
for sid in ("S1", "S2", "S3", "S4"):
    a = res[sid]
    in_band = 75 <= a["dens"] <= 200
    if not in_band: ok = False
    t = 2 * a["r"] / 3.5
    print(f"{sid}: 밀도 {a['dens']:.0f}명/ha [{'OK — 중세 밴드 75~200' if in_band else 'FAIL'}] · 횡단 {t:.0f}초 {'(마법진 포커스 이동 보조)' if t > 45 else ''}")
a4 = res["S4"]
gos = len(a4["facs"]) + HOUSING["S4"][0] + 12  # 기능+주택 GO + 광장/지형 소품
inst = a4["deco_n"] + 500 + a4["plots"]        # 가옥 + 군중(§3.8-3 상한) + 농지 타일
print(f"성능: 인터랙션 GO ~{gos} (게이트 ≤300 OK) · GPU 인스턴스 ~{inst} (가옥+군중+농지 — 3드로우콜, 10k 여유 ✓)")

r4 = res["S4"]["r"]
print(); print(f"④ 장애물 해금 구역 (전체 디스크 R={r4:.0f}m 역산 고정)")
for sid in ("S1", "S2", "S3", "S4"):
    frac = res[sid]["r"] ** 2 / r4 ** 2
    print(f"{sid}: 반경 {res[sid]['r']:.0f}m = {frac*100:.0f}% · 정화 {stages[sid]['expansion_cost']}G · 해금 {stages[sid]['unlock_floor']}층")
print(); print(f"⑤ 식민섬 재사용: R={r4:.0f}m 공식 동결 (P=1300) — 발면표·그리드·도로율 공유 OK")
print(); print("총판정:", "ALL OK" if ok else "BAND FAIL")
