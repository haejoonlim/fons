extends GutTest
## 101층 기억 배분 화면 — 규칙은 모르고, 슬라이더 값 하나를 화력/생존 점수로 돌려준다.
## 배율은 `FonsHeroStats.memory_multiplier` 몫이다 (설계 §3-2).

func _screen() -> Control:
	var packed := load("res://game/ui/memory/memory.tscn") as PackedScene
	assert_not_null(packed, "memory.tscn 이 로드된다")
	var node: Control = packed.instantiate()
	add_child_autofree(node)
	return node


func test_open_starts_at_5_5_and_shows_both_multipliers() -> void:
	var screen := _screen()
	screen.open()
	assert_true(screen.visible, "배분 화면이 뜬다")
	assert_eq(int(screen.get_node("Center/Panel/VBox/Slider").value), 5, "기본값은 5:5")
	var numbers := String(screen.get_node("Center/Panel/VBox/Numbers").text)
	assert_string_contains(numbers, "화력 ×3.71")
	assert_string_contains(numbers, "생존 ×3.71")


func test_confirm_emits_the_split_and_hides() -> void:
	var screen := _screen()
	screen.open(7)
	assert_string_contains(String(screen.get_node("Center/Panel/VBox/Numbers").text),
		"화력 ×6.27", "7점 = 1.30⁷")
	var got := [-1, -1]
	screen.chosen.connect(func(attack: int, guard: int): got[0] = attack; got[1] = guard)
	screen.get_node("Center/Panel/VBox/Confirm").pressed.emit()
	assert_eq(int(got[0]), 7, "고른 화력 점수를 그대로 넘긴다")
	assert_eq(int(got[1]), 3, "나머지는 생존")
	assert_false(screen.visible, "확인하면 닫힌다")


func test_enter_confirms() -> void:
	var screen := _screen()
	screen.open(2)
	var got := [-1, -1]
	screen.chosen.connect(func(attack: int, guard: int): got[0] = attack; got[1] = guard)
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	screen._unhandled_input(event)
	assert_eq(int(got[0]), 2, "Enter 로도 나눈다")
	assert_eq(int(got[1]), 8)
