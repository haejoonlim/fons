extends SceneTree
## 하루 리포트 — "전투만 세면 무엇이 빠지는가"를 숫자로 남긴다.
##
## 실행:
##   godot --headless --path godot -s tools/day_report.gd
##   godot --headless --path godot -s tools/day_report.gd -- --days=20 --floor=40
##
## 이 도구가 답하는 질문 셋:
##   1. 하루에 어떤 태그가 얼마나 쌓이는가 (생활·탐험·전투의 비중)
##   2. 영지·저녁을 끄면(=탐험만) 무엇이 사라지는가 — 대조군
##   3. 층이 올라가도 생활 태그가 각인 재료로 남는가
##
## 게임 코드가 아니라 측정 도구다. 수치를 여기서 정하지 않는다 — 수확은 `estate.json`,
## 태그는 GDD 09 §3, 각인 규칙은 `FonsSkillBook` 이 정본이다.

const LIFE_TAGS := ["채집", "약초학", "벌목", "채광", "요리", "운반", "청소",
	"자체훈련", "순찰", "기록", "휴식", "식사", "장비정비", "명상", "독서"]
const FIELD_TAGS := ["정찰", "영역이동", "관찰", "후퇴", "매복"]

var _races: Dictionary
var _monsters: Variant
var _biomes: Variant
var _job_tree: Dictionary
var _job_coef: Dictionary
var _equipment: Dictionary
var _estate: Dictionary
var _personalities: Dictionary
var _profiles: Dictionary
var _catalog: Dictionary
var _legacy: Dictionary
var _days := 30
var _floor := 1
var _seed := 11


func _initialize() -> void:
	_races = _load("races.json")
	_monsters = _load("monsters.json")
	_biomes = _load("biomes.json")
	_job_tree = _load("job_tree.json")
	_job_coef = _load("job_coef.json")
	_equipment = _load("equipment.json")
	_estate = _load("estate.json")
	_personalities = _load("personalities.json")
	_profiles = _load("job_ai_profiles.json")
	_catalog = _load("skills_catalog.json")
	_legacy = _load("fusion_pairs.json")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			_days = maxi(1, int(arg.split("=")[1]))
		elif arg.begins_with("--floor="):
			_floor = maxi(1, int(arg.split("=")[1]))
		elif arg.begins_with("--seed="):
			_seed = int(arg.split("=")[1])

	_modes()
	_floors()
	_one_day()
	quit()


func _modes() -> void:
	## 같은 파티·같은 일수를 세 모드로 돌린다 — 차이는 "하루에 무엇이 들어 있는가"뿐이다.
	print("## 1. 하루의 구성 — %d일 · %d층 · 시드 %d\n" % [_days, _floor, _seed])
	print("| 모드 | 태그 종류 | 생활 종류 | 생활 | 탐험 | 전투 | 생활 비중 | 각인 | 생활 각인 | 평균 턴 |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	var full := {}
	for mode in ["combat", "field", "full"]:
		var row := _run_days(mode)
		if mode == "full":
			full = row
		var total: int = int(row["life"]) + int(row["field"]) + int(row["combat"])
		print("| %s | %d | %d | %d | %d | %d | %.0f%% | %d | %d | %.1f |" % [
			_mode_name(mode), int(row["kinds"]), int(row["life_kinds"]), int(row["life"]),
			int(row["field"]), int(row["combat"]),
			100.0 * float(row["life"]) / maxf(1.0, float(total)),
			int(row["engraved"]), int(row["life_engraved"]), float(row["turns"]) / float(_days)])
	if not full.is_empty():
		var names: Array = full["life_names"]
		if not names.is_empty():
			print("\n하루가 깨운 생활 기술: %s" % ", ".join(names))
	print("")


func _floors() -> void:
	print("## 2. 층별 생활 비중 — 하루 전체 · %d일\n" % _days)
	print("| 층 | 생활 종류 | 생활 | 탐험 | 전투 | 생활 비중 | 각인 | 생활 각인 | 수확/일 |")
	print("|---|---|---|---|---|---|---|---|---|")
	for floor_value in [1, 20, 40, 80]:
		var row := _run_days("full", floor_value)
		var total: int = int(row["life"]) + int(row["field"]) + int(row["combat"])
		print("| %d | %d | %d | %d | %d | %.0f%% | %d | %d | %d |" % [
			floor_value, int(row["life_kinds"]), int(row["life"]), int(row["field"]),
			int(row["combat"]), 100.0 * float(row["life"]) / maxf(1.0, float(total)),
			int(row["engraved"]), int(row["life_engraved"]),
			int(row["stores"]) / _days])
	print("")


func _one_day() -> void:
	## 한 사람의 하루 — 어떤 태그가 붙는지 눈으로 본다.
	print("## 3. 한 사람의 하루 (%d층 · 시드 %d)\n" % [_floor, _seed])
	var heroes := _party(_seed)
	FonsDay.renew(heroes)
	var day := FonsDay.new()
	day.start(_estate, _monsters, _biomes, _floor, _seed)
	var out := day.run(heroes)
	print("결과: %s · 조우 %d/%d · 턴 %d\n" % [
		String(out["winner"]), int(out["cleared"]), int(out["required"]), int(out["turns"])])
	print("| 영웅 | 성격 | 하루 태그 | 각인 |")
	print("|---|---|---|---|")
	for hero in heroes:
		if not FonsBrain.attached(hero):
			continue
		var brain: FonsBrain = hero["brain"]
		var parts: Array = []
		var tags: Array = brain.counters.keys()
		tags.sort_custom(func(a, b): return int(brain.counters[a]) > int(brain.counters[b]))
		for tag in tags:
			parts.append("%s %d" % [String(tag), int(brain.counters[tag])])
		print("| %s | %s | %s | %d |" % [
			String(hero.get("name", "?")), FonsPersonality.describe(_personalities, brain.identity),
			" · ".join(parts), brain.book.size()])
	print("")


func _run_days(mode: String, floor_value: int = -1) -> Dictionary:
	## `mode`: combat = 전투 한 판만 / field = 탐험 / full = 영지+탐험+저녁.
	## 브레인은 파티에 그대로 남아 카운터가 이어진다. 날마다 만전에서 시작한다 (`renew`).
	var at := _floor if floor_value < 0 else floor_value
	var heroes := _party(_seed)
	var turns := 0
	var stores := 0
	for d in _days:
		FonsDay.renew(heroes)
		var day_seed := _seed + d * 101
		if mode == "combat":
			var rng := RandomNumberGenerator.new()
			rng.seed = day_seed
			var out := FonsFloorRun.simulate(rng, _monsters, _biomes, at, 0, heroes)
			turns += int(out["turns"])
		else:
			var day := FonsDay.new()
			day.start(_estate, _monsters, _biomes, at, day_seed)
			var out := day.run(heroes, mode == "full")
			turns += int(out["turns"])
			stores += _store_total(out["stores"])
	var counters := _all_counters(heroes)
	var kinds := 0
	var life_kinds := 0
	var life := 0
	var field := 0
	var combat := 0
	for tag in counters:
		kinds += 1
		var n := int(counters[tag])
		if String(tag) in LIFE_TAGS:
			life += n
			life_kinds += 1
		elif String(tag) in FIELD_TAGS:
			field += n
		else:
			combat += n
	var engraved := 0
	var life_engraved := 0
	var life_names: Array = []
	for hero in heroes:
		if not FonsBrain.attached(hero):
			continue
		var brain: FonsBrain = hero["brain"]
		for id in brain.book:
			engraved += 1
			# "생활 각인" 은 **생활 태그가 조건에 들어간 기술**이다. 도메인만 보면 지식(관찰)처럼
			# 탐험에서도 나오는 기술이 섞여 수치가 부풀려진다 (2026-10-22 측정에서 발견).
			for tag in brain.book[id].get("tags", []):
				if String(tag) in LIFE_TAGS:
					life_engraved += 1
					var skill_name := String(brain.book[id].get("name", ""))
					if not skill_name in life_names:
						life_names.append(skill_name)
					break
	return {"kinds": kinds, "life_kinds": life_kinds, "life": life, "field": field,
		"combat": combat, "engraved": engraved, "life_engraved": life_engraved,
		"life_names": life_names, "turns": turns, "stores": stores}


func _all_counters(heroes: Array) -> Dictionary:
	var out := {}
	for hero in heroes:
		if not FonsBrain.attached(hero):
			continue
		for tag in hero["brain"].counters:
			out[tag] = int(out.get(tag, 0)) + int(hero["brain"].counters[tag])
	return out


func _store_total(stores: Dictionary) -> int:
	var n := 0
	for key in stores:
		n += int(stores[key])
	return n


func _party(seed_value: int) -> Array:
	var ai := {"personalities": _personalities, "profiles": _profiles,
		"catalog": _catalog, "legacy_pairs": _legacy}
	return FonsRunState.heroes_from(_races, _job_tree, _equipment, 7, 130, seed_value,
		_job_coef, 0, FonsRunState.PARTY_SIZE, ai)


func _mode_name(mode: String) -> String:
	match mode:
		"combat":
			return "전투만"
		"field":
			return "탐험만"
		_:
			return "하루 전체"


func _load(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/%s" % name, FileAccess.READ)
	if f == null:
		push_error("데이터를 열지 못했다: %s" % name)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
