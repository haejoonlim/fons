extends GutTest
## DataLoader 가 **실제 런타임 경로**(`res://data/`)로 데이터를 읽는지 잠근다.
##
## 왜 필요한가:
##   파이썬 게이트(`tools/check_docs.py`)는 `data/` 와 `godot/data/` 가 같은지만 본다.
##   "파일이 있다"와 "게임이 그 파일을 읽어 쓸 수 있다"는 다르다 — JSON 이 깨졌거나
##   매니페스트에 적힌 이름이 실제와 다르면 게이트는 초록인데 게임은 빈 데이터로 돈다.
##   DataLoader 는 파일이 없으면 `{}` 를 조용히 돌려주므로, 그 침묵을 테스트로 깬다.

const MANIFEST := "res://data/manifest.json"

func _manifest_files() -> Array:
	var text := FileAccess.get_file_as_string(MANIFEST)
	assert_ne(text, "", "manifest.json 을 읽지 못했다: " + MANIFEST)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "manifest.json 이 객체가 아니다")
	return parsed.get("files", []) if parsed is Dictionary else []

func test_manifest_is_readable() -> void:
	assert_true(FileAccess.file_exists(MANIFEST), "manifest.json 이 없다 — tools/sync_data.py")

func test_every_manifest_file_is_present() -> void:
	for name in _manifest_files():
		assert_true(FileAccess.file_exists("res://data/" + name),
			"manifest 에는 있는데 파일이 없다: " + name)

func test_every_manifest_file_parses() -> void:
	# JSON.parse_string 은 깨진 JSON 에서 null 을 돌려준다 — 게이트가 못 보는 자리다.
	for name in _manifest_files():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + name))
		assert_not_null(parsed, "JSON 이 깨졌다: " + name)

func test_loader_reads_monsters() -> void:
	var data: Variant = DataLoader.get_monsters()
	assert_true(data is Dictionary, "monsters.json 이 객체가 아니다")
	assert_true(data.has("monsters") and data["monsters"].size() > 0, "몬스터가 비었다")
	for m in data["monsters"].slice(0, 5):
		assert_true(m.has("id") and str(m["id"]) != "", "몬스터에 id 가 없다")
		assert_true(m.has("name") and str(m["name"]) != "", "몬스터에 name 이 없다: %s" % m.get("id", "?"))

func test_loader_reads_biomes() -> void:
	var data: Variant = DataLoader.get_biomes()
	assert_true(data is Dictionary and data.has("groups"), "biomes.json 에 groups 가 없다")
	assert_gt(data["groups"].size(), 0, "바이옴 그룹이 비었다")

func test_skills_count_matches_its_own_meta() -> void:
	# 숫자를 여기 박지 않는다 — 카탈로그가 스스로 적은 수와 실제 배열 길이가 같아야 한다.
	var data: Variant = DataLoader.get_skills()
	assert_true(data is Dictionary and data.has("skills"), "skills_catalog.json 에 skills 가 없다")
	var meta: Variant = data.get("meta", {})
	assert_true(meta is Dictionary and meta.has("count"), "skills_catalog.json meta.count 가 없다")
	assert_eq(data["skills"].size(), int(meta["count"]),
		"skills 배열 길이와 meta.count 가 다르다")

func test_loader_caches_by_file_name() -> void:
	# 같은 파일을 두 번 읽으면 같은 객체를 돌려주고, 캐시 키가 남아야 한다.
	var first: Variant = DataLoader.get_monsters()
	var second: Variant = DataLoader.get_monsters()
	assert_same(first, second, "두 번째 호출이 캐시가 아닌 새 객체를 돌려줬다")
	assert_true(DataLoader.cache.has("monsters.json"), "cache 에 키가 없다")
