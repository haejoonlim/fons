extends GutTest
## 층 탐험 — 걷기 · 발견 · 후퇴. 정본은 확정 #41 · D-265 (오픈월드 진입 · 접촉 트리거 · 즉시 재도전).


func _explore() -> FonsExplore:
	var e := FonsExplore.new()
	e.start(DataLoader.get_monsters(), DataLoader.get_biomes(), 3, 20261021)
	return e


func _strong_party() -> Array:
	return FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		7, 130, 3, DataLoader.load_json("job_coef.json"))


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return rng


func _ai() -> Dictionary:
	return {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}


func _ai_party(seed_value: int = 3) -> Array:
	return FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		7, 130, seed_value, DataLoader.load_json("job_coef.json"), 0, 4, _ai())


func test_sites_are_placed_inside_their_own_chunk_and_deterministic() -> void:
	## 무한맵 — 조우는 **청크마다** 3곳이다. 활성 3×3 이라 한 번에 27곳이 보인다.
	var e := _explore()
	assert_eq(e.sites.size(), FonsExplore.SITE_COUNT * 9, "3×3 청크 × 3곳")
	for s in e.sites:
		var p: Vector2 = s["pos"]
		var chunk: Vector2i = s["chunk"]
		var origin := FonsExplore.chunk_origin(chunk)
		assert_true(FonsExplore.chunk_of(p) == chunk, "자기 청크 안에 있다")
		assert_between(p.x, origin.x, origin.x + FonsExplore.CHUNK_WIDTH)
		assert_between(p.y, origin.y, origin.y + FonsExplore.CHUNK_DEPTH)
	assert_gt(e.sites[0]["pos"].length(), FonsExplore.TOWER_CLEAR - 0.001,
		"탑 자리에는 조우를 두지 않는다")
	var again := _explore()
	for i in e.sites.size():
		assert_eq(e.sites[i]["pos"], again.sites[i]["pos"], "같은 시드 = 같은 배치")


func test_walking_into_a_site_reports_contact() -> void:
	var e := _explore()
	assert_eq(e.contact_index(), -1, "입구에서는 조우가 없다")
	var target: Vector2 = e.sites[1]["pos"]
	e.avatar = target - Vector2(0.5, 0.0)
	assert_eq(e.contact_index(), 1, "반경 1.5 안이면 접촉")


func test_walking_has_no_boundary_and_streams_new_chunks() -> void:
	## 무한맵 — 클램프가 없다. 청크를 넘으면 활성 목록이 갈리고, 같은 청크로 돌아오면
	## 조우도 지운 상태도 그대로다.
	var e := _explore()
	var before: Array = e.snapshot()["chunks"].duplicate()
	e.walk(Vector2(1, 0), 30.0)   # 126유닛 — 세 청크를 넘는다
	assert_gt(e.avatar.x, FonsExplore.CHUNK_WIDTH * 2.0, "경계 없이 걸린다")
	var after: Array = e.snapshot()["chunks"]
	assert_ne(str(before), str(after), "청크 목록이 따라온다")
	var far: Vector2 = e.avatar
	e.walk(Vector2(-1, 0), 30.0)
	assert_lt(e.avatar.x, far.x, "되돌아올 수 있다")
	assert_eq(e.avatar.x, 0.0, "같은 거리를 되걸으면 원점이다")


func test_a_cleared_site_stays_cleared_after_walking_away_and_back() -> void:
	## 캐시를 버려도 지운 조우는 월드 키로 남는다 — 재진입하면 지워진 채로 돌아온다.
	var e := _explore()
	var heroes := _strong_party()
	e.avatar = e.sites[0]["pos"]
	var out := e.fight(0, heroes, _rng())
	assert_eq(String(out["winner"]), "ally")
	var cleared_at: Vector2 = e.sites[0]["pos"]
	var chunk: Vector2i = e.sites[0]["chunk"]
	e.walk(Vector2(1, 0), 40.0)
	e.walk(Vector2(-1, 0), 40.0)
	assert_true(FonsExplore.chunk_of(e.avatar) == chunk, "같은 청크로 돌아왔다")
	var found := false
	for s in e.sites:
		if s["pos"].distance_to(cleared_at) < 0.01:
			found = true
			assert_true(bool(s["cleared"]), "지운 조우는 재진입해도 지워져 있다")
	assert_true(found, "다시 활성 목록에 들어왔다")


func test_winning_a_contact_clears_it_and_counts_toward_the_mission() -> void:
	var e := _explore()
	var heroes := _strong_party()
	e.avatar = e.sites[0]["pos"]
	var out := e.fight(0, heroes, _rng())
	assert_eq(String(out["winner"]), "ally", "1층대 조우는 만렙 파티가 이긴다")
	assert_true(bool(e.sites[0]["cleared"]))
	assert_eq(e.cleared, 1)
	assert_false(e.mission_done(), "3곳 중 1곳")
	assert_eq(e.contact_index(), -1, "지운 지점은 다시 접촉하지 않는다")


func test_losing_keeps_the_site_and_allows_retry() -> void:
	var e := _explore()
	var weak := [{"name": "약체", "side": "ally", "hp": 1, "maxHp": 1, "alive": true,
		"atk": 1.0, "def": 0.0, "pen": 0.0, "eva": 0.0, "cri": 0.0, "cdmg": 0.0,
		"mag": 0.0, "mdef": 0.0, "magical": false}]
	var out := e.fight(0, weak, _rng())
	assert_eq(String(out["winner"]), "enemy")
	assert_false(bool(e.sites[0]["cleared"]), "진 조우는 남는다 — 즉시 재도전")
	assert_eq(e.cleared, 0)


func test_retreat_returns_to_entry_but_keeps_progress() -> void:
	var e := _explore()
	var heroes := _strong_party()
	e.avatar = e.sites[0]["pos"]
	e.fight(0, heroes, _rng())
	e.walk(Vector2(1, 1), 3.0)
	e.retreat()
	assert_eq(e.avatar, FonsExplore.SPAWN, "탑 앞 시작 자리로 돌아온다")
	assert_eq(e.cleared, 1, "지운 조우는 남는다 (D-265)")
	assert_eq(e.retreated, 1)


func test_walk_to_moves_the_avatar_and_records_scout_tags() -> void:
	# 탐험도 한 행동이다 — 걷기 태그가 브레인 카운터(각인 판정)까지 가야 한다.
	var e := _explore()
	var heroes := _ai_party()
	e.walk_to(0, heroes)
	assert_gt(e.avatar.distance_to(Vector2.ZERO), 0.0, "순간이동이 아니라 실제로 걷는다")
	for hero in heroes:
		assert_eq(int(hero["brain"].counters.get("정찰", 0)), 1)
		assert_eq(int(hero["brain"].counters.get("영역이동", 0)), 1, "한 행동이 태그 둘")


func test_finding_a_contact_reaches_brain_counters() -> void:
	# 예전에는 유닛 태그 거울에만 남아 각인 판정에 안 닿았다 — 그 구멍을 잠근다.
	var e := _explore()
	var heroes := _ai_party()
	e.avatar = e.sites[0]["pos"]
	e.fight(0, heroes, _rng())
	for hero in heroes:
		assert_eq(int(hero["brain"].counters.get("관찰", 0)), 1)


func test_retreat_is_recorded_for_the_people_who_walked_back() -> void:
	var e := _explore()
	var heroes := _ai_party()
	e.retreat(heroes)
	for hero in heroes:
		assert_eq(int(hero["brain"].counters.get("후퇴", 0)), 1)


func test_snapshot_names_the_biome_and_its_topology_kit() -> void:
	## 뷰가 "어느 층이 어느 세계인가"를 판정하려면 심이 이름을 실어야 한다 (계획서 §5).
	var e := _explore()
	var snap := e.snapshot()
	assert_eq(String(snap["biome"]), "biome_plains", "3층 = 슬롯 1 풀바다")
	assert_eq(String(snap["kit"]), "topo_natural_surface", "지형 키트도 함께")


func test_a_floor_without_a_biome_says_so_with_empty_strings() -> void:
	## 표기 생략 규약 — 모르는 층은 지어내지 않고 빈 문자열이다 (`FonsEncounter.biome_for_floor`).
	var e := FonsExplore.new()
	e.start(DataLoader.get_monsters(), [], 1, 1)
	assert_eq(String(e.snapshot()["biome"]), "")
	assert_eq(String(e.snapshot()["kit"]), "")


func test_clearing_the_required_sites_finishes_the_floor() -> void:
	## 무한맵이라 근처에 27곳이 보여도, 층 목표는 예전처럼 3곳이다.
	var e := _explore()
	var heroes := _strong_party()
	for n in FonsExplore.SITE_COUNT:
		e.avatar = e.sites[n]["pos"]
		e.fight(n, heroes, _rng())
	assert_eq(e.cleared, FonsExplore.SITE_COUNT)
	assert_true(e.mission_done())
	var snap: Dictionary = e.snapshot()
	assert_true(bool(snap["done"]))
	assert_eq(snap["sites"].size(), FonsExplore.SITE_COUNT * 9, "보이는 조우 수는 그대로")
	assert_eq(snap["chunks"].size(), 9, "3×3 청크를 보여 준다")


func test_tower_stands_at_the_world_origin() -> void:
	## 무한맵 — 탑은 **월드 원점**이다. 청크 (0,0) 의 한가운데라 어디를 걷다 돌아와도 같은 자리다.
	var e := _explore()
	assert_eq(e.tower_pos(), Vector2.ZERO, "월드 원점")
	assert_eq(FonsExplore.chunk_origin(Vector2i.ZERO) + Vector2(FonsExplore.CHUNK_WIDTH,
		FonsExplore.CHUNK_DEPTH) * 0.5, Vector2.ZERO, "청크 (0,0) 의 한가운데")
	var mark: Dictionary = e.snapshot()["tower"]
	assert_almost_eq(float(mark["radius"]), FonsExplore.TOWER_RADIUS, 0.001, "소환진 반경")
	assert_lt(float(mark["body"]), float(mark["radius"]), "탑 몸통은 소환진 안쪽 원")
	var at: Vector3 = mark["pos"]
	assert_eq(at, Vector3.ZERO, "뷰 좌표도 원점")


func test_a_site_carries_the_chain_layers_of_the_party_it_will_fight() -> void:
	## 출현표 — 조우는 싸우기 전부터 **어떤 사슬층인지** 알고 있다. 편성은 전투와 같은 함수가 진다.
	var e := _explore()
	var snap_sites: Array = e.snapshot()["sites"]
	for i in range(0, mini(6, e.sites.size())):
		var site: Dictionary = e.sites[i]
		var party := FonsEncounter.build_party(DataLoader.get_monsters(), DataLoader.get_biomes(),
			e.floor, int(site["contact_index"]))
		assert_eq(String(site["chain"]), FonsEncounter.chain_line(party), "%d번 조우의 사슬" % i)
		assert_eq(String(snap_sites[i]["chain"]), String(site["chain"]), "뷰가 읽는 표에도 있다")


func test_first_contact_logs_the_layer_once() -> void:
	var e := _explore()
	var site: Dictionary = e.sites[0]
	e.avatar = Vector2(site["pos"]) - Vector2(0.5, 0)
	e.walk(Vector2.ZERO, 0.0)
	var touched := e.log_lines.filter(func(line): return String(line).begins_with("접촉 —"))
	assert_eq(touched.size(), 1, "접촉 한 번에 한 줄")
	assert_true(String(touched[0]).ends_with(String(site["chain"])), "층 이름이 그 조우의 사슬이다")
	e.walk(Vector2(0.01, 0.0), 0.1)
	touched = e.log_lines.filter(func(line): return String(line).begins_with("접촉 —"))
	assert_eq(touched.size(), 1, "같은 조우는 다시 안 적는다")
