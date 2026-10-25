extends GutTest
## 3D 뷰 골격 — 2D 와 같은 계약(mount/apply/unmount, intent)을 지키는지 잠근다.
## 트리에 붙이지 않아도 스냅샷을 받아 엔티티를 만들 수 있어야 한다(헤드리스 테스트 경로).


func _entity(id: String, kind: String, pos: Vector3) -> Dictionary:
	return {"id": id, "kind": kind, "pos": pos, "size": Vector2.ONE}


func test_mount_tracks_entities() -> void:
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("hero:1", "hero", Vector3(1, 0, 2)),
		_entity("site:0", "site", Vector3(10, 0, 14)),
	]})
	assert_eq(view.entity_count(), 2)
	assert_true(view.is_mounted())
	assert_true(view.has_entity("hero:1"))
	assert_eq(view.entity_position("hero:1"), Vector3(1, 0, 2), "심 좌표를 그대로 3D 월드에 놓는다")
	view.free()


func test_apply_replaces_whole_set() -> void:
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("hero:1", "hero", Vector3.ZERO),
		_entity("site:0", "site", Vector3(10, 0, 14)),
	]})
	view.apply({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("hero:1", "hero", Vector3(2, 0, 0)),
	]})
	assert_eq(view.entity_count(), 1)
	assert_false(view.has_entity("site:0"), "사라진 id 는 화면에서도 빠진다")
	assert_eq(view.entity_position("hero:1"), Vector3(2, 0, 0))
	view.free()


func test_unmount_clears() -> void:
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("hero:1", "hero", Vector3.ZERO),
	]})
	view.unmount()
	assert_eq(view.entity_count(), 0)
	assert_false(view.is_mounted())
	view.free()


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func test_field_keys_emit_the_same_intents_as_2d() -> void:
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	var got: Array = []
	view.intent.connect(func(kind, payload): got.append([kind, payload]))
	view._unhandled_input(_key(KEY_SPACE))
	view._unhandled_input(_key(KEY_R))
	view._unhandled_input(_key(KEY_3))
	view._unhandled_input(_key(KEY_9))
	assert_eq(got.size(), 3, "스페이스·R·1~5 만 의도가 된다")
	assert_eq(got[0][0], &"interact")
	assert_eq(got[1][0], &"retreat")
	assert_eq(got[2][0], &"switch_hero")
	assert_eq(int(got[2][1]["index"]), 2, "3번 키 = 0부터 센 2")
	view._unhandled_input(_key(KEY_C))
	assert_eq(got[3][0], &"edict", "C = 칙령 (04 §3.7) — 2D 와 같다")
	view.free()


func test_snapshot_without_field_is_not_drawn_as_a_field() -> void:
	var view := FonsView3D.new()
	view.mount({"entities": [_entity("hero:1", "hero", Vector3.ZERO)]})
	assert_false(view.is_field(), "field 크기가 없는 스냅샷은 전투 화면이다")
	view.free()


## ── 에셋 키 → 메시 (R3) ─────────────────────────────────────────────────

func test_registered_asset_wins_over_the_kind_shape() -> void:
	# 에셋 키는 `hero:knight` 처럼 문자열이다. 자산이 생기면 그 키에 메시를 걸고,
	# 걸린 메시가 있으면 종류별 기본 도형 대신 그것을 쓴다.
	var view := FonsView3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	view.register_asset("hero:knight", mesh)
	var hero := _entity("hero:1", "hero", Vector3.ZERO)
	hero["asset"] = "hero:knight"
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [hero]})
	assert_eq(view.entity_mesh("hero:1"), mesh, "등록한 메시를 쓴다")
	view.free()


func test_unregistered_asset_falls_back_to_the_kind_shape() -> void:
	# 아직 자산이 없는 키는 조용히 사라지지 않고 종류별 도형으로 그린다.
	var view := FonsView3D.new()
	var monster := _entity("monster:1", "monster", Vector3.ZERO)
	monster["asset"] = "monster:slime"
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [monster]})
	var mesh: Mesh = view.entity_mesh("monster:1")
	assert_not_null(mesh, "등록이 없어도 메시는 있다")
	assert_true(mesh is CylinderMesh, "몬스터는 뾰족한 도형으로 폴백한다")
	assert_almost_eq((mesh as CylinderMesh).top_radius, 0.0, 0.001, "= 원뿔")
	assert_null(view.entity_mesh("site:9"), "없는 id 는 null")
	view.free()


func test_different_kinds_get_different_fallback_shapes() -> void:
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("hero:1", "hero", Vector3(0, 0, 0)),
		_entity("site:0", "site", Vector3(4, 0, 0)),
		_entity("avatar", "avatar", Vector3(8, 0, 0)),
	]})
	assert_ne(view.entity_mesh("hero:1").get_class(), view.entity_mesh("site:0").get_class(),
		"동료와 조우는 한눈에 구분된다")
	assert_false(view.bar_entity_ids().has("site:0"), "조우에는 HP 바가 없다")
	view.free()


func test_heroes_with_different_assets_get_different_colors() -> void:
	# 다섯이 같은 상자·같은 파랑이면 누가 누군지 모른다. 키가 다르면 색도 달라야 한다.
	var view := FonsView3D.new()
	var a := _entity("hero:1", "hero", Vector3.ZERO)
	a["asset"] = "hero:knight"
	var b := _entity("hero:2", "hero", Vector3(2, 0, 0))
	b["asset"] = "hero:mage"
	var c := _entity("hero:3", "hero", Vector3(4, 0, 0))
	c["asset"] = "hero:knight"
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [a, b, c]})
	assert_ne(view.entity_color("hero:1"), view.entity_color("hero:2"), "키가 다르면 색이 다르다")
	assert_eq(view.entity_color("hero:1"), view.entity_color("hero:3"), "같은 키는 같은 색 — 실행마다 흔들리지 않는다")
	assert_ne(view.entity_color("hero:1"), FonsView3D.AVATAR_COLOR, "조종 표시(초록 캡슐)와 섞이지 않는다")
	view.free()


func test_five_heroes_get_five_spaced_hues() -> void:
	# 키 해시로 색을 뽑으면 두 키가 같은 색에 떨어졌다 — 자리로 나누면 반드시 벌어진다.
	var hues: Array = []
	for i in 5:
		hues.append(FonsView3D.slot_hue(i, 5))
	for i in 5:
		for j in range(i + 1, 5):
			assert_gt(absf(float(hues[j]) - float(hues[i])), 0.05,
				"%d번과 %d번이 구분되는 색" % [i, j])
		assert_gte(float(hues[i]), FonsView3D.HERO_HUE_FROM)
		assert_lte(float(hues[i]), FonsView3D.HERO_HUE_TO)
	assert_eq(FonsView3D.slot_hue(0, 1), FonsView3D.HERO_HUE_FROM, "혼자여도 색역 안")


func test_hero_without_an_asset_keeps_the_hero_color() -> void:
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("hero:1", "hero", Vector3.ZERO),
	]})
	assert_eq(view.entity_color("hero:1"), FonsView3D.HERO_COLOR, "키가 없으면 예전 색 그대로")
	view.free()


func test_snapshot_names_the_biome_and_kit() -> void:
	## 뷰는 데이터를 읽지 않는다 — 어느 세계인지는 스냅샷이 알려 준다 (계획서 §5).
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"biome": "biome_plains", "kit": "topo_natural_surface"})
	assert_eq(view.current_biome(), "biome_plains")
	assert_eq(view.current_kit(), "topo_natural_surface")
	view.free()


func _palette(ground: Color) -> Dictionary:
	return {
		"sky": Color(0.02, 0.03, 0.05),
		"ground": ground,
		"ambient": Color(0.60, 0.55, 0.50),
		"light": Color(1.0, 0.90, 0.80),
		"energy": 1.7,
	}


func test_palette_repaints_ground_sky_and_light() -> void:
	## 지면·조명은 바이옴 파생색이다. 뷰는 색을 계산하지 않고 심이 준 값을 칠한다.
	var view := FonsView3D.new()
	var ground := Color(0.31, 0.22, 0.14)
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"biome": "biome_desert", "palette": _palette(ground)})
	assert_eq(view.ground_color(), ground, "지면이 바이옴 색이다")
	assert_eq(view.sky_color(), Color(0.02, 0.03, 0.05))
	assert_eq(view.light_color(), Color(1.0, 0.90, 0.80))
	assert_almost_eq(view.light_energy(), 1.7, 0.001)
	view.free()


func test_missing_palette_keeps_the_default_look() -> void:
	## 전투 화면·헤드리스 테스트처럼 바이옴이 없는 스냅샷은 지금 모습 그대로다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	assert_eq(view.ground_color(), FonsView3D.GROUND)
	assert_eq(view.sky_color(), FonsView3D.FIELD_BG)
	assert_almost_eq(view.light_energy(), 1.1, 0.001)
	view.free()


func _prop_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "Prop"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	mesh.owner = root  # pack 은 owner 가 있는 노드만 담는다
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_packed_scene_asset_is_instantiated_under_the_entity() -> void:
	## `.glb` 는 PackedScene 으로 임포트된다 — 메시 하나 계약으로는 프롭을 못 받는다.
	var view := FonsView3D.new()
	view.register_asset("prop:camp", _prop_scene())
	var camp := _entity("prop:0", "site", Vector3(3, 0, 4))
	camp["asset"] = "prop:camp"
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [camp]})
	var instance := view.entity_asset_node("prop:0")
	assert_not_null(instance, "등록한 씬이 엔티티 아래에 붙는다")
	assert_eq(instance.get_child_count(), 1, "씬 안의 메시까지 따라온다")
	assert_null(view.entity_mesh("prop:0"), "폴백 도형은 그리지 않는다")
	assert_eq(view.entity_position("prop:0"), Vector3(3, 0, 4), "자리는 스냅샷을 따른다")
	view.free()


func test_mesh_registration_still_works_after_the_scene_extension() -> void:
	var view := FonsView3D.new()
	var mesh := BoxMesh.new()
	view.register_asset("hero:knight", mesh)
	var hero := _entity("hero:1", "hero", Vector3.ZERO)
	hero["asset"] = "hero:knight"
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [hero]})
	assert_eq(view.entity_mesh("hero:1"), mesh)
	assert_null(view.entity_asset_node("hero:1"), "메시 자산에는 씬 노드가 없다")
	view.free()


func _kit_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "Kit"
	for name in ["ground_a", "prop_bush", "landmark_tree"]:
		var part := Node3D.new()
		part.name = name
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		part.add_child(mesh)
		root.add_child(part)
		part.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_registered_kit_fills_the_field() -> void:
	## 키트는 스냅샷의 `kit` 문자열을 보고 뷰가 직접 깐다 — 심은 노드를 모른다.
	var view := FonsView3D.new()
	view.register_kit("test_kit", _kit_scene())
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [], "kit": "test_kit"})
	# 지면 타일은 지형이 맡는다 — 키트는 프롭 + 랜드마크만.
	assert_eq(view.kit_module_count(), FonsBiomeKit.PROP_COUNT + 1, "프롭 + 랜드마크")
	view.free()


func test_pilot_kit_is_laid_into_the_field() -> void:
	## 실제 파일(`res://assets/art/models/topo_natural_surface.glb`)이 배치까지 가는가.
	## 부품 11 = 바닥 4 · 높이 2 · 랜드마크 1 · 프롭 4 → 타일 48 + 높이 2 + 랜드마크 1 + 프롭 12.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"biome": "biome_plains", "kit": "topo_natural_surface"})
	assert_not_null(view.loaded_kit("topo_natural_surface"), "파일럿 키트가 임포트되어 있다")
	assert_eq(view.kit_module_count(), 2 + 1 + FonsBiomeKit.PROP_COUNT, "높이 2 + 랜드마크 1 + 프롭")
	view.free()


func test_field_gets_a_heightfield_and_units_stand_on_it() -> void:
	## 격자는 타일마다 따로 구운 법선에서 나왔다 — 지면은 한 장의 높이필드다.
	## 심 좌표는 평면(y=0)이고, 화면만 지형 높이만큼 들어 올린다.
	var view := FonsView3D.new()
	var palette := FonsBiomePalette.from_biome({"climate": {"ambient": 15}, "category": "calm"})
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("hero:1", "hero", Vector3(20, 0, 14)),
	], "palette": palette})
	var mesh := view.terrain_mesh()
	assert_not_null(mesh, "필드에는 높이필드가 깔린다")
	assert_eq(mesh.get_surface_count(), 1, "타일이 아니라 한 표면")
	var node: Node3D = view._nodes["hero:1"]
	assert_almost_eq(node.position.y, view.terrain_height(20.0, 14.0), 0.001, "발이 땅에 닿는다")
	assert_eq(view.entity_position("hero:1"), Vector3(20, 0, 14), "심 좌표는 그대로 평면")
	view.free()


func test_camera_is_a_follow_cam_behind_the_avatar() -> void:
	## 원신·엔드필드식 3인칭 — 정사영 내려보기가 아니라 **캐릭터 뒤의 원근 카메라**.
	## 수치의 출처는 우리 구도 결정이다 (두 게임 다 FOV·거리·기울기를 공개하지 않는다).
	## [ART_BIBLE](../../docs/art/ART_BIBLE.md) 카메라 절 참조.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]})
	var camera: Camera3D = view._camera
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE, "원근 카메라")
	assert_almost_eq(camera.fov, FonsView3D.CAMERA_FOV, 0.01)
	var focus: Vector3 = view.camera_focus()
	assert_almost_eq(camera.position.distance_to(focus), FonsView3D.CAMERA_DISTANCE, 0.05,
		"기본 거리만큼 뒤에 선다")
	assert_gt(camera.position.y, focus.y, "캐릭터보다 높다")
	assert_gt(camera.position.z, focus.z, "필드 앞쪽(-z)을 보도록 뒤(+z)에 선다")
	# 캐릭터를 화면 아래 3분의 1에 두려면 시선을 캐릭터보다 위에 둔다.
	var forward := -camera.transform.basis.z
	var aim := (focus + Vector3.UP * FonsView3D.CAMERA_AIM_LIFT - camera.position).normalized()
	assert_gt(forward.dot(aim), 0.999, "카메라가 캐릭터 머리 위쪽을 본다")
	view.free()


func test_orbit_and_zoom_are_clamped() -> void:
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]})
	view.orbit(0.0, 10.0)
	assert_almost_eq(rad_to_deg(view.camera_pitch()), FonsView3D.CAMERA_PITCH_MAX, 0.01,
		"위로 돌려도 상한에서 멈춘다")
	view.orbit(0.0, -10.0)
	assert_almost_eq(rad_to_deg(view.camera_pitch()), FonsView3D.CAMERA_PITCH_MIN, 0.01,
		"아래로 돌려도 하한에서 멈춘다")
	view.zoom(-100.0)
	assert_almost_eq(view.camera_distance(), FonsView3D.CAMERA_DISTANCE_MAX, 0.01, "멀리 당겨도 상한")
	view.zoom(100.0)
	assert_almost_eq(view.camera_distance(), FonsView3D.CAMERA_DISTANCE_MIN, 0.01, "가까이 당겨도 하한")
	# 휠은 실제 입력 경로로도 같은 값만 움직인다 (오른쪽 드래그는 실제 마우스 상태가 필요해 직접 호출로 잠근다).
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	var before: float = view.camera_distance()
	view._unhandled_input(wheel)
	assert_gt(view.camera_distance(), before, "휠 아래 = 멀리")
	view.free()


func test_movement_follows_the_camera_yaw() -> void:
	## 3인칭 게임의 W 는 화면 위쪽이다 — 카메라를 돌리면 걷는 방향도 같이 돈다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]})
	assert_eq(view.camera_relative(Vector2(0, -1)), Vector2(0, -1), "정면 카메라에서 W 는 필드 앞")
	view.orbit(PI * 0.5, 0.0)
	var west := view.camera_relative(Vector2(0, -1))
	assert_almost_eq(west.x, -1.0, 0.01, "카메라를 오른쪽으로 돌리면 W 는 서쪽")
	assert_almost_eq(west.y, 0.0, 0.01)
	view.free()


func test_contact_ground_is_flat_under_the_site() -> void:
	## 조우 원기둥이 경사에 뜨면 지형이 아니라 오브젝트가 붕 뜬 것으로 읽힌다.
	var view := FonsView3D.new()
	var palette := FonsBiomePalette.from_biome({"climate": {"ambient": 15}, "category": "extreme"})
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("site:0", "site", Vector3(12, 0, 9)),
	], "palette": palette})
	var level := view.terrain_height(12.0, 9.0)
	for offset in [Vector2(2.9, 0), Vector2(0, -2.9), Vector2(1.5, 2.0)]:
		assert_almost_eq(view.terrain_height(12.0 + offset.x, 9.0 + offset.y), level, 0.001,
			"조우 반경 안은 평평하다 %s" % str(offset))
	assert_ne(view.terrain_height(30.0, 20.0), level + 100.0, "멀리도 산다")
	view.free()


func test_moving_a_contact_rebuilds_the_terrain() -> void:
	## 조우가 지워지거나 자리가 바뀌면 평탄면도 따라가야 한다.
	var view := FonsView3D.new()
	var palette := FonsBiomePalette.from_biome({"climate": {"ambient": 15}, "category": "extreme"})
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("site:0", "site", Vector3(12, 0, 9)),
	], "palette": palette})
	var first := view.terrain_mesh()
	view.apply({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("site:0", "site", Vector3(28, 0, 21)),
	], "palette": palette})
	assert_ne(view.terrain_mesh(), first, "조우가 움직이면 지형을 다시 뜬다")
	var level := view.terrain_height(28.0, 21.0)
	assert_almost_eq(view.terrain_height(28.0, 18.1), level, 0.001, "새 자리도 평평하다")
	view.free()


func test_first_floor_plains_gets_gentle_relief() -> void:
	## 풀바다(평온)는 완만해야 한다 — 걷는 필드가 산이 되면 안 된다.
	var calm := FonsBiomePalette.from_biome({"climate": {"ambient": 15}, "category": "calm"})
	var extreme := FonsBiomePalette.from_biome({"climate": {"ambient": 40}, "category": "extreme"})
	assert_between(float(calm["relief"]), 0.8, 1.4, "풀바다 진폭은 계획 §11 의 0.8~1.4 유닛 안")
	assert_gt(float(extreme["relief"]), float(calm["relief"]), "극한 바이옴이 더 험하다")


func _biome_palette(ambient: float, category: String) -> Dictionary:
	return FonsBiomePalette.from_biome({"climate": {"ambient": ambient}, "category": category})


func _field_with(view: FonsView3D, biome: String, palette: Dictionary) -> void:
	view.apply({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"kit": "test_kit", "biome": biome, "palette": palette})


func test_same_kit_is_retinted_when_the_biome_changes() -> void:
	## 뿌리숲 → 포식밀림은 둘 다 topo_natural_surface 다. 키트를 새로 만들지 않고도
	## 화면이 갈라져야 한다 — 색은 메시에 곱해져 있으니 바이옴이 바뀌면 다시 깔아야 한다.
	var view := FonsView3D.new()
	view.register_kit("test_kit", _kit_scene())
	var forest := _biome_palette(12.0, "calm")
	var jungle := _biome_palette(27.0, "chaos")
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"kit": "test_kit", "biome": "biome_forest", "palette": forest})
	assert_eq(view.current_kit_tints(), forest["tints"], "스냅샷 팔레트의 역할별 틴트를 쓴다")
	var laid: Node = view._kit_root
	_field_with(view, "biome_forest", forest)
	assert_eq(view._kit_root, laid, "같은 바이옴이면 다시 깔지 않는다")
	_field_with(view, "biome_jungle", jungle)
	assert_eq(view.current_kit_tints(), jungle["tints"], "바이옴이 바뀌면 다시 곱한다")
	assert_ne(view._kit_root, laid, "키트는 새로 깐다")
	assert_gt(view.kit_module_count(), 0, "다시 깔아도 부품은 그대로 있다")
	view.free()


func test_kit_parts_are_grounded_on_the_terrain() -> void:
	## 키트 프롭은 발자국에서 가장 낮은 땅에 앉는다 — 중심 높이만 보면 경사에서 뜬다.
	var view := FonsView3D.new()
	view.register_kit("test_kit", _kit_scene())
	var palette := FonsBiomePalette.from_biome({"climate": {"ambient": 40}, "category": "extreme"})
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"kit": "test_kit", "palette": palette})
	assert_gt(view.kit_module_count(), 0)
	for child in view._kit_root.get_children():
		var ground := view.terrain_height(child.position.x, child.position.z)
		assert_lte(child.position.y, ground + 0.001, "%s 가 땅에 닿는다" % child.name)
		assert_gte(child.position.y, ground - 1.5, "%s 가 땅속에 묻히지 않는다" % child.name)
	view.free()


func test_kit_without_a_palette_is_not_tinted() -> void:
	## 전투 화면·헤드리스 테스트처럼 바이옴이 없는 필드는 지금 모습 그대로다.
	var view := FonsView3D.new()
	view.register_kit("test_kit", _kit_scene())
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [], "kit": "test_kit"})
	assert_eq(view.current_kit_tints(), {}, "바이옴이 없으면 틴트도 없다")
	view.free()


func test_unknown_kit_is_not_fatal() -> void:
	## 아직 자산이 없는 키트(파일럿 전 8종)는 조용히 빈 필드로 둔다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [], "kit": "topo_not_built"})
	assert_eq(view.kit_module_count(), 0)
	assert_true(view.is_mounted())
	view.free()


func test_unmount_clears_the_kit() -> void:
	var view := FonsView3D.new()
	view.register_kit("test_kit", _kit_scene())
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [], "kit": "test_kit"})
	assert_gt(view.kit_module_count(), 0)
	view.unmount()
	assert_eq(view.kit_module_count(), 0)
	view.free()


func test_hp_bars_cover_heroes_but_not_the_avatar() -> void:
	# 2D 와 같은 정보: 동료 HP 바는 필드에, 조종 영웅 HP 는 오른쪽 파티 칸에 있다.
	var view := FonsView3D.new()
	var hero := _entity("hero:1", "hero", Vector3.ZERO)
	hero["hp"] = 40
	hero["max_hp"] = 100
	var avatar := _entity("avatar", "avatar", Vector3(1, 0, 0))
	avatar["hp"] = 90
	avatar["max_hp"] = 100
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [hero, avatar]})
	assert_eq(view.bar_entity_ids(), ["hero:1"], "바를 가진 엔티티만 그린다")
	view.apply({"mode": "field", "field": Vector2(40, 28), "entities": []})
	assert_eq(view.bar_entity_ids(), [], "스냅샷에서 빠지면 바도 사라진다")
	view.free()


func test_strike_snapshot_spawns_one_short_effect_at_the_site() -> void:
	## 교전은 한 프레임에 끝난다 — 뷰는 `strike.seq` 가 늘어난 순간에만 그 자리에 짧은 연출을 낸다.
	var view := FonsView3D.new()
	var snapshot := {"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("site:0", "site", Vector3(10, 0, 14)),
	]}
	view.mount(snapshot)
	assert_eq(view.strike_fx_count(), 0, "교전 전에는 연출이 없다")
	snapshot["strike"] = {"seq": 1, "site": 0, "damage": 37}
	view.apply(snapshot)
	assert_eq(view.strike_fx_count(), 1, "교전 한 번에 하나")
	view.apply(snapshot)
	assert_eq(view.strike_fx_count(), 1, "같은 seq 를 다시 받아도 한 번뿐")
	snapshot["strike"] = {"seq": 2, "site": 0, "damage": 12}
	view.apply(snapshot)
	assert_eq(view.strike_fx_count(), 2, "다음 교전은 다시 보여 준다")
	view.free()


func test_camera_boom_stops_before_a_tree() -> void:
	## 카메라가 나무를 뚫고 캐노피 속으로 들어가면 화면이 초록 덩어리가 된다.
	## 지형처럼 프롭에도 콜라이더가 없으므로, 키트가 알려 준 원통으로 붐을 앞에서 끊는다.
	var view := FonsView3D.new()
	var focus := Vector3(0.0, 0.6, 0.0)
	var dir := Vector3(0.0, 1.2, 4.2).normalized()
	var tree := {"pos": Vector3(0.0, 0.0, 3.0), "radius": 0.6, "top": 4.0}
	var free: float = view.camera_free_distance(focus, dir, 4.2, [tree])
	assert_lt(free, 3.0, "나무 앞에서 붐이 멈춘다")
	assert_gt(free, 1.8, "캐릭터 등 뒤까지 접지는 않는다")
	assert_almost_eq(view.camera_free_distance(focus, dir, 4.2, []), 4.2, 0.001, "가림이 없으면 그대로")
	# 낮은 바위는 카메라가 지나가는 높이를 막지 않는다.
	var rock := {"pos": Vector3(0.0, 0.0, 3.0), "radius": 0.8, "top": 0.7}
	assert_almost_eq(view.camera_free_distance(focus, dir, 4.2, [rock]), 4.2, 0.001,
		"무릎 높이 바위는 시야를 안 막는다")
	# 캐릭터가 나무 밑에 서 있으면 붐을 0으로 만들지 않는다 — 화면이 얼굴로 꽉 찬다.
	var under := {"pos": Vector3(0.3, 0.0, 0.2), "radius": 0.6, "top": 4.0}
	assert_almost_eq(view.camera_free_distance(focus, dir, 4.2, [under]), 4.2, 0.001,
		"나무 밑에 서 있어도 붐은 유지된다")
	view.free()


func test_camera_clamps_against_the_trunk_under_the_canopy() -> void:
	## 잎 원통 안에 캐릭터가 서 있어도 줄기 원통은 살아 있어야 한다.
	## 하나로 묶으면 "나무 밑" 판정에 걸려 카메라가 줄기를 뚫고 들어간다.
	var view := FonsView3D.new()
	var focus := Vector3(0.0, 0.6, 0.0)
	var dir := Vector3(0.0, 1.2, 4.2).normalized()
	var tree := {"pos": Vector3(0.0, 0.0, 1.3), "radius": 0.22, "top": 3.2}
	var canopy := {"pos": Vector3(0.0, 0.0, 1.3), "radius": 1.81, "top": 6.0}
	var free: float = view.camera_free_distance(focus, dir, 4.2, [tree, canopy])
	assert_lt(free, 1.3, "줄기 앞에서 붐이 멈춘다")
	assert_gt(free, 0.0, "붐을 0으로 만들지는 않는다")
	view.free()


func test_camera_boom_clamps_in_the_field_without_colliders() -> void:
	## 배선 확인 — 키트가 준 가림 목록이 `_place_camera` 의 붐 길이에 실제로 닿는다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]})
	view._yaw = 0.0
	view._blockers = [{"pos": Vector3(20.0, 0.0, 17.0), "radius": 0.9, "top": 4.0}]
	view._place_camera()
	var focus: Vector3 = view.camera_focus()
	var away: float = view._camera.position.distance_to(focus)
	assert_lt(away, 3.0, "나무 앞에서 붐이 접힌다")
	assert_gt(away, 1.5, "캐릭터 등 뒤까지 접지는 않는다")
	view.free()


func test_avatar_fades_when_the_camera_is_forced_close() -> void:
	## 카메라가 등에 붙으면 캐릭터가 화면을 덮는다 — 가까울수록 흐려야 나무를 피한 게 보인다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]})
	view._fade_avatar(FonsView3D.CAMERA_AVATAR_FADE_FAR)
	assert_almost_eq(view.avatar_transparency(), 0.0, 0.001, "멀면 불투명")
	view._fade_avatar(FonsView3D.CAMERA_AVATAR_FADE_NEAR)
	assert_almost_eq(view.avatar_transparency(), 1.0, 0.001, "붙으면 투명")
	var mid: float = (FonsView3D.CAMERA_AVATAR_FADE_FAR + FonsView3D.CAMERA_AVATAR_FADE_NEAR) * 0.5
	view._fade_avatar(mid)
	assert_almost_eq(view.avatar_transparency(), 0.5, 0.01, "사이는 반투명")
	view.free()
