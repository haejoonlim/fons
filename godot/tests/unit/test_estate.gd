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


func test_settlement_collects_tax_and_pays_maintenance() -> void:
	# 세금·식량·유지비 수치는 전부 estate.json 에서 온다 (04 §3.2·§3.4·§3.12).
	var e := _estate(1)
	e._altar_level = 0   # 채집팀 없이 수지만 본다 — 생산은 별도 검사
	e.clock_epoch = 1000
	e.last_settled_day = 1
	e.stores["food"] = 200
	var out := e.settle(1000 + 12343, 100)
	assert_true(bool(out["settle"]))
	assert_eq(int(out["tax"]), 30, "주민 30 × 1G")
	assert_eq(int(out["maintenance"]), 10, "가동 시설 레벨 1 × 10G")
	assert_eq(int(out["gold"]), 120, "100 + 30 - 10")
	assert_eq(int(out["food_eaten"]), 30, "주민 30 × 1식")
	assert_eq(int(e.stores["food"]), 170, "보유 식량에서 소비한다")
	assert_true(out["log"].has("섬 2일"))


func test_settlement_runs_the_day_work_before_eating() -> void:
	# 하루의 순서는 생산 → 소비다. 정산만 돌면 게임에서 식량이 영원히 0 이다.
	# 브레인 없는 영웅의 `_choose` 는 첫 후보(채집)를 고른다 — 영웅 몫이 확정이다.
	var e := _estate(1)
	e.clock_epoch = 1000
	var out := e.settle(1000 + 12343, 0, [_hero()])
	assert_true(bool(out["settle"]))
	assert_eq(int(out["food_eaten"]), 30, "주민 30 × 1식")
	# 채집팀 1팀 × 150 × 1.02 = 153 (04 §3.3) + 영웅 한 몫 38 = 191, 먹고 30 → 161.
	assert_eq(int(out["harvest"]["food"]), 153, "팀 하나가 섬 하루 1회")
	assert_eq(int(e.stores["food"]), 161, "생산 191 먼저, 소비 30 나중")
	assert_eq(int(out["food_short"]), 0, "생산이 소비보다 먼저라 부족이 아니다")
	assert_string_contains(String(out["log"][1]), "일과 — 식량 +191", "그날 번 것을 로그가 적는다")
	assert_false(e.log_lines.has("식량 30 모자람"))


func test_gathering_team_comes_from_the_altar_level() -> void:
	# 04 §3.10 — 채집팀 = 소환제단 Lv. estate.json 의 max_teams_by_altar_level 을 그대로 읽는다.
	var e := _estate(1)
	assert_eq(e.team_count(), 1, "제단 Lv1 = 1팀 = 4인")
	e._altar_level = 5
	assert_eq(e.team_count(), 5, "Lv5 = 5팀")
	e._altar_level = 0
	assert_eq(e.team_count(), 0, "제단이 없으면 팀도 없다")
	assert_eq(e.harvest(), {}, "팀 0 이면 수확도 0")


func test_no_shift_when_no_day_has_passed() -> void:
	# 미접속·같은 날 재호출에는 일과도 정산도 없다 (04 §3.3 "수확 공백일 뿐").
	var e := _estate(1)
	e.clock_epoch = 1000
	var out := e.settle(1000, 0, [_hero()])
	assert_false(bool(out["settle"]))
	assert_eq(int(e.stores["food"]), 0, "정산이 아닌 날에는 일과도 없다")


func test_population_grows_on_the_island_day_rate() -> void:
	# 봄 1.5 배율 → 섬일 3%. 수치는 estate.json 의 2% × 계절 배율이다.
	# 식량을 넣어 두는 이유: 부족 3일째부터는 아사가 인구에 곱해진다 (별도 검사).
	var e := _estate(1)
	e.stores["food"] = 1000
	assert_almost_eq(e.population, 30.0, 0.001, "초기 30명")
	e.clock_epoch = 1000
	for i in 5:
		e.settle(1000 + (i + 1) * 12343)
	assert_almost_eq(e.population, 30.0 * pow(1.03, 5), 0.01, "봄에는 3%/섬일")


func test_population_stops_at_the_stage_cap() -> void:
	var e := _estate(1)
	e.stores["food"] = 100000
	e.clock_epoch = 1000
	for i in 80:
		e.settle(1000 + (i + 1) * 12343)
	assert_almost_eq(e.population, 60.0, 0.001, "S1 상한 60에서 멈춘다")


func test_food_shortage_is_recorded_and_never_goes_negative() -> void:
	var e := _estate(1)
	e._altar_level = 0   # 채집팀이 없어야 부족이 난다
	e.stores["food"] = 10
	e.clock_epoch = 1000
	var out := e.settle(1000 + 12343, 0)
	assert_eq(int(e.stores["food"]), 0, "보유분까지만 먹는다")
	assert_eq(int(out["food_short"]), 20, "30명 중 10명분만 있었다")
	assert_true(out["log"].has("식량 20 모자람"))


func test_maintenance_shortfall_does_not_make_gold_negative() -> void:
	var e := _estate(1)
	e._facility_levels = 5   # 건설 시스템이 붙기 전 가정 — 레벨 5 시설 하나
	e.clock_epoch = 1000
	var out := e.settle(1000 + 12343, 0)
	assert_eq(int(out["unpaid"]), 20, "유지비 50G - 세금 30G")
	assert_eq(int(out["gold"]), 0, "잔고는 0 아래로 안 내려간다")


func test_population_survives_the_save() -> void:
	var e := _estate(1)
	e.clock_epoch = 1000
	e.settle(1000 + 12343)
	var back := FonsEstate.new()
	back.start(_estate_data(), 1)
	back.from_save(e.to_save())
	assert_almost_eq(back.population, e.population, 0.001, "주민 수가 같이 저장된다")


func test_famine_starts_on_the_third_short_island_day() -> void:
	# 04 §3.14 — 식량 부족이 3섬일 이어지면 그날부터 인구 -2%/섬일.
	var fed := _estate(1)
	var hungry := _estate(1)
	fed._altar_level = 0   # 생산 없이 재고만으로 버티는 대조군
	hungry._altar_level = 0
	fed.stores["food"] = 1000
	fed.clock_epoch = 1000
	hungry.clock_epoch = 1000
	for i in 2:
		fed.settle(1000 + (i + 1) * 12343)
		hungry.settle(1000 + (i + 1) * 12343)
	assert_almost_eq(hungry.population, fed.population, 0.001, "이틀까지는 아사가 없다")
	assert_eq(hungry.shortage_days, 2, "부족일을 센다")
	fed.settle(1000 + 3 * 12343)
	var out := hungry.settle(1000 + 3 * 12343)
	assert_almost_eq(hungry.population, fed.population * 0.98, 0.01, "3일째 -2%")
	assert_gt(float(out["starved"]), 0.0, "아사량이 보고된다")
	assert_true(out["log"].any(func(line): return String(line).begins_with("아사")))


func test_shortage_counter_resets_when_fed() -> void:
	var e := _estate(1)
	e._altar_level = 0
	e.clock_epoch = 1000
	e.settle(1000 + 12343)
	e.settle(1000 + 2 * 12343)
	assert_eq(e.shortage_days, 2)
	e.stores["food"] = 1000
	e.settle(1000 + 3 * 12343)
	assert_eq(e.shortage_days, 0, "먹이면 연속일이 끊긴다")
	e.stores["food"] = 0
	var out := e.settle(1000 + 4 * 12343)
	assert_eq(int(out["starved"]), 0, "끊긴 뒤 첫 부족일은 아사가 아니다")


func test_morale_scales_gathering() -> void:
	# 04 §3.5 — (민심-50)÷50×0.20. 50 이면 1.0.
	var e := _estate(1)
	var base := e.share("food")
	e.morale = 100
	assert_eq(e.share("food"), 46, "38 × 1.2")
	e.morale = 0
	assert_eq(e.share("food"), 31, "38.25 × 0.8 = 30.6 → 31")
	e.morale = 50
	assert_eq(e.share("food"), base, "50 은 기준값")


func test_floor_clear_costs_morale_while_food_is_out() -> void:
	# 04 §3.14 — 식량 0 이면 민심 -5/층. 정산(섬일)이 아니라 층 단위다 (§3.4).
	var e := _estate(1)
	assert_eq(e.morale, 50)
	var out := e.note_floor_cleared()
	assert_eq(int(out["delta"]), -5)
	assert_eq(e.morale, 45)
	e.stores["food"] = 100
	assert_eq(int(e.note_floor_cleared()["delta"]), 0, "식량이 있으면 깎지 않는다")


func test_strike_starts_after_three_floors_below_twenty() -> void:
	# 04 §3.5·§3.12 — 민심 20 미만이 3층 이어지면 전 생산 정지 5층.
	# 수치는 estate.json `morale_unrest` 가 정한다.
	var e := _estate(1)
	e.morale = 19
	# 식량이 없으면 층마다 -5 가 붙는다 — 그래도 3층째에 파업이다.
	for i in 2:
		e.note_floor_cleared()
	assert_false(e.is_striking(), "2층까지는 파업이 아니다")
	assert_eq(e.unrest_floors, 2, "미달 층을 센다")
	var out := e.note_floor_cleared()
	assert_true(bool(out["strike_started"]))
	assert_eq(e.strike_floors_left, 5, "전 생산 정지 5층")
	assert_eq(int(out["strike"]), 5)


func test_morale_recovery_cancels_the_unrest_count() -> void:
	var e := _estate(1)
	e.morale = 19
	e.note_floor_cleared()
	assert_eq(e.unrest_floors, 1)
	e.morale = 30
	e.note_floor_cleared()
	assert_eq(e.unrest_floors, 0, "20 이상이면 연속 층이 끊긴다")
	assert_false(e.is_striking())


func test_food_alone_does_not_raise_morale() -> void:
	# 회복은 파업의 구제다 — 평시에 식량만으로 민심이 오르면 기준 50 이 무의미해진다.
	var e := _estate(1)
	e.morale = 30
	e.stores["food"] = 100
	assert_eq(int(e.note_floor_cleared()["delta"]), 0, "파업을 겪지 않았으면 식량으로 오르지 않는다")
	assert_eq(e.morale, 30)


func test_recovery_does_not_run_during_the_strike() -> void:
	# 파업 중에 민심이 오르면 정지가 무의미해진다 — 회복은 파업이 끝난 뒤다.
	var e := _estate(1)
	e.morale = 19
	for i in 3:
		e.note_floor_cleared()   # 식량 0 — 파업 시작
	assert_true(e.is_striking())
	e.stores["food"] = 100
	var out := e.note_floor_cleared()
	assert_eq(int(out["delta"]), 0, "파업 중에는 회복하지 않는다")
	assert_eq(e.strike_floors_left, 4)


func test_recovery_starts_after_the_strike_ends() -> void:
	var e := _estate(1)
	e.morale = 19
	for i in 3:
		e.note_floor_cleared()
	e.stores["food"] = 100
	for i in 5:
		e.note_floor_cleared()   # 파업 5층 소진 — 마지막 층은 회복 없음
	assert_false(e.is_striking())
	var low := e.morale
	var out := e.note_floor_cleared()
	assert_eq(int(out["delta"]), 5, "파업이 끝나면 식량 흑자로 회복한다")
	assert_eq(e.morale, low + 5)


func test_recovery_stops_at_the_baseline_morale() -> void:
	# 기준 민심(estate.json `morale.initial`)까지 돌아오면 상시 +5 는 멈춘다.
	var e := _estate(1)
	e.morale = 19
	for i in 3:
		e.note_floor_cleared()
	e.stores["food"] = 100
	for i in 5:
		e.note_floor_cleared()
	e.morale = 48
	assert_eq(int(e.note_floor_cleared()["delta"]), 2, "50 을 넘기지 않는다")
	assert_eq(e.morale, 50)
	assert_false(e.recovering, "기준에 닿으면 회복이 끝난다")
	assert_eq(int(e.note_floor_cleared()["delta"]), 0, "그 뒤에는 식량으로 더 오르지 않는다")


func test_strike_stops_estate_and_hero_work() -> void:
	var e := _estate(1)
	e.clock_epoch = 1000
	e.morale = 19
	for i in 3:
		e.note_floor_cleared()
	var out := e.settle(1000 + 12343, 0, [_hero()])
	assert_eq(out["harvest"], {}, "파업 중에는 채집팀이 안 나간다")
	assert_eq(out["work"], {}, "영웅 일과도 멈춘다")
	assert_eq(int(e.stores["food"]), 0, "수확 없이 소비만 한다")
	assert_true(String(out["log"][1]).begins_with("파업 중"), "정산 로그가 파업을 적는다")


func test_strike_ends_after_five_floors_and_work_resumes() -> void:
	var e := _estate(1)
	e.morale = 19
	for i in 3:
		e.note_floor_cleared()
	assert_eq(e.strike_floors_left, 5)
	for i in 4:
		e.note_floor_cleared()
	assert_eq(e.strike_floors_left, 1, "4층 지나면 1층 남는다")
	var out := e.note_floor_cleared()
	assert_true(bool(out["strike_ended"]))
	assert_false(e.is_striking())
	assert_gt(int(e.harvest().get("food", 0)), 0, "파업이 끝나면 생산이 돌아온다")


func test_strike_survives_the_save() -> void:
	var e := _estate(1)
	e.morale = 19
	for i in 3:
		e.note_floor_cleared()
	var back := FonsEstate.new()
	back.start(_estate_data(), 1)
	back.from_save(e.to_save())
	assert_eq(back.strike_floors_left, 5, "남은 파업 층이 저장된다")
	assert_true(back.is_striking())
	assert_true(back.recovering, "회복 중 상태도 같이 저장된다")


func _strike(floor_value: int = 12, food: int = 1000) -> FonsEstate:
	## 파업 한가운데 — 식량이 있어도 민심 20 미만이면 연속 층이 쌓인다.
	var e := _estate(floor_value)
	e.stores["food"] = food
	e.morale = 19
	for i in 3:
		e.note_floor_cleared()
	return e


func test_decrees_are_the_three_from_the_gdd_table() -> void:
	# 04 §3.7 — 중상주의 · 분배주의 · 채집장려. 없는 종을 만들지 않는다.
	var e := _estate(12)
	var ids: Array = []
	for entry in e.decrees():
		ids.append(String(entry.get("id", "")))
	assert_eq(ids, ["mercantilism", "distribution", "gathering"], "칙령 3종")


func test_mercantilism_raises_tax_and_costs_morale() -> void:
	var e := _estate(12)
	e.stores["food"] = 1000
	var out := e.set_decree("mercantilism")
	assert_true(bool(out["ok"]))
	assert_eq(e.morale, 35, "50 에서 민심 -15")
	e.clock_epoch = 1000
	var day := e.settle(1000 + 12343 * 99, 0)
	assert_eq(int(day["tax"]), 39, "주민 30 × 1G × 1.3")


func test_gathering_edict_raises_harvest_and_costs_morale() -> void:
	var e := _estate(12)
	assert_true(bool(e.set_decree("gathering")["ok"]))
	assert_eq(e.morale, 45, "50 에서 민심 -5")
	# 150 × (1+12/50) × 민심 45 보정 0.98 × 1.2 = 218.7
	assert_eq(int(e.harvest().get("food", 0)), 219, "채집 +20% 가 민심 보정 위에 곱해진다")


func test_distribution_effects_follow_the_table() -> void:
	# 04 §3.7 — 민심 +15 · 세금 ×0.8 · 자연증가 ×1.5.
	var e := _estate(12)
	e.stores["food"] = 1000
	e.set_decree("distribution")
	assert_eq(e.morale, 65)
	e.clock_epoch = 1000
	# 100일째 = 여름 (자연증가 배율 1.0). 계절 배율이 섞이지 않아야 칙령 효과만 보인다.
	var out := e.settle(1000 + 12343 * 99, 0)
	assert_eq(int(out["tax"]), 24, "주민 30 × 1G × 0.8")
	assert_almost_eq(float(out["population"]), 30.9, 0.001, "자연증가 2% × 1.5")


func test_distribution_edict_ends_the_strike_when_food_is_in_surplus() -> void:
	# 04 §3.12 — 파업 중에 식량 흑자면 칙령을 바꿔 조기 종료한다.
	var e := _strike()
	assert_true(e.is_striking(), "전제 — 파업 중")
	var out := e.set_decree("distribution")
	assert_true(bool(out["ok"]))
	assert_true(bool(out["ended_strike"]))
	assert_false(e.is_striking())
	assert_eq(e.morale, 34, "19 에서 칙령 +15")
	assert_true(e.recovering, "끝난 뒤에도 회복 +5/층 은 돌아간다")
	assert_eq(int(e.unrest_floors), 0, "불만도 같이 지운다")


func test_edict_swap_needs_food_surplus_during_a_strike() -> void:
	# 흑자가 아닌데 끝낼 수 있으면 식량은 파업의 구제가 아니다.
	var e := _strike(12, 10)
	var out := e.set_decree("mercantilism")
	assert_false(bool(out["ok"]))
	assert_string_contains(String(out["reason"]), "식량")
	assert_true(e.is_striking(), "파업은 그대로")
	assert_eq(e.morale, 19, "칙령도 적용되지 않는다")


func test_edict_needs_the_unlock_floor() -> void:
	# 칙령은 10층 해금 (04 §3.7).
	var e := _estate(5)
	var out := e.set_decree("distribution")
	assert_false(bool(out["ok"]))
	assert_string_contains(String(out["reason"]), "10층")


func test_edict_cannot_be_applied_twice() -> void:
	# 민심 +15 가 두 번 붙으면 화면을 두 번 누르는 것만으로 수치가 부풀려진다.
	var e := _estate(12)
	e.set_decree("distribution")
	var out := e.set_decree("distribution")
	assert_false(bool(out["ok"]))
	assert_string_contains(String(out["reason"]), "이미")
	assert_eq(e.morale, 65)


func test_the_edict_survives_the_save() -> void:
	var e := _estate(12)
	e.set_decree("gathering")
	var back := FonsEstate.new()
	back.start(_estate_data(), 12)
	back.from_save(e.to_save())
	assert_eq(String(back.decree_id), "gathering", "칙령이 저장된다")


func test_unrest_gauge_appears_below_25_and_warns_at_15() -> void:
	# 04 §3.5·§3.12 — 민심 25 미만이면 불만 게이지, 15 이하면 경고. 수치는 `morale_unrest` 가 정한다.
	var e := _estate(1)
	e.morale = 25
	assert_false(bool(e.unrest()["visible"]), "25 에서는 게이지가 뜨지 않는다")
	e.morale = 24
	var gauge := e.unrest()
	assert_true(bool(gauge["visible"]), "25 미만이면 게이지가 뜬다")
	assert_false(bool(gauge["warn"]), "24 는 아직 경고가 아니다")
	assert_eq(int(gauge["need"]), 3, "파업까지 3층")
	e.morale = 15
	assert_true(bool(e.unrest()["warn"]), "15 이하는 경고")
	e.morale = 16
	assert_false(bool(e.unrest()["warn"]), "16 은 경고가 아니다")


func test_unrest_gauge_counts_the_floors_toward_a_strike() -> void:
	# 게이지가 세는 것은 파업 직전 연속 층이다 (04 §3.12 "20 미달 3층").
	var e := _estate(1)
	e.morale = 19
	e.note_floor_cleared()
	e.note_floor_cleared()
	var gauge := e.unrest()
	assert_eq(int(gauge["floors"]), 2, "쌓인 층을 그대로 보여 준다")
	assert_false(bool(gauge["striking"]))
	e.note_floor_cleared()
	gauge = e.unrest()
	assert_true(bool(gauge["striking"]), "3층째에 파업")
	assert_false(bool(gauge["visible"]), "파업 중에는 HUD 가 파업을 대신 말한다")


func test_winter_entry_costs_morale_once() -> void:
	# estate.json winter.morale_delta = -5. 계절이 바뀌는 날 한 번만.
	var e := _estate(1)
	e.stores["food"] = 100000
	e.clock_epoch = 1000
	e.settle(1000 + 270 * 12343)   # 271일 = 겨울 시작
	assert_eq(e.morale, 45, "겨울 진입 -5")
	e.settle(1000 + 271 * 12343)
	assert_eq(e.morale, 45, "같은 계절에서는 다시 깎지 않는다")


func test_morale_and_hunger_survive_the_save() -> void:
	var e := _estate(1)
	e._altar_level = 0
	e.clock_epoch = 1000
	e.settle(1000 + 12343)
	e.morale = 41
	var back := FonsEstate.new()
	back.start(_estate_data(), 1)
	back.from_save(e.to_save())
	assert_eq(back.morale, 41, "민심이 저장된다")
	assert_eq(back.shortage_days, 1, "연속 부족일도 저장된다")


func test_rest_is_recovery_domain() -> void:
	var brain := _brain("느긋", ["나태", "소박"])
	var hero := _hero(brain)
	var e := _estate()
	e.recover([hero])
	var tag := String(brain.counters.keys()[0])
	assert_true(tag in ["휴식", "식사", "장비정비", "명상", "독서"], "저녁은 회복 태그만: %s" % tag)
