extends GutTest
## 층 진입 한 판 — 편성(06 §3.4) → 전투 턴 루프(`combatStep`) 배선.
##
## 이 파일이 잠그는 것:
##   · 편성이 전투 유닛으로 **그대로** 넘어간다 (id·이름·HP 가 데이터와 같다)
##   · 한 판은 반드시 끝난다 (턴 상한 · 승자 판정이 있다)
##   · 같은 시드면 같은 로그 (결정론)

func _rng(seed_value: int = 20261018) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _hero(name: String, hp: int, atk: float, deff: float = 0.0) -> Dictionary:
	return {
		"name": name, "side": "ally", "hp": hp, "maxHp": hp, "alive": true,
		"atk": atk, "def": deff, "pen": 0.0, "eva": 0.0, "cri": 0.0, "cdmg": 0.0,
		"mag": 0.0, "mdef": 0.0, "magical": false,
	}


func test_build_uses_encounter_party_and_scaled_stats() -> void:
	var floor := 1
	var biomes: Variant = DataLoader.get_biomes()
	var built := FonsFloorRun.build(DataLoader.get_monsters(), biomes, floor, 0)
	var expected := FonsEncounter.build_party(DataLoader.get_monsters(), biomes, floor, 0)
	var mult := FonsScaling.scale_for_floor(floor) \
		* FonsScaling.biome_mult(FonsEncounter.biome_for_floor(biomes, floor))
	assert_eq(built["floor"], floor)
	assert_false(String(built["biome_id"]).is_empty(), "바이옴 id 가 있어야 한다")
	assert_eq(built["party"].size(), expected.size())
	for i in range(expected.size()):
		var unit: Dictionary = built["party"][i]
		assert_eq(unit["id"], expected[i]["id"], "편성 순서가 유지된다")
		assert_eq(unit["name"], expected[i]["name"])
		assert_eq(unit["hp"], maxi(1, int(roundf(float(expected[i]["stats"]["hp"]) * mult))),
			"HP = 데이터 × 층 스케일 × 바이옴 계수")
		assert_eq(unit["side"], "enemy")
		assert_true(unit["alive"])


func test_build_scales_up_with_the_floor() -> void:
	# 같은 종이라면 깊은 층의 HP 가 더 커야 한다 — 층 스케일이 안 걸리면 이 값이 같아진다.
	var shallow := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 1, 0)
	var deep := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 100, 0)
	var count := mini(shallow["party"].size(), deep["party"].size())
	assert_gt(count, 0, "편성이 비었다")
	var scaled := 0
	for i in count:
		if int(deep["party"][i]["hp"]) > int(shallow["party"][i]["hp"]):
			scaled += 1
	assert_eq(scaled, count, "100층 편성 HP 가 1층보다 전부 크다")


func test_data_hero_can_clear_floor_one() -> void:
	# 데이터(races.json 기준스탯 + ★5 Lv130)로 만든 영웅이 실제로 1층을 클리어하는지 — 배선 검증.
	var stats := FonsHeroStats.from_data(DataLoader.load_json("races.json"))
	var field: Dictionary = FonsHeroStats.field_stats(stats.base, 5, 130)
	var heroes := [FonsBattle.unit_from_hero(field, "성좌기사")]
	var out := FonsFloorRun.simulate(_rng(1), DataLoader.get_monsters(), DataLoader.get_biomes(), 1, 0, heroes)
	assert_eq(out["winner"], "ally", "★5 Lv130 이면 1층은 뚫린다")
	assert_true(heroes[0]["alive"], "영웅은 살아 있어야 한다")


func test_deep_blocks_are_winnable_with_floor_level_party() -> void:
	# 2026-10-23 로스터 보강의 수용 기준 — 76·81·96층이 그 층대 레벨(round(층×1.3)) 파티로 뚫린다.
	# 보강 전에는 세 층 모두 0승이었고, 81~85 는 이웃 블록 tier 4 로만 채워졌다.
	var races: Dictionary = DataLoader.load_json("races.json")
	var tree: Dictionary = DataLoader.load_json("job_tree.json")
	var gear: Dictionary = DataLoader.load_json("equipment.json")
	var coef: Dictionary = DataLoader.load_json("job_coef.json")
	for floor in [76, 81, 96]:
		var level := int(roundf(float(floor) * 1.3))
		var heroes := FonsRunState.heroes_from(races, tree, gear, 5, level, floor, coef)
		var out := FonsFloorRun.simulate(_rng(floor), DataLoader.get_monsters(),
			DataLoader.get_biomes(), floor, 0, heroes)
		assert_eq(String(out["winner"]), "ally",
			"%d층(Lv%d) 이 뚫려야 한다 — 패배하면 보강이 되돌아간 것이다" % [floor, level])


func test_run_reaches_a_winner() -> void:
	var built := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 1, 0)
	var heroes := [_hero("영웅", 100000, 99999.0)]
	var out := FonsFloorRun.run(_rng(), heroes, built["party"], 1)
	assert_eq(out["winner"], "ally", "한 방에 정리되는 화력")
	assert_gt(out["turns"], 0)
	assert_gt(out["log"].size(), 0)
	for enemy in built["party"]:
		assert_false(enemy["alive"], "적이 전부 죽어야 끝난다")


func test_run_times_out_as_draw() -> void:
	var heroes := [_hero("영웅", 100000, 1.0)]
	var wall := {
		"name": "벽", "side": "enemy", "hp": 100000000, "maxHp": 100000000, "alive": true,
		"atk": 0.0, "def": 0.0, "pen": 0.0, "eva": 0.0, "cri": 0.0, "cdmg": 0.0,
		"mag": 0.0, "mdef": 0.0, "magical": false,
	}
	var out := FonsFloorRun.run(_rng(), heroes, [wall], 1, 3)
	assert_eq(out["winner"], "draw")
	assert_eq(out["turns"], 3, "턴 상한에서 멈춘다")


func test_run_reports_enemy_win() -> void:
	var heroes := [_hero("영웅", 5, 1.0)]
	var built := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 1, 0)
	var out := FonsFloorRun.run(_rng(), heroes, built["party"], 1)
	assert_eq(out["winner"], "enemy")
	assert_false(heroes[0]["alive"])


func test_run_is_deterministic_for_a_seed() -> void:
	var a := FonsFloorRun.simulate(_rng(7), DataLoader.get_monsters(), DataLoader.get_biomes(), 30, 0,
		[_hero("영웅A", 9000, 400.0), _hero("영웅B", 7000, 350.0)])
	var b := FonsFloorRun.simulate(_rng(7), DataLoader.get_monsters(), DataLoader.get_biomes(), 30, 0,
		[_hero("영웅A", 9000, 400.0), _hero("영웅B", 7000, 350.0)])
	assert_eq(a["log"], b["log"], "같은 시드 = 같은 로그")
	assert_eq(a["winner"], b["winner"])
	assert_eq(a["turns"], b["turns"])


func test_build_does_not_mutate_the_monster_data() -> void:
	# 스케일은 사본에만 건다 — 원본 데이터가 몇 번이고 커지면 그 뒤 판이 오염된다.
	var monsters: Variant = DataLoader.get_monsters()
	var party := FonsEncounter.build_party(monsters, DataLoader.get_biomes(), 1, 0)
	var before: int = int(party[0]["stats"]["hp"])
	FonsFloorRun.build(monsters, DataLoader.get_biomes(), 100, 0)
	var after := FonsEncounter.build_party(monsters, DataLoader.get_biomes(), 1, 0)
	assert_eq(int(after[0]["stats"]["hp"]), before, "원본 몬스터 HP 는 그대로")


func test_build_returns_fresh_units_each_time() -> void:
	# 유닛 Dictionary 는 전투 중 제자리에서 바뀐다 — 편성 결과를 재사용하면 두 번째 판이 반피로 시작한다.
	var first := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 30, 0)
	FonsFloorRun.run(_rng(3), [_hero("영웅", 9000, 400.0)], first["party"], 30)
	assert_true(first["party"][0]["hp"] <= first["party"][0]["maxHp"], "전투 뒤에는 체력이 바뀌어 있다")

	var second := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 30, 0)
	for enemy in second["party"]:
		assert_eq(enemy["hp"], enemy["maxHp"], "새로 만든 유닛은 만피에서 시작한다")

	var out := FonsFloorRun.simulate(_rng(3), DataLoader.get_monsters(), DataLoader.get_biomes(), 30, 0,
		[_hero("영웅", 5000, 200.0)])
	assert_eq(out["party_size"], second["party"].size(), "편성 규모는 데이터에서 다시 센다")


func test_every_floor_run_terminates() -> void:
	# 130층 전수 — 어떤 층도 상한 없이 돌지 않고, 예외 없이 승자 판정에 닿는다.
	var winners := {}
	for floor in range(1, 131):
		var heroes := [_hero("성좌기사", 12000, 700.0, 120.0), _hero("수도사", 9000, 600.0, 90.0)]
		var out := FonsFloorRun.simulate(_rng(floor), DataLoader.get_monsters(), DataLoader.get_biomes(),
			floor, 0, heroes)
		if String(out["winner"]) == "none":
			# 일반 조우가 없는 층(이데아 문턱) — 판이 성립하지 않으므로 턴도 0 이다.
			assert_eq(int(out["turns"]), 0, "%d층 면제는 턴 0" % floor)
			assert_eq(int(out["party_size"]), 0, "%d층 적 0" % floor)
		else:
			assert_true(out["turns"] >= 1 and out["turns"] <= FonsFloorRun.MAX_TURNS,
				"%d층 턴 수 %d" % [floor, out["turns"]])
			assert_true(String(out["winner"]) in ["ally", "enemy", "draw"], "%d층 판정" % floor)
		winners[out["winner"]] = int(winners.get(out["winner"], 0)) + 1
	assert_eq(int(winners.get("ally", 0)) + int(winners.get("enemy", 0)) + int(winners.get("draw", 0)) \
		+ int(winners.get("none", 0)), 130)


func test_combatless_floor_is_exempt_not_a_win() -> void:
	## 126~130 은 일반 조우가 없다 — 빈 편성을 승리로 세면 승률표가 거짓말을 한다.
	var heroes := [_hero("성좌기사", 12000, 700.0, 120.0)]
	var out := FonsFloorRun.simulate(_rng(128), DataLoader.get_monsters(),
		DataLoader.get_biomes(), 128, 0, heroes)
	assert_eq(String(out["winner"]), "none", "면제 판정")
	assert_eq(int(out["party_size"]), 0)
	assert_true(heroes[0]["alive"], "싸우지 않았으니 영웅도 그대로다")


func test_band_win_rate_never_rises_with_depth() -> void:
	# Phase 2.7 완료 정의 — 10층 대역 승률이 깊어질수록 내려가기만 한다(역전 구간 0).
	# 도구(`tools/floor_report.gd`)와 같은 시드·같은 영웅 구성으로 돌린다.
	var races: Dictionary = DataLoader.load_json("races.json")
	var tree: Dictionary = DataLoader.load_json("job_tree.json")
	var gear: Dictionary = DataLoader.load_json("equipment.json")
	var coef: Dictionary = DataLoader.load_json("job_coef.json")
	var wins := []
	for band in 13:
		wins.append(0)
	for floor in range(1, 131):
		var heroes := FonsRunState.heroes_from(races, tree, gear, 5, 130, floor, coef)
		var out := FonsFloorRun.simulate(_rng(floor), DataLoader.get_monsters(), DataLoader.get_biomes(),
			floor, 0, heroes)
		if String(out["winner"]) == "ally":
			wins[(floor - 1) / 10] = int(wins[(floor - 1) / 10]) + 1
	for i in wins.size() - 1:
		assert_true(int(wins[i]) >= int(wins[i + 1]),
			"%d~%d층 %d승 → %d~%d층 %d승 (거꾸로 올랐다)" % [
				i * 10 + 1, i * 10 + 10, int(wins[i]),
				(i + 1) * 10 + 1, (i + 1) * 10 + 10, int(wins[i + 1])])


func test_turn_limit_is_respected() -> void:
	var built := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 1, 0)
	var out := FonsFloorRun.run(_rng(), [_hero("영웅", 100000, 1.0)], built["party"], 1, 1)
	assert_eq(out["turns"], 1)
	assert_eq(out["winner"], "draw", "한 턴으로 못 끝내면 무승부")


func test_hp_knob_reaches_the_party() -> void:
	# 손잡이가 편성까지 내려오는지 — 도구만 손잡이를 들고 심이 무시하면 스윕이 거짓 표가 된다.
	var canon := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 60, 0)
	var heavy := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 60, 0, 2.0)
	assert_eq(heavy["party"].size(), canon["party"].size())
	for i in canon["party"].size():
		assert_gt(int(heavy["party"][i]["hp"]), int(canon["party"][i]["hp"]), "적 HP 가 커진다")


func test_turn_cap_is_a_caller_choice() -> void:
	# 턴 상한은 우리가 정한 값이다 (정본 아님) — 도구가 난이도를 재려고 바꿀 수 있어야 한다.
	var heroes := [_hero("영웅", 100000, 1.0)]
	var built := FonsFloorRun.build(DataLoader.get_monsters(), DataLoader.get_biomes(), 60, 0)
	var short := FonsFloorRun.run(_rng(5), heroes, built["party"], 60, 10)
	assert_true(int(short["turns"]) <= 10)


func test_gatekeeper_build_is_one_boss_and_empty_elsewhere() -> void:
	# 게이트키퍼 경로 — 5층은 보스 1체, 문지기가 없는 층은 빈 편성(대체 편성을 지어내지 않는다).
	var built := FonsFloorRun.build_gatekeeper(DataLoader.get_monsters(), DataLoader.get_biomes(), 5)
	assert_eq(built["party"].size(), 1, "게이트키퍼는 1체")
	assert_eq(built["gatekeeper"], "도플갱어")
	assert_eq(built["party"][0]["side"], "enemy")
	var none := FonsFloorRun.build_gatekeeper(DataLoader.get_monsters(), DataLoader.get_biomes(), 6)
	assert_eq(none["party"].size(), 0, "6층에는 문지기가 없다")
	assert_eq(none["gatekeeper"], "")
	# 130층은 문지기가 둘 걸린다 — 편성도 바이옴 정본(무문의 파수병)을 따라야 한다.
	var idea := FonsFloorRun.build_gatekeeper(DataLoader.get_monsters(), DataLoader.get_biomes(), 130)
	assert_eq(idea["gatekeeper"], "무문의 파수병")
	assert_eq(idea["party"].size(), 1)
