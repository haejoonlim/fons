extends GutTest
## S5 — 바이옴별 생물 3종 키 매핑표.
##
## 이 단계는 메시를 만들지 않는다. 78칸(26 × 3)의 **생산 목록**이 산출물이고,
## 그 목록이 게임의 조우 규칙과 어긋나면 아트가 엉뚱한 종을 그린다.
## 그래서 후보 규칙을 생성기와 뷰 코드 양쪽에서 잠근다:
##   · 전투 모드만 (`encounter`·`elite`) — `world`·`boss` 는 다른 경로다
##   · `ecology.habitat ∩ biome.habitat` — `FonsEncounter.shares_habitat` 그대로
##   · 키는 `monster:<mon_id>` — `run_state.gd` 의 entity.asset 규칙 그대로

const ASSETS := "res://data/monster_assets.json"
const MONSTERS := "res://data/monsters.json"
const BIOMES := "res://data/biomes.json"
const PREFIX := "monster:"
const PER_BIOME := 3


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s 를 읽는다" % path)
	return parsed if parsed is Dictionary else {}


func _monsters() -> Dictionary:
	var out := {}
	for mon in _json(MONSTERS).get("monsters", []):
		out[String((mon as Dictionary).get("id", ""))] = mon
	return out


func _biomes() -> Dictionary:
	## slot → biome. 생성기가 slots[0] 으로 짝을 짓는다.
	var out := {}
	for group in _json(BIOMES).get("groups", []):
		for biome in (group as Dictionary).get("biomes", []):
			var slots: Array = (biome as Dictionary).get("slots", [])
			if not slots.is_empty():
				out[int(slots[0])] = biome
	return out


func test_every_biome_gets_exactly_three_combat_species() -> void:
	var doc := _json(ASSETS)
	var rows: Array = doc.get("biomes", [])
	assert_eq(rows.size(), 26, "바이옴 26")
	var total := 0
	for row in rows:
		var picks: Array = (row as Dictionary).get("monsters", [])
		assert_eq(picks.size(), PER_BIOME, "%s 는 3종" % String((row as Dictionary).get("id", "")))
		total += picks.size()
	assert_eq(total, 78, "26 × 3 = 78칸")


func test_every_key_is_a_real_combat_monster() -> void:
	var monsters := _monsters()
	for row in _json(ASSETS).get("biomes", []):
		for entry in (row as Dictionary).get("monsters", []):
			var pick: Dictionary = entry
			var id := String(pick.get("id", ""))
			assert_true(monsters.has(id), "%s 가 monsters.json 에 있다" % id)
			if not monsters.has(id):
				continue
			var mon: Dictionary = monsters[id]
			assert_eq(String(pick.get("key", "")), PREFIX + id, "키 규칙 monster:<mon_id>")
			assert_true(String(mon.get("spawn", {}).get("mode", "")) in ["encounter", "elite"],
				"%s 는 전투종 (world·boss 제외)" % id)
			assert_eq(String(pick.get("name", "")), String(mon.get("name", "")), "%s 이름" % id)
			assert_eq(String(pick.get("role", "")), String(mon.get("ecology", {}).get("role", "")),
				"%s 역할" % id)


func test_every_picked_species_shares_the_biome_habitat() -> void:
	## 게임의 조우 편성이 쓰는 바로 그 판정이다. 여기서 어긋나면 아트는 그 바이옴에
	## 실재하지도 않는 종을 그리게 된다.
	var monsters := _monsters()
	var biomes := _biomes()
	for row in _json(ASSETS).get("biomes", []):
		var slot := int((row as Dictionary).get("slot", 0))
		assert_true(biomes.has(slot), "슬롯 %d 바이옴이 있다" % slot)
		var biome: Dictionary = biomes.get(slot, {})
		var ids := {}
		for entry in (row as Dictionary).get("monsters", []):
			var pick: Dictionary = entry
			var id := String(pick.get("id", ""))
			assert_false(ids.has(id), "%s 안에서 같은 종이 두 번 나오지 않는다" % String((row as Dictionary).get("id", "")))
			ids[id] = true
			if monsters.has(id):
				assert_true(FonsEncounter.shares_habitat(monsters[id], biome),
					"%s 는 %s 에 산다" % [id, String(biome.get("id", ""))])


func test_signature_species_are_in_the_floor_plan_pool() -> void:
	## 필드 확인 — 그 바이옴 한가운데 층의 실제 조우 계획(후보 풀)에 세 종이 다 있는가.
	## 후보에 없으면 아트가 그린 종은 그 바이옴에서 영원히 만나지 못한다.
	var monsters := _json(MONSTERS)
	var biomes := _json(BIOMES)
	for row in _json(ASSETS).get("biomes", []):
		var slot := int((row as Dictionary).get("slot", 0))
		var floor := (slot - 1) * 5 + 3
		var plan := FonsEncounter.plan_for_floor(monsters, biomes, floor)
		if bool(plan.get("no_combat", false)):
			# 일반 조우가 없는 바이옴(이데아 문턱) — 후보가 비는 것이 규칙이다.
			assert_eq((plan.get("candidates", []) as Array).size(), 0, "%d층 면제는 후보 0" % floor)
			continue
		var pool := {}
		for mon in plan.get("candidates", []):
			pool[String((mon as Dictionary).get("id", ""))] = true
		for entry in (row as Dictionary).get("monsters", []):
			var id := String((entry as Dictionary).get("id", ""))
			assert_true(pool.has(id), "%d층 조우 후보에 %s 가 있다" % [floor, id])


func test_three_picks_are_not_all_one_body_band() -> void:
	## 세 종이 같은 몸집 대역이면 화면에서 "한 종류 3마리"로 읽힌다.
	## 대역이 둘뿐인 바이옴(지옥 등)은 데이터가 그만큼 얇다는 뜻이므로 거기까지만 본다.
	for row in _json(ASSETS).get("biomes", []):
		var bands := {}
		for entry in (row as Dictionary).get("monsters", []):
			var band := String((entry as Dictionary).get("band", ""))
			assert_false(band.is_empty(), "%s 대역이 비어 있지 않다" % String((entry as Dictionary).get("id", "")))
			bands[band] = true
		assert_gte(bands.size(), 2, "%s 는 몸집 대역이 둘 이상" % String((row as Dictionary).get("id", "")))
