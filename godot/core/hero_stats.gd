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


func keyword_power_ratio(stat_mod: Array) -> float:
	## 카드 한 장의 CP 배율 — job_tree.json 의 power 와 같아야 한다(검산용).
	var before := combat_power(base)
	if before <= 0.0:
		return 0.0
	return combat_power(with_keyword(stat_mod)) / before
