extends GutTest
## 바이옴 키트 배치 — 필드 타일·높이·랜드마크·프롭을 결정론으로 깐다.
## 3D 키트 `.glb` 는 부품 이름(prefix)만 계약이다: ground_·height_·landmark_·prop_.


func _part(name: String) -> Node3D:
	var node := Node3D.new()
	node.name = name
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh.mesh = box
	node.add_child(mesh)
	return node


func _scene(names: Array) -> PackedScene:
	var root := Node3D.new()
	root.name = "Kit"
	for name in names:
		var child := _part(name)
		root.add_child(child)
		child.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _names(parent: Node, prefix: String) -> Array:
	## 같은 부품을 여러 번 붙이면 노드 이름이 바뀌므로, 배치기가 남긴 원본 이름 메타로 찾는다.
	var out: Array = []
	for child in parent.get_children():
		if String(child.get_meta("kit_part", child.name)).begins_with(prefix):
			out.append(child)
	return out


func test_ground_tiles_cover_the_whole_field() -> void:
	## 필드 40×28 · 타일 5 → 8 × 6 = 48칸. 빈 칸이 남으면 지면 판이 비친다.
	var parent := Node3D.new()
	var count := FonsBiomeKit.build(parent, _scene(["ground_a", "ground_b"]), Vector2(40, 28), 1)
	assert_eq(count, 48)
	assert_eq(parent.get_child_count(), 48, "부품 하나당 타일 하나")
	for child in parent.get_children():
		assert_almost_eq(child.position.y, 0.0, 0.001, "타일 바닥은 엔티티 바닥과 같은 0")
	parent.free()


func test_tiles_stay_inside_the_field() -> void:
	## 28 은 5의 배수가 아니다 — 마지막 줄이 줄어들지 않으면 타일이 지면 판 밖으로 떠 보인다.
	var parent := Node3D.new()
	var field := Vector2(40, 28)
	FonsBiomeKit.build(parent, _scene(["ground_a"]), field, 1)
	for child in _names(parent, "ground_"):
		var reach := Vector2(FonsBiomeKit.TILE_SIZE * child.scale.x,
			FonsBiomeKit.TILE_SIZE * child.scale.z) * 0.5
		assert_lte(child.position.x + reach.x, field.x + 0.001, "오른쪽으로 안 넘친다")
		assert_lte(child.position.z + reach.y, field.y + 0.001, "아래로 안 넘친다")
		assert_gte(child.position.x - reach.x, -0.001, "왼쪽으로 안 넘친다")
		assert_gte(child.position.z - reach.y, -0.001, "위로 안 넘친다")
	parent.free()


func test_heights_and_landmark_are_placed_once() -> void:
	var parent := Node3D.new()
	var scene := _scene(["ground_a", "height_hill_a", "height_hill_b", "landmark_tree"])
	var count := FonsBiomeKit.build(parent, scene, Vector2(40, 28), 3)
	assert_eq(_names(parent, "height_").size(), 2, "높이 모듈 2개")
	assert_eq(_names(parent, "landmark_").size(), 1, "랜드마크 1개")
	assert_eq(count, 48 + 3)
	parent.free()


func test_props_keep_clear_of_contacts() -> void:
	var parent := Node3D.new()
	var avoid := [Vector3(20.0, 0.0, 14.0)]
	var count := FonsBiomeKit.build(parent, _scene(["ground_a", "prop_bush"]),
		Vector2(40, 28), 7, avoid)
	assert_eq(count, 48 + FonsBiomeKit.PROP_COUNT, "자리가 모자라지 않으면 프롭은 전부 놓인다")
	for child in _names(parent, "prop_"):
		var flat := Vector2(child.position.x, child.position.z)
		assert_gt(flat.distance_to(Vector2(20.0, 14.0)), FonsBiomeKit.PROP_CLEARANCE - 0.001,
			"조우 지점 위에 프롭을 얹지 않는다")
	parent.free()


func test_same_seed_same_layout() -> void:
	var a := Node3D.new()
	var b := Node3D.new()
	var scene := _scene(["ground_a", "prop_bush", "landmark_tree"])
	FonsBiomeKit.build(a, scene, Vector2(40, 28), 11)
	FonsBiomeKit.build(b, scene, Vector2(40, 28), 11)
	assert_eq(a.get_child_count(), b.get_child_count())
	for i in a.get_child_count():
		assert_eq(a.get_child(i).position, b.get_child(i).position, "%d번째 부품 자리" % i)
	a.free()
	b.free()


## ── 틴트 — 같은 키트를 쓰는 바이옴이 색으로 갈라지는 자리 ─────────────────

func _colored_scene(names: Array, color: Color) -> PackedScene:
	var root := Node3D.new()
	root.name = "Kit"
	for name in names:
		var part := Node3D.new()
		part.name = name
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		box.material = material
		mesh.mesh = box
		part.add_child(mesh)
		root.add_child(part)
		# pack 은 owner 가 있는 노드만 담는다 — 메시까지 챙겨야 재질이 따라온다.
		part.owner = root
		mesh.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _surface_material(part: Node) -> StandardMaterial3D:
	var mesh := part.get_child(0) as MeshInstance3D
	return mesh.get_surface_override_material(0) as StandardMaterial3D


func test_tint_multiplies_the_baked_color() -> void:
	## 틴트는 대체색이 아니라 곱셈이다 — 부품마다 구운 색(잔디·바위·나무)의 관계가 유지된다.
	var baked := Color(0.40, 0.60, 0.20)
	var tint := Color(1.0, 0.70, 0.55)
	var parent := Node3D.new()
	FonsBiomeKit.build(parent, _colored_scene(["ground_a"], baked), Vector2(10, 10), 1,
		[], {"grass": tint})
	var material := _surface_material(parent.get_child(0))
	assert_not_null(material, "틴트가 있으면 surface override 를 건다")
	assert_almost_eq(material.albedo_color.r, baked.r * tint.r, 0.001)
	assert_almost_eq(material.albedo_color.g, baked.g * tint.g, 0.001)
	assert_almost_eq(material.albedo_color.b, baked.b * tint.b, 0.001)
	var source := _colored_scene(["ground_a"], baked).instantiate()
	var base: StandardMaterial3D = (source.get_child(0).get_child(0) as MeshInstance3D).mesh.material
	assert_eq(base.albedo_color, baked, "공유 재질은 건드리지 않는다")
	source.free()
	parent.free()


func test_white_tint_leaves_the_kit_alone() -> void:
	## 바이옴을 모르는 필드의 모습이 바뀌면 안 된다 — 흰색은 곱셈 항등원이다.
	var parent := Node3D.new()
	FonsBiomeKit.build(parent, _colored_scene(["ground_a"], Color(0.4, 0.6, 0.2)),
		Vector2(10, 10), 1)
	assert_null(_surface_material(parent.get_child(0)), "틴트가 없으면 override 도 없다")
	parent.free()


func test_two_tints_share_one_material_per_part() -> void:
	## 48장 타일이 재질 48개를 만들면 낭비다 — 원본 재질 + 역할·틴트 조합당 하나로 재사용한다.
	var parent := Node3D.new()
	FonsBiomeKit.build(parent, _colored_scene(["ground_a"], Color(0.4, 0.6, 0.2)),
		Vector2(10, 10), 1, [], {"grass": Color(1.0, 0.7, 0.55)})
	var first := _surface_material(parent.get_child(0))
	var second := _surface_material(parent.get_child(1))
	assert_not_null(first)
	assert_eq(first.get_instance_id(), second.get_instance_id(), "같은 조합은 같은 재질")
	parent.free()


func _multi_scene(colors: Dictionary) -> PackedScene:
	## 부품마다 다른 색을 굽는다 — 역할 판정(식생/암석/원색)을 한 씬에서 확인하려고.
	var root := Node3D.new()
	root.name = "Kit"
	for name in colors:
		var part := Node3D.new()
		part.name = name
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[name]
		box.material = material
		mesh.mesh = box
		part.add_child(mesh)
		root.add_child(part)
		part.owner = root
		mesh.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_stone_takes_the_rock_tint_and_wood_keeps_its_color() -> void:
	## 마인크래프트식 역할 분리 — 잎·풀은 식생 틴트, 돌은 암석 틴트, 나무는 원색.
	var grass := Color(0.40, 0.60, 0.20)
	var stone := Color(0.52, 0.52, 0.50)
	var wood := Color(0.42, 0.26, 0.12)
	var tints := {"grass": Color(1.0, 0.8, 0.6), "rock": Color(0.8, 0.85, 1.0)}
	var parent := Node3D.new()
	FonsBiomeKit.build(parent, _multi_scene({
		"ground_a": grass, "height_stone": stone, "prop_stump": wood}),
		Vector2(10, 10), 1, [], tints)
	var tiles := _names(parent, "ground_")
	assert_eq(tiles.size(), 4, "10×10 은 2×2 타일")
	assert_almost_eq(_surface_material(tiles[0]).albedo_color.g, grass.g * tints["grass"].g, 0.001,
		"풀은 식생 틴트")
	var heights := _names(parent, "height_")
	assert_eq(heights.size(), 2, "높이 모듈은 모서리 2곳")
	assert_almost_eq(_surface_material(heights[0]).albedo_color.b, stone.b * tints["rock"].b, 0.001,
		"돌은 암석 틴트")
	var props := _names(parent, "prop_")
	assert_gt(props.size(), 0, "프롭이 놓였다")
	assert_null(_surface_material(props[0]), "나무는 원색을 지킨다")
	parent.free()


func test_ground_uses_one_base_tile() -> void:
	## 5유닛 타일 4색을 섞으면 5m 격자무늬로 읽힌다 — 지면은 한 색, 변화는 프롭·조명이 만든다.
	var parent := Node3D.new()
	FonsBiomeKit.build(parent, _scene(["ground_a", "ground_b", "ground_c", "ground_d"]),
		Vector2(40, 28), 5)
	var names := {}
	for part in _names(parent, "ground_"):
		names[String(part.get_meta("kit_part", part.name))] = true
	assert_eq(names.size(), 1, "한 부품만 깔린다")
	assert_true(names.has("ground_a"), "첫 지면 부품을 쓴다")
	assert_eq(_names(parent, "ground_").size(), 48, "타일 수는 그대로")
	parent.free()


func _flat_height(_x: float, _z: float) -> float:
	return 0.75


func test_height_function_lifts_every_part_and_skips_tiles() -> void:
	## 지형이 바닥을 맡으면 키트는 지면 타일을 깔지 않고, 높이·랜드마크·프롭이 땅에 붙는다.
	var parent := Node3D.new()
	var count := FonsBiomeKit.build(parent, _scene(["ground_a", "height_hill", "landmark_tree", "prop_bush"]),
		Vector2(40, 28), 3, [], {}, false, Callable(self, "_flat_height"))
	assert_eq(_names(parent, "ground_").size(), 0, "지면 타일은 안 깔린다")
	assert_eq(count, parent.get_child_count(), "놓은 수 = 붙은 수")
	assert_gt(count, 0)
	for child in parent.get_children():
		assert_almost_eq(child.position.y, 0.75, 0.001, "부품이 지형 높이를 따른다")
	parent.free()


func _slope_height(x: float, _z: float) -> float:
	return 0.18 * x


func _slope_normal(_x: float, _z: float) -> Vector3:
	return Vector3(-0.18, 1.0, 0.0).normalized()


func _part_named(parent: Node, name: String) -> Node3D:
	for child in parent.get_children():
		if String(child.get_meta("kit_part", child.name)) == name:
			return child
	return null


func test_parts_sit_on_the_lowest_footprint_point() -> void:
	## 중심 높이에만 맞추면 경사에서 반대쪽이 뜨고 그 틈으로 지면이 보인다 —
	## 발자국 내 귀퉁이 중 가장 낮은 땅에 앉힌다.
	var parent := Node3D.new()
	var scene := _multi_scene({
		"prop_rock": Color(0.5, 0.5, 0.5), "prop_tree": Color(0.3, 0.5, 0.2),
		"height_hill": Color(0.5, 0.5, 0.5), "landmark_tree": Color(0.3, 0.5, 0.2)})
	FonsBiomeKit.build(parent, scene, Vector2(40, 28), 3, [], {}, false,
		Callable(self, "_slope_height"), Callable(self, "_slope_normal"))
	assert_gt(parent.get_child_count(), 0)
	for child in parent.get_children():
		var center := _slope_height(child.position.x, child.position.z)
		assert_lte(child.position.y, center + 0.001, "%s 가 중심 높이보다 뜨지 않는다" % child.name)
		assert_gte(child.position.y, center - 0.4, "%s 가 땅에 과하게 박히지 않는다" % child.name)
	parent.free()


func test_only_rocks_tilt_with_the_slope() -> void:
	## 나무가 경사를 따라 누우면 뿌리째 쓰러진 것처럼 보인다.
	var parent := Node3D.new()
	var scene := _multi_scene({
		"prop_rock": Color(0.5, 0.5, 0.5), "prop_tree": Color(0.3, 0.5, 0.2)})
	FonsBiomeKit.build(parent, scene, Vector2(40, 28), 3, [], {}, false,
		Callable(self, "_slope_height"), Callable(self, "_slope_normal"))
	var rock := _part_named(parent, "prop_rock")
	var tree := _part_named(parent, "prop_tree")
	assert_not_null(rock, "바위 프롭이 놓였다")
	assert_not_null(tree, "나무 프롭이 놓였다")
	assert_lt(rock.basis.y.dot(Vector3.UP), 0.999, "바위는 경사면을 따른다")
	assert_almost_eq(tree.basis.y.dot(Vector3.UP), 1.0, 0.0001, "나무는 세워 둔다")
	parent.free()


func _ridge_height(_x: float, z: float) -> float:
	## z≈6 에 능선, z≈22 에 골 — 프롭이 성향대로 자리를 고르는지 보는 지형이다.
	return 0.9 * exp(-pow((z - 6.0) / 3.0, 2.0)) - 0.9 * exp(-pow((z - 22.0) / 3.0, 2.0))


func test_rock_props_take_the_crest_and_plants_the_hollow() -> void:
	## 지형을 무시하고 균일하게 뿌리면 풀밭이 초록 판에 색 알갱이를 흩은 것으로 읽힌다.
	## 돌은 능선(위쪽), 풀·꽃은 골(아래쪽)에 앉아야 지형이 프롭을 부른다.
	var parent := Node3D.new()
	var scene := _multi_scene({
		"prop_rock": Color(0.5, 0.5, 0.5),
		"prop_bush": Color(0.30, 0.45, 0.20),
		"prop_flower": Color(0.36, 0.52, 0.24)})
	FonsBiomeKit.build(parent, scene, Vector2(40, 28), 5, [], {}, false,
		Callable(self, "_ridge_height"))
	var seen := {"prop_rock": 0, "prop_bush": 0, "prop_flower": 0}
	for child in _names(parent, "prop_"):
		var part := String(child.get_meta("kit_part", child.name))
		seen[part] += 1
		if part == "prop_rock":
			assert_lt(child.position.z, 14.0, "돌은 능선(z≈6) 쪽에 선다")
		else:
			assert_gt(child.position.z, 14.0, "%s 는 골(z≈22) 쪽에 앉는다" % part)
	for part in seen:
		assert_gt(seen[part], 0, "%s 가 놓였다" % part)
	parent.free()


func test_props_do_not_share_a_spot() -> void:
	## 두 프롭이 같은 점에 서면 하나로 뭉쳐 보인다 — 자리는 서로 겹치지 않는다.
	var parent := Node3D.new()
	FonsBiomeKit.build(parent, _scene(["ground_a", "prop_bush", "prop_rock"]),
		Vector2(40, 28), 5)
	var spots: Array = []
	for child in _names(parent, "prop_"):
		var here := Vector2(child.position.x, child.position.z)
		for other in spots:
			assert_gt(here.distance_to(other), 0.3, "프롭 두 개가 같은 자리에 겹친다")
		spots.append(here)
	parent.free()


func test_props_of_one_kind_clump_together() -> void:
	## 한 마디씩 흩으면 24개도 알갱이다 — 같은 부품은 성향 자리 하나에 모여야
	## 덤불·바위무리로 읽힌다.
	var parent := Node3D.new()
	FonsBiomeKit.build(parent, _scene(["ground_a", "prop_bush", "prop_rock"]),
		Vector2(40, 28), 5)
	var first := {}
	for child in _names(parent, "prop_"):
		var part := String(child.get_meta("kit_part", child.name))
		var here := Vector2(child.position.x, child.position.z)
		if not first.has(part):
			first[part] = here
			continue
		assert_lte(here.distance_to(first[part]), FonsBiomeKit.CLUMP_RADIUS + 0.001,
			"%s 가 무리 반경을 벗어났다" % part)
	parent.free()


func test_scene_without_kit_parts_adds_nothing() -> void:
	var parent := Node3D.new()
	var count := FonsBiomeKit.build(parent, _scene(["not_a_kit_part"]), Vector2(40, 28), 1)
	assert_eq(count, 0, "이름 규칙에 맞는 부품이 없으면 아무것도 안 깐다")
	assert_eq(parent.get_child_count(), 0)
	parent.free()


func test_an_empty_scene_is_not_fatal() -> void:
	var parent := Node3D.new()
	assert_eq(FonsBiomeKit.build(parent, null, Vector2(40, 28), 1), 0)
	assert_eq(parent.get_child_count(), 0)
	parent.free()


func test_pilot_kit_imports_with_every_family() -> void:
	## S2 파일럿 — 풀바다 키트 한 벌이 실제로 임포트되고 네 부품군을 갖는가.
	var path := "res://assets/art/models/topo_natural_surface.glb"
	assert_true(ResourceLoader.exists(path), "익스포트 결과물이 있어야 한다 (Blender 스크립트로 뽑는다)")
	var scene := load(path) as PackedScene
	assert_not_null(scene, "glb 는 PackedScene 으로 임포트된다")
	var root := scene.instantiate()
	var families := {}
	_collect_families(root, families)
	for prefix in ["ground_", "height_", "landmark_", "prop_"]:
		assert_true(families.has(prefix), "%s 부품이 있다" % prefix)
	root.free()


func test_pilot_kit_reports_tall_camera_blockers() -> void:
	## 실제 .glb 로도 카메라 가림이 나와야 한다 — 테스트용 상자 장면만 통과하면 의미가 없다.
	var scene := load("res://assets/art/models/topo_natural_surface.glb") as PackedScene
	assert_not_null(scene, "파일럿 키트가 있어야 한다")
	var parent := Node3D.new()
	var blockers: Array = []
	FonsBiomeKit.build(parent, scene, Vector2(40, 28), 5, [], {}, false,
		Callable(), Callable(), blockers)
	assert_gt(blockers.size(), 0, "파일럿 키트의 키 큰 부품이 가림으로 나온다")
	var tallest := 0.0
	for entry in blockers:
		tallest = maxf(tallest, float(entry["top"]) - (entry["pos"] as Vector3).y)
	assert_gt(tallest, 1.2, "나무·바위 높이가 카메라 높이를 넘는다")
	parent.free()


func _collect_families(node: Node, found: Dictionary) -> void:
	for prefix in ["ground_", "height_", "landmark_", "prop_"]:
		if String(node.name).begins_with(prefix):
			found[prefix] = true
	for child in node.get_children():
		_collect_families(child, found)


func test_tall_parts_report_camera_blockers() -> void:
	## 카메라는 지형 높이만 피하면 나무를 뚫는다. 키트가 **키 큰 부품**을 원통으로 알려 준다.
	var root := Node3D.new()
	root.name = "Kit"
	var tree := Node3D.new()
	tree.name = "prop_tree"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 4.0, 2.0)
	mesh.mesh = box
	tree.add_child(mesh)
	root.add_child(tree)
	tree.owner = root
	mesh.owner = root  # pack 은 owner 가 있는 노드만 담는다 — 없으면 메시가 빠져 가림도 안 나온다
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var parent := Node3D.new()
	var blockers: Array = []
	FonsBiomeKit.build(parent, scene, Vector2(40, 28), 5, [], {}, false,
		Callable(), Callable(), blockers)
	assert_gt(blockers.size(), 0, "키 큰 프롭은 가림 목록에 오른다")
	for entry in blockers:
		var base: Vector3 = entry["pos"]
		assert_gt(float(entry["top"]) - base.y, 1.2, "카메라 높이를 넘는 부품만")
		assert_gt(float(entry["radius"]), 0.0, "원통 반경이 있다")
	parent.free()
	var flat := Node3D.new()
	var none: Array = []
	FonsBiomeKit.build(flat, _scene(["ground_a"]), Vector2(40, 28), 5, [], {}, true,
		Callable(), Callable(), none)
	assert_eq(none.size(), 0, "바닥 타일은 가림이 아니다")
	flat.free()


func test_tree_reports_trunk_and_canopy_as_separate_cylinders() -> void:
	## 줄기와 잎을 원통 하나로 묶으면 반경이 잎 폭(1.81)이 되고, 그 원통 안에 캐릭터가 서면
	## 가림이 통째로 무시되어 카메라가 줄기를 뚫는다. 표면(surface) 단위여야 줄기가 얇게 남는다.
	var scene := load("res://assets/art/models/topo_natural_surface.glb") as PackedScene
	assert_not_null(scene, "파일럿 키트가 있어야 한다")
	var parent := Node3D.new()
	var blockers: Array = []
	FonsBiomeKit.build(parent, scene, Vector2(40, 28), 5, [], {}, false,
		Callable(), Callable(), blockers)
	var thin := INF
	var wide := 0.0
	for entry in blockers:
		var radius := float(entry["radius"])
		thin = minf(thin, radius)
		wide = maxf(wide, radius)
	assert_lt(thin, 0.5, "줄기는 얇은 원통으로 따로 나온다")
	assert_gt(wide, 1.0, "잎은 넓은 원통으로 따로 나온다")
	parent.free()
