class_name FonsDay
extends RefCounted
## 하루 — **아침 영지 → 낮 탐험 → 저녁 회복**. 전투만 세던 것을 하루 전체로 넓힌다.
##
## 왜 필요한가
## ----------
## Phase 2.10 의 각인 측정은 **전투만** 돌았다. 그래서 태그가 공격·기동에 쏠리고
## "생활직이 생활을 해서 기술을 깨우친다"는 09 §1 의 전제가 비어 있었다.
## 이 파일이 영지의 일과와 탐험의 걷기·발견을 같은 카운터에 붙여, 하루가 통째로
## 각인 재료가 되게 한다.
##
## 순서는 정본의 재판정 주기를 따른다 (09 §4-1 "영지 = 현재 행동 완료 시 재판정")
## ------------------------------------------------------------------------
##   아침  영웅마다 일 하나 (`FonsEstate.shift`) — 생산·지식·사회 태그
##   낮    조우 지점까지 걷고 싸운다 (`FonsExplore.walk_to`·`fight`) — 기동·지식·공격 태그
##   저녁  살아 있는 영웅이 회복 행동 하나 (`FonsEstate.recover`) — 회복 태그
## 하루에 영웅당 일 1 · 구간 1~3 · 회복 1 이다. 턴 수로 세지 않는 이유: 생활 행동에는
## 턴이 없고, 프레임마다 세면 걷기가 모든 태그를 덮는다 (행동의 단위 = 의미 있는 한 걸음).
##
## 하루의 경계
## -----------
## 이 클래스는 **한 층의 하루**다. 다음 날은 새 `FonsDay` 이고, 파티는 `renew` 로 만전에서
## 시작한다 — 세이브가 없으므로 "숙박으로 회복했다"를 수치로 주장하지 않는다.
## 뷰 배선은 Phase 3 이다 (지금은 헤드리스 시뮬·측정만).

var floor := 1
var estate: FonsEstate = null
var explore: FonsExplore = null
var log_lines: Array = []
var born: Array = []

var _rng := RandomNumberGenerator.new()


func start(estate_data: Dictionary, monsters: Variant, biomes: Variant,
		floor_value: int = 1, seed_value: int = 0) -> void:
	floor = maxi(1, floor_value)
	_rng.seed = seed_value * 31 + floor
	estate = FonsEstate.new()
	estate.start(estate_data, floor, _rng)
	explore = FonsExplore.new()
	explore.start(monsters, biomes, floor, seed_value)
	log_lines = []
	born = []


func run(heroes: Array, with_life: bool = true, now: int = 0) -> Dictionary:
	## `with_life=false` 는 **탐험만** 도는 대조군이다 (영지·저녁 없음).
	## 전투만 도는 대조군은 부르는 쪽이 `FonsFloorRun` 으로 따로 돌린다.
	## `now` 는 시계 주입이다 — 0 이면 기기 시각. 정산 검사가 가짜 시계를 쓴다.
	log_lines = []
	born = []
	if with_life:
		# 섬일 정산 — 여러 층 하루가 같은 섬일에 들어도 한 번만 돈다 (`FonsIslandClock.tick`).
		# 수지 줄은 영지 로그에 붙으므로, 표시를 먼저 찍고 그 뒤를 그대로 가져온다.
		var settle_mark := estate.log_lines.size()
		estate.settle(now)
		_append(estate.log_lines, settle_mark)
		var mark := estate.log_lines.size()
		var shift := estate.shift(heroes)
		_append(estate.log_lines, mark)
		born.append_array(shift["born"])

	var turns := 0
	for i in explore.sites.size():
		if bool(explore.sites[i]["cleared"]):
			continue
		var move := explore.walk_to(i, heroes)
		log_lines.append_array(move["log"])
		var out := explore.fight(i, heroes, _rng)
		log_lines.append_array(out["log"])
		turns += int(out["turns"])
		if String(out["winner"]) != "ally":
			# 진 채로 다음 지점으로 가면 그건 하루가 아니라 무한 재도전이다.
			# 후퇴해서 하루를 닫는다 — 지운 조우는 남는다 (D-265).
			var back := explore.retreat(heroes)
			log_lines.append_array(back["log"])
			break

	if with_life:
		var mark2 := estate.log_lines.size()
		estate.recover(heroes)
		_append(estate.log_lines, mark2)

	var winner := "draw"
	if explore.mission_done():
		winner = "ally"
	elif _alive(heroes) == 0:
		winner = "enemy"
	return {
		"floor": floor,
		"winner": winner,
		"cleared": explore.cleared,
		"required": explore.required,
		"turns": turns,
		"born": born.duplicate(),
		"stores": estate.stores.duplicate(),
		"log": log_lines.duplicate(),
	}


static func renew(heroes: Array) -> void:
	## 새 날은 만전에서 시작한다 — 층 사이 회복 규칙이 생기면 이 함수가 그 자리를 대신한다.
	## (지금은 측정 장치다: 하루를 여러 번 돌리려면 HP 가 이어지면 안 된다)
	for hero in heroes:
		hero["hp"] = int(hero.get("maxHp", 0))
		hero["alive"] = true


func _append(lines: Array, from: int) -> void:
	log_lines.append_array(lines.slice(from))


static func _alive(units: Array) -> int:
	var n := 0
	for unit in units:
		if bool(unit.get("alive", false)):
			n += 1
	return n
