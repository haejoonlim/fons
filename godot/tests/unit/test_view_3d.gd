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
	view._unhandled_input(_key(KEY_F))
	view._unhandled_input(_key(KEY_R))
	view._unhandled_input(_key(KEY_3))
	view._unhandled_input(_key(KEY_9))
	assert_eq(got.size(), 3, "F·R·1~5 만 의도가 된다")
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
	## 부품 11 = 바닥 4 · 높이 2 · 랜드마크 1 · 프롭 4 → 지형은 높이필드가 맡고,
	## 키트는 높이 2 + 랜드마크 1 + 바이옴 프롭 계획(풀바다 20)을 깐다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"biome": "biome_plains", "kit": "topo_natural_surface"})
	assert_not_null(view.loaded_kit("topo_natural_surface"), "파일럿 키트가 임포트되어 있다")
	# 프롭 수는 바이옴 계획이 정한다 (S4) — 상수 24 가 아니라 `biome_plains` 의 배분이다.
	var plan := FonsBiomeKit.plan("biome_plains")
	var planned := 0
	for part in plan:
		planned += int(plan[part])
	assert_gt(planned, 0, "풀바다에 프롭 계획이 있다")
	assert_eq(view.kit_module_count(), 2 + 1 + planned, "높이 2 + 랜드마크 1 + 프롭 계획")
	view.free()


func test_the_kit_keeps_off_the_tower_plaza() -> void:
	## 시작 자리(탑 앞 광장)에 랜드마크가 서면 시작하자마자 카메라가 바위에 막힌다.
	## 뷰가 광장을 키트에 알려 주는지 — 안 알려주면 키트는 소환진 위에 봉우리를 세운다.
	## 2026-10-28 실측(동굴 청크 0,0): 랜드마크 중심이 시작 자리에서 2.54유닛 ·
	## 카메라 24방향 중 16방향 붐 접힘. 광장 반경 = 소환진 고리 + 카메라 기본 거리.
	var view := FonsView3D.new()
	var tower := {"pos": Vector3(20, 0, 14), "radius": 3.4, "body": 1.2}
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 16.6)),
	], "biome": "biome_cave", "kit": "topo_rock_cavern_mountain", "tower": tower})
	var keep := 3.4 + FonsView3D.CAMERA_DISTANCE
	var checked := 0
	for root in view._kit_root.get_children():
		for child in root.get_children():
			var part := String(child.get_meta("kit_part", ""))
			if not (part.begins_with("landmark_") or part.begins_with("prop_")):
				continue
			var flat := Vector2((child as Node3D).position.x, (child as Node3D).position.z)
			var away := flat.distance_to(Vector2(20.0, 14.0))
			assert_gte(away, keep - 0.01, "%s 가 광장 밖에 선다 (%.2f)" % [part, away])
			checked += 1
	assert_gt(checked, 0, "랜드마크·프롭이 깔려야 검사가 의미 있다")
	view.free()


func test_every_biome_keeps_the_camera_open_at_the_start_spot() -> void:
	## 26바이옴 × 24방향 — 시작 자리에서 카메라를 어느 쪽으로 돌려도 붐이 접히지 않고,
	## 프롭도 시작 자리 앞에 서지 않는다. 둘은 같은 규칙의 앞뒤다: 탑 가림 원통 때문에 시작
	## 자리가 멀어졌고(`FonsExplore.SPAWN`), 그 자리도 뷰가 광장으로 넘긴다(`_kit_clear`).
	##
	## 2026-10-28 실측(고치기 전 · 탑 몸통 앞 2.6): 624방향 중 182방향이 접혔고 130방향은
	## 붐이 1.1 미만이라 조종 영웅이 화면에서 사라졌다. 키트 몫은 0 — 전부 탑 가림 원통이었다.
	## 시작 자리만 옮기고 광장을 안 넓히면 반대가 된다(6.4 에서 키트 몫 5방향 · 7.0 에서 4방향).
	##
	## 좌표는 **월드**다 — 심이 청크 목록을 주면 뷰는 청크 로컬에 부품을 두고 뿌리만 옮긴다.
	var world := Vector3(-20.0, 0.0, -14.0)   # 청크 (0,0) 의 남서 모서리 = 진짜 월드 원점
	var collapsed := 0
	var hidden := 0
	var close := 0
	var parts := 0
	var worst := INF
	var at := ""
	var nearest := INF
	for biome in _biomes():
		var view := FonsView3D.new()
		view.mount({"mode": "field", "field": Vector2(40, 28), "chunks": [world], "entities": [
			_entity("avatar", "avatar", Vector3(FonsExplore.SPAWN.x, 0.0, FonsExplore.SPAWN.y)),
		], "biome": String(biome.get("id", "")), "kit": String(biome.get("topologyKit", "")),
			"palette": FonsBiomePalette.from_biome(biome),
			"tower": {"pos": Vector3.ZERO, "radius": 3.4, "body": 1.2}})
		for root in view._kit_root.get_children():
			for child in root.get_children():
				var part := String(child.get_meta("kit_part", ""))
				if not (part.begins_with("landmark_") or part.begins_with("prop_")):
					continue
				var local: Vector3 = (root as Node3D).position + (child as Node3D).position
				var away := Vector2(local.x, local.z).distance_to(FonsExplore.SPAWN)
				parts += 1
				if away < nearest:
					nearest = away
				if away < FonsView3D.CAMERA_DISTANCE - 0.01:
					close += 1
		var focus: Vector3 = view.camera_focus()
		var pitch := deg_to_rad(FonsView3D.CAMERA_PITCH_DEFAULT)
		for i in 24:
			var yaw := TAU * float(i) / 24.0
			var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
			var boom: float = view.camera_free_distance(focus, dir, FonsView3D.CAMERA_DISTANCE)
			if boom < FonsView3D.CAMERA_DISTANCE - 0.01:
				collapsed += 1
			if boom < FonsView3D.CAMERA_AVATAR_FADE_NEAR:
				hidden += 1
			if boom < worst:
				worst = boom
				at = "%s %d°" % [String(biome.get("id", "")), int(rad_to_deg(yaw))]
		view.free()
	assert_gt(parts, 0, "랜드마크·프롭이 깔려야 검사가 의미 있다")
	assert_eq(close, 0, "시작 자리 앞에 서는 부품 0 (최단 %.2f)" % nearest)
	assert_eq(collapsed, 0, "붐이 접히는 방향 0 (최단 %.2f @ %s)" % [worst, at])
	assert_eq(hidden, 0, "조종 영웅이 화면에서 사라지는 방향 0")


func _biomes() -> Array:
	## 26바이옴 — `data/biomes.json` 의 그룹 순서 그대로.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))
	var out: Array = []
	if not (parsed is Dictionary):
		fail_test("biomes.json 을 읽지 못했다")
		return out
	for group in (parsed as Dictionary).get("groups", []):
		for biome in (group as Dictionary).get("biomes", []):
			out.append(biome)
	return out


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
	# 시간이 안 흔른 호출은 스무딩을 안 밀므로(2026-10-28), 자리 잡힌 배치를 따로 청한다.
	view._boom_ready = false
	view._place_camera()
	var focus: Vector3 = view.camera_focus()
	var away: float = view._camera.position.distance_to(focus)
	assert_lt(away, 3.0, "나무 앞에서 붐이 접힌다")
	assert_gt(away, 1.5, "캐릭터 등 뒤까지 접지는 않는다")
	view.free()


## ── 벽 앞 스윙 (2026-10-28) ────────────────────────────────────────
## 붐이 영웅 몸속까지 접히면 화면이 벽(또는 파티 몸통)으로 꽉 찬다. 그 자리에서는 접는 대신
## **옆으로 돌아** 뚫린 각도를 찾는다. 작은 프롭은 지금처럼 당긴다 — 스윙은 마지막 수단이다.

func _tower_wall(at: Vector3) -> Dictionary:
	## 뷰가 탑을 세울 때 쓰는 가림 원통과 같은 크기 (몸통 × `TOWER_BLOCKER_SCALE`).
	return {"pos": at, "radius": FonsExplore.TOWER_BODY * FonsView3D.TOWER_BLOCKER_SCALE,
		"top": FonsView3D.TOWER_HEIGHT}


func test_camera_swings_around_a_wall_instead_of_going_inside_the_hero() -> void:
	## 탑 벽(몸통 1.2 × 1.35 = 1.62)에 등지고 시점을 벽 쪽으로 돌린 자리. 옛 규칙은 붐을 0.63 까지
	## 접어 카메라가 영웅 몸속에 들어갔다 — 화면이 벽과 파티 몸통으로 찼다(2026-10-28).
	var view := _wall_view()
	var pitch := deg_to_rad(FonsView3D.CAMERA_PITCH_DEFAULT)
	var ideal: float = view.camera_free_distance(view.camera_focus(),
		Vector3(0.0, sin(pitch), cos(pitch)), FonsView3D.CAMERA_DISTANCE)
	assert_lt(ideal, FonsView3D.CAMERA_AVATAR_FADE_NEAR,
		"전제 — 벽이 붐을 영웅 몸속까지 접는다 (%.2f)" % ideal)
	view._place_camera()
	assert_gt(view.camera_boom(), FonsView3D.CAMERA_AVATAR_FADE_FAR,
		"붐을 접는 대신 돌았다 — 영웅이 흐려지지 않는다 (%.2f)" % view.camera_boom())
	assert_almost_eq(view.avatar_transparency(), 0.0, 0.001, "영웅은 불투명하게 남는다")
	var turned := absf(rad_to_deg(view.camera_swing()))
	assert_gt(turned, 40.0, "옆으로 돌았다 (%.0f°)" % turned)
	assert_lt(turned, 121.0, "120° 상한 — 뒤집히지는 않는다")
	var at: Vector3 = view._camera.position
	assert_gt(Vector2(at.x - 20.0, at.z - 16.6).length(), 1.62, "카메라가 벽 원통 밖에 선다")
	view.free()


func test_small_props_still_pull_the_boom_in_instead_of_swinging() -> void:
	## 스윙은 마지막 수단이다 — 나무 하나가 붐을 1.9 로 접는 정도면 지금처럼 당긴다.
	## 영웅은 반투명하게 남고, 화면도 안 뒤집힌다 (2026-10-25 의 손맛을 지킨다).
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]})
	view._yaw = 0.0
	view._blockers = [{"pos": Vector3(20.0, 0.0, 17.0), "radius": 0.9, "top": 4.0}]
	view._boom_ready = false
	view._swing_ready = false
	view._place_camera()
	assert_almost_eq(view.camera_swing(), 0.0, 0.001, "옆으로 돌지 않는다")
	assert_lt(view.camera_boom(), 2.2, "붐은 지금처럼 나무 앞에서 접힌다")
	assert_gt(view.camera_boom(), FonsView3D.CAMERA_AVATAR_FADE_NEAR, "그래도 영웅이 화면에 남는다")
	view.free()


func test_apply_does_not_snap_the_camera_smoothing() -> void:
	## 걷는 동안에는 스냅샷을 미는 `apply` 가 매 프레임 카메라를 놓는다 — 그때 시간이 안 흘렀다고
	## 목표로 꽂으면(`delta <= 0` 을 스냅으로 보면) 붐·스윙 스무딩이 통째로 무너진다.
	## 2026-10-28 실창 실측: 43ms 프레임에서 붐이 1.34 → 4.20 으로 3프레임에 튀었다.
	var view := FonsView3D.new()
	var snapshot := {"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]}
	view.mount(snapshot)
	view._yaw = 0.0
	view._place_camera()
	assert_almost_eq(view.camera_boom(), FonsView3D.CAMERA_DISTANCE, 0.01, "전제 — 가림 없음")
	view._blockers = [{"pos": Vector3(20.0, 0.0, 17.0), "radius": 0.9, "top": 4.0}]
	view.apply(snapshot)
	assert_almost_eq(view.camera_boom(), FonsView3D.CAMERA_DISTANCE, 0.01,
		"apply 는 붐을 목표로 꽂지 않는다 (걷는 중 스냅 금지)")
	view._process(1.0 / 60.0)
	assert_lt(view.camera_boom(), FonsView3D.CAMERA_DISTANCE - 0.2, "프레임이 지나면 당겨진다")
	view.free()


func test_camera_swing_eases_out_instead_of_snapping() -> void:
	## 스윙 각도도 시간으로 는다 — 한 프레임에 꽂히면 시점이 튄다. 벽이 사라지면 천천히 돌아온다.
	var view := _wall_view()
	view._place_camera()
	var swung: float = view.camera_swing()
	assert_gt(absf(swung), 0.5, "먼저 벽을 피해 돌아 있다")
	view._blockers = []
	var prev := swung
	for i in 90:
		view._place_camera(1.0 / 60.0)
		assert_lte(absf(view.camera_swing() - prev), 0.12, "프레임당 6.9° 안쪽으로만 돈다")
		prev = view.camera_swing()
	var left := absf(rad_to_deg(view.camera_swing()))
	assert_lt(left, 12.0, "1.5초면 거의 제자리 (남은 %.1f°)" % left)
	assert_almost_eq(view.camera_boom(), FonsView3D.CAMERA_DISTANCE, 0.1, "붐도 같이 풀린다")
	view.free()


func test_camera_stays_out_of_the_wall_through_a_full_turn() -> void:
	## 벽 앞에서 시점을 360° 돌려도 카메라가 벽 원통 안이나 영웅 몸속에 들어가지 않는다.
	## 각도마다 따로 잰다 — 스윙이 시점을 따라 계속 다시 잡아야 한다는 뜻이다.
	## (탑 가림 원통 반지름 1.62 — 카메라가 그 안이면 화면이 돌 하나다.)
	var view := _wall_view()
	var worst := INF
	for i in 72:
		view._yaw = TAU * float(i) / 72.0
		# 각 방향에서 "자리 잡힌" 자세를 잰다 — 스무딩이 흐르는 중간값이 아니라.
		view._boom_ready = false
		view._swing_ready = false
		view._place_camera()
		var at: Vector3 = view._camera.position
		worst = minf(worst, view.camera_boom())
		assert_gt(Vector2(at.x - 20.0, at.z - 16.6).length(), 1.62, "%d° 에서 카메라가 벽 밖" % int(rad_to_deg(view._yaw)))
		assert_gt(view.camera_boom(), FonsView3D.CAMERA_AVATAR_FADE_NEAR,
			"%d° 에서 영웅이 화면에 남는다 (붐 %.2f)" % [int(rad_to_deg(view._yaw)), worst])
	view.free()


func _wall_view() -> FonsView3D:
	## 벽 앞 자리 — 영웅이 탑 가림 원통(1.62)에서 2.6, 시점은 벽 쪽(yaw 0 = +z)으로 돌아 있다.
	## 2.6 은 2026-10-28 이전의 시작 자리와 같은 거리다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]})
	view._yaw = 0.0
	view._blockers = [_tower_wall(Vector3(20.0, 0.0, 16.6))]
	# `mount` 가 이미 한 번 놓았으므로 스무딩을 풀어 둔다 — 테스트의 첫 `_place_camera()` 가
	# 그 자리에 “자리 잡힌” 배치를 내도록 (2026-10-28: 델타 0 은 스무딩을 안 민다).
	view._boom_ready = false
	view._swing_ready = false
	return view


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


func test_strike_shakes_the_camera_briefly() -> void:
	## 교전은 한 프레임에 끝난다 — 카메라도 그 순간에 짧게 흔들리고 곧 제자리로 돌아와야 한다.
	var view := FonsView3D.new()
	var snapshot := {"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]}
	view.mount(snapshot)
	view._yaw = 0.0
	view._place_camera()
	var rest: Vector3 = view._camera.position
	snapshot["strike"] = {"seq": 1, "site": 0, "damage": 37}
	view.apply(snapshot)
	assert_gt(view.shake_left(), 0.0, "교전 순간 카메라가 흔들린다")
	assert_gt(view._camera.position.distance_to(rest), 0.005, "정지 자리에서 벗어난다")
	# 흔들림은 0.18초 — 0.5초를 돌리면 끝나고 카메라도 정확히 제자리다.
	for i in 30:
		view._process(1.0 / 60.0)
	assert_almost_eq(view.shake_left(), 0.0, 0.001, "짧게 끝난다")
	view._place_camera()
	assert_lt(view._camera.position.distance_to(rest), 0.001, "제자리로 돌아온다")
	view.free()


func test_a_repeated_strike_seq_does_not_shake_again() -> void:
	## 스냅샷은 매 입력마다 온다 — 같은 교전을 다시 받아도 흔들림이 다시 시작되면 안 된다.
	var view := FonsView3D.new()
	var snapshot := {"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]}
	view.mount(snapshot)
	snapshot["strike"] = {"seq": 1, "site": 0, "damage": 20}
	view.apply(snapshot)
	for i in 20:
		view._process(1.0 / 60.0)
	var left: float = view.shake_left()
	view.apply(snapshot)
	assert_almost_eq(view.shake_left(), left, 0.001, "같은 seq 는 다시 흔들지 않는다")
	view.free()


func test_space_jumps_the_avatar_and_lands() -> void:
	## Space 는 이제 교전이 아니라 점프다. 교전은 F — 조우와 미션 완료 둘 다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]})
	var got: Array = []
	view.intent.connect(func(kind, payload): got.append(kind))
	view._unhandled_input(_key(KEY_SPACE))
	assert_eq(got.size(), 0, "Space 는 교전 의도가 아니다")
	view._process(1.0 / 60.0)
	assert_gt(view.jump_height(), 0.0, "발이 땅에서 뜬다")
	var peak := view.jump_height()
	for i in 59:
		view._process(1.0 / 60.0)
		peak = maxf(peak, view.jump_height())
	assert_gt(peak, 0.3, "눈에 보이는 높이로 뜬다")
	assert_almost_eq(view.jump_height(), 0.0, 0.001, "내려온다")
	assert_almost_eq(view._nodes["avatar"].position.y, 0.0, 0.001, "지면 높이로 돌아간다")
	view.free()


func test_mouse_capture_turns_the_view_without_a_button() -> void:
	## 서브컬쳐 게임처럼 들어가면 커서를 잡고, 버튼 없이 마우스만 움직여 시점을 돈다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	assert_true(view.mouse_capture_wanted(), "필드에 들어가면 마우스를 잡는다")
	var before: float = view.camera_yaw()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80.0, 0.0)
	view._unhandled_input(motion)
	assert_ne(view.camera_yaw(), before, "버튼 없이 움직여도 시점이 돈다")
	var turned: float = view.camera_yaw()
	# Esc 로 놓으면 커서가 돌아오고, 그동안은 마우스가 시점을 안 건드린다.
	view._unhandled_input(_key(KEY_ESCAPE))
	assert_false(view.mouse_capture_wanted(), "Esc 로 마우스를 놓는다")
	view._unhandled_input(motion)
	assert_almost_eq(view.camera_yaw(), turned, 0.0001, "놓은 동안에는 시점이 안 돈다")
	# 필드를 클릭하면 다시 잡는다.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	view._unhandled_input(click)
	assert_true(view.mouse_capture_wanted(), "클릭하면 다시 잡는다")
	view.free()


func test_leaving_the_field_releases_the_mouse() -> void:
	## 전투 화면·타이틀로 나가면 커서를 돌려줘야 한다 — 아니면 마우스가 갇힌다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	assert_true(view.mouse_capture_wanted())
	view.apply({"entities": []})
	assert_false(view.mouse_capture_wanted(), "필드가 아닌 화면에서는 커서가 보인다")
	view.free()


func test_terrain_paints_the_same_trail_the_kit_avoids() -> void:
	## 지형색과 프롭 피하기가 서로 다른 길을 보면 프롭이 칠해진 길 위에 선다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("site:0", "site", Vector3(13, 0, 7)),
		_entity("site:1", "site", Vector3(11, 0, 14)),
	]})
	assert_not_null(view._terrain, "지형이 있어야 한다")
	var painted: PackedVector2Array = view._terrain.trails[0]
	var shared := view.terrain_trail()
	assert_eq(painted, shared, "지형이 칠한 길 = 키트가 피한 길")
	assert_gt(shared.size(), 2, "조우를 잇는 길이다")
	view.free()


func _sky_palette(sky: Color, light: Color) -> Dictionary:
	var palette := _palette(Color(0.36, 0.52, 0.28))
	palette["sky"] = sky
	palette["light"] = light
	return palette


func test_field_sky_grades_into_haze_instead_of_a_flat_void() -> void:
	## 3인칭 카메라는 지평선을 보여 준다 — 단색 배경이면 땅이 어두운 허공에 뜬다.
	## 천정은 심의 sky, 지평선은 그 sky 를 태양광 쪽으로 섞은 헤이즈(공기 원근)다.
	var view := FonsView3D.new()
	var sky := Color(0.10, 0.14, 0.24)
	var light := Color(1.0, 0.94, 0.86)
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"palette": _sky_palette(sky, light)})
	assert_eq(view._environment.background_mode, Environment.BG_SKY, "필드는 하늘 그라데이")
	assert_eq(view._sky_material.sky_top_color, sky.srgb_to_linear(),
		"천정 = 심이 준 sky — 하늘 재질은 선형광을 받으므로 변환해서 넣는다")
	var horizon := view.horizon_color()
	assert_gt(horizon.v, sky.v, "지평선이 천정보다 밝다 — 먼 공기가 밝아진다")
	assert_almost_eq(horizon.h, sky.h, 0.01, "색상각은 지킨다 — 회색 안개가 아니라 그 하늘의 먼 빛")
	assert_eq(view._sky_material.sky_horizon_color, horizon.srgb_to_linear(),
		"칠한 지평선 = 헤이즈 (선형광으로 변환해서)")
	assert_eq(view._environment.fog_light_color, horizon.srgb_to_linear(),
		"먼 땅은 같은 헤이즈로 잠긴다 (안개도 선형광)")
	assert_true(view._environment.fog_enabled, "거리 안개를 켠다")
	assert_almost_eq(view._environment.fog_sky_affect, FonsView3D.FOG_SKY_AFFECT, 0.001,
		"안개가 하늘을 덮으면 그라데이가 한 색 판이 된다")
	view.free()


func test_battle_screen_keeps_the_flat_backdrop() -> void:
	## 전투 화면·헤드리스에는 지평선이 없다 — 하늘을 켜면 HUD 뒤 배경이 통째로 바뀐다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"palette": _sky_palette(Color(0.10, 0.14, 0.24), Color.WHITE)})
	assert_eq(view._environment.background_mode, Environment.BG_SKY)
	view.apply({"entities": []})
	assert_eq(view._environment.background_mode, Environment.BG_COLOR, "필드가 아니면 단색")
	assert_false(view._environment.fog_enabled, "안개도 끈다")
	view.free()


func test_strike_also_tilts_the_camera_for_a_frame() -> void:
	## 위치만 흔들면 화면이 미끄러지는 것으로 읽힌다 — 짧은 기울기(롤)가 한 방의 무게를 만든다.
	## 2026-10-25 상향: 실측 첫 프레임 0.72° → 1.44° 로 키웠다 (위치는 0.178 → 0.290유닛).
	var view := FonsView3D.new()
	var snapshot := {"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]}
	view.mount(snapshot)
	view._yaw = 0.0
	view._place_camera()
	# 롤은 카메라 오른쪽 축이 수평에서 벗어난 각이다. look_at(UP) 만으로는 항상 0 이고,
	# 위치 흔들림은 요우·피치만 바꾸므로 이 값은 회전 성분만 잰다.
	assert_almost_eq(rad_to_deg(asin(clampf(view._camera.transform.basis.x.y, -1.0, 1.0))), 0.0, 0.001,
		"교전 전에는 기울지 않았다")
	snapshot["strike"] = {"seq": 1, "site": 0, "damage": 30}
	view.apply(snapshot)
	var rolled := absf(rad_to_deg(asin(clampf(view._camera.transform.basis.x.y, -1.0, 1.0))))
	assert_gt(rolled, 0.5, "위치만이 아니라 화면이 기운다 (롤)")
	assert_lt(rolled, 3.0, "2.2° 상한 안 — 5°를 넘기면 멀미가 난다")
	for i in 30:
		view._process(1.0 / 60.0)
	view._place_camera()
	assert_almost_eq(rad_to_deg(asin(clampf(view._camera.transform.basis.x.y, -1.0, 1.0))), 0.0, 0.001,
		"흔들림이 끝나면 기울기도 정확히 0 (회전이 누적되지 않는다)")
	view.free()


func test_heavy_strike_shakes_harder_than_a_light_one() -> void:
	## 세기 단계는 피해 숫자가 아니라 치명타 여부로 가른다 (`strike.heavy`).
	## 실측 피해가 1,000 단위라 숫자 문턱값을 박으면 모든 판이 한 쪽에 붙는다.
	var light := _shake_peak(false)
	var heavy := _shake_peak(true)
	assert_gt(float(heavy["roll"]), float(light["roll"]) * 1.5, "강한 일격은 롤이 확실히 크다")
	assert_gt(float(heavy["offset"]), float(light["offset"]) * 1.2, "위치도 더 밀린다")
	assert_lte(float(heavy["offset"]), 0.35, "가림 여유(0.35유닛)를 넘지 않는다 — 나무를 뚫으면 안 된다")
	assert_lt(float(heavy["roll"]), 5.0, "3인칭 멀미 상한(5°)")


func _shake_peak(heavy: bool) -> Dictionary:
	## 한 번 흔드는 동안의 최대 롤(도)과 최대 위치 이동(유닛). 흔들림 RNG 는 고정 시드라
	## 가벼운 쪽과 무거운 쪽이 **같은 난수 수열**을 쓰므로 배율 차이만 남는다.
	var view := FonsView3D.new()
	var snapshot := {"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]}
	view.mount(snapshot)
	view._yaw = 0.0
	view._place_camera()
	var rest: Vector3 = view._camera.position
	snapshot["strike"] = {"seq": 1, "site": 0, "damage": 30, "heavy": heavy}
	view.apply(snapshot)
	var max_roll := 0.0
	var max_off := 0.0
	for i in 12:
		view._place_camera()
		max_roll = maxf(max_roll, absf(rad_to_deg(asin(clampf(view._camera.transform.basis.x.y, -1.0, 1.0)))))
		max_off = maxf(max_off, view._camera.position.distance_to(rest))
		view._process(1.0 / 60.0)
	view.free()
	return {"roll": max_roll, "offset": max_off}


func test_boom_eases_when_a_tree_clips_the_view() -> void:
	## 나무가 시야를 가리면 목표 붐이 프레임마다 튄다 — 그대로 쓰면 카메라가 툭툭 당겨진다.
	## 당길 때는 빠르되 한 프레임에 꽂히지 않고, 풀릴 때는 느리게 돌아온다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		_entity("avatar", "avatar", Vector3(20, 0, 14)),
	]})
	view._yaw = 0.0
	view._place_camera()
	var open: float = view.camera_boom()
	assert_almost_eq(open, FonsView3D.CAMERA_DISTANCE, 0.05, "가림이 없으면 기본 거리")
	# 카메라 뒤쪽에 나무가 들어온다 → 목표가 ≈2.8 로 접힌다.
	view._blockers = [{"pos": Vector3(20.0, 0.0, 17.0), "radius": 0.9, "top": 4.0}]
	# 정상 경로(`_process` → `_update_camera(delta)` → `_place_camera(delta)`)로 돌린다 — 배선까지 잡는다.
	view._process(1.0 / 60.0)
	var first: float = view.camera_boom()
	assert_lt(first, open, "당겨진다")
	assert_gt(first, 3.2, "한 프레임에 목표(≈2.8)까지 꽂히지 않는다 — 끊기지 않게")
	var prev := first
	for i in 20:
		view._place_camera(1.0 / 60.0)
		assert_lte(prev - view.camera_boom(), 0.6, "프레임 사이로 한 번에 다 줄지 않는다")
		assert_lte(view.camera_boom(), prev + 0.001, "되돌아가며 떨지 않는다")
		prev = view.camera_boom()
	assert_lt(view.camera_boom(), 3.0, "0.35초 안에 나무 앞까지 당겨진다")
	# 나무가 빠지면 천천히 풀린다 — 즉시 튀어나오면 그게 다시 끊김이다.
	view._blockers = []
	view._place_camera(1.0 / 60.0)
	assert_lt(view.camera_boom(), 3.2, "풀릴 때는 한 프레임에 돌아오지 않는다")
	for i in 60:
		view._place_camera(1.0 / 60.0)
	assert_almost_eq(view.camera_boom(), FonsView3D.CAMERA_DISTANCE, 0.1, "1초면 원래 거리")
	# 휠 줌은 손맛이다 — 스무딩을 거치지 않고 그 프레임에 붙는다.
	view.zoom(2.0)
	view._place_camera(1.0 / 60.0)
	assert_almost_eq(view.camera_boom(), view.camera_distance(), 0.01, "줌은 즉시")
	view.free()


func test_blocking_distance_is_continuous_when_a_tree_slides_across_the_view() -> void:
	## 스침 판정을 그대로 쓰면 목표 거리가 한 프레임에 2.34유닛 튄다 (실측) — 카메라가 툭 당겨진다.
	## 축에서 반경+완중폭 안으로 들어올 때부터 가중치를 섞어 목표를 연속으로 만든다.
	var view := FonsView3D.new()
	var from := Vector3(0.0, 0.62, 0.0)
	var tree := {"pos": Vector3(0.0, 0.0, 3.0), "radius": 1.8, "top": 6.0}
	var prev := -1.0
	var max_step := 0.0
	var blocked := 4.2
	for i in 200:
		var yaw := deg_to_rad(-60.0 + float(i) * 0.6)
		var dir := Vector3(sin(yaw), 0.32, cos(yaw)).normalized()
		var free: float = view.camera_free_distance(from, dir, 4.2, [tree])
		if prev >= 0.0:
			max_step = maxf(max_step, absf(free - prev))
		prev = free
		blocked = minf(blocked, free)
	assert_lt(max_step, 0.3, "나무가 시야를 가로질러도 붐 목표가 튀지 않는다")
	assert_lt(blocked, 3.0, "정면으로 막히면 여전히 접힌다")
	assert_almost_eq(view.camera_free_distance(from, Vector3(-0.9, 0.32, 0.35).normalized(),
		4.2, [tree]), 4.2, 0.001, "완전히 빗나가면 그대로")
	view.free()


func test_blocking_distance_is_continuous_when_the_pitch_rises_into_a_canopy() -> void:
	## 시점을 올리면 광선 교점이 캐노피 **밑동**을 넘는 순간이 있다. 위/아래 판정이 이진이면
	## 그 프레임에 목표가 2.32유닛 튄다 (42° 시점 · 실제 키트 잎 반경 1.81 실측).
	## 높이 가장자리도 가로와 같은 폭으로 물어야 한다.
	var view := FonsView3D.new()
	var from := Vector3(0.0, 0.62, 0.0)
	# 실제 키트의 잎 원통 — 밑동이 땅에서 2.1 위에 떠 있다. 예전 코드는 여기서 끊겼다.
	var canopy := {"pos": Vector3(0.0, 2.1, 3.0), "radius": 1.81, "top": 5.9}
	var prev := -1.0
	var max_step := 0.0
	var blocked := 4.2
	for i in 120:
		var pitch := deg_to_rad(18.0 + float(i) * 0.2)
		var dir := Vector3(0.0, sin(pitch), cos(pitch)).normalized()
		var free: float = view.camera_free_distance(from, dir, 4.2, [canopy])
		if prev >= 0.0:
			max_step = maxf(max_step, absf(free - prev))
		prev = free
		blocked = minf(blocked, free)
	assert_lt(max_step, 0.15, "시점을 올려도 붐 목표가 프레임마다 튀지 않는다")
	assert_lt(blocked, 3.2, "캐노피 쪽으로 기울이면 여전히 당겨진다")
	view.free()


func test_tower_and_summoning_circle_are_built_from_the_mark() -> void:
	## 심은 자리·반경만 보낸다 — 탑·소환진 메시는 뷰가 세운다. 반경을 지어내면 안 된다.
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28),
		"tower": {"pos": Vector3(20, 0, 14), "radius": 3.4, "body": 1.2},
		"entities": [_entity("avatar", "avatar", Vector3(20, 0, 14))]})
	assert_not_null(view.tower_node(), "탑이 서 있다")
	assert_almost_eq(view.tower_radius(), 3.4, 0.001, "반경은 심이 준 값 그대로")
	assert_eq(view.tower_node().position.x, 20.0, "자리도 심이 준 값")
	assert_eq(view.tower_node().position.z, 14.0)
	# 몸통·덮개 + 소환진 고리 둘 = 4개 이상. 고리가 빠지면 땅에 돌기둥만 선다.
	assert_gt(view.tower_node().get_child_count(), 3)
	# 표가 없으면 세우지 않는다 (전투 화면).
	view.apply({"mode": "field", "field": Vector2(40, 28), "entities": []})
	assert_null(view.tower_node(), "표가 빠지면 탑도 사라진다")
	view.free()


func test_streaming_terrain_is_wider_than_the_encounter_radius() -> void:
	## 청크 스트리밍 — 심은 조우 반경(3×3)만 보내지만 지형은 7×7 로 깔아야 안개가 끝을 덮는다.
	var chunks: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			chunks.append(Vector3(dx * FonsExplore.CHUNK_WIDTH, 0.0, dz * FonsExplore.CHUNK_DEPTH))
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(FonsExplore.CHUNK_WIDTH, FonsExplore.CHUNK_DEPTH),
		"entities": [_entity("site:0", "site", Vector3(4, 0, 4))],
		"chunks": chunks, "kit": "topo_not_built", "biome": "biome_forest",
		"palette": _biome_palette(12.0, "calm")})
	assert_eq(view._chunk_meshes.size(), (FonsView3D.VISUAL_RADIUS * 2 + 1) * (FonsView3D.VISUAL_RADIUS * 2 + 1),
		"지형은 조우 반경보다 넓은 (2R+1)² 청크")
	assert_eq(view.entity_count(), 1, "조우는 심이 준 목록 그대로 — 지형 확장에 늘지 않는다")
	view.free()


func test_fog_stops_before_the_terrain_even_at_the_chunk_edge() -> void:
	## 무한맵 2단계 — 안개와 활성 반경을 **같은 수**에서 뽑는다. 지형은 아바타 청크에서
	## R 청크까지 깔리므로, 청크 안 어디에 서도 가장 가까운 끝은 R 청크다. 손으로 고른 수를
	## 쓰면 반경이나 청크 크기를 바꿀 때 조용히 어긋난다 (2026-10-26).
	var view := FonsView3D.new()
	# 아바타를 청크 남서 모서리에 붙인다 — 가장 불리한 자리.
	view.mount({"mode": "field", "field": Vector2(FonsExplore.CHUNK_WIDTH, FonsExplore.CHUNK_DEPTH),
		"entities": [_entity("avatar", "avatar", Vector3(-19.9, 0, -13.9))],
		"chunks": _stream_chunks(), "kit": "topo_not_built", "biome": "biome_forest",
		"palette": _biome_palette(12.0, "calm")})
	assert_gt(FonsView3D.VISUAL_RADIUS, FonsExplore.ACTIVE_RADIUS,
		"지형은 심의 활성 반경보다 넓다 — 같으면 조우가 지형 끝에 선다")
	var span := view.fog_span()
	var nearest := float(FonsView3D.VISUAL_RADIUS) * float(FonsExplore.CHUNK_DEPTH)
	assert_lt(span.y, nearest, "안개 끝이 가장 가까운 지형 끝 앞에서 잠긴다")
	assert_lt(span.x, span.y, "안개 시작이 끝보다 앞선다")
	assert_almost_eq(span.x, span.y * FonsView3D.FOG_BEGIN_RATIO, 0.001,
		"시작도 손으로 고른 수가 아니라 끝의 비율이다 — 둘이 따로 놀면 중간 거리 프롭이 하늘보다 밝게 남는다")
	assert_almost_eq(view._environment.fog_depth_end, span.y, 0.001, "끝이 환경에 실제로 걸린다")
	assert_almost_eq(view._environment.fog_depth_begin, span.x, 0.001, "시작도 같이")
	assert_almost_eq(view._environment.fog_depth_curve, FonsView3D.FOG_DEPTH_CURVE, 0.001,
		"곡선도 환경에 걸린다 — 상수만 두고 적용을 빼먹으면 중경이 다시 뿌옇다")
	# 반경을 한 겹 더 깔면 안개도 그만큼 멀어진다 — 두 수를 따로 맞추지 않는다.
	var chunk := Vector2(FonsExplore.CHUNK_WIDTH, FonsExplore.CHUNK_DEPTH)
	assert_gt(FonsView3D.fog_span_for(FonsView3D.VISUAL_RADIUS + 1, chunk).y, span.y,
		"반경이 커지면 안개 끝도 따라간다")
	assert_lt(FonsView3D.fog_span_for(FonsView3D.VISUAL_RADIUS + 1, chunk).y,
		float(FonsView3D.VISUAL_RADIUS + 1) * float(FonsExplore.CHUNK_DEPTH),
		"커진 반경에서도 여전히 지형 안쪽에서 잠근다")
	view.free()


func test_mid_distance_props_sit_deep_in_the_haze() -> void:
	## 45~55 거리 프롭이 지형을 넘어 하늘 위에 옅게 뜨던 자리 (2026-10-26 4방향 검수).
	## 그 거리는 아직 색이 반 넘게 남아 있어서 컬링으로 지우면 팝이 난다 — 안개 세기로만 닫힌다.
	## 세 쪽을 같이 잠근다: 그 대역은 깊이 젖고, 컬링 거리(60)는 더 젖고, 가까운 필드(35)는 남는다.
	##
	## 안개량은 **선형이 아니다**. Godot 4.7 은 `smoothstep(시작, 끝, 거리)` 에 `FOG_DEPTH_CURVE`
	## 를 거듭제곱한다 (2026-10-27 흰 판 실측: curve 1 에서 16.4 / 44.0 / 85.5%, curve 2 에서
	## 2.6 / 19.5 / 72.8%). 선형으로 계산하면 곡선을 아무리 올려도 55 가 66% 로 보여서
	## 지평선 위 옅은 판이 돌아온 것을 못 잡는다.
	var span := FonsView3D.fog_span_for(float(FonsView3D.VISUAL_RADIUS),
		Vector2(FonsExplore.CHUNK_WIDTH, FonsExplore.CHUNK_DEPTH))
	var wet := func(d: float) -> float:
		var t := clampf((d - span.x) / (span.y - span.x), 0.0, 1.0)
		return pow(t * t * (3.0 - 2.0 * t), FonsView3D.FOG_DEPTH_CURVE)
	assert_gte(wet.call(55.0), 0.62, "55 거리가 62%% 미만으로 젖으면 프롭이 지평선 위에 뜬다")
	assert_gte(wet.call(60.0), 0.71, "컬링 거리(60)가 71%% 미만이면 프롭이 뚝 끊겨 보인다")
	assert_lte(wet.call(35.0), 0.30, "가까운 필드(35)까지 뿌옇게 되면 프롭의 색과 입체가 안 읽힌다")


func test_kit_parts_disappear_where_the_air_turns_solid() -> void:
	## 무한맵 2단계 마무리 — 안개가 100%가 되는 거리 밖의 프롭은 땅과 같은 안개색이라
	## 땅 위에선 보이지 않는다. 그런데 지평선을 넘어 하늘 위로 솟으면 옅은 판으로 뜬다
	## (2026-10-26 렌더) — 그 거리에서 인스턴스를 끈다. 값은 안개 끝에서 받는다.
	## 다만 100% 지점까지 기다리면 60~72 대역이 70~100% 만 젖은 채 남아 지평선에 뜬다
	## (2026-10-26 4방향 검수) — 안개 span 의 `KIT_CULL_RATIO` 지점에서 끈다.
	var view := FonsView3D.new()
	view.register_kit("test_kit_mesh", _mesh_kit_scene())
	view.mount({"mode": "field", "field": Vector2(FonsExplore.CHUNK_WIDTH, FonsExplore.CHUNK_DEPTH),
		"entities": [_entity("avatar", "avatar", Vector3.ZERO)],
		"chunks": _stream_chunks(), "kit": "test_kit_mesh", "biome": "biome_forest",
		"palette": _biome_palette(12.0, "calm")})
	assert_not_null(view._kit_root, "키트가 깔렸다")
	var meshes := _kit_meshes(view._kit_root)
	assert_gt(meshes.size(), 0, "그려지는 부품이 있다")
	var span := view.fog_span()
	var end: float = span.x + (span.y - span.x) * FonsView3D.KIT_CULL_RATIO
	assert_gt(end, span.x + FonsBiomeKit.DRAW_END_FADE,
		"끄는 자리가 안개 시작보다 충분히 멀다 — 가까운 프롭이 흐려지면 안 된다")
	assert_lt(end, span.y, "안개가 100%가 되기 전에 끈다")
	for mesh in meshes:
		assert_almost_eq(mesh.visibility_range_end, end, 0.001,
			"%s 는 안개 끝보다 앞에서 꺼진다" % mesh.name)
	view.free()


func test_kit_cull_keeps_the_same_haze_in_dense_fog_biomes() -> void:
	## 짙은 안개 바이옴은 안개 span 을 **나눈다** (`palette.fog` 1.30 · 1.45, 동굴은 light:dark 가
	## 겹쳐 1.8125). 26바이옴 중 11개가 배율 1 초과다. 컬링이 고정 거리면 짧아진 span 안에서 더
	## 이르게 잡혀 반쯤 젖은 자리에서 프롭이 사라진다 — 비율로 끄면 배율이 달라도 같은 만큼 젖는다.
	## 측정(2026-10-27): 고정 12 유닛이면 1.45 에서 63.7%, 1.8125 에서 49.1% (곡선 1.4 기준).
	for fog in [1.0, 1.30, 1.45, 1.8125]:
		var view := FonsView3D.new()
		var palette := _biome_palette(12.0, "calm")
		palette["fog"] = fog
		view.register_kit("test_kit_mesh", _mesh_kit_scene())
		view.mount({"mode": "field", "field": Vector2(FonsExplore.CHUNK_WIDTH, FonsExplore.CHUNK_DEPTH),
			"entities": [_entity("avatar", "avatar", Vector3.ZERO)],
			"chunks": _stream_chunks(), "kit": "test_kit_mesh", "biome": "biome_forest",
			"palette": palette})
		var meshes := _kit_meshes(view._kit_root)
		assert_gt(meshes.size(), 0, "배율 %.2f — 키트가 깔렸다" % fog)
		var span := view.fog_span()
		assert_lt(span.x, span.y, "배율 %.2f — 안개 시작이 끝보다 앞선다" % fog)
		var t: float = (meshes[0].visibility_range_end - span.x) / (span.y - span.x)
		var haze: float = pow(t * t * (3.0 - 2.0 * t), FonsView3D.FOG_DEPTH_CURVE)
		assert_gte(haze, 0.71, "배율 %.2f — 컬링 자리가 %.0f%% 젖는다 (71%% 이상)" % [fog, haze * 100.0])
		assert_lt(meshes[0].visibility_range_end, span.y, "배율 %.2f — 안개가 100%% 되기 전에 끈다" % fog)
		view.free()


func _kit_meshes(node: Node) -> Array:
	## 거리 컬링은 메시에만 걸린다 — 키트 부품을 끝까지 파고들어 모은다.
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_kit_meshes(child))
	return out


func _mesh_kit_scene() -> PackedScene:
	## `_kit_scene` 과 같은 부품인데 **메시가 씬에 살아남는다** — `PackedScene.pack` 은
	## owner 가 붙은 노드만 저장하므로, 메시 검사(거리 컬링)는 이 헬퍼로 해야 한다.
	var root := Node3D.new()
	root.name = "Kit"
	for name in ["ground_a", "prop_bush", "landmark_tree"]:
		var part := Node3D.new()
		part.name = name
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		root.add_child(part)
		part.add_child(mesh)
		# owner 는 부모가 붙은 **뒤**에 정한다 — 미리 정하면 owner_valid 경고가 난다.
		mesh.owner = root
		part.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _stream_chunks() -> Array:
	## 심이 보내는 3×3 활성 청크 — 뷰 테스트들이 같은 목록을 쓴다.
	var chunks: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			chunks.append(Vector3(dx * FonsExplore.CHUNK_WIDTH, 0.0, dz * FonsExplore.CHUNK_DEPTH))
	return chunks
