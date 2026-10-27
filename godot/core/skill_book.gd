class_name FonsSkillBook
extends RefCounted
## 행동 카운터 → **각인** → 단계·레벨 성장. 스킬은 배우는 게 아니라 생긴다 (GDD 09 §1 원칙 1).
##
## 정본 규칙 (09 §5 — 여기서 수치를 만들지 않는다)
## ------------------------------------------------
##   각인     조건 태그 최소치를 **전부** 넘고 + 태그 합계 ≥ `engrave_threshold`
##            (예: L 유성… = 390/325/195 최소 + 합계 936 — 3태그 910 에 문맥 26 이 붙는다)
##   발견     도달 후 **50% 판정** — 실패해도 재화 없이 다음 틱에 다시 (09 §5 표 2행)
##   레벨     단계 내 1~13 · 필요 XP = 13 × 현재 레벨 · 행동 실행당 +1
##   승격     13레벨 도달 → 단계 +1, 레벨 1 리셋 (7단계)
##   상한     단계 상한 = 레어도 + 1 (D 중급 ~ L 초월급) · 상한 13레벨에서 XP 정지
##   보유     영웅당 **32개** (09 §6 생성 게이트) — 넘으면 더 각인하지 않는다
##
## 왜 카운터만 보나: 원시 로그를 버렸기 때문이다 (원칙 3). 태그 숫자만으로도 "무엇을 오래 했는지"는 남는다.
##
## XP 가중: 부가 성격의 도메인 선호 ×1.10 · 반대 ×0.95 는 **XP 에도 걸린다** (09 §4-4 ①).
## 그래서 같은 행동을 해도 성격이 다르면 다른 속도로 자란다 — 이게 개체차의 실체다.
##
## **연습 열기(heat)** 는 정본에 없는 가안이다. 단계·레벨은 "얼마나 자랐나"고,
## 열기는 "요즘 손에 붙었나"다. 같은 단계의 두 기술을 가르는 용도로만 쓰고 피해는 안 건드린다.

const CAP := 32
## 성장 예산 — 층마다 늘어나는 총 보유 상한(각인+융합).
##
## 왜 직선이 아닌가: 직선 6 + 0.55 × 층 은 48층에 32 에 닿고, 그 뒤 82층은 새 기술이
## 하나도 안 생긴다. 130층이 실제 최대 층이므로 성장도 130층까지 이어져야 한다.
## 그래서 40층에서 한 번 꺾는다 — 초반은 빨리, 이후는 9층에 하나씩.
##
##   1층 6 → 40층 22 → 49층 23 → 58층 24 → … → 121층 31 → 130층 32(상한)
##
## 각인 확률만 낮추면 융합이 그 자리를 메워 상한이 그대로 찬다(2026-10-22 실측).
## 마지막 한 칸을 130층에 두는 이유: 최대 층에서 새 기술이 나야 "끝까지 자란다"가 성립한다.
const GROWTH_BASE := 6.0
const GROWTH_KNEE_FLOOR := 40
const GROWTH_KNEE := 22.0
const GROWTH_END_FLOOR := 130
const GROWTH_END := 32.0


static func growth_limit(floor_value: int) -> int:
	var f := clampi(floor_value, 1, GROWTH_END_FLOOR)
	var n := 0.0
	if f <= GROWTH_KNEE_FLOOR:
		n = GROWTH_BASE + (GROWTH_KNEE - GROWTH_BASE) * float(f - 1) / float(GROWTH_KNEE_FLOOR - 1)
	else:
		n = GROWTH_KNEE + (GROWTH_END - GROWTH_KNEE) * float(f - GROWTH_KNEE_FLOOR) \
			/ float(GROWTH_END_FLOOR - GROWTH_KNEE_FLOOR)
	return mini(CAP, floori(n))
const MAX_STAGE := 7
const MAX_LEVEL := 13
const LEVEL_STEP := 13        ## 필요 XP = 13 × 현재 레벨
const ENGRAVE_CHANCE := 0.50
const K_STEP := 0.05          ## K항 = 1 + 0.05 × 관련 스킬 단계 합 (09 §4-1)
## 연습 열기 — "요즘 손에 붙었나". 정본에 없는 가안이다 (09 는 단계·레벨만 센다).
## 단계가 같은 두 기술이라도 최근에 쓴 쪽을 고르게 만든다. 안 쓴 기술은 식는다 — 지우지는 않는다.
const HEAT_START := 1.0
const HEAT_PER_USE := 1.0
const HEAT_CAP := 8.0
const HEAT_DECAY := 0.98     ## 다른 기술을 한 번 쓸 때마다 ×0.98 — 100번 안 쓰면 8 → 0.13
const HEAT_BIAS := 0.15      ## 뜨거운 기술 선호 상한 +15% (피해가 아니라 **선택** 가중)


static func total_xp(counters: Dictionary) -> int:
	## 각인 합계 판정에 쓰는 값 — 태그 + 문맥 카운터 전부 (L 은 문맥 26 이 합계에 들어간다).
	var n := 0
	for tag in counters:
		n += int(counters[tag])
	return n


static func meets(skill: Dictionary, counters: Dictionary, total: int) -> bool:
	## 태그 최소치 전부 + 합계 임계. 하나라도 모자라면 false.
	for req in skill.get("tag_thresholds", []):
		if int(counters.get(String(req.get("tag", "")), 0)) < int(req.get("v", 0)):
			return false
	return total >= int(skill.get("engrave_threshold", 0))


static func eligible(book: Dictionary, counters: Dictionary, catalog: Array) -> Array:
	## 지금 각인 조건을 넘은, 아직 없는 스킬. 카탈로그 순서를 유지한다 (결정론).
	var total := total_xp(counters)
	var out: Array = []
	for skill in catalog:
		var id := str(skill.get("id", ""))
		if book.has(id):
			continue
		if meets(skill, counters, total):
			out.append(skill)
	return out


static func try_engrave(book: Dictionary, counters: Dictionary, catalog: Array,
		rng: RandomNumberGenerator, chance: float = ENGRAVE_CHANCE,
		domain_weight: Dictionary = {}, floor_value: int = 0) -> Array:
	## **한 번에 하나**만 각인한다. 50% 판정을 한 번 굴리고, 후보가 여럿이면
	## 그 영웅이 **좋아하는 도메인**의 기술을 먼저 집는다 — 같은 행동을 해도
## 성격이 다르면 다른 기술을 깨우친다 (09 §4-2 장치 1).
	## 한꺼번에 여러 개를 각인하면 1,300종 카탈로그가 한 판에 쏟아져 발견의 순간이 사라진다.
	## `chance` 는 측정·테스트용 손잡이다 — 정본 값은 0.50 (09 §5 표 2행).
	var born: Array = []
	if book.size() >= CAP:
		return born
	if floor_value > 0 and book.size() >= growth_limit(floor_value):
		return born
	var pool := eligible(book, counters, catalog)
	if pool.is_empty():
		return born
	var skill := _preferred(pool, domain_weight)
	if rng.randf() >= chance:
		return born
	var id := str(skill.get("id", ""))
	book[id] = make_entry(skill)
	born.append(String(skill.get("name", "")))
	return born


static func make_entry(skill: Dictionary) -> Dictionary:
	## 카탈로그 항목 → 스킬북 항목. 각인과 **복원**이 같은 모양을 쓴다.
	## 복원에서 이 함수를 안 쓰면 저장에서 돌아온 스킬북과 새로 깨운 스킬북의 필드가 갈린다.
	return {
		"name": String(skill.get("name", "")),
		"rarity": int(skill.get("rarity", 1)),
		"domain": String(skill.get("domain", "")),
		"tags": skill.get("tags", []),
		"context": String(skill.get("context", "")),
		"effect_kind": String(skill.get("effect_kind", "")),
		"effect_base": float(skill.get("effect_base", 0.0)),
		"cool_base": float(skill.get("cool_base", 0.0)),
		"stage": 1,
		"level": 1,
		"xp": 0,
		"heat": HEAT_START,
	}


static func _preferred(pool: Array, domain_weight: Dictionary) -> Dictionary:
	## 좋아하는 도메인 → 낮은 임계 → 작은 id 순. 결정론이 있어야 같은 시드가 같은 기술을 깨운다.
	var best: Dictionary = {}
	var best_key := -INF
	for skill in pool:
		var weight := float(domain_weight.get(String(skill.get("domain", "")), 1.0))
		var key := weight * 10000.0 - float(skill.get("engrave_threshold", 0)) - float(skill.get("id", 0)) / 10000.0
		if key > best_key:
			best_key = key
			best = skill
	return best


static func stage_cap(entry: Dictionary) -> int:
	## 레어도가 곧 도달 가능한 최대 단계 — D 2(중급) ~ L 7(초월급).
	return clampi(int(entry.get("rarity", 1)) + 1, 2, MAX_STAGE)


static func add_use(book: Dictionary, skill_id: String) -> void:
	## 스킬을 한 번 썼다 — XP +1. 상한 단계의 13레벨이면 멈춘다 (융합으로만 상한 돌파).
	## 쓴 기술은 뜨거워지고, 안 쓴 기술은 조금씩 식는다 — 같은 태그의 다른 기술을 고르는 기준.
	if not book.has(skill_id):
		return
	for id in book:
		book[id]["heat"] = maxf(0.0, float(book[id].get("heat", 0.0)) * HEAT_DECAY)
	var entry: Dictionary = book[skill_id]
	entry["heat"] = minf(HEAT_CAP, float(entry.get("heat", 0.0)) + HEAT_PER_USE)
	if int(entry["stage"]) >= stage_cap(entry) and int(entry["level"]) >= MAX_LEVEL:
		return
	entry["xp"] = int(entry.get("xp", 0)) + 1
	var need := LEVEL_STEP * int(entry["level"])
	if int(entry["xp"]) < need:
		return
	entry["xp"] = int(entry["xp"]) - need
	if int(entry["level"]) >= MAX_LEVEL:
		entry["stage"] = mini(MAX_STAGE, int(entry["stage"]) + 1)
		entry["level"] = 1
		entry["xp"] = 0
	else:
		entry["level"] = int(entry["level"]) + 1


static func heat_bias(heat: float) -> float:
	## 연습 열기 → 선택 가중. 0 이면 1.0, 상한이면 1+HEAT_BIAS.
	return 1.0 + HEAT_BIAS * clampf(heat / HEAT_CAP, 0.0, 1.0)


static func factor(book: Dictionary, tag: String) -> float:
	## K항 — 이 태그를 쓰는 스킬들이 자랄수록 그 행동을 더 좋아한다 (자기강화 루프).
	var stages := 0
	for id in book:
		var entry: Dictionary = book[id]
		if tag in entry.get("tags", []):
			stages += int(entry.get("stage", 1))
	return 1.0 + K_STEP * float(stages)


static func skills_for_tag(book: Dictionary, tag: String) -> Array:
	## 이 태그로 쓸 수 있는 스킬 id — 전투가 "행동에 맞는 기술"을 고를 때 쓴다.
	var out: Array = []
	for id in book:
		if tag in book[id].get("tags", []):
			out.append(id)
	return out


static func strongest(book: Dictionary, catalog_by_id: Dictionary) -> Dictionary:
	## 단계·레벨이 가장 높은 스킬 하나. 융합 후보·표시용.
	var best: Dictionary = {}
	for id in book:
		var entry: Dictionary = book[id]
		if best.is_empty():
			best = entry
			continue
		var a := int(entry["stage"]) * MAX_LEVEL + int(entry["level"])
		var b := int(best["stage"]) * MAX_LEVEL + int(best["level"])
		if a > b:
			best = entry
	if best.is_empty():
		return {}
	return best


static func by_id(catalog: Array) -> Dictionary:
	var out := {}
	for skill in catalog:
		out[str(skill.get("id", ""))] = skill
	return out
