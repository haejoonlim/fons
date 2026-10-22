extends GutTest
## 직업계수 — `data/job_coef.json` (정본은 `sim/center/sims/gacha_test.py`, 05 §8-1).
##
## 이 파일이 잠그는 것:
##   · 트리의 모든 직업이 계수를 가진다 (L1 7 · L2 26) — 빠진 직업이 있으면 조용히 1.0 이 된다
##   · 전직 티어는 6축에 제곱근으로 걸리고 CRI 에는 안 걸린다 (gacha_test.apply_tier_to_stats)
##   · 모르는 직업은 0 이 아니라 배율 1.0 이다

var _coef: Dictionary
var _tree: Dictionary


func before_all() -> void:
	_coef = DataLoader.load_json("job_coef.json")
	_tree = DataLoader.load_json("job_tree.json")


func test_table_shape() -> void:
	assert_eq(_coef["axes"].size(), 7, "축 7종 (HP·ATK·DEF·ASPD·MAG·MDEF·CRI)")
	assert_eq(_coef["l1"].size(), 7, "L1 7종")
	assert_eq(_coef["l2"].size(), 26, "L2 26종")
	assert_almost_eq(float(_coef["tierMul"]["A"]), 1.00, 0.0001)
	assert_almost_eq(float(_coef["tierMul"]["B"]), 1.30, 0.0001)
	assert_almost_eq(float(_coef["tierMul"]["C"]), 1.65, 0.0001)


func test_every_tree_job_has_a_row() -> void:
	# 트리에 있는데 계수가 없으면 그 직업 영웅만 조용히 중립으로 나온다.
	for job in _tree["jobs"]:
		var id := String(job["id"])
		var stage := int(job.get("stage", 0))
		if stage == 1:
			assert_true(_coef["l1"].has(id), "L1 계수 누락: %s" % job["name"])
		elif stage == 2:
			assert_true(_coef["l2"].has(id), "L2 계수 누락: %s" % job["name"])
			assert_eq(String(_coef["l2"][id]["name"]), String(job["name"]), "이름 일치")


func test_l1_multipliers_are_the_table() -> void:
	var m := FonsJobCoef.multipliers(_coef, "l1_warrior")
	assert_almost_eq(float(m["HP"]), 1.2, 0.0001, "전사 HP 1.2")
	assert_almost_eq(float(m["ATK"]), 1.0, 0.0001, "전사 ATK 1.0")
	assert_almost_eq(float(m["CRI"]), 1.05, 0.0001, "전사 CRI 1.05")


func test_l2_tier_is_square_rooted_on_six_axes() -> void:
	# 파쇄사 1.57 / 평탄 티어 B(1.30) → HP 1.57 × √1.30
	var m := FonsJobCoef.multipliers(_coef, "l2_breaker")
	var root := sqrt(1.30)
	assert_almost_eq(float(m["HP"]), 1.57 * root, 0.0001, "HP 는 √티어가 걸린다")
	assert_almost_eq(float(m["MAG"]), 0.52 * root, 0.0001)
	assert_almost_eq(float(m["ASPD"]), 0.73 * root, 0.0001)
	assert_almost_eq(float(m["CRI"]), 1.05, 0.0001, "CRI 는 티어 축이 아니다")


func test_every_row_uses_its_own_tier() -> void:
	for id in _coef["l2"]:
		var row: Dictionary = _coef["l2"][id]
		var tier := String(row["tier"])
		assert_true(_coef["tierMul"].has(tier), "%s 티어 표기 이상: %s" % [id, tier])
		var root := sqrt(float(_coef["tierMul"][tier]))
		var m := FonsJobCoef.multipliers(_coef, id)
		for i in FonsJobCoef.AXES.size():
			var axis: String = FonsJobCoef.AXES[i]
			var want := float(row["coef"][i]) * (root if axis in FonsJobCoef.TIER_AXES else 1.0)
			assert_almost_eq(float(m[axis]), want, 0.0001, "%s %s" % [id, axis])


func test_nameless_is_neutral() -> void:
	# 무명자는 산하 직업이 없는 자리라 중립 1.0 을 쓴다 (데이터 fallbacks 에 근거).
	for axis in FonsJobCoef.AXES:
		assert_almost_eq(float(FonsJobCoef.multipliers(_coef, "l1_nameless")[axis]), 1.0, 0.0001, axis)


func test_unknown_job_is_neutral_not_zero() -> void:
	var m := FonsJobCoef.multipliers(_coef, "l2_does_not_exist")
	for axis in FonsJobCoef.AXES:
		assert_almost_eq(float(m[axis]), 1.0, 0.0001, "모르는 직업은 배율을 안 건다")
	assert_eq(m.size(), FonsJobCoef.AXES.size(), "축은 항상 채운다")


func test_field_stats_applies_job_coef() -> void:
	var stats := {"HP": 100.0, "ATK": 50.0, "DEF": 40.0, "ASPD": 1.0,
		"MAG": 30.0, "MDEF": 30.0, "CRI": 0.05}
	var m := FonsJobCoef.multipliers(_coef, "l2_breaker")
	var plain := FonsHeroStats.field_stats(stats, 3, 10)
	var with_job := FonsHeroStats.field_stats(stats, 3, 10, 1.0, [], {}, m)
	assert_almost_eq(float(with_job["HP"]), float(plain["HP"]) * float(m["HP"]), 0.01)
	assert_almost_eq(float(with_job["CRI"]), float(plain["CRI"]) * float(m["CRI"]), 0.001)
