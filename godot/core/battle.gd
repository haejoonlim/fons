class_name FonsBattle
extends RefCounted
## 전투 턴 루프 — 원본 웹 `combat.ts combatStep`(→ Unity `BattleSystem`) 포팅.
##
## 왜 이 순서를 그대로 옮기나
## -------------------------
## 턴 루프는 "누가 먼저 때리는가"가 곧 밸런스다. 순서를 바꾸면 데미지 식이 맞아도 전투가 다르게 굴러간다.
## 그래서 아래 여섯 가지를 원본에서 **한 줄도 바꾸지 않는다**:
##   ① 턴 시작에 전술게이지 +5 (4층 이상 활성)  ② 아군은 목록 순서대로
##   ③ 대상 = 지정 대상(살아 있으면) 아니면 최저 HP 적  ④ 처치 시 게이지 +10
##   ⑤ 적군은 목록 순서대로, 최저 HP 아군을 때린다  ⑥ 대상이 없으면 남은 유닛은 때리지 않는다
##
## `combat_step` 은 유닛 Dictionary 를 **제자리에서 고친다**(hp·alive). 원본도 배열 원소를 고친다 —
## 복사본을 돌려주면 호출부가 둘 중 하나를 잊고 "죽었는데 계속 때리는" 상태가 된다.

const GAUGE_MAX := 100
const GAUGE_START := 50
const GAUGE_PER_KILL := 10
const GAUGE_PER_TURN := 5        ## 데모 환산 — 실시간 초+2 를 1턴 2.5초로 본 값 (원본 주석 그대로)
const TACTICAL_FROM_FLOOR := 4
const MOVE_COST := 20
const FOCUS_COST := 30
const EMERGENCY_COST := 40

const MAGICAL_AI := ["magic"]    ## monsters.json aiType — magic 만 마법 공격


static func make_gauge(floor: int) -> Dictionary:
	return {"enabled": floor >= TACTICAL_FROM_FLOOR, "value": GAUGE_START}


static func gauge_kill(gauge: Dictionary) -> void:
	gauge["value"] = mini(GAUGE_MAX, int(gauge.get("value", 0)) + GAUGE_PER_KILL)


static func gauge_spend(gauge: Dictionary, cost: int) -> bool:
	if not bool(gauge.get("enabled", false)) or int(gauge.get("value", 0)) < cost:
		return false
	gauge["value"] = int(gauge["value"]) - cost
	return true


static func unit_from_monster(monster: Dictionary, side: String = "enemy") -> Dictionary:
	# 몬스터 정본 스탯을 전투 유닛 모양으로 옮긴다. 층 스케일은 여기서 안 건다 —
	# 스케일식은 06 §3.2 에 1~100층만 있고, 없는 구간의 수치를 여기서 만들지 않는다.
	var s: Dictionary = monster.get("stats", {})
	var hp := int(s.get("hp", 0))
	return {
		"name": String(monster.get("name", "?")),
		"id": String(monster.get("id", "")),
		"side": side,
		"hp": hp,
		"maxHp": hp,
		"alive": hp > 0,
		"atk": float(s.get("atk", 0.0)),
		"def": float(s.get("def", 0.0)),
		"pen": 0.0,
		"eva": float(s.get("eva", 0.0)),
		"cri": float(s.get("cri", 0.0)),
		"cdmg": float(s.get("cdmg", 0.0)),
		"mag": float(s.get("mag", 0.0)),
		"mdef": float(s.get("mdef", 0.0)),
		"magical": String(monster.get("aiType", "")) in MAGICAL_AI,
	}


static func unit_from_hero(stats: Dictionary, display_name: String, magical: bool = false) -> Dictionary:
	## `FonsHeroStats.field_stats` 결과를 전투 유닛으로 — 영웅 스탯 경로와 이 판을 잇는 자리.
	## EVA 는 0 이다: 38차에 영웅 축에서 회피율이 빠졌다(민첩 = MS). 적 `stats.eva` 는 남아 있다.
	## `magical` 은 호출자가 정한다 — 직업 축(`races.json meta.jobWeightContract.magicAxis`).
	var hp := int(roundf(float(stats.get("HP", 0.0))))
	return {
		"name": display_name,
		"side": "ally",
		"hp": hp,
		"maxHp": hp,
		"alive": hp > 0,
		"atk": float(stats.get("ATK", 0.0)),
		"def": float(stats.get("DEF", 0.0)),
		"pen": float(stats.get("PEN", 0.0)),
		"eva": 0.0,
		"cri": float(stats.get("CRI", 0.0)),
		"cdmg": float(stats.get("CDMG", 0.0)),
		"mag": float(stats.get("MAG", 0.0)),
		"mdef": float(stats.get("MDEF", 0.0)),
		"magical": magical,
	}


static func _weakest(units: Array) -> Dictionary:
	# 원본은 `filter(alive).sort(hp)[0]` — 안정 정렬이라 **동률이면 목록 앞쪽**이 뽑힌다.
	# GDScript `sort_custom` 은 안정성을 보장하지 않으므로 직접 훑어 그 규칙을 유지한다.
	var best: Dictionary = {}
	for u in units:
		if not bool(u.get("alive", false)):
			continue
		if best.is_empty() or int(u["hp"]) < int(best["hp"]):
			best = u
	return best


static func _take_skill(attacker: Dictionary) -> float:
	## 이번 행동에 쓸 스킬의 피해 배율(%). 준비된 것이 없으면 0.
	## 쿨타임은 **유닛 상태**다 — 목록 사본은 `FonsSkillEffect.attach` 가 넣는다.
	var skills: Array = attacker.get("skills", [])
	if skills.is_empty():
		return 0.0
	var best: Dictionary = {}
	for s in skills:
		if int(s.get("left", 0)) > 0:
			continue
		if best.is_empty() or float(s["pct"]) > float(best["pct"]):
			best = s
	if best.is_empty():
		return 0.0
	best["left"] = int(best.get("cd", 1))
	return float(best["pct"])


static func _tick_cooldowns(attacker: Dictionary) -> void:
	for s in attacker.get("skills", []):
		s["left"] = maxi(0, int(s.get("left", 0)) - 1)


static func _consume_skill(hero: Dictionary, skill_id: String) -> float:
	## 고른 기술의 쿨을 걸고 이번 행동의 피해 배율을 돌려준다. 기술이 없으면 0 (맨손).
	if skill_id.is_empty():
		return 0.0
	for s in hero.get("skills", []):
		if String(s.get("id", "")) != skill_id:
			continue
		if int(s.get("left", 0)) > 0:
			return 0.0
		s["left"] = int(s.get("cd", 1))
		return float(s.get("pct", 0.0))
	return 0.0


static func _attack_tag_of(hero: Dictionary) -> String:
	## 맨손 공격이 남길 태그 (행동 이름 → 태그). 모르는 이름이면 근접타격.
	var tags := FonsActionTags.tags_for(FonsActionTags.attack_tag(hero))
	return String(tags[0]) if not tags.is_empty() else "근접타격"


static func _move_candidates(hero: Dictionary) -> Array:
	## **무엇으로 칠까** — 맨손 + 지금 쓸 수 있는 기술. 각인된 기술이 곧 커맨드다 (09 §4-2 장치 1).
	## 기술마다 태그가 다르므로, 성격이 다르면 같은 직업이라도 다른 기술을 골라 쓴다.
	var magical := bool(hero.get("magical", false))
	var out: Array = [{
		"action": FonsActionTags.attack_tag(hero), "tag": _attack_tag_of(hero), "domain": "공격",
		"stat": "MAG" if magical else "ATK",
		"stat_value": float(hero.get("mag", 0.0)) if magical else float(hero.get("atk", 0.0)),
	}]
	for s in hero.get("skills", []):
		if int(s.get("left", 0)) > 0:
			continue
		var tags: Array = s.get("tags", [])
		var tag := String(tags[0]) if not tags.is_empty() else _attack_tag_of(hero)
		out.append({
			"action": String(s.get("name", "기술")), "tag": tag,
			"domain": String(s.get("domain", "공격")),
			"skill_id": String(s.get("id", "")),
			"stat": "MAG" if magical else "ATK",
			"stat_value": float(hero.get("mag", 0.0)) if magical else float(hero.get("atk", 0.0)),
			# 연습 열기 — 같은 단계라도 요즘 쓴 기술을 먼저 검토한다 (skill_book 가안).
			"bias": FonsSkillBook.heat_bias(float(s.get("heat", 0.0))),
		})
	return out


static func _target_candidates(enemies: Array, move: Dictionary) -> Array:
	## **누구를 칠까** — 같은 기술이라도 약한 놈을 마무리하는 사람과 센 놈을 먼저 치는 사람이 있다.
	var strongest := 0.0
	for enemy in enemies:
		if bool(enemy.get("alive", false)):
			strongest = maxf(strongest, float(enemy.get("atk", 0.0)))
	var out: Array = []
	for enemy in enemies:
		if not bool(enemy.get("alive", false)):
			continue
		var ratio := float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("maxHp", 1)))
		var cand: Dictionary = move.duplicate()
		cand["target"] = enemy
		cand["low_hp"] = ratio <= 0.30
		cand["high_threat"] = strongest > 0.0 and float(enemy.get("atk", 0.0)) >= strongest * 0.99
		out.append(cand)
	return out


static func _context(hero: Dictionary, party: Array, enemies: Array, party_avg: Dictionary) -> Dictionary:
	## 09 §4-1 C항에 들어가는 문맥 — 지금 계산할 수 있는 것만.
	var hp_max := maxf(1.0, float(hero.get("maxHp", 1)))
	var alive := 0
	var lowest := 1.0
	var threat := 0.0
	for enemy in enemies:
		if not bool(enemy.get("alive", false)):
			continue
		alive += 1
		lowest = minf(lowest, float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("maxHp", 1))))
		threat = maxf(threat, float(enemy.get("atk", 0.0)))
	var ally_hurt := false
	for mate in party:
		if mate == hero or not bool(mate.get("alive", false)):
			continue
		if float(mate.get("hp", 0)) / maxf(1.0, float(mate.get("maxHp", 1))) < 0.5:
			ally_hurt = true
	return {
		"hp_ratio": float(hero.get("hp", 0)) / hp_max,
		"party_avg": party_avg,
		"enemy_count": alive,
		"enemy_low": lowest <= 0.30,
		"ally_hurt": ally_hurt,
		"boss": float(hero.get("maxHp", 0)) > 0.0 and threat > 0.0 and alive == 1 and threat > 40.0,
	}


static func strike(rng, attacker: Dictionary, defender: Dictionary,
		position_multiplier: float = 1.0, skill_pct: float = 0.0) -> Dictionary:
	var eva := float(defender.get("eva", 0.0))
	var cri := float(attacker.get("cri", 0.0))
	var cdmg := float(attacker.get("cdmg", 0.0))
	# 원본 RNG 소비 순서 = 회피 → 치명타. 능력치가 0 이면 원본도 난수를 **안 굴린다**
	# (`tryEvade`/`tryCrit` 조기 반환) — 여기서도 같은 순서를 유지해야 결정론이 같다.
	var roll_evade: float = rng.randf() if eva > 0.0 else 0.0
	var roll_crit: float = rng.randf() if cri > 0.0 else 0.0

	var out: Dictionary
	if bool(attacker.get("magical", false)):
		out = FonsCombat.resolve_magical(float(attacker.get("mag", 0.0)), float(defender.get("mdef", 0.0)),
			eva, cri, cdmg, position_multiplier, 0.0, roll_evade, roll_crit)
	else:
		out = FonsCombat.resolve_physical(float(attacker.get("atk", 0.0)), float(defender.get("def", 0.0)),
			float(attacker.get("pen", 0.0)), eva, cri, cdmg, position_multiplier, roll_evade, roll_crit)

	var name_a := String(attacker.get("name", "?"))
	var name_d := String(defender.get("name", "?"))
	if bool(out["evaded"]):
		return {"text": "%s → %s 빗나감" % [name_a, name_d], "killed": false}

	var dmg := int(out["damage"])
	if skill_pct > 0.0:
		# 스킬은 스탯이 아니라 **행동 한 번의 피해**를 올린다 (GDD 09 §5-2 성장식).
		dmg = FonsCombat.bankers_round(float(dmg) * (1.0 + skill_pct / 100.0))
	defender["hp"] = maxi(0, int(defender["hp"]) - dmg)
	var killed := int(defender["hp"]) <= 0
	defender["alive"] = not killed
	var text := "%s → %s %d" % [name_a, name_d, dmg]
	if skill_pct > 0.0:
		text += " 스킬"
	if bool(out["critical"]):
		text += " 치명타"
	text += " 처치" if killed else " (잔여 %d)" % int(defender["hp"])
	return {"text": text, "killed": killed}


static func combat_step(rng, party: Array, enemies: Array, gauge: Dictionary,
		focus_target: Dictionary = {}, position_mul: Dictionary = {}) -> Dictionary:
	## 한 턴 — 로그 배열과 이번 턴에 죽은 유닛을 돌려준다. 유닛은 제자리에서 바뀐다.
	## `position_mul` 은 유닛 name → 이번 턴 위치보정 (없으면 1.0).
## `rng` 는 `randf()` 하나만 있으면 된다 — 보통 `RandomNumberGenerator`, 테스트는 고정 수열 스텁을 넣는다
## (원본과 같은 난수 수열로 돌려 로그를 대조하려면 스텁이 필요하다).
	var log_lines: Array = []
	var killed: Array = []
	if bool(gauge.get("enabled", false)):
		gauge["value"] = mini(GAUGE_MAX, int(gauge.get("value", 0)) + GAUGE_PER_TURN)
	var party_avg := {}
	var stat_n := 0
	for unit in party:
		party_avg["ATK"] = float(party_avg.get("ATK", 0.0)) + float(unit.get("atk", 0.0))
		party_avg["MAG"] = float(party_avg.get("MAG", 0.0)) + float(unit.get("mag", 0.0))
		stat_n += 1
	for key in ["ATK", "MAG"]:
		party_avg[key] = float(party_avg.get(key, 0.0)) / float(maxi(1, stat_n))

	if _weakest(enemies).is_empty() or _weakest(party).is_empty():
		return {"log": log_lines, "killed": killed}

	for hero in party:
		if not bool(hero.get("alive", false)):
			continue
		var target: Dictionary = focus_target if not focus_target.is_empty() and bool(focus_target.get("alive", false)) \
			else _weakest(enemies)
		if target.is_empty():
			break
		_tick_cooldowns(hero)
		var skill_pct := 0.0
		if FonsBrain.attached(hero):
			# 성격이 붙은 유닛은 **누구를 칠지**를 스스로 고른다 (09 §4-2).
			var brain: FonsBrain = hero["brain"]
			brain.sync_unit(hero)
			var ctx := _context(hero, party, enemies, party_avg)
			# ① 무엇으로 칠까 (맨손 vs 보유 기술) ② 누구를 칠까 — 두 번 판단한다.
			var move := brain.decide(_move_candidates(hero), ctx)
			if not move.is_empty():
				var aimed := brain.decide(_target_candidates(enemies, move), ctx)
				if not aimed.is_empty():
					target = aimed["target"]
				skill_pct = _consume_skill(hero, String(move.get("skill_id", "")))
				var seen: Dictionary = brain.commit({"tag": String(move["tag"]),
					"skill_id": String(move.get("skill_id", ""))})
				brain.mirror(hero)
				for born in seen["born"]:
					log_lines.append("%s → 새 기술 「%s」" % [String(hero.get("name", "?")), String(born)])
			else:
				skill_pct = _take_skill(hero)
		else:
			FonsActionTags.record(hero, FonsActionTags.attack_tag(hero))
			skill_pct = _take_skill(hero)
		var res := strike(rng, hero, target, float(position_mul.get(String(target.get("name", "")), 1.0)), skill_pct)
		log_lines.append(res["text"])
		if bool(res["killed"]):
			if FonsBrain.attached(hero):
				hero["brain"].commit({"tag": "약점타격"})
				hero["brain"].mirror(hero)
			else:
				FonsActionTags.record(hero, "처치")
			killed.append(target)
			gauge_kill(gauge)

	for enemy in enemies:
		if not bool(enemy.get("alive", false)):
			continue
		var victim := _weakest(party)
		if victim.is_empty():
			break
		var res2 := strike(rng, enemy, victim, 1.0)
		log_lines.append(res2["text"])
		if bool(res2["killed"]):
			killed.append(victim)

	return {"log": log_lines, "killed": killed}
