extends GutTest
## 초반 탐험만으로 스킬이 태어나는가 — 영지·저녁 없이 **걷기·발견·전투**만 돈다.
##
## GDD 09 §5 의 흐름을 그대로 밟는다:
##   행동 → 태그 카운터 → 조건 태그 최소치 + 합계 임계 → 50% 발견 판정 → 각인.
## 이 테스트가 없으면 "스킬북은 있지만 게임에서는 안 생긴다"를 아무도 못 잡는다.

const DAYS := 6
const LIFE_TAGS := ["채집", "약초학", "벌목", "채광", "요리", "운반", "청소",
	"자체훈련", "순찰", "기록", "휴식", "식사", "장비정비", "명상", "독서"]


func _ai() -> Dictionary:
	return {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}


func _early_party() -> Array:
	# 초반 전제 — ★3 · Lv10. 1층 조우는 이 파티로도 이긴다 (아래 테스트가 같이 잠근다).
	return FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		3, 10, 31, DataLoader.load_json("job_coef.json"), 0, 4, _ai())


func _open_site(explore: FonsExplore) -> int:
	for i in explore.sites.size():
		if not bool(explore.sites[i]["cleared"]):
			return i
	return -1


func test_early_exploration_alone_engraves_skills() -> void:
	var heroes := _early_party()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for day in DAYS:
		var explore := FonsExplore.new()
		explore.start(DataLoader.get_monsters(), DataLoader.get_biomes(), 1, 31 + day)
		# 무한맵 — 활성 조우가 27곳이라 전부 칠 필요가 없다. 층 목표(3곳)만 채운다.
		# 걷는 동안 청크가 갈리면 목록 순서가 바뀌므로, 걸은 뒤에 다시 고른다.
		var guard := 0
		while not explore.mission_done() and guard < FonsExplore.SITE_COUNT * 2:
			guard += 1
			var index := _open_site(explore)
			if index < 0:
				break
			explore.walk_to(index, heroes)
			index = _open_site(explore)
			var out := explore.fight(index, heroes, rng)
			assert_eq(String(out["winner"]), "ally",
				"초반 파티가 1층 조우를 이겨야 태그가 쌓인다 (day %d)" % day)
		FonsDay.renew(heroes)

	var born := 0
	var life := 0
	for hero in heroes:
		assert_true(FonsBrain.attached(hero), "AI 데이터가 있으면 초반 영웅에도 브레인이 붙는다")
		var brain: FonsBrain = hero["brain"]
		born += brain.born.size()
		for tag in brain.counters:
			if String(tag) in LIFE_TAGS:
				life += 1
	assert_gt(born, 0, "탐험만 %d일 돌아도 기술이 각인된다" % DAYS)
	assert_eq(life, 0, "영지·저녁을 안 돌렸으므로 생활 태그는 0이다")

	# 각인은 책에만 남는 기록이 아니다 — 전투 목록까지 올라와야 "실제 스킬"이다.
	var fielded := 0
	for hero in heroes:
		var brain: FonsBrain = hero["brain"]
		var ids: Array = []
		for s in hero.get("skills", []):
			ids.append(String(s.get("id", "")))
		for id in brain.book:
			if float(brain.book[id].get("cool_base", 0.0)) > 0.0 and String(id) in ids:
				fielded += 1
	assert_gt(fielded, 0, "각인된 기술이 전투 스킬 목록에도 올라간다")


func test_every_engraved_skill_has_a_tag_that_was_actually_exercised() -> void:
	# 각인은 **해온 일**에서만 생긴다 — 태그 조건이 카운터에 실제로 있어야 한다.
	var heroes := _early_party()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for day in 4:
		var explore := FonsExplore.new()
		explore.start(DataLoader.get_monsters(), DataLoader.get_biomes(), 1, 41 + day)
		for i in explore.sites.size():
			explore.walk_to(i, heroes)
			explore.fight(i, heroes, rng)
		FonsDay.renew(heroes)

	var checked := 0
	for hero in heroes:
		var brain: FonsBrain = hero["brain"]
		for id in brain.book:
			var entry: Dictionary = brain.book[id]
			var has_counter := false
			for tag in entry.get("tags", []):
				if int(brain.counters.get(String(tag), 0)) > 0:
					has_counter = true
					break
			assert_true(has_counter, "각인 '%s' 의 태그가 카운터에 없다" % String(entry.get("name", "")))
			checked += 1
	assert_gt(checked, 0, "검사할 각인이 있어야 한다")
