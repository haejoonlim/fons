extends GutTest


func after_each() -> void:
	# 층을 깨면 자동 저장이 돈다 — 다음 테스트·실제 게임이 그 파일을 물려받지 않게 지운다.
	SaveManager.erase()
	GameState.start_mode = "new"


## 조립 루트가 실제로 도는지 — 씬을 띄워 탐험 필드가 화면까지 오고, 의도가 심을 움직이는지 본다.
## 단위 테스트(`test_field_state`)는 심만 본다. 이 파일은 **배선**을 본다: 씬 → 심 → 뷰 → HUD.

func test_continue_loads_the_saved_run() -> void:
	## 타이틀 "이어하기" 의 실제 경로 — 저장 파일 → FonsSave → 필드 복원 → HUD.
	var field := FonsFieldState.new()
	field.start(DataLoader.load_json("races.json"), DataLoader.get_monsters(),
		DataLoader.get_biomes(), 265, FonsFieldState.START_FLOOR,
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		DataLoader.load_json("job_coef.json"), _ai(), DataLoader.load_json("basic_attacks.json"))
	field.floor = 2
	var estate := FonsEstate.new()
	estate.start(DataLoader.load_json("estate.json"), 1)
	estate.clock_epoch = int(Time.get_unix_time_from_system())
	SaveManager.save_payload(FonsSave.to_dict(field.to_save(), estate.to_save(),
		{"gold": 5, "pull_count": 1}))
	GameState.start_mode = "continue"
	var node := _scene()
	await wait_process_frames(2)
	assert_string_contains(node.get_node("Hud/FloorLabel").text, "2층", "저장한 층에서 이어한다")
	assert_eq(GameState.gold, 5, "지갑도 같이 돌아온다")
	assert_eq(GameState.pull_count, 1, "소환 횟수도 같이 돌아온다")


func _ai() -> Dictionary:
	return {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}


func test_main_scene_starts_on_the_exploration_field() -> void:
	var packed := load("res://game/main/main.tscn") as PackedScene
	assert_not_null(packed, "main.tscn 이 로드된다")
	var node: Node = packed.instantiate()
	add_child_autofree(node)
	await wait_process_frames(2)

	var floor_label: Label = node.get_node("Hud/FloorLabel")
	var hint_label: Label = node.get_node("Hud/HintLabel")
	assert_string_contains(floor_label.text, "1층", "1층 탐험이 뜬다")
	assert_string_contains(floor_label.text, "0/3", "조우 0/3 에서 시작한다")
	assert_string_contains(hint_label.text, "걷기", "이동 키 안내가 뜬다")
	assert_eq(node._view.entity_count(), 4, "조우 3 + 아바타 1")


func test_island_day_settlement_pays_tax_and_logs_it() -> void:
	## 영지 일과와 섬일 정산의 배선 — 세금·유지비가 지갑에 닿고 수지 줄이 화면 로그에 온다.
	var node := _scene()
	GameState.gold = 100
	node._estate.clock_epoch = int(Time.get_unix_time_from_system()) - 12343
	node._estate.last_settled_day = 1
	node._clock_accum = 0.0
	node._tick_estate(1.0)
	assert_eq(GameState.gold, 120, "세금 30G - 유지비 10G")
	assert_string_contains(node.get_node("Hud/LogLabel").text, "섬 2일")
	assert_string_contains(node.get_node("Hud/LogLabel").text, "유지비")


func test_island_day_runs_the_estate_shift_so_food_piles_up() -> void:
	## 하루가 지나면 영웅들이 영지에서 일하고, 그 수확이 그날 소비보다 먼저 들어간다.
	## 예전에는 정산만 돌아 게임 안에서 식량이 영원히 0 이었다.
	var node := _scene()
	node._estate.clock_epoch = int(Time.get_unix_time_from_system()) - 12343
	node._estate.last_settled_day = 1
	node._clock_accum = 0.0
	node._tick_estate(1.0)
	assert_string_contains(node.get_node("Hud/LogLabel").text, "일과", "하루가 지나면 일과가 돈다")
	assert_gt(int(node._estate.stores["food"]), 0, "수확이 남는다")
	assert_string_contains(node.get_node("Hud/FloorLabel").text, "식량",
		"HUD 가 쌓인 식량을 보여 준다")


func test_clearing_a_floor_costs_morale_when_food_is_out() -> void:
	## 층 클리어 훅 — 식량이 없으면 민심 -5 가 실제 게임 경로에서 돈다 (04 §3.14).
	var node := _scene()
	for i in node._field.explore.sites.size():
		node._field.explore.avatar = node._field.explore.sites[i]["pos"]
		node._on_intent(&"interact", {})
	node._on_intent(&"next_floor", {})
	assert_eq(node._estate.morale, 45, "식량 0 에서 2층으로 넘어가면 민심 50 → 45")
	assert_string_contains(node.get_node("Hud/LogLabel").text, "민심 -5")
	assert_string_contains(node.get_node("Hud/FloorLabel").text, "민심 45", "HUD 가 민심을 보여 준다")


func test_strike_stops_production_and_reaches_the_hud() -> void:
	## 민심 19 가 3층 이어지면 파업 — 채집팀·영웅 일과가 멈추고 HUD 가 남은 층을 보여 준다.
	var node := _scene()
	node._estate.morale = 19
	for i in 3:
		node._note_floor_cleared()
	assert_true(node._estate.is_striking(), "민심 19 × 3층 = 파업")
	assert_true(node._field.log_lines.has("파업 — 전 생산 정지 5층"))
	node._estate.stores["food"] = 100
	var before := int(node._estate.stores["food"])
	node._estate.clock_epoch = int(Time.get_unix_time_from_system()) - 12343
	node._estate.last_settled_day = 1
	node._clock_accum = 0.0
	node._tick_estate(1.0)
	assert_eq(int(node._estate.stores["food"]), before - 30, "생산 없이 소비만 한다")
	assert_string_contains(node.get_node("Hud/LogLabel").text, "파업 중")
	assert_string_contains(node.get_node("Hud/FloorLabel").text, "파업 5층")


func test_unrest_gauge_shows_on_the_hud_below_25_and_warns_at_15() -> void:
	## 불만 게이지 (04 §3.5·§3.12) — 민심 25 미만 진입 표시, 15 이하 경고. 50 이면 없다.
	var node := _scene()
	var label: Label = node.get_node("Hud/UnrestLabel")
	var fill: ColorRect = node.get_node("Hud/UnrestGauge/Fill")
	node._estate.morale = 50
	node._push()
	assert_false(label.visible, "민심 50 — 게이지가 없다")

	node._estate.morale = 24
	node._push()
	assert_true(label.visible, "민심 24 — 게이지가 뜬다")
	assert_string_contains(label.text, "불만")
	assert_false(String(label.text).contains("경고"), "24 는 경고가 아니다")
	var calm := label.get_theme_color("font_color")

	var bar: ColorRect = node.get_node("Hud/UnrestGauge")
	node._estate.unrest_floors = 2
	node._push()
	assert_almost_eq(fill.size.x, 2.0 / 3.0 * bar.size.x, 0.5, "게이지가 2/3 만큼 찬다")

	node._estate.morale = 15
	node._push()
	assert_string_contains(label.text, "경고", "민심 15 — 경고")
	assert_ne(label.get_theme_color("font_color"), calm, "경고는 색으로도 구분한다")

	node._estate.morale = 19
	for i in 3:
		node._note_floor_cleared()
	node._push()
	assert_true(node._estate.is_striking(), "3층 아래로 내려가면 파업")
	assert_false(label.visible, "파업 중에는 게이지를 숨긴다")


func test_move_intent_walks_the_avatar() -> void:
	var node := _scene()
	var before: float = node._field.explore.avatar.x
	node._on_intent(&"move", {"dir": Vector2(1.0, 0.0)})
	node._process(0.5)
	node._on_intent(&"move", {"dir": Vector2.ZERO})
	assert_gt(node._field.explore.avatar.x, before, "move 의도가 아바타를 걷게 한다")
	assert_lt(node._field.explore.avatar.x, FonsExplore.FIELD_WIDTH, "필드 밖으로 나가지 않는다")


func test_interact_fights_a_contact_and_retreat_returns_to_entry() -> void:
	var node := _scene()
	var site: Dictionary = node._field.explore.sites[0]
	node._field.explore.avatar = site["pos"]
	node._on_intent(&"interact", {})
	assert_eq(node._field.explore.cleared, 1, "접촉한 조우를 이긴다")
	assert_gt(node.get_node("Hud/LogLabel").text.length(), 0, "전투 로그가 화면까지 온다")

	node._on_intent(&"retreat", {})
	assert_eq(node._field.explore.avatar, Vector2.ZERO, "후퇴하면 입구로 돌아온다")
	assert_eq(node._field.explore.cleared, 1, "지운 조우는 후퇴해도 남는다 (D-265)")


func test_clearing_the_mission_advances_and_restart_resets() -> void:
	var node := _scene()
	for i in node._field.explore.sites.size():
		node._field.explore.avatar = node._field.explore.sites[i]["pos"]
		node._on_intent(&"interact", {})
	assert_true(node._field.mission_done(), "조우 셋을 정리하면 미션이 끝난다")
	node._on_intent(&"next_floor", {})
	assert_string_contains(node.get_node("Hud/FloorLabel").text, "2층", "미션 완료 뒤 다음 층")

	node._on_intent(&"restart", {})
	assert_string_contains(node.get_node("Hud/FloorLabel").text, "1층", "재시작은 1층으로 돌린다")
	assert_eq(node._field.explore.cleared, 0)


func _scene() -> Node:
	var packed := load("res://game/main/main.tscn") as PackedScene
	var node: Node = packed.instantiate()
	add_child_autofree(node)
	return node
