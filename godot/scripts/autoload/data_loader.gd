extends Node
## Loads JSON SSOT from res://data/ (copied by tools/sync_data.py).
## Mirrors unity/Assets/Scripts/Data + fons-web-ver sync_web_data.py concept.

const DATA_DIR := "res://data"
var cache := {}

func load_json(file_name: String) -> Variant:
	if cache.has(file_name):
		return cache[file_name]
	var path := DATA_DIR.path_join(file_name)
	if not FileAccess.file_exists(path):
		push_error("missing data file: %s (run tools/sync_data.py)" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	cache[file_name] = parsed
	return parsed

func get_monsters() -> Variant:
	return load_json("monsters.json")

func get_biomes() -> Variant:
	return load_json("biomes.json")

func get_skills() -> Variant:
	return load_json("skills_catalog.json")
