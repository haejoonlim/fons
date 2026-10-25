class_name FonsStrikeFx
extends Node3D
## 조우 타격 연출 — 한 번의 교전에 0.55초.
##
## 전투는 한 프레임에 끝난다 (턴 루프가 같은 프레임에서 돈다). 그래서 "싸우는 중"을 그릴 수 없고,
## **방금 한 판**을 한 번 보여 준다: 땅에 퍼지는 고리 + 가운데 번쩍임 + 뜨는 피해 숫자.
## 규칙은 심이 정한다 — 여기는 받은 숫자를 그리기만 하고 아무것도 계산하지 않는다.
##
## 숫자는 그 판 마지막 일격의 피해다 — 로그 마지막 줄과 같은 값이라 화면과 기록이 어긋나지 않는다.
## 여러 턴의 합을 띄우면 한 방처럼 보이는 큰 수가 되어 오해를 만든다.

const LIFE := 0.55
const RING_TIME := 0.36
const FLASH_TIME := 0.18
## 고리는 조우 발자국(지름 1.5)보다 살짝 큰 정도. 3인칭 카메라는 4유닛 앞이라
## 예전 탑뷰(44유닛)에서 쓰던 4.2 는 화면 절반을 덮었다.
const RING_FROM := 0.3
const RING_TO := 2.2
## 숫자는 머리 위에서 살짝만 떠오른다. 3인칭 카메라에서는 1유닛이 화면 150px 이라
## 예전 탑뷰의 1.4유닛은 숫자를 하늘 끝까지 밀어 올렸다.
const RISE := 0.5
const RING_RADIUS := 0.5

const RING_COLOR := Color(1.0, 0.92, 0.72, 1.0)
const FLASH_COLOR := Color(1.0, 0.55, 0.38, 1.0)
const NUMBER_COLOR := Color(1.0, 0.46, 0.36, 1.0)
const OUTLINE_COLOR := Color(0.12, 0.06, 0.05, 0.9)

var _ring: MeshInstance3D = null
var _flash: MeshInstance3D = null
var _number: Label3D = null
var _elapsed := 0.0


static func spawn(parent: Node3D, at: Vector3, damage: int) -> FonsStrikeFx:
	## 지면 높이까지 계산한 자리를 받는다 — 여기서 지형을 다시 묻지 않는다.
	var fx := FonsStrikeFx.new()
	fx.position = at
	fx._build(damage)
	parent.add_child(fx)
	return fx


func _build(damage: int) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - 0.08
	torus.outer_radius = RING_RADIUS
	_ring = _mesh_node(torus, RING_COLOR)
	_ring.scale = Vector3(RING_FROM, 1.0, RING_FROM)
	_ring.position.y = 0.02
	add_child(_ring)

	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	_flash = _mesh_node(sphere, FLASH_COLOR)
	_flash.position.y = 0.7
	add_child(_flash)

	if damage <= 0:
		return
	_number = Label3D.new()
	_number.name = "Damage"
	_number.text = "-%d" % damage
	_number.font_size = 48
	# 화면 크기 고정 — 줌아웃해도 숫자가 작아지지 않고, 가까이서도 화면을 덮지 않는다.
	_number.fixed_size = true
	_number.pixel_size = 0.002
	_number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_number.no_depth_test = true
	_number.modulate = NUMBER_COLOR
	_number.outline_size = 12
	_number.outline_modulate = OUTLINE_COLOR
	_number.position = Vector3(0.0, 1.15, 0.0)
	add_child(_number)


func _mesh_node(mesh: Mesh, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	node.material_override = material
	return node


func _process(delta: float) -> void:
	_elapsed += delta
	var ring_k := clampf(_elapsed / RING_TIME, 0.0, 1.0)
	var spread := lerpf(RING_FROM, RING_TO, ease(ring_k, 0.35))
	_ring.scale = Vector3(spread, 1.0, spread)
	_set_alpha(_ring, 1.0 - ring_k)
	var flash_k := clampf(_elapsed / FLASH_TIME, 0.0, 1.0)
	_flash.scale = Vector3.ONE * lerpf(0.45, 1.7, ease(flash_k, 0.4))
	_set_alpha(_flash, 1.0 - flash_k)
	if _number != null:
		var t := clampf(_elapsed / LIFE, 0.0, 1.0)
		_number.position.y = 1.15 + RISE * ease(t, 0.6)
		_number.modulate.a = 1.0 - clampf((t - 0.4) / 0.6, 0.0, 1.0)
	if _elapsed >= LIFE:
		queue_free()


static func _set_alpha(node: MeshInstance3D, alpha: float) -> void:
	var material := node.material_override as StandardMaterial3D
	if material == null:
		return
	var color := material.albedo_color
	material.albedo_color = Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
