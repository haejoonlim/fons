extends Control
## 101층 한 번 — 100층을 올라온 기억 10점을 화력과 생존에 나눈다.
##
## 규칙은 여기 없다. 배율은 `FonsHeroStats.memory_multiplier` 가 정하고, 이 화면은
## **화력 점수 하나**만 돌려준다 (생존 = 10 − 화력). 닫기는 없다 — 한 번뿐인 선택이다.
## 근거·측정: docs/design/★5_101_120_기억_성장축_설계.md

signal chosen(attack: int, guard: int)

@onready var _slider: HSlider = $Center/Panel/VBox/Slider
@onready var _numbers: Label = $Center/Panel/VBox/Numbers
@onready var _confirm: Button = $Center/Panel/VBox/Confirm


func _ready() -> void:
	_confirm.pressed.connect(_accept)
	_slider.value_changed.connect(_refresh)
	hide()


func open(attack: int = 4) -> void:
	## 기본값 4:6 — 만피 표(101~120 10시드 100/100)와 사슬(130 10/10)에서 가장 안전하다.
	## 5:5는 사슬에서 130에 1/5로 남아 542턴 잔당전이 된다 (130_무승부_턴상한_판단.md).
	_slider.value = clampi(attack, 0, FonsHeroStats.MEMORY_MAX)
	_refresh(_slider.value)
	show()


func _refresh(value: float) -> void:
	var attack := int(value)
	var guard := FonsHeroStats.MEMORY_MAX - attack
	_numbers.text = "화력 ×%.2f · 생존 ×%.2f — 화력 %d점 · 생존 %d점" % [
		FonsHeroStats.memory_multiplier(attack),
		FonsHeroStats.memory_multiplier(guard),
		attack, guard,
	]


func _accept() -> void:
	var attack := int(_slider.value)
	hide()
	chosen.emit(attack, FonsHeroStats.MEMORY_MAX - attack)


func _unhandled_input(event: InputEvent) -> void:
	## 화면이 떠 있는 동안 세계는 멈춰 있다 (`get_tree().paused`). 멈춘 트리에서도 입력을
	## 받으려고 이 씬은 `process_mode = ALWAYS` 다 — Enter 만 받는다.
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code := (event as InputEventKey).keycode
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		_accept()
		get_viewport().set_input_as_handled()
