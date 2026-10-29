extends SceneTree
## 필드 사슬 측정 — 층 사이 **HP 를 이어받는** 경로를 잰다.
##
## `floor_report` 의 표는 층마다 만피로 영웅을 새로 만든다. 필드는 그렇지 않다:
## `FonsFieldState.next_floor` 는 "영웅 HP 는 이어진다 — 쉬어서 회복하는 규칙은 아직 없다"고 적는다.
## 상층 도달 가능성은 이쪽에서 갈린다 — 만피 표가 10승이어도 사슬에서는 106층에서 멈출 수 있다.
##
## 실행:
##   godot --headless --path godot -s tools/chain_report.gd
##   godot --headless --path godot -s tools/chain_report.gd -- --grades=5,7 --seeds=1,2,3 --party=5
##   godot --headless --path godot -s tools/chain_report.gd -- --from=101 --to=110 --bosses=115,118,120
##   godot --headless --path godot -s tools/chain_report.gd -- --to=125 --bosses=126,127,128,130 --heal=0.25
##   godot --headless --path godot -s tools/chain_report.gd -- --grades=5 --seeds=1,2,3 --to=125 --bosses=126,127,128,130 --memory=5:5 --party-tank=1 --party-heal=1 --party-shield=1
##   godot --headless --path godot -s tools/chain_report.gd -- --from=130 --to=129 --bosses=130 --turns=1200 --hero-atk=1.2
##
## `--memory=화력:생존` 은 101층에 닿을 때 그 파티에 한 번 건다 (`FonsRunState.apply_memory_to_party`).
## `--party-tank` · `--party-heal` · `--party-shield` 는 편성 최소 수다 — 게임과 같은 인자다.
## `--turns` 는 한 판 상한, `--hero-atk` 는 아군 화력만의 배율이다 — 둘 다 측정 순잡이·가드다.
## `--from` > `--to` 면 일반 조우는 건너뛰고 `--bosses` 만 친다 (한 층만 볼 때).
##
## 기본값은 101~110 일반 조우다. `--bosses` 를 주면 `--to` 를 통과한 파티가 그 층들을
## 문지기(`gatekeeper_for_floor`)로 차례로 친다 — 전환 뒤 경로를 볼 때 쓴다.
## `--heal` 은 층 승리 직후 살아 있는 영웅의 HP 를 `maxHp × 비율` 만큼 채운다(기본 0 = 현행).
## 게임 규칙이 아니라 **측정 손잡이**다 — `FonsFieldState.next_floor` 는 아직 회복하지 않는다.
## 조우는 접촉 0 만 친다. 필드는 한 층에 3곳을 다 쳐야 하므로 이 도구는 필드보다 **관대하다**.

var _grades: Array = [5, 7]
var _party := 5
var _seeds: Array = [1, 2, 3]
var _from := 101
var _to := 110
var _bosses: Array = []
var _heal := 0.0
## 측정용 — 101층 기억 배분. 사슬은 101층에 닿을 때 한 번 건다.
var _memory_attack := 0
var _memory_guard := 0
var _memory_done := false
## 편성 최소 수 — 게임 경로(`heroes_from`)와 같은 인자다. 0 이면 규칙 없음.
var _party_shield := 0
var _party_tank := 0
var _party_heal := 0
## 한 판 턴 상한 — 추이의 `FonsFloorRun.MAX_TURNS`(500)가 기본이다.
var _turns := FonsFloorRun.MAX_TURNS
## 측정용 — 아군 화력(ATK·MAG)만의 배율. HP·DEF 는 그대로다.
var _hero_atk := 1.0


func _initialize() -> void:
	var races: Dictionary = _load("races.json")
	var monsters: Variant = _load("monsters.json")
	var biomes: Variant = _load("biomes.json")
	var job_tree: Dictionary = _load("job_tree.json")
	var job_coef: Dictionary = _load("job_coef.json")
	var equipment: Dictionary = _load("equipment.json")
	var basics: Dictionary = _load("basic_attacks.json")
	var catalog: Array = _load("skills_catalog.json").get("skills", [])
	var ai := {
		"personalities": _load("personalities.json"),
		"profiles": _load("job_ai_profiles.json"),
		"catalog": {"skills": catalog},
		"legacy_pairs": _load("fusion_pairs.json"),
	}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grades="):
			_grades = _ints(arg.split("=", true, 1)[1])
		elif arg.begins_with("--seeds="):
			_seeds = _ints(arg.split("=", true, 1)[1])
		elif arg.begins_with("--party="):
			_party = int(arg.split("=")[1])
		elif arg.begins_with("--from="):
			_from = int(arg.split("=")[1])
		elif arg.begins_with("--to="):
			_to = int(arg.split("=")[1])
		elif arg.begins_with("--bosses="):
			_bosses = _ints(arg.split("=", true, 1)[1])
		elif arg.begins_with("--heal="):
			_heal = clampf(float(arg.split("=")[1]), 0.0, 1.0)
		elif arg.begins_with("--memory="):
			var kv := arg.split("=", true, 1)[1].split(":")
			if kv.size() == 2:
				_memory_attack = maxi(0, int(kv[0]))
				_memory_guard = maxi(0, int(kv[1]))
		elif arg.begins_with("--party-shield="):
			_party_shield = maxi(0, int(arg.split("=")[1]))
		elif arg.begins_with("--party-tank="):
			_party_tank = maxi(0, int(arg.split("=")[1]))
		elif arg.begins_with("--party-heal="):
			_party_heal = maxi(0, int(arg.split("=")[1]))
		elif arg.begins_with("--turns="):
			_turns = maxi(1, int(arg.split("=")[1]))
		elif arg.begins_with("--hero-atk="):
			_hero_atk = float(arg.split("=")[1])

	print("사슬 %d~%d · %d인 · 시드 %s · 턴 상한 %d · 회복 %.0f%% · 기억 %d:%d · 역할 수호%d/치유%d/보호막%d · 아군 화력 ×%.2f" % [
		_from, _to, _party, str(_seeds), _turns, _heal * 100.0,
		_memory_attack, _memory_guard, _party_tank, _party_heal, _party_shield, _hero_atk])
	for grade in _grades:
		for run_seed in _seeds:
			_memory_done = false
			var heroes := FonsRunState.heroes_from(races, job_tree, equipment, grade, 130,
				int(run_seed), job_coef, 0, _party, ai, basics,
				_party_shield, _party_tank, _party_heal)
			_scale_hero_atk(heroes)
			var rng := RandomNumberGenerator.new()
			var reached := _from - 1
			var stopped := ""
			for floor in range(_from, _to + 1):
				_apply_memory(heroes, floor)
				rng.seed = int(run_seed) * 31 + floor
				var out := FonsFloorRun.simulate(rng, monsters, biomes, floor, 0, heroes, _turns)
				_line("★%d seed%d" % [grade, run_seed], floor, "일반", out, heroes)
				if String(out.get("winner", "")) != "ally":
					stopped = "%d %s" % [floor, String(out.get("winner", "?"))]
					break
				reached = floor
				_heal_party(heroes)
			if stopped.is_empty() and not _bosses.is_empty():
				for floor in _bosses:
					rng.seed = int(run_seed) * 31 + int(floor)
					var out := FonsFloorRun.simulate_gatekeeper(rng, monsters, biomes, int(floor), heroes,
						_turns)
					_line("★%d seed%d" % [grade, run_seed], int(floor),
						String(out.get("gatekeeper", "")), out, heroes)
					if String(out.get("winner", "")) != "ally":
						stopped = "%d %s" % [int(floor), String(out.get("winner", "?"))]
						break
					reached = int(floor)
					_heal_party(heroes)
			var tail := "" if stopped.is_empty() else " · 정지 %s" % stopped
			# 시작 층에서 바로 지면 "도달 100" 처럼 범위 밖 값이 나온다 — 그건 "한 층도 못 넘음"이다.
			var where := "없음" if reached < _from else str(reached)
			print("도달 ★%d seed%d %s%s" % [grade, run_seed, where, tail])
	quit()


func _apply_memory(heroes: Array, floor: int) -> void:
	## 101층에 닿는 순간 한 번 — 게임과 같은 함수·같은 경계다. 두 번 걸면 배율이 겹친다.
	if _memory_done or _memory_attack + _memory_guard <= 0 or floor < FonsRunState.MEMORY_FLOOR:
		return
	FonsRunState.apply_memory_to_party(heroes, _memory_attack, _memory_guard)
	_memory_done = true


func _scale_hero_atk(heroes: Array) -> void:
	## 측정용 — 화력만 올린다. 층 상한(`--turns`)과 함께 "안 끝나는 판"과 "긴 판"을 가른다.
	if is_equal_approx(_hero_atk, 1.0):
		return
	for h in heroes:
		h["atk"] = float(h.get("atk", 0.0)) * _hero_atk
		h["mag"] = float(h.get("mag", 0.0)) * _hero_atk


func _heal_party(heroes: Array) -> void:
	## 층 승리 직후 회복 — 살아 있는 영웅만 채운다. 죽은 영웅은 안 살린다(부활은 다른 규칙이다).
	if _heal <= 0.0:
		return
	for h in heroes:
		if not bool(h.get("alive", false)):
			continue
		var top := int(h.get("maxHp", 0))
		h["hp"] = mini(top, int(h.get("hp", 0)) + int(roundf(float(top) * _heal)))


func _line(tag: String, floor: int, kind: String, out: Dictionary, heroes: Array) -> void:
	var alive := 0
	var hp := 0
	var max_hp := 0
	for h in heroes:
		hp += int(h.get("hp", 0))
		max_hp += int(h.get("maxHp", 0))
		if bool(h.get("alive", false)):
			alive += 1
	## 적에게 남은 HP — 상한에서 끝난 판이 "길었던 판"인지 "양쪽이 못 죽이는 판"인지 가른다.
	var e_hp := 0
	var e_max := 0
	for e in out.get("enemies", []):
		e_hp += int(e.get("hp", 0))
		e_max += int(e.get("maxHp", 0))
	print("%s %d %s %s %d %d/%d hp %d/%d · 적 hp %d/%d" % [tag, floor, kind,
		String(out.get("winner", "?")), int(out.get("turns", 0)), alive, heroes.size(), hp, max_hp,
		e_hp, e_max])


func _ints(text: String) -> Array:
	var out: Array = []
	for part in text.split(","):
		if not String(part).is_empty():
			out.append(int(part))
	return out


func _load(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/%s" % name, FileAccess.READ)
	if f == null:
		push_error("데이터를 열지 못했다: %s" % name)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
