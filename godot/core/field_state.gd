class_name FonsFieldState
extends RefCounted
## 탐험 필드의 **진행 상태** — 뷰가 읽는 스냅샷을 만든다. 화면을 모른다.
##
## `FonsExplore` 는 필드 한 판의 규칙(걷기·조우·후퇴·미션)만 안다. 이 클래스는 그 위에
## **영웅·층·로그**를 얹어 `main.gd` 가 뷰에 밀어 넣을 수 있는 한 덩어리로 만든다.
## 전투 규칙은 `FonsFloorRun`/`FonsBattle` 그대로다 — 여기서 새로 만들지 않는다.
##
## 왜 `FonsRunState` 를 안 고쳤나
## ---------------------------
## `FonsRunState` 는 층 한 판 = 전투 한 번인 측정·기존 화면의 심이다. 그 의미를 바꾸면
## `floor_report`·`brain_report`·`test_run_state` 가 같이 흔들린다. 탐험 화면은 별도 심으로
## 두고, 나중에 하루(`FonsDay`)와 합칠 때 이 클래스가 그 접점이 된다.
##
## 입력은 `intent` 로만 들어온다 (뷰 계약). 이 클래스는 키를 모른다.

const MAX_FLOOR := 130
const START_FLOOR := 1
const PARTY_SIZE := 4
const LOG_TAIL := 8
## 조우 지점 위에 서 있는 판정은 `FonsExplore.contact_index()` 가 진다 (반경 1.5).

var floor := START_FLOOR
var heroes: Array = []
var explore: FonsExplore = null
var log_lines: Array = []
var winner := ""

var _races: Dictionary = {}
var _monsters: Variant = null
var _biomes: Variant = null
var _job_tree: Dictionary = {}
var _equipment: Dictionary = {}
var _job_coef: Dictionary = {}
var _ai: Dictionary = {}
var _seed := 0
var _start_floor := START_FLOOR
var _rng := RandomNumberGenerator.new()


func start(races: Dictionary, monsters: Variant, biomes: Variant,
		seed_value: int = 0, start_floor: int = START_FLOOR,
		job_tree: Dictionary = {}, equipment: Dictionary = {},
		job_coef: Dictionary = {}, ai: Dictionary = {}) -> void:
	_races = races
	_monsters = monsters
	_biomes = biomes
	_job_tree = job_tree
	_equipment = equipment
	_job_coef = job_coef
	_ai = ai
	_seed = seed_value
	_start_floor = clampi(start_floor, START_FLOOR, MAX_FLOOR)
	floor = _start_floor
	heroes = _make_party()
	_open_field()
	log_lines = []
	winner = ""


func restart() -> void:
	floor = _start_floor
	heroes = _make_party()
	_open_field()
	log_lines = []
	winner = ""


func walk(direction: Vector2, seconds: float) -> void:
	if explore == null or not winner.is_empty():
		return
	explore.walk(direction, seconds)


func contact_index() -> int:
	return explore.contact_index() if explore != null else -1


func engage() -> Dictionary:
	## 접촉 중인 조우 하나를 친다. 접촉이 없으면 빈 Dictionary (뷰가 "할 일 없음"을 안다).
	var index := contact_index()
	if index < 0:
		return {}
	var out := explore.fight(index, heroes, _rng)
	# 이 조우에서 겪은 세계(물가·동굴·문지기)를 문맥 카운터로 남긴다.
	var world := FonsFusion.place_context(_biomes, floor)
	for hero in heroes:
		if FonsBrain.attached(hero) and bool(hero.get("alive", false)):
			hero["brain"].note_context(world)
	# 이긴 조우 뒤에만 융합을 심사한다 — 싸우다 만 판에서 기술이 태어나면 이유를 설명할 수 없다.
	if String(out["winner"]) == "ally":
		for item in _judge_fusion():
			explore.log_lines.append("%s → 융합 「%s」" % [String(item["hero"]), String(item["name"])])
	log_lines = explore.log_lines.slice(maxi(0, explore.log_lines.size() - LOG_TAIL))
	_update_winner()
	return out


func retreat() -> void:
	if explore == null or not winner.is_empty():
		return
	explore.retreat(heroes)
	log_lines = explore.log_lines.slice(maxi(0, explore.log_lines.size() - LOG_TAIL))
	_update_winner()


func mission_done() -> bool:
	return explore != null and explore.mission_done()


func next_floor() -> bool:
	## 미션을 끝냈을 때만 다음 층. 영웅 HP 는 이어진다 — 쉬어서 회복하는 규칙은 아직 없다.
	if explore == null or not explore.mission_done() or floor >= MAX_FLOOR:
		return false
	floor += 1
	_open_field()
	log_lines = []
	winner = ""
	return true


func party_alive() -> int:
	var n := 0
	for hero in heroes:
		if bool(hero.get("alive", false)):
			n += 1
	return n


func hint() -> String:
	## HUD 아래 줄 — 지금 누를 수 있는 것만 말한다.
	if explore == null:
		return ""
	if not winner.is_empty():
		return "전멸 — R 로 1층부터 재도전"
	if explore.mission_done():
		return "미션 완료 — 스페이스로 다음 층"
	var index := contact_index()
	if index >= 0:
		return "조우 접촉 — 스페이스로 싸운다"
	return "WASD/방향키 — 걷기 · R — 후퇴 · 미션: 조우 %d/%d" % [explore.cleared, explore.required]


func snapshot() -> Dictionary:
	## 뷰가 읽는 유일한 형식. 좌표는 `Vector3`(R2), 엔티티 id 는 문자열(R3).
	var entities: Array = []
	var contact := contact_index()
	for i in explore.sites.size():
		var site: Dictionary = explore.sites[i]
		entities.append({
			"id": "site:%d" % i,
			"kind": "site",
			"pos": Vector3(float(site["pos"].x), 0.0, float(site["pos"].y)),
			"size": Vector2(1.2, 1.2),
			"cleared": bool(site["cleared"]),
			"contact": i == contact,
		})
	entities.append({
		"id": "avatar",
		"kind": "avatar",
		"pos": Vector3(explore.avatar.x, 0.0, explore.avatar.y),
		"size": Vector2(0.9, 0.9),
	})
	return {
		"mode": "field",
		"floor": floor,
		"field": Vector2(FonsExplore.FIELD_WIDTH, FonsExplore.FIELD_DEPTH),
		"avatar": Vector3(explore.avatar.x, 0.0, explore.avatar.y),
		"contact": contact,
		"cleared": explore.cleared,
		"required": explore.required,
		"done": explore.mission_done(),
		"wiped": not winner.is_empty(),
		"entities": entities,
		"log": log_lines.duplicate(),
	}


func _judge_fusion() -> Array:
	## 세 심사자(Rule·Neural·JEV)를 실제 플레이 경로에서 돌린다.
	## JEV 문맥은 지금 층의 바이옴에서 나온다 — 필드에서도 "이 세계에 어울리는 기술"만 태어난다.
	if _ai.is_empty() or heroes.is_empty():
		return []
	var catalog: Array = _ai.get("catalog", {}).get("skills", _ai.get("catalog", []))
	var legacy: Array = _ai.get("legacy_pairs", {}).get("pairs", [])
	return FonsFusion.run_for_party(heroes, FonsFusion.place_context(_biomes, floor), catalog, legacy)


func _open_field() -> void:
	explore = FonsExplore.new()
	explore.start(_monsters, _biomes, floor, _seed)
	_rng.seed = _seed * 31 + floor


func _make_party() -> Array:
	return FonsRunState.heroes_from(_races, _job_tree, _equipment, 5, 130, _seed,
		_job_coef, 0, PARTY_SIZE, _ai)


func _update_winner() -> void:
	if party_alive() == 0:
		winner = "enemy"
	else:
		winner = ""
