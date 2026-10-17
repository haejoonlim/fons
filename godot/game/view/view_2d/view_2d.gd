class_name FonsView2D
extends FonsView
## 2D 뷰 — 심 스냅샷을 받아 엔티티를 화면에 그린다.
##
## 심은 Vector3 로 말하고(R2), 이 뷰만 FonsProjection 으로 축을 접는다.
## 에셋은 문자열 키(R3)이고, 지금은 키→색으로만 해석한다. 스프라이트는 키 매핑 테이블만 갈아 끼우면 된다.
##
## 그리기는 자식 Canvas(Node2D)가 맡는다 — FonsView 계약이 Node 를 베이스로 하기 때문에
## 이 클래스 자체는 CanvasItem 이 아니다(_draw 가 호출되지 않는다).

@export var pixels_per_unit: float = 48.0
@export var origin: Vector2 = Vector2(640, 360)
## 0 = XZ(탑다운, 기본) · 1 = XY(횡스크롤) — FonsProjection.Axes 와 같은 값
@export_enum("XZ", "XY") var axes: int = 0

## 키 접두어별 색. 실제 스프라이트가 들어오면 이 표를 아틀라스 매핑으로 교체한다.
const KIND_COLORS := {
	"hero": Color(0.35, 0.75, 1.0),
	"monster": Color(1.0, 0.35, 0.35),
	"prop": Color(0.55, 0.55, 0.55),
}
const DEFAULT_COLOR := Color(0.85, 0.85, 0.85)


class Canvas extends Node2D:
	var view_ref: Node = null

	func _draw() -> void:
		if view_ref != null and view_ref.has_method("draw_entities"):
			view_ref.draw_entities(self)


var _entities: Dictionary = {}
var _canvas: Canvas = null


func _ready() -> void:
	_ensure_canvas()


func mount(snapshot: Dictionary) -> void:
	_entities.clear()
	apply(snapshot)
	_mounted = true


func apply(snapshot: Dictionary) -> void:
	# 스냅샷은 매 틱 전체 집합이다 — 증분이 아니다. 사라진 id 는 여기서 자연히 빠진다.
	_entities.clear()
	for entity in snapshot.get("entities", []):
		_entities[entity["id"]] = entity
	_redraw()


func unmount() -> void:
	_entities.clear()
	_mounted = false
	_redraw()


func entity_count() -> int:
	return _entities.size()


func has_entity(id: StringName) -> bool:
	return _entities.has(id)


func screen_position(world_pos: Vector3) -> Vector2:
	return origin + FonsProjection.to_screen(world_pos, axes) * pixels_per_unit


func draw_entities(canvas: Node2D) -> void:
	for id in _entities:
		var entity: Dictionary = _entities[id]
		var center := screen_position(entity["pos"])
		var size: Vector2 = entity.get("size", Vector2.ONE) * pixels_per_unit
		var color: Color = KIND_COLORS.get(entity.get("kind", ""), DEFAULT_COLOR)
		canvas.draw_rect(Rect2(center - size * 0.5, size), color)


func _ensure_canvas() -> Canvas:
	if _canvas != null:
		return _canvas
	if not is_inside_tree():
		return null
	_canvas = Canvas.new()
	_canvas.view_ref = self
	_canvas.name = "Canvas"
	add_child(_canvas)
	return _canvas


func _redraw() -> void:
	var canvas := _ensure_canvas()
	if canvas != null:
		canvas.queue_redraw()
