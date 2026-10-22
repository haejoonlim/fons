extends GutTest
## 영지의 하루 — 사람이 한 일이 생활 태그가 되고, 그 태그가 스킬을 깨우는가 (GDD 09 §3·§4-1).
##
## 이 파일이 잠그는 것:
##   ① 일과 후보의 태그는 전부 GDD 09 §3 의 생활 태그다 (새 태그를 지어내지 않는다)
##   ② 수확은 `estate.json` 의 `gathering` 값에서 나온다 (여기서 수치를 만들지 않는다)
##   ③ 일과 기록이 브레인 카운터·각인 판정까지 닿는다
##   ④ 영지는 스탯을 건드리지 않는다 (09 §4-1 "CP 무영향")
##   ⑤ 같은 시드 = 같은 하루 (결정론)

const JOB := "l2_breaker"


func _data() -> Dictionary:
	return DataLoader.load_json("personalities.json")


func _estate_data() -> Dictionary:
	return DataLoader.load_json("estate.json")


func _job() -> Dictionary:
	return DataLoader.load_json("job_ai_profiles.json")["profiles"][JOB]


func _catalog() -> Array:
	return DataLoader.load_json("skills_catalog.json")["skills"]


func _brain(main: String, subs: Array, seed_value: int = 5) -> FonsBrain:
	var b := FonsBrain.new()
	b.setup({"main": main, "subs": subs, "seed": seed_value}, _data(), _job(), "선봉",
		_catalog(), seed_value)
	return b


func _hero(brain: FonsBrain = null) -> Dictionary:
	var hero := {"name": "일꾼", "alive": true, "hp": 100, "maxHp": 100,
		"atk": 50.0, "def": 20.0, "mag": 10.0, "mdef": 10.0}
	if brain != null:
		hero["brain"] = brain
	return hero


func _estate(floor_value: int = 5) -> FonsEstate:
	var e := FonsEstate.new()
	e.start(_estate_data(), floor_value)
	return e


func test_work_tags_are_gdd_section_3_life_tags() -> void:
	# 09 §3 생활 52종 중 이번에 쓰는 것만. 태그 이름이 여기 없으면 새로 지어낸 것이다.
	var allowed := ["채집", "약초학", "벌목", "채광", "요리", "운반", "청소",
		"자체훈련", "순찰", "기록", "휴식", "식사", "장비정비", "명상", "독서"]
	var e := _estate()
	for job in e.candidates() + e.rest_candidates():
		assert_true(String(job["tag"]) in allowed, "GDD 에 없는 태그: %s" % String(job["tag"]))
		assert_true(String(job["domain"]) in FonsPersonality.DOMAINS,
			"도메인 8종 밖: %s" % String(job["domain"]))


func test_share_comes_from_estate_json() -> void:
	var e := _estate(1)
	# base_yield × (1+floor/50) ÷ team_size(4) — 값은 estate.json 이 정본이다.
	assert_eq(e.share("food"), 38)
	assert_eq(e.share("herb"), 3)
	assert_eq(e.share("wood"), 2)
	assert_eq(e.share("ore"), 1)
	var high := _estate(24)
	assert_gt(high.share("food"), e.share("food"), "층이 오르면 수확이 오른다")


func test_a_shift_records_one_action() -> void:
	var brain := _brain("성실", ["근면", "꾸준"])
	var hero := _hero(brain)
	var e := _estate(1)
	e.shift([hero])
	assert_eq(brain.counters.size(), 1, "한 행동 = 태그 하나")
	assert_eq(int(hero["tags"].get(String(brain.counters.keys()[0]), 0)), 1,
		"유닛 태그 거울도 함께 오른다")


func test_gathering_work_fills_the_stores() -> void:
	# 어떤 일을 고를지는 성격이 정한다 — 스무 번이면 채집 일이 한 번은 나온다.
	var brain := _brain("성실", ["근면", "꾸준"])
	var hero := _hero(brain)
	var e := _estate(1)
	for i in 20:
		e.shift([hero])
	var total := int(e.stores["food"]) + int(e.stores["herb"]) + int(e.stores["wood"]) + int(e.stores["ore"])
	assert_gt(total, 0, "채집 일은 수확을 남긴다")


func test_estate_alone_can_engrave_a_life_skill() -> void:
	# 전투를 한 번도 안 하고 영지 일만 해도 기술이 생겨야 한다 — 이게 이번 작업의 핵심이다.
	var brain := _brain("성실", ["근면", "꾸준"], 9)
	var hero := _hero(brain)
	var e := _estate(1)
	for i in 240:
		e.shift([hero])
		if brain.book.size() > 0:
			break
	assert_gt(brain.book.size(), 0, "생활 태그만으로 기술이 각인된다")
	for id in brain.book:
		assert_true(String(brain.book[id]["domain"]) in ["생산", "지식", "사회"],
			"영지에서 나온 기술은 생활 도메인이다: %s" % String(brain.book[id]["domain"]))


func test_shift_does_not_touch_stats() -> void:
	var brain := _brain("신중", ["관조", "침울"])
	var hero := _hero(brain)
	var before := [hero["atk"], hero["def"], hero["mag"], hero["mdef"], hero["maxHp"], hero["hp"]]
	var e := _estate()
	for i in 20:
		e.shift([hero])
	assert_eq([hero["atk"], hero["def"], hero["mag"], hero["mdef"], hero["maxHp"], hero["hp"]],
		before, "성격·일과는 취향이다 — 스탯에 닿으면 안 된다 (09 §4-1)")


func test_same_seed_gives_the_same_work() -> void:
	var a := _brain("교활", ["재치", "책략"], 21)
	var b := _brain("교활", ["재치", "책략"], 21)
	var ea := _estate()
	var eb := _estate()
	for i in 12:
		ea.shift([_hero(a)])
		eb.shift([_hero(b)])
	assert_eq(a.counters, b.counters, "같은 시드 = 같은 하루")
	assert_eq(ea.stores, eb.stores)


func test_hero_without_brain_still_counts() -> void:
	var hero := _hero()
	var e := _estate()
	e.shift([hero])
	assert_eq(hero["tags"].keys().size(), 1, "브레인이 없어도 태그 거울은 남는다 — 기록이 멈추지 않는다")


func test_rest_is_recovery_domain() -> void:
	var brain := _brain("느긋", ["나태", "소박"])
	var hero := _hero(brain)
	var e := _estate()
	e.recover([hero])
	var tag := String(brain.counters.keys()[0])
	assert_true(tag in ["휴식", "식사", "장비정비", "명상", "독서"], "저녁은 회복 태그만: %s" % tag)
