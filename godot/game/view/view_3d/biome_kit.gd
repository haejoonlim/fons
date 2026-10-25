class_name FonsBiomeKit
extends RefCounted
## 바이옴 키트 배치 — 필드에 바닥 타일·높이·랜드마크·프롭을 깐다.
##
## 계약은 **부품 이름 prefix** 뿐이다. `.glb` 안의 오브젝트 이름이 `ground_`·`height_`·
## `landmark_`·`prop_` 로 시작하면 그 가족으로 묶이고, 이름 규칙에 없는 노드는 무시한다.
## 메시 모양·재질은 이 클래스가 모른다 — 3D 뷰가 씬을 그대로 인스턴스한다.
##
## 배치는 **결정론**이다. 같은 키트·같은 시드면 같은 자리 — 스크린샷과 눈 검토가 흔들리지 않는다.
## 심은 이 클래스를 부르지 않는다. 필드 스냅샷의 `kit` 문자열만 보고 뷰가 직접 깐다.
##
## 색은 **역할별 틴트**(`tints`)로만 바뀐다 — 심이 `FonsBiomePalette` 로 파생한 값이다.
## 마인크래프트처럼 잎·풀만 틴트하고 돌은 따로, 나무·꽃잎은 구운 색을 지킨다.
## 역할은 부품 이름이 아니라 **구운 재질색**으로 고른다(회색=돌, 초록 대역=식생) — 
## 이름 계약(prefix)은 그대로 두고 부품이 늘어도 규칙이 안 바뀐다.
## 메시에 구워진 색에 곱하므로 같은 키트를 쓰는 바이옴이 지형을 새로 만들지 않고도 다르게 읽힌다.
## 틴트가 없으면 곱셈 항등원 — 지금 모습 그대로다.
##
## 프롭은 **지형이 부른다**. 자리를 균일 난수로 던지면 풀밭이 초록 판에 색 알갱이를
## 흩은 것으로 읽힌다. 돌은 능선·급경사, 풀·꽃은 골, 나무·그루터기는 어깨에 앉힌다 —
## 판정은 부품 이름이 아니라 구운 재질색(역할)이다.
##
## 아직 파일럿이다: 길·물은 키트 모듈이 늘어난 뒤(S3) 정한다.

const TILE_SIZE := 5.0
## 프롭 수 — 파일럿 값이다. 바이옴별 확정 수는 `data/biome_assets.json` 의 props 가 정한다 (S2 이후).
## 12 로는 40×28 에서 성향별 무리가 안 보이고 알갱이 12개로 읽혔다 (2026-10-25 렌더).
const PROP_COUNT := 24
## 지면은 **한 부품**으로 깐다. 5유닛 타일 4색을 섞으면(순환·가중 무관) 5m 격자무늬로 읽힌다.
## 마인크래프트도 색 변화를 1m 블록 텍스처 단위로 두지, 5m 판때기 단위로 두지 않는다.
## 색 변화는 프롭·높이·조명이 만들고, 지면은 바이옴 한 색으로 둔다 (2026-10-24 렌더 판정).
## 역할 판정 — 재질색의 채도가 낮으면 돌, 색상각이 초록 대역이면 식생, 나머지는 원색 유지.
const ROLE_GRASS := "grass"
const ROLE_ROCK := "rock"
const STONE_SATURATION := 0.20
const VEGETATION_HUE_FROM := 0.16
const VEGETATION_HUE_TO := 0.46
## 조우 지점 위에 프롭을 얹지 않는 거리.
const PROP_CLEARANCE := 2.5
## 프롭 성향 — 능선(돌)·골(식생)·평지(그루터기).
const FIT_RIDGE := "ridge"
const FIT_HOLLOW := "hollow"
const FIT_FLAT := "flat"
## 성향을 재는 반경(유닛) — 지형 결(33유닛)보다 작고 프롭 크기보다 크다.
const RELIEF_SPAN := 2.0
## 기울기 1.0 기준 — 이 지형의 최대 기울기는 실측 0.18 이다 (`FonsTerrain.ROCK_SLOPE` 언저리).
const STEEP_SLOPE := 0.18
## 볼록함 ±1 이 되는 유닛 — 이 지형 기복(±1.5)에서 능선과 골이 갈리는 폭.
const CURVE_SCALE := 0.12
## 능선 점수에서 볼록함이 차지하는 몫. 나머지는 기울기 — 돌은 급경사에도 선다.
const CURVE_WEIGHT := 0.75
## 프롭 자리 후보 간격(유닛)과 흔드는 폭. 촘촘하면 무리가 뭉치고, 성기면 격자로 보인다.
const SPOT_STEP := 1.5
const SPOT_JITTER := 0.6
## 같은 점수가 여럿일 때 순서를 흐트러뜨리는 폭 — 격자 줄로 프롭이 늘어서지 않게.
const SPOT_TIEBREAK := 0.01
## 한 가지 프롭이 모이는 반경(유닛). 성향이 맞는 자리 하나에 몰아 놓아야
## 덤불·바위·꽃밭이 무리로 읽힌다. 하나씩 흩으면 24개도 여전히 알갱이다(2026-10-25 렌더).
const CLUMP_RADIUS := 3.0
## 발자국 샘플 반경 상한 — 프롭이 이보다 넓으면 가장자리 대신 중심 근처만 본다.
## 넓은 바위를 발자국 전체로 내리면 반대쪽이 땅에 박힌다.
const FOOTPRINT_MAX := 1.6
## 프롭이 필드 가장자리에 붙지 않게 두는 여백.
const EDGE_MARGIN := 2.5
## 카메라 가림으로 보고할 최소 높이 — 이보다 낮은 풀·꽃·바위는 시선을 안 막는다.
const BLOCKER_HEIGHT := 1.2

const GROUND := "ground_"
const HEIGHT := "height_"
const LANDMARK := "landmark_"
const PROP := "prop_"
const FAMILIES := [GROUND, HEIGHT, LANDMARK, PROP]


static func build(parent: Node3D, scene: PackedScene, field: Vector2,
		seed_value: int, avoid: Array = [], tints: Dictionary = {},
		lay_ground: bool = true, height: Callable = Callable(),
		normal: Callable = Callable(), blockers: Array = []) -> int:
	## 부품을 parent 아래에 깔고 놓은 수를 돌려준다. parent·scene 이 없으면 0.
	## `lay_ground` 가 false 면 지면 타일을 깔지 않는다 — 높이필드 지형이 바닥을 맡을 때다.
	## `height` 는 (x, z) → y 함수다. 주면 높이·랜드마크·프롭이 땅에 붙는다.
	## `normal` 은 (x, z) → 법선이다. 주면 바위가 경사면에 눕는다.
	## `blockers` 를 주면 카메라를 가리는 **키 큰 부품**의 원통(자리·반경·높이)을 담아 준다.
	## 카메라가 프롭을 뚫지 않게 하는 유일한 정보원이다 — 물리 콜라이더는 없다.
	if parent == null or scene == null or field.x <= 0.0 or field.y <= 0.0:
		return 0
	var source := scene.instantiate()
	# 부품을 찾는 동안에만 원본 씬을 살려 둔다 — 인스턴스는 duplicate() 라 원본과 무관하다.
	var parts := _collect(source)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# 틴트 재질은 부품 수만큼 만들면 낭비다 — 원본 재질 + 틴트 조합당 하나로 재사용한다.
	var materials := {}
	var count := 0
	if lay_ground:
		count += _lay_ground(parent, parts[GROUND], field, tints, materials)
	# 높이 모듈은 땅 자체라 가림이 아니다 — 카메라를 밀면 지형이 아니라 프롭만 피해야 한다.
	count += _place_at(parent, parts[HEIGHT], _edge_spots(field), rng, tints, materials, height, normal, [])
	count += _place_at(parent, parts[LANDMARK], [Vector2(field.x * 0.5, TILE_SIZE * 0.5)],
		rng, tints, materials, height, normal, blockers)
	count += _scatter_props(parent, parts[PROP], field, rng, avoid, tints, materials, height, normal, blockers)
	source.free()
	return count


static func _role(material: StandardMaterial3D) -> String:
	## 구운 색만 보고 역할을 고른다. 돌은 채도가 낮고, 식생은 초록 대역이다.
	## 나무 줄기·꽃잎은 둘 다 아니라 원색을 지킨다 — 마인크래프트도 나무는 틴트하지 않는다.
	var albedo := material.albedo_color
	if albedo.s < STONE_SATURATION:
		return ROLE_ROCK
	if albedo.h > VEGETATION_HUE_FROM and albedo.h < VEGETATION_HUE_TO:
		return ROLE_GRASS
	return ""


static func _tint_node(node: Node, tints: Dictionary, materials: Dictionary) -> void:
	## 메시에 구워진 재질은 공유 자산이라 건드리지 않는다 — 인스턴스에 surface override 로만 곱한다.
	## 부품 하나가 재질 여러 개를 쓰는 경우(나무 줄기+잎)도 있으니 surface 단위로 순회한다.
	if tints.is_empty():
		return
	if node is MeshInstance3D and node.mesh != null:
		var instance := node as MeshInstance3D
		for i in instance.mesh.get_surface_count():
			var base := instance.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var role := _role(base)
			if role.is_empty() or not tints.has(role):
				continue
			var tint: Color = tints[role]
			if tint == Color.WHITE:
				continue
			var key := "%d|%s|%s" % [base.get_instance_id(), role, tint.to_html(false)]
			if not materials.has(key):
				var tinted := base.duplicate() as StandardMaterial3D
				var albedo := base.albedo_color
				tinted.albedo_color = Color(albedo.r * tint.r, albedo.g * tint.g,
					albedo.b * tint.b, albedo.a)
				materials[key] = tinted
			instance.set_surface_override_material(i, materials[key])
	for child in node.get_children():
		_tint_node(child, tints, materials)


static func _collect(root: Node) -> Dictionary:
	var out := {}
	for family in FAMILIES:
		out[family] = []
	_walk(root, out)
	return out


static func _walk(node: Node, out: Dictionary) -> void:
	for child in node.get_children():
		var name := String(child.name)
		var matched := false
		for family in FAMILIES:
			if name.begins_with(family):
				out[family].append(child)
				matched = true
				break
		if not matched:
			_walk(child, out)


static func _instance(part: Node, position: Vector3, yaw: float,
		tints: Dictionary, materials: Dictionary) -> Node3D:
	var node := part.duplicate() as Node3D	# 같은 부품을 여러 번 붙이면 Godot 가 이름을 바꿔 버린다 — 원본 이름을 메타로 남겨
	# 가족(prefix)을 테스트·디버깅에서도 찾을 수 있게 한다.
	node.set_meta("kit_part", String(part.name))
	node.position = position
	node.rotation_degrees.y = yaw
	_tint_node(node, tints, materials)
	return node


static func _lay_ground(parent: Node3D, parts: Array, field: Vector2,
		tints: Dictionary, materials: Dictionary) -> int:
	## 필드를 5유닛 칸으로 덮는다 — 40×28 이면 8 × 6 = 48장. 빈 칸이 남으면 지면 판이 비친다.
	if parts.is_empty():
		return 0
	var cols := int(ceil(field.x / TILE_SIZE))
	var rows := int(ceil(field.y / TILE_SIZE))
	var count := 0
	for cx in cols:
		for cz in rows:
			# 마지막 줄은 필드 밖으로 넘친다 (40×28 이면 6줄 = 30). 남은 폭만큼 줄여 깔아
			# 타일이 지면 판 밖으로 떠 보이지 않게 한다 — 색만 있는 판이라 줄여도 티가 안 난다.
			var span := Vector2(minf(TILE_SIZE, field.x - cx * TILE_SIZE),
				minf(TILE_SIZE, field.y - cz * TILE_SIZE))
			if span.x <= 0.0 or span.y <= 0.0:
				continue
			var tile := _instance(parts[0], Vector3(
				cx * TILE_SIZE + span.x * 0.5, 0.0, cz * TILE_SIZE + span.y * 0.5), 0.0, tints, materials)
			tile.scale = Vector3(span.x / TILE_SIZE, 1.0, span.y / TILE_SIZE)
			parent.add_child(tile)
			count += 1
	return count


static func _edge_spots(field: Vector2) -> Array:
	## 높이 모듈은 모서리에 둔다 — 조우 지점(세로 3줄)과 겹치지 않는다.
	return [
		Vector2(TILE_SIZE * 0.5, field.y - TILE_SIZE * 0.5),
		Vector2(field.x - TILE_SIZE * 0.5, TILE_SIZE * 0.5),
	]


static func _place_at(parent: Node3D, parts: Array, spots: Array, rng: RandomNumberGenerator,
		tints: Dictionary, materials: Dictionary, height: Callable, normal: Callable,
		blockers: Array) -> int:
	if parts.is_empty():
		return 0
	var count := 0
	for i in spots.size():
		var point: Vector2 = spots[i]
		var part: Node = parts[i % parts.size()]
		var node := _instance_grounded(part, point, float(rng.randi_range(0, 3)) * 90.0,
			tints, materials, height, normal)
		parent.add_child(node)
		_append_blocker(blockers, node, part)
		count += 1
	return count


static func _ground_y(point: Vector2, height: Callable) -> float:
	## 높이 함수가 없으면 예전처럼 y=0 — 헤드리스 테스트 경로가 그대로 산다.
	return float(height.call(point.x, point.y)) if height.is_valid() else 0.0


static func _instance_grounded(part: Node, point: Vector2, yaw: float, tints: Dictionary,
		materials: Dictionary, height: Callable, normal: Callable) -> Node3D:
	## 프롭을 **발자국에서 가장 낮은 땅**에 앉힌다. 중심 높이에만 맞추면 경사에서
	## 한쪽이 뜨고, 그 틈으로 지면이 비친다.
	var node := _instance(part, Vector3.ZERO, 0.0, tints, materials)
	var low := _ground_y(point, height)
	if height.is_valid():
		var reach := minf(_footprint_radius(part), FOOTPRINT_MAX)
		for step in [Vector2(reach, 0.0), Vector2(-reach, 0.0),
				Vector2(0.0, reach), Vector2(0.0, -reach)]:
			low = minf(low, _ground_y(point + step, height))
	node.position = Vector3(point.x, low, point.y)
	if normal.is_valid() and _tilts_in_slope(part):
		node.basis = _slope_basis(normal.call(point.x, point.y), yaw)
	else:
		node.rotation_degrees.y = yaw
	return node


static func _append_blocker(blockers: Array, node: Node3D, part: Node) -> void:
	## 카메라 붐이 못 지나갈 원통을 **표면(surface)마다** 하나씩.
	## 메시 하나를 원통 하나로 묶으면 나무 기둥(반경 0.22)과 잎(반경 1.81)이 한 덩어리가 된다 —
	## 그 넓은 원통이 캐릭터까지 덮으면 `_cylinder_hit` 이 "발치에 섰다"고 보고 기둥을 통째로
	## 무시해, 카메라가 줄기를 뚫고 들어간다 (2026-10-25 렌더: 화면이 줄기로 꽉 참).
	## 표면은 모델러가 이미 줄기·잎으로 나눠 두었으므로, 반경이 따로 놀게 하려면 여기까지 내려온다.
	for entry in _meshes(part):
		var mesh := entry as MeshInstance3D
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var box := _surface_box(mesh.mesh, i)
			if box.size.y <= 0.0:
				continue
			var base := mesh.position.y + box.position.y * mesh.scale.y
			var top := base + box.size.y * mesh.scale.y
			if top - base < BLOCKER_HEIGHT:
				continue
			var center := mesh.position * mesh.scale + box.get_center() * mesh.scale
			var offset := node.basis * Vector3(center.x, 0.0, center.z)
			var radius := maxf(box.size.x * mesh.scale.x, box.size.z * mesh.scale.z) * 0.5
			if radius <= 0.0:
				continue
			blockers.append({
				"pos": Vector3(node.position.x + offset.x, node.position.y + base,
					node.position.z + offset.z),
				"radius": radius,
				"top": node.position.y + top,
			})


static func _surface_box(mesh: Mesh, index: int) -> AABB:
	## 표면 하나의 로컬 AABB. `ArrayMesh.get_aabb()` 는 메시 전체라 표면 구분이 안 된다.
	var arrays := mesh.surface_get_arrays(index)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return AABB()
	var box := AABB(vertices[0], Vector3.ZERO)
	for point in vertices:
		box = box.expand(point)
	return box


static func _footprint_radius(part: Node) -> float:
	## 부품 중심에서 가장 먼 수평 발자국 반경. AABB 모서리까지의 거리로 잡는다.
	var radius := 0.0
	for entry in _meshes(part):
		var mesh := entry as MeshInstance3D
		var box: AABB = mesh.get_aabb()
		var center: Vector3 = mesh.position + box.get_center()
		var half := Vector2(box.size.x, box.size.z) * 0.5
		radius = maxf(radius, Vector2(center.x, center.z).length() + half.length())
	return radius


static func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out


static func _tilts_in_slope(part: Node) -> bool:
	## 기운 것은 바위뿐이다. 나무는 하늘로 자라고, 풀·꽃은 눕으면 뜻이 뒤집힌다.
	## 돌 판정은 틴트·성향과 같은 규칙 — 부품 이름이 아니라 구운 재질색이다.
	return String(part.name).begins_with(HEIGHT) or _part_role(part) == ROLE_ROCK


static func _slope_basis(up: Vector3, yaw: float) -> Basis:
	## 로컬 +Y 를 지면 법선에 맞춘다. yaw 는 경사면 안에서 돈다.
	var y := up.normalized()
	if y.dot(Vector3.UP) > 0.9999:
		return Basis(Vector3.UP, deg_to_rad(yaw))
	var yaw_rad := deg_to_rad(yaw)
	var forward := Vector3(sin(yaw_rad), 0.0, cos(yaw_rad))
	var z := (forward - y * forward.dot(y)).normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


static func _scatter_props(parent: Node3D, parts: Array, field: Vector2,
		rng: RandomNumberGenerator, avoid: Array, tints: Dictionary, materials: Dictionary,
		height: Callable, normal: Callable, blockers: Array) -> int:
	if parts.is_empty():
		return 0
	var margin := minf(EDGE_MARGIN, minf(field.x, field.y) * 0.1)
	# 프롭마다 무작위로 한 점을 던지면 성향을 못 쓴다 — 후보를 미리 깔고 점수를 매긴 뒤
	# 부품 성향에 가장 맞는 자리를 고른다. 쓴 자리는 다시 안 쓴다(겹치면 하나로 뭉친다).
	var spots := _spots(field, margin, rng, avoid, height)
	var used := {}
	var anchors := {}
	var count := 0
	for slot in PROP_COUNT:
		var index := slot % parts.size()
		var part: Node = parts[index]
		var fit := _part_fit(part)
		if not anchors.has(index):
			# 이 종류가 모일 자리 — 성향에 가장 맞는 자리 하나. 첫 하나는 반드시 여기 선다.
			var anchor := _best_spot(spots, used, fit, rng, null)
			if anchor < 0:
				break
			anchors[index] = anchor
		var home: int = anchors[index]
		var pick := home if not used.has(home) else \
			_best_spot(spots, used, fit, rng, spots[home]["pos"])
		if pick < 0:
			# 무리 반경 안에 자리가 모자라면 남은 성향 자리로 흘린다 — 개수는 안 줄인다.
			pick = _best_spot(spots, used, fit, rng, null)
		if pick < 0:
			break
		used[pick] = true
		var point: Vector2 = spots[pick]["pos"]
		var node := _instance_grounded(part, point, rng.randf_range(0.0, 360.0),
			tints, materials, height, normal)
		parent.add_child(node)
		_append_blocker(blockers, node, part)
		count += 1
	return count


static func _spots(field: Vector2, margin: float, rng: RandomNumberGenerator,
		avoid: Array, height: Callable) -> Array:
	## 후보 자리 — 격자에 흔들어 깔고, 그 자리의 성향 점수(능선 +1 ↔ 골 −1)를 함께 적는다.
	var out: Array = []
	var cols := maxi(1, int(floor((field.x - margin * 2.0) / SPOT_STEP)) + 1)
	var rows := maxi(1, int(floor((field.y - margin * 2.0) / SPOT_STEP)) + 1)
	for ix in cols:
		for iz in rows:
			var point := Vector2(margin + ix * SPOT_STEP, margin + iz * SPOT_STEP)
			point += Vector2(rng.randf_range(-SPOT_JITTER, SPOT_JITTER),
				rng.randf_range(-SPOT_JITTER, SPOT_JITTER))
			point = Vector2(clampf(point.x, margin, field.x - margin),
				clampf(point.y, margin, field.y - margin))
			if _too_close(point, avoid):
				continue
			out.append({"pos": point, "ridge": _ridge_score(point, height)})
	return out


static func _ridge_score(point: Vector2, height: Callable) -> float:
	## +1 능선 · −1 골. 주변 평균과의 차(볼록함)와 기울기를 함께 본다.
	## 지형이 없으면 0 — 성향을 못 가리므로 점수가 같은 자리끼리 흔들어 고른다.
	if not height.is_valid():
		return 0.0
	var e := RELIEF_SPAN
	var hc := float(height.call(point.x, point.y))
	var hxp := float(height.call(point.x + e, point.y))
	var hxm := float(height.call(point.x - e, point.y))
	var hzp := float(height.call(point.x, point.y + e))
	var hzm := float(height.call(point.x, point.y - e))
	var slope := Vector2(hxp - hxm, hzp - hzm).length() / (2.0 * e)
	var curve := clampf((hc - (hxp + hxm + hzp + hzm) * 0.25) / CURVE_SCALE, -1.0, 1.0)
	return curve * CURVE_WEIGHT + clampf(slope / STEEP_SLOPE, 0.0, 1.0) * (1.0 - CURVE_WEIGHT)


static func _part_fit(part: Node) -> String:
	## 구운 재질색으로 성향을 고른다 — 돌은 능선, 식생은 골, 나무·그루터기는 어깨.
	match _part_role(part):
		ROLE_ROCK:
			return FIT_RIDGE
		ROLE_GRASS:
			return FIT_HOLLOW
		_:
			return FIT_FLAT


static func _part_role(part: Node) -> String:
	## 부품이 쓴 재질색 중 대표 역할 하나. 식생이 하나라도 있으면 식생이다 —
	## 나무 줄기보다 잎이 뜻을 정한다.
	var rock := false
	for mesh in _meshes(part):
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if material == null:
				continue
			var role := _role(material)
			if role == ROLE_GRASS:
				return ROLE_GRASS
			if role == ROLE_ROCK:
				rock = true
	return ROLE_ROCK if rock else ""


static func _best_spot(spots: Array, used: Dictionary, fit: String,
		rng: RandomNumberGenerator, near: Variant = null) -> int:
	## 아직 안 쓴 자리 중 성향에 가장 맞는 하나. `near` 를 주면 그 무리 반경 안에서만 찾는다.
	## 점수가 같으면 흔든 순서가 이긴다.
	var best := -INF
	var pick := -1
	for i in spots.size():
		if used.has(i):
			continue
		if near != null and (spots[i]["pos"] as Vector2).distance_to(near as Vector2) > CLUMP_RADIUS:
			continue
		var score := _fit_score(float(spots[i]["ridge"]), fit) + rng.randf() * SPOT_TIEBREAK
		if score > best:
			best = score
			pick = i
	return pick


static func _fit_score(ridge: float, fit: String) -> float:
	match fit:
		FIT_RIDGE:
			return ridge
		FIT_HOLLOW:
			return -ridge
		_:
			# 그루터기·나무는 능선도 골도 아닌 어깨 — 어중간한 땅을 고른다.
			return -absf(ridge)


static func _too_close(point: Vector2, avoid: Array) -> bool:
	for entry in avoid:
		var pos: Vector3 = entry
		if point.distance_to(Vector2(pos.x, pos.z)) <= PROP_CLEARANCE:
			return true
	return false
