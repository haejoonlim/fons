class_name FonsGacha
extends RefCounted
## Ports W0 gacha rules. SSOT: fons-web-ver/PLAN.md §6-2 + sim/gacha.py.
## 130 pulls, shaped 5% + legacy, D-265 gate.

const PULLS := 130
const SHAPED_BONUS := 0.05
const LEGACY_COVERAGE := 0.95

static func expected_shaped(pulls: int = PULLS) -> float:
	return float(pulls) * SHAPED_BONUS

static func d265_gate() -> Dictionary:
	return {"pulls": PULLS, "shaped_rate": SHAPED_BONUS, "legacy": LEGACY_COVERAGE}
