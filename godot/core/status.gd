class_name FonsStatus
extends RefCounted
## 기본 공격의 **지원·제어 효과** — 치유 · 보호막 · 도발.
##
## 왜 여기인가
## ----------
## 102종 기본 공격의 `cls`(offense/support/control)와 태그는 이미 데이터에 있다.
## 그런데 전투는 모든 행동을 피해로만 처리해서, 치유·도발을 골라도 맨손과 같은
## 피해가 들어갔다. 이 파일이 그 자리를 채운다 — 태그가 곧 효과의 이름이다.
##
## 수치는 정본이 없다
## -----------------
## GDD 09 §5-2 는 **스킬** 효과 기본값만 정한다. 기본 공격의 회복·보호막 수치는
## 어디에도 없으므로 지어내지 않고 **가안**으로 두고 등록소에 먼저 적었다:
##   BASIC_HEAL_PCT 0.12 · BASIC_SHIELD_PCT 0.15 · BASIC_SHIELD_TURNS 3 · BASIC_TAUNT_TURNS 2
## 밸런스가 확정되면 `tools/tracked_numbers.json` 과 여기 상수를 함께 고친다.
##
## 구현한 태그만 효과가 있다
## ------------------------
##   치유                              → 가장 다친 아군 회복
##   보호막 · 아군보호                  → 가장 다친 아군 보호막
##   방어태세 · 반격자세 · 경계          → 자기 보호막
##   도발                              → 자기 도발 (적이 나를 친다)
## 나머지 지원·제어 태그(정화·전술신호·침묵 등)는 상태 모델이 더 있어야 하므로
## **아직 기본 피해**로 남는다 — 없는 효과를 흉내내지 않는다.

const HEAL_PCT := 0.12
const SHIELD_PCT := 0.15
const SHIELD_TURNS := 3
const TAUNT_TURNS := 2

const HEAL_TAGS := ["치유"]
const ALLY_SHIELD_TAGS := ["보호막", "아군보호"]
const SELF_SHIELD_TAGS := ["방어태세", "반격자세", "경계"]
const TAUNT_TAGS := ["도발"]


static func handles(tag: String) -> bool:
	return tag in HEAL_TAGS or tag in ALLY_SHIELD_TAGS \
		or tag in SELF_SHIELD_TAGS or tag in TAUNT_TAGS


static func lowest_ratio(units: Array) -> Dictionary:
	## 살아 있는 유닛 중 HP 비율이 가장 낮은 하나. 없으면 빈 Dictionary.
	var best: Dictionary = {}
	var best_ratio := 2.0
	for u in units:
		if not bool(u.get("alive", false)):
			continue
		var ratio := float(u.get("hp", 0)) / maxf(1.0, float(u.get("maxHp", 1)))
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best


static func taunt_target(party: Array) -> Dictionary:
	## 도발 중인 살아 있는 아군. 적은 이 사람을 먼저 친다.
	for u in party:
		if bool(u.get("alive", false)) and int(u.get("taunt", 0)) > 0:
			return u
	return {}


static func act(actor: Dictionary, party: Array, move: Dictionary) -> Dictionary:
	## 기본 공격 하나의 효과를 적용하고 로그 한 줄을 돌려준다.
	## 효과가 없는 태그면 빈 Dictionary — 호출부는 그대로 피해를 굴린다.
	if String(move.get("basic_id", "")).is_empty():
		return {}
	var tag := String(move.get("tag", ""))
	if not handles(tag):
		return {}
	var actor_name := String(actor.get("name", "?"))

	if tag in TAUNT_TAGS:
		actor["taunt"] = TAUNT_TURNS
		return {"text": "%s → 「도발」 %d턴" % [actor_name, TAUNT_TURNS]}

	var target: Dictionary = actor if tag in SELF_SHIELD_TAGS else lowest_ratio(party)
	if target.is_empty():
		return {}
	var target_name := String(target.get("name", "?"))

	if tag in HEAL_TAGS:
		var amount := int(roundf(float(target.get("maxHp", 1)) * HEAL_PCT))
		var before := int(target.get("hp", 0))
		target["hp"] = mini(int(target.get("maxHp", 1)), before + amount)
		var healed := int(target["hp"]) - before
		return {"text": "%s → %s 「치유」 +%d" % [actor_name, target_name, healed]}

	var shield := int(roundf(float(target.get("maxHp", 1)) * SHIELD_PCT))
	target["shield"] = float(target.get("shield", 0.0)) + float(shield)
	target["shield_turns"] = SHIELD_TURNS
	return {"text": "%s → %s 「보호막」 %d (%d턴)" % [actor_name, target_name, shield, SHIELD_TURNS]}


static func tick(unit: Dictionary) -> void:
	## 턴 시작 — 보호막·도발의 남은 턴을 줄인다. 0이 되면 지운다.
	if float(unit.get("shield", 0.0)) > 0.0:
		unit["shield_turns"] = int(unit.get("shield_turns", 0)) - 1
		if int(unit["shield_turns"]) <= 0:
			unit["shield"] = 0.0
			unit["shield_turns"] = 0
	if int(unit.get("taunt", 0)) > 0:
		unit["taunt"] = int(unit["taunt"]) - 1


static func absorb(unit: Dictionary, damage: int) -> int:
	## 피해에서 보호막이 먹은 양. 보호막이 다 닳아도 턴은 그대로 센다.
	var shield := float(unit.get("shield", 0.0))
	if shield <= 0.0 or damage <= 0:
		return 0
	var absorbed := mini(int(shield), damage)
	unit["shield"] = shield - float(absorbed)
	return absorbed
