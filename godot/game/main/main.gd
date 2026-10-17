extends Node
## 조립 루트 — 심 스냅샷을 만들어 뷰에 밀어 넣는 유일한 곳.
##
## 이 파일은 2D/3D 를 모른다. FonsViewFactory 가 ProjectSettings(fons/view_mode)를 읽어 뷰를 정한다(R4).
## 3D 착수 시 이 파일을 고치지 않는다 — view_3d.tscn 을 추가하고 설정만 바꾼다.

const TICK_SECONDS := 1.0

var _view: FonsView = null
var _tick := 0
var _elapsed := 0.0


func _ready() -> void:
	_view = FonsViewFactory.create()
	if _view == null:
		push_error(
			"뷰를 만들지 못했다 (mode=%s, available=%s)"
			% [FonsViewFactory.configured_mode(), FonsViewFactory.available_modes()]
		)
		return
	_view.intent.connect(_on_intent)
	add_child(_view)
	_view.mount(_snapshot())
	_view.apply(_snapshot())


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < TICK_SECONDS:
		return
	_elapsed = 0.0
	_tick += 1
	if _view != null:
		_view.apply(_snapshot())


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	# 입력은 아직 없다. 뷰가 보내는 의도만 받아 두고, 규칙은 심(Phase 2)이 붙으면 연결한다.
	print("[intent] %s %s" % [kind, payload])


## 데모 스냅샷 — 심 스키마(§3)의 최소 예시. Phase 2 에서 FonsGameState 로 교체한다.
func _snapshot() -> Dictionary:
	var t := float(_tick)
	return {
		"tick": _tick,
		"entities": [
			{
				"id": &"hero",
				"asset": "hero:knight",
				"pos": Vector3(sin(t) * 2.0, 0.0, 0.0),
				"size": Vector2(0.8, 0.8),
				"kind": "hero",
			},
			{
				"id": &"wolf",
				"asset": "monster:wolf_t1",
				"pos": Vector3(2.0, 0.0, 1.5),
				"size": Vector2(1.0, 1.0),
				"kind": "monster",
			},
			{
				"id": &"gate",
				"asset": "prop:gate",
				"pos": Vector3(-3.0, 0.0, -2.0),
				"size": Vector2(1.2, 0.6),
				"kind": "prop",
			},
		],
	}
