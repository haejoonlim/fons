extends Control
## 칙령 선택 — 3종을 보여 주고 하나를 고른다 (04 §3.7).
##
## 규칙은 여기 없다. 무엇이 가능한지(10층 해금·파업 중 식량)는 `FonsEstate` 가 정하고,
## 이 화면은 **고른 id** 만 돌려준다. 거절 사유도 규칙이 만든 문장을 그대로 받아 보여 준다.
## 켜진 칙령은 잠근다 — 다시 누르면 민심 델타가 한 번 더 붙는다.

signal chosen(id: String)
signal closed

@onready var _rows: VBoxContainer = $Center/Panel/VBox/Rows
@onready var _status: Label = $Center/Panel/VBox/Status
@onready var _close_button: Button = $Center/Panel/VBox/Close

var _buttons: Array = []


func _ready() -> void:
	_close_button.pressed.connect(_close)
	hide()


func open(options: Array, current: String, note: String) -> void:
	## 목록은 `FonsEstate.decrees()` 가 준 사본이다 — 여기서 수치를 만들지 않는다.
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_buttons = []
	for entry in options:
		var id := String(entry.get("id", ""))
		var button := Button.new()
		button.text = "%s — %s" % [String(entry.get("name_ko", id)), _summary(entry)]
		if id == current:
			button.text += " · 켜짐"
			button.disabled = true
		button.pressed.connect(_pick.bind(id))
		_rows.add_child(button)
		_buttons.append(button)
	set_note(note)
	show()


func set_note(text: String) -> void:
	## 규칙이 돌려준 이유를 그대로 쓴다 (UI 문구 규칙 §6 — 조건을 그대로).
	_status.text = text


func _summary(entry: Dictionary) -> String:
	## 데이터에 있는 효과 키만 문장으로 만든다. 없는 효과를 여기서 지어내지 않는다.
	var parts: Array = []
	if entry.has("morale_delta"):
		parts.append("민심 %+d" % int(entry["morale_delta"]))
	if entry.has("tax_mul"):
		parts.append("세금 %+d%%" % _percent(entry["tax_mul"]))
	if entry.has("natural_growth_mul"):
		parts.append("자연증가 %+d%%" % _percent(entry["natural_growth_mul"]))
	if entry.has("harvest_mul"):
		parts.append("채집 %+d%%" % _percent(entry["harvest_mul"]))
	return " · ".join(parts)


func _percent(mul: Variant) -> int:
	return roundi((float(mul) - 1.0) * 100.0)


func _pick(id: String) -> void:
	chosen.emit(id)


func _close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	## 화면이 떠 있는 동안 세계는 멈춰 있다 (`get_tree().paused`). 멈춘 트리에서도 입력을 받으려고
	## 이 씬은 `process_mode = ALWAYS` 다 — 그래서 C·Esc·숫자키를 여기서 직접 처리한다.
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code := (event as InputEventKey).keycode
	if code == KEY_ESCAPE or code == KEY_C:
		_close()
		get_viewport().set_input_as_handled()
		return
	if code < KEY_1 or code > KEY_9:
		return
	var index := int(code - KEY_1)
	if index >= _buttons.size() or (_buttons[index] as Button).disabled:
		return
	(_buttons[index] as Button).pressed.emit()
	get_viewport().set_input_as_handled()
