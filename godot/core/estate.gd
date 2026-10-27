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
##   팀     `gathering.base_yield` × `floor_multiplier_formula`(1+floor/50) × 팀 수
##   개인   팀 수확 ÷ `gathering.team_size`(4) — 영웅이 일 하나를 고를 때 받는 몫
## 팀 수 = 소환제단 레벨 (`max_teams_by_altar_level`). 팀 배치·쿨다운·숙련도 티어는 아직 없다
## (ponytail: 배치 화면과 티어 데이터가 붙을 때).
##
## 섬일 수지 — 세금 · 식량 소비 · 인구증가 · 유지비 (04 §3.2·§3.4·§3.12)
## ------------------------------------------------------------------
## 정산은 `settle()` 한 번이다. 수치는 전부 `estate.json` 에서 읽는다:
##   세금    `tax.gold_per_pop_per_island_day` × 인구
##   식량    `food.consumption_per_pop_per_island_day` × 인구
##   인구    `population.natural_growth_rate_per_island_day` × 계절 `natural_growth_mul`, 상한은 스테이지
##   유지비  `maintenance_gold_per_level_per_island_day` × 가동 시설 레벨 합
## 지금 건설·업글이 없으므로 가동 시설 = `initial_level > 0` 인 시설뿐이다. 값을 지어내지 않는다.
## 인구 상한은 S1 고정이다 — 섬 확장(expansion_cost)이 아직 없어 스테이지를 올릴 수 없다.
## 침상 상한(주택 1동 +20)은 주택 상태가 붙을 때 `population_cap()` 에 min 으로 더한다:
## 초기 S1 은 스테이지 60 = 침상 60 이라 지금 차이가 없다.
##
## 일과가 정산에 붙는 자리 (2026-10-25)
## --------------------------------
## `settle(now, gold, workers)` 가 하루치 정산 **전에** 그날의 생산을 돌린다.
## 순서가 핵심이다 — 소비가 먼저면 첫날부터 식량이 모자라 3일째에 아사가 나고,
## 수확이 먼저면 그날 번 만큼 먹고 남는다. 하루의 순서는 생산 → 소비 (04 §3.13).
## 미접속으로 건너뛴 날은 `FonsIslandClock.tick` 이 정산을 내지 않으므로 생산도 돌지 않는다.
##
## 생산은 두 길이다
## ---------------
##   채집팀  `harvest()` — 팀 하나가 섬 하루 1회, `base_yield` × 층 배율 (04 §3.3).
##          팀수 = 소환제단 레벨(초기 1팀 = 4인). 이것이 정본의 식량 기둥이다.
##   영웅    `shift()` — 일 하나를 골라 그 몫(`share`)을 받고, 태그가 스킬이 된다.
## 채집팀을 따로 두는 이유: 필드 파티는 전투 인원이고 배치 주민은 별개다 (00 #70 —
## 초기 배치 5 = 운영 1 + 채집 4). 영웅의 자유 선택만으로는 곡물이 고르게 나오지 않아
## (성격 소프트맥스) 식량이 영원히 0 이 되었다 — 2026-10-25 실측.
##
## 민심 · 아사 (04 §3.4·§3.5·§3.14) — 두 주기를 가른다
## -------------------------------------------------
##   아사   섬일 정산 — 식량이 모자란 날이 3일 이어지면 그날부터 인구 -2%/섬일
##   민심   층 클리어 — 식량이 바닥이면 -5/층. 정산(섬일)이 아니라 층 단위인 이유는
##          정본이 두 주기를 명시적으로 분리했기 때문이다 (§3.4 "민심 -5는 층 클리어 시")
##   겨울   계절이 바뀌는 날 `morale_delta` 만큼 한 번 (estate.json)
##   효과   채집 수확 ×(1 + (민심-50)/50 × 0.20) — 04 §3.5 수치화식
## 파업 — 민심이 `strike_below`(20) 미만인 층이 `strike_after_floors`(3) 이어지면
## 전 생산 정지 `strike_floors`(5)층 (04 §3.5·§3.12·§3.14). 주기는 섬일이 아니라 **층**이다 —
## 시작도 카운트다운도 `note_floor_cleared()` 가 센다. 파업 중에는 채집팀·영웅 일과가
## 모두 멈추고(수확 0), 정산은 그대로 돌아 식량이 줄어든다.
## 파업을 겪은 뒤 식량이 남아 있으면 층마다 민심 +5 (04 §3.14 "파업 후 식량흑자 시 +5/층").
## 회복은 **기준 민심(`morale.initial`)** 에서 멈춘다 — 파업의 구제이지 상시 상승이 아니다.
## 식량이 바닥이면 돌지 않는다 — 그 층은 -5 가 먼저다.
##
## 파업 조기 종료 — 식량 흑자 + 칙령 (04 §3.12·§3.7)
## ------------------------------------------
## 5층을 기다리지 않고 끝내는 길이다. 조건은 둘이다: 하루치 식량이 남아 있을 것,
## 칙령이 열려 있을 것(10층). 칙령은 1슬롯이고 값은 `decrees.list` 가 준다.
## 3종 전부 된다 — 중상주의(세금 ×1.3 · 민심 -15) · 분배주의(민심 +15 · 세금 ×0.8 ·
## 자연증가 ×1.5) · 채집장려(채집 ×1.2 · 민심 -5). 수치는 04 §3.7 표 그대로다.
## 교체는 언제든 되지만 같은 칙령을 다시 켜지는 않는다 — 민심 델타가 두 번 붙으면 수치가 부푼다.
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

## 수확 표시 이름 — 화면 로그 전용. 자원 id(`food`…)는 데이터가 정하고 이 표는 읽기용이다.
const ITEM_NAMES := {"food": "식량", "herb": "약초", "wood": "목재", "ore": "광석"}
## 칙령 칸 상한 — 데이터가 더 큰 값을 줘도 저장 배열과 화면은 둘까지다 (ADR 0011).
const MAX_SLOTS := 2

## 런 층의 파생값 — 저장하지 않고 `main` 이 필드 층에서 맞춘다 (ADR 0008).
## 수확 배율(`1+floor/50`)과 칙령 10층 해금이 이 값을 읽는다.
var floor := 1
## 수확 누적 — `food`·`herb`·`wood`·`ore`. 소비는 섬일 정산이 한다.
var stores := {}
## 주민 수. 자연증가는 비율이라 소수로 들고 있는다 (표시·징수는 정수로 반올림).
var population := 0.0
## 민심 0~100 (50 시작). 채집 수확에 걸린다.
var morale := 50
## 연속으로 식량이 모자란 섬일 수 — 3일째부터 아사.
var shortage_days := 0
## 섬일 시계 — 세이브가 함께 적는 기준점 둘 (설계 §4). 날짜 자체는 `FonsIslandClock` 이 계산한다.
var clock_epoch := 0
var last_settled_day := 1
var log_lines: Array = []

var _gathering: Dictionary = {}
## 소환제단 레벨 — 채집팀 수를 정한다 (Lv1 = 1팀).
var _altar_level := 0
var _population_rules: Dictionary = {}
var _food_rules: Dictionary = {}
var _tax_rules: Dictionary = {}
var _maintenance_per_level := 0
var _stage_caps: Array = []
var _seasons: Array = []
var _morale_rules: Dictionary = {}
var _unrest_rules: Dictionary = {}
var _decrees: Dictionary = {}
var _decree_slots: Array = []
var _change_cooldown := 0
## 켜진 칙령 id — 칸 순서대로. 30층 미만에서는 `slot_count()` 가 1이라 2번 칸은 쉰다.
var decree_ids: Array = ["", ""]
## 마지막 교체 층 — 5층 쿨다운 (ADR 0011). 0 이면 아직 바꾼 적 없다.
var last_change_floor := 0
var _facility_levels := 0
## 파업 잔여 층과 민심 미달 연속 층 — 둘 다 층 단위다 (04 §3.14).
var strike_floors_left := 0
var unrest_floors := 0
## 파업을 겪었는가 — 끝난 뒤 식량 흑자로 민심을 되돌리는 동안만 true (04 §3.14).
var recovering := false
var _rng: RandomNumberGenerator = null


func start(estate_data: Dictionary, floor_value: int, rng: RandomNumberGenerator = null) -> void:
	floor = maxi(1, floor_value)
	_gathering = estate_data.get("gathering", {})
	_population_rules = estate_data.get("population", {})
	_food_rules = estate_data.get("food", {})
	_tax_rules = estate_data.get("tax", {})
	_morale_rules = estate_data.get("morale", {})
	_unrest_rules = estate_data.get("morale_unrest", {})
	_decrees = estate_data.get("decrees", {})
	_decree_slots = _decrees.get("slot_count_by_floor", [])
	_change_cooldown = maxi(0, int(_decrees.get("change_cooldown_floors", 0)))
	_maintenance_per_level = int(estate_data.get("maintenance_gold_per_level_per_island_day", 0))
	_stage_caps = _population_rules.get("max_by_stage", [])
	_seasons = estate_data.get("farming", {}).get("seasons", [])
	_facility_levels = 0
	_altar_level = 0
	for facility in estate_data.get("facilities", []):
		# 건설이 없으므로 "가동 중" = 데이터가 초기 레벨을 준 시설이다 (00 #70 — 소환제단 1).
		var level := int(facility.get("initial_level", 0))
		_facility_levels += level
		if String(facility.get("id", "")) == "summon_altar":
			_altar_level = level
	_rng = rng
	stores = {"food": 0, "herb": 0, "wood": 0, "ore": 0}
	population = float(_population_rules.get("initial", 0))
	morale = clampi(int(_morale_rules.get("initial", 50)), _morale_min(), _morale_max())
	shortage_days = 0
	strike_floors_left = 0
	unrest_floors = 0
	recovering = false
	decree_ids = _empty_decree_slots()
	last_change_floor = 0
	log_lines = []
	clock_epoch = int(Time.get_unix_time_from_system())
	last_settled_day = 1


func settle(now: int = 0, gold: int = -1, workers: Array = []) -> Dictionary:
	## 섬일 정산 — 접속 중 하루 한 번, 밀린 날은 건너뛴다 (`FonsIslandClock.tick`).
	## `gold` 는 지갑이다 (`GameState.gold`). 음수면 지갑 없이 도는 시뮬 — 세금·유지비는 계산해
	## 보고만 하고 잔고는 건드리지 않는다. 지갑을 이 클래스가 들지 않는 이유는 세이브·화면이
	## 지갑의 주인이기 때문이다 (core 는 노드·오토로드를 모른다).
	## `workers` 는 그날 영지에서 일할 영웅들이다 (보통 `FonsFieldState.heroes`). 비어 있으면
	## 일과를 건너뛴다 — 헤드리스 시뮬·단위 검사가 정산만 볼 수 있어야 한다.
	var stamp := now if now > 0 else int(Time.get_unix_time_from_system())
	if clock_epoch <= 0:
		clock_epoch = stamp
		last_settled_day = 1
	var result := FonsIslandClock.tick(clock_epoch, stamp, last_settled_day)
	last_settled_day = int(result["last_settled_day"])
	result["tax"] = 0
	result["maintenance"] = 0
	result["food_eaten"] = 0
	result["food_short"] = 0
	result["starved"] = 0.0
	result["morale"] = morale
	result["morale_delta"] = 0
	result["shortage_days"] = shortage_days
	result["population"] = population
	result["cap"] = population_cap()
	result["gold"] = gold
	result["unpaid"] = 0
	result["log"] = []
	result["work"] = {}
	result["harvest"] = {}
	if bool(result["settle"]):
		var work_line := ""
		var held := stores.duplicate()
		if is_striking():
			work_line = "파업 중 — 생산 없음"
		else:
			result["harvest"] = harvest()
			if not workers.is_empty():
				result["work"] = shift(workers)
			work_line = _gained_line(held)
		_settle_day(int(result["day"]), gold, result, work_line)
	return result


func team_count() -> int:
	## 채집팀 수 — 소환제단 레벨 표(`max_teams_by_altar_level`)를 그대로 읽는다 (04 §3.10).
	var table: Array = _gathering.get("max_teams_by_altar_level", [])
	if table.is_empty() or _altar_level <= 0:
		return 0
	return int(table[clampi(_altar_level - 1, 0, table.size() - 1)])


func harvest() -> Dictionary:
	## 채집팀의 하루 수확 — 팀 수 × `base_yield` × 층 배율 × 민심 배율 (04 §3.3·§3.5).
	## 팀 배치·특성 티어·계절 배율은 아직 없다 (배치 화면과 티어 데이터가 붙을 때).
	if is_striking():
		return {}   # 파업 — 전 생산 정지 (04 §3.5)
	var teams := team_count()
	if teams <= 0:
		return {}
	var mult := multiplier() * morale_multiplier() * _decree_mul("harvest_mul")
	var gained := {}
	var base: Dictionary = _gathering.get("base_yield", {})
	for item in base:
		var amount := int(round(float(base[item]) * float(teams) * mult))
		if amount == 0:
			continue
		stores[item] = int(stores.get(item, 0)) + amount
		gained[item] = amount
	return gained


func _gained_line(held: Dictionary) -> String:
	## 그날 일과가 실제로 늘린 것만 적는다. 0 인 항목을 늘어놓으면 로그가 소음이 된다.
	var gained: Array = []
	for item in stores:
		var delta := int(stores[item]) - int(held.get(item, 0))
		if delta != 0:
			gained.append("%s +%d" % [String(ITEM_NAMES.get(item, item)), delta])
	return "" if gained.is_empty() else "일과 — " + " · ".join(gained)


func _settle_day(day: int, gold: int, result: Dictionary, work_line: String = "") -> void:
	## 하루치 수지. 순서: 세금 → 유지비 → 식량 → 인구 → 아사 → 민심.
	## 인구는 그날의 계절 배율을 받고, 아사는 3일째부터 그 위에 곱해진다.
	## 상한을 넘긴 성장 시도분은 분배주의가 골드로 바꾼다 (ADR 0012).
	var cap := population_cap()
	if cap > 0 and population > float(cap):
		population = float(cap)   # 예전·손상 세이브가 상한을 넘겨 있으면 먼저 자른다
	var residents := roundi(population)
	var tax := roundi(residents * float(_tax_rules.get("gold_per_pop_per_island_day", 0))
		* _decree_mul("tax_mul"))
	var upkeep := roundi(_facility_levels * float(_maintenance_per_level))

	var need := _day_food_need()
	var held := int(stores.get("food", 0))
	var eaten := mini(need, held)
	stores["food"] = held - eaten
	var short := need - eaten

	var season := FonsIslandClock.season_of(day, _seasons)
	var rate := float(_population_rules.get("natural_growth_rate_per_island_day", 0.0)) \
		* float(season.get("natural_growth_mul", 1.0)) * _decree_mul("natural_growth_mul")
	var before := population
	var overflow := 0.0
	if cap > 0:
		var raw := population + population * rate
		if raw > float(cap):
			overflow = raw - float(cap)
			population = float(cap)
		else:
			population = raw
	var overflow_gold := roundi(overflow * _decree_overflow_gold_per_pop())

	# 아사 — 연속 부족일이 기준을 넘으면 그날부터 인구가 준다 (04 §3.14).
	var starved := 0.0
	if short > 0:
		shortage_days += 1
		if shortage_days >= int(_food_rules.get("starvation_after_island_days", 3)):
			starved = population * float(_food_rules.get("starvation_pop_loss_pct", 0.0))
			population = maxf(0.0, population - starved)
	else:
		shortage_days = 0

	# 민심 — 계절이 바뀌는 날 한 번 `morale_delta` (겨울 -5).
	var morale_before := morale
	var prev_season := FonsIslandClock.season_of(day - 1, _seasons)
	if String(prev_season.get("id", "")) != String(season.get("id", "")) and season.has("morale_delta"):
		morale = clampi(morale + int(season["morale_delta"]), _morale_min(), _morale_max())

	var after := gold
	var unpaid := 0
	if gold >= 0:
		after = gold + tax + overflow_gold - upkeep
		if after < 0:
			unpaid = -after
			after = 0

	result["tax"] = tax
	result["maintenance"] = upkeep
	result["food_eaten"] = eaten
	result["food_short"] = short
	result["starved"] = starved
	result["morale"] = morale
	result["morale_delta"] = morale - morale_before
	result["shortage_days"] = shortage_days
	result["population"] = population
	result["cap"] = cap
	result["overflow"] = overflow
	result["overflow_gold"] = overflow_gold
	result["gold"] = after
	result["unpaid"] = unpaid

	var lines: Array = ["섬 %d일" % day]
	if not work_line.is_empty():
		lines.append(work_line)
	if tax != 0 or upkeep != 0:
		lines.append("세금 +%dG · 유지비 -%dG" % [tax, upkeep])
	if overflow_gold != 0:
		lines.append("상한 초과 +%dG" % overflow_gold)
	if need > 0:
		lines.append("식량 -%d · 남은 %d" % [eaten, int(stores["food"])])
	if short > 0:
		lines.append("식량 %d 모자람" % short)
	if unpaid > 0:
		lines.append("유지비 %dG 모자람" % unpaid)
	if roundi(population) != roundi(before):
		lines.append("인구 %d → %d" % [roundi(before), roundi(population)])
	if starved >= 0.5:
		lines.append("아사 — 인구 -%d" % roundi(starved))
	if morale != morale_before:
		lines.append("민심 %d → %d" % [morale_before, morale])
	result["log"] = lines
	log_lines.append_array(lines)


func note_floor_cleared() -> Dictionary:
	## 층 클리어 — 식량이 바닥이면 민심 -5 (04 §3.14 "식량 0: 즉시 민심 -5/층").
	## 정산이 아니라 층 단위인 이유: 04 §3.4 가 민심(층)과 아사(섬일) 주기를 나눠 두었다.
	## 파업도 같은 주기라 여기서 센다 — 민심을 깎은 뒤에 판정해야 그 층이 반영된다.
	var before := morale
	if int(stores.get("food", 0)) <= 0:
		morale = clampi(morale + int(_food_rules.get("shortage_morale_per_floor", 0)),
			_morale_min(), _morale_max())
	elif recovering and strike_floors_left == 0:
		# 식량 흑자 — 파업을 겪은 뒤에만 회복한다 (04 §3.14). 파업 중에 오르면 정지가 무의미해진다.
		if morale < _morale_base():
			morale = mini(_morale_base(), morale + int(_morale_rules.get("recovery_per_floor", 0)))
		if morale >= _morale_base():
			recovering = false   # 기준 민심까지 돌아왔으면 상시 상승은 멈춘다
	var strike_before := strike_floors_left
	_advance_strike()
	return {
		"morale": morale,
		"delta": morale - before,
		"strike": strike_floors_left,
		"strike_started": strike_floors_left > 0 and strike_before == 0,
		"strike_ended": strike_before > 0 and strike_floors_left == 0,
	}


func _advance_strike() -> void:
	## 층 하나가 지났다. 파업 중이면 남은 층을 줄이고, 아니면 민심 미달 층을 센다.
	if strike_floors_left > 0:
		strike_floors_left -= 1
		if strike_floors_left == 0:
			unrest_floors = 0
		return
	if morale < int(_unrest_rules.get("strike_below", 20)):
		unrest_floors += 1
		if unrest_floors >= int(_unrest_rules.get("strike_after_floors", 3)):
			strike_floors_left = int(_unrest_rules.get("strike_floors", 5))
			unrest_floors = 0
			recovering = true
	else:
		unrest_floors = 0


func is_striking() -> bool:
	return strike_floors_left > 0


func decrees() -> Array:
	## 칙령 목록 (04 §3.7). 세 종 모두 데이터가 정한다 — 없는 종을 여기서 만들지 않는다.
	return (_decrees.get("list", []) as Array).duplicate(true)


func decree() -> Dictionary:
	## 첫 번째 켜진 칙령. 없으면 빈 사전 — 1슬롯 시절 호출 호환.
	var ids := active_decree_ids()
	return _decree_by_id(String(ids[0])) if not ids.is_empty() else {}


func slot_count() -> int:
	## 칸 수 — `decrees.slot_count_by_floor` 의 층 임계값 표를 그대로 읽는다 (ADR 0011).
	var count := 1
	for entry in _decree_slots:
		if floor >= int(entry.get("min_floor", 1)):
			count = int(entry.get("slots", count))
	return clampi(count, 1, MAX_SLOTS)


func active_decree_ids() -> Array:
	## 지금 효과를 내는 칸의 id 만 — 30층 미만이면 2번 칸이 빠진다.
	var out: Array = []
	for i in slot_count():
		var id := String(decree_ids[i])
		if not id.is_empty():
			out.append(id)
	return out


func slot_ids() -> Array:
	## 칸 순서 그대로 — 빈 칸은 "" 로 남긴다. 화면이 인덱스를 칸 번호로 읽는다 (ADR 0011).
	## `active_decree_ids()` 처럼 빈 칸을 건너뛰면 2번 칸만 켰을 때 1번으로 보인다.
	var out: Array = []
	for i in slot_count():
		out.append(String(decree_ids[i]))
	return out


func active_decrees() -> Array:
	## 켜진 칙령 사전들 — 화면·HUD 가 읽는다.
	var out: Array = []
	for id in active_decree_ids():
		var entry := _decree_by_id(id)
		if not entry.is_empty():
			out.append(entry)
	return out


func decree_name(id: String) -> String:
	if id.is_empty():
		return ""
	var entry := _decree_by_id(id)
	return String(entry.get("name_ko", id)) if not entry.is_empty() else id


func cooldown_left() -> int:
	## 남은 교체 쿨다운(층). 파업 중이어도 값은 그대로 — 허용 여부는 `can_set_decree` 가 가른다.
	if _change_cooldown <= 0 or last_change_floor <= 0 or floor < last_change_floor:
		return 0
	return maxi(0, last_change_floor + _change_cooldown - floor)


func reset_decree_cooldown() -> void:
	## 재시작처럼 층이 뒤로 돌아갈 때 — 쿨다운 기준도 새 런에 맞춘다 (ADR 0011).
	last_change_floor = 0


func can_set_decree(decree_id_value: String = "", slot: int = -1) -> Dictionary:
	## 칙령 교체 조건 — 10층 해금(04 §3.7), 칸 수(ADR 0011), 5층 쿨다운,
	## 파업 중이면 하루치 식량(04 §3.12). 안 되면 이유를 돌려준다 — 화면이 그대로 보여 준다.
	if _decrees.get("list", []).is_empty():
		return {"ok": false, "reason": "칙령이 없다"}
	var unlock := int(_decrees.get("unlock_floor", 1))
	if floor < unlock:
		return {"ok": false, "reason": "%d층에 열립니다" % unlock}
	if not decree_id_value.is_empty() and _decree_by_id(decree_id_value).is_empty():
		return {"ok": false, "reason": "칙령이 없다"}
	if slot >= 0:
		if slot >= slot_count():
			return {"ok": false, "reason": "%d층부터 %d번 칸" % [_slot_unlock_floor(slot), slot + 1]}
		var current := String(decree_ids[slot])
		if not decree_id_value.is_empty() and current == decree_id_value:
			return {"ok": false, "reason": "이미 %s 다" % decree_name(current)}
	# 쉬는 2번 칸도 검사한다 — 30층 아래에서 숨은 칙령을 1번 칸에 또 넣으면
	# 30층에서 같은 칙령이 두 칸에 켜진다 (ADR 0011). 쉬는 칸은 화면에 안 보이므로
	# «이미» 대신 어느 칸에 있고 언제 다시 켜지는지 말한다.
	var held_slot := decree_ids.find(decree_id_value)
	if not decree_id_value.is_empty() and held_slot >= 0:
		if held_slot >= slot_count():
			return {"ok": false,
				"reason": "%d번 칸에 있다 — %d층부터 다시 켜진다" % [held_slot + 1, _slot_unlock_floor(held_slot)]}
		return {"ok": false, "reason": "이미 %s 다" % decree_name(decree_id_value)}
	if cooldown_left() > 0 and not is_striking():
		return {"ok": false, "reason": "%d층 뒤에 바꿀 수 있다" % cooldown_left()}
	if is_striking():
		var need := _day_food_need() * maxi(1, int(_unrest_rules.get("early_end_food_days", 1)))
		var held := int(stores.get("food", 0))
		if held < need:
			return {"ok": false, "reason": "식량 %d 모자람" % (need - held)}
	return {"ok": true, "reason": ""}


func set_decree(decree_id_value: String, slot: int = -1) -> Dictionary:
	## 칙령 교체 (04 §3.7). 파업 중이면 교체가 곧 조기 종료다 (04 §3.12).
	## 30층 이상에서는 칸을 반드시 고른다 — 빈 칸이 있어도 자동으로 채우지 않는다 (ADR 0011).
	## `recovering` 을 켜 두는 이유: 04 §3.14 가 파업 뒤 식량 흑자 회복(+5/층)을 묶어 두었다.
	if decree_id_value.is_empty():
		return {"ok": false, "reason": "칙령이 없다"}
	var target := slot
	if target < 0:
		if slot_count() <= 1:
			target = 0
		else:
			return {"ok": false, "reason": "칸을 골라야 한다"}
	var gate := can_set_decree(decree_id_value, target)
	if not bool(gate["ok"]):
		return gate
	var pick := _decree_by_id(decree_id_value)
	if pick.is_empty():
		return {"ok": false, "reason": "칙령이 없다"}
	var id := String(pick.get("id", ""))
	var ended := is_striking()
	decree_ids[target] = id
	last_change_floor = floor
	morale = clampi(morale + int(pick.get("morale_delta", 0)), _morale_min(), _morale_max())
	if ended:
		strike_floors_left = 0
		unrest_floors = 0
		recovering = true
	var line := "칙령 %s" % String(pick.get("name_ko", id))
	if slot_count() > 1:
		line += " — %d번 칸" % (target + 1)
	if ended:
		line += " — 파업 종료"
	log_lines.append(line)
	return {"ok": true, "reason": "", "decree": pick, "slot": target,
		"decrees": decree_ids.duplicate(), "morale": morale,
		"ended_strike": ended, "line": line}


func _decree_by_id(id: String) -> Dictionary:
	## 빈 id 는 첫 칙령을 뜻한다 — 조기 종료는 "바꾸기"라 기본값이 있어야 한다.
	var list: Array = _decrees.get("list", [])
	if list.is_empty():
		return {}
	if id.is_empty():
		return list[0]
	for entry in list:
		if String(entry.get("id", "")) == id:
			return entry
	return {}


func _decree_mul(key: String) -> float:
	## 칙령 배율 — 켜진 칸을 모두 곱한다. 없으면 1.0. 값을 코드에 적지 않고 `decrees.list` 에서 읽는다.
	var mul := 1.0
	for entry in active_decrees():
		mul *= float(entry.get(key, 1.0))
	return mul


func _decree_overflow_gold_per_pop() -> float:
	## 상한 초과 1명당 골드 — 분배주의만 이 키를 갖는다 (ADR 0012).
	## 합으로 둔 이유: 나중에 다른 칙령이 같은 키를 주면 자연스럽게 더해진다.
	var total := 0.0
	for entry in active_decrees():
		total += float(entry.get("overflow_gold_per_pop", 0.0))
	return total


func _empty_decree_slots() -> Array:
	var out: Array = []
	for i in MAX_SLOTS:
		out.append("")
	return out


func _slot_unlock_floor(slot_index: int) -> int:
	## 그 칸이 열리는 첫 층 — 데이터 표에서 찾는다. 없으면 해금 층.
	var need := slot_index + 1
	for entry in _decree_slots:
		if int(entry.get("slots", 1)) >= need:
			return int(entry.get("min_floor", 1))
	return int(_decrees.get("unlock_floor", 1))


func _day_food_need() -> int:
	## 하루치 식량 소비 — 주민 수(정수 표시 기준) × 1인분 (04 §3.2).
	return roundi(float(roundi(population))
		* float(_food_rules.get("consumption_per_pop_per_island_day", 0)))


func unrest() -> Dictionary:
	## 불만 게이지 (04 §3.5·§3.12) — 민심 25 미만이면 뜨고 15 이하면 경고.
	## 게이지가 세는 것은 파업 직전 연속 층(`unrest_floors`)이다 — 표시와 규칙이 같은 수를 쓴다.
	## 파업 중에는 감춘다: HUD 가 남은 파업 층을 따로 말하므로 같은 사실을 두 번 말하지 않는다.
	var enter := int(_unrest_rules.get("enter_below", 25))
	var need := maxi(1, int(_unrest_rules.get("strike_after_floors", 3)))
	return {
		"visible": morale < enter and not is_striking(),
		"warn": morale <= int(_unrest_rules.get("warn_below", 15)),
		"floors": mini(unrest_floors, need),
		"need": need,
		"striking": is_striking(),
	}


func morale_multiplier() -> float:
	## (민심-50) ÷ 50 × 0.20 — 04 §3.5 수치화식. 50 이면 1.0, 0 이면 0.8.
	var base := float(_morale_rules.get("initial", 50))
	var span := float(_morale_rules.get("max", 100)) - base
	if span <= 0.0:
		return 1.0
	return 1.0 + (float(morale) - base) / span \
		* float(_morale_rules.get("production_bonus_factor", 0.0))


func _morale_base() -> int:
	## 기준 민심 — 파업 회복이 멈추는 선 (estate.json `morale.initial`).
	return int(_morale_rules.get("initial", 50))


func _morale_min() -> int:
	return int(_morale_rules.get("min", 0))


func _morale_max() -> int:
	return int(_morale_rules.get("max", 100))


func population_cap() -> int:
	## 스테이지 상한 (04 §3.2 — S1 60). 확장이 아직 없으므로 첫 스테이지에 머문다.
	if not _stage_caps.is_empty():
		return int(_stage_caps[0])
	return 0


func to_save() -> Dictionary:
	return {
		"clock_epoch": clock_epoch,
		"last_settled_day": last_settled_day,
		"stores": stores.duplicate(),
		"population": population,
		"morale": morale,
		"shortage_days": shortage_days,
		"strike_floors_left": strike_floors_left,
		"unrest_floors": unrest_floors,
		"recovering": recovering,
		"decrees": decree_ids.duplicate(),
		"last_change_floor": last_change_floor,
	}


func from_save(saved: Dictionary, now: int = 0) -> void:
	## 기준점이 없는 예전 세이브는 **지금**을 기준점으로 삼는다 — 필드 추가는 마이그레이션이 아니다
	## (ADR 0008 부수 결정). 밀린 날을 세어 주지 않는 것은 그 값을 모르기 때문이다.
	var stamp := now if now > 0 else int(Time.get_unix_time_from_system())
	clock_epoch = int(saved.get("clock_epoch", stamp))
	last_settled_day = maxi(1, int(saved.get("last_settled_day",
		FonsIslandClock.day_at(clock_epoch, stamp))))
	population = float(saved.get("population", population))
	morale = clampi(int(saved.get("morale", morale)), _morale_min(), _morale_max())
	shortage_days = maxi(0, int(saved.get("shortage_days", shortage_days)))
	strike_floors_left = maxi(0, int(saved.get("strike_floors_left", strike_floors_left)))
	unrest_floors = maxi(0, int(saved.get("unrest_floors", unrest_floors)))
	recovering = bool(saved.get("recovering", recovering))
	decree_ids = _empty_decree_slots()
	if saved.get("decrees", null) is Array:
		var saved_ids: Array = saved["decrees"]
		for i in mini(MAX_SLOTS, saved_ids.size()):
			var id := String(saved_ids[i])
			if not id.is_empty() and not _decree_by_id(id).is_empty():
				decree_ids[i] = id
	elif saved.has("decree"):
		var old_id := String(saved["decree"])
		if not old_id.is_empty() and not _decree_by_id(old_id).is_empty():
			decree_ids[0] = old_id
	last_change_floor = maxi(0, int(saved.get("last_change_floor", 0)))
	var saved_stores: Dictionary = saved.get("stores", {})
	for key in stores:
		if saved_stores.has(key):
			stores[key] = int(saved_stores[key])


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
	## 파업 중에는 아무도 나가지 않는다 — 태그도 수확도 없다 (04 §3.5).
	if is_striking():
		return {"born": [], "stores": stores.duplicate()}
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
	return int(round(base * multiplier() / team * morale_multiplier() * _decree_mul("harvest_mul")))


func multiplier() -> float:
	return 1.0 + float(floor) / 50.0


func snapshot() -> Dictionary:
	return {
		"floor": floor,
		"stores": stores.duplicate(),
		"population": roundi(population),
		"morale": morale,
		"log": log_lines.slice(maxi(0, log_lines.size() - 6)),
		"teams": team_count(),
	}
