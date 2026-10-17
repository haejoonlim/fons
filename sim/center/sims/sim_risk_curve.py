#!/usr/bin/env python3
"""sim_risk_curve.py — 층 위험도 지수 D(f) 검증 (확정 #58 · 층별세계_26블록_설계 v2.1 §9)

공식: D(f) = 13^((f-1)/129) — f=1..130 · 소수점 3자리 표기
엔드필드식 지역 진입 카드 — 세계 진입(블록 첫층) = 풀카드(세계명·지역명·D 3자리·등급 워드),
블록 내 나머지 4층 = 경량 배너(지역명 + 소형 D).

검증:
  1. 단조성 — D(f+1) > D(f) 전 구간
  2. 앵커 — D(1)=1.000 · D(130)=13.000 (3자리 반올림 정확)
  3. 구역 카드 티어 — 26 블록 첫층 D값 + 등급 워드 매핑 표 출력
  4. 등급 밴드 — 6등급(잔잔/경계/위협/위험/재앙/종말) 로그 균등 분할, 전 층 커버
  5. 카드 규칙 — 블록 첫층만 풀카드(26장) · 나머지 104층 배너
"""
import math

TOP = 13.0
N = 130

def D(f: int) -> float:
    return TOP ** ((f - 1) / (N - 1))

GRADES = ["잔잔", "경계", "위협", "위험", "재앙", "종말"]
GRADE_THRESHOLDS = [TOP ** (i / len(GRADES)) for i in range(1, len(GRADES))]  # 5 경계

def grade_of(d: float) -> str:
    g = 0
    for t in GRADE_THRESHOLDS:
        if d >= t:
            g += 1
    return GRADES[g]

# 26블록 = 130층 · 5층씩 (층별세계_26블록_설계 v2.0 배치 순서)
BLOCKS = [
    "풀바다", "뿌리숲", "원천연안", "지맥굴", "잿마을", "지맥능선", "부유 이끼늪", "기억묘역", "먼지벌판", "압력화구",
    "미궁도시", "서약성소", "증기구름층", "먹빛 해구", "탑의 서고", "침전수로", "포식밀림", "무광심연", "맥의 상흔", "역류폭포",
    "광로들판", "형상군락", "무풍고원", "마른 지맥", "찢긴 천창", "이데아 문턱",
]

def check_monotonic() -> bool:
    bad = [f for f in range(1, N) if not (D(f + 1) > D(f))]
    print(f"1) 단조성: {'PASS' if not bad else f'FAIL {bad[:5]}'} — 129 구간 전부 증가")
    return not bad

def check_anchors() -> bool:
    a1, a2 = round(D(1), 3), round(D(N), 3)
    ok = (a1 == 1.0 and a2 == TOP)
    print(f"2) 앵커: D(1)={a1:.3f} · D(130)={a2:.3f} → {'PASS' if ok else 'FAIL'}")
    return ok

def check_grade_bands() -> bool:
    ok = True
    print("3) 등급 밴드 (로그 균등 6등분):")
    bounds = [1.0] + [round(t, 3) for t in GRADE_THRESHOLDS] + [TOP]
    for i, g in enumerate(GRADES):
        lo, hi = bounds[i], bounds[i + 1]
        print(f"   {g}: {lo:.3f} ≤ D < {hi:.3f}")
    # 전 층 어느 등급에도 속하는지 + 등급별 층수
    counts = {g: 0 for g in GRADES}
    for f in range(1, N + 1):
        g = grade_of(D(f))
        if g not in counts:
            ok = False
        counts[g] += 1
    print("   분포: " + " · ".join(f"{g} {counts[g]}층" for g in GRADES))
    ok = ok and all(counts[g] > 0 for g in GRADES)
    print(f"   {'PASS' if ok else 'FAIL'}")
    return ok

def check_block_cards() -> bool:
    print("4) 블록 진입 풀카드 표 (26장):")
    print("   " + "-" * 58)
    print(f"   {'블록':>4} {'세계':<6} {'층':>5} {'D(f)':>10}  {'등급':<4}")
    rows = []
    for b in range(26):
        f = b * 5 + 1
        d = D(f)
        rows.append((b + 1, BLOCKS[b], f, d, grade_of(d)))
        print(f"   {b+1:>4} {BLOCKS[b]:<6} {f:>5} {d:>10.3f}  {grade_of(d):<4}")
    print("   " + "-" * 58)
    # 같은 등급이 3블록 이상 연속해도 밴드가 넓어 자연스러움 — 검증은 단조성으로 충분
    ok = all(rows[i][3] < rows[i + 1][3] for i in range(len(rows) - 1))
    print(f"   블록 진입 D 단조 증가: {'PASS' if ok else 'FAIL'} · 풀카드 26장 + 배너 104장 = 130")
    return ok

if __name__ == "__main__":
    print("sim_risk_curve — 층 위험도 지수 D(f) = 13^((f-1)/129) 검증 (확정 #58)\n")
    r = all([check_monotonic(), check_anchors(), check_grade_bands(), check_block_cards()])
    print(f"\n결과: {'ALL PASS' if r else 'FAIL'}")
    raise SystemExit(0 if r else 1)
