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
var _view: FonsView = null
var _move_dir := Vector2.ZERO

@onready var _floor_label: Label = $Hud/FloorLabel
@onready var _hint_label: Label = get_node_or_null("Hud/HintLabel")
@onready var _log_label: Label = $Hud/LogLabel


func _ready() -> void:
	_field = FonsFieldState.new()
	# 영웅 AI 묶음 — 성격 3키워드·직업 프로필·스킬 카탈로그. 없으면 브레인 없이 예전처럼 돈다.
	var ai := {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}
	_field.start(DataLoader.load_json("races.json"), DataLoader.get_monsters(),
		DataLoader.get_biomes(), SEED, FonsFieldState.START_FLOOR,
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		DataLoader.load_json("job_coef.json"), ai)

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
				_field.next_floor()
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
