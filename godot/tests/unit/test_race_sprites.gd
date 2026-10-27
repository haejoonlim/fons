extends GutTest
## 종족 스프라이트 시트 — MPFB 로 만든 14종 × 6칸이 계약대로 로드되는가.
##
## 계약은 각 `<key>.json` 이 스스로 밝힌다: 96px 칸 6개, 576×96 시트, 1유닛 48px.
## 시트를 만든 쪽(`FONS_Character_Assets/export/mpfb_sprite.py`)과 읽는 쪽이
## 다른 폴더라, 이름·칸 좌표가 어긋나면 여기서만 잡힌다.

const DIR := "res://assets/art/sprites/races/mpfb"
const FRAMES := ["idle", "walk_a", "walk_b", "attack_a", "attack_b", "point"]
const FRAME := 96
const UNIT := 48
const RACES := 14


func _sheets() -> Array:
	var names := []
	var d := DirAccess.open(DIR)
	assert_not_null(d, "시트 폴더가 없다: " + DIR)
	if d == null:
		return names
	for f in d.get_files():
		if f.ends_with(".json"):
			names.append(f.get_basename())
	names.sort()
	return names


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	return data if data is Dictionary else {}


func test_fourteen_races_have_a_sheet() -> void:
	assert_eq(_sheets().size(), RACES)
	for key in _sheets():
		assert_true(FileAccess.file_exists(DIR + "/" + key + ".png"), key + " png 짝이 없다")


func test_each_sheet_loads_as_576x96_texture() -> void:
	for key in _sheets():
		var tex := load(DIR + "/" + key + ".png") as Texture2D
		assert_not_null(tex, key + ".png 가 로드되지 않는다")
		if tex == null:
			continue
		assert_eq(tex.get_width(), FRAME * FRAMES.size(), key + " 폭")
		assert_eq(tex.get_height(), FRAME, key + " 높이")


func test_meta_slices_six_frames_inside_the_sheet() -> void:
	for key in _sheets():
		var meta := _read_json(DIR + "/" + key + ".json")
		assert_false(meta.is_empty(), key + ".json 이 안 열린다")
		if meta.is_empty():
			continue
		assert_eq(meta.get("columns"), FRAMES.size(), key + " 칸 수")
		assert_eq(meta.get("pixels_per_unit"), UNIT, key + " 픽셀 밀도")
		var sheet_w := int(meta["frame_size"]["w"]) * FRAMES.size()
		var sheet_h := int(meta["frame_size"]["h"])
		var frames: Array = meta.get("frames", [])
		assert_eq(frames.size(), FRAMES.size(), key + " 프레임 수")
		for i in frames.size():
			var fr: Dictionary = frames[i]
			assert_eq(fr["name"], FRAMES[i], "%s %d번 칸 이름" % [key, i])
			assert_eq(fr["x"], i * FRAME, "%s %d번 칸 x" % [key, i])
			assert_true(fr["x"] + fr["w"] <= sheet_w, "%s %d번 칸이 시트 밖" % [key, i])
			assert_true(fr["y"] + fr["h"] <= sheet_h, "%s %d번 칸이 시트 위로 넘친다" % [key, i])


func test_frame_rect_is_usable_as_atlas_region() -> void:
	# 칸 좌표가 숫자로만 맞고 실제로 잘라 쓸 수 없으면 게임에서 빈 스프라이트가 된다.
	var key := "race_genasi_03"
	var tex := load(DIR + "/" + key + ".png") as Texture2D
	assert_not_null(tex)
	if tex == null:
		return
	var meta := _read_json(DIR + "/" + key + ".json")
	for fr in meta.get("frames", []):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(fr["x"], fr["y"], fr["w"], fr["h"])
		assert_eq(at.get_width(), FRAME, "%s 칸 폭" % fr["name"])
		assert_eq(at.get_height(), FRAME, "%s 칸 높이" % fr["name"])
		# 잘린 칸이 투명뿐이면 그 프레임은 비어 있다.
		var img: Image = tex.get_image().get_region(Rect2i(fr["x"], fr["y"], fr["w"], fr["h"]))
		var painted := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					painted += 1
		assert_gt(painted, 200, "%s/%s 에 그림이 거의 없다" % [key, fr["name"]])
