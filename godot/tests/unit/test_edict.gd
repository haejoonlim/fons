extends GutTest
## 칙령 화면 — 규칙은 모르고, 받은 목록을 그리고 고른 id 만 돌려준다.
## 조건 판정(10층·식량)은 `FonsEstate.set_decree` 몫이다. 화면은 그 이유를 받아 보여 주기만 한다.

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _screen() -> Control:
	var packed := load("res://game/ui/edict/edict.tscn") as PackedScene
	assert_not_null(packed, "edict.tscn 이 로드된다")
	var node: Control = packed.instantiate()
	add_child_autofree(node)
	return node


func _options() -> Array:
	return [
		{"id": "mercantilism", "name_ko": "중상주의", "morale_delta": -15, "tax_mul": 1.3},
		{"id": "distribution", "name_ko": "분배주의", "morale_delta": 15,
			"tax_mul": 0.8, "natural_growth_mul": 1.5},
		{"id": "gathering", "name_ko": "채집장려", "morale_delta": -5, "harvest_mul": 1.2},
	]


func _rows(screen: Control) -> Array:
	return screen.get_node("Center/Panel/VBox/Rows").get_children()


func test_open_lists_the_decrees_with_their_numbers() -> void:
	# 04 §3.7 — 효과는 데이터에서 읽어 문장으로 만든다. 여기서 수치를 지어내지 않는다.
	var screen := _screen()
	screen.open(_options(), "distribution", "파업 중")
	assert_eq(_rows(screen).size(), 3)
	assert_string_contains(String(_rows(screen)[0].text), "중상주의")
	assert_string_contains(String(_rows(screen)[0].text), "세금 +30%")
	assert_string_contains(String(_rows(screen)[0].text), "민심 -15")
	assert_string_contains(String(_rows(screen)[2].text), "채집 +20%")
	assert_string_contains(String(screen.get_node("Center/Panel/VBox/Status").text), "파업")


func test_the_active_decree_is_marked_and_cannot_be_repicked() -> void:
	# 다시 누르면 민심이 한 번 더 붙는다 — 화면에서 막고, 규칙은 `set_decree` 가 한 번 더 막는다.
	var screen := _screen()
	screen.open(_options(), "distribution", "")
	assert_true(_rows(screen)[1].disabled, "켜진 칙령은 잠근다")
	assert_false(_rows(screen)[0].disabled)
	assert_string_contains(String(_rows(screen)[1].text), "켜짐")


func test_pressing_a_row_returns_its_id() -> void:
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id): got.append(id))
	screen.open(_options(), "", "")
	_rows(screen)[2].pressed.emit()
	assert_eq(got, ["gathering"])


func test_the_reason_from_the_rule_shows_on_the_screen() -> void:
	var screen := _screen()
	screen.open(_options(), "", "")
	screen.set_note("식량 30 모자람")
	assert_string_contains(String(screen.get_node("Center/Panel/VBox/Status").text), "식량 30 모자람")


func test_a_number_key_picks_that_decree_instead_of_a_click() -> void:
	# 마우스 없이도 고를 수 있어야 한다 — 목록 순서가 곧 숫자다.
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id): got.append(id))
	screen.open(_options(), "", "")
	screen._unhandled_input(_key(KEY_2))
	assert_eq(got, ["distribution"])


func test_a_number_key_on_the_active_decree_does_nothing() -> void:
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id): got.append(id))
	screen.open(_options(), "distribution", "")
	screen._unhandled_input(_key(KEY_2))
	assert_eq(got, [], "켜진 칙령은 잠겨 있다 — 숫자키로도")


func test_c_closes_the_screen() -> void:
	# 화면이 떠 있는 동안에는 뷰가 입력을 못 받는다 — 닫기도 화면이 받는다.
	var screen := _screen()
	screen.open(_options(), "", "")
	screen._unhandled_input(_key(KEY_C))
	assert_false(screen.visible)


func test_close_reports_itself() -> void:
	var screen := _screen()
	var closed: Array = []
	screen.closed.connect(func(): closed.append(true))
	screen.open(_options(), "", "")
	screen.get_node("Center/Panel/VBox/Close").pressed.emit()
	assert_false(screen.visible)
	assert_eq(closed.size(), 1)
