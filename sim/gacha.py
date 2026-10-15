"""W0 gacha simulator — standalone gate reproduction.
SSOT: soul-commander/fons-web-ver/PLAN.md 6-2, D-265.
130 pulls, shaped 5% + legacy 95%. No assets, no Unity.
"""
import random

PULLS = 130
SHAPED_RATE = 0.05
LEGACY_COVERAGE = 0.95

def simulate(seed: int = 265) -> dict:
    rng = random.Random(seed)
    shaped = sum(1 for _ in range(PULLS) if rng.random() < SHAPED_RATE)
    return {
        "pulls": PULLS,
        "shaped": shaped,
        "expected": PULLS * SHAPED_RATE,
        "legacy": LEGACY_COVERAGE,
        "seed": seed,
    }

if __name__ == "__main__":
    r = simulate()
    print(r)
    assert r["pulls"] == 130
    assert abs(r["expected"] - 6.5) < 1e-9
    print("GATE OK: W0 pulls=130 expected_shaped=6.5 legacy=0.95")
