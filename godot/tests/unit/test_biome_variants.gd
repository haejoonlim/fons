extends GutTest
## S4 — 같은 키트를 쓰는 바이옴이 화면에서 갈라지는가.
##
## S3 에서 구조(실루엣)는 갈렸다. 남은 것은 키트가 같은 짝이다 — 서고·미궁도시·폐허·침전수로는
## 모두 `topo_urban_ruins`, 원천연안·부끼 이끼늪·정점은 `topo_wetland_water`, 수정 군락·유리 사막은
## `topo_rock_cavern_mountain` 이다. 색으로 더 벌리면 다른 바이옴이 망가지므로(계획 §9)
## **프롭 배분**과 **라이팅 프리셋**으로 가른다. 이 파일이 그 두 축을 잠근다.

const ASSETS := "res://data/biome_assets.json"
const BIOMES := "res://data/biomes.json"

## 프롭 총량 범위 — 필드 40×28 에서 12 미만이면 빈 판, 36 초과면 지형이 묻힌다.
const PROP_MIN := 12
const PROP_MAX := 36


func _biome_doc() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BIOMES))
	assert_true(parsed is Dictionary, "biomes.json 을 읽는다")
	return parsed


func _biomes() -> Array:
	var out: Array = []
	for group in _biome_doc().get("groups", []):
		for biome in (group as Dictionary).get("biomes", []):
			out.append(biome)
	return out


func _biome(id: String) -> Dictionary:
	for biome in _biomes():
		if String((biome as Dictionary).get("id", "")) == id:
			return biome
	fail_test("바이옴이 없다: %s" % id)
	return {}


func _asset_rows() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSETS))
	assert_true(parsed is Dictionary, "biome_assets.json 을 읽는다")
	return (parsed as Dictionary).get("biomes", [])


func _prop_names(kit: String) -> Array:
	## GLB 안의 프롭 부품 접미사 — data 의 part 와 대조하는 유일한 근거다.
	var scene := load("res://assets/art/models/%s.glb" % kit) as PackedScene
	assert_not_null(scene, "%s 가 임포트되어 있다" % kit)
	var root := scene.instantiate()
	var names := _parts(root)
	root.free()
	return names


func _parts(node: Node, out: Array = []) -> Array:
	if String(node.name).begins_with("prop_"):
		out.append(String(node.name).trim_prefix("prop_"))
	for child in node.get_children():
		_parts(child, out)
	return out


func _placed_props(root: Node) -> Array:
	## `build()` 가 실제로 깐 프롭 인스턴스의 부품 이름. 메타 `kit_part` 가 계약이다.
	var out: Array = []
	for child in root.get_children():
		var part := String(child.get_meta("kit_part", ""))
		if part.begins_with("prop_"):
			out.append(part.trim_prefix("prop_"))
	return out


func test_every_biome_has_a_prop_plan_for_its_own_kit() -> void:
	## 키가 가리키는 부품이 그 키트 GLB 에 실제로 있어야 한다 — 이름이 어긋나면
	## 프롭이 하나도 안 서는데 테스트는 통과하는 침묵 실패가 된다.
	var rows := _asset_rows()
	assert_eq(rows.size(), 26, "바이옴 26")
	var by_kit := {}
	for row in rows:
		var data: Dictionary = row
		var kit := String(data.get("kit", ""))
		var parts: Array = _prop_names(kit)
		assert_eq(parts.size(), 4, "%s 프롭 부품 4" % kit)
		var props: Array = data.get("props", [])
		assert_eq(props.size(), 4, "%s 는 프롭 네 종을 모두 쓴다" % String(data.get("id", "")))
		var total := 0
		for entry in props:
			var prop: Dictionary = entry
			var part := String(prop.get("part", ""))
			var count := int(prop.get("n", 0))
			assert_true(parts.has(part), "%s 에 prop_%s 가 있다" % [kit, part])
			assert_eq(String(prop.get("key", "")), "prop:%s:%s" % [kit, part],
				"키 규칙 prop:<kit>:<part>")
			assert_gt(count, 0, "%s 개수가 0보다 크다" % part)
			total += count
		assert_between(total, PROP_MIN, PROP_MAX, "%s 프롭 %d개" % [String(data.get("id", "")), total])
		by_kit[kit] = int(by_kit.get(kit, 0)) + 1
	assert_eq(by_kit.size(), 9, "키트 9종")


func test_same_kit_biomes_get_different_prop_mixes() -> void:
	## 서고↔미궁도시↔폐허↔침전수로처럼 키트·카테고리가 겹치는 짝이 여기서 갈린다.
	## 개수 벡터가 같으면 두 바이옴은 화면에서 같은 프롭 밭이다.
	var sigs := {}
	for row in _asset_rows():
		var data: Dictionary = row
		var counts: Array = []
		for entry in data.get("props", []):
			counts.append(int((entry as Dictionary).get("n", 0)))
		var kit := String(data.get("kit", ""))
		var key := "%s|%s" % [kit, str(counts)]
		assert_false(sigs.has(key), "%s 와 %s 는 같은 프롭 배분이다"
			% [String(data.get("id", "")), String(sigs.get(key, ""))])
		sigs[key] = String(data.get("id", ""))


func test_kit_places_exactly_the_plan_and_nothing_else() -> void:
	## 계획이 있으면 `PROP_COUNT` 를 무시한다 — 24개를 그대로 두면 바이옴별 배분이 무의미해진다.
	var scene := load("res://assets/art/models/topo_natural_surface.glb") as PackedScene
	assert_not_null(scene)
	var root := Node3D.new()
	var plan := {"bush": 5, "rock": 3, "flower": 2, "stump": 1}
	var placed := FonsBiomeKit.build(root, scene, Vector2(40, 28), 7, [], {}, false,
		Callable(), Callable(), [], [], 0.0, plan)
	var props := _placed_props(root)
	assert_eq(props.size(), 11, "계획 합계 11개만 깐다 (폴백 24개가 아니다)")
	var counts := {}
	for part in props:
		counts[part] = int(counts.get(part, 0)) + 1
	for part in plan:
		assert_eq(int(counts.get(part, 0)), int(plan[part]), "%s 개수" % part)
	assert_eq(placed, 11 + 3, "높이 2 + 랜드마크 1 이 더해진 반환값")
	root.free()


func test_unknown_biome_keeps_the_pilot_fallback() -> void:
	## 바이옴을 모르는 화면(전투·헤드리스)은 예전 동작 그대로여야 한다.
	assert_true(FonsBiomeKit.plan("").is_empty(), "빈 id 는 계획이 없다")
	assert_true(FonsBiomeKit.plan("biome_없는_바이옴").is_empty(), "모르는 id 도 빈 계획")
	var scene := load("res://assets/art/models/topo_natural_surface.glb") as PackedScene
	var root := Node3D.new()
	FonsBiomeKit.build(root, scene, Vector2(40, 28), 7, [], {}, false,
		Callable(), Callable(), [], [])
	assert_eq(_placed_props(root).size(), FonsBiomeKit.PROP_COUNT, "폴백은 파일럿 24개")
	root.free()


func test_lighting_preset_separates_same_kit_biomes() -> void:
	## 서고(평온)·미궁도시(혼돈)·폐허(혼돈)·침전수로(혼돈)는 키트가 같다. 빛이 갈라야 한다.
	var library := FonsBiomePalette.from_biome(_biome("biome_library"))
	var maze := FonsBiomePalette.from_biome(_biome("biome_maze_city"))
	var sewer := FonsBiomePalette.from_biome(_biome("biome_sewer"))
	assert_gt(float(library["fill"]), float(maze["fill"]), "서고 채움광이 미궁도시보다 세다")
	assert_gt(float(library["fill"]), float(sewer["fill"]), "서고 채움광이 수로보다 세다")
	assert_gt(float(sewer["fog"]), float(library["fog"]), "수로 안개가 서고보다 짙다")
	assert_ne(float(library["energy"]), float(maze["energy"]), "태양광도 같은 값이 아니다")


func test_sewer_is_dimmer_and_hazier_than_maze_city() -> void:
	## 같은 `chaos`·같은 키트라 카테고리 프리셋만으로는 둘이 화면에서 붙는다 (2026-10-28 시트).
	## 수로는 `light:dim` 으로 한 단 더 내려앉고, 미궁도시는 chaos 그대로다 — 동굴(`dark`)만큼은 아니다.
	var maze := FonsBiomePalette.from_biome(_biome("biome_maze_city"))
	var sewer := FonsBiomePalette.from_biome(_biome("biome_sewer"))
	var cave := FonsBiomePalette.from_biome(_biome("biome_cave"))
	assert_lt(float(sewer["energy"]), float(maze["energy"]), "수로 태양광이 미궁도시보다 약하다")
	assert_lt(float(sewer["fill"]), float(maze["fill"]), "수로 채움광이 더 낮다")
	assert_gt(float(sewer["fog"]), float(maze["fog"]), "수로 안개가 더 짙다")
	assert_gt(float(sewer["fill"]), float(cave["fill"]), "수로는 동굴만큼 어둡지 않다")


func test_light_dark_mod_is_darker_than_its_category() -> void:
	## 동굴(dark + light:dark)은 묘역(dark)보다 어둡고 짙어야 한다 — 카테고리만으로는
	## 낮의 어둠과 지하가 구분되지 않는다.
	var cave := FonsBiomePalette.from_biome(_biome("biome_cave"))
	var graveyard := FonsBiomePalette.from_biome(_biome("biome_graveyard"))
	assert_lt(float(cave["energy"]), float(graveyard["energy"]), "동굴이 더 어둡다")
	assert_lt(float(cave["fill"]), float(graveyard["fill"]), "동굴 채움광이 더 낮다")
	assert_gt(float(cave["fog"]), float(graveyard["fog"]), "동굴 안개가 더 짙다")


func test_no_biome_keeps_the_unknown_defaults() -> void:
	## 26바이옴 전부가 기본값과 다른 프리셋을 받아야 한다 — 하나라도 기본값이면
	## 그 바이옴만 조명이 안 걸린 것이고, 화면에서는 다른 키트처럼 보인다.
	var defaults := FonsBiomePalette.defaults()
	for biome in _biomes():
		var palette := FonsBiomePalette.from_biome(biome)
		var id := String((biome as Dictionary).get("id", ""))
		assert_ne(float(palette["fog"]), float(defaults["fog"]), "%s 안개" % id)


func _stream_snapshot(biome_id: String) -> Dictionary:
	return {
		"mode": "field",
		"field": Vector2(40, 28),
		"entities": [],
		"chunks": [Vector3.ZERO],
		"biome": biome_id,
		"kit": String(_biome(biome_id).get("topologyKit", "")),
		"palette": FonsBiomePalette.from_biome(_biome(biome_id)),
	}


func test_dense_fog_pulls_the_fog_span_closer() -> void:
	## 물가(안개 1.30)는 평온(0.95)보다 앞에서 잠긴다. 얇은 안개는 거리를 늘리지 않는다 —
	## 늘리면 지형 끝을 넘어 허공이 보인다.
	var clear := FonsView3D.new()
	clear.mount(_stream_snapshot("biome_plains"))
	var wet := FonsView3D.new()
	wet.mount(_stream_snapshot("biome_coastal_sea"))
	assert_lt(wet.fog_span().y, clear.fog_span().y, "물가 안개가 더 앞에서 잠긴다")
	assert_almost_eq(clear.fog_span().y,
		FonsView3D.fog_span_for(float(FonsView3D.VISUAL_RADIUS), Vector2(40, 28)).y, 0.001,
		"얇은 안개는 기본 거리를 그대로 쓴다")
	clear.free()
	wet.free()


func test_view_applies_the_fill_light() -> void:
	## 채움광이 실제 Environment 에 걸리는가 — 팔레트에만 있고 화면에 안 걸리면
	## 라이팅 프리셋은 문서에만 있는 값이다.
	var snapshot := _stream_snapshot("biome_cave")
	snapshot["palette"]["fill"] = 0.35
	var view := FonsView3D.new()
	view.mount(snapshot)
	assert_almost_eq(view._environment.ambient_light_energy, 0.35, 0.001,
		"심이 준 채움광을 그대로 건다")
	view.free()
