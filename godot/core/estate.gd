class_name FonsEstate
extends RefCounted
## 영지의 **하루 일과** — 사람이 하는 일이 곧 태그가 되고, 태그가 스킬이 된다 (GDD 09 §3·§4-1).
##
## 왜 시설 운영이 아니라 일과인가
## ---------------------------
## `data/estate.json` 의 시설은 **해금 층과 건설**을 따로 갖는다 (소환제단만 초기 가동 · 확정 #70).
## 건설·시설 레벨·수지표는 아직 구현이 없으므로, 여기서 시설을 "가동 중"이라고 우기지 않는다.
## 대신 초기 영지에 실제로 있는 것 — **채집 4인**을 포함한 주민의 노동 — 을 행동으로 적는다.
## 시설 운영(간호·연구·조제)은 건설·레벨이 붙을 때 `WORK` 에 추가한다.
##
## 수확은 `estate.json` 이 정한다 (값을 여기서 만들지 않는다)
## ------------------------------------------------------
##   `gathering.base_yield` × `floor_multiplier_formula`(1+floor/50) ÷ `gathering.team_size`
## 한 사람 몫 = 팀 수확 ÷ 팀 크기(4). 팀 배치 자체는 아직 모델링하지 않는다 — 하루에 한 번,
## 각 영웅이 일 하나를 고르고 그 몫을 받는다. (ponytail: 팀·쿨다운·숙련도는 수지표가 붙을 때)
##
## AI 판정은 `FonsBrain` 이 진다 (09 §4-1: 영지 = 행동 완료 시 재판정)
## -----------------------------------------------------------------
## 후보 = `{action, tag, domain, apt}`. 전투 태그가 아니므로 A항(적성 효율)이 실제로 걸린다
## (09 §4-1-1 — 적성은 생활 전용). S항은 생활 스탯 데이터가 없어 1.0 이다: 없는 값을 지어내지 않는다.
##
## 태그 이름은 전부 GDD 09 §3 의 104종에서 온다. 여기서 새 태그를 만들지 않는다.

## 아침 일과 — 태그 옆은 `personalities.json` 의 적성 이름이다 (09 §4-1-1 매핑).
## 적성이 의미상 1:1 로 서지 않는 일(운반·청소·기록·순찰·자체훈련)은 비워 둔다 — 억지 매핑은 취향을 왜곡한다.
const WORK := [
	{"action": "채집", "tag": "채집", "domain": "생산", "apt": "채집꾼", "yield": "food"},
	{"action": "약초채집", "tag": "약초학", "domain": "지식", "apt": "조약사", "yield": "herb"},
	{"action": "벌목", "tag": "벌목", "domain": "생산", "apt": "벌목꾼", "yield": "wood"},
	{"action": "채광", "tag": "채광", "domain": "생산", "apt": "광부", "yield": "ore"},
	{"action": "요리", "tag": "요리", "domain": "생산", "apt": "요리사"},
	{"action": "운반", "tag": "운반", "domain": "생산"},
	{"action": "청소", "tag": "청소", "domain": "사회"},
	{"action": "자체훈련", "tag": "자체훈련", "domain": "사회"},
	{"action": "순찰", "tag": "순찰", "domain": "사회"},
	{"action": "기록", "tag": "기록", "domain": "지식"},
]

## 저녁 회복 — 09 §3 회복 도메인만. 회복량은 병원·숙소 데이터가 붙을 때 정한다 (지금은 태그만).
const REST := [
	{"action": "휴식", "tag": "휴식", "domain": "회복"},
	{"action": "식사", "tag": "식사", "domain": "회복"},
	{"action": "장비정비", "tag": "장비정비", "domain": "회복"},
	{"action": "명상", "tag": "명상", "domain": "회복"},
	{"action": "독서", "tag": "독서", "domain": "회복"},
]

var floor := 1
## 수확 누적 — `food`·`herb`·`wood`·`ore`. 소비·저장고는 아직 없다 (수지표 몫).
var stores := {}
var log_lines: Array = []

var _gathering: Dictionary = {}
var _rng: RandomNumberGenerator = null


func start(estate_data: Dictionary, floor_value: int, rng: RandomNumberGenerator = null) -> void:
	floor = maxi(1, floor_value)
	_gathering = estate_data.get("gathering", {})
	_rng = rng
	stores = {"food": 0, "herb": 0, "wood": 0, "ore": 0}
	log_lines = []


func candidates() -> Array:
	## 지금 할 수 있는 일. `WORK` 는 const 라 사본을 돌려준다 — 브레인이 고른 행에 표시를 달아도
	## 원본이 더러워지지 않는다.
	var out: Array = []
	for job in WORK:
		out.append(job.duplicate())
	return out


func rest_candidates() -> Array:
	var out: Array = []
	for job in REST:
		out.append(job.duplicate())
	return out


func shift(heroes: Array) -> Dictionary:
	## 아침 — 영웅마다 일 하나. 고른 일의 태그가 그 사람의 카운터에 남고 각인 판정까지 간다.
	## 반환: `{born, stores}` — 부르는 쪽이 "새 기술"과 수확을 로그에 남긴다.
	var pool := candidates()
	var born: Array = []
	for hero in heroes:
		if not bool(hero.get("alive", true)):
			continue
		var pick := _choose(hero, pool)
		if pick.is_empty():
			continue
		_record(hero, pick, "영지", born)
		_apply_yield(pick)
		log_lines.append("%s — %s" % [String(hero.get("name", "?")), String(pick["action"])])
	return {"born": born, "stores": stores.duplicate()}


func recover(heroes: Array) -> Dictionary:
	## 저녁 — 하루를 닫는 행동. 지금은 태그만 남는다 (회복량은 병원·숙소가 붙을 때).
	var pool := rest_candidates()
	var born: Array = []
	for hero in heroes:
		if not bool(hero.get("alive", false)):
			continue
		var pick := _choose(hero, pool)
		if pick.is_empty():
			continue
		_record(hero, pick, "저녁", born)
		log_lines.append("%s — %s" % [String(hero.get("name", "?")), String(pick["action"])])
	return {"born": born}


func _choose(hero: Dictionary, pool: Array) -> Dictionary:
	## 브레인이 있으면 그 사람의 취향대로 (09 §4-1). 없으면 결정론적 추첨 — 측정이 멈추지 않게.
	if pool.is_empty():
		return {}
	if FonsBrain.attached(hero):
		return hero["brain"].decide(pool, {"hp_ratio": 1.0})
	if _rng != null:
		return pool[_rng.randi_range(0, pool.size() - 1)]
	return pool[0]


func _record(hero: Dictionary, pick: Dictionary, where: String, born: Array) -> void:
	## 행동 하나를 남긴다. 브레인이 있으면 카운터·각인, 없으면 유닛 태그 거울.
	if FonsBrain.attached(hero):
		var brain: FonsBrain = hero["brain"]
		var seen := brain.commit({"action": pick["action"], "tag": pick["tag"],
			"domain": pick["domain"]})
		brain.mirror(hero)
		for name in seen["born"]:
			born.append(name)
			log_lines.append("%s → 새 기술 「%s」 (%s)" % [
				String(hero.get("name", "?")), String(name), where])
	else:
		FonsActionTags.record(hero, String(pick["action"]))


func _apply_yield(pick: Dictionary) -> void:
	var item := String(pick.get("yield", ""))
	if item.is_empty():
		return
	stores[item] = int(stores.get(item, 0)) + share(item)


func share(item: String) -> int:
	## 한 사람 몫 — `estate.json` 의 `base_yield` × 층 배율 ÷ 팀 크기.
	## `floor_multiplier_formula` 는 정본이 문자열로 적어 둔 식(`1+floor/50`)이다. 여기서 그대로 옮긴다.
	var base := float(_gathering.get("base_yield", {}).get(item, 0))
	var team := maxf(1.0, float(_gathering.get("team_size", 1)))
	return int(round(base * multiplier() / team))


func multiplier() -> float:
	return 1.0 + float(floor) / 50.0


func snapshot() -> Dictionary:
	return {
		"floor": floor,
		"stores": stores.duplicate(),
		"log": log_lines.slice(maxi(0, log_lines.size() - 6)),
	}
