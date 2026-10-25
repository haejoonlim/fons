extends Node
## 조립 루트 — 심 스냅샷을 뷰에 밀어 넣는 유일한 곳.
##
## 심은 `FonsFieldState` 다 — 1층 탐험 필드에서 시작해 걷고, 접촉한 조우와 싸우고,
## 미션을 끝내면 다음 층으로 간다. 전투 판 자체는 `FonsFloorRun`/`FonsBattle` 그대로다.
##
## 이 파일은 2D/3D 를 모른다. `FonsViewFactory` 가 ProjectSettings(fons/view_mode)를 읽어 뷰를 정한다(R4).
## 입력은 뷰가 `intent` 로 되돌리고, 여기서 심에 반영한 뒤 스냅샷을 다시 민다.
##
## 이동은 **매 프레임** 밀어야 해서 `_move_dir` 를 들고 `_process` 에서 걷는다.
## 뷰는 키를 눌렀다 뗄 때마다 `move` 를 보내고, 이 파일은 규칙을 모른 채 방향만 넘긴다.

const SEED := 20261020

var _field: FonsFieldState = null
var _estate: FonsEstate = null
var _view: FonsView = null
var _move_dir := Vector2.ZERO

@onready var _floor_label: Label = $Hud/FloorLabel
@onready var _hint_label: Label = get_node_or_null("Hud/HintLabel")
@onready var _log_label: Label = $Hud/LogLabel


func _ready() -> void:
	var data := _data_bundle()
	_estate = FonsEstate.new()
	_estate.start(data["estate"], FonsFieldState.START_FLOOR)
	_field = FonsFieldState.new()
	if not _restore_if_asked(data):
		_field.start(data["races"], data["monsters"], data["biomes"], SEED,
			FonsFieldState.START_FLOOR, data["job_tree"], data["equipment"],
			data["job_coef"], data["ai"], data["basics"])

	_view = FonsViewFactory.create()
	if _view == null:
		push_error(
			"뷰를 만들지 못했다 (mode=%s, available=%s)"
			% [FonsViewFactory.configured_mode(), FonsViewFactory.available_modes()]
		)
		return
	_view.intent.connect(_on_intent)
	add_child(_view)
	_view.mount(_field.snapshot())
	_push()


func _data_bundle() -> Dictionary:
	## DataLoader 를 한 번만 읽어 아래로 넘긴다 — 시험과 게임이 같은 묶음을 쓴다.
	return {
		"races": DataLoader.load_json("races.json"),
		"monsters": DataLoader.get_monsters(),
		"biomes": DataLoader.get_biomes(),
		"job_tree": DataLoader.load_json("job_tree.json"),
		"equipment": DataLoader.load_json("equipment.json"),
		"job_coef": DataLoader.load_json("job_coef.json"),
		"ai": {
			"personalities": DataLoader.load_json("personalities.json"),
			"profiles": DataLoader.load_json("job_ai_profiles.json"),
			"catalog": DataLoader.load_json("skills_catalog.json"),
			"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
		},
		"basics": DataLoader.load_json("basic_attacks.json"),
		"estate": DataLoader.load_json("estate.json"),
	}


func _restore_if_asked(data: Dictionary) -> bool:
	## 타이틀에서 "이어하기" 를 눌렀을 때만. 없는 파일·손상·더 새 판이면 새 게임으로 떨어진다.
	if String(GameState.start_mode) != "continue":
		return false
	var loaded := SaveManager.load_payload()
	if not bool(loaded["ok"]):
		return false
	var payload: Dictionary = loaded["data"]
	var run: Dictionary = payload.get("run", {})
	_field.configure(data["races"], data["monsters"], data["biomes"],
		int(String(run.get("seed", str(SEED)))), FonsFieldState.START_FLOOR,
		data["job_tree"], data["equipment"], data["job_coef"], data["ai"], data["basics"])
	if not _field.restore(run):
		return false
	_estate.from_save(payload.get("estate", {}))
	GameState.from_save(payload.get("wallet", {}))
	return true


func _save() -> void:
	## 저장은 층을 깼을 때·창을 닫을 때만. 전투 도중은 없다.
	if _field == null or _estate == null:
		return
	SaveManager.save_payload(FonsSave.to_dict(_field.to_save(), _estate.to_save(), GameState.to_save()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _process(delta: float) -> void:
	## 뷰가 방향을 보내는 동안만 걷는다. 벽·필드 밖은 `FonsExplore.walk` 가 자른다.
	if _field == null or _move_dir == Vector2.ZERO:
		return
	_field.walk(_move_dir, delta)
	_push()


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	match String(kind):
		"move":
			_move_dir = payload.get("dir", Vector2.ZERO)
			return
		"interact":
			if _field.contact_index() >= 0:
				_field.engage()
			elif _field.mission_done():
				if _field.next_floor():
					_save()
		"retreat":
			_move_dir = Vector2.ZERO
			_field.retreat()
		"next_floor":
			# 예전 화면·테스트가 쓰던 의도 — 미션을 끝냈을 때만 실제로 넘어간다.
			_field.next_floor()
		"restart":
			_move_dir = Vector2.ZERO
			_field.restart()
		_:
			return
	_push()


func _push() -> void:
	if _view != null:
		_view.apply(_field.snapshot())
	_update_hud()


func _update_hud() -> void:
	if _floor_label != null:
		_floor_label.text = "%d층 · 탐험 %d/%d · 생존 %d/%d" % [
			_field.floor, _field.explore.cleared, _field.explore.required,
			_field.party_alive(), _field.heroes.size()
		]
	if _hint_label != null:
		_hint_label.text = _field.hint()
	if _log_label != null:
		_log_label.text = "\n".join(_field.log_lines)
