extends GutTest
## 층 진행 상태 — 시작 → 한 층 → 이기면 다음 층. 화면 없이 도는 경로를 잠근다.
##
## 이 파일이 잠그는 것:
##   · 영웅 4인이 데이터 기준스탯으로 만져진다 (만피로 시작)
##   · 이겼을 때만 다음 층으로 간다 (지고 나서도 층이 오르면 거짓 진행이다)
##   · 스냅샷이 뷰가 읽는 형식이다 (Vector3 위치 · hp/max_hp · 문자열 id)

func _state(seed_value: int = 1, start_floor: int = 1) -> FonsRunState:
	# 게임이 실제로 부르는 조합과 같다 (main.gd) — 직업계수를 빼면 이 테스트만 다른 판을 돈다.
	var st := FonsRunState.new()
	st.start(DataLoader.load_json("races.json"), DataLoader.get_monsters(),
		DataLoader.get_biomes(), seed_value, start_floor,
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		DataLoader.load_json("job_coef.json"))
	return st


func test_heroes_from_data_start_at_full_hp() -> void:
	var heroes := FonsRunState.heroes_from(DataLoader.load_json("races.json"))
	assert_eq(heroes.size(), FonsRunState.PARTY_SIZE, "영웅 4인")
	for h in heroes:
		assert_eq(h["hp"], h["maxHp"], "만피로 만들어진다")
		assert_true(h["hp"] > 0)
		assert_eq(h["side"], "ally")


func test_heroes_carry_a_job_card_and_variance() -> void:
	# Phase 2.6 — 키워드 카드 한 장 + 개체 변량. 4인이 전부 같은 숫자면 변량이 안 걸린 것이다.
	var heroes := FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"), 5, 130, 7)
	var hps := {}
	var jobs := {}
	for h in heroes:
		assert_true(h.has("job"), "직업이 붙어 있다")
		assert_gt(String(h["keyword"]).length(), 0, "키워드 카드가 붙어 있다")
		hps[h["hp"]] = true
		jobs[h["job"]] = true
	assert_gt(hps.size(), 1, "개체 변량으로 HP 가 갈린다")
	assert_gt(jobs.size(), 1, "파티원이 서로 다른 카드를 든다")


func test_keyword_mod_follows_the_original_accumulation_rule() -> void:
	# 원본 규칙 (Unity `ProgressionData.Accumulate`): 일반 L2 는 키워드 3장을 **전부** 곱하고,
	# 종점(키워드 7장 L2 — 정령기사·원소마도사)은 1장만 곱한다.
	# 현행 포팅은 직업당 첫 카드 **1장만** 곱했다 — 원본과 다르다.
	var tree: Dictionary = DataLoader.load_json("job_tree.json")
	var job := _job_of(tree, "l2_ironwall")
	var mod := FonsRunState.keyword_mod_for(job)
	var expect: Array = []
	for a in FonsHeroStats.AXES.size():
		expect.append(1.0)
	for card in job.get("keywords", []):
		var sm: Array = card.get("statMod", [])
		for a in FonsHeroStats.AXES.size():
			expect[a] = float(expect[a]) * float(sm[a])
	for a in FonsHeroStats.AXES.size():
		assert_almost_eq(float(mod[a]), float(expect[a]), 0.0001, "축 %d — 3장 전부 곱" % a)

	var term := _job_of(tree, "l2_spirit_knight")
	var tmod := FonsRunState.keyword_mod_for(term)
	var first: Array = term.get("keywords", [])[0].get("statMod", [])
	for a in FonsHeroStats.AXES.size():
		assert_almost_eq(float(tmod[a]), float(first[a]), 0.0001, "축 %d — 종점은 1장만" % a)

	# 종점 판정은 **카드 수가 아니라 직업 id** 로 한다 (원본 `TerminalKeywordCounts` — 원본 대조).
	# 대현자(l2_sage)는 카드가 1장뿐이라 카드 수로 판정해도 같지만, 장수로 판정하면
	# "7장이 아닌 종점" 과 "7장짜리 일반 직업" 이 갈린다.
	var sage := _job_of(tree, "l2_sage")
	assert_eq(FonsRunState.applied_cards(sage).size(), 1, "대현자 — 카드 1장")
	assert_eq(FonsRunState.applied_cards(_job_of(tree, "l2_ironwall")).size(), 3, "철벽기사 — 3장 전부")
	assert_eq(FonsRunState.applied_cards(term).size(), 1, "정령기사 — 7장 중 1장")
	assert_eq(FonsRunState.applied_cards(_job_of(tree, "l3_life")).size(), 13, "생활직 — 13장 전부")


func test_party_gains_all_cards_not_one() -> void:
	# 편성된 파티원도 3장 곱을 받는다 — 1장짜리보다 HP 가 크다.
	var races: Dictionary = DataLoader.load_json("races.json")
	var tree: Dictionary = DataLoader.load_json("job_tree.json")
	var one := FonsRunState.heroes_from(races, tree, {}, 5, 130, 3, {}, 1)
	var all := FonsRunState.heroes_from(races, tree, {}, 5, 130, 3, {}, 3)
	for i in one.size():
		assert_gt(int(all[i]["maxHp"]), int(one[i]["maxHp"]), "파티원 %d — 3장 곱이 1장보다 크다" % i)


func test_five_hero_party_gives_every_hero_a_job_and_a_brain() -> void:
	# 필드 파티는 5인이다 (확정 #3). 그런데 직업은 `keyword_jobs` 기본값 4개만 뽑혀서
	# 다섯 번째가 직업계수·직업명·브레인 없이 홀로 남았다 — 화면에서도 그 한 명만 달랐다.
	var ai := {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}
	var heroes := FonsRunState.heroes_from(DataLoader.load_json("races.json"),
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		5, 130, 11, DataLoader.load_json("job_coef.json"), 0, 5, ai)
	assert_eq(heroes.size(), 5, "다섯을 만든다")
	var jobs := {}
	for i in heroes.size():
		var job_id := String(heroes[i].get("job_id", ""))
		assert_false(job_id.is_empty(), "%d번 영웅에 직업이 붙는다" % (i + 1))
		assert_false(String(heroes[i].get("job", "")).is_empty(), "%d번 영웅에 직업명이 붙는다" % (i + 1))
		assert_true(FonsBrain.attached(heroes[i]), "%d번 영웅에 브레인이 붙는다" % (i + 1))
		jobs[job_id] = true
	assert_eq(jobs.size(), 5, "다섯이 서로 다른 직업 — 직업 id 가 키다")


func _job_of(tree: Dictionary, job_id: String) -> Dictionary:
	for job in tree.get("jobs", []):
		if String(job.get("id", "")) == job_id:
			return job
	return {}


func test_equipment_and_keywords_raise_the_party() -> void:
	# 성장 축이 실제로 전투 유닛까지 오는지 — 없을 때와 있을 때를 같은 시드로 비교한다.
	var races: Dictionary = DataLoader.load_json("races.json")
	var bare := FonsRunState.heroes_from(races, {}, {}, 5, 130, 3)
	var grown := FonsRunState.heroes_from(races, DataLoader.load_json("job_tree.json"),
		DataLoader.load_json("equipment.json"), 5, 130, 3)
	assert_gt(int(grown[0]["maxHp"]), int(bare[0]["maxHp"]), "3등급 장비가 HP 를 올린다")
	assert_gt(float(grown[0]["atk"]), 0.0)


func test_job_coefficient_reaches_the_party() -> void:
	# 직업계수는 카드의 job_id 로 찾는다 — 같은 시드에서 계수만 빼면 파티 스탯이 달라져야 한다.
	var races: Dictionary = DataLoader.load_json("races.json")
	var tree: Dictionary = DataLoader.load_json("job_tree.json")
	var coef: Dictionary = DataLoader.load_json("job_coef.json")
	var flat := FonsRunState.heroes_from(races, tree, {}, 5, 130, 3)
	var with_job := FonsRunState.heroes_from(races, tree, {}, 5, 130, 3, coef)
	var differ := 0
	for i in flat.size():
		if int(flat[i]["maxHp"]) != int(with_job[i]["maxHp"]):
			differ += 1
	assert_gt(differ, 0, "계수를 건 파티원의 HP 가 달라진다")
	for h in with_job:
		assert_gt(int(h["maxHp"]), 0, "계수로 HP 가 사라지지 않는다")


func test_start_runs_the_first_floor() -> void:
	var st := _state()
	assert_eq(st.heroes.size(), FonsRunState.PARTY_SIZE)
	assert_eq(st.floor, 1)
	assert_gt(st.log_lines.size(), 0, "1층 판이 실제로 돌아 로그가 남는다")
	assert_gt(st.party_alive(), 0, "1층에서 전멸하지는 않는다")


func test_floor_one_is_cleared_by_data_heroes() -> void:
	var st := _state()
	assert_eq(st.winner, "ally", "★5 Lv130 4인이면 1층은 뚫린다")
	assert_gt(st.party_alive(), 0)


func test_next_floor_advances_after_a_win_and_carries_hp() -> void:
	var st := _state()
	var before: int = int(st.heroes[0]["hp"])
	assert_true(st.next_floor(), "이겼으니 다음 층으로 간다")
	assert_eq(st.floor, 2)
	assert_true(int(st.heroes[0]["hp"]) <= before, "영웅 HP 는 층 사이에 회복되지 않는다")
	assert_gt(st.enemies.size(), 0, "새 층의 적이 새로 편성된다")


func test_next_floor_refuses_after_a_loss() -> void:
	# 지거나 비기면 진행하지 않는다 — 이기지 않은 층을 지나가면 층 번호가 거짓말이 된다.
	var st := _state(1, 130)
	if st.winner == "ally":
		assert_true(true, "130층을 이기는 시드라 이 검사는 의미가 없다")
		return
	assert_false(st.next_floor(), "패배·무승부 뒤에는 진행 없음")
	assert_eq(st.floor, 130, "층 번호가 그대로다")


func test_restart_returns_to_floor_one_with_a_fresh_party() -> void:
	var st := _state()
	var first_log: Array = st.log_lines.duplicate()
	st.next_floor()
	st.restart()
	assert_eq(st.floor, 1, "재시작은 1층으로 돌린다")
	assert_eq(st.log_lines, first_log, "같은 시드·같은 층이면 같은 판이 다시 돈다")
	for h in st.heroes:
		assert_gt(int(h["hp"]), 0, "새 영웅으로 다시 시작한다")


func test_snapshot_shape() -> void:
	var st := _state()
	var snap := st.snapshot()
	assert_eq(snap["floor"], 1)
	assert_eq(snap["winner"], "ally")
	assert_eq(snap["entities"].size(), st.heroes.size() + st.enemies.size())
	assert_true(snap["log"].size() <= FonsRunState.LOG_TAIL, "로그는 꼬리만 보낸다")
	var ids := {}
	for e in snap["entities"]:
		assert_true(e["pos"] is Vector3, "위치는 Vector3 다 (R2)")
		assert_true(e["max_hp"] > 0, "HP 바를 그릴 수 있어야 한다")
		assert_false(ids.has(e["id"]), "id 는 유일하다: %s" % e["id"])
		ids[e["id"]] = true
		assert_true(String(e["kind"]) in ["hero", "monster"])


func test_same_seed_same_snapshot() -> void:
	var a := _state(42).snapshot()
	var b := _state(42).snapshot()
	assert_eq(a["log"], b["log"], "같은 시드 = 같은 로그")
	assert_eq(a["winner"], b["winner"])


func test_start_clamps_the_floor() -> void:
	var st := _state(1, 0)
	assert_eq(st.floor, 1, "0층은 1층으로 자른다")
	var high := _state(1, 999)
	assert_eq(high.floor, FonsRunState.MAX_FLOOR, "상한 130")
