class_name FonsViewFactory
extends RefCounted
## 2D/3D 선택 지점 — 프로젝트에서 여기 한 곳만 모드 문자열을 안다.
##
## 다른 코드가 `mode == "3d"` 같은 분기를 하면 3D 전환 비용이 그 파일로 번진다.
## 새 뷰를 추가하려면 SCENES 에 경로 한 줄만 넣는다.

const SETTING := "fons/view_mode"
const DEFAULT_MODE := "2d"

const SCENES := {
	"2d": "res://game/view/view_2d/view_2d.tscn",
	"3d": "res://game/view/view_3d/view_3d.tscn",
}


static func scene_path(mode: String) -> String:
	return String(SCENES.get(mode, ""))


static func available_modes() -> PackedStringArray:
	var out := PackedStringArray()
	for mode in SCENES:
		if ResourceLoader.exists(SCENES[mode]):
			out.append(mode)
	return out


static func configured_mode() -> String:
	var mode := String(ProjectSettings.get_setting(SETTING, DEFAULT_MODE))
	return DEFAULT_MODE if mode.is_empty() else mode


static func create(mode: String = "") -> FonsView:
	var wanted := mode if not mode.is_empty() else configured_mode()
	var path := scene_path(wanted)
	# 씬이 없으면 null — 호출자가 폴백 여부를 정한다. 조용히 2D 로 바꾸지 않는다.
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate()
	if node is FonsView:
		return node as FonsView
	push_error("뷰 씬 루트가 FonsView 가 아니다: %s" % path)
	node.queue_free()
	return null
