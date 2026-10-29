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
const PARTY_SIZE := 5
const LOG_TAIL := 8
## 동료가 따라다니는 범위 — 조종 영웅 중심. 40×28 필드에서 약 2초 거리 (가안, 제안서 §6).
const PARTY_RADIUS := 8.0
const ALLY_SPEED := 3.2
## 동료 사각형은 0.8 단위다 — 1.0 이면 가장자리가 붙어 다섯이 한 덩어리로 보인다.
const ALLY_MIN_DIST := 1.4
## 동료가 한 행동을 붙잡고 있는 시간 (가안). 제안서 §8의 2주차 조각.
const ALLY_ACTION_SECONDS := 2.5
## 조우 지점 위에 서 있는 판정은 `FonsExplore.contact_index()` 가 진다 (반경 1.5).
## 동료가 같은 반경에 닿으면 위험 신호를 한 번 보낸다 — 오른쪽 칸이 세 번 빛난다 (제안서 §6-3).
const SIGNAL_SECONDS := 1.5
const SIGNAL_HALF := 0.25
## 조우가 보이는 거리 — 이 안의 가장 가까운 지점에 실제 편성을 세운다.
## 접촉 판정(1.5)만 쓰면 이미 코앞이라, "무엇과 싸우는지"를 보고 물러설 틈이 없다.
## 지점 간격이 한 청크에 2~4개라 8 이면 보통 한 곳만 들어온다.
const ENCOUNTER_SIGHT := 8.0
## 미리보기 생물이 지점 둘레에 서는 반경. 지점 판정(1.2)보다 밖이라 발밑을 안 막는다.
const PREVIEW_RADIUS := 2.4

var floor := START_FLOOR
var heroes: Array = []
## 필드 위 다섯 자리. 조종 중인 영웅의 좌표가 곧 `explore.avatar` 다.
var party_pos: Array = []
var controlled := 0
var explore: FonsExplore = null
var log_lines: Array = []
var winner := ""
## 이데아 문턱(126~130)은 일반 조우가 없다 — 문지기 한 체가 그 층의 전투다.
## 격파가 미션 자리를 대신하고, 문지기가 없는 층(129)은 그냥 통과다.
var _combatless := false
var _gatekeeper := {}
var _gatekeeper_cleared := false
## 이미 전리품을 준 층 — 같은 층 재도전으로 무한 파밍을 만들지 않는다 (설계 §5).
## 저장한다: 불러와서 같은 문지기를 또 잡아도 전리품은 안 나온다. 재시작(새 런)하면 비운다.
var _rewarded_floors := {}
## 130층 격파 — 엔딩 조건. 저장한다 (설계 §5 "130 격파 + 엔딩").
var ending := false
## 마지막 문지기 판 — 이름·턴·생존·전리품. 엔딩 화면이 이 숫자를 적는다 (연출 전용).
var last_gatekeeper := {}
## 101층 기억 배분 — 화력 점수 / 생존 점수. 합이 `FonsHeroStats.MEMORY_MAX` 면 나눈 것이다.
## 저장한다: 불러오면 같은 배분으로 영웅을 다시 만든다.
var memory_attack := 0
var memory_guard := 0

var _races: Dictionary = {}
var _monsters: Variant = null
var _biomes: Variant = null
var _job_tree: Dictionary = {}
var _equipment: Dictionary = {}
var _job_coef: Dictionary = {}
var _ai: Dictionary = {}
var _basics: Dictionary = {}
var _seed := 0
var _start_floor := START_FLOOR
var _rng := RandomNumberGenerator.new()
var _ally_targets: Array = []
## 지금 하는 일 — 이동 · 채집 · 휴식. 오른쪽 패널의 행동 글자가 이 값을 그대로 쓴다.
var _ally_state: Array = []
var _ally_timer: Array = []
var _ally_rng: Array = []
## 남은 위험 신호 시간. 0 이면 안 빛난다.
var _ally_signal: Array = []
## 이미 신호를 보낸 조우 — 영웅마다 한 번뿐이다 (같은 조우를 두 번 재촉하지 않는다).
var _ally_signaled: Array = []
## 이미 판단이 끝난 조우 — 한 조우는 한 번만 싸울지 물러날지 정한다.
var _ally_decided: Dictionary = {}
## 교전 준비 중인 조우 — 준비가 끝나면 이 지점을 친다 (분리 밀어내기에 목표를 잃지 않게).
var _ally_battle: Array = []
## 이번 tick 에 화면이 달라졌는가 — 안 움직여도 점멸·행동·전투 결과는 다시 밀어야 한다.
var _changed := false
## 미리보기 편성 캐시 — "층:접촉번호" → 편성. 스냅샷은 걷는 동안 매번 불린다.
var _preview_cache: Dictionary = {}
## 마지막 교전 — 뷰는 `seq` 가 늘어난 순간에만 그 자리에 타격 연출을 낸다.
## 전투는 한 프레임에 끝나므로 "지금 싸우는 중" 대신 "방금 한 판"을 실어 보낸다.
var _strike_seq := 0
var _strike_site := -1
var _strike_damage := 0
## 마지막 일격이 치명타였나 — 뷰가 흔들림 세기를 고르는 기준 (약한 일격 / 강한 일격).
var _strike_heavy := false


func configure(races: Dictionary, monsters: Variant, biomes: Variant,
		seed_value: int = 0, start_floor: int = START_FLOOR,
		job_tree: Dictionary = {}, equipment: Dictionary = {},
		job_coef: Dictionary = {}, ai: Dictionary = {}, basics: Dictionary = {}) -> void:
	## 데이터만 잡아 둔다 — 불러오기는 이 위에 `restore()` 를 얹는다.
	_races = races
	_monsters = monsters
	_biomes = biomes
	_job_tree = job_tree
	_equipment = equipment
	_job_coef = job_coef
	_ai = ai
	_basics = basics
	_seed = seed_value
	_start_floor = clampi(start_floor, START_FLOOR, MAX_FLOOR)
	floor = _start_floor


func start(races: Dictionary, monsters: Variant, biomes: Variant,
		seed_value: int = 0, start_floor: int = START_FLOOR,
		job_tree: Dictionary = {}, equipment: Dictionary = {},
		job_coef: Dictionary = {}, ai: Dictionary = {}, basics: Dictionary = {}) -> void:
	configure(races, monsters, biomes, seed_value, start_floor, job_tree, equipment, job_coef, ai, basics)
	heroes = _make_party()
	_open_field()
	log_lines = []
	winner = ""


func to_save() -> Dictionary:
	## 층·영웅만 낸다. 필드 좌표·조우 배치는 층 시작에서 다시 만들고,
	## 전투 도중은 저장하지 않는다 (설계 §1·§6).
	return {
		"seed": str(_seed),
		"grade": FonsRunState.GRADE,
		"level": FonsRunState.LEVEL,
		"start_floor": _start_floor,
		"floor": floor,
		"heroes": FonsRunState.heroes_to_save(heroes),
		"ending": ending,
		## JSON 이 정수를 float 로 돌려주므로 복원할 때 다시 int 로 읽는다 (설계 §2).
		"rewarded": _rewarded_floors.keys(),
		"memory": {"attack": memory_attack, "guard": memory_guard},
	}


func restore(saved: Dictionary) -> bool:
	## `configure()` 를 먼저 호출해야 한다. 층과 영웅을 되살리고 필드는 그 층 시작으로 연다.
	if saved.is_empty():
		return false
	_seed = int(String(saved.get("seed", "0")))
	_start_floor = clampi(int(saved.get("start_floor", _start_floor)), START_FLOOR, MAX_FLOOR)
	floor = clampi(int(saved.get("floor", _start_floor)), START_FLOOR, MAX_FLOOR)
	heroes = _make_party()
	_restore_memory(saved.get("memory", {}))
	FonsRunState.apply_hero_save(heroes, saved.get("heroes", []))
	_open_field()
	# 저장분이 필드 시작값을 덮는다 — 여기는 "변한 것"이다 (ADR 0008).
	ending = bool(saved.get("ending", false))
	_rewarded_floors.clear()
	for f in saved.get("rewarded", []):
		_rewarded_floors[int(f)] = true
	if ending and floor >= MAX_FLOOR:
		# 이미 넘은 문턱을 다시 세우지 않는다 — 불러오면 격파 상태로 선다.
		_gatekeeper_cleared = true
	log_lines = []
	winner = ""
	return true


func _restore_memory(saved: Variant) -> void:
	## 저장된 배분을 먼저 영웅에게 걸고, 그 다음에 HP 를 되살린다 — 순서를 바꾸면
	## 저장된 HP 가 배분 전 상한으로 잘린다.
	## 배분 키가 없는 예전 세이브는 101층 위에서 5:5 로 되살린다 — 그때의 기본값이고,
	## 지금 기본값은 4:6 이다. 저장된 값을 바꾸지 않고 예전 판만 그대로 따라간다.
	memory_attack = 0
	memory_guard = 0
	if saved is Dictionary:
		memory_attack = clampi(int(saved.get("attack", 0)), 0, FonsHeroStats.MEMORY_MAX)
		memory_guard = clampi(int(saved.get("guard", 0)), 0, FonsHeroStats.MEMORY_MAX)
	if memory_attack + memory_guard < FonsHeroStats.MEMORY_MAX and floor >= FonsRunState.MEMORY_FLOOR:
		memory_attack = 5
		memory_guard = FonsHeroStats.MEMORY_MAX - memory_attack
	FonsRunState.apply_memory_to_party(heroes, memory_attack, memory_guard)


func restart() -> void:
	## 새 런이다 — 첫 격파 기억도 같이 비운다. 엔딩은 기록이라 남긴다.
	floor = _start_floor
	controlled = 0
	_rewarded_floors.clear()
	memory_attack = 0
	memory_guard = 0
	heroes = _make_party()
	_open_field()
	log_lines = []
	winner = ""


func walk(direction: Vector2, seconds: float) -> void:
	if explore == null or not winner.is_empty():
		return
	var walked: Dictionary = explore.walk(direction, seconds)
	if controlled < party_pos.size():
		party_pos[controlled] = explore.avatar
	# 접촉 로그가 방금 늘었을 때만 로그 꼬리를 다시 집는다 — 매 프레임 배열을 새로 만들지 않는다.
	if not Array(walked.get("log", [])).is_empty():
		log_lines = explore.log_lines.slice(maxi(0, explore.log_lines.size() - LOG_TAIL))


func switch_hero(index: int) -> bool:
	## 조종 영웅을 바꾼다 — 범위의 중심만 옮긴다. 성향은 각자 브레인에 남는다.
	## (지피티 브레인스토밍 ④ — 시점 변경이 파티 전체의 성격을 바꾸면 개성이 흔들린다.)
	if index < 0 or index >= party_pos.size() or index == controlled:
		return false
	party_pos[controlled] = explore.avatar
	_ally_state[controlled] = "이동"
	_ally_battle[controlled] = -1
	controlled = index
	_ally_state[index] = "이동"
	_ally_battle[index] = -1
	explore.avatar = party_pos[index]
	for i in party_pos.size():
		if i != controlled:
			_ally_targets[i] = _pick_target(i)
	return true


func tick(seconds: float) -> bool:
	## 동료 4명을 범위 안에서 움직인다. 조종 영웅은 플레이어가 움직이므로 여기서 안 건드린다.
	if explore == null or not winner.is_empty() or party_pos.is_empty():
		return false
	_changed = false
	party_pos[controlled] = explore.avatar
	var center: Vector2 = explore.avatar
	var moved := false
	for i in party_pos.size():
		if i == controlled or not bool(heroes[i].get("alive", false)):
			continue
		_tick_signal(i, maxf(0.0, seconds))
		# 전투에서 죽었을 수 있다 — 시체를 계속 움직이지 않는다.
		if not bool(heroes[i].get("alive", false)):
			continue
		if not winner.is_empty():
			break
		# 하는 일이 있으면 그 자리에 머문다 — 이동만 계속하면 사람이 아니다.
		if String(_ally_state[i]) != "이동":
			_ally_timer[i] = float(_ally_timer[i]) - maxf(0.0, seconds)
			if float(_ally_timer[i]) > 0.0:
				continue
			_finish_ally_action(i)
			if not bool(heroes[i].get("alive", false)) or not winner.is_empty():
				continue
			var drift: Vector2 = party_pos[i] - center
			if drift.length() > PARTY_RADIUS:
				party_pos[i] = center + drift.normalized() * PARTY_RADIUS
			continue
		# 플레이어가 달아나면 옛 목표가 범위 밖이 된다 — 그때 목표를 다시 고른다.
		if party_pos[i].distance_to(center) > PARTY_RADIUS \
				or _ally_targets[i].distance_to(center) > PARTY_RADIUS:
			_ally_targets[i] = _pick_target(i)
		var target: Vector2 = _ally_targets[i]
		if party_pos[i].distance_to(target) < 0.4:
			_start_ally_action(i)
			continue
		var step: Vector2 = target - party_pos[i]
		if step.length() > 0.001:
			party_pos[i] += step.normalized() * minf(step.length(), ALLY_SPEED * maxf(0.0, seconds))
			# 무한맵 — 좌표를 청크 경계로 묶지 않는다. 묶으면 동료가 경계에 붙어 늘어서고
			# 아바타만 넘어가면 파티가 벽에 걸린 것처럼 보인다.
			moved = true
		# 범위는 결과로 강제한다 — 한 걸음이 커도 밖으로 나가지 않는다.
		var off: Vector2 = party_pos[i] - center
		if off.length() > PARTY_RADIUS:
			party_pos[i] = center + off.normalized() * PARTY_RADIUS
	_separate()
	# 분리 밀어내기가 마지막 한 걸음이 될 수 있다 — 범위는 마지막에 다시 잠근다.
	for i in party_pos.size():
		if i == controlled:
			continue
		var back: Vector2 = party_pos[i] - center
		if back.length() > PARTY_RADIUS:
			party_pos[i] = center + back.normalized() * PARTY_RADIUS
	if _alerting():
		_changed = true
	return moved or _changed


func _tick_signal(index: int, seconds: float) -> void:
	## 반경에 닿은 순간 한 번만 신호를 켜고, 시간이 지나면 스스로 꺼진다.
	## 그 자리에서 브레인이 싸울지 물러날지 정하고, 고른 대로 실제로 일어난다.
	if float(_ally_signal[index]) <= 0.0 and explore != null:
		var site := _touching_site(index)
		var seen: Dictionary = _ally_signaled[index]
		if site >= 0 and not seen.has(site):
			seen[site] = true
			_ally_signal[index] = SIGNAL_SECONDS
			_ally_encounter(index, site)
	_ally_signal[index] = maxf(0.0, float(_ally_signal[index]) - seconds)


func _ally_encounter(index: int, site: int) -> void:
	## 동료가 조우에 닿았다 — 판단은 한 번, 결과는 진짜다.
	## 다른 동료가 같은 조우를 다시 붙잡지 않는다 (한 조우 = 한 판단).
	if _ally_decided.has(site):
		return
	_changed = true
	_ally_decided[site] = true
	var action := _ally_engage_choice(index)
	_ally_state[index] = action
	# 교전은 1.5초 준비 — 점멸하는 동안 플레이어가 합류하거나 R 로 물릴 수 있는 창이다.
	_ally_timer[index] = SIGNAL_SECONDS if action == "교전" else ALLY_ACTION_SECONDS
	_ally_battle[index] = site if action == "교전" else -1
	if action == "후퇴":
		FonsBrain.record_action(heroes[index], "후퇴")
		_ally_targets[index] = _pick_target(index)


func _ally_engage_choice(index: int) -> String:
	## 교전 vs 후퇴 — 점수는 여기서만 쓰고 화면에는 안 보낸다.
	## 브레인이 없으면 체력으로만 가른다 (반 이하 → 후퇴).
	var candidates := [
		{"action": "교전", "domain": "공격"},
		{"action": "후퇴", "tag": "후퇴", "domain": "기동"},
	]
	var hero: Dictionary = heroes[index]
	var hp_ratio := clampf(float(hero.get("hp", 0)) / maxf(1.0, float(hero.get("maxHp", 1))), 0.0, 1.0)
	if FonsBrain.attached(hero):
		var chosen: Dictionary = hero["brain"].decide(candidates, {"hp_ratio": hp_ratio})
		if not chosen.is_empty():
			return String(chosen.get("action", "후퇴"))
	return "교전" if hp_ratio >= 0.5 else "후퇴"


func _touching_site(index: int) -> int:
	## 아직 안 지운 조우 중 이 영웅이 반경 안에 선 것. 없으면 -1.
	var best := -1
	var best_d := FonsExplore.CONTACT_RADIUS
	for i in explore.sites.size():
		if bool(explore.sites[i]["cleared"]):
			continue
		var d: float = party_pos[index].distance_to(explore.sites[i]["pos"])
		if d <= best_d:
			best_d = d
			best = i
	return best


func _alerting() -> bool:
	for left in _ally_signal:
		if float(left) > 0.0:
			return true
	return false


func _signal_on(index: int) -> bool:
	## 0.25초 켜짐 · 0.25초 꺼짐 × 3회 = 1.5초. 첫 틱은 켜진 채로 시작한다.
	var left := float(_ally_signal[index])
	if left <= 0.0:
		return false
	var elapsed := SIGNAL_SECONDS - left
	return int(elapsed / SIGNAL_HALF) % 2 == 0


func _separate() -> void:
	## 다섯이 한 점에 겹치지 않게 민다. 조종 영웅은 플레이어 것이므로 안 민다.
	## 한 번으로는 밀린 자리가 다시 겹친다 — 두 번 돌려 간격을 잡는다.
	for _pass in 2:
		_separate_once()


func _separate_once() -> void:
	for i in party_pos.size():
		for j in range(i + 1, party_pos.size()):
			var gap: Vector2 = party_pos[j] - party_pos[i]
			var dist := gap.length()
			if dist >= ALLY_MIN_DIST:
				continue
			# 정확히 같은 좌표면 방향이 없다 — 그대로 두면 다섯이 한 칸에 쌓인다.
			# 인덱스로 방향을 정해 두면 같은 시드에서 늘 같은 쪽으로 갈라진다.
			var angle := TAU * float(i * 7 + j) / 23.0
			var dir := gap / dist if dist > 0.001 else Vector2(cos(angle), sin(angle))
			var push := dir * (ALLY_MIN_DIST - dist) * 0.5
			if i != controlled:
				party_pos[i] -= push
			if j != controlled:
				party_pos[j] += push


func _start_ally_action(index: int) -> void:
	## 목표점에 닿았다 — 브레인에게 "이제 뭐 할까"를 물어본다.
	_changed = true
	var action := _ally_choice(index)
	if action == "이동":
		_ally_targets[index] = _pick_target(index)
		return
	_ally_state[index] = action
	_ally_timer[index] = ALLY_ACTION_SECONDS


func _finish_ally_action(index: int) -> void:
	## 끝난 행동을 **그 영웅의** 태그로 남긴다 (각인 판정까지 간다).
	_changed = true
	var action := String(_ally_state[index])
	if action == "교전":
		# 준비 시간이 끝났다 — 그 자리에서 진짜 싸운다. 플레이어가 먼저 끝냈으면 할 일이 없다.
		var site := int(_ally_battle[index])
		_ally_battle[index] = -1
		if site >= 0:
			_fight(site)
	elif action in ["채집", "휴식"]:
		FonsBrain.record_action(heroes[index], action)
	_ally_state[index] = "이동"
	_ally_timer[index] = 0.0
	_ally_targets[index] = _pick_target(index)


func _ally_choice(index: int) -> String:
	## 후보 셋 중 하나. 점수는 화면에 안 보이고, 여기서만 쓴다 (제안서 §6).
	var candidates := [
		{"action": "채집", "tag": "채집", "domain": "생산"},
		{"action": "휴식", "tag": "휴식", "domain": "회복"},
		{"action": "이동", "tag": "정찰", "domain": "기동"},
	]
	var hero: Dictionary = heroes[index]
	if FonsBrain.attached(hero):
		var max_hp := maxf(1.0, float(hero.get("maxHp", 1)))
		var ctx := {"hp_ratio": clampf(float(hero.get("hp", 0)) / max_hp, 0.0, 1.0)}
		var chosen: Dictionary = hero["brain"].decide(candidates, ctx)
		if not chosen.is_empty():
			return String(chosen.get("action", "이동"))
	var ratio := float(hero.get("hp", 0)) / maxf(1.0, float(hero.get("maxHp", 1)))
	return "휴식" if ratio < 0.5 else "채집"


func _pick_target(index: int) -> Vector2:
	## 범위 안의 다음 목표점. 같은 시드면 같은 자리 — 이동이 결정론적이다.
	var rng: RandomNumberGenerator = _ally_rng[index]
	var center: Vector2 = explore.avatar if explore != null else Vector2.ZERO
	for attempt in 8:
		var angle := rng.randf() * TAU
		var dist := PARTY_RADIUS * 0.7 * sqrt(rng.randf())
		var point := center + Vector2(cos(angle), sin(angle)) * dist
		if point.distance_to(center) <= PARTY_RADIUS and _free_spot(index, point):
			return point
	return center


func _free_spot(index: int, point: Vector2) -> bool:
	for j in party_pos.size():
		if j != index and party_pos[j].distance_to(point) < ALLY_MIN_DIST:
			return false
	return true


func contact_index() -> int:
	return explore.contact_index() if explore != null else -1


func engage() -> Dictionary:
	## 접촉 중인 조우 하나를 친다. 접촉이 없고 이 층에 문지기가 있으면 문지기와 싸운다.
	## 접촉도 문지기도 없거나 파티가 전멸했으면 빈 Dictionary.
	if explore == null or not winner.is_empty():
		return {}
	var index := contact_index()
	if index < 0:
		return fight_gatekeeper()
	return _fight(index)


func gatekeeper_ready() -> bool:
	## 이 층에 문지기가 있고 아직 안 이겼다 — F 가 그 판을 연다.
	return not _gatekeeper.is_empty() and not _gatekeeper_cleared and winner.is_empty()


func fight_gatekeeper() -> Dictionary:
	## 이데아 문턱의 전투 — 문지기 한 체. 일반 조우가 없어 필드에 지점을 세우지 않는다.
	## 지면 파티가 전멸해 `winner` 가 `enemy` 가 된다 — 재도전은 기존 R 경로다.
	if not gatekeeper_ready():
		return {}
	_changed = true
	var out := FonsFloorRun.simulate_gatekeeper(_rng, _monsters, _biomes, floor, heroes)
	for line in out.get("log", []):
		explore.log_lines.append(String(line))
	var gk_name := String(_gatekeeper.get("name", ""))
	var loot := {}
	if String(out["winner"]) == "ally":
		_gatekeeper_cleared = true
		explore.log_lines.append("문지기 %s — 격파 (%d턴)" % [gk_name, int(out["turns"])])
		loot = claim_gatekeeper_loot()
		out["first_clear"] = not loot.is_empty()
		out["loot"] = loot
		explore.log_lines.append(_loot_line(loot) if not loot.is_empty()
			else "전리품 — 이미 받은 층")
		if floor >= MAX_FLOOR:
			ending = true
			explore.log_lines.append("문턱을 넘었다 — 엔딩")
		for item in _judge_fusion():
			explore.log_lines.append("%s → 융합 「%s」" % [String(item["hero"]), String(item["name"])])
	else:
		explore.log_lines.append("문지기 %s — %s (%d턴)" % [gk_name,
			"패배" if String(out["winner"]) == "enemy" else "무승부", int(out["turns"])])
	log_lines = explore.log_lines.slice(maxi(0, explore.log_lines.size() - LOG_TAIL))
	_update_winner()
	## 엔딩 화면이 읽는 한 판의 요약 — 규칙이 아니라 연출이 쓴다.
	last_gatekeeper = {
		"name": gk_name,
		"turns": int(out["turns"]),
		"survivors": party_alive(),
		"loot": loot.duplicate(),
	}
	return out


func _fight(index: int) -> Dictionary:
	## 전투 한 판 — 플레이어가 누른 것과 동료가 고른 것이 같은 길을 지난다.
	_changed = true
	var out := explore.fight(index, heroes, _rng)
	# 뷰에 넘길 타격 한 번 — 자리와 그 판의 피해 합 (연출 전용, 규칙에는 안 쓴다).
	# 이미 지운 조우를 동료가 마저 치면 `turns` 가 0 이다 — 싸우지 않았으니 연출도 없다.
	if int(out.get("turns", 0)) > 0:
		_strike_seq += 1
		_strike_site = index
		_strike_damage = int(out.get("last_hit", 0))
		_strike_heavy = bool(out.get("last_crit", false))
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
	_cancel_ally_battles()
	explore.retreat(heroes)
	party_pos[controlled] = explore.avatar
	log_lines = explore.log_lines.slice(maxi(0, explore.log_lines.size() - LOG_TAIL))
	_update_winner()


func _cancel_ally_battles() -> void:
	## R 은 파티를 물린다 — 준비 중이던 동료의 교전도 같이 취소한다 (제안서 §6 R 로 회피).
	for i in range(_ally_state.size()):
		if String(_ally_state[i]) != "교전":
			continue
		_ally_state[i] = "이동"
		_ally_timer[i] = 0.0
		_ally_battle[i] = -1
		_ally_targets[i] = _pick_target(i)


func mission_done() -> bool:
	if explore == null:
		return false
	if explore.mission_done():
		return true
	## 일반 조우가 없는 층 — 문지기 격파가 미션 자리를 대신한다. 문지기가 없는 층(129)은 통과다.
	return _gatekeeper_cleared or (_combatless and _gatekeeper.is_empty())


func next_floor() -> bool:
	## 미션을 끝냈을 때만 다음 층. 영웅 HP 는 이어진다 — 쉬어서 회복하는 규칙은 아직 없다.
	if explore == null or not mission_done() or floor >= MAX_FLOOR:
		return false
	floor += 1
	_open_field()
	log_lines = []
	winner = ""
	return true


func gatekeeper_name() -> String:
	## 이 층 문지기의 이름 — 엔딩 화면·힌트가 쓴다. 없으면 빈 문자열.
	return String(_gatekeeper.get("name", ""))


func claim_gatekeeper_loot() -> Dictionary:
	## 첫 격파 전리품 — 데이터 `loot` 그대로. 같은 층에서 두 번 부르면 빈 Dictionary.
	## 지갑에 넣는 것은 호출처(`main.gd`)다 — 여기는 무엇을 줄지만 정한다 (estate.settle 과 같은 결).
	if not _gatekeeper_cleared or _rewarded_floors.has(floor):
		return {}
	_rewarded_floors[floor] = true
	return _gatekeeper.get("loot", {}).duplicate()


func _loot_line(loot: Dictionary) -> String:
	## HUD 로그 한 줄 — 영혼·exp 는 아직 받을 곳이 없어 숫자만 적는다.
	var souls: Array = loot.get("soul", [])
	var names: Array[String] = []
	for s in souls:
		names.append(String(s))
	var soul := "없음" if names.is_empty() else "/".join(names)
	return "전리품 — 영혼 %s · gold %d · exp %d" % [soul, int(loot.get("gold", 0)), int(loot.get("exp", 0))]


func floor_progress() -> String:
	## HUD 한 칸 — 일반 조우 층은 조우 수, 문턱은 문지기 이름과 상태다.
	## `explore.required` 는 상수 3 이라 문턱에서 "0/3" 이 거짓 진행처럼 보인다.
	if explore == null:
		return ""
	if _combatless:
		if _gatekeeper.is_empty():
			return "통과"
		return "문지기 %s%s" % [String(_gatekeeper.get("name", "")), " 격파" if _gatekeeper_cleared else ""]
	return "탐험 %d/%d" % [explore.cleared, explore.required]


func party_alive() -> int:
	var n := 0
	for hero in heroes:
		if bool(hero.get("alive", false)):
			n += 1
	return n


func memory_pending() -> bool:
	## 101층 위인데 아직 안 나눴다 — main 이 이때 한 번 묻는다.
	return floor >= FonsRunState.MEMORY_FLOOR \
		and memory_attack + memory_guard < FonsHeroStats.MEMORY_MAX


func allocate_memory(attack: int, guard: int) -> bool:
	## 101층 한 번 — 10점을 화력과 생존에 나눈다. 나눈 뒤에는 이 런에서 못 바꾼다.
	## HP 는 비율을 지킨다 (층 사이에 반피로 서 있어도 그 비율 그대로 커진다).
	if not memory_pending():
		return false
	var a := clampi(attack, 0, FonsHeroStats.MEMORY_MAX)
	var g := clampi(guard, 0, FonsHeroStats.MEMORY_MAX)
	if a + g != FonsHeroStats.MEMORY_MAX:
		return false
	memory_attack = a
	memory_guard = g
	FonsRunState.apply_memory_to_party(heroes, a, g)
	log_lines.append("기억 %d점 — 화력 ×%.2f · 생존 ×%.2f" % [
		FonsHeroStats.MEMORY_MAX, FonsHeroStats.memory_multiplier(a),
		FonsHeroStats.memory_multiplier(g)])
	log_lines = log_lines.slice(maxi(0, log_lines.size() - LOG_TAIL))
	return true


func hint() -> String:
	## HUD 아래 줄 — 지금 누를 수 있는 것만 말한다.
	if explore == null:
		return ""
	if not winner.is_empty():
		return "전멸 — R 로 1층부터 재도전"
	for i in range(_ally_state.size()):
		if String(_ally_state[i]) == "교전":
			return "동료 교전 준비 중 — R 로 물린다"
	if gatekeeper_ready():
		return "문지기 %s — F 로 싸운다" % String(_gatekeeper.get("name", ""))
	if mission_done():
		if floor >= MAX_FLOOR:
			return "문턱을 넘었다" if ending else "미션 완료"
		return "미션 완료 — F 로 다음 층"
	var index := contact_index()
	if index >= 0:
		return "조우 접촉 — F 로 싸운다"
	return "WASD — 걷기 · Space — 점프 · 마우스 — 시점 · 휠 — 거리 · F — 교전 · 1~5 — 전환 · R — 후퇴 · 미션: 조우 %d/%d" % [explore.cleared, explore.required]


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
		"asset": _hero_asset(controlled),
		"pos": Vector3(explore.avatar.x, 0.0, explore.avatar.y),
		"size": Vector2(0.9, 0.9),
		"hero": controlled,
		"hp": int(heroes[controlled].get("hp", 0)),
		"max_hp": int(heroes[controlled].get("maxHp", 0)),
	})
	# 지금 향하는 조우에 무엇이 서 있는지 — 교전 전에 보이게 한다 (S5b 필드 확인).
	_append_preview(entities)
	# 동료 4명 — 조종 영웅은 위의 avatar 하나로 그린다(같은 자리에 두 번 그리지 않는다).
	for i in party_pos.size():
		if i == controlled:
			continue
		entities.append({
			"id": "hero:%d" % i,
			"kind": "hero",
			"asset": _hero_asset(i),
			"pos": Vector3(float(party_pos[i].x), 0.0, float(party_pos[i].y)),
			"size": Vector2(0.8, 0.8),
			"hero": i,
			"alive": bool(heroes[i].get("alive", false)),
			"hp": int(heroes[i].get("hp", 0)),
			"max_hp": int(heroes[i].get("maxHp", 0)),
		})
	# 오른쪽 파티 칸 — 다섯 줄. 행동 글자는 다섯 개만 쓴다 (이동·교전·채집·휴식·후퇴).
	# 지금은 자율 행동이 이동뿐이라 전부 "이동" 이다. 행동이 붙으면 그 이름으로 바뀐다.
	var party: Array = []
	for i in party_pos.size():
		party.append({
			"index": i,
			"hp": int(heroes[i].get("hp", 0)),
			"max_hp": int(heroes[i].get("maxHp", 0)),
			"acting": "이동" if i == controlled else String(_ally_state[i]),
			"controlled": i == controlled,
			"alive": bool(heroes[i].get("alive", false)),
			"alert": i != controlled and _signal_on(i),
		})
	var world: Dictionary = explore.biome() if explore != null else {}
	return {
		"mode": "field",
		"floor": floor,
		# 바이옴 이름·지형 키트·파생색 — 뷰는 데이터를 읽지 않고 이 세 값만 칠한다.
		"biome": String(world.get("id", "")),
		"kit": String(world.get("topologyKit", "")),
		"palette": FonsBiomePalette.from_biome(world),
		"controlled": controlled,
		"radius": PARTY_RADIUS,
		"party": party,
		# `field` 는 이제 **청크 크기**다. 뷰는 이 크기로 지형 타일을 뜨고, `chunks` 목록만 그린다.
		"field": Vector2(FonsExplore.CHUNK_WIDTH, FonsExplore.CHUNK_DEPTH),
		"chunks": explore.active_chunks() if explore != null else [],
		# 탑·소환진 — 월드 원점의 랜드마크. 자리와 반경만 준다 (메시는 뷰가 만든다).
		"tower": explore.tower_mark() if explore != null else {},
		"avatar": Vector3(explore.avatar.x, 0.0, explore.avatar.y),
		"contact": contact,
		"cleared": explore.cleared,
		"required": explore.required,
		"done": mission_done(),
		"ending": ending,
		# 이 층의 문지기 — 이름·이겼는지·지금 칠 수 있는지. 없으면 빈 이름이다.
		"gatekeeper": {
			"name": String(_gatekeeper.get("name", "")),
			"cleared": _gatekeeper_cleared,
			"ready": gatekeeper_ready(),
		},
		"wiped": not winner.is_empty(),
		# 방금 끝난 교전 — seq 가 바뀐 순간에만 뷰가 그 자리에 짧게 그린다.
		"strike": {"seq": _strike_seq, "site": _strike_site, "damage": _strike_damage,
			"heavy": _strike_heavy},
		"entities": entities,
		"log": log_lines.duplicate(),
	}


func _append_preview(entities: Array) -> void:
	## 시야 안의 가장 가까운, 아직 안 지운 조우 하나에 그 편성을 세운다.
	## 편성은 전투와 같은 함수에서 나온다 — 따로 굴리면 화면에 선 종과 실제로 싸우는 종이 갈린다.
	var index := _sight_index()
	if index < 0:
		return
	var site: Dictionary = explore.sites[index]
	var party: Array = _preview_party(int(site.get("contact_index", 0)))
	if party.is_empty():
		return
	var center := Vector3(float(site["pos"].x), 0.0, float(site["pos"].y))
	var facing := Vector3(explore.avatar.x, 0.0, explore.avatar.y) - center
	if facing.length() < 0.01:
		facing = Vector3(0.0, 0.0, 1.0)
	facing = facing.normalized()
	var side := Vector3(-facing.z, 0.0, facing.x)
	for i in party.size():
		var monster: Dictionary = party[i]
		# 반원으로 늘어서 플레이어를 마주 본다 — 한 줄이면 뒤 생물이 가린다.
		var t := 0.0 if party.size() == 1 else lerpf(-0.85, 0.85, float(i) / float(party.size() - 1))
		entities.append({
			"id": "preview:%d" % i,
			"kind": "monster",
			"asset": "monster:%s" % String(monster.get("id", "")),
			"pos": center + (facing * cos(t) + side * sin(t)) * PREVIEW_RADIUS,
			"size": Vector2(1.0, 1.0),
			"name": String(monster.get("name", "?")),
			"preview": true,
		})


func _sight_index() -> int:
	## 문지기 층·지운 조우는 세지 않는다. 접촉 판정과 같은 "가장 가까운 하나" 규칙.
	if explore == null:
		return -1
	var best := -1
	var best_d := ENCOUNTER_SIGHT
	for i in explore.sites.size():
		var site: Dictionary = explore.sites[i]
		if bool(site["cleared"]):
			continue
		var d := explore.avatar.distance_to(site["pos"])
		if d <= best_d:
			best_d = d
			best = i
	return best


func _preview_party(contact: int) -> Array:
	var key := "%d:%d" % [floor, contact]
	if not _preview_cache.has(key):
		_preview_cache[key] = FonsEncounter.build_party(_monsters, _biomes, floor, contact)
	return _preview_cache[key]


func _hero_asset(index: int) -> String:
	## R3 — 영웅은 문자열 키로 가리킨다. 직업 id 가 있으면 그것(`hero:knight`),
	## 없으면 자리 번호. 뷰는 이 키를 각자 해석한다 (2D 색, 3D 색·메시).
	if index < 0 or index >= heroes.size():
		return ""
	var key := String(heroes[index].get("job_id", ""))
	return "hero:%s" % (key if not key.is_empty() else str(index))


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
	# 일반 조우가 없는 바이옴은 문지기가 그 층의 유일한 전투다 (`biomes.json` noCombat).
	# 층마다 다시 고른다 — 130층은 바이옴 이름으로 무문의 파수병이 잡힌다.
	_combatless = FonsEncounter.is_combatless_biome(FonsEncounter.biome_for_floor(_biomes, floor))
	_gatekeeper = FonsEncounter.gatekeeper_for_floor(_monsters, floor, _biomes) if _combatless else {}
	_gatekeeper_cleared = false
	_preview_cache.clear()
	_rng.seed = _seed * 31 + floor
	_reset_party_positions()
	# 브레인도 지금 층을 안다 — 성장 예산(층당 상한)과 연계 세션 경계가 이 값을 쓴다.
	# (예전에는 `FonsRunState` 만 갱신해서 필드 경로에서는 1층에 고정됐다.)
	for hero in heroes:
		if FonsBrain.attached(hero):
			hero["brain"].floor = floor


func _reset_party_positions() -> void:
	## 층이 바뀌면 다섯을 입구 주변에 다시 세운다 — 조종 영웅은 유지된다.
	party_pos = []
	_ally_targets = []
	_ally_state = []
	_ally_timer = []
	_ally_rng = []
	_ally_signal = []
	_ally_signaled = []
	_ally_decided = {}
	_ally_battle = []
	_ally_battle.resize(heroes.size())
	_ally_battle.fill(-1)
	party_pos.resize(heroes.size())
	_ally_targets.resize(heroes.size())
	_ally_state.resize(heroes.size())
	_ally_timer.resize(heroes.size())
	_ally_signal.resize(heroes.size())
	_ally_signaled.resize(heroes.size())
	_ally_state.fill("이동")
	_ally_timer.fill(0.0)
	_ally_signal.fill(0.0)
	for i in heroes.size():
		_ally_signaled[i] = {}
	for i in heroes.size():
		var angle := TAU * float(i) / float(maxi(1, heroes.size()))
		var ring := 0.0 if i == controlled else 2.0 + float(i % 3)
		party_pos[i] = Vector2(cos(angle), sin(angle)) * ring
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 131 + floor * 17 + i
		_ally_rng.append(rng)
	party_pos[controlled] = FonsExplore.SPAWN
	explore.avatar = party_pos[controlled]
	for i in heroes.size():
		if i != controlled:
			_ally_targets[i] = _pick_target(i)


func _make_party() -> Array:
	return FonsRunState.heroes_from(_races, _job_tree, _equipment, 5, 130, _seed,
		_job_coef, 0, PARTY_SIZE, _ai, _basics)


func _update_winner() -> void:
	if party_alive() == 0:
		winner = "enemy"
	else:
		winner = ""
