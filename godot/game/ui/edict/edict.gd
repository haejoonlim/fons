extends Control
## 칙령 선택 — 3종을 보여 주고, 30층 이상이면 어느 칸에 넣을지도 고른다 (04 §3.7 · ADR 0011).
##
## 규칙은 여기 없다. 무엇이 가능한지(10층 해금·칸 수·쿨다운·파업 중 식량)는 `FonsEstate` 가 정하고,
## 이 화면은 **고른 id 와 칸** 만 돌려준다. 거절 사유도 규칙이 만든 문장을 그대로 받아 보여 준다.
## 켜진 칙령은 잠근다 — 다시 누르면 민심 델타가 한 번 더 붙는다.

signal chosen(id: String, slot: int)
signal closed

@onready var _rows: VBoxContainer = $Center/Panel/VBox/Rows
@onready var _slots: HBoxContainer = $Center/Panel/VBox/Slots
@onready var _status: Label = $Center/Panel/VBox/Status
@onready var _hint: Label = $Center/Panel/VBox/Hint
@onready var _close_button: Button = $Center/Panel/VBox/Close

var _buttons: Array = []
var _slot_buttons: Array = []
var _active_ids: Array = []
var _names: Dictionary = {}
var _slot_count := 1
## 칸을 기다리는 칙령 id — 비어 있으면 목록 모드다.
var _pending_id := ""
var _base_note := ""


func _ready() -> void:
	_close_button.pressed.connect(_close)
	_slots.visible = false
	hide()


func open(options: Array, active_ids: Array, note: String, slot_count: int = 1,
		locked: bool = false) -> void:
	## 목록은 `FonsEstate.decrees()` 가 준 사본이다 — 여기서 수치를 만들지 않는다.
	## `active_ids` 는 칸 순서 그대로다 — 인덱스가 칸 번호이고 빈 칸은 `""` 다 (ADR 0011).
	## `locked` 는 교체 쿨다운 — 비활성 줄을 잠그고 상태 줄의 이유만 남긴다 (ADR 0011).
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_buttons = []
	_names = {}
	_active_ids = active_ids.duplicate()
	_slot_count = clampi(slot_count, 1, 2)
	_base_note = note
	_reset_slot_mode()
	for entry in options:
		var id := String(entry.get("id", ""))
		_names[id] = String(entry.get("name_ko", id))
		var button := Button.new()
		button.text = "%s — %s" % [_names[id], _summary(entry)]
		var slot_index := _active_ids.find(id)
		if slot_index >= 0:
			button.text += " · %d번 칸" % (slot_index + 1)
			button.disabled = true
		elif locked:
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
	if entry.has("overflow_gold_per_pop"):
		parts.append("상한 초과 +%dG/명" % int(entry["overflow_gold_per_pop"]))
	if entry.has("harvest_mul"):
		parts.append("채집 %+d%%" % _percent(entry["harvest_mul"]))
	return " · ".join(parts)


func _percent(mul: Variant) -> int:
	return roundi((float(mul) - 1.0) * 100.0)


func _pick(id: String) -> void:
	## 1칸 시대에는 바로 넘긴다. 2칸 시대에는 빈 칸이 있어도 플레이어가 칸을 고른다 (ADR 0011).
	if _slot_count <= 1:
		chosen.emit(id, 0)
		return
	_pending_id = id
	_build_slot_buttons()
	_slots.visible = true
	_hint.text = "1·2 — 칸 고르기 · Esc — 취소"
	_status.text = "어느 칸에 넣을까?"


func _build_slot_buttons() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	_slot_buttons = []
	for i in _slot_count:
		var held := String(_active_ids[i]) if i < _active_ids.size() else ""
		var what := String(_names.get(held, held)) if not held.is_empty() else "비어 있음"
		var button := Button.new()
		button.text = "%d번 — %s" % [i + 1, what]
		button.pressed.connect(_choose_slot.bind(i))
		_slots.add_child(button)
		_slot_buttons.append(button)
	var cancel := Button.new()
	cancel.text = "취소"
	cancel.pressed.connect(_cancel_slots)
	_slots.add_child(cancel)
	_slot_buttons.append(cancel)


func _choose_slot(index: int) -> void:
	var id := _pending_id
	_reset_slot_mode()
	chosen.emit(id, index)


func _cancel_slots() -> void:
	## 칸 선택만 취소한다 — 목록으로 돌아가고 화면은 열린 채다.
	_reset_slot_mode()
	set_note(_base_note)


func _reset_slot_mode() -> void:
	_pending_id = ""
	_slots.visible = false
	_hint.text = "1~3 — 고르기 · C — 닫기"


func _close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	## 화면이 떠 있는 동안 세계는 멈춰 있다 (`get_tree().paused`). 멈춘 트리에서도 입력을 받으려고
	## 이 씬은 `process_mode = ALWAYS` 다 — 그래서 C·Esc·숫자키를 여기서 직접 처리한다.
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code := (event as InputEventKey).keycode
	if not _pending_id.is_empty():
		# 칸 선택 중 — 숫자는 칸, Esc·C 는 칸 선택 취소. 화면을 닫지 않는다.
		if code == KEY_ESCAPE or code == KEY_C:
			_cancel_slots()
			get_viewport().set_input_as_handled()
			return
		if code >= KEY_1 and code <= KEY_9:
			var slot := int(code - KEY_1)
			if slot < _slot_count:
				_choose_slot(slot)
				get_viewport().set_input_as_handled()
		return
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
