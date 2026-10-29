class_name FonsRunState
extends RefCounted
## 층 진행 상태 — 심. 화면을 모른다 ([PLAN_2D_FIRST](../docs/design/PLAN_2D_FIRST.md) R1).
##
## 지금까지 `FonsFloorRun` 은 테스트에서만 돌았다. 이 클래스가 그 위에 **진행**을 얹는다 —
##   시작 → 한 층 판 → 이기면 다음 층 → 지면 멈춤.
## 뷰는 `snapshot()` 만 읽고, 입력은 `intent` 로 되돌아온다. 이 클래스는 Godot 노드 타입을 참조하지 않는다.
##
## 아직 없는 것: 소환·영지·저장. 영웅은 `races.json` 기준스탯으로 만든 고정 4인이다
## (성장 축 배선은 DEV_PLAN Phase 2.6).

const PARTY_SIZE := 4
const MAX_FLOOR := 130
const START_FLOOR := 1
## 기억 배분이 열리는 층 — 100층까지 올라온 런이 101층에서 10점을 받는다.
const MEMORY_FLOOR := 101
## 세이브가 같이 적는 값 — 불러올 때 이 값으로 영웅을 다시 만든다.
const GRADE := 5
const LEVEL := 130
## 종점 직업 — 키워드를 **1장만** 적용하는 직업. 원본 `ProgressionData.TerminalKeywordCounts` (원본 대조).
##   l2_sage 1장(대현자) · l2_spirit_knight 7장(정령기사) · l2_elementalist 7장(원소마도사).
## 값은 키워드 장수다 — 원본이 직업 id 로 물고 값을 회수한다.
const TERMINAL_JOBS := {"l2_sage": 1, "l2_spirit_knight": 7, "l2_elementalist": 7}
## HUD 에 보여 줄 로그 줄 수 — 전투 로그는 수십 줄이라 전부 그리면 화면을 덮는다.
const LOG_TAIL := 6

const ALLY_SIZE := Vector2(0.8, 0.8)
const ENEMY_SIZE := Vector2(1.0, 1.0)
const ALLY_X := -2.4
const ENEMY_X := 2.4
const ROW_GAP := 1.2

## 영웅 4인의 표시 이름. 정본 이름(종족·직업)이 아니라 자리표시자다 — 소환이 붙으면 그 이름으로 교체한다.
const HERO_LABELS := ["영웅 1", "영웅 2", "영웅 3", "영웅 4", "영웅 5"]

var floor := START_FLOOR
var winner := ""
var turns := 0
var heroes: Array = []
var enemies: Array = []
var log_lines: Array = []

var _rng := RandomNumberGenerator.new()
var _races: Dictionary = {}
var _job_tree: Dictionary = {}
var _job_coef: Dictionary = {}
var _equipment: Dictionary = {}
var _ai: Dictionary = {}
var _basics: Dictionary = {}
var _monsters: Variant = null
var _biomes: Variant = null
var _seed := 0
var _start_floor := START_FLOOR


static func keyword_jobs(job_tree: Dictionary, count: int = PARTY_SIZE, seed_value: int = 0) -> Array:
	## 파티원이 맡을 직업 — 키워드가 붙은 L2 를 **역할이 안 겹치게** 한 명씩 먼저 뽑는다.
	## 트리 앞에서부터 다섯을 집으면 전원이 선봉이 되어 필드에 같은 몸통 다섯이 선다
	## (실측: l2_breaker · l2_vengeance_knight · l2_fighter · l2_swordsman · l2_spirit_knight).
	##
	## 역할 순서·역할 안 순서를 시드로 섞는다 — 같은 시드면 같은 파티(세이브가 시드로 영웅을
	## 다시 만든다), 다른 판이면 다른 다섯. 역할이 모자라면 돌아가며 두 번째를 채운다.
	## L1 은 키워드가 없고 L3(생활직)은 전투 파티 자리가 아니므로 stage 2 만 쓴다.
	var by_role: Dictionary = {}
	var roles: Array = []
	for job in job_tree.get("jobs", []):
		if int(job.get("stage", 0)) != 2:
			continue
		if (job.get("keywords", []) as Array).is_empty():
			continue
		var role := String(job.get("role", ""))
		if not by_role.has(role):
			by_role[role] = []
			roles.append(role)
		(by_role[role] as Array).append(job)
	if roles.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_shuffle(roles, rng)
	for role in roles:
		_shuffle(by_role[role], rng)
	var out: Array = []
	var depth := 0
	while out.size() < count:
		var added := false
		for role in roles:
			if out.size() >= count:
				break
			var rows: Array = by_role[role]
			if depth < rows.size():
				out.append(rows[depth])
				added = true
		if not added:
			break
		depth += 1
	return out


static func _shuffle(rows: Array, rng: RandomNumberGenerator) -> void:
	## 시드를 쓰는 섞기 — `Array.shuffle()` 은 전역 RNG 라 세이브 재현이 안 된다.
	for i in range(rows.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = rows[i]
		rows[i] = rows[j]
		rows[j] = tmp


static func memory_points(floor_value: int) -> int:
	## 깊이로만 정해지는 점수 — 101층 10점, 100층 9점, 1층 0점.
	## 한 번 주고 더 안 준다 (상한이 곧 `MEMORY_MAX`).
	return clampi(int((floor_value - 1) / 10.0), 0, FonsHeroStats.MEMORY_MAX)


static func apply_memory_to_party(party: Array, attack: int, guard: int) -> void:
	## 이미 걷고 있는 파티에 배분을 건다 — 101층에서 한 번. HP 는 비율을 지킨다.
	## `heroes_from` 의 배율과 같은 축이다 — 두 경로가 같은 숫자를 내야 한다.
	if attack <= 0 and guard <= 0:
		return
	var attack_mul := FonsHeroStats.memory_multiplier(attack)
	var guard_mul := FonsHeroStats.memory_multiplier(guard)
	for hero in party:
		var max_hp := maxf(1.0, float(hero.get("maxHp", 1)))
		var ratio := clampf(float(hero.get("hp", 0)) / max_hp, 0.0, 1.0)
		hero["maxHp"] = int(roundf(max_hp * guard_mul))
		hero["hp"] = int(roundf(float(hero["maxHp"]) * ratio))
		for axis in ["atk", "mag"]:
			hero[axis] = float(hero.get(axis, 0.0)) * attack_mul
		for axis in ["def", "mdef"]:
			hero[axis] = float(hero.get(axis, 0.0)) * guard_mul


static func applied_cards(job: Dictionary, cards: int = 0) -> Array:
	## 적용되는 키워드 카드 — 원본 규칙 (Unity `ProgressionData.Accumulate`, 원본 대조):
	##   일반 L2 — 키워드 **전부**를 곱한다 (원본은 3장 L2 를 전부 곱했다).
	##   종점(`TERMINAL_JOBS`) — 1장만 곱한다 (미선택이면 첫 장 — 원본 `SelectedKeywordOf`).
	## `cards` 는 측정용 상한(1 = 한 장만) — 0 이면 규칙 그대로.
	##
	## ponytail: 원본은 L2 에 달린 **L3 자식**의 카드까지 같이 곱한다 (`job.stage == 2` → stage 3 자식 누적).
	## 이 트리에서 L3 자식이 있는 L2 는 무직(`l2_jobless`)뿐이고 그 키워드는 0장이다.
	## 생활직(`l3_life` 13장)은 파티 직업으로 고를 때 그 자체로 13장 전부가 곱해지므로
	## 숫자가 같다 — 무직을 파티에 넣게 되면 여기서 자식 누적 규칙을 넣어야 한다.
	var kws: Array = job.get("keywords", [])
	if kws.is_empty():
		return []
	var use: Array = kws
	if TERMINAL_JOBS.has(String(job.get("id", ""))):
		use = [kws[0]]
	if cards > 0:
		use = use.slice(0, mini(cards, use.size()))
	return use


static func keyword_mod_for(job: Dictionary, cards: int = 0) -> Array:
	## 적용되는 카드의 13축 배율을 곱한 값 — 영웅 스탯에 건다.
	var mod: Array = []
	for a in FonsHeroStats.AXES.size():
		mod.append(1.0)
	for card in applied_cards(job, cards):
		var sm: Array = card.get("statMod", [])
		for a in FonsHeroStats.AXES.size():
			if a < sm.size():
				mod[a] = float(mod[a]) * float(sm[a])
	return mod


static func heroes_from(races: Dictionary, job_tree: Dictionary = {}, equipment: Dictionary = {},
		grade: int = 5, level: int = 130, seed_value: int = 0,
		job_coef: Dictionary = {}, cards: int = 0, party_size: int = PARTY_SIZE,
		ai: Dictionary = {}, basics: Dictionary = {},
		memory_attack: int = 0, memory_guard: int = 0) -> Array:
	## 기준스탯 → **직업계수** × 키워드 × 등급 × 레벨 × 순수도 + 장비 → 개체 변량 ±7% → 전투 유닛.
	## 키워드는 원본 규칙대로 — 일반 L2 는 3장 전부 곱, 종점(7장)은 1장만 (`cards` 로 상한 재면 측정용).
	## `memory_attack`·`memory_guard` — 101층 기억 배분. 기본 0:0 이면 배율 없음(기존 경로 그대로).
	## 장비는 3등급 한 벌(`equipment.json`) — 강화·상점·획득 경로는 아직 없다 (원본 대조는 구현만).
	var def := FonsHeroStats.from_data(races)
	var gear: Dictionary = FonsEquipment.from_grade(equipment, 3) if not equipment.is_empty() else {}
	# 직업은 **이 파티 크기**만큼 뽑는다. 기본값(PARTY_SIZE=4)에 기대면 5인 파티의 마지막이
	# 직업·계수·브레인 없이 남는다 — 필드 파티는 5인이다.
	var jobs: Array = keyword_jobs(job_tree, party_size, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for i in party_size:
		var job: Dictionary = jobs[i] if i < jobs.size() else {}
		var mod: Array = keyword_mod_for(job, cards)
		var job_mod: Dictionary = {}
		if not job_coef.is_empty() and not job.is_empty():
			job_mod = FonsJobCoef.multipliers(job_coef, String(job.get("id", "")))
		var field: Dictionary = FonsHeroStats.field_stats(def.base, grade, level, 1.0, mod, gear, job_mod)
		field = FonsHeroStats.varied(field, rng)
		if memory_attack > 0 or memory_guard > 0:
			field = FonsHeroStats.apply_memory(field, memory_attack, memory_guard)
		var unit: Dictionary = FonsBattle.unit_from_hero(field, String(HERO_LABELS[i] if i < HERO_LABELS.size() else "영웅 %d" % (i + 1)))
		if not job.is_empty():
			unit["job"] = String(job.get("name", ""))
			unit["job_id"] = String(job.get("id", ""))
			unit["keyword"] = _card_names(applied_cards(job, cards))
		FonsBasicAttacks.install(unit, basics)
		_attach_ai(unit, ai, job, grade, level, seed_value, i)
		out.append(unit)
	return out


static func _attach_ai(unit: Dictionary, ai: Dictionary, job: Dictionary, grade: int,
		level: int, seed_value: int, index: int) -> void:
	## 성격 3키워드 + 판단(`FonsBrain`). **스탯은 안 건드린다** — 행동 선호만 붙는다 (09 §4-1).
	## 시드는 실행 시드 + 자리 번호라, 같은 실행이면 층이 올라도 같은 사람이다.
	var data: Dictionary = ai.get("personalities", {})
	if not FonsPersonality.is_ready(data) or job.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + index * 104729 + 17
	var identity := FonsPersonality.roll(data, rng, grade, level)
	var profiles: Dictionary = ai.get("profiles", {}).get("profiles", {})
	var profile: Dictionary = profiles.get(String(job.get("id", "")), {})
	var catalog: Array = ai.get("catalog", {}).get("skills", ai.get("catalog", []))
	FonsBrain.attach(unit, identity, data, profile, String(job.get("role", "")), catalog)


static func _card_names(cards: Array) -> String:
	## 적용된 카드 이름 — 표시용. 여러 장이면 · 로 잇는다.
	var names: Array = []
	for card in cards:
		names.append(String(card.get("name", "")))
	return "·".join(names)


func configure(races: Dictionary, monsters: Variant, biomes: Variant,
		seed_value: int = 0, start_floor: int = START_FLOOR,
		job_tree: Dictionary = {}, equipment: Dictionary = {},
		job_coef: Dictionary = {}, ai: Dictionary = {}, basics: Dictionary = {}) -> void:
	## 데이터만 잡아 둔다 — 영웅을 만들지 않고 판도 돌리지 않는다.
	## 불러오기는 이 위에 `restore()` 를 얹는다: `start()` 를 부르면 1층을 한 번 싸워
	## 카운터·각인이 늘어난 뒤에 덮어쓰게 된다.
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
	heroes = heroes_from(races, job_tree, equipment, GRADE, LEVEL, seed_value, job_coef, 0, PARTY_SIZE, ai, basics)
	_run_floor()


func restart() -> void:
	floor = _start_floor
	heroes = heroes_from(_races, _job_tree, _equipment, GRADE, LEVEL, _seed, _job_coef, 0, PARTY_SIZE, _ai, _basics)
	_run_floor()


func to_save() -> Dictionary:
	## 이 런이 **가진 것**만 낸다. 적·로그·스냅샷은 시드의 함수라 넣지 않는다 (ADR 0008).
	return {
		## 64비트 시드는 문자열로 쓴다 — JSON 이 정수를 float 로 돌려준다 (설계 §2).
		"seed": str(_seed),
		"grade": GRADE,
		"level": LEVEL,
		"start_floor": _start_floor,
		"floor": floor,
		"heroes": heroes_to_save(heroes),
	}


static func heroes_to_save(party: Array) -> Array:
	## 영웅 한 줄의 저장 형식. 런과 필드가 같은 형식을 쓴다 — 둘을 따로 쓰면 갈라진다.
	var rows: Array = []
	for i in party.size():
		var hero: Dictionary = party[i]
		var row := {
			"index": i,
			"job_id": String(hero.get("job_id", "")),
			"hp": int(hero.get("hp", 0)),
			"alive": bool(hero.get("alive", false)),
			"equipment": [],
		}
		if FonsBrain.attached(hero):
			row["brain"] = hero["brain"].to_save()
		rows.append(row)
	return rows


static func apply_hero_save(party: Array, rows: Array) -> void:
	## 저장값을 이미 만들어진 영웅에게 덮어쓴다. 브레인이 없던 시절의 세이브는 HP·생존만 되살아난다.
	for i in mini(rows.size(), party.size()):
		var row: Dictionary = rows[i]
		var hero: Dictionary = party[i]
		hero["hp"] = clampi(int(row.get("hp", hero.get("hp", 0))), 0, int(hero.get("maxHp", 1)))
		hero["alive"] = bool(row.get("alive", true)) and int(hero["hp"]) > 0
		if FonsBrain.attached(hero) and row.get("brain") is Dictionary:
			hero["brain"].from_save(row["brain"])
			hero["brain"].mirror(hero)


func restore(saved: Dictionary) -> bool:
	## `configure()` 를 먼저 부른 뒤에 써야 한다. 영웅을 시드로 다시 만들고 저장값을 덮어쓴다.
	## 판은 돌리지 않는다 — 저장 파일에는 판 중간이 없고, 다음 층은 `next_floor()` 가 새로 돈다.
	if saved.is_empty():
		return false
	_seed = int(String(saved.get("seed", "0")))
	_start_floor = clampi(int(saved.get("start_floor", _start_floor)), START_FLOOR, MAX_FLOOR)
	floor = clampi(int(saved.get("floor", _start_floor)), START_FLOOR, MAX_FLOOR)
	heroes = heroes_from(_races, _job_tree, _equipment, int(saved.get("grade", GRADE)),
		int(saved.get("level", LEVEL)), _seed, _job_coef, 0, PARTY_SIZE, _ai, _basics)
	apply_hero_save(heroes, saved.get("heroes", []))
	# 이 층의 적은 시드에서 다시 만든다 — 저장하지 않는다.
	var built := FonsFloorRun.build(_monsters, _biomes, floor, 0)
	enemies = built["party"]
	winner = ""
	turns = 0
	log_lines = []
	return true


func next_floor() -> bool:
	## 이겼을 때만 다음 층으로 간다. 지거나 비기면 멈춘다 (그 상태로 더 밀면 거짓 진행이 된다).
	if winner != "ally" or floor >= MAX_FLOOR:
		return false
	floor += 1
	_run_floor()
	return true


func party_alive() -> int:
	var n := 0
	for h in heroes:
		if bool(h.get("alive", false)):
			n += 1
	return n


func tail() -> Array:
	var from := maxi(0, log_lines.size() - LOG_TAIL)
	return log_lines.slice(from)


func snapshot() -> Dictionary:
	## 뷰가 읽는 유일한 형식. 엔티티 id 는 문자열 키이고(R3) 위치는 `Vector3`(R2)다.
	var entities: Array = []
	for i in heroes.size():
		entities.append(_entity(&"hero:%d" % i, "hero", heroes[i], i, ALLY_X, ALLY_SIZE))
	for i in enemies.size():
		entities.append(_entity(&"monster:%d" % i, "monster", enemies[i], i, ENEMY_X, ENEMY_SIZE))
	return {
		"floor": floor,
		"winner": winner,
		"turns": turns,
		"log": tail(),
		"entities": entities,
	}


func _entity(id: StringName, kind: String, unit: Dictionary, row: int, x: float, size: Vector2) -> Dictionary:
	# 같은 편은 z 축으로 줄을 세운다 — 탑다운(XZ)에서 세로로 늘어선다.
	var z := (float(row) - float(PARTY_SIZE - 1) * 0.5) * ROW_GAP
	return {
		"id": id,
		"asset": "%s:%s" % [kind, unit.get("id", row)],
		"pos": Vector3(x, 0.0, z),
		"size": size,
		"kind": kind,
		"name": String(unit.get("name", "?")),
		"hp": int(unit.get("hp", 0)),
		"max_hp": int(unit.get("maxHp", 0)),
		"alive": bool(unit.get("alive", false)),
	}


func _run_floor() -> void:
	# 판마다 새 유닛을 만든다 — `FonsFloorRun.build` 가 그 책임을 진다 (재사용하면 반피로 시작한다).
	_rng.seed = _seed + floor
	var built := FonsFloorRun.build(_monsters, _biomes, floor, 0)
	enemies = built["party"]
	# 세션 경계 — 융합의 "여러 판에서 반복"은 층 단위로 센다.
	for hero in heroes:
		if FonsBrain.attached(hero):
			hero["brain"].floor = floor
	var out := FonsFloorRun.run(_rng, heroes, enemies, floor)
	winner = String(out["winner"])
	turns = int(out["turns"])
	log_lines = out["log"]
	# 이 층에서 실제로 겪은 세계를 문맥 카운터로 남긴다 — 수중 기술은 물에서, 보스 기술은 문지기 앞에서.
	# (예전에는 `note_context` 가 테스트에만 불려 문맥 태그가 게임에서 한 번도 안 쌓였다.)
	var world := FonsFusion.place_context(_biomes, floor)
	for hero in heroes:
		if FonsBrain.attached(hero) and bool(hero.get("alive", false)):
			hero["brain"].note_context(world)
	if winner == "ally" and not _ai.is_empty():
		_try_fusion()


func _try_fusion() -> void:
	## 이긴 판 뒤에만 심사한다 — 싸우다 만 판에서 기술이 태어나면 이유를 설명할 수 없다.
	## JEV 는 **지금 세계**를 본다: 바이옴의 habitat·category 를 문맥 태그로 옮겨 넘긴다.
	## (예전에는 빈 Dictionary 라 JEV 가 항상 중립 0.5 였다 — 세 심사자 중 하나가 죽어 있었다.)
	var catalog: Array = _ai.get("catalog", {}).get("skills", _ai.get("catalog", []))
	var legacy: Array = _ai.get("legacy_pairs", {}).get("pairs", [])
	var ctx := FonsFusion.place_context(_biomes, floor)
	var born := FonsFusion.run_for_party(heroes, ctx, catalog, legacy)
	for item in born:
		log_lines.append("%s → 융합 「%s」" % [String(item["hero"]), String(item["name"])])
