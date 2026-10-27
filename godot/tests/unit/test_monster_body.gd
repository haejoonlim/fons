extends GutTest
## S5b — 생물 몸통 3종과 종별 색·크기 파생.
##
## 계약은 셋이다.
##   1. 대역 셋(heavy·small·odd)이 실제 `.glb` 로 임포트되고 부품 이름이 다섯 노드다.
##   2. 78칸 전부가 대역·원소색·배율로 풀린다 — 뷰는 키 매핑만 보고 그린다.
##   3. 틴트는 몸통 부품만 바꾼다 — 뿔·눈은 구운 색을 지킨다.

const PLANS := {
	"heavy": "res://assets/art/models/creature_heavy.glb",
	"small": "res://assets/art/models/creature_small.glb",
	"odd": "res://assets/art/models/creature_odd.glb",
}
const PARTS := ["body_hide", "body_belly", "skin_limb", "horn_spike", "eye_dark"]
const ASSETS := "res://data/monster_assets.json"
const MONSTERS := "res://data/monsters.json"


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s 를 읽는다" % path)
	return parsed if parsed is Dictionary else {}


func _picks() -> Array:
	var out: Array = []
	for row in _json(ASSETS).get("biomes", []):
		for pick in (row as Dictionary).get("monsters", []):
			out.append(pick)
	return out


func _meshes(node: Node) -> Dictionary:
	var out := {}
	for child in node.find_children("*", "MeshInstance3D", true, false):
		out[String(child.name)] = child
	return out


func test_three_body_plans_are_imported_with_the_five_part_contract() -> void:
	for band in PLANS:
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
			assert_gt((meshes[part] as MeshInstance3D).mesh.get_surface_count(), 0,
				"%s 의 %s 는 메시가 있다" % [band, part])
		assert_gt(FonsMonsterBody.height(instance), 0.8, "%s 는 설 수 있는 높이다" % band)
		instance.free()


func test_every_pick_resolves_to_a_band_and_a_color() -> void:
	var picks := _picks()
	assert_eq(picks.size(), 78, "26 × 3")
	for entry in picks:
		var pick: Dictionary = entry
		var id := String(pick.get("id", ""))
		var visual := FonsMonsterBody.visual("monster:" + id)
		assert_false(visual.is_empty(), "%s 가 몸통으로 풀린다" % id)
		assert_eq(String(visual.get("band", "")), String(pick.get("band", "")),
			"%s 대역이 키 매핑과 같다" % id)
		assert_true(PLANS.has(String(visual.get("band", ""))), "%s 대역에 몸통 파일이 있다" % id)
		assert_eq(FonsMonsterBody.band_for(id), String(pick.get("band", "")),
			"prefix 없는 id 도 받는다")
		var scale := float(visual.get("scale", 0.0))
		assert_between(scale, FonsMonsterBody.TIER_SCALE_BASE,
			FonsMonsterBody.TIER_SCALE_BASE + FonsMonsterBody.TIER_SCALE_STEP * 4.0
			+ FonsMonsterBody.ELITE_SCALE, "%s 배율 범위" % id)


func test_element_picks_the_hue_and_none_stays_gray() -> void:
	var fire := FonsMonsterBody.element_color("fire")
	assert_almost_eq(fire.h, FonsMonsterBody.ELEMENT_HUE["fire"], 0.01, "불 = 붉은 색상")
	assert_gt(fire.s, 0.4, "원소색은 회색이 아니다")
	var water := FonsMonsterBody.element_color("water")
	assert_gt(absf(water.h - fire.h), 0.3, "물과 불은 색상이 갈린다")
	assert_almost_eq(FonsMonsterBody.element_color("none").s, 0.0, 0.001,
		"원소 없음 = 회색 — 색이 뜻을 갖지 않는다")


func test_scale_grows_with_tier_and_elite() -> void:
	## 같은 tier 면 elite 가 더 크고, tier 가 오르면 작아지지 않는다.
	var by_tier := {}
	var elite_by_tier := {}
	for monster in _json(MONSTERS).get("monsters", []):
		var mon: Dictionary = monster
		var visual := FonsMonsterBody.visual("monster:" + String(mon.get("id", "")))
		if visual.is_empty():
			continue
		var tier := int(mon.get("tier", 1))
		var is_elite := bool((mon.get("spawn", {}) as Dictionary).get("elite", false))
		var bucket: Dictionary = elite_by_tier if is_elite else by_tier
		bucket[tier] = maxf(float(bucket.get(tier, 0.0)), float(visual.get("scale", 0.0)))
	var previous := 0.0
	for tier in range(1, 6):
		if not by_tier.has(tier):
			continue
		assert_gt(float(by_tier[tier]), previous, "tier %d 가 아래 tier 보다 작지 않다" % tier)
		previous = float(by_tier[tier])
	for tier in elite_by_tier:
		if not by_tier.has(tier):
			continue
		assert_gt(float(elite_by_tier[tier]), float(by_tier[tier]),
			"tier %d elite 가 같은 tier 일반보다 크다" % tier)


func test_species_outside_the_78_picks_follow_their_ecology_role() -> void:
	## 78칸은 바이옴 대표 3종이다. 실제 편성은 그 밖의 종도 부른다 — 1~130층 121종 중 52종.
	## 그때도 콘이 아니라 대역 몸통이 서야 조우 화면이 한 몸통 규칙을 지킨다.
	## 대역은 새로 정하지 않는다 — `monster_assets.json` meta.bands 의 역할표를 그대로 쓴다.
	var meta: Dictionary = _json(ASSETS).get("meta", {})
	var bands: Dictionary = meta.get("bands", {})
	assert_false(bands.is_empty(), "meta.bands 역할표가 있다")
	var picked := {}
	for pick in _picks():
		picked[String((pick as Dictionary).get("id", ""))] = true
	var covered := {}
	for monster in _json(MONSTERS).get("monsters", []):
		var mon: Dictionary = monster
		var id := String(mon.get("id", ""))
		if picked.has(id):
			continue
		var role := String((mon.get("ecology", {}) as Dictionary).get("role", ""))
		var want := ""
		for band in bands:
			if role in (bands[band] as Array):
				want = String(band)
		if want.is_empty():
			continue
		assert_eq(FonsMonsterBody.band_for("monster:" + id), want, "%s(%s) → %s" % [id, role, want])
		var visual := FonsMonsterBody.visual("monster:" + id)
		assert_false(visual.is_empty(), "%s 도 몸통으로 풀린다" % id)
		assert_true(PLANS.has(String(visual.get("band", ""))), "%s 대역에 몸통 파일이 있다" % id)
		covered[want] = true
	assert_eq(covered.size(), 3, "세 대역 모두 매핑 밖 종에서 채워진다")


func test_pick_still_wins_over_the_role_table() -> void:
	## 바이옴 대표 3종은 손으로 고른 대역을 지킨다 — 역할표가 덮어쓰면 시트가 바뀐다.
	for entry in _picks():
		var pick: Dictionary = entry
		assert_eq(FonsMonsterBody.band_for("monster:" + String(pick.get("id", ""))),
			String(pick.get("band", "")), "%s 는 키 매핑이 이긴다" % String(pick.get("id", "")))


func test_unknown_key_has_no_body() -> void:
	assert_true(FonsMonsterBody.visual("monster:slime").is_empty(), "키 매핑에 없는 종은 폴백")
	assert_eq(FonsMonsterBody.band_for("monster:slime"), "", "대역 없음")
	assert_null(FonsMonsterBody.scene(""), "몸통 파일이 없는 대역은 null")


func test_tint_touches_body_parts_only() -> void:
	var scene := FonsMonsterBody.scene("heavy")
	assert_not_null(scene, "heavy 몸통")
	if scene == null:
		return
	var instance := scene.instantiate()
	var color := FonsMonsterBody.element_color("fire")
	FonsMonsterBody.apply(instance, color)
	var meshes := _meshes(instance)
	var hide := meshes["body_hide"] as MeshInstance3D
	assert_not_null(hide.get_surface_override_material(0), "몸통은 틴트 재질로 덮인다")
	assert_eq((hide.get_surface_override_material(0) as StandardMaterial3D).albedo_color, color,
		"몸통 = 원소색")
	var belly := meshes["body_belly"] as MeshInstance3D
	assert_eq((belly.get_surface_override_material(0) as StandardMaterial3D).albedo_color,
		color.darkened(0.15), "배는 한 단계 어둡다 — 실루엣에 깊이")
	assert_null((meshes["horn_spike"] as MeshInstance3D).get_surface_override_material(0),
		"뿔은 구운 색을 지킨다")
	assert_null((meshes["eye_dark"] as MeshInstance3D).get_surface_override_material(0),
		"눈은 원소색에 물들지 않는다")
	instance.free()


func test_view_mounts_the_band_body_for_a_real_monster_key() -> void:
	var pick: Dictionary = _picks()[0]
	var id := String(pick.get("id", ""))
	var view := FonsView3D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [{
		"id": "monster:1", "kind": "monster", "pos": Vector3.ZERO,
		"size": Vector2.ONE, "asset": "monster:" + id,
	}]})
	assert_null(view.entity_mesh("monster:1"), "몸통 씬이 그림을 맡는다 — 폴백 도형은 비어 있다")
	var node: Node3D = view._nodes["monster:1"]
	var asset := node.get_node_or_null("Asset")
	assert_not_null(asset, "몸통 씬이 붙는다")
	if asset != null:
		var scale := (asset as Node3D).scale.x
		assert_gt(scale, 0.0, "배율이 걸린다")
		assert_almost_eq(float(view._lifts["monster:1"]),
			FonsMonsterBody.height(asset) * scale, 0.001, "HP 바 높이는 실제 몸통 높이")
	view.free()


func test_dead_monster_dims_its_body() -> void:
	## 씬 몸통은 폴백 메시처럼 material_override 로 죽음을 알릴 수 없다 — 재질을 다시 곱한다.
	var pick: Dictionary = _picks()[0]
	var view := FonsView3D.new()
	var entity := {
		"id": "monster:1", "kind": "monster", "pos": Vector3.ZERO,
		"size": Vector2.ONE, "asset": "monster:" + String(pick.get("id", "")), "alive": true,
	}
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [entity]})
	var asset: Node = view._nodes["monster:1"].get_node("Asset")
	var alive := _hide_color(asset)
	var dead: Dictionary = entity.duplicate(true)
	dead["alive"] = false
	view.apply({"mode": "field", "field": Vector2(40, 28), "entities": [dead]})
	assert_eq(_hide_color(asset), alive * FonsView3D.DEAD_FADE, "죽으면 몸통이 어두워진다")
	view.free()


func _hide_color(asset: Node) -> Color:
	var hide := asset.get_node("body_hide") as MeshInstance3D
	var material := hide.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(material, "몸통에 틴트 재질이 있다")
	return material.albedo_color if material != null else Color.WHITE
