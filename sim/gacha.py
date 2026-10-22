"""소환 규칙 게이트 — 원본 확정값 재현.

이 파일이 존재하는 이유:
  이 저장소는 원본 Unity 저장소(haejoonlim/soul-commander)의 정본을 Godot으로 옮기는 중이다.
  소환 확률·천장·종족 롤은 밸런스의 뿌리라서, 코드가 정본과 다른 값을 쓰면 게임이 조용히 달라진다.
  그래서 여기서 정본 수치를 선언하고, 시뮬레이션이 그 수치를 실제로 재현하는지 확인한다.

출처 (원본 클론 2026-10-17 대조):
  확정 #32  소환 확률표 · 추첨 = 단일 난수 vs 누적 밴드(등급마다 재추첨 금지)
            ★4 피티 소프트 70회부터 회차당 +2%p · 하드 130회 보장 · ★5+ 하드 5,200회(★5:★6 = 5:1 교대)
            천장은 전부 비공개 — 유저에게 존재·횟수·소프트 시작점을 표기하지 않는다
  확정 #33  천장 수치(70/130/5,200)는 가안 — 구조만 확정, 플탐 후 확정
  확정 #11 · D-276  종족 롤 = shaped 5% + legacy 20종 95%(기존 종족별 균등 4.75%)
                    신규 런 시작 영웅은 legacy-only
  확정 #16  소환 티켓 단가 130마석 · 최초 10회 무료(#17)

이전 버전에 있던 `PULLS = 130`("130회 소환")과 `expected_shaped = 6.5`는 지웠다.
  원본에 '소환 130회'라는 정의가 없다. 원본의 130은 ① 탑 130층 ② 티켓 단가 130마석
  ③ Lv130 만렙 ④ 1마석 = 130MP ⑤ ★4 하드 천장 130회 ⑥ 에너지 배급 상한 −130석이다.
  또 이 파일은 D-265를 근거로 적고 있었지만 D-265는 층 미션 시스템이지 가챠가 아니다.
"""
import os
import random
import sys

# 확정 #32 — 합 100.00 (%). 등급마다 재추첨하지 않고 누적 밴드로 한 번에 뽑는다.
RARITY_BANDS = (
    ("★1", 70.04),
    ("★2", 20.00),
    ("★3", 8.70),
    ("★4", 1.20),
    ("★5", 0.05),
    ("★6", 0.01),
)

# 확정 #16 · #17 — 마석
TICKET_COST = 130
FREE_SUMMONS = 10

# 확정 #32 천장 (수치 자체는 #33 가안)
SOFT_PITY_START = 70
SOFT_PITY_STEP = 0.02
HARD_PITY_4 = 130
HARD_PITY_5PLUS = 5200

# 확정 #11 · D-276 종족 롤
SHAPED_RATE = 0.05
LEGACY_RATE = 0.95
LEGACY_SPECIES = 20

# 시뮬레이션 표본 수 — 게임 상수가 아니라 검증 파라미터다 (registry 에 넣지 않는다).
SAMPLE_SIZE = 200000
SEED = 265


def band_sum() -> float:
    """확률표 합. 정본은 정확히 100.00 이다."""
    return sum(p for _, p in RARITY_BANDS)


def roll_rarity(u: float) -> str:
    """단일 난수 u(0.0~1.0) 하나로 등급을 뽑는다 — 누적 밴드 방식.

    등급마다 따로 재추첨하면 ★4 이상이 33배 과소출현하는 결함이 있었다(확정 #32).
    """
    point = u * 100.0
    acc = 0.0
    for grade, pct in RARITY_BANDS:
        acc += pct
        if point <= acc:
            return grade
    return RARITY_BANDS[-1][0]


def roll_race(u: float) -> str:
    """종족 계열 롤 — shaped 5% 아니면 legacy 95% (확정 #11 · D-276)."""
    return "shaped" if u < SHAPED_RATE else "legacy"


def simulate(sample: int = SAMPLE_SIZE, seed: int = SEED) -> dict:
    rng = random.Random(seed)
    rarity = {grade: 0 for grade, _ in RARITY_BANDS}
    shaped = 0
    for _ in range(sample):
        rarity[roll_rarity(rng.random())] += 1
        if roll_race(rng.random()) == "shaped":
            shaped += 1
    return {
        "sample": sample,
        "seed": seed,
        "rarity": rarity,
        "shaped": shaped,
        "shaped_rate": shaped / sample,
    }


def _tolerance(pct: float, sample: int) -> float:
    """이항분포 3시그마. 표본이 크면 좁아지고, 희귀 등급은 넓게 잡힌다."""
    p = pct / 100.0
    return max(3.0 * (p * (1.0 - p) / sample) ** 0.5 * 100.0, 0.0005)


def check() -> dict:
    """정본 수치를 시뮬레이션이 재현하는지 검사한다. 실패는 예외로 알린다."""
    # `100%%` — 이 줄은 % 포맷이라 `100%가` 로 쓰면 assert 가 터지는 순간 ValueError 가 나고
    # 진짜 이유(합이 얼마였는지)가 사라진다. 2026-10-18 실측으로 걸렸다.
    assert abs(band_sum() - 100.0) < 1e-9, "확정 #32 확률표 합이 100%%가 아닙니다: %r" % band_sum()

    result = simulate()
    sample = result["sample"]
    largest = 0.0

    for grade, pct in RARITY_BANDS:
        observed = result["rarity"][grade] / sample * 100.0
        delta = abs(observed - pct)
        largest = max(largest, delta)
        assert delta <= _tolerance(pct, sample), (
            "%s 분포가 정본 밖입니다: 정본 %.2f%% / 관측 %.4f%% (표본 %d)"
            % (grade, pct, observed, sample)
        )

    shaped_delta = abs(result["shaped_rate"] - SHAPED_RATE)
    assert shaped_delta <= _tolerance(SHAPED_RATE * 100.0, sample) / 100.0, (
        "shaped 비율이 정본 밖입니다: 정본 %.2f / 관측 %.4f"
        % (SHAPED_RATE, result["shaped_rate"])
    )

    return {"result": result, "largest_delta_pct": largest, "shaped_delta": shaped_delta}


def main() -> int:
    out = check()
    result = out["result"]
    bands = " ".join("%s=%.4f%%" % (g, result["rarity"][g] / result["sample"] * 100.0)
                     for g, _ in RARITY_BANDS)
    print("sample=%d seed=%d" % (result["sample"], result["seed"]))
    print("rarity: %s" % bands)
    print("shaped=%.4f (정본 %.2f) legacy=%.4f" % (result["shaped_rate"], SHAPED_RATE, LEGACY_RATE))
    print("band_sum=%.2f%% | 최대 편차 %.4f%%p | shaped 편차 %.5f"
          % (band_sum(), out["largest_delta_pct"], out["shaped_delta"]))
    print("GATE OK: 확정 #32 확률표·#11 종족 롤 재현 "
          "(표본 %d, seed %d)" % (result["sample"], result["seed"]))
    return 0


if __name__ == "__main__":
    # 계약 G-1~G-4 — 실패는 assert traceback 이 아니라 `[FAIL] gacha — …` 로 끝난다.
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
    from gate_contract import run  # noqa: E402
    sys.exit(run("gacha", main))
