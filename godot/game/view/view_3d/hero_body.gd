class_name FonsHeroBody
extends RefCounted
## 영웅 몸통 — 대역 3종(`hero_guard/scout/mystic.glb`)과 영웅별 색.
##
## 무엇이 정본인가
## ---------------
## 몸통은 **대역**이 정하고(`BANDS`), 영웅은 **색**이 가른다. 색은 뷰가 이미 나눠 준
## `asset_colors`(영웅 키별 색상각)를 그대로 받는다 — 여기서 새 색을 만들지 않는다.
##
## 대역 선택은 **직업 → 몸통 표**(`data/hero_assets.json`, 생성기 `tools/gen_hero_assets.py`)다.
## 직업 id 가 없는 키(`hero:<번호>`)만 키 해시로 고른다 — 같은 영웅이 판마다 다른 몸통을
## 입지 않는 것만 보장한다.
##
## 부품 이름 계약
## --------------
## 생성기(`tools/gen_hero_glb.py`)가 부품을 다섯 노드로 쓴다.
##
## | 노드 | 틴트 | 내용 |
## |---|---|---|
## | `body_hide` | 영웅 색 | 몸통·로브·어깨 |
## | `skin_limb` | 영웅 색 | 팔·다리·망토 |
## | `gear_metal` | 안 함 | 방패·지팡이·금속 띠 |
## | `gear_shine` | 안 함 | 방패 판·지팡이 보석 |
## | `eye_dark` | 안 함 | 눈 — 영웅 색이 눈까지 물들면 표정이 사라진다 |
##
## 색은 `set_surface_override_material` 로 **인스턴스마다** 갈아 끼운다. glTF 재질은
## 공유되므로 재질 자체를 고치면 같은 몸통을 쓴 모든 영웅이 같이 변한다.

const PREFIX := "hero:"
const BANDS := ["guard", "scout", "mystic"]
const PLANS := {
	"guard": "res://assets/art/models/hero_guard.glb",
	"scout": "res://assets/art/models/hero_scout.glb",
	"mystic": "res://assets/art/models/hero_mystic.glb",
}
const TINT_PREFIXES := ["body_", "skin_", "head_"]

static var _scenes: Dictionary = {}
## 직업 id → 대역. `data/hero_assets.json` 의 `jobs[]` 를 처음 한 번만 읽는다.
static var _job_bands: Dictionary = {}
static var _loaded := false


static func band_for(asset: String) -> String:
	## `hero:<job id>` 면 표를 따르고, `hero:<번호>` 처럼 표에 없으면 키 해시.
	## 키가 비면 빈 문자열(폴백 도형).
	var id := _id_of(asset)
	if id.is_empty():
		return ""
	var picked := String(_bands().get(id, ""))
	if BANDS.has(picked):
		return picked
	var sum := 0
	for i in id.length():
		sum += id.unicode_at(i)
	return BANDS[sum % BANDS.size()]


static func scene(band: String) -> PackedScene:
	if _scenes.has(band):
		return _scenes[band]
	var path := String(PLANS.get(band, ""))
	var packed: PackedScene = null
	if not path.is_empty() and ResourceLoader.exists(path):
		packed = load(path) as PackedScene
	_scenes[band] = packed
	return packed


static func has_body(asset: String) -> bool:
	return scene(band_for(asset)) != null


static func apply(instance: Node, color: Color) -> void:
	## 틴트 대상 부품만 영웅 색으로 덮는다. 재질은 인스턴스 전용이다.
	if instance == null:
		return
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		if not _tintable(String(mesh.name)):
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, material)


static func fade(instance: Node, alpha: float) -> void:
	## 카메라가 등에 붙었을 때 영웅을 흐린다. 지금 재질의 색을 읽어 알파만 바꾼 재질을
	## 노드 단위(`material_override`)로 건다 — 색은 지키고, 표면 덮개는 건드리지 않는다.
	##
	## `eye_dark` 에 표면 덮개를 걸면 헤드리스 더미 렌더러가 해제 중 `material is null`
	## 오류를 두 줄 찍는다 (직접 확인). 노드 덮개는 그 경로를 타지 않는다.
	if instance == null:
		return
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		if alpha <= 0.0:
			mesh.material_override = null
			continue
		var base := mesh.get_active_material(0) as StandardMaterial3D
		var material := StandardMaterial3D.new()
		var color := base.albedo_color if base != null else Color.WHITE
		color.a = 1.0 - clampf(alpha, 0.0, 1.0)
		material.albedo_color = color
		material.roughness = base.roughness if base != null else 0.8
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = material


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


static func _bands() -> Dictionary:
	if _loaded:
		return _job_bands
	_loaded = true
	var text := FileAccess.get_file_as_string("res://data/hero_assets.json")
	if text.is_empty():
		return _job_bands
	var doc: Variant = JSON.parse_string(text)
	if doc is Dictionary:
		for row in (doc as Dictionary).get("jobs", []):
			_job_bands[String((row as Dictionary).get("id", ""))] = String(
				(row as Dictionary).get("band", ""))
	return _job_bands


static func _tintable(name: String) -> bool:
	for prefix in TINT_PREFIXES:
		if name.begins_with(prefix):
			return true
	return false


static func _id_of(asset: String) -> String:
	return asset.substr(PREFIX.length()) if asset.begins_with(PREFIX) else asset
