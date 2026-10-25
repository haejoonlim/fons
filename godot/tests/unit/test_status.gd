extends GutTest
## 기본 공격의 지원·제어 효과 — 치유 · 보호막 · 도발.
##
## 이 파일이 잠그는 것:
##   · 가장 다친 아군이 치유·보호막 대상이 된다
##   · 보호막이 피해를 먹고, 턴이 지나면 사라진다
##   · 도발 중인 아군이 적의 표적이 된다
##   · 데이터의 지원·제어 태그가 실제로 효과와 연결돼 있다


func _unit(name: String, hp: int, extra: Dictionary = {}) -> Dictionary:
	var u := {
		"name": name, "side": "ally", "hp": hp, "maxHp": hp, "alive": hp > 0,
		"atk": 0.0, "def": 0.0, "pen": 0.0, "eva": 0.0, "cri": 0.0, "cdmg": 0.0,
		"mag": 0.0, "mdef": 0.0, "magical": false,
	}
	for k in extra:
		u[k] = extra[k]
	return u


func _move(tag: String) -> Dictionary:
	return {"basic_id": "ba_test", "tag": tag, "action": "시험"}


func test_heal_goes_to_the_most_hurt_ally() -> void:
	var actor := _unit("신관", 1000)
	var hurt := _unit("자객", 1000)
	hurt["hp"] = 100
	var party: Array = [actor, hurt]
	var out := FonsStatus.act(actor, party, _move("치유"))
	assert_false(out.is_empty())
	assert_eq(int(hurt["hp"]), 220, "최대 HP 12% 회복")
	assert_true(String(out["text"]).contains("치유"))


func test_heal_does_not_overflow_max_hp() -> void:
	var actor := _unit("신관", 1000)
	var hurt := _unit("자객", 1000)
	hurt["hp"] = 950
	FonsStatus.act(actor, [actor, hurt], _move("치유"))
	assert_eq(int(hurt["hp"]), 1000)


func test_shield_absorbs_damage() -> void:
	var actor := _unit("수호자", 1000)
	var target := _unit("전사", 1000)
	target["hp"] = 500
	FonsStatus.act(actor, [actor, target], _move("보호막"))
	assert_eq(float(target["shield"]), 150.0, "최대 HP 15%")
	var striker := _unit("적", 1000, {"atk": 100.0})
	var before := int(target["hp"])
	FonsBattle.strike(RandomNumberGenerator.new(), striker, target)
	assert_eq(int(target["hp"]), before, "100 피해를 보호막 150이 전부 먹는다")
	assert_eq(float(target["shield"]), 50.0)


func test_shield_expires() -> void:
	var actor := _unit("수호자", 1000)
	FonsStatus.act(actor, [actor], _move("방어태세"))
	assert_gt(float(actor["shield"]), 0.0, "자기 보호막")
	for i in FonsStatus.SHIELD_TURNS:
		FonsStatus.tick(actor)
	assert_eq(float(actor["shield"]), 0.0)
	assert_eq(int(actor["shield_turns"]), 0)


func test_taunt_redirects_enemy_attack() -> void:
	var taunter := _unit("전사", 10000)
	var weak := _unit("자객", 100)
	var party: Array = [taunter, weak]
	var enemy := _unit("적", 100000, {"side": "enemy", "atk": 500.0})
	FonsStatus.act(taunter, party, _move("도발"))
	assert_eq(int(taunter["taunt"]), FonsStatus.TAUNT_TURNS)
	var out := FonsBattle.combat_step(RandomNumberGenerator.new(), party, [enemy],
		FonsBattle.make_gauge(1))
	assert_eq(int(weak["hp"]), 100, "도발 중에는 자객을 치지 않는다")
	assert_lt(int(taunter["hp"]), 10000, "적이 도발한 전사를 친다")
	assert_true(not (out["log"] as Array).is_empty())


func test_taunt_expires() -> void:
	var actor := _unit("전사", 1000)
	FonsStatus.act(actor, [actor], _move("도발"))
	FonsStatus.tick(actor)
	FonsStatus.tick(actor)
	assert_eq(int(actor["taunt"]), 0)


func test_ai_actually_uses_an_effect() -> void:
	# 단위 테스트만으로는 "게임에서 실제로 걸리는가"를 모른다. 성격 AI + 기본 공격으로
	# 여러 시드의 1층을 돌려, 효과 로그가 한 번이라도 나오는지 본다.
	var basics: Dictionary = DataLoader.load_json("basic_attacks.json")
	var ai := {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}
	var found := ""
	for seed_value in range(1, 21):
		var heroes := FonsRunState.heroes_from(DataLoader.load_json("races.json"),
			DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
			5, 130, seed_value, DataLoader.load_json("job_coef.json"), 0, 4, ai, basics)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var out := FonsFloorRun.simulate(rng, DataLoader.get_monsters(),
			DataLoader.get_biomes(), 1, 0, heroes)
		for line in out["log"]:
			for mark in ["「치유」", "「보호막」", "「도발」"]:
				if String(line).contains(mark):
					found = String(line)
					break
			if not found.is_empty():
				break
		if not found.is_empty():
			break
	assert_false(found.is_empty(), "성격 AI 가 20시드 동안 치유·보호막·도발을 한 번도 고르지 않았다")


func test_data_tags_are_connected() -> void:
	# 데이터에 있는 지원·제어 태그가 하나도 효과와 연결되지 않으면
	# 이 파일은 초록인데 게임은 여전히 맨손과 같다.
	var data: Dictionary = DataLoader.load_json("basic_attacks.json")
	var tags := {}
	for job_id in data["jobs"]:
		for row in data["jobs"][job_id]:
			if String(row.get("cls", "")) in ["support", "control"]:
				tags[String(row["tag"])] = true
	for tag in ["치유", "보호막", "도발"]:
		assert_true(tags.has(tag), "데이터에 태그가 없다: " + tag)
		assert_true(FonsStatus.handles(tag), "효과가 연결되지 않았다: " + tag)
