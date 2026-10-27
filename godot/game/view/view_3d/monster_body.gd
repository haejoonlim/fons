class_name FonsMonsterBody
extends RefCounted
## 생물 몸통 — 대역 3종(`creature_heavy/small/odd.glb`)과 종별 색·크기 파생.
##
## 무엇이 정본인가
## ---------------
## 몸통은 **대역**이 정하고(`data/monster_assets.json` 의 `band`), 종은 **색과 크기**가
## 가른다. 원소는 `monsters.json` 의 `element`, 크기는 `tier`(+elite) 에서 나온다.
## 이 파일은 새 수치를 만들지 않는다 — 배율 상수만 이 파일이 정하고 테스트가 잠근다.
##
## 부품 이름 계약
## --------------
## 생성기(`tools/gen_monster_glb.py`)가 부품을 다섯 노드로 쓴다:
##
## | 노드 | 틴트 | 내용 |
## |---|---|---|
## | `body_hide` | 원소색 | 몸통·머리 |
## | `body_belly` | 원소색(어둡게) | 배 — 실루엣에 깊이를 준다 |
## | `skin_limb` | 원소색 | 다리·팔·꼬리 |
## | `horn_spike` | 안 함 | 뿔·가시·귀 — 구운 색 |
## | `eye_dark` | 안 함 | 눈 — 원소색이 눈까지 물들면 표정이 사라진다 |
##
## 색은 `set_surface_override_material` 로 **인스턴스마다** 갈아 끼운다. glTF 재질은
## 공유되므로 재질 자체를 고치면 같은 몸통을 쓰는 모든 개체가 같이 변한다.

const PREFIX := "monster:"
const PLANS := {
	"heavy": "res://assets/art/models/creature_heavy.glb",
	"small": "res://assets/art/models/creature_small.glb",
	"odd": "res://assets/art/models/creature_odd.glb",
}
const TINT_PREFIXES := ["body_", "skin_", "head_", "tail_"]
const BELLY := "body_belly"

## tier 1 → 0.85, tier 5 → 1.09. 같은 몸통이라도 깊은 층 개체가 크게 읽힌다.
const TIER_SCALE_BASE := 0.85
const TIER_SCALE_STEP := 0.06
## elite 는 같은 tier 에서 한 단계 더 크다 — 조우 화면에서 먼저 눈에 들어와야 한다.
const ELITE_SCALE := 0.12

## 원소 색상각. 채도·명도는 아래 두 상수가 정한다 — 색상만 데이터에서 온다.
const ELEMENT_HUE := {
	"fire": 0.02, "water": 0.56, "earth": 0.09, "wind": 0.42, "light": 0.13,
	"dark": 0.75, "nature": 0.30, "poison": 0.22, "void": 0.68, "none": 0.0,
}
const ELEMENT_SATURATION := 0.50
const ELEMENT_VALUE := 0.66

static var _picks: Dictionary = {}
static var _monsters: Dictionary = {}
static var _scenes: Dictionary = {}
## 역할 → 대역. `monster_assets.json` meta.bands 를 뒤집어 읽는다 (새 표를 만들지 않는다).
static var _role_bands: Dictionary = {}


static func band_for(asset: String) -> String:
	## `monster:<id>` 또는 `<id>` → 대역. 모르는 종이면 빈 문자열(폴백 도형).
	_ensure()
	return _band_of(_id_of(asset))


static func visual(asset: String) -> Dictionary:
	## 종 하나의 화면 파생값. 대역을 못 정하면 `{}` — 뷰는 지금의 폴백 도형을 쓴다.
	_ensure()
	var id := _id_of(asset)
	var band := _band_of(id)
	if band.is_empty() or not _monsters.has(id):
		return {}
	var monster: Dictionary = _monsters.get(id, {})
	var tier := clampi(int(monster.get("tier", 1)), 1, 5)
	var elite := bool((monster.get("spawn", {}) as Dictionary).get("elite", false))
	var scale := TIER_SCALE_BASE + TIER_SCALE_STEP * float(tier - 1)
	if elite:
		scale += ELITE_SCALE
	return {
		"id": id,
		"band": band,
		"color": element_color(String(monster.get("element", "none"))),
		"scale": scale,
	}


static func element_color(element: String) -> Color:
	var hue := float(ELEMENT_HUE.get(element, ELEMENT_HUE["none"]))
	var saturation := 0.0 if element == "none" else ELEMENT_SATURATION
	return Color.from_hsv(hue, saturation, ELEMENT_VALUE)


static func scene(band: String) -> PackedScene:
	if _scenes.has(band):
		return _scenes[band]
	var path := String(PLANS.get(band, ""))
	var packed: PackedScene = null
	if not path.is_empty() and ResourceLoader.exists(path):
		packed = load(path) as PackedScene
	_scenes[band] = packed
	return packed


static func apply(instance: Node, color: Color) -> void:
	## 인스턴스의 틴트 대상 부품만 원소색으로 덮는다. 재질은 인스턴스 전용이다.
	if instance == null:
		return
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var name := String(mesh.name)
		if not _tintable(name):
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = color.darkened(0.15) if name == BELLY else color
		material.roughness = 0.85
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, material)


static func height(instance: Node) -> float:
	## 인스턴스 안 메시의 최고점(로컬 유닛). HP 바 높이를 재는 데 쓴다.
	var top := 0.0
	if instance == null:
		return top
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		top = maxf(top, mesh.position.y + mesh.mesh.get_aabb().end.y)
	return top


static func _tintable(name: String) -> bool:
	for prefix in TINT_PREFIXES:
		if name.begins_with(prefix):
			return true
	return false


static func _band_of(id: String) -> String:
	## 바이옴 대표 3종(78칸)이 먼저다 — 손으로 고른 대역을 역할표가 덮지 않는다.
	var picked := String(_picks.get(id, ""))
	if not picked.is_empty():
		return picked
	## 나머지 종은 생태 역할로 대역을 고른다. 1~130층 실제 편성 121종 중 52종이 이 길이다 —
	## 이게 없으면 조우 화면에 회색 콘이 서서 몸통 규칙이 깨진다 (2026-10-27 실렌더).
	var monster: Dictionary = _monsters.get(id, {})
	if monster.is_empty():
		return ""
	var role := String((monster.get("ecology", {}) as Dictionary).get("role", ""))
	return String(_role_bands.get(role, ""))


static func _id_of(asset: String) -> String:
	return asset.substr(PREFIX.length()) if asset.begins_with(PREFIX) else asset


static func _ensure() -> void:
	if not _picks.is_empty():
		return
	var assets := _load_json("monster_assets.json")
	var bands: Dictionary = (assets.get("meta", {}) as Dictionary).get("bands", {})
	for band in bands:
		for role in (bands[band] as Array):
			_role_bands[String(role)] = String(band)
	for row in assets.get("biomes", []):
		for pick in (row as Dictionary).get("monsters", []):
			_picks[String(pick.get("id", ""))] = String(pick.get("band", ""))
	for monster in _load_json("monsters.json").get("monsters", []):
		_monsters[String((monster as Dictionary).get("id", ""))] = monster


static func _load_json(file_name: String) -> Dictionary:
	var text := FileAccess.get_file_as_string("res://data/" + file_name)
	if text.is_empty():
		return {}
	var doc: Variant = JSON.parse_string(text)
	return doc if doc is Dictionary else {}
