class_name FonsHeroStats
extends RefCounted
## 영웅 스탯 13축 + 전투력(CP) — 순수 계산. Unity 를 쓰지 않는다.
##
## 정본은 전부 데이터다:
##   기준스탯   `races.json` meta.heroBaseStats   (MS 100% = 기준)
##   CP 가중치  `races.json` meta.cpWeights       (01 §3 ①식 13항)
##   카드 배율  `job_tree.json` keywords[].statMod (13축 배율, 순서는 AXES 와 같다)
##
## 38차 결정: 회피율(EVA)은 없다. 민첩 축이 이동속도(MS)를 올리고,
## 이동속도는 "붙기까지 걸리는 시간" 하나로 읽힌다. 확률로 피해를 지우는 판정은 없다.
##
## 왜 여기서 CP 를 계산하나:
##   전투력은 표시용이지만 "카드 한 장의 CP 배율 == power" 계약을 지켜야 한다.
##   그 검산을 유니티 없이 돌리려면 같은 식이 이쪽에도 있어야 한다.

const AXES := ["HP", "ATK", "DEF", "ASPD", "MAG", "MDEF", "CRI",
		"PEN", "MPEN", "MS", "CDMG", "STA", "MANA"]

## 축 → races.json heroBaseStats 키 (소문자)
const BASE_KEYS := {
	"HP": "hp", "ATK": "atk", "DEF": "def", "ASPD": "aspd", "MAG": "mag",
	"MDEF": "mdef", "CRI": "cri", "PEN": "pen", "MPEN": "mpen", "MS": "ms",
	"CDMG": "cdmg", "STA": "sta", "MANA": "mana",
}

## 등급계수·레벨계수가 어느 축에 걸리는지 — 축 집합이 다르다. 근거는 원본 구현이다.
##   등급계수: HP · ATK · MAG · DEF · MDEF · **MANA** — 05 §7 "등급계수 미적용 7종"의 여집합
##             (ASPD·CRI·PEN·MS·CDMG·SPD_CAST·STA 는 미적용)
##   레벨계수: HP · ATK · MAG · DEF · MDEF — **MANA 는 안 받는다**
## 원본 `CombatStats.FromRace` 는 MANA 에 `rankMul` 을 곱하고,
## `BattleSystem.AddHero` 는 `Mana = stats.Mana + equipment.Mana` 로 가산만 한다 (원본 대조).
## GDD 05 §7 은 레벨계수의 축별 예외를 적지 않아 이 구분이 코드에만 있었다 — docs/adr/0005.
const GRADE_AXES := ["HP", "ATK", "MAG", "DEF", "MDEF", "MANA"]
const LEVEL_AXES := ["HP", "ATK", "MAG", "DEF", "MDEF"]
const MAX_GRADE := 7        ## ★1~★7 (01 §2)
const MAX_LEVEL := 130      ## 확정 #34

## 101층 기억 — 100층을 올라온 런이 101층에서 10점을 화력·생존에 나눈다.
## 1점당 ×1.30 **곱연산**이라 5점이면 ×3.71, 10점이면 ×13.79다.
## 근거·측정: docs/design/★5_101_120_기억_성장축_설계.md
const MEMORY_MAX := 10
const MEMORY_STEP := 0.30
const MEMORY_ATTACK_AXES := ["ATK", "MAG"]
const MEMORY_GUARD_AXES := ["HP", "DEF", "MDEF"]

var base: Dictionary = {}
var weights: Dictionary = {}


static func from_data(races: Dictionary) -> FonsHeroStats:
	## races.json 전체를 넘긴다 — meta 안에서 기준스탯과 가중치를 꺼낸다.
	var stats := FonsHeroStats.new()
	var meta: Dictionary = races.get("meta", {})
	var raw: Dictionary = meta.get("heroBaseStats", {})
	var w: Dictionary = meta.get("cpWeights", {})
	for axis in AXES:
		stats.base[axis] = float(raw.get(BASE_KEYS[axis], 0.0))
		if not w.has(axis):
			push_error("cpWeights 누락: %s (races.json meta.cpWeights)" % axis)
		stats.weights[axis] = float(w.get(axis, 0.0))
	if stats.base["MS"] <= 0.0:
		push_error("heroBaseStats.ms 가 0 이다 — 이동속도 기준은 100 이어야 한다")
	return stats


func with_keyword(stat_mod: Array) -> Dictionary:
	## 카드 한 장을 곱한 스탯. statMod 는 재배분이라 총량은 그대로고 방향만 바뀐다.
	var out := {}
	for i in AXES.size():
		var mul: float = float(stat_mod[i]) if i < stat_mod.size() else 1.0
		out[AXES[i]] = base[AXES[i]] * mul
	return out


func combat_power(stats: Dictionary) -> float:
	var total := 0.0
	for axis in AXES:
		total += weights[axis] * float(stats.get(axis, 0.0))
	return total


static func grade_coeff(grade: int) -> float:
	## 01 §2 — 등급당 ×1.3 복리. ★1 1.00 · ★5 2.86 · ★7 4.83.
	return pow(1.3, float(clampi(grade, 1, MAX_GRADE) - 1))


static func level_coeff(level: int) -> float:
	## 확정 #34 — 1 + (Lv−1) × 0.05. Lv130 ×7.45.
	return 1.0 + float(clampi(level, 1, MAX_LEVEL) - 1) * 0.05


static func memory_multiplier(points: int) -> float:
	## 나눈 점수가 만드는 배율. 0점 1.00 · 5점 3.71 · 10점 13.79.
	return pow(1.0 + MEMORY_STEP, float(clampi(points, 0, MEMORY_MAX)))


static func apply_memory(stats: Dictionary, attack: int, guard: int) -> Dictionary:
	## 101층 배분을 필드스탯에 건다 — 화력은 ATK·MAG, 생존은 HP·DEF·MDEF.
	## 개체 변량(`varied`) 뒤에 걸어야 변량까지 같은 배율로 커진다.
	var out := stats.duplicate()
	var attack_mul := memory_multiplier(attack)
	var guard_mul := memory_multiplier(guard)
	for axis in MEMORY_ATTACK_AXES:
		out[axis] = float(out.get(axis, 0.0)) * attack_mul
	for axis in MEMORY_GUARD_AXES:
		out[axis] = float(out.get(axis, 0.0)) * guard_mul
	return out


static func varied(stats: Dictionary, rng, rate: float = 0.07) -> Dictionary:
	## 05 §7 개체 변량 ±7% — 소환 시점에 전 축에 건다 (`summon.ts buildStats` 마지막 곱, 원본 대조).
	## 시드 고정 난수를 받으므로 같은 시드면 같은 개체가 나온다.
	var out := stats.duplicate()
	for axis in AXES:
		out[axis] = float(out.get(axis, 0.0)) * (1.0 + rate * (rng.randf() * 2.0 - 1.0))
	return out


static func field_stats(stats: Dictionary, grade: int, level: int, purity: float = 1.0,
		keyword_mod: Array = [], equipment: Dictionary = {},
		job_mod: Dictionary = {}) -> Dictionary:
	## 05 §7 필드스탯 = 기준 × 종족mods × **직업계수** × 키워드 × 등급계수 × 레벨계수 × 순수도 + 장비.
	##   직업계수는 `FonsJobCoef.multipliers()` 가 만든 7축 배율이다 (05 §4 표 → `data/job_coef.json`).
	##   원본도 계수를 계수 앞에 건다 — `gacha_test` 주석 "필드스탯 = 기준 × (1+statMods%) × 직업계수 × 등급계수 × 레벨계수".
	##   배율이 없는 축(7축 밖)은 1.0 이라 건드리지 않는다 — PEN·MS·CDMG·STA·MANA.
	##   장비는 곱이 아니라 가산이고 계수 뒤에 온다 (원본 `AddHero`: `stats.Atk * lvMul + equipment.Atk`).
	##   순수도와 장비의 선후는 GDD 에 없다 — 순수도는 영웅 자신의 배율, 장비는 별개 층이라
	##   순수도를 먼저 걸고 장비를 더한다 (장비까지 순수도로 깎지 않는다).
	var grade_mul := grade_coeff(grade)
	var level_mul := level_coeff(level)
	var out := stats.duplicate()
	# 직업계수 — 종족mods 다음, 등급계수 앞. 원본 `buildStats` 순서와 같다.
	if not job_mod.is_empty():
		for axis in AXES:
			var job_mul: float = float(job_mod.get(axis, 1.0))
			if not is_equal_approx(job_mul, 1.0):
				out[axis] = float(out.get(axis, 0.0)) * job_mul
	# 키워드 카드는 곱도 계수 앞이다 — 원본 `CombatStats.FromRace` 가 종족mods 뒤, 등급계수 앞에 건다.
	if not keyword_mod.is_empty():
		for i in AXES.size():
			var card_mul: float = float(keyword_mod[i]) if i < keyword_mod.size() else 1.0
			out[AXES[i]] = float(out.get(AXES[i], 0.0)) * card_mul
	for axis in GRADE_AXES:
		out[axis] = float(out.get(axis, 0.0)) * grade_mul
	for axis in LEVEL_AXES:
		out[axis] = float(out.get(axis, 0.0)) * level_mul
	# 순수도는 전 축 최종 배율 (05 §7-1) — 승급 1회 −0.04, 각성 상한 1.08.
	if not is_equal_approx(purity, 1.0):
		for axis in AXES:
			out[axis] = float(out.get(axis, 0.0)) * purity
	if not equipment.is_empty():
		for axis in AXES:
			out[axis] = float(out.get(axis, 0.0)) + float(equipment.get(axis, 0.0))
	return out


func keyword_power_ratio(stat_mod: Array) -> float:
	## 카드 한 장의 CP 배율 — job_tree.json 의 power 와 같아야 한다(검산용).
	var before := combat_power(base)
	if before <= 0.0:
		return 0.0
	return combat_power(with_keyword(stat_mod)) / before
