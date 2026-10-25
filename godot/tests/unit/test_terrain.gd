extends GutTest
## 연속 높이필드 — 필드 한 장을 뜨고, 높이·색·법선이 지형으로 읽히는지 잠근다.
## 격자가 보이던 원인은 타일별 메시의 법선이었다. 한 장이면 정점을 공유해 경계가 없다.


func _mesh(relief: float = 1.0, seed_value: int = 7) -> ArrayMesh:
	return FonsTerrain.new(Vector2(40, 28), seed_value, relief).build(Color(0.24, 0.32, 0.12))


func test_one_surface_shares_every_vertex() -> void:
	## 타일을 이어 붙이면 정점이 판마다 복제된다. 한 장이면 격자 하나뿐이다.
	## 3인칭 카메라가 필드 밖으로 나가므로 땅은 사방 `MARGIN` 만큼 더 뜬다 (플레이 경계는 그대로).
	var mesh := _mesh()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols := int(ceil((40.0 + 2.0 * FonsTerrain.MARGIN) / FonsTerrain.STEP))
	var rows := int(ceil((28.0 + 2.0 * FonsTerrain.MARGIN) / FonsTerrain.STEP))
	assert_eq(mesh.get_surface_count(), 1, "지면은 한 표면")
	assert_eq(vertices.size(), (cols + 1) * (rows + 1), "경계에 복제된 정점이 없다")
	assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), cols * rows * 6, "칸마다 삼각형 2장")


func test_height_is_the_meshes_height() -> void:
	## 메시 y 와 height_at 이 갈라지면 유닛이 땅에 뜨거나 박힌다 — 같은 함수를 부른다.
	var terrain := FonsTerrain.new(Vector2(12, 8), 5, 1.0)
	var arrays := terrain.build(Color(0.2, 0.3, 0.1)).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in [0, 13, 50, vertices.size() - 1]:
		var point := vertices[index]
		assert_almost_eq(point.y, terrain.height_at(point.x, point.z), 0.0001)


func test_same_seed_same_terrain() -> void:
	var a := FonsTerrain.new(Vector2(40, 28), 9, 1.0)
	var b := FonsTerrain.new(Vector2(40, 28), 9, 1.0)
	var c := FonsTerrain.new(Vector2(40, 28), 10, 1.0)
	assert_almost_eq(a.height_at(11.0, 7.0), b.height_at(11.0, 7.0), 0.0001, "같은 시드는 같은 땅")
	assert_ne(a.height_at(11.0, 7.0), c.height_at(11.0, 7.0), "시드가 다르면 다른 땅")


func test_relief_is_bounded_and_visible() -> void:
	## 진폭은 relief 를 넘지 않고, 0 이면 예전처럼 평평하다.
	var terrain := FonsTerrain.new(Vector2(40, 28), 3, 1.0)
	var low := 0.0
	var high := 0.0
	for i in 41:
		for j in 29:
			var h := terrain.height_at(i * 1.0, j * 1.0)
			low = minf(low, h)
			high = maxf(high, h)
	assert_lte(absf(low), 1.1, "진폭이 relief 를 넘지 않는다")
	assert_lte(absf(high), 1.1)
	assert_gt(high - low, 0.5, "들쭉날쭉함이 보인다 — 평평한 판이 아니다")
	var flat := FonsTerrain.new(Vector2(40, 28), 3, 0.0)
	assert_almost_eq(flat.height_at(20.0, 14.0), 0.0, 0.0001, "relief 0 은 평면")


func test_colors_follow_height_and_slope() -> void:
	## 한 색으로 칠하면 기복이 안 읽힌다 — 정점색이 높이·경사로 갈라져야 한다.
	var mesh := _mesh()
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var distinct := {}
	for color in colors:
		distinct[color.to_html(false)] = true
	assert_gt(distinct.size(), 8, "한 색이 아니다")


func test_normals_point_out_of_the_ground() -> void:
	## 법선이 뒤집히면 지면이 새까맣거나 안 보인다.
	var normals: PackedVector3Array = _mesh().surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for normal in [normals[0], normals[normals.size() / 2], normals[normals.size() - 1]]:
		assert_gt(normal.y, 0.5, "위를 향한다")


func test_contacts_are_flat_within_the_radius() -> void:
	## 조우 원기둥·유닛이 경사에 뜨지 않게 반경 3유닛은 한 높이다.
	var terrain := FonsTerrain.new(Vector2(40, 28), 7, 1.35, [Vector2(12, 9)])
	var level := terrain.height_at(12.0, 9.0)
	for offset in [Vector2(2.9, 0), Vector2(-2.9, 0), Vector2(0, 2.9), Vector2(2.0, 2.0), Vector2(-1.5, -2.0)]:
		var point: Vector2 = Vector2(12, 9) + offset
		assert_almost_eq(terrain.height_at(point.x, point.y), level, 0.0001,
			"반경 안 %s 는 같은 높이" % str(offset))


func test_flattening_fades_back_into_the_hills() -> void:
	## 반경 밖은 원래 지형 그대로다 — 평탄면이 지형을 삼키면 안 된다.
	var point := Vector2(12, 9)
	var flat := FonsTerrain.new(Vector2(40, 28), 7, 1.35, [point])
	var raw := FonsTerrain.new(Vector2(40, 28), 7, 1.35)
	var far := point + Vector2(FonsTerrain.FLAT_RADIUS + FonsTerrain.FLAT_FEATHER + 0.5, 0)
	assert_almost_eq(flat.height_at(far.x, far.y), raw.height_at(far.x, far.y), 0.0001,
		"이음매 밖은 손대지 않는다")
	# 이음매 폭 어딘가에서는 두 값 사이여야 한다 — 계단이 아니라 경사로 잇는다.
	var edge := point + Vector2(FonsTerrain.FLAT_RADIUS + 1.0, 0)
	var blended := flat.height_at(edge.x, edge.y)
	var before := raw.height_at(edge.x, edge.y)
	assert_ne(blended, before, "이음매에는 섞인 값이 있다")
	assert_ne(blended, flat.height_at(point.x, point.y), "아직 완전히 평탄하지도 않다")


func test_no_contacts_means_no_flat_plateau() -> void:
	var plain := FonsTerrain.new(Vector2(40, 28), 7, 1.35)
	var with_flat := FonsTerrain.new(Vector2(40, 28), 7, 1.35, [Vector2(12, 9)])
	assert_almost_eq(plain.height_at(12.0, 9.0), with_flat._raw_height(12.0, 9.0), 0.0001,
		"빈 목록이면 높이 함수가 원래대로다")


func test_rock_tint_reaches_steep_vertices() -> void:
	## 가파른 곳만 암석 틴트를 받는다 — 경사 축이 없으면 절벽도 잔디로 보인다.
	## 어느 정점이 경사인지는 지형이 정하므로, 틴트를 준 메시와 안 준 메시를 비교한다.
	var terrain := FonsTerrain.new(Vector2(40, 28), 21, 1.0)
	var base := Color(0.24, 0.32, 0.12)
	var plain: PackedColorArray = terrain.build(base).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var rocky: PackedColorArray = terrain.build(base,
		{"rock": Color(0.45, 0.50, 0.62)}).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var changed := 0
	for i in plain.size():
		if plain[i] != rocky[i]:
			changed += 1
	assert_gt(changed, 0, "암석 틴트가 닿는 경사 정점이 있다")
	assert_lt(changed, plain.size(), "평지까지 돌로 칠하지 않는다 — 경사 축은 좁다")
