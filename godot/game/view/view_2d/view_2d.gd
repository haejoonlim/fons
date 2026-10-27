class_name FonsView2D
extends FonsView
## 2D 뷰 — 심 스냅샷을 받아 엔티티를 화면에 그린다.
##
## 심은 Vector3 로 말하고(R2), 이 뷰만 `FonsProjection` 으로 축을 접는다.
## 에셋은 문자열 키(R3)이고, 지금은 키→색으로만 해석한다. 스프라이트는 키 매핑 테이블만 갈아 끼우면 된다.
##
## 화면이 두 종류다.
##   전투 스냅샷 — `field` 가 없다. 예전처럼 고정 배율(`pixels_per_unit`)로 엔티티를 그린다.
##   탐험 스냅샷 — `mode = "field"` · `field` 크기가 있다. 필드가 화면 안에 들어오도록
##                 배율·원점을 **매번 계산**하고, 배경 격자·조우 지점·아바타를 그린다.
##                 (40×28 필드를 48px/u 로 그리면 1920×1344 라 화면 밖으로 나간다)
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
	"site": Color(0.95, 0.72, 0.28),
	"avatar": Color(0.40, 0.90, 0.55),
}
const DEFAULT_COLOR := Color(0.85, 0.85, 0.85)

## 탐험 필드 배경 — 전투 화면과 구분되는 어두운 판.
const FIELD_BG := Color(0.06, 0.07, 0.09, 1.0)
const FIELD_AREA := Color(0.11, 0.13, 0.16, 1.0)
const FIELD_GRID := Color(0.20, 0.23, 0.27, 0.6)
const FIELD_BORDER := Color(0.34, 0.40, 0.47, 1.0)
const SITE_CLEARED := Color(0.32, 0.34, 0.36, 1.0)
## 2D 명도 배율 — 배경은 하늘을 UI 톤으로 내리고(0.35), 판은 지면을 격자가 보일 만큼 올린다(1.6).
const BACKGROUND_GAIN := 0.35
const GROUND_GAIN := 1.6
const SITE_CONTACT := Color(1.0, 0.95, 0.55)
const AVATAR_RING := Color(0.85, 1.0, 0.90, 0.9)
## 동료가 따라다니는 범위 — 심이 준 반경을 그린다. 숫자는 심이 정한다.
const PARTY_RING := Color(0.45, 0.75, 1.0, 0.35)

## 오른쪽 파티 칸은 `FonsPartyPanel` 이 그린다 — 2D·3D 가 같은 그림을 쓴다.
## HP 바도 마찬가지다 — 모양·비율은 `FonsHpBar`, 놓는 자리만 뷰가 정한다.


class Canvas extends Node2D:
	var view_ref: Node = null

	func _draw() -> void:
		if view_ref != null and view_ref.has_method("draw_entities"):
			view_ref.draw_entities(self)


var _entities: Dictionary = {}
var _canvas: Canvas = null
## 심이 준 바이옴 파생색. 배경 = 하늘, 판 = 지면 — 3D 와 같은 바이옴을 같은 색으로 부른다.
var _palette: Dictionary = {}
var _field := Vector2.ZERO
var _is_field := false
var _contact := -1
var _radius := 0.0
var _avatar_pos := Vector3.ZERO
## 탑·소환진 — 3D 와 같은 스냅샷 표를 같은 자리에 그린다.
var _tower: Dictionary = {}
## 이 창이 보는 월드 중심 — 아바타다. 2D 는 무한맵을 창 하나로 보여 준다.
var _center := Vector2.ZERO
var _party: Array = []
var _last_dir := Vector2.ZERO


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
	_field = snapshot.get("field", Vector2.ZERO)
	var palette: Variant = snapshot.get("palette", {})
	_palette = palette if palette is Dictionary else {}
	_is_field = String(snapshot.get("mode", "")) == "field" and _field.x > 0.0 and _field.y > 0.0
	_contact = int(snapshot.get("contact", -1))
	_radius = float(snapshot.get("radius", 0.0))
	_avatar_pos = snapshot.get("avatar", Vector3.ZERO)
	_center = Vector2(_avatar_pos.x, _avatar_pos.z)
	var tower: Variant = snapshot.get("tower", {})
	_tower = tower if tower is Dictionary else {}
	_party = snapshot.get("party", [])
	_redraw()


func unmount() -> void:
	_entities.clear()
	_palette = {}
	_field = Vector2.ZERO
	_is_field = false
	_contact = -1
	_tower = {}
	_party = []
	_mounted = false
	_redraw()


func entity_count() -> int:
	return _entities.size()


func party_count() -> int:
	return _party.size()


func has_entity(id: StringName) -> bool:
	return _entities.has(id)


func screen_position(world_pos: Vector3) -> Vector2:
	if _is_field:
		# 탐험 필드는 **탑다운 지도**다 — x 오른쪽, z 아래. `FonsProjection` 은 전투용 축 접기라
		# z 부호를 뒤집어(y 감소) 필드가 위로 솟는다. 여기서는 필드 좌표를 그대로 쓴다.
		# 창은 아바타를 중심으로 월드를 미리 빌린다 — 걸어도 지도가 따라오고 탑만 움직인다.
		var metrics := field_metrics()
		var local := Vector2(world_pos.x, world_pos.z) - _center + _field * 0.5
		return Vector2(metrics["origin"]) + local * float(metrics["scale"])
	return origin + FonsProjection.to_screen(world_pos, axes) * pixels_per_unit


func field_metrics() -> Dictionary:
	## 필드를 화면 안에 넣는 배율·원점. 최소 배율 4px/unit.
	## 위 여백은 HUD 두 줄(층·힌트), 아래 여백은 전투 로그 자리를 비운다 —
	## 입구(0,0)의 아바타와 격자가 글자를 덮지 않게.
	# 40×28 필드를 1280×720 에서는 약 22px/unit 로 그린다.
	# 오른쪽은 파티 칸 자리다 — 필드가 그 아래로 들어가면 글자가 겹친다.
	var viewport := _viewport_size()
	var left := 32.0
	var right := FonsPartyPanel.WIDTH + FonsPartyPanel.MARGIN * 2.0
	var top := 88.0
	var bottom := 200.0
	var sx := (viewport.x - left - right) / maxf(1.0, _field.x)
	var sy := (viewport.y - top - bottom) / maxf(1.0, _field.y)
	var scale_value := maxf(4.0, minf(sx, sy))
	var inner := Vector2(viewport.x - left - right, viewport.y - top - bottom)
	return {
		"scale": scale_value,
		"origin": Vector2(left, top) + (inner - _field * scale_value) * 0.5,
	}


func draw_entities(canvas: Node2D) -> void:
	if _is_field:
		_draw_field(canvas)
	for id in _entities:
		var entity: Dictionary = _entities[id]
		var kind := String(entity.get("kind", ""))
		if kind == "site":
			_draw_site(canvas, entity)
			continue
		if kind == "avatar":
			_draw_avatar(canvas, entity)
			continue
		var center := screen_position(entity["pos"])
		var size := entity_screen_size(entity)
		var color: Color = KIND_COLORS.get(kind, DEFAULT_COLOR)
		if not bool(entity.get("alive", true)):
			color = color.darkened(0.6)
		canvas.draw_rect(Rect2(center - size * 0.5, size), color)
		_draw_hp_bar(canvas, center, size, entity)
	if _is_field:
		_draw_party(canvas)


func entity_screen_size(entity: Dictionary) -> Vector2:
	## 엔티티 사각형의 화면 크기. 탐험 필드는 필드 배율을 써야 한다 —
	## 40×28 을 화면에 맞추면 48px/unit 보다 작아서, 전투 배율로 그리면 영웅이 세 배로 커진다.
	var unit_scale := float(field_metrics()["scale"]) if _is_field else pixels_per_unit
	return entity.get("size", Vector2.ONE) * unit_scale


func _draw_field(canvas: Node2D) -> void:
	var metrics := field_metrics()
	var scale_value := float(metrics["scale"])
	var origin_at: Vector2 = metrics["origin"]
	var area := Rect2(origin_at, _field * scale_value)
	canvas.draw_rect(Rect2(Vector2.ZERO, _viewport_size()), field_background())
	canvas.draw_rect(area, field_area_color())
	# 5유닛 격자 — **월드 좌표**에 고정한다. 창에 붙이면 걸을 때 격자가 같이 흘러 바닥이 미끄러진다.
	var step := 5.0
	var low := _center - _field * 0.5
	var x := ceilf(low.x / step) * step
	while x <= low.x + _field.x + 0.01:
		var px := origin_at.x + (x - low.x) * scale_value
		canvas.draw_line(Vector2(px, area.position.y), Vector2(px, area.end.y), FIELD_GRID, 1.0)
		x += step
	var z := ceilf(low.y / step) * step
	while z <= low.y + _field.y + 0.01:
		var pz := origin_at.y + (z - low.y) * scale_value
		canvas.draw_line(Vector2(area.position.x, pz), Vector2(area.end.x, pz), FIELD_GRID, 1.0)
		z += step
	canvas.draw_rect(area, FIELD_BORDER, false, 2.0)
	_draw_tower(canvas, scale_value)
	if _radius > 0.0:
		canvas.draw_circle(screen_position(_avatar_pos), _radius * scale_value, PARTY_RING, false, 1.5)


func _draw_tower(canvas: Node2D, scale_value: float) -> void:
	## 중심 랜드마크 — 소환진 고리 둘과 탑 몸통. 3D 와 같은 자리·같은 반경이다.
	if _tower.is_empty():
		return
	var at: Variant = _tower.get("pos", null)
	if not (at is Vector3):
		return
	var radius := float(_tower.get("radius", 0.0))
	var body := float(_tower.get("body", 0.0))
	if radius <= 0.0:
		return
	var center: Vector2 = screen_position(at)
	var glow: Variant = _palette.get("light", null)
	var ring: Color = glow if glow is Color else SITE_CLEARED
	canvas.draw_circle(center, radius * scale_value, ring, false, 2.0)
	canvas.draw_circle(center, radius * 0.55 * scale_value, ring, false, 1.5)
	if body > 0.0:
		canvas.draw_circle(center, maxf(3.0, body * scale_value), Color(0.72, 0.70, 0.66))


func tower_radius() -> float:
	## 테스트·디버그용 — 지금 그리는 소환진 반경 (없으면 0).
	return float(_tower.get("radius", 0.0))


func field_background() -> Color:
	## 바이옴을 모르는 스냅샷(전투·헤드리스)은 예전 색 그대로 — 화면이 바뀌지 않는다.
	## 하늘색을 그대로 칠하지는 않는다: 2D 는 지도·HUD 화면이라 밝은 하늘을 깔면 흰 글씨가 안 읽힌다.
	## 색상각은 팔레트, 명도만 UI 범위로 내린 파생값이다 (3D 헤이즈와 같은 규칙).
	var sky: Variant = _palette.get("sky", null)
	return _shade(sky, BACKGROUND_GAIN) if sky is Color else FIELD_BG


func field_area_color() -> Color:
	## 3D 지면과 같은 파생색. 지면색은 3D 조명까지 곱한 값보다 어두워서, 그대로 깔면 격자가 안 보인다.
	var ground: Variant = _palette.get("ground", null)
	return _shade(ground, GROUND_GAIN) if ground is Color else FIELD_AREA


func _shade(color: Color, value_gain: float) -> Color:
	## 색상각·채도는 팔레트 그대로, 명도만 화면 톤으로 옴긴다.
	return Color.from_hsv(color.h, color.s, clampf(color.v * value_gain, 0.0, 1.0))


func _draw_site(canvas: Node2D, entity: Dictionary) -> void:
	var center := screen_position(entity["pos"])
	var radius := maxf(7.0, float(entity.get("size", Vector2.ONE).x) * float(field_metrics()["scale"]) * 0.5)
	var cleared := bool(entity.get("cleared", false))
	canvas.draw_circle(center, radius, SITE_CLEARED if cleared else KIND_COLORS["site"])
	if cleared:
		canvas.draw_line(center + Vector2(-radius * 0.5, 0), center + Vector2(radius * 0.5, 0),
			Color(0.75, 0.78, 0.80), 2.0)
		return
	canvas.draw_circle(center, radius, FIELD_BORDER, false, 2.0)
	if bool(entity.get("contact", false)):
		canvas.draw_circle(center, radius + 7.0, SITE_CONTACT, false, 3.0)


func _draw_avatar(canvas: Node2D, entity: Dictionary) -> void:
	var center := screen_position(entity["pos"])
	var scale_value := float(field_metrics()["scale"])
	var radius := maxf(8.0, float(entity.get("size", Vector2.ONE).x) * scale_value * 0.5)
	canvas.draw_circle(center, radius, KIND_COLORS["avatar"])
	canvas.draw_circle(center, radius + 4.0, AVATAR_RING, false, 2.0)


func _draw_party(canvas: Node2D) -> void:
	## 오른쪽 다섯 줄. 심이 준 `party` 만 그린다 — 계산은 심이 진다.
	FonsPartyPanel.draw(canvas, _party, _viewport_size())


func _viewport_size() -> Vector2:
	## `FonsView` 는 Node 라 `get_viewport_rect()`(CanvasItem)를 못 쓴다.
	var vp := get_viewport()
	if vp == null:
		return Vector2(1280.0, 720.0)
	return vp.get_visible_rect().size


func _draw_hp_bar(canvas: Node2D, center: Vector2, size: Vector2, entity: Dictionary) -> void:
	## 심이 `hp`·`max_hp` 를 실어 보낸 엔티티만 그린다 (판단은 `FonsHpBar`).
	var bottom := center + Vector2(0.0, size.y * 0.5)
	FonsHpBar.draw(canvas, FonsHpBar.top_left_below(bottom, size.x), size.x, entity)


func _process(_delta: float) -> void:
	## 탐험 화면에서만 키를 읽는다. 방향이 **바뀔 때만** 의도를 보낸다 — 매 프레임 보내면
	## 심이 같은 입력을 계속 받아 로그·스냅샷을 불필요하게 다시 만든다.
	if not _is_field:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	if dir == _last_dir:
		return
	_last_dir = dir
	intent.emit(&"move", {"dir": dir})


func _unhandled_input(event: InputEvent) -> void:
	## 입력은 뷰가 받아 `intent` 로만 되돌린다 — 뷰가 규칙을 직접 고치지 않는다.
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if _is_field:
		match key:
			KEY_SPACE, KEY_ENTER, KEY_F:
				# 3D 는 Space 가 점프라 F 가 교전 키다 — 폴백도 같이 알아둔다.
				intent.emit(&"interact", {})
			KEY_R:
				intent.emit(&"retreat", {})
			KEY_C:
				intent.emit(&"edict", {})
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				intent.emit(&"switch_hero", {"index": int(key) - int(KEY_1)})
	else:
		match key:
			KEY_SPACE, KEY_ENTER:
				intent.emit(&"next_floor", {})
			KEY_R:
				intent.emit(&"restart", {})


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
