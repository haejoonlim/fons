extends SceneTree
## 영웅 AI 리포트 — "이 사람이 진짜 사람처럼 구는가"를 숫자로 남긴다.
##
## 실행:
##   godot --headless --path godot -s tools/brain_report.gd
##   godot --headless --path godot -s tools/brain_report.gd -- --floors=60
##
## 이 도구가 답하는 질문 넷:
##   1. 같은 직업 쌍둥이가 성격 때문에 **다르게** 행동하는가 (행동 분포 + 분화율)
##   2. 반복이 스킬이 되는가 (행동 수 → 각인 수 곡선)
##   3. 융합이 **드물게** 일어나는가 (흔하면 특별하지 않고, 0이면 죽은 시스템이다)
##   4. 한 판이 결정론적인가 (같은 시드 두 번 → 같은 로그)
##
## 게임 코드가 아니라 측정 도구다. 수치를 여기서 정하지 않는다.

const TWIN_RUNS := 400
const ENGRAVE_STEPS := [50, 150, 300, 600, 1000]

var _races: Dictionary
var _monsters: Variant
var _biomes: Variant
var _job_tree: Dictionary
var _job_coef: Dictionary
var _equipment: Dictionary
var _catalog: Dictionary
var _personalities: Dictionary
var _profiles: Dictionary
var _legacy: Dictionary
var _basics: Dictionary
var _floors := 40


func _initialize() -> void:
	_races = _load("races.json")
	_monsters = _load("monsters.json")
	_biomes = _load("biomes.json")
	_job_tree = _load("job_tree.json")
	_job_coef = _load("job_coef.json")
	_equipment = _load("equipment.json")
	_catalog = _load("skills_catalog.json")
	_personalities = _load("personalities.json")
	_profiles = _load("job_ai_profiles.json")
	_legacy = _load("fusion_pairs.json")
	_basics = _load("basic_attacks.json")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--floors="):
			_floors = int(arg.split("=")[1])

	_twins()
	_engrave_curve()
	_live_run()
	quit()


func _ai() -> Dictionary:
	return {"personalities": _personalities, "profiles": _profiles,
		"catalog": _catalog, "legacy_pairs": _legacy}


func _twins() -> void:
	## 같은 직업·같은 후보·같은 상황 — 성격만 바꾼 쌍둥이.
	print("## 1. 쌍둥이 분화 — 같은 직업(%s), 성격만 다르다 (%d판)\n" % ["파쇄사", TWIN_RUNS])
	print("| 왼쪽 | 오른쪽 | 공격 | 방어·제어 | 기동 | 지원 | 분화율 |")
	print("|---|---|---|---|---|---|---|")
	var pairs := [
		["난폭", ["격정", "충동"], "신중", ["관조", "침울"]],
		["용감", ["대담", "직설"], "냉정", ["명석", "이성"]],
		["헌신", ["다정", "온후"], "무자비", ["정복욕", "야망"]],
	]
	for pair in pairs:
		var left := _brain(pair[0], pair[1], 41)
		var right := _brain(pair[2], pair[3], 42)
		var l := _decide_many(left, TWIN_RUNS)
		var r := _decide_many(right, TWIN_RUNS)
		var split := 0
		for tag in l:
			split += absi(int(l[tag]) - int(r.get(tag, 0)))
		# 공격/방어 같은 **도메인** 비중으로 잰다 — 기술을 배우면 맨손 공격은 줄지만
		# 공격적인 사람은 계속 공격 기술을 쓴다. 태그로 재면 "기술을 배웠나"가 섞인다.
		print("| %s | %s | %.0f%% vs %.0f%% | %.0f%% vs %.0f%% | %.0f%% vs %.0f%% | %.0f%% vs %.0f%% | %d%% |" % [
			String(pair[0]), String(pair[2]),
			100.0 * float(l.get("공격", 0)) / TWIN_RUNS, 100.0 * float(r.get("공격", 0)) / TWIN_RUNS,
			100.0 * float(l.get("방어·제어", 0)) / TWIN_RUNS, 100.0 * float(r.get("방어·제어", 0)) / TWIN_RUNS,
			100.0 * float(l.get("기동", 0)) / TWIN_RUNS, 100.0 * float(r.get("기동", 0)) / TWIN_RUNS,
			100.0 * float(l.get("지원", 0)) / TWIN_RUNS, 100.0 * float(r.get("지원", 0)) / TWIN_RUNS,
			split * 100 / (TWIN_RUNS * 2),
		])
	print("")


func _engrave_curve() -> void:
	## 같은 행동을 계속하면 스킬이 몇 개 생기는가. 각인 50% 판정이라 곡선이 계단식이다.
	print("## 2. 반복 → 각인 곡선 (같은 태그만 계속 · 평균 %d회)\n" % 20)
	print("| 행동 수 | 각인 수 | 연계 종류 |")
	print("|---|---|---|")
	for step in ENGRAVE_STEPS:
		var total_book := 0
		var total_links := 0
		for i in 20:
			var b := _brain("성실", ["근면", "꾸준"], 100 + i)
			for n in step:
				b.commit({"action": "공격", "tag": "근접타격", "domain": "공격"})
				if n % 3 == 0:
					b.commit({"action": "정찰", "tag": "정찰", "domain": "기동"})
			total_book += b.book.size()
			total_links += b.links.size()
		print("| %d | %.1f | %.1f |" % [step, float(total_book) / 20.0, float(total_links) / 20.0])
	print("")


func _live_run() -> void:
	## 실제 런 — 층을 올라가며 영웅이 자란다. 여기서만 카운터가 이어진다.
	print("## 3. 실제 런 — %d층 (시드 3개 평균)\n" % _floors)
	print("| 시드 | 도달 층 | 생존 | 각인 합 | 융합 합 | 새 기술 로그 |")
	print("|---|---|---|---|---|---|")
	for seed_value in [11, 22, 33]:
		var st := FonsRunState.new()
		st.start(_races, _monsters, _biomes, seed_value, 1, _job_tree, _equipment, _job_coef, _ai(), _basics)
		var guard := 0
		while st.winner == "ally" and st.floor < _floors and guard < _floors + 5:
			guard += 1
			if not st.next_floor():
				break
		var books := 0
		var fusions := 0
		var born := 0
		for h in st.heroes:
			if not FonsBrain.attached(h):
				continue
			books += h["brain"].book.size()
			fusions += h["brain"].fusions.size()
			born += h["brain"].born.size()
		print("| %d | %d | %d/%d | %d | %d | %d |" % [
			seed_value, st.floor, st.party_alive(), st.heroes.size(), books, fusions, born])
	print("")

	print("### 영웅별 정체 (시드 11 · 마지막 층)\n")
	var st2 := FonsRunState.new()
	st2.start(_races, _monsters, _biomes, 11, 1, _job_tree, _equipment, _job_coef, _ai(), _basics)
	var guard2 := 0
	while st2.winner == "ally" and st2.floor < _floors and guard2 < _floors + 5:
		guard2 += 1
		if not st2.next_floor():
			break
	print("| 자리 | 직업 | 성격 3키워드 | 많이 한 행동 | 각인 | 연계 |")
	print("|---|---|---|---|---|---|")
	for i in st2.heroes.size():
		var h: Dictionary = st2.heroes[i]
		var line := "| %d | %s |" % [i + 1, String(h.get("job", "?"))]
		if not FonsBrain.attached(h):
			print(line + " (브레인 없음) | | | |")
			continue
		var b: FonsBrain = h["brain"]
		var top_tag := "-"
		var top_n := 0
		for tag in b.counters:
			if int(b.counters[tag]) > top_n:
				top_n = int(b.counters[tag])
				top_tag = "%s %d" % [String(tag), top_n]
		print("| %d | %s | %s | %s | %d | %d |" % [
			i + 1, String(h.get("job", "?")), FonsPersonality.describe(_personalities, b.identity),
			top_tag, b.book.size(), b.links.size()])


func _brain(main: String, subs: Array, seed_value: int) -> FonsBrain:
	var b := FonsBrain.new()
	var profile: Dictionary = _profiles.get("profiles", {}).get("l2_breaker", {})
	b.setup({"main": main, "subs": subs, "seed": seed_value}, _personalities, profile, "선봉",
		_catalog.get("skills", []), seed_value)
	return b


func _decide_many(b: FonsBrain, runs: int) -> Dictionary:
	## 상황을 섞는다 — 사람의 개성은 **만피 평지**가 아니라 저체력·아군부상·야간에서 드러난다.
	## 한 상황만 주면 모두가 "공격"을 골라 분화가 0 에 가깝게 나온다 (측정 설계의 함정).
	var counts := {}
	var scenes := [
		{"hp_ratio": 1.0, "party_avg": {"ATK": 100.0}, "enemy_count": 3},
		{"hp_ratio": 0.25, "party_avg": {"ATK": 100.0}, "enemy_count": 3},
		{"hp_ratio": 0.8, "party_avg": {"ATK": 100.0}, "enemy_count": 2, "ally_hurt": true},
		{"hp_ratio": 0.9, "party_avg": {"ATK": 100.0}, "enemy_count": 4, "night": true},
		{"hp_ratio": 0.5, "party_avg": {"ATK": 100.0}, "enemy_count": 1, "enemy_low": true, "boss": true},
	]
	for i in runs:
		var ctx: Dictionary = scenes[i % scenes.size()]
		var chosen := b.decide(_candidates(), ctx)
		var domain := String(chosen.get("domain", "?"))
		counts[domain] = int(counts.get(domain, 0)) + 1
		b.commit(chosen)
	return counts


func _candidates() -> Array:
	return [
		{"action": "공격", "tag": "근접타격", "domain": "공격", "stat": "ATK", "stat_value": 100.0},
		{"action": "방어", "tag": "방어태세", "domain": "방어·제어"},
		{"action": "치유", "tag": "치유", "domain": "지원"},
		{"action": "정찰", "tag": "정찰", "domain": "기동"},
		{"action": "후퇴", "tag": "후퇴", "domain": "기동"},
		{"action": "매복", "tag": "매복", "domain": "기동"},
	]


func _load(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/%s" % name, FileAccess.READ)
	if f == null:
		push_error("데이터를 열지 못했다: %s" % name)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
