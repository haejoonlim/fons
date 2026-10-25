class_name FonsView3D
extends FonsView
## 3D 뷰 골격 — 같은 심 스냅샷을 3D 월드에 놓는다.
##
## 2D 뷰와 계약이 같다: `mount`/`apply`/`unmount` 로 스냅샷을 받고, 입력은 `intent` 로만 되돌린다.
## 심은 `Vector3`(x, y=높이, z) 로 말하므로 여기서는 **축을 접지 않고 그대로** 쓴다.
## 2D 가 `FonsProjection` 으로 접는 것과 달리 3D 는 y 를 높이로 쓴다 — 필드 스냅샷의 y 는 0 이다.
##
## 에셋은 문자열 키(R3)다 — `hero:knight` 같은 키에 `Mesh` 또는 `PackedScene` 을 걸면 그것을 쓰고,
## 안 걸린 키는 종류별 기본 도형으로 폴백한다. `.glb` 는 `PackedScene` 으로 임포트되므로 씬도 받는다.
## 그래서 자산이 들어오면 `register_asset` 만 호출하면 되고, 심·조립 루트는 안 건드린다.
##
## HP 바는 화면 픽셀에 그린다(`FonsHpBar`) — 머리 위 월드 지점을 카메라로 투영해서, 2D 와 같은 두께·색이 된다.
##
## 화면 구성
##   · 지면(PlaneMesh) + 방향광 + 환경광 — 필드 크기만큼 깔리고, 색은 바이옴 파생값(`palette`)이다
##   · 폴백 도형 — 조우 = 원기둥, 조종 영웅 = 캡슐, 동료 = 상자, 몬스터 = 원뿔
##   · 오른쪽 파티 칸은 `FonsPartyPanel`, HP 바는 `FonsHpBar` — 2D 와 같은 그림

const FIELD_BG := Color(0.04, 0.05, 0.07, 1.0)
const GROUND := Color(0.10, 0.12, 0.15, 1.0)
const HERO_COLOR := Color(0.35, 0.75, 1.0, 1.0)
const AVATAR_COLOR := Color(0.40, 0.90, 0.55, 1.0)
const SITE_COLOR := Color(0.95, 0.72, 0.28, 1.0)
## 2D 의 `KIND_COLORS["monster"]` 와 같은 색 — 두 뷰가 같은 적을 같은 색으로 부른다.
const MONSTER_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const SITE_CLEARED := Color(0.32, 0.34, 0.36, 1.0)
const DEAD_FADE := 0.45

const SITE_HEIGHT := 1.0
const HERO_SIZE := 0.7
const AVATAR_RADIUS := 0.38
const MONSTER_HEIGHT := 0.9
## 조우 종류 이름 — `kind` 가 이것이면 원기둥 기둥으로 그린다.
const KIND_SITE := "site"
const KIND_AVATAR := "avatar"
const KIND_MONSTER := "monster"
const KIND_HERO := "hero"
## 키트 `.glb` 경로 규칙 — 키트 id 가 파일명이다. `art-source/export/<kit>.py` 가 뽑는다.
const KIT_DIR := "res://assets/art/models/%s.glb"
## 지형 알베도 배율 — 식생 틴트를 그대로 쓰면 조명을 얹고 파스텔이 된다.
const TERRAIN_ALBEDO_GAIN := 0.78

## ── 카메라 구도 — 3인칭 추적 ──────────────────────
## 정본이 된 구도는 "캐릭터 뒤의 낮은 원근 카메라"다 (원신·엔드필드가 쓰는 부류).
## 두 게임 다 FOV·거리·기울기 수치를 공개하지 않는다 — 아래 값은 우리 월드 스케일에서
## [ART_BIBLE](../../docs/art/ART_BIBLE.md) 이 정한 **구도 목표**를 맞추려고 고른 값이다.
## 1 유닛 키의 캐릭터가 화면 세로의 약 1/4 을 차지하고, 시선 높이가 캐릭터 머리보다 살짝 위다.
const CAMERA_FOV := 50.0
## 내려다보는 기본 기울기. 0°(수평)에 가까우면 지면이 안 보이고, 40° 를 넘으면 다시 탑뷰가 된다.
const CAMERA_PITCH_DEFAULT := 18.0
const CAMERA_PITCH_MIN := 6.0
const CAMERA_PITCH_MAX := 42.0
## 캐릭터 1 유닛 키 기준. `2 × d × tan(FOV/2)` 가 세로 화면 높이이므로 4.6 이면 캐릭터가 약 24%.
const CAMERA_DISTANCE := 4.2
## 최소는 캐릭터 어깨 바로 뒤, 최대는 필드 28유닛을 한 화면에 담는 거리.
const CAMERA_DISTANCE_MIN := 2.8
const CAMERA_DISTANCE_MAX := 30.0
const CAMERA_ZOOM_STEP := 1.15
## 카메라가 보는 기준점 — 캐릭터 가슴 높이.
const CAMERA_FOCUS_HEIGHT := 0.62
## 시선을 이만큼 더 올리면 캐릭터가 화면 아래 3분의 1로 내려간다.
const CAMERA_AIM_LIFT := 0.75
## 추적 지연. 0 이면 카메라가 딱 붙어 사람이 아닌 것처럼 보이고, 크면 발밑이 늦게 온다.
const CAMERA_FOLLOW := 9.0
## 이보다 멀리 순간이동하면(조종 전환·층 이동) 미끄러지지 않고 그 자리로 붙는다.
const CAMERA_SNAP_DISTANCE := 12.0
## 카메라가 능선에 파묻히지 않게 두는 지면 여유.
const CAMERA_GROUND_CLEAR := 0.5
## 나무·큰 바위 원통 앞에서 붐을 끊을 때 남기는 여유 — 표면에 딱 붙으면 화면이 덜컥거린다.
const CAMERA_COLLISION_PAD := 0.35
## 붐이 이보다 짧아지면 조종 영웅을 흐린다 — 카메라가 등에 붙으면 초록 덩어리가 화면을 덮는다.
## 원신도 벽에 붙으면 같은 방식으로 쓴다. 가까울수록 투명, 멀어지면 원래대로.
## NEAR 아래로는 완전히 가린다 — 카메라가 몸 안에 들어간 상태다.
const CAMERA_AVATAR_FADE_FAR := 2.4
const CAMERA_AVATAR_FADE_NEAR := 1.1
## 마우스 감도 (라디안/픽셀, 약 0.2°/px).
const CAMERA_SENSITIVITY := 0.0035
## 전투·헤드리스처럼 필드가 아닌 화면의 폴백 — 예전 정사영 탑뷰를 그대로 둔다.
const STATIC_PITCH := 60.0
const STATIC_HEIGHT := 34.0

## 동료 색은 에셋 키가 정한다 — 키가 다르면 색이 다르다. 다섯이 같은 상자·같은 파랑이면
## 누가 누군지 모른다. 색역은 청록~자홍 사이만 쓴다 (빨강·주황은 몬스터·조우 몫, 초록은 조종 표시 몫).
##
## 색은 **한 판의 영웅들 사이에서 나눈다**. 키 해시로 색을 뽑으면 두 키가 같은 색에 떨어져서
## 실제로 두 쌍이 구분되지 않았다 — 그래서 키를 정렬해 색역을 고르게 쪼갠다.
const HERO_HUE_FROM := 0.45
const HERO_HUE_TO := 0.90
const HERO_SATURATION := 0.55

## HP 바는 2D 와 같은 그림을 쓴다 (엔티티 크기를 픽셀 폭으로 옮기는 배율만 여기서 정한다).
const BAR_PIXELS_PER_UNIT := 42.0
const BAR_MIN_WIDTH := 18.0
const BAR_MAX_WIDTH := 46.0


class PanelCanvas extends Node2D:
	var view_ref: Node = null

	func _draw() -> void:
		if view_ref != null and view_ref.has_method("draw_party_panel"):
			view_ref.draw_party_panel(self)


class BarCanvas extends Node2D:
	var view_ref: Node = null

	func _draw() -> void:
		if view_ref != null and view_ref.has_method("draw_bars"):
			view_ref.draw_bars(self)


var _world: Node3D = null
var _entities_root: Node3D = null
## 타격 연출이 사는 자리 — 엔티티와 분리해 둔다 (교전 때만 잠깐 붙었다 사라진다).
var _strike_root: Node3D = null
## 마지막으로 그린 교전 번호 — 같은 seq 를 다시 받아도 두 번 그리지 않는다.
var _strike_seq := 0
var _camera: Camera3D = null
var _ground: MeshInstance3D = null
var _light: DirectionalLight3D = null
var _environment: Environment = null
## 지형 — 필드 한 장을 뜬 높이필드. 바이옴·필드가 바뀔 때만 다시 뜬다.
var _terrain: FonsTerrain = null
var _terrain_key := ""
var _terrain_base := GROUND
var _panel_canvas: PanelCanvas = null
var _bar_canvas: BarCanvas = null
var _nodes: Dictionary = {}
var _positions: Dictionary = {}
var _visuals: Dictionary = {}
var _lifts: Dictionary = {}
var _entities: Dictionary = {}
var _materials: Dictionary = {}
## 이번 스냅샷의 조우 자리 — 지형을 평탄하게 누를 지점이다.
var _flats: Array = []
## 에셋 키(`hero:knight`) → `Mesh` 또는 `PackedScene`. 없으면 종류별 도형으로 폴백한다.
var asset_resources: Dictionary = {}
## 에셋 키 → 이번 스냅샷에서 나눠 준 색. `apply` 마다 다시 계산한다.
var asset_colors: Dictionary = {}
var _party: Array = []
var _field := Vector2.ZERO
var _is_field := false
## 이번 스냅샷이 말한 세계 — 뷰는 판정하지 않고 받아 적기만 한다.
var _biome := ""
var _kit := ""
var _palette: Dictionary = {}
var _floor := 1
var _kit_root: Node3D = null
var _kit_built := ""
var _kit_count := 0
## 지금 깔린 키트에 곱해진 역할별 색 — 바이옴이 바뀌면 키트를 다시 깐다
## (색이 메시에 곱해져 있으므로). `_kit_key` 는 그 값을 비교 가능한 문자열로 줄인 것이다.
var _kit_tints: Dictionary = {}
var _kit_key := ""
## 이번 키트가 놓은 키 큰 프롭 — 카메라 붐이 못 지나가는 원통(자리·반경·높이).
## 물리 콜라이더는 없다. 키트가 배치하면서 같이 알려 준다.
var _blockers: Array = []
## 이 뷰가 아는 키트 씬 — 테스트가 가짜 씬을 넣는다 (파일이 없는 키트도 배선 확인 가능).
var kit_scenes: Dictionary = {}
var _last_dir := Vector2.ZERO
## 3인칭 카메라 상태 — 수평 회전(yaw), 내려다보는 각(pitch), 거리.
## 값은 여기 있고 위치는 매 프레임 `_place_camera` 가 다시 낸다.
var _yaw := 0.0
var _pitch := deg_to_rad(CAMERA_PITCH_DEFAULT)
var _distance := CAMERA_DISTANCE
var _focus := Vector3.ZERO
var _focus_ready := false
## 마우스 없이도 시점을 돌릴 수 있게 둔 키 회전(Q/E).
const CAMERA_KEY_TURN := 1.8
var _last_yaw := 0.0


func _ready() -> void:
	_ensure_world()
	_ensure_panel()


func mount(snapshot: Dictionary) -> void:
	_ensure_world()
	_ensure_panel()
	apply(snapshot)
	_mounted = true


func apply(snapshot: Dictionary) -> void:
	_party = snapshot.get("party", [])
	_floor = int(snapshot.get("floor", 1))
	_biome = String(snapshot.get("biome", ""))
	_kit = String(snapshot.get("kit", ""))
	_palette = snapshot.get("palette", {})
	_field = snapshot.get("field", Vector2.ZERO)
	_is_field = String(snapshot.get("mode", "")) == "field" and _field.x > 0.0 and _field.y > 0.0
	var entities: Array = snapshot.get("entities", [])
	_update_colors(entities)
	_update_flats(entities)
	# 지형을 먼저 뜬다 — 유닛·프롭 높이가 그 위에 얹힌다.
	_apply_palette()
	_sync_entities(entities)
	_sync_kit(entities)
	_play_strike(snapshot.get("strike", {}))
	if _is_field:
		_update_camera(0.0)
	else:
		_set_static_camera()
	if _bar_canvas != null:
		_bar_canvas.queue_redraw()
	if _panel_canvas != null:
		_panel_canvas.queue_redraw()


func unmount() -> void:
	for id in _nodes:
		_nodes[id].queue_free()
	_nodes.clear()
	asset_colors.clear()
	_positions.clear()
	_visuals.clear()
	_lifts.clear()
	_entities.clear()
	_party = []
	_field = Vector2.ZERO
	_flats = []
	_is_field = false
	_biome = ""
	_kit = ""
	_palette = {}
	_floor = 1
	_strike_seq = 0
	_yaw = 0.0
	_pitch = deg_to_rad(CAMERA_PITCH_DEFAULT)
	_distance = CAMERA_DISTANCE
	_focus_ready = false
	_clear_kit()
	_clear_terrain()
	_clear_strikes()
	_mounted = false
	if _bar_canvas != null:
		_bar_canvas.queue_redraw()
	if _panel_canvas != null:
		_panel_canvas.queue_redraw()


func entity_count() -> int:
	return _nodes.size()


func strike_fx_count() -> int:
	## 지금 살아 있는 타격 연출 수 — 보통 0 이고, 교전 직후 0.55초 동안만 1 이상이다.
	return 0 if _strike_root == null else _strike_root.get_child_count()


func has_entity(id: String) -> bool:
	return _nodes.has(id)


func entity_position(id: String) -> Vector3:
	return _positions.get(id, Vector3.ZERO)


func entity_mesh(id: String) -> Mesh:
	var visual: MeshInstance3D = _visuals.get(id, null)
	return null if visual == null else visual.mesh


func entity_color(id: String) -> Color:
	## 지금 화면에 칠해진 색 — 죽은 동료는 어둡게 깎인 값이다.
	var visual: MeshInstance3D = _visuals.get(id, null)
	if visual == null or visual.material_override == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	return (visual.material_override as StandardMaterial3D).albedo_color


func entity_asset_node(id: String) -> Node:
	## `PackedScene` 자산이면 엔티티 아래에 붙은 그 씬을 돌려준다 (메시 자산이면 null).
	var node: Node3D = _nodes.get(id, null)
	return null if node == null else node.get_node_or_null("Asset")


func current_biome() -> String:
	return _biome


func current_kit() -> String:
	return _kit


func ground_color() -> Color:
	## 지형은 정점색으로 칠한다 — 재질 알베도는 흰색이므로 기준색을 따로 들고 있는다.
	if _terrain != null:
		return _terrain_base
	if _ground == null:
		return GROUND
	var material := _ground.material_override as StandardMaterial3D
	return GROUND if material == null else material.albedo_color


func sky_color() -> Color:
	return FIELD_BG if _environment == null else _environment.background_color


func light_color() -> Color:
	return Color.WHITE if _light == null else _light.light_color


func light_energy() -> float:
	return 0.0 if _light == null else _light.light_energy


func is_field() -> bool:
	return _is_field


## HP 바를 그릴 엔티티 id — 조우·조종 영웅은 2D 처럼 필드 위에 바를 달지 않는다.
func bar_entity_ids() -> Array:
	var out: Array = []
	for id in _entities:
		var entity: Dictionary = _entities[id]
		var kind := String(entity.get("kind", ""))
		if kind == KIND_SITE or kind == KIND_AVATAR:
			continue
		if FonsHpBar.has_bar(entity):
			out.append(id)
	return out


func draw_party_panel(canvas: Node2D) -> void:
	FonsPartyPanel.draw(canvas, _party, _viewport_size())


func draw_bars(canvas: Node2D) -> void:
	## 머리 위 지점을 화면 픽셀로 옮겨 `FonsHpBar` 에 넘긴다. 트리 밖(헤드리스 테스트)에서는
	## 카메라 투영을 못 하므로 조용히 건너뛴다.
	if _camera == null or not is_inside_tree():
		return
	for id in bar_entity_ids():
		var entity: Dictionary = _entities[id]
		var node: Node3D = _nodes.get(id, null)
		if node == null:
			continue
		var anchor := node.position + Vector3.UP * float(_lifts.get(id, 1.0))
		if _camera.is_position_behind(anchor):
			continue
		var screen := _camera.unproject_position(anchor)
		var width := clampf(float(entity.get("size", Vector2.ONE).x) * BAR_PIXELS_PER_UNIT,
			BAR_MIN_WIDTH, BAR_MAX_WIDTH)
		FonsHpBar.draw(canvas, FonsHpBar.top_left_above(screen, width), width, entity)


## ── 월드 ────────────────────────────────────────────────────────────────

func _ensure_world() -> void:
	if _world != null:
		return
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = FIELD_BG
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.60, 0.70)
	environment.ambient_light_energy = 0.9
	world_env.environment = environment
	_world.add_child(world_env)
	_environment = environment

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	light.light_energy = FonsBiomePalette.DEFAULT_ENERGY
	_world.add_child(light)
	_light = light

	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	# 지형이 없을 때(전투 화면)의 바닥 — 필드가 오면 높이필드로 갈아 끼운다.
	_ground.mesh = PlaneMesh.new()
	_ground.position = Vector3(20.0, -0.02, 14.0)
	_ground.material_override = _material(GROUND)
	_world.add_child(_ground)

	_camera = Camera3D.new()
	_camera.current = true
	_world.add_child(_camera)
	_set_static_camera()

	_entities_root = Node3D.new()
	_entities_root.name = "Entities"
	_world.add_child(_entities_root)

	_strike_root = Node3D.new()
	_strike_root.name = "Strikes"
	_world.add_child(_strike_root)


func _ensure_panel() -> void:
	if _panel_canvas != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	layer.layer = 1
	add_child(layer)
	# 바를 먼저 붙여 파티 칸이 위에 그려지게 한다.
	_bar_canvas = BarCanvas.new()
	_bar_canvas.name = "Bars"
	_bar_canvas.view_ref = self
	layer.add_child(_bar_canvas)
	_panel_canvas = PanelCanvas.new()
	_panel_canvas.view_ref = self
	layer.add_child(_panel_canvas)


func _set_static_camera() -> void:
	## 필드가 아닌 화면(전투·헤드리스)의 폴백 — 예전 정사영 탑뷰. 추적할 캐릭터가 없다.
	if _camera == null:
		return
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 30.0
	_camera.position = Vector3(20.0, STATIC_HEIGHT, 36.0)
	_camera.rotation_degrees = Vector3(-STATIC_PITCH, 0.0, 0.0)


## ── 3인칭 추적 카메라 ──────────────────────────────────────────────

func camera_focus() -> Vector3:
	## 카메라가 보는 기준점 — 조종 영웅의 가슴 높이. 뷰에 아바타가 없으면 필드 가운데.
	var at: Vector3 = _positions.get("avatar", Vector3(_field.x * 0.5, 0.0, _field.y * 0.5))
	return Vector3(at.x, terrain_height(at.x, at.z) + CAMERA_FOCUS_HEIGHT, at.z)


func camera_pitch() -> float:
	return _pitch


func camera_distance() -> float:
	return _distance


func orbit(delta_yaw: float, delta_pitch: float) -> void:
	## 시점 회전. 마우스는 픽셀을 라디안으로 바꿔서 부른다 (테스트는 직접 라디안).
	_yaw = wrapf(_yaw + delta_yaw, -PI, PI)
	_pitch = clampf(_pitch + delta_pitch, deg_to_rad(CAMERA_PITCH_MIN), deg_to_rad(CAMERA_PITCH_MAX))


func zoom(steps: float) -> void:
	## 양수 = 가까이, 음수 = 멀리. 휠 한 칸이 1 스텝이다.
	_distance = clampf(_distance * pow(CAMERA_ZOOM_STEP, -steps),
		CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)


func camera_relative(dir: Vector2) -> Vector2:
	## 화면 기준 입력을 월드 평면으로 돌린다 — 3인칭 게임의 W 는 화면 위쪽이다.
	if dir == Vector2.ZERO:
		return dir
	var c := cos(_yaw)
	var s := sin(_yaw)
	return Vector2(c * dir.x + s * dir.y, -s * dir.x + c * dir.y)


func _update_camera(delta: float) -> void:
	## 기준점은 부드럽게 따라가고, 순간이동(조종 전환·층 이동)은 그 자리로 붙인다.
	if _camera == null or not _is_field:
		return
	var target := camera_focus()
	if not _focus_ready:
		_focus = target
		_focus_ready = true
	elif delta > 0.0:
		if _focus.distance_to(target) > CAMERA_SNAP_DISTANCE:
			_focus = target
		else:
			_focus = _focus.lerp(target, clampf(delta * CAMERA_FOLLOW, 0.0, 1.0))
	_place_camera()


func camera_free_distance(from: Vector3, dir: Vector3, max_distance: float,
		blockers: Array = []) -> float:
	## 기준점에서 `dir` 쪽으로 갈 때 프롭을 뚫지 않을 수 있는 최대 거리.
	## 나무 밑에 서 있으면 그 나무는 무시한다 — 붐을 0으로 만들면 화면이 얼굴로 꽉 찬다.
	var list: Array = _blockers if blockers.is_empty() else blockers
	var limit := max_distance
	for entry in list:
		var hit := _cylinder_hit(from, dir, limit, entry)
		if hit >= 0.0:
			limit = minf(limit, hit - CAMERA_COLLISION_PAD)
	return maxf(0.0, limit)


static func _cylinder_hit(from: Vector3, dir: Vector3, max_distance: float,
		blocker: Dictionary) -> float:
	## 무한 원통(수직)과 선분의 첫 교점. 높이 범위 밖이면 맞지 않은 것으로 본다.
	var pos: Vector3 = blocker.get("pos", Vector3.ZERO)
	var radius := float(blocker.get("radius", 0.0))
	var top := float(blocker.get("top", 0.0))
	if radius <= 0.0 or top <= pos.y:
		return -1.0
	var start := Vector2(from.x - pos.x, from.z - pos.z)
	if start.length() <= radius + CAMERA_COLLISION_PAD:
		return -1.0
	var a := dir.x * dir.x + dir.z * dir.z
	if a <= 0.000001:
		return -1.0
	var b := 2.0 * (start.x * dir.x + start.y * dir.z)
	var c := start.length_squared() - radius * radius
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var hit := (-b - sqrt(disc)) / (2.0 * a)
	if hit < 0.0 or hit > max_distance:
		return -1.0
	# 카메라는 기준점에서 올라가며 뒤로 간다 — 교점이 꼭대기 위면 그 뒤에도 못 들어간다.
	var y := from.y + dir.y * hit
	if y < pos.y or y > top:
		return -1.0
	return hit


func _place_camera() -> void:
	var horizontal := cos(_pitch)
	var offset := Vector3(sin(_yaw) * horizontal, sin(_pitch), cos(_yaw) * horizontal) * _distance
	var dir := offset.normalized()
	# 나무·큰 바위에 파고들지 않게 붐을 앞에서 끊는다.
	var boom := camera_free_distance(_focus, dir, _distance)
	var pos := _focus + dir * boom
	_fade_avatar(boom)
	# 능선에 파묻히지 않게 — 지형에는 콜라이더가 없어서 물리 레이캐스트를 못 쓴다.
	pos.y = maxf(pos.y, terrain_height(pos.x, pos.z) + CAMERA_GROUND_CLEAR)
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = CAMERA_FOV
	# `look_at` 은 트리 밖(헤드리스 테스트)에서 전역 변환을 못 읽는다 — 기저를 직접 만든다.
	# 나무 앞에서 붐이 접히면 고정 시선 높이는 위로 30° 넘게 꺾여 하늘만 보인다 —
	# 기본 거리에 못 미치는 만큼 시선 높이도 줄여 캐릭터를 프레임에 남긴다.
	var lift := CAMERA_AIM_LIFT * clampf(boom / CAMERA_DISTANCE, 0.0, 1.0)
	var aim := _focus + Vector3.UP * lift
	_camera.transform = Transform3D(Basis.looking_at((aim - pos).normalized(), Vector3.UP), pos)


func _fade_avatar(boom: float) -> void:
	## 붐이 짧을수록 조종 영웅을 흐린다. 카메라가 등에 붙은 채 캐릭터를 그대로 두면
	## 화면이 초록 덩어리로 덮여, 나무를 피한 의미가 없다 (2026-10-25 렌더).
	var node: Node3D = _nodes.get(KIND_AVATAR, null)
	if node == null:
		return
	var span := CAMERA_AVATAR_FADE_FAR - CAMERA_AVATAR_FADE_NEAR
	var alpha := 0.0 if span <= 0.0 else clampf(
		(CAMERA_AVATAR_FADE_FAR - boom) / span, 0.0, 1.0)
	_apply_fade(node, alpha)


static func _apply_fade(node: Node, alpha: float) -> void:
	## `GeometryInstance3D.transparency` 는 gl_compatibility 에서 화면을 안 바꿨다 (2026-10-25 렌더).
	## 그래서 메시 재질의 알베도 알파를 직접 바꾼다 — 재질은 색별로 공유되므로 복제해서 건다.
	## 씬 자산은 메시가 여러 겹이다 — 조상 하나만 건드리면 반만 흐려진다.
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var source := mesh.material_override as StandardMaterial3D
		if source != null:
			var faded: StandardMaterial3D = null
			if mesh.has_meta("fade_material"):
				faded = mesh.get_meta("fade_material") as StandardMaterial3D
			if faded == null or mesh.material_override != faded:
				faded = source.duplicate() as StandardMaterial3D
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh.set_meta("fade_source", source)
				mesh.set_meta("fade_material", faded)
			mesh.material_override = source if alpha <= 0.0 else faded
			if alpha > 0.0:
				var color := faded.albedo_color
				color.a = clampf(1.0 - alpha, 0.0, 1.0)
				faded.albedo_color = color
	for child in node.get_children():
		_apply_fade(child, alpha)


func avatar_transparency() -> float:
	## 테스트·디버그용 — 조종 영웅에 걸린 흐림(0 = 불투명, 1 = 안 보임).
	var node: Node3D = _nodes.get(KIND_AVATAR, null)
	if node == null:
		return 0.0
	var mesh := node.find_child("Visual", true, false) as MeshInstance3D
	if mesh == null:
		return 0.0
	var material := mesh.material_override as StandardMaterial3D
	if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		return 0.0
	return clampf(1.0 - material.albedo_color.a, 0.0, 1.0)


func _apply_palette() -> void:
	## 지면·하늘·조명을 바이옴 파생색으로 칠한다. 팔레트가 없는 스냅샷(전투·헤드리스)은 지금 모습 그대로다.
	if _environment == null or _light == null or _ground == null:
		return
	var palette := _palette if not _palette.is_empty() else FonsBiomePalette.defaults()
	_environment.background_color = _color(palette, "sky", FonsBiomePalette.DEFAULT_SKY)
	_environment.ambient_light_color = _color(palette, "ambient", FonsBiomePalette.DEFAULT_AMBIENT)
	_light.light_color = _color(palette, "light", FonsBiomePalette.DEFAULT_LIGHT)
	_light.light_energy = float(palette.get("energy", FonsBiomePalette.DEFAULT_ENERGY))
	_sync_terrain(_color(palette, "ground", FonsBiomePalette.DEFAULT_GROUND), palette)


static func _color(palette: Dictionary, key: String, fallback: Color) -> Color:
	## 깨진 팔레트(문자열 등)가 들어와도 화면이 죽지 않게.
	var value: Variant = palette.get(key, fallback)
	return value if value is Color else fallback


func terrain_height(x: float, z: float) -> float:
	## 유닛·프롭 발밑 높이. 지형이 없으면 0 — 화면이 땅에 붙어 있게.
	return 0.0 if _terrain == null else _terrain.height_at(x, z)


func terrain_normal(x: float, z: float) -> Vector3:
	## 프롭을 경사면에 눕힐 때 쓰는 법선. 지형이 없으면 위.
	if _terrain == null:
		return Vector3.UP
	var e := 0.6
	var dx := _terrain.height_at(x + e, z) - _terrain.height_at(x - e, z)
	var dz := _terrain.height_at(x, z + e) - _terrain.height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func terrain_mesh() -> Mesh:
	return null if _ground == null else _ground.mesh


func _update_flats(entities: Array) -> void:
	## 조우 자리만 평탄화한다 — 유닛과 원기둥이 경사에 뜨지 않게.
	_flats.clear()
	for entity in entities:
		if String(entity.get("kind", "")) != KIND_SITE:
			continue
		var pos: Vector3 = entity.get("pos", Vector3.ZERO)
		_flats.append(Vector2(pos.x, pos.z))


func _sync_terrain(base: Color, palette: Dictionary) -> void:
	## 필드 크기·지면색·기복·조우 자리가 그대로면 다시 뜨지 않는다 (apply 는 매 입력마다 온다).
	if not _is_field or _ground == null:
		return
	var tints: Dictionary = {}
	var value: Variant = palette.get("tints", {})
	if value is Dictionary:
		tints = value
	var relief := float(palette.get("relief", FonsTerrain.default_relief()))
	var key := "%s|%s|%s|%.2f|%s" % [_field, base.to_html(), str(tints), relief, str(_flats)]
	if key == _terrain_key and _terrain != null:
		return
	# 지면색(`ground`)은 2D 배경용으로 어둡다. 3D 알베도는 식생 틴트를 쓴다 —
	# 기복의 명암이 보이려면 빛을 받을 색이 필요하고, 발광으로 밝히면 기복이 다시 지워진다.
	# 틴트는 구운 재질에 곱하는 값이라 그대로 알베도로 쓰면 파스텔로 뜬다.
	# 0.78 은 조명·환경광을 얹은 뒤 중간 초록이 남는 값(2026-10-24 렌더).
	var albedo := base
	var grass: Variant = tints.get("grass", null)
	if grass is Color:
		albedo = (grass as Color) * TERRAIN_ALBEDO_GAIN
	_terrain = FonsTerrain.new(_field, _kit_seed(_biome), relief, _flats)
	_terrain_base = base
	_ground.position = Vector3.ZERO
	_ground.mesh = _terrain.build(albedo, tints)
	_ground.material_override = _terrain_material()
	_terrain_key = key


func _clear_terrain() -> void:
	_terrain = null
	_terrain_key = ""
	_terrain_base = GROUND
	if _ground != null:
		var plane := PlaneMesh.new()
		plane.size = Vector2(40.0, 28.0)
		_ground.mesh = plane
		_ground.position = Vector3(20.0, -0.02, 14.0)


func _terrain_material() -> StandardMaterial3D:
	## 정점색이 곧 알베도다. `_material` 처럼 발광을 섞지 않는다 — 발광은 기복의 명암을 지운다.
	var key := "terrain"
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		# 정점색을 sRGB 로 굽기 때문에 여기서 한 번만 선형으로 바꾼다.
		material.vertex_color_is_srgb = true
		material.roughness = 0.95
		_materials[key] = material
	return _materials[key]


func _sync_entities(entities: Array) -> void:
	if _entities_root == null:
		return
	var seen := {}
	for entity in entities:
		var id := String(entity.get("id", ""))
		if id.is_empty():
			continue
		seen[id] = true
		_entities[id] = entity
		var node: Node3D = _nodes.get(id, null)
		if node == null:
			node = _make_node(entity)
			_nodes[id] = node
			_visuals[id] = node.get_child(0)
			_entities_root.add_child(node)
		_place(node, entity)
	_remove_missing(seen)


func _remove_missing(seen: Dictionary) -> void:
	for id in _nodes.keys():
		if seen.has(id):
			continue
		_nodes[id].queue_free()
		_nodes.erase(id)
		_positions.erase(id)
		_visuals.erase(id)
		_lifts.erase(id)
		_entities.erase(id)


## ── 에셋 키 → 메시 ──────────────────────────────────────────────────────

func register_asset(asset: String, resource: Resource) -> void:
	## 자산이 생기면 여기에 건다: `register_asset("hero:knight", load("res://...glb"))`.
	## `.glb` 는 `PackedScene` 으로 임포트된다 — 씬은 엔티티 아래에 인스턴스로 붙는다.
	## 이미 그려진 엔티티는 다음 `apply` 에서 새 자산을 쓴다.
	if asset.is_empty() or resource == null:
		return
	if resource is Mesh or resource is PackedScene:
		asset_resources[asset] = resource


func asset_mesh(asset: String) -> Mesh:
	var resource: Resource = asset_resources.get(asset, null)
	return resource if resource is Mesh else null


func asset_scene(asset: String) -> PackedScene:
	var resource: Resource = asset_resources.get(asset, null)
	return resource if resource is PackedScene else null


## ── 바이옴 키트 (S2) ────────────────────────────────────────────────────

func register_kit(kit: String, scene: PackedScene) -> void:
	## 테스트·조립 루트가 키트 씬을 직접 건다. 실제 경로는 `KIT_DIR` 규칙으로도 찾는다.
	if kit.is_empty() or scene == null:
		return
	kit_scenes[kit] = scene


func kit_module_count() -> int:
	return _kit_count


func current_kit_tints() -> Dictionary:
	return _kit_tints


func loaded_kit(kit: String) -> PackedScene:
	if kit_scenes.has(kit):
		return kit_scenes[kit]
	var path := KIT_DIR % kit
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


func _sync_kit(entities: Array) -> void:
	## 스냅샷의 `kit` 이 바뀔 때만 다시 깐다 — 매 프레임 48장을 새로 만들지 않는다.
	## 바이옴이 바뀌면 `palette.tints` 도 바뀐다 — 같은 키트라도 색을 다시 곱해야 한다.
	var want := _kit if _is_field else ""
	var tints: Dictionary = {}
	var value: Variant = _palette.get("tints", {})
	if value is Dictionary:
		tints = value
	var key := str(tints) if not want.is_empty() else ""
	if want == _kit_built and key == _kit_key:
		return
	_clear_kit()
	if want.is_empty() or _world == null:
		return
	var scene := loaded_kit(want)
	if scene == null:
		# 아직 자산이 없는 키트 — 빈 필드로 둔다. 나중에 등록되면 다음 apply 에서 깐다.
		return
	var avoid: Array = []
	for entity in entities:
		if String(entity.get("kind", "")) == KIND_SITE:
			avoid.append(entity.get("pos", Vector3.ZERO))
	_kit_root = Node3D.new()
	_kit_root.name = "Kit"
	_world.add_child(_kit_root)
	# 지면 타일은 지형이 대신한다 — 키트는 높이·랜드마크·프롭만 얹고, 모두 지형 높이를 따른다.
	_kit_count = FonsBiomeKit.build(_kit_root, scene, _field, _kit_seed(want), avoid, tints,
		false, Callable(self, "terrain_height"), Callable(self, "terrain_normal"), _blockers)
	_kit_built = want
	_kit_tints = tints
	_kit_key = key


func _kit_seed(kit: String) -> int:
	## 같은 키트·같은 층이면 같은 배치 — 스크린샷과 눈 검토가 흔들리지 않는다.
	return absi(kit.hash() + _floor * 31)


func _clear_kit() -> void:
	if _kit_root != null:
		_kit_root.queue_free()
		_kit_root = null
	_kit_count = 0
	_kit_built = ""
	_kit_tints = {}
	_kit_key = ""
	_blockers.clear()


func _play_strike(strike: Variant) -> void:
	## 심이 "방금 한 판"을 실어 보낸 순간에만 그 자리에 짧은 타격을 낸다.
	## seq 비교는 연출 전용이다 — 전투 결과는 이미 스냅샷의 조우 상태가 말한다.
	if not (strike is Dictionary) or _strike_root == null:
		return
	var seq := int((strike as Dictionary).get("seq", 0))
	if seq <= _strike_seq:
		return
	_strike_seq = seq
	var site := int((strike as Dictionary).get("site", -1))
	if site < 0 or not _positions.has("site:%d" % site):
		return
	var at: Vector3 = _positions["site:%d" % site]
	# 땅에 살짝 띄운다 — 고리가 지형에 뚫리거나 z-파이팅으로 깜빡이지 않게.
	var ground := terrain_height(at.x, at.z)
	FonsStrikeFx.spawn(_strike_root, Vector3(at.x, ground + 0.04, at.z),
		int((strike as Dictionary).get("damage", 0)))


func _clear_strikes() -> void:
	if _strike_root == null:
		return
	for child in _strike_root.get_children():
		child.queue_free()


static func slot_hue(slot: int, count: int) -> float:
	## 색역을 count 칸으로 고르게 쪼갠 slot 번째 색상. count 가 1 이어도 색역 가운데는 안 쏠린다.
	var n := maxi(1, count)
	return HERO_HUE_FROM + (HERO_HUE_TO - HERO_HUE_FROM) * float(clampi(slot, 0, n - 1)) / float(n)


func _update_colors(entities: Array) -> void:
	## 이번 스냅샷의 영웅 키들을 정렬해 색을 나눠 준다 — 키가 다르면 반드시 색이 다르다.
	var assets: Array = []
	for entity in entities:
		if String(entity.get("kind", "")) != KIND_HERO:
			continue
		var asset := String(entity.get("asset", ""))
		if asset.is_empty() or assets.has(asset):
			continue
		assets.append(asset)
	assets.sort()
	asset_colors.clear()
	for i in assets.size():
		asset_colors[assets[i]] = Color.from_hsv(slot_hue(i, assets.size()), HERO_SATURATION, 1.0)


func _make_node(entity: Dictionary) -> Node3D:
	var kind := String(entity.get("kind", ""))
	var asset := String(entity.get("asset", ""))
	var node := Node3D.new()
	node.name = String(entity.get("id", "entity"))
	var mesh := MeshInstance3D.new()
	mesh.name = "Visual"
	var scene := asset_scene(asset)
	if scene != null:
		# 씬이 그림을 맡는다 — 폴백 도형 자리는 비워 두고(child 0) 색·높이 계산 경로는 그대로 둔다.
		mesh.mesh = null
	else:
		var custom := asset_mesh(asset)
		mesh.mesh = custom if custom != null else _fallback_mesh(kind)
	mesh.position.y = _fallback_height(kind) * 0.5
	node.add_child(mesh)
	if scene != null:
		var instance := scene.instantiate()
		instance.name = "Asset"
		node.add_child(instance)
	# ponytail: 씬 자산 높이는 종류 기본값 — 실제 AABB 는 S2 에서 잰다 (HP 바가 떠 보이면 여기).
	_lifts[String(entity.get("id", ""))] = _fallback_height(kind)
	return node


func _fallback_mesh(kind: String) -> Mesh:
	## 자산 키가 없거나 아직 등록 안 된 엔티티용 도형. 종류만큼은 한눈에 구분되게.
	match kind:
		KIND_SITE:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.75
			cylinder.bottom_radius = 0.75
			cylinder.height = SITE_HEIGHT
			return cylinder
		KIND_AVATAR:
			var capsule := CapsuleMesh.new()
			capsule.radius = AVATAR_RADIUS
			capsule.height = 1.0
			return capsule
		KIND_MONSTER:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.45
			cone.height = MONSTER_HEIGHT
			return cone
		_:
			var box := BoxMesh.new()
			box.size = Vector3(HERO_SIZE, HERO_SIZE, HERO_SIZE)
			return box


func _fallback_height(kind: String) -> float:
	match kind:
		KIND_SITE:
			return SITE_HEIGHT
		KIND_AVATAR:
			return 1.0
		KIND_MONSTER:
			return MONSTER_HEIGHT
		_:
			return HERO_SIZE


func _place(node: Node3D, entity: Dictionary) -> void:
	var kind := String(entity.get("kind", ""))
	var pos: Vector3 = entity.get("pos", Vector3.ZERO)
	# 심 좌표는 평면(y=0)이다 — 화면만 지형 높이만큼 들어 올린다.
	var world_pos := Vector3(pos.x, 0.0, pos.z)
	node.position = Vector3(pos.x, terrain_height(pos.x, pos.z), pos.z)
	_positions[String(entity.get("id", ""))] = world_pos
	var mesh: MeshInstance3D = node.get_child(0)
	var height := _fallback_height(kind)
	if kind == KIND_SITE:
		var cleared := bool(entity.get("cleared", false))
		mesh.material_override = _material(SITE_CLEARED if cleared else SITE_COLOR)
		mesh.scale = Vector3(1.0, 0.18, 1.0) if cleared else Vector3.ONE
		mesh.position.y = height * 0.5 * mesh.scale.y
	elif kind == KIND_AVATAR:
		mesh.material_override = _material(AVATAR_COLOR)
		mesh.scale = Vector3.ONE
		mesh.position.y = height * 0.5
	else:
		var color: Color = MONSTER_COLOR if kind == KIND_MONSTER else HERO_COLOR
		if kind != KIND_MONSTER:
			color = asset_colors.get(String(entity.get("asset", "")), HERO_COLOR)
		if not bool(entity.get("alive", true)):
			color = color * DEAD_FADE
		mesh.material_override = _material(color)
		mesh.scale = Vector3.ONE
		mesh.position.y = height * 0.5


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		material.emission_enabled = true
		material.emission = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25)
		_materials[key] = material
	return _materials[key]


## ── 입력 ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _is_field:
		return
	_turn_with_keys(delta)
	_update_camera(delta)
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
	# 카메라를 돌리면 같은 키라도 가는 방향이 바뀐다 — 입력이 같아도 다시 보낸다.
	if dir == _last_dir and is_equal_approx(_yaw, _last_yaw):
		return
	_last_dir = dir
	_last_yaw = _yaw
	intent.emit(&"move", {"dir": camera_relative(dir)})


func _turn_with_keys(delta: float) -> void:
	## 마우스 없이 시점을 돌리는 길. Q·E 는 걷기·행동 키와 겹치지 않는다.
	var turn := 0.0
	if Input.is_key_pressed(KEY_Q):
		turn -= 1.0
	if Input.is_key_pressed(KEY_E):
		turn += 1.0
	if turn != 0.0:
		orbit(turn * CAMERA_KEY_TURN * delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# 오른쪽 버튼을 누른 채로만 시점이 돈다 — 커서를 가두지 않아 창 밖으로 나갈 수 있다.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var motion := event as InputEventMouseMotion
			orbit(-motion.relative.x * CAMERA_SENSITIVITY, motion.relative.y * CAMERA_SENSITIVITY)
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(-1.0)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if _is_field:
		match key:
			KEY_SPACE, KEY_ENTER:
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


func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(1280.0, 720.0)
	return vp.get_visible_rect().size
