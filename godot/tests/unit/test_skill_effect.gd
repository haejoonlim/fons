extends GutTest
## 스킬이 전투에서 하는 일 — GDD 09 §5-2 의 식이 그대로 도는지 잠근다.
## 스킬은 스탯이 아니라 **행동 한 번의 피해**를 올린다 (09 §2 원칙 5).


func _damage_skill() -> Dictionary:
	return {"id": 1, "name": "시험참", "effect_kind": "피해", "effect_base": 35.0,
		"cool_base": 6.0, "cost_mana": 32, "rarity": 6}


func test_effect_pct_follows_the_growth_formula() -> void:
	# 효과 = 기본 × (1+0.10×(단계−1)) × (1+0.015×(레벨−1))
	var skill := _damage_skill()
	assert_almost_eq(FonsSkillEffect.effect_pct(skill, 1, 1), 35.0, 0.001, "1단계 1레벨 = 기본")
	assert_almost_eq(FonsSkillEffect.effect_pct(skill, 7, 13), 35.0 * 1.6 * 1.18, 0.001,
		"7단계 13레벨 = 66.08%")


func test_cooldown_shrinks_with_stage_and_becomes_turns() -> void:
	var skill := _damage_skill()
	assert_almost_eq(FonsSkillEffect.cooldown_seconds(skill, 1), 6.0, 0.001)
	assert_almost_eq(FonsSkillEffect.cooldown_seconds(skill, 7), 6.0 * 0.82, 0.001, "단계당 −3%")
	# 4.92초 / 2.5초 = 1.97 → 올림 2턴. 최소 1턴.
	assert_eq(FonsSkillEffect.cooldown_turns(skill, 7), 2)
	assert_eq(FonsSkillEffect.cooldown_turns({"cool_base": 1.0}, 1), 1, "1턴 아래로는 안 내려간다")


func test_combat_kinds_are_damage_and_speed_only() -> void:
	assert_true(FonsSkillEffect.is_combat_skill(_damage_skill()))
	assert_true(FonsSkillEffect.is_combat_skill({"effect_kind": "속도", "cool_base": 10.0}))
	assert_false(FonsSkillEffect.is_combat_skill({"effect_kind": "회복", "cool_base": 20.0}),
		"회복·버프는 상태·버프 레이어가 있어야 뜻이 생긴다")


func test_loadout_filters_kind_rarity_and_count() -> void:
	var catalog: Array = DataLoader.load_json("skills_catalog.json")["skills"]
	var loadout := FonsSkillEffect.loadout(catalog, 3, 6)
	assert_eq(loadout.size(), 3, "요청한 장수만큼")
	for s in loadout:
		assert_gt(float(s["pct"]), 0.0)
		assert_gte(int(s["cd"]), 1)
	assert_eq(FonsSkillEffect.loadout(catalog, 3, 6)[0]["pct"],
		FonsSkillEffect.loadout(catalog, 3, 6)[0]["pct"], "같은 입력이면 같은 장착")


func test_attach_copies_so_party_members_do_not_share_cooldowns() -> void:
	var loadout := FonsSkillEffect.loadout([_damage_skill()], 1, 0)
	var a := {}
	var b := {}
	FonsSkillEffect.attach(a, loadout)
	FonsSkillEffect.attach(b, loadout)
	a["skills"][0]["left"] = 5
	assert_eq(int(b["skills"][0]["left"]), 0, "쿨타임은 유닛마다 따로다")
	assert_eq(int(loadout[0]["left"]), 0, "원본 목록도 안 바뀐다")


func test_skill_raises_the_damage_of_one_action() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var attacker := {"name": "영웅", "side": "ally", "hp": 999, "maxHp": 999, "alive": true,
		"atk": 1000.0, "def": 0.0, "pen": 0.0, "eva": 0.0, "cri": 0.0, "cdmg": 0.0,
		"mag": 0.0, "mdef": 0.0, "magical": false}
	var target := {"name": "더미", "side": "enemy", "hp": 10000, "maxHp": 10000, "alive": true,
		"atk": 0.0, "def": 0.0, "pen": 0.0, "eva": 0.0, "cri": 0.0, "cdmg": 0.0,
		"mag": 0.0, "mdef": 0.0, "magical": false}
	var plain := target.duplicate(true)
	FonsBattle.strike(rng, attacker, plain)
	FonsBattle.strike(rng, attacker, target, 1.0, 50.0)
	var plain_dmg: int = 10000 - int(plain["hp"])
	var skill_dmg: int = 10000 - int(target["hp"])
	assert_eq(skill_dmg, FonsCombat.bankers_round(plain_dmg * 1.5),
		"스킬은 같은 타격의 피해를 1.5배로 만든다 (50%)")
