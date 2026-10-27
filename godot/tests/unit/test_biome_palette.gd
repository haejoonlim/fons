extends GutTest
## 바이옴 파생색 — 정본 수치(`climate.ambient` · `category`)에서 식생·암석·대기 색을 뽑는다.
## 수치 자체는 가안이다 (docs/design/바이옴_에셋_계획.md §4). 여기서 잠그는 것은 값이 아니라
## **방향**이다: 식생은 한랭 청록 ~ 고온 올리브, 암석은 낮은 채도, 대기는 기후를 따른다.
##
## 2026-10-24 이전 규칙은 온도축을 회색→파랑/주황으로 이었고, 회색과 파랑의 색상각이 같아
## 26색 중 21색이 같은 파랑으로 접혔다. 아래 첫 테스트가 그 회귀를 막는다.


func _biome(ambient: float, category: String) -> Dictionary:
	return {"climate": {"ambient": ambient}, "category": category}


func _tints(ambient: float, category: String) -> Dictionary:
	return FonsBiomePalette.from_biome(_biome(ambient, category))["tints"]


func test_unknown_biome_keeps_the_dark_studio_look() -> void:
	var palette := FonsBiomePalette.from_biome({})
	assert_eq(palette["sky"], FonsBiomePalette.DEFAULT_SKY)
	assert_eq(palette["ground"], FonsBiomePalette.DEFAULT_GROUND)
	assert_eq(palette["ambient"], FonsBiomePalette.DEFAULT_AMBIENT)
	assert_eq(palette["energy"], FonsBiomePalette.DEFAULT_ENERGY)
	assert_eq(palette["tints"], {}, "바이옴을 모르면 틴트도 없다 — 지금 모습 그대로")


func test_cold_vegetation_is_teal_and_hot_is_olive() -> void:
	## 식생은 파랑이 아니라 초록이다. 한랭과 고온은 청록↔올리브로 갈라진다.
	var cold: Color = _tints(-70.0, "extreme")["grass"]
	var hot: Color = _tints(60.0, "extreme")["grass"]
	assert_gt(cold.g, cold.b, "한랭 식생도 초록이 앞선다 — 예전 규칙은 여기서 파랑이었다")
	assert_gt(cold.h, hot.h, "한랭은 청록 쪽, 고온은 올리브 쪽")
	assert_gt(hot.r, hot.b + 0.2, "고온 식생은 노란 쪽으로 돈다")
	assert_gt(cold.b, hot.b + 0.05, "한랭 식생에는 파랑이 남아 있다")


func test_temperate_sky_is_daylight_and_cool() -> void:
	## 15℃ 를 한 직선의 65% 에 놓으면 풀바다가 갈색으로 읽혔고, sky 값을 낮게 두면
	## 해 질 녘으로 읽혔다 (2026-10-23 · 2026-10-25 스크린샷). 온대는 **파랑이 살아 있는 낮**이다.
	var sky: Color = FonsBiomePalette.from_biome(_biome(15.0, "calm"))["sky"]
	assert_gt(sky.v, 0.6, "낮 하늘 밝기 — 0.145 는 밤이다")
	assert_gt(sky.b, sky.r, "온대 하늘은 한색 쪽 — 갈색이 아니다")
	assert_gt(sky.g, sky.r, "초록 채널도 파랑 쪽에 붙는다 (노랑으로 안 간다)")


func test_every_biome_sky_is_daylit() -> void:
	## 26바이옴 전부. 하늘은 카메라가 늘 보는 배경이라 바이옴마다 시간대가 바뀌면
	## 세계가 아니라 조명을 보게 된다 — 어두운 카테고리도 '흐린 낮'이지 밤이 아니다.
	for ambient in [FonsBiomePalette.TEMP_MIN, -30.0, 0.0, 15.0, 45.0, FonsBiomePalette.TEMP_MAX]:
		for category in ["calm", "chaos", "dark", "extreme", "waterside", ""]:
			var sky: Color = FonsBiomePalette.from_biome(_biome(ambient, category))["sky"]
			assert_gte(sky.v, 0.55, "%s℃ %s — 낮 밝기" % [ambient, category])
			assert_lt(sky.s, 0.45, "%s℃ %s — 노을이 될 만큼 진하지 않다" % [ambient, category])


func test_temperate_sky_is_clear_and_hot_sky_stays_sand() -> void:
	## 2026-10-25: 0.30 은 평온이 흐린 회색이었다. 카테고리 편차를 절반만 따라 올렸다.
	## 상한은 0.46 — 그 위에서는 먼지벌판 하늘이 노란 필터가 되어 낮으로 안 읽힌다(시트 비교).
	var calm: Color = FonsBiomePalette.from_biome(_biome(15.0, "calm"))["sky"]
	assert_gte(calm.s, 0.28, "풀바다 하늘은 맑은 파랑 — 흐린 회색이 아니다")
	var hot: Color = FonsBiomePalette.from_biome(_biome(55.0, "extreme"))["sky"]
	assert_lte(hot.s, 0.44, "고온 하늘 채도 상한 — 노을로 돌아가기 전")
	assert_gte(hot.v, 0.75, "그래도 낮 밝기다")
	assert_gt(hot.h, 0.05, "색상각이 주황(0.05) 아래로 내려가지 않는다")


func test_hot_sky_is_hazier_than_cold_sky() -> void:
	## 고온 하늘은 먼지 섞인 옅은 모래빛, 한랭은 맑은 파랑 — 같은 파랑으로 접히면 안 된다.
	var cold: Color = FonsBiomePalette.from_biome(_biome(-60.0, "extreme"))["sky"]
	var hot: Color = FonsBiomePalette.from_biome(_biome(55.0, "extreme"))["sky"]
	assert_gt(cold.b, cold.r + 0.05, "한랭 하늘은 파랑이 앞선다")
	assert_gt(hot.r, hot.b, "고온 하늘은 따뜻한 쪽으로 돈다")
	assert_lt(hot.s, cold.s + 0.25, "그래도 노을만큼 진하지는 않다")


func test_category_drives_vegetation_saturation_and_light() -> void:
	var calm: Dictionary = FonsBiomePalette.from_biome(_biome(15.0, "calm"))
	var extreme: Dictionary = FonsBiomePalette.from_biome(_biome(15.0, "extreme"))
	var calm_grass: Color = calm["tints"]["grass"]
	var extreme_grass: Color = extreme["tints"]["grass"]
	assert_gt(extreme_grass.s, calm_grass.s, "extreme 은 채도가 높다")
	assert_gt(extreme_grass.v, calm_grass.v, "extreme 은 밝다")
	assert_gt(float(extreme["energy"]), float(calm["energy"]), "광량도 카테고리를 따른다")
	var dark_grass: Color = FonsBiomePalette.from_biome(_biome(15.0, "dark"))["tints"]["grass"]
	assert_lt(dark_grass.s, calm_grass.s, "dark 는 채도가 낮다")


func test_rock_tint_stays_low_saturation_and_follows_climate() -> void:
	var cold: Color = _tints(-70.0, "extreme")["rock"]
	var hot: Color = _tints(60.0, "extreme")["rock"]
	assert_lte(cold.s, FonsBiomePalette.ROCK_SATURATION_MAX + 0.001, "돌은 흙·잎보다 회색에 가깝다")
	assert_gt(cold.b, cold.r, "한랭 암석은 청회")
	assert_gt(hot.r, hot.b, "고온 암석은 적갈")
	assert_ne(cold, hot)


func test_unknown_category_falls_back_to_the_default_gain() -> void:
	var plain := FonsBiomePalette.from_biome({"climate": {"ambient": 15.0}})
	var named := FonsBiomePalette.from_biome(_biome(15.0, "없는분류"))
	assert_eq(plain["ground"], named["ground"], "카테고리가 없어도 같은 기본값")


func test_derivation_is_deterministic() -> void:
	var biome := _biome(11.0, "dark")
	assert_eq(FonsBiomePalette.from_biome(biome), FonsBiomePalette.from_biome(biome),
		"층을 다시 그려도 같은 색")


## ── 같은 키트를 쓰는 바이옴이 갈라지는가 ────────────────────────────────

func test_same_kit_biomes_get_different_vegetation() -> void:
	## 뿌리숲(12℃ · calm)과 포식밀림(27℃ · chaos)은 같은 topo_natural_surface 를 쓴다.
	var forest: Color = _tints(12.0, "calm")["grass"]
	var jungle: Color = _tints(27.0, "chaos")["grass"]
	assert_ne(forest, jungle, "같은 키트라도 식생 색이 다르다")
	assert_gt(jungle.r, forest.r, "더운 바이옴은 노란 쪽으로 읽힌다")
	assert_gt(forest.b, jungle.b, "서늘한 바이옴은 파랑이 더 남는다")


func test_cold_biomes_do_not_collapse_to_one_hue() -> void:
	## 예전 규칙은 한랭 8바이옴이 전부 `#8eb4ff` 였다. 이제 한랭 축에서도 색이 움직인다.
	var grass := {}
	var rock := {}
	for ambient in [-70.0, -62.0, -46.0, -38.0, -30.0, -22.0, -12.0]:
		var tints := _tints(ambient, "extreme")
		grass[(tints["grass"] as Color).to_html(false)] = true
		rock[(tints["rock"] as Color).to_html(false)] = true
	assert_eq(grass.size(), 7, "한랭 7바이옴이 서로 다른 식생 색")
	assert_eq(rock.size(), 7, "암석 색도 같다")


func test_categories_stay_distinct_at_one_temperature() -> void:
	## 같은 온도라도 평온·혼돈·어둠·극한·물가는 채도·명도로 갈라진다.
	var grass := {}
	for category in ["calm", "chaos", "dark", "extreme", "waterside"]:
		grass[(_tints(15.0, category)["grass"] as Color).to_html(false)] = true
	assert_eq(grass.size(), 5)
