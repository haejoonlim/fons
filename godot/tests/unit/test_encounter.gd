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


func _no_combat(floor: int) -> bool:
	## 이데아 문턱(126~130)은 `difficulty.mods.noCombat` — 일반 조우가 없는 층이다.
	return FonsEncounter.is_combatless_biome(
		FonsEncounter.biome_for_floor(DataLoader.get_biomes(), floor))


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
	# 예외는 **일반 조우가 없는 바이옴**뿐이다 (이데아 문턱 · `noCombat`) — 그 빔은 규칙이다.
	var empty := []
	for floor in range(1, FLOORS + 1):
		if _no_combat(floor):
			continue
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
		if _no_combat(floor):
			continue
		var party := _party(floor)
		assert_true(party.size() >= 3 and party.size() <= 5,
			"%d층 편성 %d종 (3~5종)" % [floor, party.size()])


func test_party_cap_switch_is_off_by_default_and_caps() -> void:
	# 측정 스위치가 기본으로 꺼져 있어야 게임 경로가 정본 규칙을 쓴다.
	assert_eq(FonsEncounter.party_cap, 0, "party_cap 기본값은 0")
	FonsEncounter.party_cap = 4
	var capped := _party(91)
	FonsEncounter.party_cap = 0
	assert_true(capped.size() <= 4, "상한 4 인데 편성 %d종" % capped.size())
	assert_true(_party(91).size() >= capped.size(), "스위치를 끄면 원래 규칙으로 돌아온다")


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
		if _no_combat(floor):
			continue
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
	# 이 불변식은 **회전 함수**의 것이다. 그 위에 얹힌 먹이층 보장은 한 자리를 바꾸므로 따로 잰다
	# (`test_the_food_layer_guarantee_changes_at_most_one_slot`) — 둘을 섮어 버리면 어느 규칙이
	# 깨졌는지 알 수 없다.
	for floor in range(1, FLOORS + 1):
		var candidates: Array = _plan(floor)["candidates"]
		var center := FonsEncounter.center_tier_for_floor(DataLoader.get_biomes(), floor, candidates)
		var base := _distances(_rotation(floor, candidates, 0), center)
		for contact in range(1, 6):
			assert_eq(_distances(_rotation(floor, candidates, contact), center), base,
				"%d층 접촉%d 의 중심 거리 구성이 접촉0 과 다르다" % [floor, contact])


func _rotation(floor: int, candidates: Array, contact: int) -> Array:
	return FonsEncounter.select_by_floor_center(candidates, FonsEncounter.party_size(candidates.size()),
		DataLoader.get_biomes(), floor, contact)


func test_the_food_layer_guarantee_changes_at_most_one_slot() -> void:
	## 양보는 한 자리다 — 회전 결과와 비교해 바뀐 자리 수를 센다.
	for floor in range(1, FLOORS + 1):
		var candidates: Array = _plan(floor)["candidates"]
		for contact in 3:
			var raw := _rotation(floor, candidates, contact)
			var party := _party(floor, contact)
			assert_eq(party.size(), raw.size(), "%d층 접촉%d 인원" % [floor, contact])
			var diff := 0
			for i in raw.size():
				if String(raw[i]["id"]) != String(party[i]["id"]):
					diff += 1
			assert_lte(diff, 1, "%d층 접촉%d 에서 %d자리가 바뀌였다" % [floor, contact, diff])


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
		if _no_combat(floor):
			continue        # 편성이 비는 게 규칙인 층 — 중심 tier 도 없다
		var candidates: Array = _plan(floor)["candidates"]
		var center := FonsEncounter.center_tier_for_floor(DataLoader.get_biomes(), floor, candidates)
		assert_true(center >= FonsEncounter.target_tier(floor),
			"%d층 중심 tier %d < 목표 %d" % [floor, center, FonsEncounter.target_tier(floor)])


func test_weak_biome_borrows_stronger_neighbors() -> void:
	# 2026-10-26 먹이층 승격으로 유리 사막에 tier 5 피식자(유리 도마뱀)가 들어와,
	# 실데이터에서는 더 이상 이웃 tier 를 빌리는 층이 없다. 경로 자체는 남아 있으므로
	# tier 5 를 걷어낸 사본으로 그 동작을 잰다 — 안 그러면 이 테스트가 공회전한다.
	var biomes: Variant = DataLoader.get_biomes()
	var target_biome: Dictionary = FonsEncounter.biome_for_floor(biomes, 116)
	var weak: Array = []
	for m in FonsEncounter._monster_list(DataLoader.get_monsters()):
		if int(m.get("tier", 1)) >= 5 and FonsEncounter.shares_habitat(m, target_biome):
			continue
		weak.append(m)
	var plan: Dictionary = FonsEncounter.plan_for_floor(weak, biomes, 116)
	assert_true(bool(plan["tier_shortfall_used"]), "116층 — tier 5 를 걷어냈는데 보충이 안 돌았다")
	# 보증하는 것: 보충 후 후보 최대 tier 가 자체 풀보다 **줄지 않는다**.
	# 목표 도달까지 보증하지는 않는다 — 온도 게이트가 더 섞종을 거를 수 있다(105층 실측).
	assert_true(int(_max_tier(plan["candidates"])) >= FonsEncounter._max_tier(
		FonsEncounter._collect_habitat_pool(weak, target_biome)),
		"116층 보충이 풀을 약하게 만들었다")
	assert_true(int(_max_tier(plan["candidates"])) >= 5, "116층 보충이 tier 5 에 못 닿았다")
	# 실데이터도 다시 빌린다. tier 게이트는 먹이층을 세지 않으므로(_max_tier_for_gate),
	# 승격 피식자 유리 도마뱀(t5)이 있어도 자체 **포식·분해** 최고 tier 가 5 에 못 닿으면
	# 이웃 t5 를 빌린다. 이 경로가 꺼지면 116~120 HP 합이 621,686 → 168,325 로 떨어진다.
	var real := _plan(116)
	assert_true(bool(real["tier_shortfall_used"]), "116층이 이웃 tier 를 안 빌린다 — 먹이층이 게이트를 채웠다")
	assert_true(int(_max_tier(real["candidates"])) >= 5, "116층 보충이 tier 5 에 못 닿았다")
	var has_food := false
	for m in _party(116):
		if FonsEncounter.chain_role(m) == FonsEncounter.CHAIN_FOOD:
			has_food = true
	assert_true(has_food, "116층 편성에 먹이층이 없다 — 차용이 먹이층을 밀어냈다")


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


func test_blocks_16_17_20_use_their_own_roster() -> void:
	# 76~85·96~100 은 이웃 블록 tier 4 를 빌려 5칸을 채우던 구간이다 (2026-10-23 보강 전).
	# 보강 후에는 자기 바이옴 풀만으로 목표 tier 에 닿고, 후보도 4종을 넘는다.
	for block in [16, 17, 20]:
		var lo: int = (int(block) - 1) * FonsEncounter.BLOCK_FLOORS + 1
		for floor in range(lo, lo + FonsEncounter.BLOCK_FLOORS):
			var plan := _plan(floor)
			assert_false(bool(plan["tier_shortfall_used"]),
				"%d층(블록 %d) — 자기 풀에 목표 tier 가 없어 이웃을 빌렸다" % [floor, block])
			assert_true(int(plan["candidates"].size()) >= 4,
				"%d층(블록 %d) 후보 %d종 (4종 이상)" % [floor, block, plan["candidates"].size()])


func test_deep_blocks_are_not_all_top_tier() -> void:
	# 보강의 목적은 tier 4 로 5칸을 채우지 않는 것이다 — 승격종이 낮은 칸을 채운다.
	# 76~85 는 tier 4 가 2 이하 (보강 전 4~5). 96~100 은 2 이하 — 2026-10-26 먹이층 승격으로
	# 무광심연에 tier 4 피식자(틈새우레지)가 들어와 보강 전 3·승격 전 1 에서 2 가 되었다.
	# 상한을 1 로 두면 그 피식자를 tier 3 으로 내려야 하는데, 그러면 보장이 가장 약한 자리
	# (tier 2)를 비우고 층 HP 가 오히려 올라간다. 5칸 중 3칸이 tier 4 가 되는 것은 여전히 막는다.
	for floor in range(76, 86):
		assert_true(_tier_count(_party(floor), 4) <= 2,
			"%d층 tier4 %d종" % [floor, _tier_count(_party(floor), 4)])
	for floor in range(96, 101):
		assert_true(_tier_count(_party(floor), 4) <= 2,
			"%d층 tier4 %d종" % [floor, _tier_count(_party(floor), 4)])


func _tier_count(party: Array, tier: int) -> int:
	var n := 0
	for m in party:
		if int(m.get("tier", 1)) == tier:
			n += 1
	return n


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


func test_biome_names_the_winner_on_a_shared_gatekeeper_floor() -> void:
	# 130층에는 이데아수문장[126,130]과 무문의 파수병[128,130]이 둘 다 걸린다.
	# 정본은 biomes.json 의 gatekeeper — 무문의 파수병이다.
	var biomes: Variant = DataLoader.get_biomes()   # DataLoader 는 Variant 를 돌려준다 — `:=` 는 경고(오류)에 걸린다
	var gk := FonsEncounter.gatekeeper_for_floor(DataLoader.get_monsters(), 130, biomes)
	assert_eq(gk["id"], "mon_nullsentinel_01", "130층 문지기 = 무문의 파수병 (biomes 정본)")
	assert_eq(FonsEncounter.gatekeeper_for_floor(DataLoader.get_monsters(), 126, biomes)["id"],
		"mon_idealis_01", "126층은 이데아수문장")
	assert_eq(FonsEncounter.gatekeeper_for_floor(DataLoader.get_monsters(), 127, biomes)["id"],
		"mon_debtavatar_01", "127층은 장부군주")
	assert_true(FonsEncounter.gatekeeper_for_floor(DataLoader.get_monsters(), 129, biomes).is_empty(),
		"129층은 문지기가 없다 — 통과 층")
	# 바이옴을 안 주면 기존 규칙(데이터 순서 첫 번째) 그대로다.
	assert_eq(FonsEncounter.gatekeeper_for_floor(DataLoader.get_monsters(), 130)["id"],
		"mon_idealis_01", "바이옴 미지정 호출은 데이터 순서를 유지한다")


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


func test_ending_gatekeeper_attack_rises_from_127() -> void:
	# 엔딩 구간(127~130)만 문지기 공격 ×15 — 기억 배분이 깎은 위험을 되돌린다.
	# HP 는 안 건드린다: HP 2배는 길이만 늘고 생존은 5.0/5 그대로였다.
	var monsters: Variant = DataLoader.get_monsters()
	var biomes: Variant = DataLoader.get_biomes()
	var end_gk := FonsEncounter.gatekeeper_for_floor(monsters, 130, biomes)
	var plain := FonsScaling.scale_monster(end_gk, 130, {})
	var scaled := FonsScaling.scale_gatekeeper(end_gk, 130)
	assert_eq(int(scaled["stats"]["atk"]),
		int(roundf(float(plain["stats"]["atk"]) * FonsScaling.ENDING_GATEKEEPER_ATK)),
		"130층 무문의 파수병 ATK = 층 스케일 × 15")
	assert_eq(int(scaled["stats"]["hp"]), int(plain["stats"]["hp"]), "HP 는 안 건드린다")
	# 마법형 문지기는 `mag` 축에 걸린다 — 127 장부군주.
	var caster := FonsEncounter.gatekeeper_for_floor(monsters, 127, biomes)
	assert_eq(int(FonsScaling.scale_gatekeeper(caster, 127)["stats"]["mag"]),
		int(roundf(float(FonsScaling.scale_monster(caster, 127, {})["stats"]["mag"])
			* FonsScaling.ENDING_GATEKEEPER_ATK)), "127 마법형은 mag × 15")
	# 관문 126 은 그대로다 — 기억을 안 나눈 파티도 이겨야 하는 층이다 (test_field_party).
	var gate := FonsEncounter.gatekeeper_for_floor(monsters, 126, biomes)
	assert_eq(int(FonsScaling.scale_gatekeeper(gate, 126)["stats"]["atk"]),
		int(FonsScaling.scale_monster(gate, 126, {})["stats"]["atk"]), "126층은 보정 없음")
	# 문턱 밖과 선형식 문지기는 그대로다.
	var before := FonsEncounter.gatekeeper_for_floor(monsters, 125, biomes)
	assert_eq(int(FonsScaling.scale_gatekeeper(before, 125)["stats"]["atk"]),
		int(FonsScaling.scale_monster(before, 125, {})["stats"]["atk"]), "125층은 보정 없음")
	var early := FonsEncounter.gatekeeper_for_floor(monsters, 5)
	var ref := int(early["spawn"]["bossScaleRefFloor"])
	assert_eq(int(FonsScaling.scale_gatekeeper(early, 5)["stats"]["hp"]),
		maxi(1, int(roundf(float(early["stats"]["hp"]) * 5.0 / float(ref)))), "5층 선형식 그대로")


func test_chain_role_folds_the_ecology_role_into_three_layers() -> void:
	## 08 §4 — 마커 접촉 로그와 사슬 사냥이 쓰는 세 층. 역할 이름은 데이터 그대로 두고
	## **그물에서의 자리만** 셋으로 접는다. 새 역할 이름을 만들지 않는다.
	var cases := {
		"prey": FonsEncounter.CHAIN_FOOD,
		"swarm": FonsEncounter.CHAIN_FOOD,
		"predator": FonsEncounter.CHAIN_PREDATOR,
		"hunter": FonsEncounter.CHAIN_PREDATOR,
		"ambusher": FonsEncounter.CHAIN_PREDATOR,
		"apex": FonsEncounter.CHAIN_PREDATOR,
		"decomposer": FonsEncounter.CHAIN_DECOMPOSER,
		"scavenger": FonsEncounter.CHAIN_DECOMPOSER,
		"undead": FonsEncounter.CHAIN_DECOMPOSER,
		"elemental": FonsEncounter.CHAIN_NONE,
		"guardian": FonsEncounter.CHAIN_NONE,
	}
	for role in cases.keys():
		var m := {"id": "probe", "ecology": {"role": role}}
		assert_eq(FonsEncounter.chain_role(m), cases[role], "%s 의 사슬 자리" % role)


func test_chain_line_names_only_the_layers_in_the_party() -> void:
	var food := {"ecology": {"role": "prey"}}
	var hunter := {"ecology": {"role": "hunter"}}
	var decay := {"ecology": {"role": "scavenger"}}
	assert_eq(FonsEncounter.chain_line([food, hunter, hunter]), "먹이층 1 · 포식층 2")
	assert_eq(FonsEncounter.chain_line([decay]), "분해층 1")
	var spirit := {"ecology": {"role": "elemental"}}
	assert_eq(FonsEncounter.chain_line([spirit, spirit]), "그물 밖 2", "정령은 그물 밖이다 (08 §5.3)")


func test_every_floor_party_reports_its_chain_layers() -> void:
	for floor in range(1, FLOORS + 1):
		var party := _party(floor)
		var counts := FonsEncounter.chain_counts(party)
		var total := 0
		for key in [FonsEncounter.CHAIN_FOOD, FonsEncounter.CHAIN_PREDATOR,
				FonsEncounter.CHAIN_DECOMPOSER, FonsEncounter.CHAIN_NONE]:
			total += int(counts[key])
		assert_eq(total, party.size(), "%d층 사슬 집계가 편성 인원과 같다" % floor)
		assert_ne(FonsEncounter.chain_line(party), "", "%d층 접촉 로그가 빈다" % floor)


func test_a_party_takes_a_food_layer_when_the_floor_has_one() -> void:
	## 08 §3 — 접촉 로그와 사슬 사냥은 **그 층 편성의 먹이층**에 걸린다. 후보에 먹이층이 있으면
	## 중심 tier 를 한 칸 양보해서라도 한 자리를 내준다. 후보에 없으면(데이터가 모자란 층)
	## 손대지 않는다 — 없는 종을 지어내지 않는다.
	var missing := []
	for floor in range(1, FLOORS + 1):
		var pool_food := false
		for m in _plan(floor)["candidates"]:
			if FonsEncounter.chain_role(m) == FonsEncounter.CHAIN_FOOD:
				pool_food = true
				break
		if not pool_food:
			continue
		for contact in 3:
			var party := _party(floor, contact)
			if not party.any(func(m): return FonsEncounter.chain_role(m) == FonsEncounter.CHAIN_FOOD):
				missing.append("%d층#%d" % [floor, contact])
	assert_eq(missing, [], "먹이층을 빠띄린 편성: %s" % str(missing))


func test_combatless_biome_has_no_general_party() -> void:
	## 정본: `biome_idea_gate.difficulty.mods.noCombat = 1` — "엔딩 무대 — 일반 조우 없음(#59 미션
	## 없음 규칙), 이벤트 전투만". 코드가 이 키를 안 읽으면 126~130 에 4체 편성이 생긴다.
	var exempt := []
	for floor in range(1, FLOORS + 1):
		if _no_combat(floor):
			exempt.append(floor)
	assert_eq(exempt, [126, 127, 128, 129, 130], "일반 조우 없음 층은 이데아 문턱 다섯 층뿐")
	for floor in exempt:
		assert_true(bool(_plan(floor)["no_combat"]), "%d층 계획에 no_combat 표시" % floor)
		assert_eq(_party(floor).size(), 0, "%d층은 일반 편성이 비어야 한다" % floor)
	assert_gt(_party(125).size(), 0, "찢긴 천창(121~125)은 일반 조우가 있다")


func test_the_measurement_switch_reproduces_the_old_composition() -> void:
	## A/B 는 같은 조건에서 규칙 하나만 꺼야 성립한다. 스위치를 끄면 22층이 먹이층 없이 나온다.
	assert_true(FonsEncounter.food_layer_guard, "게임 경로는 항상 켜져 있다")
	FonsEncounter.food_layer_guard = false
	var raw := _party(22, 0)
	FonsEncounter.food_layer_guard = true
	assert_false(raw.any(func(m): return FonsEncounter.chain_role(m) == FonsEncounter.CHAIN_FOOD),
		"보장을 끄면 22층은 먹이층 없이 나온다")
	assert_true(_party(22, 0).any(func(m): return FonsEncounter.chain_role(m) == FonsEncounter.CHAIN_FOOD))


func test_the_food_layer_swap_keeps_the_party_shape() -> void:
	## 양보는 **한 자리**다 — 인원·중복·후보 밖 종이 생기면 편성 계약이 깨진 것이다.
	for floor in range(1, FLOORS + 1):
		if _no_combat(floor):
			continue
		var allowed := {}
		for m in _plan(floor)["candidates"]:
			allowed[m["id"]] = true
		for contact in 3:
			var party := _party(floor, contact)
			assert_true(party.size() >= 3 and party.size() <= 5, "%d층 인원" % floor)
			var seen := {}
			for m in party:
				assert_true(allowed.has(m["id"]), "%d층 후보 밖 %s" % [floor, m["id"]])
				assert_false(seen.has(m["id"]), "%d층 중복 %s" % [floor, m["id"]])
				seen[m["id"]] = true
