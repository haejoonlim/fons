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


func test_sites_are_placed_inside_the_field_and_deterministic() -> void:
	var e := _explore()
	assert_eq(e.sites.size(), FonsExplore.SITE_COUNT)
	for s in e.sites:
		var p: Vector2 = s["pos"]
		assert_between(p.x, 0.0, FonsExplore.FIELD_WIDTH)
		assert_between(p.y, 0.0, FonsExplore.FIELD_DEPTH)
	var again := _explore()
	for i in e.sites.size():
		assert_eq(e.sites[i]["pos"], again.sites[i]["pos"], "같은 시드 = 같은 배치")


func test_walking_into_a_site_reports_contact() -> void:
	var e := _explore()
	assert_eq(e.contact_index(), -1, "입구에서는 조우가 없다")
	var target: Vector2 = e.sites[1]["pos"]
	e.avatar = target - Vector2(0.5, 0.0)
	assert_eq(e.contact_index(), 1, "반경 1.5 안이면 접촉")


func test_walk_clamps_to_the_field() -> void:
	var e := _explore()
	e.walk(Vector2(-1, -1), 100.0)
	assert_eq(e.avatar, Vector2.ZERO, "필드 밖으로 나가지 않는다")
	e.walk(Vector2(1, 1), 100.0)
	assert_eq(e.avatar, Vector2(FonsExplore.FIELD_WIDTH, FonsExplore.FIELD_DEPTH))


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
	assert_eq(e.avatar, Vector2.ZERO, "입구로 돌아온다")
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


func test_clearing_every_site_finishes_the_floor() -> void:
	var e := _explore()
	var heroes := _strong_party()
	for i in e.sites.size():
		e.avatar = e.sites[i]["pos"]
		e.fight(i, heroes, _rng())
	assert_eq(e.cleared, FonsExplore.SITE_COUNT)
	assert_true(e.mission_done())
	var snap: Dictionary = e.snapshot()
	assert_true(bool(snap["done"]))
	assert_eq(snap["sites"].size(), FonsExplore.SITE_COUNT)
