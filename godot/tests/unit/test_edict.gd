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
			"tax_mul": 0.8, "natural_growth_mul": 1.5, "overflow_gold_per_pop": 4},
		{"id": "gathering", "name_ko": "채집장려", "morale_delta": -5, "harvest_mul": 1.2},
	]


func _rows(screen: Control) -> Array:
	return screen.get_node("Center/Panel/VBox/Rows").get_children()


func test_open_lists_the_decrees_with_their_numbers() -> void:
	# 04 §3.7 — 효과는 데이터에서 읽어 문장으로 만든다. 여기서 수치를 지어내지 않는다.
	var screen := _screen()
	screen.open(_options(), ["distribution"], "파업 중")
	assert_eq(_rows(screen).size(), 3)
	assert_string_contains(String(_rows(screen)[0].text), "중상주의")
	assert_string_contains(String(_rows(screen)[0].text), "세금 +30%")
	assert_string_contains(String(_rows(screen)[0].text), "민심 -15")
	assert_string_contains(String(_rows(screen)[1].text), "상한 초과 +4G/명")
	assert_string_contains(String(_rows(screen)[2].text), "채집 +20%")
	assert_string_contains(String(screen.get_node("Center/Panel/VBox/Status").text), "파업")


func test_the_active_decree_is_marked_with_its_slot_and_cannot_be_repicked() -> void:
	# 다시 누르면 민심이 한 번 더 붙는다 — 화면에서 막고, 규칙은 `set_decree` 가 한 번 더 막는다.
	var screen := _screen()
	screen.open(_options(), ["mercantilism", "gathering"], "")
	assert_true(_rows(screen)[0].disabled, "켜진 칙령은 잠근다")
	assert_false(_rows(screen)[1].disabled)
	assert_string_contains(String(_rows(screen)[0].text), "1번 칸")
	assert_string_contains(String(_rows(screen)[2].text), "2번 칸")


func test_pressing_a_row_returns_its_id() -> void:
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id, slot): got.append([id, slot]))
	screen.open(_options(), [], "")
	_rows(screen)[2].pressed.emit()
	assert_eq(got, [["gathering", 0]])


func test_cooldown_locks_the_inactive_rows() -> void:
	## ADR 0011 — 쿨다운 중에는 목록의 비활성 칙령을 잠그고 상태 줄이 남은 층을 말한다.
	var screen := _screen()
	screen.open(_options(), ["mercantilism"], "5층 뒤에 바꿀 수 있다", 2, true)
	assert_true(_rows(screen)[0].disabled, "켜진 줄")
	assert_true(_rows(screen)[1].disabled, "쿨다운 중에는 못 고른다")
	assert_true(_rows(screen)[2].disabled)
	assert_string_contains(String(screen.get_node("Center/Panel/VBox/Status").text), "5층 뒤에")


func test_two_slots_ask_which_slot_before_choosing() -> void:
	## ADR 0011 — 30층 이상에서는 비활성 칙령을 고르면 항상 칸을 고른다. 빈 칸도 자동으로 채우지 않는다.
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id, slot): got.append([id, slot]))
	screen.open(_options(), ["mercantilism"], "", 2)
	_rows(screen)[1].pressed.emit()
	assert_eq(got, [], "칸을 고르기 전에는 나가지 않는다")
	var slots: Control = screen.get_node("Center/Panel/VBox/Slots")
	assert_true(slots.visible, "칸 선택 줄이 뜬다")
	assert_eq(slots.get_child_count(), 3, "1번·2번·취소")
	assert_string_contains(String(slots.get_child(0).text), "1번 — 중상주의")
	assert_string_contains(String(slots.get_child(1).text), "2번 — 비어 있음")
	assert_string_contains(String(screen.get_node("Center/Panel/VBox/Status").text), "어느 칸")


func test_picking_a_slot_returns_id_and_slot() -> void:
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id, slot): got.append([id, slot]))
	screen.open(_options(), ["mercantilism"], "", 2)
	_rows(screen)[1].pressed.emit()
	screen.get_node("Center/Panel/VBox/Slots").get_child(1).pressed.emit()
	assert_eq(got, [["distribution", 1]], "2번 칸으로 간다")


func test_number_keys_pick_a_slot() -> void:
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id, slot): got.append([id, slot]))
	screen.open(_options(), [], "", 2)
	_rows(screen)[2].pressed.emit()
	screen._unhandled_input(_key(KEY_2))
	assert_eq(got, [["gathering", 1]])


func test_cancelling_slot_choice_returns_to_the_list() -> void:
	## Esc·C 는 칸 선택만 취소한다 — 화면을 닫지 않는다.
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id, slot): got.append([id, slot]))
	screen.open(_options(), [], "", 2)
	_rows(screen)[1].pressed.emit()
	screen._unhandled_input(_key(KEY_ESCAPE))
	assert_true(screen.visible, "화면은 열린 채다")
	assert_false(screen.get_node("Center/Panel/VBox/Slots").visible)
	assert_eq(got, [])
	screen._unhandled_input(_key(KEY_C))
	assert_false(screen.visible, "목록에서 다시 C 를 누르면 닫는다")


func test_the_reason_from_the_rule_shows_on_the_screen() -> void:
	var screen := _screen()
	screen.open(_options(), [], "")
	screen.set_note("식량 30 모자람")
	assert_string_contains(String(screen.get_node("Center/Panel/VBox/Status").text), "식량 30 모자람")


func test_a_number_key_picks_that_decree_instead_of_a_click() -> void:
	# 마우스 없이도 고를 수 있어야 한다 — 목록 순서가 곧 숫자다.
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id, slot): got.append([id, slot]))
	screen.open(_options(), [], "")
	screen._unhandled_input(_key(KEY_2))
	assert_eq(got, [["distribution", 0]])


func test_a_number_key_on_the_active_decree_does_nothing() -> void:
	var screen := _screen()
	var got: Array = []
	screen.chosen.connect(func(id, slot): got.append([id, slot]))
	screen.open(_options(), ["distribution"], "")
	screen._unhandled_input(_key(KEY_2))
	assert_eq(got, [], "켜진 칙령은 잠겨 있다 — 숫자키로도")


func test_c_closes_the_screen() -> void:
	# 화면이 떠 있는 동안에는 뷰가 입력을 못 받는다 — 닫기도 화면이 받는다.
	var screen := _screen()
	screen.open(_options(), [], "")
	screen._unhandled_input(_key(KEY_C))
	assert_false(screen.visible)


func test_close_reports_itself() -> void:
	var screen := _screen()
	var closed: Array = []
	screen.closed.connect(func(): closed.append(true))
	screen.open(_options(), [], "")
	screen.get_node("Center/Panel/VBox/Close").pressed.emit()
	assert_false(screen.visible)
	assert_eq(closed.size(), 1)
