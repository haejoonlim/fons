class_name FonsSkillEffect
extends RefCounted
## 스킬이 **전투에서 하는 일** — 행동 한 번의 피해 배율과 쿨타임.
##
## 정본은 GDD 09 §5-2 다. 이 파일은 새 수치를 만들지 않고 그 표의 식만 옮긴다.
##   효과_기본(전투 %)   D 5 · C 8 · B 12 · A 18 · S 25 · L 35   (`skills_catalog.json effect_base`)
##   성장식              효과 = 기본 × (1 + 0.10×(단계−1)) × (1 + 0.015×(레벨−1))
##   쿨_기본(초)         종류별 6(피해) · 10(속도) · 15(방어·지속) · 20(회복·효과)
##   쿨 = 기본 × (1 − 0.03×(단계−1))
##   마나 = (8 + 4r) × (1 + 0.05(r−1)) — 데이터 `cost_mana` 가 이미 그 값이다
##
## 왜 배율인가: 스킬은 **스탯을 올리지 않는다**(09 §2 원칙 5). 행동 한 번의 피해량을 올린다.
## 그래서 필드스탯·CP 는 그대로이고, 전투 로그의 한 줄만 커진다.
##
## 범위: 여기서는 **피해 계열**(`effect_kind` 가 피해·속도)만 전투에 건다. 방어·회복·효과는
## 전투 상태이상·버프 레이어가 있어야 뜻이 생기므로 미룬다 (GDD 09 §5-2 의 쿨·마나 규격은 같다).

## 1턴 = 2.5초. 원본 데모 환산 — `battle.gd` 의 GAUGE_PER_TURN 주석과 같은 근거다.
const TURN_SECONDS := 2.5
const STAGE_STEP := 0.10
const LEVEL_STEP := 0.015
const COOL_STEP := 0.03
const MAX_STAGE := 7
const MAX_LEVEL := 13

## 전투에 바로 걸리는 종류. 나머지는 상태·버프 레이어가 필요하다.
const COMBAT_KINDS := ["피해", "속도"]


static func is_combat_skill(skill: Dictionary) -> bool:
	if not String(skill.get("effect_kind", "")) in COMBAT_KINDS:
		return false
	return float(skill.get("cool_base", 0.0)) > 0.0


static func effect_pct(skill: Dictionary, stage: int, level: int) -> float:
	## 행동 한 번에 ATK(또는 MAG)의 몇 % 를 **더** 때리는가.
	var base := float(skill.get("effect_base", 0.0))
	var s := clampi(stage, 1, MAX_STAGE)
	var l := clampi(level, 1, MAX_LEVEL)
	return base * (1.0 + STAGE_STEP * float(s - 1)) * (1.0 + LEVEL_STEP * float(l - 1))


static func cooldown_seconds(skill: Dictionary, stage: int) -> float:
	var base := float(skill.get("cool_base", 0.0))
	var s := clampi(stage, 1, MAX_STAGE)
	return maxf(0.0, base * (1.0 - COOL_STEP * float(s - 1)))


static func cooldown_turns(skill: Dictionary, stage: int) -> int:
	## 초를 턴으로 올림 변환한다. 최소 1턴 — 같은 턴에 두 번 쓰지 않는다.
	return maxi(1, int(ceil(cooldown_seconds(skill, stage) / TURN_SECONDS)))


static func mana_cost(skill: Dictionary, level: int) -> float:
	var base := float(skill.get("cost_mana", 0.0))
	return base * (1.0 + LEVEL_STEP * float(clampi(level, 1, MAX_LEVEL) - 1))


static func loadout(skills: Array, count: int, rarity: int = 0, stage: int = 0,
		level: int = MAX_LEVEL) -> Array:
	## 측정·배선용 장착 목록. `rarity` 0 이면 카탈로그 순서 그대로 집는다.
	## `stage` 0 이면 그 스킬의 단계 상한(= 레어도+1 — D 2단계 ~ L 7단계)을 쓴다.
	var out: Array = []
	for skill in skills:
		if not is_combat_skill(skill):
			continue
		if rarity > 0 and int(skill.get("rarity", 0)) != rarity:
			continue
		var st := stage if stage > 0 else mini(MAX_STAGE, int(skill.get("rarity", 1)) + 1)
		out.append({
			"id": str(skill.get("id", "")),
			"name": String(skill.get("name", "")),
			"pct": effect_pct(skill, st, level),
			"cd": cooldown_turns(skill, st),
			"left": 0,
		})
		if out.size() >= count:
			break
	return out


static func attach(unit: Dictionary, equipped: Array) -> void:
	## 전투 유닛에 장착 목록을 붙인다. 사본을 넣는다 — 쿨타임이 유닛 상태라 목록을 공유하면
	## 파티원끼리 쿨을 나눠 쓰게 된다.
	unit["skills"] = equipped.duplicate(true)
