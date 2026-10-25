extends GutTest
## 직업별 기본 공격 102종 — `data/basic_attacks.json` 이 정본과 맞는지, 전투가 실제로
## 그 세 갈래를 후보로 올리고 쿨을 소비하는지 잠근다.
##
## 왜 이 테스트가 필요한가:
##   기본 공격은 **데이터만 늘리면 끝나지 않는다**. 전투가 `basics` 를 읽지 않으면
##   파일은 102줄인데 게임은 여전히 맨손 하나로 싸운다 — 게이트는 초록, 화면은 그대로다.

const JOBS := 34
const PER_JOB := 3


func _data() -> Dictionary:
	return DataLoader.load_json("basic_attacks.json")


func _tree() -> Dictionary:
	return DataLoader.load_json("job_tree.json")


func _catalog() -> Array:
	return DataLoader.load_json("skills_catalog.json").get("skills", [])


func test_every_job_has_three_attacks() -> void:
	var data := _data()
	assert_false(data.is_empty(), "basic_attacks.json 을 읽지 못했다")
	var jobs: Dictionary = data.get("jobs", {})
	assert_eq(jobs.size(), JOBS, "L1 7 + L2 26 + L3 1")
	var total := 0
	for job_id in jobs:
		assert_eq((jobs[job_id] as Array).size(), PER_JOB, job_id)
		total += (jobs[job_id] as Array).size()
	assert_eq(total, JOBS * PER_JOB)


func test_job_ids_match_the_tree() -> void:
	var tree_ids := {}
	for job in _tree().get("jobs", []):
		tree_ids[String(job["id"])] = true
	for job_id in (_data().get("jobs", {}) as Dictionary):
		assert_true(tree_ids.has(job_id), "직업 트리에 없는 id: " + job_id)


func test_ids_and_names_are_unique() -> void:
	var ids := {}
	var names := {}
	for job_id in (_data().get("jobs", {}) as Dictionary):
		for row in _data()["jobs"][job_id]:
			assert_false(ids.has(row["id"]), "중복 id: " + row["id"])
			assert_false(names.has(row["name"]), "중복 이름: " + row["name"])
			ids[row["id"]] = true
			names[row["name"]] = true


func test_tags_and_domains_exist_in_the_catalog() -> void:
	# 새 태그를 지어내지 않는다 — 스킬 카탈로그 104종 밖이면 각인·판단이 그 태그를 못 읽는다.
	var tags := {}
	var domains := {}
	for skill in _catalog():
		for tag in skill.get("tags", []):
			tags[tag] = true
		domains[String(skill.get("domain", ""))] = true
	for job_id in (_data().get("jobs", {}) as Dictionary):
		for row in _data()["jobs"][job_id]:
			assert_true(tags.has(row["tag"]), "카탈로그에 없는 태그: " + row["tag"])
			assert_true(domains.has(row["domain"]), "카탈로그에 없는 domain: " + row["domain"])


func test_install_uses_the_job_pool() -> void:
	var unit := {"job_id": "l2_summoner"}
	FonsBasicAttacks.install(unit, _data())
	assert_eq(unit["basics"].size(), PER_JOB)
	assert_eq(String(unit["basics"][0]["name"]), "떼로 자리를 채우기")
	for b in unit["basics"]:
		assert_eq(int(b["left"]), 0, "새 유닛은 쿨이 없다")
		assert_gte(int(b["cd"]), 1, "쿨은 최소 1턴")


func test_unknown_job_falls_back_to_nameless() -> void:
	var unit := {"job_id": "l9_nowhere"}
	FonsBasicAttacks.install(unit, _data())
	assert_eq(unit["basics"].size(), PER_JOB)
	assert_eq(String(unit["basics"][0]["name"]), "살피기", "무명자 풀")


func test_cooldown_converts_seconds_to_turns() -> void:
	assert_eq(FonsBasicAttacks.cooldown_turns(9.0), 4, "9초 = 3.6턴 → 4")
	assert_eq(FonsBasicAttacks.cooldown_turns(2.5), 1)
	assert_eq(FonsBasicAttacks.cooldown_turns(0.0), 1, "0초라도 같은 턴에 두 번 못 쓴다")


func test_consume_sets_cooldown_and_returns_power() -> void:
	var unit := {"job_id": "l2_summoner"}
	FonsBasicAttacks.install(unit, _data())
	var first: Dictionary = unit["basics"][0]
	var pct := FonsBasicAttacks.consume(unit, String(first["id"]))
	assert_eq(pct, 0.0, "지원 기본 공격은 피해 가산이 없다")
	assert_eq(int(first["left"]), int(first["cd"]))
	assert_eq(FonsBasicAttacks.consume(unit, String(first["id"])), 0.0, "쿨 중에는 못 쓴다")
	FonsBasicAttacks.tick(unit)
	assert_eq(int(first["left"]), int(first["cd"]) - 1)


func test_offense_attack_carries_damage_bonus() -> void:
	# 명사수 1번은 power 2.4 — (2.4−1)×100 = +140%.
	var unit := {"job_id": "l2_marksman"}
	FonsBasicAttacks.install(unit, _data())
	var row: Dictionary = unit["basics"][0]
	assert_eq(float(row["pct"]), 140.0)


func test_move_candidates_include_available_attacks_only() -> void:
	var unit := {
		"job_id": "l2_summoner", "name": "소환술사", "hp": 100, "maxHp": 100, "alive": true,
		"atk": 100.0, "mag": 100.0, "def": 0.0, "mdef": 0.0, "magical": true,
	}
	FonsBasicAttacks.install(unit, _data())
	var seen := 0
	for row in FonsBattle._move_candidates(unit):
		if row.has("basic_id"):
			seen += 1
	assert_eq(seen, PER_JOB, "쿨 0 인 세 갈래가 후보에 오른다")
	unit["basics"][1]["left"] = 3
	seen = 0
	for row in FonsBattle._move_candidates(unit):
		if String(row.get("basic_id", "")) == String(unit["basics"][1]["id"]):
			seen += 1
	assert_eq(seen, 0, "쿨 중인 기본 공격은 후보에서 빠진다")


func test_floor_log_names_a_job_attack() -> void:
	# 데이터·후보·쿨이 다 맞아도 **전투가 고르지 않으면** 화면에는 안 나온다.
	# 성격 AI + 기본 공격을 붙인 실제 1층 한 판에서 그 이름이 로그에 남는지 본다.
	var basics := _data()
	var ai := {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}
	var heroes := FonsRunState.heroes_from(DataLoader.load_json("races.json"), _tree(),
		DataLoader.load_json("equipment.json"), 5, 130, 1, DataLoader.load_json("job_coef.json"),
		0, 4, ai, basics)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var out := FonsFloorRun.simulate(rng, DataLoader.get_monsters(), DataLoader.get_biomes(),
		1, 0, heroes)
	var names := {}
	for hero in heroes:
		for b in hero.get("basics", []):
			names[String(b["name"])] = true
	var found := ""
	for line in out["log"]:
		for name in names:
			if String(line).contains(name):
				found = String(line)
				break
		if not found.is_empty():
			break
	assert_false(found.is_empty(), "1층 로그에 직업 기본 공격 이름이 없다: %s" % str(out["log"]))


func test_run_state_party_gets_the_job_pool() -> void:
	var basics := _data()
	var heroes := FonsRunState.heroes_from(DataLoader.load_json("races.json"), _tree(),
		DataLoader.load_json("equipment.json"), 5, 130, 7, DataLoader.load_json("job_coef.json"),
		0, 4, {}, basics)
	assert_eq(heroes.size(), 4)
	for hero in heroes:
		assert_eq((hero.get("basics", []) as Array).size(), PER_JOB,
			"직업이 있는 영웅은 기본 공격 세 갈래를 들고 태어난다")
