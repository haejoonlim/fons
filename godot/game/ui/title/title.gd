extends Control
## 타이틀 — 이어하기는 세이브가 있을 때만 열린다.
##
## 세이브 판정은 `SaveManager.load_payload()` 하나로 한다. 없음·손상·더 새 판이면 이어하기를 닫는다.
## 손상 파일은 여기서 한 번 격리된다 — 메인 씬이 반쯤 읽은 상태로 시작하지 않게.
##
## 새로 시작은 세이브를 지운다 — 지우기 전에 확인을 받는다 (UI 문구 규칙 §2 확인창).
## `.bak` 까지 같이 지우는 이유: 본파일만 지우면 `load_payload` 가 백업에서 옛 런을 되살린다.

@onready var _status: Label = $Center/VBox/Status
@onready var _continue: Button = $Center/VBox/Continue
@onready var _start: Button = $Center/VBox/Start
@onready var _confirm: ConfirmationDialog = $Confirm

var _has_save := false


func _ready() -> void:
	_continue.pressed.connect(_on_continue)
	_start.pressed.connect(_on_start)
	_confirm.confirmed.connect(_on_confirm_new)
	var probe := SaveManager.load_payload()
	_has_save = bool(probe["ok"])
	if _has_save:
		var payload: Dictionary = probe["data"]
		var run: Dictionary = payload.get("run", {})
		var estate: Dictionary = payload.get("estate", {})
		_status.text = "저장된 런 — %d층 · 섬 %d일" % [
			int(run.get("floor", 1)), int(estate.get("last_settled_day", 1))
		]
		_continue.disabled = false
	elif String(probe["status"]) == "newer":
		_status.text = "더 새 판의 세이브다 — 이 빌드로는 열 수 없다"
		_continue.disabled = true
	else:
		_status.text = "저장된 런이 없다"
		_continue.disabled = true


func _on_continue() -> void:
	GameState.start_mode = "continue"
	_open_game()


func _on_start() -> void:
	if _has_save:
		_confirm.popup_centered()
		return
	_begin_new()


func _on_confirm_new() -> void:
	_wipe_save()
	_begin_new()


func _wipe_save() -> void:
	## 본파일·임시·백업을 함께 지운다. 백업이 남으면 옛 런이 되살아난다.
	SaveManager.erase()
	_has_save = false


func _begin_new() -> void:
	# 새 런은 지갑도 새로 시작한다 — 같은 프로세스에서 이어하기를 거친 값이 남으면 안 된다.
	GameState.gold = 0
	GameState.pull_count = 0
	GameState.start_mode = "new"
	_open_game()


func _open_game() -> void:
	get_tree().change_scene_to_file("res://game/main/main.tscn")
