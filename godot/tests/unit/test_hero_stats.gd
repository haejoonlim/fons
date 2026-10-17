extends GutTest
## 영웅 스탯·CP 가 데이터 정본과 맞는지 — Unity 없이 도는 검산.
## 38차 결정: 회피(EVA) 폐지 · 민첩 = 이동속도(MS, 100% 기준).

var _races: Dictionary
var _stats: FonsHeroStats


func before_all() -> void:
	_races = DataLoader.load_json("races.json")
	_stats = FonsHeroStats.from_data(_races)


func test_thirteen_axes() -> void:
	assert_eq(FonsHeroStats.AXES.size(), 13, "스탯 13축")


func test_no_evade_and_ms_is_a_stat() -> void:
	var base: Dictionary = _races["meta"]["heroBaseStats"]
	assert_false(base.has("eva"), "회피(EVA)는 데이터에서 사라졌다")
	assert_true(base.has("ms"), "이동속도(MS)는 실스탯이다")
	assert_almost_eq(_stats.base["MS"], 100.0, 0.0001, "MS 기준 100%")


func test_every_axis_has_cp_weight() -> void:
	for axis in FonsHeroStats.AXES:
		assert_true(_stats.weights.has(axis), "CP 가중치 누락: " + axis)
		assert_gt(_stats.weights[axis], 0.0, "CP 가중치는 0보다 커야 한다: " + axis)


func test_ms_enters_combat_power() -> void:
	## 회피가 빠지고 MS 가 들어왔는지 — MS 만 올렸을 때 CP 가 올라야 한다.
	var before: float = _stats.combat_power(_stats.base)
	var faster: Dictionary = _stats.base.duplicate()
	faster["MS"] = 200.0
	assert_gt(_stats.combat_power(faster), before, "MS 는 CP 식에 있다")


func test_keyword_multiplies_stats() -> void:
	var mod := []
	for i in FonsHeroStats.AXES.size():
		mod.append(1.0)
	mod[FonsHeroStats.AXES.find("MS")] = 1.5
	var after: Dictionary = _stats.with_keyword(mod)
	assert_almost_eq(after["MS"], 150.0, 0.0001, "민첩 카드 ×1.5 → MS 150%")
	assert_almost_eq(after["HP"], _stats.base["HP"], 0.0001, "다른 축은 그대로")


func test_neutral_keyword_keeps_power( ) -> void:
	## 배율이 전부 1 이면 CP 도 그대로다 (재배분 카드의 기준점).
	var mod := []
	for i in FonsHeroStats.AXES.size():
		mod.append(1.0)
	assert_almost_eq(_stats.keyword_power_ratio(mod), 1.0, 0.0001)


func test_keyword_ratio_reads_job_tree_cards() -> void:
	## 카드의 statMod 가 실제로 CP 를 옮기는지 — 데이터 모양(13축 배열)이 맞는지 잠근다.
	## CP 배율 == power 검산은 기준 장비 빌드가 필요해서 시뮬(cp_formula.py)이 맡는다.
	var tree: Dictionary = DataLoader.load_json("job_tree.json")
	var checked := 0
	for job in tree.get("jobs", []):
		for card in job.get("keywords", []):
			if not card.has("statMod"):
				continue
			assert_eq(card["statMod"].size(), FonsHeroStats.AXES.size(),
				"statMod 는 13축이다: %s" % card["name"])
			assert_gt(_stats.keyword_power_ratio(card["statMod"]), 0.0)
			checked += 1
	assert_gt(checked, 80, "검산한 카드 수")


func test_move_distance_scales_with_ms() -> void:
	assert_almost_eq(FonsCombat.move_distance({"MS": 100.0}, 1.0), FonsCombat.BASE_SPEED, 0.0001)
	assert_almost_eq(FonsCombat.move_distance({"MS": 150.0}, 2.0), FonsCombat.BASE_SPEED * 3.0, 0.0001,
		"MS 150% 면 같은 시간에 1.5배 간다")
