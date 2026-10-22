class_name FonsFloorRun
extends RefCounted
## 층 한 판 — 06 §3.4 편성 → `combatStep` 턴 루프. 두 모듈(`FonsEncounter`·`FonsBattle`)을 잇는 자리.
##
## 층 스케일은 `FonsScaling` 이 건다
## ----------------------------
## 06 §3.2 G1~G3 + 확정 #52 G4 천정 + 확정 #38 HP 손잡이. 이전 판은 "G4 식이 어디에도 없다"고 적고
## 스케일을 통째로 안 걸었는데, G4 식은 확정 #52 에 `scale = 5.8+(f−100)×0.05` 로 있었다 (2026-10-18 정정).
## 원본 Unity 런타임이 스케일을 안 걷었던 것은 사실이지만, 그건 정본 부재가 아니라 미구현이다.
##
## `build` 는 **매번 새 유닛**을 만든다. 전투가 유닛 Dictionary 를 제자리에서 고치기 때문에
## 편성 결과를 재사용하면 두 번째 판이 반피로 시작한다.

## 한 판 턴 상한 — **설계값이 아니라 안전 가드**다.
##
## 원본 웹은 라운드 상한이 없다 (`stepTurn()` 한 번이 한 턴 · 한쪽이 죽을 때까지).
## 원본의 "30" 은 런 행동력 `GameRules.MaxAp = 30` 이지 턴 수가 아니다 (원본 대조).
## 상한을 30 으로 두면 상층 판이 "이겨야 하는데 턴이 모자란 판"으로 끊긴다 —
## 2026-10-21 실측에서 91~100층 승리가 상한 30 에서 5, 상한 없음에서 5~10 으로 갈렸다.
## 그래서 여기서는 무한 루프(양쪽 피해 0)만 막는 큰 수를 둔다. 이 값이 밸런스에 닿으면 안 된다.
const MAX_TURNS := 500


static func build(monsters: Variant, biomes: Variant, floor: int, contact_index: int = 0,
		hp_knob: float = 1.0) -> Dictionary:
	var party := FonsEncounter.build_party(monsters, biomes, floor, contact_index)
	var biome := FonsEncounter.biome_for_floor(biomes, floor)
	var units := []
	for m in party:
		# 06 §3.2 — 적 스탯 = 기본 × 층 스케일 × 바이옴 계수. 사본에만 건다 (원본 데이터 불변).
		units.append(FonsBattle.unit_from_monster(FonsScaling.scale_monster(m, floor, biome, hp_knob)))
	return {
		"floor": floor,
		"biome_id": String(biome.get("id", "")),
		"party": units,
	}


static func build_gatekeeper(monsters: Variant, biomes: Variant, floor: int,
		hp_ratio: float = 0.0, atk_ratio: float = 0.0) -> Dictionary:
	## 게이트키퍼 층의 **보스 1체** 편성. 일반 조우(3~5종)와 섞지 않는다 — 02 조우 모드 규약.
	## 문지기가 없는 층(계층문지기 경계 포함)은 `party` 가 빈 배열이고 `gatekeeper` 도 빈 문자열이다.
	##
	## `hp_ratio`·`atk_ratio` 는 **제안 측정용**이다 (기본 0 = 정본 식 그대로).
	##   hp_ratio  — 같은 층 일반 조우 HP **합계**의 몇 배로 문지기 HP 를 잡을지
	##   atk_ratio — 일반 조우 **한 마리 평균** 공격력의 몇 배로 문지기 ATK 를 잡을지
	## 배수를 정하는 것은 밸런스 결정이라 여기서 기본값을 바꾸지 않는다.
	var gk := FonsEncounter.gatekeeper_for_floor(monsters, floor)
	if gk.is_empty():
		return {"floor": floor, "biome_id": "", "party": [], "gatekeeper": "", "gatekeeper_id": ""}
	var hp_target := 0.0
	var atk_target := 0.0
	if hp_ratio > 0.0 or atk_ratio > 0.0:
		var normal := normal_encounter_stats(monsters, biomes, floor)
		if hp_ratio > 0.0:
			hp_target = float(normal["hp"]) * hp_ratio
		if atk_ratio > 0.0:
			atk_target = float(normal["avg_atk"]) * atk_ratio
	var scaled := FonsScaling.scale_gatekeeper(gk, floor, hp_target, atk_target)
	return {
		"floor": floor,
		"biome_id": String(FonsEncounter.biome_for_floor(biomes, floor).get("id", "")),
		"party": [FonsBattle.unit_from_monster(scaled)],
		"gatekeeper": String(gk.get("name", "")),
		"gatekeeper_id": String(gk.get("id", "")),
	}


static func normal_encounter_stats(monsters: Variant, biomes: Variant, floor: int) -> Dictionary:
	## 같은 층 **일반 조우**의 HP 합계·공격력 합계·한 마리 평균. 문지기 배수를 재는 기준이다.
	## 적 스탯이 아니라 **스케일을 건 뒤**의 값이다 — 플레이어가 실제로 마주치는 숫자.
	var biome := FonsEncounter.biome_for_floor(biomes, floor)
	var hp := 0.0
	var atk := 0.0
	var n := 0
	for m in FonsEncounter.build_party(monsters, biomes, floor, 0):
		var stats: Dictionary = FonsScaling.scale_monster(m, floor, biome).get("stats", {})
		hp += float(stats.get("hp", 0))
		atk += maxf(float(stats.get("atk", 0)), float(stats.get("mag", 0)))
		n += 1
	return {"hp": hp, "atk": atk, "avg_atk": atk / float(maxi(1, n)), "count": n}


static func simulate_gatekeeper(rng, monsters: Variant, biomes: Variant, floor: int,
		heroes: Array, max_turns: int = MAX_TURNS) -> Dictionary:
	## 문지기 한 판. `simulate` 와 같은 반환 모양을 유지해 측정 도구가 같이 쓸 수 있다.
	var built := build_gatekeeper(monsters, biomes, floor)
	var enemies: Array = built["party"]
	var out := run(rng, heroes, enemies, floor, max_turns)
	out["party_size"] = enemies.size()
	out["enemies"] = enemies
	out["biome_id"] = built["biome_id"]
	out["gatekeeper"] = built["gatekeeper"]
	out["gatekeeper_id"] = built["gatekeeper_id"]
	return out


static func _alive(units: Array) -> int:
	var n := 0
	for u in units:
		if bool(u.get("alive", false)):
			n += 1
	return n


static func run(rng, heroes: Array, enemies: Array, floor: int, max_turns: int = MAX_TURNS) -> Dictionary:
	## 유닛은 제자리에서 바뀐다. 반환: turns · log(평탄한 문자열 배열) · winner(ally/enemy/draw) · gauge.
	var gauge := FonsBattle.make_gauge(floor)
	var log_lines: Array = []
	var turns := 0
	for turn in range(1, maxi(1, max_turns) + 1):
		var step := FonsBattle.combat_step(rng, heroes, enemies, gauge, {})
		log_lines.append_array(step["log"])
		turns = turn
		if _alive(enemies) == 0 or _alive(heroes) == 0:
			break
	var winner := "draw"
	if _alive(enemies) == 0 and _alive(heroes) > 0:
		winner = "ally"
	elif _alive(heroes) == 0:
		winner = "enemy"
	return {"turns": turns, "log": log_lines, "winner": winner, "gauge": gauge}


static func simulate(rng, monsters: Variant, biomes: Variant, floor: int, contact_index: int,
		heroes: Array, max_turns: int = MAX_TURNS, hp_knob: float = 1.0) -> Dictionary:
	## 편성부터 한 판까지 — 판마다 새 유닛을 만든다.
	## `hp_knob` 은 적 HP 에만 걸리는 측정 손잡이다 (정본 곡선은 그대로, 기본 1.0).
	var built := build(monsters, biomes, floor, contact_index, hp_knob)
	var enemies: Array = built["party"]
	var out := run(rng, heroes, enemies, floor, max_turns)
	out["party_size"] = enemies.size()
	out["enemies"] = enemies
	out["biome_id"] = built["biome_id"]
	return out
