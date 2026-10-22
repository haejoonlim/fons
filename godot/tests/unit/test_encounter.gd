extends GutTest
## 06 §3.4 생태 조우 편성 — habitat 1차 · 온도 2차 · 인접 블록 폴백.
## 원본은 Unity C# `EcologyEncounter` 다. 이 저장소에는 아직 포팅이 없었다 (06 §3.4 각주).
##
## 계약은 전부 GDD 06 이 말한 것이다:
##   후보 = monsters.json ∩ biome.habitat (일반+엘리트) → 4종 미만이면 층대 ±1블록 병합
##   스폰 = 후보 ∩ 온도 band (elemental·guardian·undead 는 면역)
##   편성 = 3~5종 · 중심 tier = 층 스케일 · 같은 tier 거리 안에서만 접촉 번호로 회전

const FLOORS := 130


func _plan(floor: int) -> Dictionary:
	return FonsEncounter.plan_for_floor(DataLoader.get_monsters(), DataLoader.get_biomes(), floor)


func _party(floor: int, contact: int = 0) -> Array:
	return FonsEncounter.build_party(DataLoader.get_monsters(), DataLoader.get_biomes(), floor, contact)


func test_biomes_cover_every_floor() -> void:
	var seen := {}
	for floor in range(1, FLOORS + 1):
		var biome: Dictionary = FonsEncounter.biome_for_floor(DataLoader.get_biomes(), floor)
		assert_false(biome.is_empty(), "%d층에 바이옴이 없다" % floor)
		if not biome.is_empty():
			seen[biome.get("id", "")] = true
	assert_eq(seen.size(), 26, "26바이옴이 130층을 덮어야 한다")


func test_every_floor_has_candidates() -> void:
	# 06 §3.4 폴백의 목적이 이것이다 — 빈 편성 금지.
	# 원본 Unity 는 이 자리가 비어 있어도 로그 한 줄만 남겼다.
	var empty := []
	for floor in range(1, FLOORS + 1):
		if _plan(floor)["candidates"].is_empty():
			empty.append(floor)
	assert_eq(empty, [], "후보 0층: %s" % str(empty))


func test_temperature_gate_empties_nothing() -> void:
	var emptied := []
	for floor in range(1, FLOORS + 1):
		if _plan(floor)["temperature_emptied"]:
			emptied.append(floor)
	assert_eq(emptied, [], "온도 게이트가 후보를 전멸시킨 층: %s" % str(emptied))


func test_party_size_is_three_to_five() -> void:
	for floor in range(1, FLOORS + 1):
		var party := _party(floor)
		assert_true(party.size() >= 3 and party.size() <= 5,
			"%d층 편성 %d종 (3~5종)" % [floor, party.size()])


func test_party_comes_only_from_candidates() -> void:
	for floor in range(1, FLOORS + 1):
		var allowed := {}
		for m in _plan(floor)["candidates"]:
			allowed[m["id"]] = true
		for m in _party(floor):
			assert_true(allowed.has(m["id"]), "%d층 후보에 없는 %s" % [floor, m["id"]])


func test_world_and_boss_never_selected() -> void:
	# D-261 — world 는 전투 조우에 절대 안 나온다. 보스는 게이트키퍼 경로가 따로 맡는다.
	for floor in range(1, FLOORS + 1):
		for m in _party(floor):
			var mode: String = String(m.get("spawn", {}).get("mode", ""))
			assert_true(mode == "encounter" or mode == "elite",
				"%d층에 %s(mode=%s) 편성" % [floor, m["id"], mode])


func test_same_floor_and_contact_is_deterministic() -> void:
	var a := _party(37, 3)
	var b := _party(37, 3)
	assert_eq(_ids(a), _ids(b), "같은 층 + 같은 접촉 = 같은 편성")


func test_party_always_contains_nearest_tier() -> void:
	# 06 §3.7 — 회전은 같은 tier 거리 그룹 안에서만 일어난다.
	# 그러므로 중심 tier 에 가장 가까운 종은 접촉 번호와 무관하게 항상 들어온다.
	for floor in range(1, FLOORS + 1):
		var candidates: Array = _plan(floor)["candidates"]
		var center := FonsEncounter.center_tier_for_floor(DataLoader.get_biomes(), floor, candidates)
		var nearest := 99
		for m in candidates:
			nearest = mini(nearest, absi(int(m["tier"]) - center))
		for contact in range(0, 6):
			var has_nearest := false
			for m in _party(floor, contact):
				if absi(int(m["tier"]) - center) == nearest:
					has_nearest = true
					break
			assert_true(has_nearest, "%d층 접촉%d — 중심 tier 이웃이 편성에 없다" % [floor, contact])


func test_contact_rotation_never_changes_tier_distance_mix() -> void:
	# 06 §3.7 — 회전은 **같은 tier 거리 그룹 안에서만** 일어난다. 그러므로 접촉 번호가 바뀌어도
	# 중심에서의 거리 구성은 같다. (tier 자체는 distance 1 안에서 2층과 4층이 섞이므로 달라질 수 있다)
	for floor in range(1, FLOORS + 1):
		var candidates: Array = _plan(floor)["candidates"]
		var center := FonsEncounter.center_tier_for_floor(DataLoader.get_biomes(), floor, candidates)
		var base := _distances(_party(floor, 0), center)
		for contact in range(1, 6):
			assert_eq(_distances(_party(floor, contact), center), base,
				"%d층 접촉%d 의 중심 거리 구성이 접촉0 과 다르다" % [floor, contact])


func test_contact_rotation_splits_a_tie_group() -> void:
	# 접촉 회전이 실제로 도는지 합성 풀로 확인한다 — 같은 tier 6종 · k=5 면 6가지가 나온다.
	# (실데이터에서는 tier 거리 그룹이 1종뿐인 층이 있어 회전 여지가 없다. 그건 결함이 아니다)
	var candidates := []
	for i in range(0, 6):
		candidates.append({"id": "syn_%d" % i, "tier": 2})
	var combos := {}
	for contact in range(0, 6):
		var picked := FonsEncounter.select_by_floor_center(candidates, 5, DataLoader.get_biomes(), 6, contact)
		assert_eq(picked.size(), 5, "접촉%d 편성 규모" % contact)
		combos[_ids(picked)] = true
	assert_eq(combos.size(), 6, "같은 tier 6종에서 접촉 6개가 6가지를 내야 한다")


func test_fallback_only_when_pool_is_short() -> void:
	for floor in range(1, FLOORS + 1):
		var plan := _plan(floor)
		var short := int(plan["pool_before_fallback"]) < FonsEncounter.POOL_MIN
		assert_eq(bool(plan["fallback_used"]), short, "%d층 폴백 판정" % floor)
		if short:
			assert_true(plan["candidates"].size() >= int(plan["pool_before_fallback"]),
				"%d층 폴백이 후보를 줄였다" % floor)


func test_center_tier_depends_on_floor_not_on_contact() -> void:
	# 06 §3.7 — 중심 tier 은 **층만** 본다. 후보를 부분집합으로 바꿔도 같은 층이면 같은 값,
	# 접촉 번호도 보지 않는다.
	for floor in range(1, FLOORS + 1):
		var candidates: Array = _plan(floor)["candidates"]
		var center := FonsEncounter.center_tier_for_floor(DataLoader.get_biomes(), floor, candidates)
		assert_true(center >= 1 and center <= 5, "%d층 중심 tier %d (1~5)" % [floor, center])
		var subset := candidates.slice(0, maxi(1, candidates.size() - 1))
		assert_eq(FonsEncounter.center_tier_for_floor(DataLoader.get_biomes(), floor, subset), center,
			"%d층 — 후보가 줄면 중심 tier 이 흔들렸다 (층이 아니라 풀을 보고 있다)" % floor)


func test_target_tier_rises_with_depth() -> void:
	# 130층을 tier 5개로 나눔 — 26층씩. 새 수치 없음(130·5 둘 다 정본).
	assert_eq(FonsEncounter.target_tier(1), 1)
	assert_eq(FonsEncounter.target_tier(26), 1)
	assert_eq(FonsEncounter.target_tier(27), 2)
	assert_eq(FonsEncounter.target_tier(130), 5)
	var last := 1
	for floor in range(1, FLOORS + 1):
		var t := FonsEncounter.target_tier(floor)
		assert_true(t >= last, "%d층 목표 tier 가 내려갔다 (%d → %d)" % [floor, last, t])
		last = t


func test_center_tier_never_resets_below_the_depth_target() -> void:
	# 이전엔 바이옴 5층 구간마다 tier 가 1 로 되돌아가서 76층이 75층보다, 101층이 100층보다 쉬웠다.
	for floor in range(1, FLOORS + 1):
		var candidates: Array = _plan(floor)["candidates"]
		var center := FonsEncounter.center_tier_for_floor(DataLoader.get_biomes(), floor, candidates)
		assert_true(center >= FonsEncounter.target_tier(floor),
			"%d층 중심 tier %d < 목표 %d" % [floor, center, FonsEncounter.target_tier(floor)])


func test_weak_biome_borrows_stronger_neighbors() -> void:
	# 유리 사막(24번 블록)은 최고 tier 4 뿐인데 116~120층의 목표는 tier 5 다.
	# 보충이 없으면 그 블록만 쉽게 뚫리고, 그게 대역 승률을 거꾸로 오르게 했다.
	var floors := []
	for floor in range(1, FLOORS + 1):
		var plan := _plan(floor)
		if not bool(plan["tier_shortfall_used"]):
			continue
		floors.append(floor)
		# 보증하는 것: 보충 후 후보 최대 tier 가 자체 풀보다 **줄지 않는다**.
		# 목표 도달까지 보증하지는 않는다 — 온도 게이트가 더 섞종을 거를 수 있다(105층 실측).
		assert_true(int(_max_tier(plan["candidates"])) >= FonsEncounter._max_tier(
			FonsEncounter._collect_habitat_pool(DataLoader.get_monsters(),
				FonsEncounter.biome_for_floor(DataLoader.get_biomes(), floor))),
			"%d층 보충이 풀을 약하게 만들었다" % floor)
	assert_gt(floors.size(), 0, "tier 가 모자란 층이 하나도 없다 — 보충 경로가 안 돌았다")
	# 알려진 사례: 유리 사막 116층은 이웃에서 tier 5 를 빌려 목표에 닻는다.
	assert_true(int(_max_tier(_plan(116)["candidates"])) >= 5, "116층 보충이 tier 5 에 못 닿았다")


func test_composition_varies_within_a_block() -> void:
	# 중심 tier 를 깊이 목표로 올린 뒤에도 블록 안 5층의 편성이 같아지면, 06 §3.4 가 고쳤던
	# "130층에 편성 26개뿐" 회귀다. 조합 수로 그 회귀를 막는다.
	var combos := {}
	for floor in range(1, FLOORS + 1):
		var tiers := []
		for m in _party(floor):
			tiers.append(int(m["tier"]))
		tiers.sort()
		combos["%s|%s" % [_plan(floor)["biome_id"], str(tiers)]] = true
	assert_gt(combos.size(), 26, "고유 편성 %d — 블록 단위 반복으로 퇴화했다" % combos.size())


func _max_tier(pool: Array) -> int:
	var top := 0
	for m in pool:
		top = maxi(top, int(m.get("tier", 1)))
	return top


func _ids(party: Array) -> Array:
	var out := []
	for m in party:
		out.append(m["id"])
	out.sort()
	return out


func _distances(party: Array, center: int) -> Array:
	var out := []
	for m in party:
		out.append(absi(int(m["tier"]) - center))
	out.sort()
	return out


func test_gatekeeper_floors_are_five_ten_fifteen_twenty() -> void:
	# 02 조우 모드 — 게이트키퍼층은 5/10/15/20 고정.
	assert_eq(FonsEncounter.GATEKEEPER_FLOORS, [5, 10, 15, 20])
	for floor in [5, 10, 15, 20]:
		assert_true(FonsEncounter.is_gatekeeper_floor(floor))
		assert_false(FonsEncounter.gatekeeper_for_floor(DataLoader.get_monsters(), floor).is_empty(),
			"%d층에 문지기가 있어야 한다" % floor)
	assert_true(FonsEncounter.gatekeeper_for_floor(DataLoader.get_monsters(), 6).is_empty(),
		"6층은 게이트키퍼층이 아니다")


func test_gatekeeper_is_boss_mode_and_single() -> void:
	var gk := FonsEncounter.gatekeeper_for_floor(DataLoader.get_monsters(), 5)
	assert_eq(gk["id"], "mon_doppelganger_01", "5층 문지기 = 도플갱어")
	assert_eq(String(gk["spawn"]["mode"]), "boss")
	# 일반 편성 풀에는 boss 가 안 섞인다 — 두 축을 섞으면 문지기가 3~5종 중 하나가 된다.
	for m in FonsEncounter.build_party(DataLoader.get_monsters(), DataLoader.get_biomes(), 5, 0):
		assert_ne(String(m.get("spawn", {}).get("mode", "")), "boss")


func test_gatekeeper_scale_is_linear_to_ref_floor() -> void:
	# 02 보스 스케일 — HP·ATK × (배치층 / bossScaleRefFloor). 층 스케일을 다시 곱하지 않는다.
	var gk := FonsEncounter.gatekeeper_for_floor(DataLoader.get_monsters(), 5)
	var scaled := FonsScaling.scale_gatekeeper(gk, 5)
	var ref := int(gk["spawn"]["bossScaleRefFloor"])
	var mul := 5.0 / float(ref)
	assert_eq(int(scaled["stats"]["hp"]), maxi(1, int(roundf(float(gk["stats"]["hp"]) * mul))))
	assert_eq(int(scaled["stats"]["atk"]), maxi(1, int(roundf(float(gk["stats"]["atk"]) * mul))))
	assert_eq(int(scaled["stats"]["def"]), int(gk["stats"]["def"]), "DEF 는 이 식의 대상이 아니다")
