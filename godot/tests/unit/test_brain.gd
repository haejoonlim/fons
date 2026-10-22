extends GutTest
## 영웅 판단 — "같은 직업 쌍둥이가 성격 때문에 다르게 행동하는가"를 잠근다.
##
## 이 파일이 잠그는 것 (09 §4-2 다양성 장치 5건):
##   ① 성격 취향이 행동 분포를 가른다 (난폭은 때리고, 신중은 버틴다)
##   ② 개체 시드 — 같은 개체는 같은 결정을 반복한다 (결정론)
##   ③ 습관 — 반복한 행동이 선호로 굳고, 4연속부터 지루해진다
##   ④ 문맥 — 같은 개체가 저체력·야간에서 다르게 군다
##   ⑤ 직업 금지 태그는 후보에서 0 (banned_tags)
## 그리고 행동 기록이 각인·연계로 이어지는지 (스킬은 해온 일에서 생긴다)

const JOB := "l2_breaker"   # 파쇄사 (선봉 · 마법시전 금지)


func _data() -> Dictionary:
	return DataLoader.load_json("personalities.json")


func _job() -> Dictionary:
	return DataLoader.load_json("job_ai_profiles.json")["profiles"][JOB]


func _catalog() -> Array:
	return DataLoader.load_json("skills_catalog.json")["skills"]


func _brain(main: String, subs: Array, seed_value: int = 3) -> FonsBrain:
	var b := FonsBrain.new()
	b.setup({"main": main, "subs": subs, "seed": seed_value}, _data(), _job(), "선봉",
		_catalog(), seed_value)
	return b


func _candidates() -> Array:
	return [
		{"action": "공격", "tag": "근접타격", "domain": "공격", "stat": "ATK", "stat_value": 100.0},
		{"action": "방어", "tag": "방어태세", "domain": "방어·제어"},
		{"action": "치유", "tag": "치유", "domain": "지원"},
		{"action": "정찰", "tag": "정찰", "domain": "기동"},
	]


func _ctx() -> Dictionary:
	return {"hp_ratio": 1.0, "party_avg": {"ATK": 100.0}, "enemy_count": 3}


func _pick(b: FonsBrain, runs: int) -> Dictionary:
	var counts := {}
	for i in runs:
		var chosen := b.decide(_candidates(), _ctx())
		var tag := String(chosen.get("tag", "?"))
		counts[tag] = int(counts.get(tag, 0)) + 1
		b.commit(chosen)
	return counts


func test_same_seed_gives_the_same_decisions() -> void:
	var a := _brain("교활", ["재치", "책략"], 12)
	var b := _brain("교활", ["재치", "책략"], 12)
	var seq_a: Array = []
	var seq_b: Array = []
	for i in 40:
		var ca := a.decide(_candidates(), _ctx())
		var cb := b.decide(_candidates(), _ctx())
		seq_a.append(String(ca.get("tag", "")))
		seq_b.append(String(cb.get("tag", "")))
		a.commit(ca)
		b.commit(cb)
	assert_eq(seq_a, seq_b, "같은 성격·같은 시드 = 같은 사람")


func test_personality_splits_a_twin_pair() -> void:
	# 같은 직업·같은 후보·같은 상황 — 성격만 다르다.
	var rage := _brain("난폭", ["격정", "충동"], 21)
	var careful := _brain("신중", ["관조", "침울"], 22)
	var c_rage := _pick(rage, 240)
	var c_careful := _pick(careful, 240)
	var attack_rage := float(c_rage.get("근접타격", 0))
	var attack_careful := float(c_careful.get("근접타격", 0))
	var hold_rage := float(c_rage.get("방어태세", 0)) + float(c_rage.get("치유", 0))
	var hold_careful := float(c_careful.get("방어태세", 0)) + float(c_careful.get("치유", 0))
	assert_gt(attack_rage, attack_careful * 1.3, "난폭이 훨씬 자주 때린다 (%.0f vs %.0f)" % [attack_rage, attack_careful])
	assert_gt(hold_careful, hold_rage * 1.3, "신중이 훨씬 자주 버틴다 (%.0f vs %.0f)" % [hold_careful, hold_rage])
	assert_gte(rage.decisions.size(), 2, "한 사람이 한 가지만 고르지는 않는다 (소프트맥스)")


func test_habit_sticks_then_bores() -> void:
	var b := _brain("고집", ["꾸준", "세심"], 5)
	var scout := {"action": "정찰", "tag": "정찰", "domain": "기동"}
	for i in 3:
		b.commit(scout)
	var fresh: float = b.routine_factor("정찰")
	var other: float = b.routine_factor("방어태세")
	assert_gt(fresh, other, "세 번 했으니 더 좋아한다 (R항)")
	for i in 6:
		b.commit(scout)
	assert_eq(b.streak, 9)
	var bored: float = b.routine_factor("정찰")
	assert_lt(bored, fresh, "9연속이면 지루해진다 (피로)")
	assert_gte(bored, FonsBrain.FATIGUE_FLOOR, "피로 하한 아래로는 안 내려간다")


func test_context_changes_the_same_person() -> void:
	var b := _brain("신중", ["관조", "침울"], 8)
	var retreat := {"action": "후퇴", "tag": "후퇴", "domain": "기동"}
	var healthy := b.context_factor("후퇴", {"hp_ratio": 1.0})
	var wounded := b.context_factor("후퇴", {"hp_ratio": 0.2})
	assert_almost_eq(healthy, 1.0, 0.001, "만피에서는 후퇴가 매력 없음")
	assert_gt(wounded, 2.0, "저체력이면 후퇴 ×2/기질")
	var help := b.context_factor("치유", {"ally_hurt": true})
	assert_gt(help, 1.5, "아군이 다치면 치유가 올라온다")
	var splash := b.context_factor("광역살포", {"enemy_count": 4})
	assert_almost_eq(splash, 1.5, 0.001, "적 다수 → 광역 ×1.5 (09 §4-1 예시)")


func test_practice_bias_is_a_score_factor() -> void:
	# 연습 열기는 피해가 아니라 **선택**을 움직인다 — 점수 항 P 로만 들어간다.
	var b := _brain("성실", ["근면", "꾸준"], 7)
	var move := {"action": "공격", "tag": "근접타격", "domain": "공격", "stat": "ATK", "stat_value": 100.0}
	var cold := b.score(move, _ctx())
	var hot_move := move.duplicate()
	hot_move["bias"] = 1.15
	var hot := b.score(hot_move, _ctx())
	assert_almost_eq(float(cold["P"]), 1.0, 0.001, "bias 없으면 1.0")
	assert_almost_eq(float(hot["P"]), 1.15, 0.001, "bias 는 P 항에 그대로")


func test_banned_tag_scores_zero() -> void:
	var b := _brain("냉정", ["명석", "이성"], 4)
	var ban := {"action": "마법", "tag": "마법시전", "domain": "공격"}
	var row := b.score(ban, _ctx())
	assert_almost_eq(float(row["J"]), 0.0, 0.0001, "파쇄사는 마법시전 금지")
	assert_almost_eq(float(row["total"]), 0.0, 0.0001, "금지 태그는 후보에서 죽는다")


func test_commit_engraves_and_mirrors_counters() -> void:
	var b := _brain("성실", ["근면", "꾸준"], 31)
	var unit := {"name": "영웅 1"}
	for i in 30:
		var born: Dictionary = b.commit({"action": "공격", "tag": "근접타격", "domain": "공격"})
		if not born["born"].is_empty():
			break
	assert_gt(b.book.size(), 0, "30번 반복하면 하나는 각인된다 (50%% 판정)")
	assert_lte(b.book.size(), 32)
	for id in b.book:
		assert_true(String(b.book[id]["name"]) in _catalog_names(), "카탈로그 이름만 쓴다")
	b.mirror(unit)
	assert_eq(int(unit["tags"]["근접타격"]), int(b.counters["근접타격"]), "유닛 태그는 브레인의 거울")
	assert_gt(FonsSkillBook.factor(b.book, "근접타격"), 1.0, "각인된 스킬이 K항을 올린다")


func test_links_become_fusion_candidates() -> void:
	# 연계는 **스킬과 스킬 사이**다 — 태그가 아니라서 부모 두 개가 각인돼 있어야 한다 (09 §6).
	var b := _brain("교활", ["재치", "책략"], 9)
	b.book["201"] = {"name": "A기술", "rarity": 1, "tags": ["매복"], "stage": 1, "level": 1, "xp": 0}
	b.book["202"] = {"name": "B기술", "rarity": 1, "tags": ["근접타격"], "stage": 1, "level": 1, "xp": 0}
	for i in 4:
		b.commit({"action": "매복", "tag": "매복", "domain": "기동", "skill_id": "201"})
		b.commit({"action": "공격", "tag": "근접타격", "domain": "공격", "skill_id": "202"})
	assert_eq(int(b.links.get("A기술|B기술", 0)), 4, "A→B 연계를 센다")
	assert_eq(int(b.links.get("B기술|A기술", 0)), 3, "방향이 다르면 다른 연계다")
	assert_false(b.links.has("매복|근접타격"), "태그끼리는 연계가 아니다")
	assert_eq(int(b.link_sessions.get("A기술|B기술", 0)), 1, "한 판 안의 반복은 1세션")
	for f in [2, 3]:
		b.floor = f
		b.commit({"action": "매복", "tag": "매복", "domain": "기동", "skill_id": "201"})
		b.commit({"action": "공격", "tag": "근접타격", "domain": "공격", "skill_id": "202"})
	assert_eq(int(b.link_sessions.get("A기술|B기술", 0)), 3, "판이 바뀌면 새 세션으로 센다")
	var cands := FonsFusion.candidates(b, _catalog())
	var found := false
	for c in cands:
		if String(c["key"]) == "A기술|B기술":
			found = true
	assert_true(found, "3판에서 함께 쓴 연계가 심사대에 오른다")


func test_context_tags_are_counted() -> void:
	# L 스킬은 태그 910 + 문맥 26 = 936 이다 — 문맥이 합계에 들어간다 (09 §5).
	var b := _brain("냉정", ["야망", "이성"], 2)
	b.note_context({"night": true, "crowd": true, "boss": false})
	assert_eq(int(b.counters.get("야간", 0)), 1)
	assert_eq(int(b.counters.get("다수적", 0)), 1)
	assert_false(b.counters.has("보스급"), "없는 문맥은 안 센다")


func _catalog_names() -> Array:
	var names: Array = []
	for skill in _catalog():
		names.append(String(skill["name"]))
	return names


func _ai() -> Dictionary:
	return {"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json")}


func _fight(seed_value: int) -> Dictionary:
	var heroes := FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		5, 130, seed_value, DataLoader.load_json("job_coef.json"), 0,
		FonsRunState.PARTY_SIZE, _ai())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return FonsFloorRun.simulate(rng, DataLoader.get_monsters(), DataLoader.get_biomes(), 3, 0, heroes, 60)


func test_battle_runs_with_brains_and_stays_deterministic() -> void:
	# 전투가 브레인을 실제로 쓰는 경로 — 여기서 죽으면 게임이 안 돌아간다.
	var a := _fight(5)
	var b := _fight(5)
	assert_eq(String(a["winner"]), String(b["winner"]), "같은 시드 = 같은 결과")
	assert_eq(a["log"], b["log"], "같은 시드 = 같은 로그 (결정론)")
	assert_gt(int(a["turns"]), 0)


func test_battle_records_decisions_and_tags() -> void:
	var heroes := FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		5, 130, 7, DataLoader.load_json("job_coef.json"), 0, FonsRunState.PARTY_SIZE, _ai())
	for h in heroes:
		assert_true(FonsBrain.attached(h), "성격이 붙는다")
		assert_gt(String(h["personality"]).length(), 0, "메인 성향이 있다")
		assert_eq(h["traits"].size(), 2, "부가 2종")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	FonsFloorRun.simulate(rng, DataLoader.get_monsters(), DataLoader.get_biomes(), 3, 0, heroes, 60)
	var acted := 0
	for h in heroes:
		var b: FonsBrain = h["brain"]
		acted += b.decisions.size()
		assert_eq(int(h["tags"].size()), b.counters.size(), "유닛 태그는 브레인의 거울")
	assert_gt(acted, 0, "판단이 기록된다")


func test_record_action_routes_life_actions_to_counters() -> void:
	# 영지·탐험이 부르는 공용 문 — 브레인이 있으면 각인 판정까지, 없으면 태그 거울만.
	var brain := _brain("성실", ["근면", "꾸준"])
	var unit := {"name": "가", "brain": brain}
	FonsBrain.record_action(unit, "걷기")
	assert_eq(int(brain.counters.get("정찰", 0)), 1)
	assert_eq(int(brain.counters.get("영역이동", 0)), 1, "한 행동이 태그 둘")
	assert_eq(int(unit["tags"].get("정찰", 0)), 1, "유닛 태그는 거울")
	var plain := {"name": "나"}
	FonsBrain.record_action(plain, "채집")
	assert_eq(FonsActionTags.count(plain, "채집"), 1, "브레인이 없으면 태그만 오른다")


func test_personality_never_touches_stats() -> void:
	# 09 §4-1 불변식 — 성격은 행동 선호만 바꾼다. 스탯이 흔들리면 CP 가 오염된다.
	var plain := FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"), 5, 130, 11,
		DataLoader.load_json("job_coef.json"))
	var with_ai := FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		5, 130, 11, DataLoader.load_json("job_coef.json"), 0, FonsRunState.PARTY_SIZE, _ai())
	for i in plain.size():
		assert_eq(int(plain[i]["maxHp"]), int(with_ai[i]["maxHp"]), "HP 불변")
		assert_almost_eq(float(plain[i]["atk"]), float(with_ai[i]["atk"]), 0.001, "ATK 불변")
		assert_almost_eq(float(plain[i]["def"]), float(with_ai[i]["def"]), 0.001, "DEF 불변")
