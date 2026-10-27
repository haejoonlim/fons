extends GutTest
## 타이틀 — 저장된 런이 있을 때만 이어하기가 열리는가.
##
## 세이브가 없는데 이어하기가 열려 있으면 눌렀을 때 새 게임이 시작되고,
## 그 사실을 화면이 말해 주지 않는다. 그 침묵을 여기서 막는다.

func before_each() -> void:
	SaveManager.erase()
	GameState.start_mode = "new"


func after_each() -> void:
	SaveManager.erase()
	GameState.start_mode = "new"


func _scene() -> Node:
	var packed := load("res://game/ui/title/title.tscn") as PackedScene
	assert_not_null(packed, "title.tscn 이 로드된다")
	var node: Node = packed.instantiate()
	add_child_autofree(node)
	return node


func test_continue_is_disabled_without_a_save() -> void:
	var node := _scene()
	assert_true(node.get_node("Center/VBox/Continue").disabled, "세이브가 없으면 이어하기 잠금")
	assert_string_contains(node.get_node("Center/VBox/Status").text, "없다")
	assert_false(node.get_node("Center/VBox/Start").disabled, "새로 시작은 늘 열려 있다")


func test_continue_shows_the_saved_run() -> void:
	_write_save()
	var node := _scene()
	assert_false(node.get_node("Center/VBox/Continue").disabled, "세이브가 있으면 이어하기 열림")
	assert_string_contains(node.get_node("Center/VBox/Status").text, "3층")
	assert_string_contains(node.get_node("Center/VBox/Status").text, "섬 2일")


func test_start_asks_before_overwriting_a_save() -> void:
	_write_save()
	var node := _scene()
	GameState.start_mode = "continue"
	node.get_node("Center/VBox/Start").pressed.emit()
	assert_true(node.get_node("Confirm").visible, "세이브가 있으면 먼저 확인창을 띄운다")
	assert_true(FileAccess.file_exists(SaveManager.path_of()), "확인 전에는 지우지 않는다")
	assert_eq(GameState.start_mode, "continue", "확인 전에는 새 런도 시작하지 않는다")


func test_confirm_wipes_the_save_and_its_backup() -> void:
	_write_save()
	_write_save()   # 두 번 쓰면 이전 판이 .bak 에 남는다
	assert_true(FileAccess.file_exists(SaveManager.path_of() + ".bak"), "백업이 있어야 이 검사가 의미 있다")
	var node := _scene()
	assert_true(node._confirm.confirmed.is_connected(Callable(node, "_on_confirm_new")),
		"확인 버튼이 지우기에 닿는다")
	node._wipe_save()
	assert_false(FileAccess.file_exists(SaveManager.path_of()), "본파일 삭제")
	assert_false(FileAccess.file_exists(SaveManager.path_of() + ".bak"),
		"백업도 지운다 — 남기면 옛 런이 되살아난다")
	assert_false(bool(SaveManager.load_payload()["ok"]), "지운 뒤에는 불러올 것이 없다")


func _write_save() -> void:
	SaveManager.save_payload(FonsSave.to_dict(
		{"seed": "1", "grade": 5, "level": 130, "start_floor": 1, "floor": 3, "heroes": []},
		{"clock_epoch": 1000, "last_settled_day": 2, "stores": {}, "population": 30},
		{"gold": 0, "pull_count": 0}))
