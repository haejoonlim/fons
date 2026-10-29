extends GutTest
## 전투 턴 루프 — 정본은 웹 `combat.ts combatStep` · 원본 `BattleSystem` 순서다.
##
##   턴 시작: 전술게이지 활성(4층 이상)이면 +5
##   아군: 살아 있는 순서대로 → 지정 대상(없거나 죽었으면 **최저 HP 적**)
##   적군: 목록 순서대로 → **최저 HP 아군**
##   처치: 게이지 +10 · 처치 목록에 적립
##
## RNG 는 회피 → 치명타 순서로만 소비한다. eva·cri 가 0 이면 아예 굴리지 않으므로
## (원본 `tryEvade` 조기 반환) 아래 테스트는 시드 없이도 결정론적이다.

## 원본 난수 수열을 그대로 넣기 위한 스텁 — `randf()` 하나만 있으면 된다.
class FixedRng:
	var seq: Array = [0.37, 0.81, 0.05, 0.62, 0.94, 0.13, 0.48, 0.71, 0.29, 0.56]
	var i := 0

	func randf() -> float:
		var v: float = seq[i % seq.size()]
		i += 1
		return v


func _unit(name: String, side: String, hp: int, atk: float = 100.0, deff: float = 0.0,
		extra: Dictionary = {}) -> Dictionary:
	var u := {
		"name": name, "side": side, "hp": hp, "maxHp": hp, "alive": hp > 0,
		"atk": atk, "def": deff, "pen": 0.0, "eva": 0.0, "cri": 0.0, "cdmg": 0.0,
		"mag": 0.0, "mdef": 0.0, "magical": false,
	}
	for k in extra:
		u[k] = extra[k]
	return u


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261018
	return rng


func test_skill_heat_biases_the_move_candidates() -> void:
	# 같은 단계·같은 피해라도 요즘 쓴 기술을 먼저 검토한다 — 연습 열기가 선택에 닿는지 본다.
	var hero := _unit("영웅", "ally", 500, 100.0, 0.0, {"skills": [
		{"id": "hot", "name": "뜨거운", "tags": ["근접타격"], "domain": "공격", "pct": 10.0, "cd": 2, "left": 0, "heat": 8.0},
		{"id": "cold", "name": "식은", "tags": ["근접타격"], "domain": "공격", "pct": 10.0, "cd": 2, "left": 0, "heat": 0.0},
	]})
	var by_id := {}
	for row in FonsBattle._move_candidates(hero):
		if row.has("skill_id"):
			by_id[String(row["skill_id"])] = float(row["bias"])
	assert_gt(float(by_id["hot"]), 1.0, "뜨거운 기술은 +선호")
	assert_almost_eq(float(by_id["cold"]), 1.0, 0.001, "식은 기술은 가중 없음")


func test_gauge_is_disabled_below_floor_four() -> void:
	assert_false(FonsBattle.make_gauge(3)["enabled"], "3층 — 전술게이지 없음")
	assert_true(FonsBattle.make_gauge(4)["enabled"], "4층부터 활성")
	assert_eq(FonsBattle.make_gauge(10)["value"], FonsBattle.GAUGE_START)


func test_gauge_accrues_per_turn_and_caps() -> void:
	var gauge := FonsBattle.make_gauge(10)
	var party := [_unit("영웅", "ally", 500)]
	var enemies := [_unit("벽", "enemy", 99999, 0.0)]
	for i in range(0, 3):
		FonsBattle.combat_step(_rng(), party, enemies, gauge, {})
	assert_eq(gauge["value"], FonsBattle.GAUGE_START + 3 * FonsBattle.GAUGE_PER_TURN)
	gauge["value"] = 99
	FonsBattle.combat_step(_rng(), party, enemies, gauge, {})
	assert_eq(gauge["value"], FonsBattle.GAUGE_MAX, "상한 100")


func test_gauge_spend_requires_enabled_and_enough_value() -> void:
	var disabled := FonsBattle.make_gauge(1)
	assert_false(FonsBattle.gauge_spend(disabled, FonsBattle.FOCUS_COST), "비활성층은 못 쓴다")
	var gauge := FonsBattle.make_gauge(10)
	assert_true(FonsBattle.gauge_spend(gauge, FonsBattle.FOCUS_COST), "50 에서 30 소비")
	assert_eq(gauge["value"], 20)
	assert_true(FonsBattle.gauge_spend(gauge, FonsBattle.MOVE_COST), "남은 20 으로 이동 가능")
	assert_eq(gauge["value"], 0)
	assert_false(FonsBattle.gauge_spend(gauge, 1), "0 < 1 은 실패")
	assert_eq(gauge["value"], 0, "실패한 소비는 값을 건드리지 않는다")


func test_lethal_hit_kills_target_and_pays_gauge() -> void:
	var gauge := FonsBattle.make_gauge(10)
	var party := [_unit("영웅", "ally", 500, 100.0)]
	var enemies := [_unit("슬라임", "enemy", 100)]
	var out := FonsBattle.combat_step(_rng(), party, enemies, gauge, {})
	assert_eq(enemies[0]["hp"], 0)
	assert_false(enemies[0]["alive"])
	assert_eq(out["killed"].size(), 1)
	assert_eq(out["killed"][0]["name"], "슬라임")
	assert_eq(gauge["value"], FonsBattle.GAUGE_START + FonsBattle.GAUGE_PER_TURN + FonsBattle.GAUGE_PER_KILL)
	assert_string_contains(out["log"][0], "처치")
	assert_string_contains(out["log"][0], "→")


func test_without_focus_the_weakest_enemy_is_targeted() -> void:
	var party := [_unit("영웅", "ally", 500, 10.0)]
	var weak := _unit("약한", "enemy", 50)
	var strong := _unit("강한", "enemy", 900)
	var out := FonsBattle.combat_step(_rng(), party, [strong, weak], FonsBattle.make_gauge(1), {})
	assert_string_contains(out["log"][0], "약한", "최저 HP 적부터 맞는다")
	assert_lt(weak["hp"], 50)


func test_focus_target_is_honoured_while_alive() -> void:
	var party := [_unit("영웅", "ally", 500, 10.0)]
	var weak := _unit("약한", "enemy", 50)
	var boss := _unit("보스", "enemy", 900)
	var out := FonsBattle.combat_step(_rng(), party, [weak, boss], FonsBattle.make_gauge(1), boss)
	assert_string_contains(out["log"][0], "보스")
	assert_eq(weak["hp"], 50, "지정 대상이 살아 있으면 최저 HP 적은 안 맞는다")


func test_focus_falls_back_when_dead() -> void:
	var party := [_unit("영웅", "ally", 500, 10.0)]
	var weak := _unit("약한", "enemy", 50)
	var dead_focus := _unit("시체", "enemy", 0)
	var out := FonsBattle.combat_step(_rng(), party, [weak, dead_focus], FonsBattle.make_gauge(1), dead_focus)
	assert_string_contains(out["log"][0], "약한", "죽은 지정 대상은 무시하고 최저 HP 적")


func test_enemy_phase_hits_weakest_ally() -> void:
	var healthy := _unit("튼튼", "ally", 500, 1.0)
	var hurt := _unit("부상", "ally", 300, 1.0)
	var enemy := _unit("고블린", "enemy", 9999, 50.0)
	var out := FonsBattle.combat_step(_rng(), [healthy, hurt], [enemy], FonsBattle.make_gauge(1), {})
	assert_eq(healthy["hp"], 500, "튼튼한 쪽은 안 맞는다")
	assert_lt(hurt["hp"], 300)
	assert_eq(out["log"].size(), 3, "아군 2 + 적군 1")


func test_dead_enemies_do_not_act() -> void:
	var party := [_unit("영웅", "ally", 500, 200.0)]
	var enemy := _unit("약체", "enemy", 100, 50.0)
	var out := FonsBattle.combat_step(_rng(), party, [enemy], FonsBattle.make_gauge(1), {})
	assert_eq(out["log"].size(), 1, "죽은 적은 반격하지 않는다")
	assert_eq(party[0]["hp"], 500)


func test_second_ally_does_not_act_after_last_enemy_dies() -> void:
	var party := [_unit("영웅A", "ally", 500, 200.0), _unit("영웅B", "ally", 500, 200.0)]
	var enemy := _unit("약체", "enemy", 100)
	var out := FonsBattle.combat_step(_rng(), party, [enemy], FonsBattle.make_gauge(1), {})
	assert_eq(out["log"].size(), 1, "대상이 없으면 남은 아군은 때리지 않는다")


func test_evade_consumes_the_roll_before_crit() -> void:
	var party := [_unit("영웅", "ally", 500, 100.0)]
	var dodger := _unit("회피", "enemy", 100, 0.0, 0.0, {"eva": 100.0})
	var out := FonsBattle.combat_step(_rng(), party, [dodger], FonsBattle.make_gauge(1), {})
	assert_string_contains(out["log"][0], "빗나감")
	assert_eq(dodger["hp"], 100)
	assert_eq(out["killed"].size(), 0)


func test_crit_shows_in_log_and_damage() -> void:
	var party := [_unit("영웅", "ally", 500, 100.0, 0.0, {"cri": 100.0, "cdmg": 100.0})]
	var enemy := _unit("더미", "enemy", 1000)
	var out := FonsBattle.combat_step(_rng(), party, [enemy], FonsBattle.make_gauge(1), {})
	assert_string_contains(out["log"][0], "치명타")
	assert_eq(enemy["hp"], 1000 - 200, "100 × (1 − 0) × 2.0")


func test_magic_damage_is_reduced_by_mdef() -> void:
	## 마법 공격은 `mag` vs **mdef** 로 계산한다. mdef 가 0 이면 감소 없이 그대로 들어간다 —
	## 상층(101~130)은 마법형 적이 다수라 이 축이 0 이면 판이 성립하지 않는다 (2026-10-21 실측).
	var caster := _unit("사제", "enemy", 999, 0.0)
	caster["magical"] = true
	caster["mag"] = 800.0
	var target := _unit("영웅", "ally", 5000)
	target["mdef"] = 600.0
	FonsBattle.strike(_rng(), caster, target)
	assert_eq(5000 - int(target["hp"]), 200, "800 × (1 − 600/800)")


func test_side_with_no_units_returns_empty_log_but_still_accrues() -> void:
	var gauge := FonsBattle.make_gauge(10)
	var out := FonsBattle.combat_step(_rng(), [_unit("영웅", "ally", 500)], [], gauge, {})
	assert_eq(out["log"], [])
	assert_eq(gauge["value"], FonsBattle.GAUGE_START + FonsBattle.GAUGE_PER_TURN,
		"턴 게이지는 붙는다 — 원본도 적립 뒤에 빈 편성을 확인한다")


func test_parity_with_web_combat_step() -> void:
	# 이 3턴 로그는 원본 `fons-web-ver/app/src/combat.ts combatStep` 을 node 로 **직접 돌려** 받은 값이다
	# (node v22 --experimental-strip-types, 난수는 위 FixedRng 수열). 포팅이 한 글자라도 어긋나면 여기서 깨진다.
	var rng := FixedRng.new()
	var party := [_unit("영웅A", "ally", 500, 120.0), _unit("영웅B", "ally", 300, 90.0, 0.0, {"cri": 100.0, "cdmg": 100.0})]
	var boss := _unit("보스", "enemy", 900, 80.0, 40.0, {"eva": 25.0})
	boss["magical"] = true
	boss["mag"] = 150.0
	boss["mdef"] = 30.0
	var enemies := [_unit("약체", "enemy", 250, 60.0), boss]
	var gauge := {"enabled": true, "value": 50}

	var t1 := FonsBattle.combat_step(rng, party, enemies, gauge, {})
	assert_eq(t1["log"], [
		"영웅A → 약체 120 (잔여 130)",
		"영웅B → 약체 180 치명타 처치",
		"보스 → 영웅B 150 (잔여 150)",
	])
	assert_eq(gauge["value"], 65)

	var t2 := FonsBattle.combat_step(rng, party, enemies, gauge, {})
	assert_eq(t2["log"], [
		"영웅A → 보스 100 (잔여 800)",
		"영웅B → 보스 빗나감",
		"보스 → 영웅B 150 처치",
	])
	assert_eq(gauge["value"], 70)

	var t3 := FonsBattle.combat_step(rng, party, enemies, gauge, {})
	assert_eq(t3["log"], [
		"영웅A → 보스 100 (잔여 700)",
		"보스 → 영웅A 150 (잔여 350)",
	])
	assert_eq(gauge["value"], 75)
	assert_eq([party[0]["hp"], party[1]["hp"], enemies[0]["hp"], enemies[1]["hp"]], [350, 0, 0, 700])


func test_unit_from_monster_maps_stats() -> void:
	var monster := {
		"name": "성광심판관", "aiType": "magic", "stats": {
			"hp": 23500, "atk": 380, "def": 46, "mdef": 58, "mag": 320,
			"eva": 12, "cri": 6, "cdmg": 160,
		},
	}
	var unit := FonsBattle.unit_from_monster(monster)
	assert_eq(unit["name"], "성광심판관")
	assert_eq(unit["side"], "enemy")
	assert_eq(unit["hp"], 23500)
	assert_eq(unit["maxHp"], 23500)
	assert_eq(unit["atk"], 380.0)
	assert_true(unit["magical"], "aiType magic 은 마법 공격")
	assert_false(FonsBattle.unit_from_monster({"name": "늑대", "aiType": "melee", "stats": {"hp": 10, "atk": 1, "def": 0}})["magical"])


func test_unit_from_monster_reads_pen_from_data() -> void:
	# 데이터 `stats.pen` 은 퍼센트다 — 전투 유닛까지 그대로 실려야 한다.
	# 예전에는 0.0 고정이라 monsters.json 12종의 관통이 전투에 안 닿았다.
	var bear := {"name": "곰", "aiType": "melee", "stats": {"hp": 100, "atk": 30, "def": 10, "pen": 10}}
	assert_eq(float(FonsBattle.unit_from_monster(bear)["pen"]), 10.0, "관통 10%")
	var plain := {"name": "늑대", "aiType": "melee", "stats": {"hp": 10, "atk": 1, "def": 0}}
	assert_eq(float(FonsBattle.unit_from_monster(plain)["pen"]), 0.0, "관통이 없으면 0")
	# 관통은 실제 피해를 키운다 — DEF 820 한 대 62 → 70 (2026-10-29 실측 비율).
	assert_gt(FonsCombat.compute(1000.0, 820.0, 0.1), FonsCombat.compute(1000.0, 820.0, 0.0))
