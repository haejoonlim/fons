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

	print("사슬 %d~%d · %d인 · 시드 %s · 턴 상한 %d · 회복 %.0f%%" % [_from, _to, _party, str(_seeds),
		FonsFloorRun.MAX_TURNS, _heal * 100.0])
	for grade in _grades:
		for run_seed in _seeds:
			var heroes := FonsRunState.heroes_from(races, job_tree, equipment, grade, 130,
				int(run_seed), job_coef, 0, _party, ai, basics)
			var rng := RandomNumberGenerator.new()
			var reached := _from - 1
			var stopped := ""
			for floor in range(_from, _to + 1):
				rng.seed = int(run_seed) * 31 + floor
				var out := FonsFloorRun.simulate(rng, monsters, biomes, floor, 0, heroes)
				_line("★%d seed%d" % [grade, run_seed], floor, "일반", out, heroes)
				if String(out.get("winner", "")) != "ally":
					stopped = "%d %s" % [floor, String(out.get("winner", "?"))]
					break
				reached = floor
				_heal_party(heroes)
			if stopped.is_empty() and not _bosses.is_empty():
				for floor in _bosses:
					rng.seed = int(run_seed) * 31 + int(floor)
					var out := FonsFloorRun.simulate_gatekeeper(rng, monsters, biomes, int(floor), heroes)
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
	print("%s %d %s %s %d %d/%d hp %d/%d" % [tag, floor, kind,
		String(out.get("winner", "?")), int(out.get("turns", 0)), alive, heroes.size(), hp, max_hp])


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
