extends GutTest
## 세이브 — 왕복·화이트리스트·원자성·손상·버전.
##
## 이 파일이 잠그는 것:
##   · 저장 → 불러오기가 층·HP·생존·카운터·스킬북을 그대로 돌려준다
##   · 파일에 파생 값(전투 유닛·적·로그)이 새지 않는다
##   · 교체 실패가 기존 파일을 망치지 않는다
##   · 손상된 파일은 지우지 않고 격리하고, `.bak` 으로 한 번 복구한다
##   · 더 새 `schema` 는 읽지 않고 파일을 건드리지 않는다

const SLOT := "test_slot.json"


func before_each() -> void:
	SaveManager.erase(SLOT)


func after_each() -> void:
	SaveManager.erase(SLOT)
	var tmp := SaveManager.path_of(SLOT) + ".tmp"
	if DirAccess.dir_exists_absolute(tmp):
		DirAccess.remove_absolute(tmp)


func _ai() -> Dictionary:
	return {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}


func _configure(run: FonsRunState, seed_value: int) -> void:
	run.configure(DataLoader.load_json("races.json"), DataLoader.get_monsters(),
		DataLoader.get_biomes(), seed_value, 1, DataLoader.load_json("job_tree.json"),
		DataLoader.load_json("equipment.json"), DataLoader.load_json("job_coef.json"),
		_ai(), DataLoader.load_json("basic_attacks.json"))


func _run(seed_value: int = 265) -> FonsRunState:
	var run := FonsRunState.new()
	_start(run, seed_value)
	return run


func _start(run: FonsRunState, seed_value: int) -> void:
	run.start(DataLoader.load_json("races.json"), DataLoader.get_monsters(),
		DataLoader.get_biomes(), seed_value, 1, DataLoader.load_json("job_tree.json"),
		DataLoader.load_json("equipment.json"), DataLoader.load_json("job_coef.json"),
		_ai(), DataLoader.load_json("basic_attacks.json"))


func _restored(saved: Dictionary) -> FonsRunState:
	var run := FonsRunState.new()
	_configure(run, int(String(saved["seed"])))
	assert_true(run.restore(saved), "복원은 성공해야 한다")
	return run


func _payload(seed_value: int) -> Dictionary:
	var estate := FonsEstate.new()
	estate.start(DataLoader.load_json("estate.json"), 1)
	estate.clock_epoch = 1000
	estate.last_settled_day = 1
	return FonsSave.to_dict(_run(seed_value).to_save(), estate.to_save(),
		{"gold": 10, "pull_count": 2}, "2026-10-24T00:00:00")


func test_save_roundtrip() -> void:
	var run := _run(265)
	var back := _restored(run.to_save())
	assert_eq(back.floor, run.floor, "층이 같다")
	assert_eq(back.heroes.size(), run.heroes.size(), "영웅 수가 같다")
	for i in run.heroes.size():
		var before: Dictionary = run.heroes[i]
		var after: Dictionary = back.heroes[i]
		assert_eq(int(after["hp"]), int(before["hp"]), "%d번 HP" % i)
		assert_eq(bool(after["alive"]), bool(before["alive"]), "%d번 생존" % i)
		assert_eq(String(after["job_id"]), String(before["job_id"]), "%d번 직업" % i)
		if FonsBrain.attached(before):
			assert_true(FonsBrain.attached(after), "%d번 판단이 붙어 있다" % i)
			var a: FonsBrain = after["brain"]
			var b: FonsBrain = before["brain"]
			assert_eq(a.counters, b.counters, "%d번 행동 카운터" % i)
			assert_eq(a.book.size(), b.book.size(), "%d번 스킬북 수" % i)
			assert_eq(a.identity, b.identity, "%d번 성격" % i)


func test_field_save_roundtrip() -> void:
	## 실제 게임이 도는 심은 `FonsFieldState` 다 — 타이틀 이어하기가 이 길로 들어온다.
	var field := FonsFieldState.new()
	field.start(DataLoader.load_json("races.json"), DataLoader.get_monsters(),
		DataLoader.get_biomes(), 265, FonsFieldState.START_FLOOR,
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		DataLoader.load_json("job_coef.json"), _ai(), DataLoader.load_json("basic_attacks.json"))
	var back := FonsFieldState.new()
	back.configure(DataLoader.load_json("races.json"), DataLoader.get_monsters(),
		DataLoader.get_biomes(), 265, FonsFieldState.START_FLOOR,
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		DataLoader.load_json("job_coef.json"), _ai(), DataLoader.load_json("basic_attacks.json"))
	assert_true(back.restore(field.to_save()), "필드 복원 성공")
	assert_eq(back.floor, field.floor, "층")
	assert_eq(int(back.heroes[0]["hp"]), int(field.heroes[0]["hp"]), "HP")
	assert_eq(back.heroes[0]["brain"].counters, field.heroes[0]["brain"].counters, "카운터")
	assert_eq(back.explore.cleared, 0, "조우는 저장하지 않고 층 시작에서 다시 만든다")


func test_save_whitelist() -> void:
	# 파생(전투 유닛·적·로그·스냅샷)이 파일에 새면 밸런스 수정이 구세이브에 닿지 않는다.
	var payload := _payload(7)
	for key in payload.keys():
		assert_true(String(key) in FonsSave.TOP_KEYS, "최상위 키 %s" % key)
	for key in payload["run"].keys():
		assert_true(String(key) in FonsSave.RUN_KEYS, "run 키 %s" % key)
	for key in payload["estate"].keys():
		assert_true(String(key) in FonsSave.ESTATE_KEYS, "estate 키 %s" % key)
	for hero in payload["run"]["heroes"]:
		for key in hero.keys():
			assert_true(String(key) in FonsSave.HERO_KEYS, "hero 키 %s" % key)
	assert_false(payload.has("enemies"), "적 목록은 저장하지 않는다")
	assert_false(payload.has("log"), "로그는 저장하지 않는다")


func test_save_atomic_keeps_original() -> void:
	assert_true(bool(SaveManager.save_payload(_payload(9), SLOT)["ok"]))
	var before := FileAccess.get_file_as_string(SaveManager.path_of(SLOT))
	# 임시 파일 자리를 폴더로 막아 쓰기를 실패시킨다 — 기존 파일은 손대지 않아야 한다.
	DirAccess.make_dir_recursive_absolute(SaveManager.path_of(SLOT) + ".tmp")
	var result := SaveManager.save_payload(_payload(11), SLOT)
	assert_false(bool(result["ok"]), "쓰기 실패를 숨기지 않는다")
	assert_eq(FileAccess.get_file_as_string(SaveManager.path_of(SLOT)), before, "본파일 그대로")


func test_save_corrupt_quarantines_and_recovers() -> void:
	SaveManager.save_payload(_payload(7), SLOT)
	SaveManager.save_payload(_payload(8), SLOT)   # .bak 에 7번이 남는다
	var path := SaveManager.path_of(SLOT)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"schema\": 1, \"run\"")
	file.close()
	var loaded := SaveManager.load_payload(SLOT)
	assert_eq(String(loaded["status"]), "recovered", "백업으로 한 번 복구한다")
	assert_eq(String(loaded["data"]["run"]["seed"]), "7", "복구된 것은 이전 저장이다")
	assert_true(_corrupt_aside(path), "손상 파일은 지우지 않고 옆으로 옮긴다")


func test_save_migrates_old_shape() -> void:
	var result := FonsSave.migrate({"run": {"seed": "5", "floor": 3}})
	assert_eq(String(result["status"]), "ok")
	assert_eq(int(result["data"]["schema"]), 1, "schema 1 로 올라온다")
	assert_true(result["data"]["wallet"] is Dictionary, "빠진 칸은 기본값")
	assert_true(result["data"]["estate"] is Dictionary)


func test_save_newer_keeps_file() -> void:
	var path := SaveManager.path_of(SLOT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"schema\": 99}")
	file.close()
	var before := FileAccess.get_file_as_string(path)
	var loaded := SaveManager.load_payload(SLOT)
	assert_eq(String(loaded["status"]), "newer", "더 새 판은 거부한다")
	assert_eq(FileAccess.get_file_as_string(path), before, "파일을 고치지 않는다")


func test_save_load_save_is_stable() -> void:
	var once := _run(265).to_save()
	var twice := _restored(once).to_save()
	assert_eq(twice, once, "저장 → 복원 → 저장이 같은 사전이어야 한다")


func _corrupt_aside(path: String) -> bool:
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	for name in dir.get_files():
		if name.contains(".corrupt-"):
			return true
	return false
