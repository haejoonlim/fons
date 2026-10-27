extends GutTest
## 영웅 몸통 3종 — 색 상자·캡슐을 대신하는 실루엣 셋.
##
## 계약은 넷이다.
##   1. 대역 셋(guard·scout·mystic)이 실제 `.glb` 로 임포트되고 부품 이름이 정해져 있다.
##   2. 같은 영웅 키는 언제나 같은 몸통을 입는다 — 판마다 바뀌면 정체성이 사라진다.
##   3. 틴트는 몸 부품만 바꾼다 — 방패·지팡이·눈은 구운 색을 지킨다.
##   4. 뷰가 씬을 붙이고, HP 바 높이를 실제 몸통 높이로 잡는다. 흐림도 씬에 걸린다.

const BANDS := ["guard", "scout", "mystic"]
const PLANS := {
	"guard": "res://assets/art/models/hero_guard.glb",
	"scout": "res://assets/art/models/hero_scout.glb",
	"mystic": "res://assets/art/models/hero_mystic.glb",
}
## 모든 영웅에 있어야 하는 부품. 장비(gear_*)는 대역마다 다르다 — 방패 없는 영웅이 있다.
const PARTS := ["body_hide", "skin_limb", "eye_dark"]


func _meshes(node: Node) -> Dictionary:
	var out := {}
	for child in node.find_children("*", "MeshInstance3D", true, false):
		out[String(child.name)] = child
	return out


func test_three_hero_plans_are_imported_with_the_part_contract() -> void:
	for band in BANDS:
		var path: String = PLANS[band]
		assert_true(ResourceLoader.exists(path), "%s 가 임포트되어 있다" % path)
		var scene := load(path) as PackedScene
		assert_not_null(scene, "%s 는 씬이다" % path)
		if scene == null:
			continue
		var instance := scene.instantiate()
		var meshes := _meshes(instance)
		for part in PARTS:
			assert_true(meshes.has(part), "%s 에 %s 부품이 있다" % [band, part])
			if meshes.has(part):
				assert_gt((meshes[part] as MeshInstance3D).mesh.get_surface_count(), 0,
					"%s 의 %s 는 메시가 있다" % [band, part])
		var tall := FonsHeroBody.height(instance)
		assert_between(tall, 1.2, 2.0, "%s 키가 사람 키대다 (%.2f)" % [band, tall])
		instance.free()


func test_a_hero_key_always_wears_the_same_body() -> void:
	for key in ["hero:0", "hero:1", "hero:l1_knight", "hero:l2_sage", "hero:l3_life"]:
		var band := FonsHeroBody.band_for(key)
		assert_true(BANDS.has(band), "%s → 대역 %s" % [key, band])
		assert_eq(FonsHeroBody.band_for(key), band, "%s 는 두 번 불러도 같은 대역" % key)
	assert_eq(FonsHeroBody.band_for(""), "", "키가 없으면 폴백 도형")
	assert_false(FonsHeroBody.has_body(""), "키가 없으면 몸통이 없다")


func test_every_job_in_the_canonical_table_wears_its_band() -> void:
	## 정본은 `data/hero_assets.json` 이다 — 직업이 늘면 생성기가 다시 뽑는다.
	var text := FileAccess.get_file_as_string("res://data/hero_assets.json")
	assert_false(text.is_empty(), "직업 → 몸통 표가 있다")
	var doc: Variant = JSON.parse_string(text)
	assert_true(doc is Dictionary, "표는 JSON 객체")
	var rows: Array = (doc as Dictionary).get("jobs", []) if doc is Dictionary else []
	assert_eq(rows.size(), 34, "34직업이 전부 들어 있다")
	for row in rows:
		var id := String((row as Dictionary).get("id", ""))
		var band := String((row as Dictionary).get("band", ""))
		assert_eq(FonsHeroBody.band_for("hero:" + id), band, "%s → %s" % [id, band])
		assert_not_null(FonsHeroBody.scene(band), "%s 대역 몸통 씬이 있다" % band)


func test_job_role_picks_the_silhouette_the_table_names() -> void:
	## 앞에 서는 직업은 방패, 뒤에서 부리는 직업은 로브 — 역할이 실루엣을 가른다.
	assert_eq(FonsHeroBody.band_for("hero:l1_guardian"), "guard", "수호 → 방패")
	assert_eq(FonsHeroBody.band_for("hero:l1_warrior"), "guard", "선봉 → 방패")
	assert_eq(FonsHeroBody.band_for("hero:l2_cutthroat"), "scout", "암살 → 두건")
	assert_eq(FonsHeroBody.band_for("hero:l1_archer"), "scout", "포격 → 두건")
	assert_eq(FonsHeroBody.band_for("hero:l2_priest"), "mystic", "지원 → 로브")
	assert_eq(FonsHeroBody.band_for("hero:l1_mage"), "mystic", "마법 → 로브")
	# 표에 없는 키도 빈손으로 두지 않는다 — 해시 대역으로 서고, 두 번 부르면 같은 대역.
	var unknown := FonsHeroBody.band_for("hero:l9_unknown")
	assert_true(BANDS.has(unknown), "표에 없는 직업도 대역을 얻는다: %s" % unknown)
	assert_eq(FonsHeroBody.band_for("hero:l9_unknown"), unknown, "두 번 불러도 같다")


func test_tint_touches_body_parts_only() -> void:
	var scene := FonsHeroBody.scene("guard")
	assert_not_null(scene, "guard 몸통")
	if scene == null:
		return
	var instance := scene.instantiate()
	var color := Color(0.2, 0.7, 0.9)
	FonsHeroBody.apply(instance, color)
	var meshes := _meshes(instance)
	var hide := meshes["body_hide"] as MeshInstance3D
	assert_not_null(hide.get_surface_override_material(0), "몸통은 틴트 재질로 덮인다")
	assert_eq((hide.get_surface_override_material(0) as StandardMaterial3D).albedo_color, color)
	var limb := meshes["skin_limb"] as MeshInstance3D
	assert_eq((limb.get_surface_override_material(0) as StandardMaterial3D).albedo_color, color,
		"팔·다리도 영웅 색")
	var eye := meshes["eye_dark"] as MeshInstance3D
	assert_null(eye.get_surface_override_material(0), "눈은 영웅 색에 물들지 않는다")
	if meshes.has("gear_metal"):
		var gear := meshes["gear_metal"] as MeshInstance3D
		assert_null(gear.get_surface_override_material(0), "장비는 구운 금속색을 지킨다")
	instance.free()


func test_fade_keeps_the_color_and_only_moves_alpha() -> void:
	## 카메라가 붙으면 3인칭 시야를 가리지 않게 흐려야 한다 — 씬 몸통에도 걸려야 한다.
	var scene := FonsHeroBody.scene("scout")
	assert_not_null(scene, "scout 몸통")
	if scene == null:
		return
	var instance := scene.instantiate()
	var color := Color(0.9, 0.4, 0.2)
	FonsHeroBody.apply(instance, color)
	var hide := _meshes(instance)["body_hide"] as MeshInstance3D
	var eye := _meshes(instance)["eye_dark"] as MeshInstance3D
	FonsHeroBody.fade(instance, 0.5)
	var faded := hide.material_override as StandardMaterial3D
	assert_not_null(faded, "흐림 재질이 붙는다")
	if faded != null:
		assert_almost_eq(faded.albedo_color.a, 0.5, 0.001, "알파만 절반")
		assert_almost_eq(faded.albedo_color.r, color.r, 0.001, "색은 그대로")
		assert_almost_eq(faded.albedo_color.g, color.g, 0.001)
	assert_not_null(eye.material_override, "눈·장비까지 같이 흐려진다 — 떠 있는 눈은 안 된다")
	var solid_albedo := (hide.get_surface_override_material(0) as StandardMaterial3D).albedo_color
	FonsHeroBody.fade(instance, 0.0)
	assert_null(hide.material_override, "붐이 돌아오면 노드 덮개를 걷는다")
	assert_eq((hide.get_surface_override_material(0) as StandardMaterial3D).albedo_color, solid_albedo,
		"표면 틴트는 그대로 남는다")
	instance.free()


func test_view_mounts_the_body_for_heroes_and_the_avatar() -> void:
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [
		{"id": "avatar", "kind": "avatar", "pos": Vector3.ZERO, "size": Vector2.ONE,
			"asset": "hero:l1_knight"},
		{"id": "hero:1", "kind": "hero", "pos": Vector3(1.0, 0.0, 0.0), "size": Vector2.ONE,
			"asset": "hero:l2_sage", "alive": true},
	]})
	for id in ["avatar", "hero:1"]:
		assert_null(view.entity_mesh(id), "%s 는 씬 몸통이 그림을 맡는다" % id)
		var node: Node3D = view._nodes[id]
		var asset := node.get_node_or_null("Asset")
		assert_not_null(asset, "%s 에 몸통 씬이 붙는다" % id)
		if asset != null:
			assert_almost_eq(float(view._lifts[id]), FonsHeroBody.height(asset), 0.001,
				"%s HP 바 높이는 실제 몸통 높이" % id)
	view.free()


func test_dead_hero_dims_its_body() -> void:
	var view := FonsView3D.new()
	var entity := {"id": "hero:1", "kind": "hero", "pos": Vector3.ZERO, "size": Vector2.ONE,
		"asset": "hero:l1_knight", "alive": true}
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [entity]})
	var asset: Node = view._nodes["hero:1"].get_node("Asset")
	var alive := _hide_color(asset)
	var dead: Dictionary = entity.duplicate(true)
	dead["alive"] = false
	view.apply({"mode": "field", "field": Vector2(40, 28), "entities": [dead]})
	assert_eq(_hide_color(asset), alive * FonsView3D.DEAD_FADE, "죽은 영웅은 어두워진다")
	view.free()


func _hide_color(asset: Node) -> Color:
	var hide := asset.get_node("body_hide") as MeshInstance3D
	var material := hide.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(material, "몸통에 틴트 재질이 있다")
	return material.albedo_color if material != null else Color.WHITE
