extends GutTest
## W0 gacha gate. SSOT: fons-web-ver/PLAN.md §6-2 + sim/gacha.py.

func test_pull_count_is_130() -> void:
	assert_eq(FonsGacha.PULLS, 130, "W0 gate: 130 pulls")

func test_expected_shaped_is_6_5() -> void:
	assert_almost_eq(FonsGacha.expected_shaped(), 6.5, 0.0001, "130 * 5% shaped = 6.5")

func test_d265_gate_values() -> void:
	var gate := FonsGacha.d265_gate()
	assert_eq(gate["pulls"], 130)
	assert_almost_eq(gate["shaped_rate"], 0.05, 0.0001)
	assert_almost_eq(gate["legacy"], 0.95, 0.0001)
