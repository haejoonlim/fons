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


func test_hero_mdef_is_ten_not_zero() -> void:
	## 05 §7 표는 `MDEF | 0 + 직업·종족 보정` 이고 원본 구현은 기준값을 10 으로 쓴다
	## (`fons-web-ver/app/src/summon.ts` `buildStats`: `MDEF: Math.round(10 * mdef * gm)`).
	## 0 으로 두면 직업계수가 0 에 곱해져 영웅 MDEF 가 영원히 0 이 되고,
	## 마법형 적의 피해가 감소 없이 그대로 들어온다 (2026-10-21 상층 실측).
	assert_eq(_stats.base["MDEF"], 10.0, "영웅 기준 MDEF 는 10")


func test_hero_mdef_survives_the_coefficients() -> void:
	## 등급·레벨 계수를 걸어도 MDEF 가 0 에 남지 않는지 — 0 이면 상층 마법 피해가 전부 들어온다.
	var field: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130)
	assert_gt(float(field["MDEF"]), 0.0, "★5 Lv130 영웅 MDEF 가 0 이면 안 된다")


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


func test_grade_coefficient_is_1_3_compounded() -> void:
	# 01 §2 — 등급당 ×1.3 복리. ★1 1.00 · ★5 2.86 · ★7 4.83
	assert_almost_eq(FonsHeroStats.grade_coeff(1), 1.00, 0.005, "★1 기준")
	assert_almost_eq(FonsHeroStats.grade_coeff(2), 1.30, 0.005, "★2")
	assert_almost_eq(FonsHeroStats.grade_coeff(5), 2.86, 0.005, "★5 = 1.3^4")
	assert_almost_eq(FonsHeroStats.grade_coeff(7), 4.83, 0.005, "★7 = 1.3^6")


func test_level_coefficient_is_linear_to_130() -> void:
	# 확정 #34 — 1+(Lv−1)×0.05 · Lv130 ×7.45
	assert_almost_eq(FonsHeroStats.level_coeff(1), 1.0, 0.0001, "Lv1 기준")
	assert_almost_eq(FonsHeroStats.level_coeff(50), 3.45, 0.0001, "Lv50")
	assert_almost_eq(FonsHeroStats.level_coeff(130), 7.45, 0.0001, "Lv130 만렙")
	assert_almost_eq(FonsHeroStats.level_coeff(200), 7.45, 0.0001, "레벨 상한 밖은 130 으로 자른다")


func test_field_stats_of_a_completed_hero() -> void:
	# ★5 Lv130 — 크기 스탯 = 기준 × 등급계수 × 레벨계수 (05 §7 필드스탯 식)
	var stats: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130)
	var mul: float = FonsHeroStats.grade_coeff(5) * FonsHeroStats.level_coeff(130)
	assert_almost_eq(stats["HP"], 500.0 * mul, 0.01, "HP")
	assert_almost_eq(stats["ATK"], 45.0 * mul, 0.01, "ATK")
	assert_almost_eq(stats["MAG"], 20.0 * mul, 0.01, "MAG")
	assert_almost_eq(stats["DEF"], 20.0 * mul, 0.01, "DEF")
	assert_almost_eq(stats["MDEF"], 10.0 * mul, 0.01, "MDEF")
	# 05 §7 표의 "0 + 직업·종족 보정" 중 기준값은 원본 구현이 10 이다 (`summon.ts buildStats`).
	# 0 이면 계수가 0 에 곱해져 MDEF 가 영원히 0 이고 마법 피해가 그대로 들어온다.


func test_mana_takes_grade_but_not_level() -> void:
	# 원본 `CombatStats.FromRace` 는 MANA 에 rankMul 을 걸고, `BattleSystem.AddHero` 는
	# Mana 에 lvMul 을 안 건다 (원본 대조 · docs/adr/0005).
	var stats: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130)
	assert_almost_eq(stats["MANA"], 100.0 * FonsHeroStats.grade_coeff(5), 0.01,
		"MANA = 기준 × 등급계수 (레벨계수 없음)")
	assert_lt(stats["MANA"], 100.0 * FonsHeroStats.grade_coeff(5) * FonsHeroStats.level_coeff(130),
		"MANA 에 레벨계수를 곱하지 않는다")


func test_rate_axes_are_not_multiplied() -> void:
	# 01 §2 등급계수 미적용 7종. 퍼센트·회수 축에 ×7.45 를 곱하면 회피·공속이 판을 지배한다.
	var stats: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130)
	assert_almost_eq(stats["MS"], 100.0, 0.0001, "MS 는 100% 그대로")
	assert_almost_eq(stats["ASPD"], 10.0, 0.0001, "ASPD 그대로")
	assert_almost_eq(stats["CRI"], 0.0, 0.0001, "CRI 그대로")
	assert_almost_eq(stats["CDMG"], 0.0, 0.0001, "CDMG 그대로")
	assert_almost_eq(stats["PEN"], 0.0, 0.0001, "PEN 그대로")
	assert_almost_eq(stats["STA"], 80.0, 0.0001, "STA 그대로")


func test_field_stats_identity_at_grade_1_level_1() -> void:
	# 기준값이 곧 ★1 Lv1 이다 — 배율을 안 걸었을 때 데이터와 같아야 한다.
	var stats: Dictionary = FonsHeroStats.field_stats(_stats.base, 1, 1)
	for axis in FonsHeroStats.AXES:
		assert_almost_eq(stats[axis], _stats.base[axis], 0.0001, axis)


func test_purity_multiplies_every_axis() -> void:
	# 05 §7-1 — 순수도는 전 축에 최종 배율. 승급 1회 = −0.04
	var pure: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130, 1.0)
	var promoted: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130, 0.96)
	assert_almost_eq(promoted["HP"], pure["HP"] * 0.96, 0.01, "HP −4%")
	assert_almost_eq(promoted["MS"], 96.0, 0.0001, "비율 축도 순수도는 곱해진다")


func test_keyword_multiplies_before_the_coefficients() -> void:
	# 원본 `CombatStats.FromRace` = 기준 × 종족mods × **키워드** × 등급계수, 그 뒤 AddHero 가 레벨계수.
	var mod := []
	for i in FonsHeroStats.AXES.size():
		mod.append(1.0)
	mod[FonsHeroStats.AXES.find("ATK")] = 2.0
	var out: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130, 1.0, mod)
	var mul: float = FonsHeroStats.grade_coeff(5) * FonsHeroStats.level_coeff(130)
	assert_almost_eq(out["ATK"], _stats.base["ATK"] * 2.0 * mul, 0.01, "카드 배율도 계수와 같이 곱해진다")
	assert_almost_eq(out["HP"], _stats.base["HP"] * mul, 0.01, "안 건드린 축은 그대로")


func test_equipment_is_added_after_the_coefficients() -> void:
	# 원본 `AddHero`: `stats.Atk * lvMul + equipment.Atk` — 장비는 곱이 아니라 **가산**이고 마지막이다.
	var gear := {}
	for axis in FonsHeroStats.AXES:
		gear[axis] = 0.0
	gear["ATK"] = 5.0
	var out: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130, 1.0, [], gear)
	var mul: float = FonsHeroStats.grade_coeff(5) * FonsHeroStats.level_coeff(130)
	assert_almost_eq(out["ATK"], _stats.base["ATK"] * mul + 5.0, 0.01, "ATK = 기준×계수 + 장비")
	assert_almost_eq(out["HP"], _stats.base["HP"] * mul, 0.01, "장비가 없는 축은 가산 없음")


func test_variance_stays_within_seven_percent() -> void:
	# 05 §7 — 개체 변량 ±7%. 소환 시점에 전 축에 걸린다 (`summon.ts buildStats` 마지막 줄).
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var stats: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130)
	for i in 200:
		var v: Dictionary = FonsHeroStats.varied(stats, rng)
		for axis in FonsHeroStats.AXES:
			assert_between(float(v[axis]), float(stats[axis]) * 0.93 - 0.001,
				float(stats[axis]) * 1.07 + 0.001, axis)


func test_variance_is_deterministic_for_a_seed() -> void:
	var stats: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130)
	var a := RandomNumberGenerator.new()
	a.seed = 11
	var b := RandomNumberGenerator.new()
	b.seed = 11
	assert_eq(FonsHeroStats.varied(stats, a), FonsHeroStats.varied(stats, b), "같은 시드 = 같은 변량")


func test_hero_becomes_a_battle_unit() -> void:
	var stats: Dictionary = FonsHeroStats.field_stats(_stats.base, 5, 130)
	var unit: Dictionary = FonsBattle.unit_from_hero(stats, "성좌기사")
	assert_eq(unit["name"], "성좌기사")
	assert_eq(unit["side"], "ally")
	assert_eq(unit["hp"], int(roundf(stats["HP"])), "HP")
	assert_eq(unit["maxHp"], unit["hp"])
	assert_true(unit["alive"])
	assert_almost_eq(unit["atk"], stats["ATK"], 0.0001, "ATK")
	assert_almost_eq(unit["def"], stats["DEF"], 0.0001, "DEF")
	assert_almost_eq(unit["eva"], 0.0, 0.0001, "영웅에게 회피율 축은 없다 (38차)")
	assert_false(unit["magical"], "기본은 물리 공격")
	assert_true(FonsBattle.unit_from_hero(stats, "대마도사", true)["magical"])
