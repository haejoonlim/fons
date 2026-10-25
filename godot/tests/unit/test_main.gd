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
