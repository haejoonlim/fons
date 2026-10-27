extends GutTest
## 하루 — 아침 영지 → 낮 탐험 → 저녁 회복이 **한 사람의 카운터**로 이어지는가.
##
## 이 파일이 잠그는 것:
##   ① 하루를 돌면 생활 태그와 탐험 태그가 같은 영웅에게 함께 남는다
##   ② 영지·저녁을 끄면 생활 태그가 사라진다 (대조군이 실제로 대조군이다)
##   ③ 같은 시드 = 같은 하루 (로그·카운터)
##   ④ 하루는 스탯을 바꾸지 않는다 — 하루가 바꾸는 것은 \"해온 일\"뿐이다
##   ⑤ 다음 날은 만전에서 시작한다 (`renew`)

const LIFE_TAGS := ["채집", "약초학", "벌목", "채광", "요리", "운반", "청소",
	"자체훈련", "순찰", "기록", "휴식", "식사", "장비정비", "명상", "독서"]
const FIELD_TAGS := ["정찰", "영역이동", "관찰", "후퇴"]


func _ai() -> Dictionary:
	return {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}


func _party(seed_value: int = 7) -> Array:
	return FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		7, 130, seed_value, DataLoader.load_json("job_coef.json"), 0, 4, _ai())


func _day(seed_value: int = 7, floor_value: int = 1) -> FonsDay:
	var d := FonsDay.new()
	d.start(DataLoader.load_json("estate.json"), DataLoader.get_monsters(),
		DataLoader.get_biomes(), floor_value, seed_value)
	return d


func _counters(heroes: Array) -> Array:
	var out: Array = []
	for hero in heroes:
		if FonsBrain.attached(hero):
			out.append(hero["brain"].counters.duplicate())
		else:
			out.append({})
	return out


func test_island_day_settles_once_across_floor_days() -> void:
	## 층 하루(FonsDay)와 섬일은 다른 단위다 — 같은 섬일에 층 하루를 두 번 돌려도 정산은 한 번.
	var d := _day()
	d.estate.clock_epoch = 1000
	d.estate.last_settled_day = 1
	var heroes := _party()
	var first := d.run(heroes, true, 1000 + 12343)
	assert_eq(d.estate.last_settled_day, 2, "경계를 넘은 날이 정산된다")
	assert_true(first["log"].has("섬 2일"), "정산한 날이 로그에 남는다")
	var second := d.run(heroes, true, 1000 + 12343 + 600)
	assert_eq(d.estate.last_settled_day, 2, "같은 섬일에 두 번 정산하지 않는다")
	assert_false(second["log"].has("섬 3일"), "없는 날을 지어내지 않는다")


func test_one_day_connects_estate_field_and_recovery() -> void:
	var heroes := _party()
	var out := _day().run(heroes)
	assert_eq(String(out["winner"]), "ally", "1층은 만렙 파티가 이긴다")
	assert_eq(int(out["cleared"]), FonsExplore.SITE_COUNT)
	for hero in heroes:
		assert_true(FonsBrain.attached(hero), "AI 데이터가 있으면 브레인이 붙는다")
		var counters: Dictionary = hero["brain"].counters
		var life := 0
		var field := 0
		for tag in counters:
			if String(tag) in LIFE_TAGS:
				life += int(counters[tag])
			if String(tag) in FIELD_TAGS:
				field += int(counters[tag])
		assert_gt(life, 0, "%s 에게 생활 태그가 남아야 한다" % String(hero.get("name", "?")))
		assert_gt(field, 0, "%s 에게 탐험 태그가 남아야 한다" % String(hero.get("name", "?")))
		assert_gt(int(counters.get("근접타격", 0)) + int(counters.get("마법시전", 0)) +
			int(counters.get("원거리사격", 0)), 0, "전투 태그도 같은 카운터에 남는다")


func test_without_life_there_are_no_life_tags() -> void:
	var heroes := _party(8)
	_day(8).run(heroes, false)
	for hero in heroes:
		for tag in hero["brain"].counters:
			assert_false(String(tag) in LIFE_TAGS,
				"영지·저녁을 끄면 생활 태그가 없어야 한다: %s" % String(tag))


func test_same_seed_gives_the_same_day() -> void:
	var a := _party(11)
	var b := _party(11)
	var out_a := _day(11).run(a)
	var out_b := _day(11).run(b)
	assert_eq(out_a["log"], out_b["log"], "같은 시드 = 같은 하루")
	assert_eq(_counters(a), _counters(b), "같은 시드 = 같은 기록")
	assert_eq(out_a["stores"], out_b["stores"])


func test_a_day_does_not_change_stats() -> void:
	var heroes := _party(12)
	var before: Array = []
	for hero in heroes:
		before.append([hero["atk"], hero["def"], hero["mag"], hero["mdef"], hero["maxHp"]])
	_day(12).run(heroes)
	for i in heroes.size():
		assert_eq([heroes[i]["atk"], heroes[i]["def"], heroes[i]["mag"],
			heroes[i]["mdef"], heroes[i]["maxHp"]], before[i],
			"하루가 바꾸는 것은 '해온 일'뿐 — 스탯은 그대로다")


func test_renew_starts_the_next_day_at_full_health() -> void:
	var heroes := _party(13)
	_day(13).run(heroes)
	FonsDay.renew(heroes)
	for hero in heroes:
		assert_eq(int(hero["hp"]), int(hero["maxHp"]))
		assert_true(bool(hero["alive"]))


func test_life_actions_reach_engraving_not_just_the_mirror() -> void:
	# 생활 태그가 유닛 태그 거울에만 쌓이고 브레인 카운터에 안 들어가면 각인은 영원히 안 된다.
	# 각인은 50% 판정이라 하루에 0건일 수 있다 — 닷새를 돌려 "생활이 재료가 된다"를 본다.
	var heroes := _party(14)
	for d in 5:
		FonsDay.renew(heroes)
		_day(14 + d).run(heroes)
	var catalog: Array = DataLoader.load_json("skills_catalog.json")["skills"]
	var engraved := 0
	var life_ready := 0
	for hero in heroes:
		var brain: FonsBrain = hero["brain"]
		assert_gt(brain.counters.size(), 0, "생활 태그가 브레인 카운터에 들어간다")
		for id in brain.book:
			engraved += 1
		# 각인은 50% 판정 + 도메인 선호라 "생활 기술이 뽑힐" 보장이 없다. 대신 생활 태그가
		# **각인 후보 조건**을 넘는지 본다 — 태그가 거울에만 쌓였다면 후보 풀에 못 들어온다.
		for skill in FonsSkillBook.eligible(brain.book, brain.counters, catalog):
			if String(skill["domain"]) in ["생산", "지식", "사회", "회복"]:
				life_ready += 1
	assert_gt(engraved, 0, "닷새면 기술이 깨우쳐진다")
	assert_gt(life_ready, 0, "생활 태그가 각인 후보 조건을 넘는다 — 하루가 각인 재료가 됐다는 증거")


func test_every_born_skill_name_is_a_catalog_name() -> void:
	# 각인·융합이 이름을 지어내지 않는다 — 태어난 이름은 전부 카탈로그 정본이다 (AGENTS §1).
	var heroes := _party(15)
	var names := {}
	for skill in DataLoader.load_json("skills_catalog.json")["skills"]:
		names[String(skill["name"])] = true
	var seen := 0
	for d in 5:
		FonsDay.renew(heroes)
		var out := _day(15 + d).run(heroes)
		for name in out["born"]:
			seen += 1
			assert_true(names.has(String(name)), "카탈로그 밖 이름: %s" % String(name))
	for hero in heroes:
		for name in hero["brain"].born:
			seen += 1
			assert_true(names.has(String(name)), "카탈로그 밖 이름: %s" % String(name))
	assert_gt(seen, 0, "닷새면 태어난 이름이 있다")
