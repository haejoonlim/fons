extends SceneTree
## 26바이옴 시트 — 심이 파생한 하늘·지평선·지면·식생/암석 색을 한 장에 늘어놓는다.
## `godot --path godot -s tools/shot_biome_sheet.gd` (렌더링이 필요하다 — headless 아님)
## 결과: `godot/screenshots/biome_tints.png`
##
## 왜 필요한가
## -----------
## 색은 26개라 눈으로 하나씩 볼 수 없다. 3D 로 26바이옴을 도는 것보다 **같은 조건의 판**에
## 나란히 놓는 편이 "하늘이 낮인가 · 바이옴끼리 갈라지는가"를 한눈에 보여 준다.
## 칸은 위에서부터 천정 → 지평선 헤이즈 그라데이, 아래는 지면색, 왼쪽 두 칸은 식생·암석 틴트다.
##
## 칸의 색은 팔레트 값(sRGB)을 **그대로** 칠한다. 실제 렌더는 하늘 재질이 선형광을 거치며
## 조금 밝아지므로 화면 픽셀과 1:1 은 아니다 — 이 시트는 바이옴 사이의 비교용이다.

const CELL := Vector2(268.0, 176.0)
const GAP := 8.0
const MARGIN := 16.0
const HEADER := 44.0
const COLUMNS := 5
const HEADER_TEXT := "26바이옴 — 하늘 · 지면 · 식생/암석 (FonsBiomePalette 파생값, sRGB)"


func _initialize() -> void:
	var biomes := _biomes()
	var rows := ceili(float(biomes.size()) / float(COLUMNS))
	# 창 크기에 기대지 않는다 — 화면보다 큰 시트는 잘린다. 전용 뷰포트에 그린다.
	var size := Vector2i(
		int(MARGIN * 2.0 + CELL.x * COLUMNS + GAP * (COLUMNS - 1)),
		int(HEADER + MARGIN * 2.0 + CELL.y * rows + GAP * (rows - 1)))
	var view := SubViewport.new()
	view.size = size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.transparent_bg = false
	root.add_child(view)
	var sheet := Control.new()
	sheet.size = Vector2(size)
	view.add_child(sheet)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.05, 0.06)
	back.size = sheet.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(back)
	_label(sheet, HEADER_TEXT, Vector2(MARGIN, 10.0), 18, Color(0.92, 0.93, 0.95))
	for i in biomes.size():
		_cell(sheet, i, biomes[i])
	for i in 4:
		await process_frame
	await _save(view, "res://screenshots/biome_tints.png")
	quit()


func _biomes() -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))
	var out: Array = []
	for group in data.get("groups", []):
		for biome in (group as Dictionary).get("biomes", []):
			out.append(biome)
	return out


func _cell(sheet: Control, index: int, biome: Dictionary) -> void:
	var col := index % COLUMNS
	var row := index / COLUMNS
	var at := Vector2(MARGIN + float(col) * (CELL.x + GAP),
		HEADER + MARGIN + float(row) * (CELL.y + GAP))
	var palette := FonsBiomePalette.from_biome(biome)
	var sky: Color = palette.get("sky", FonsBiomePalette.DEFAULT_SKY)
	var horizon: Color = Color.from_hsv(sky.h, sky.s * FonsView3D.SKY_HAZE_SATURATION,
		lerpf(sky.v, 1.0, FonsView3D.SKY_HAZE_MIX))
	var sky_rect := TextureRect.new()
	sky_rect.texture = _gradient(sky, horizon)
	sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_rect.position = at
	sky_rect.size = Vector2(CELL.x, 64.0)
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(sky_rect)
	var ground := ColorRect.new()
	ground.color = palette.get("ground", FonsBiomePalette.DEFAULT_GROUND)
	ground.position = at + Vector2(0.0, 64.0)
	ground.size = Vector2(CELL.x, CELL.y - 64.0)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(ground)
	var tints: Dictionary = palette.get("tints", {})
	_swatch(sheet, at + Vector2(10.0, 74.0), tints.get("grass", Color.TRANSPARENT))
	_swatch(sheet, at + Vector2(32.0, 74.0), tints.get("rock", Color.TRANSPARENT))
	var label := _label(sheet, "%02d %s" % [index + 1, String(biome.get("name", "?"))],
		at + Vector2(10.0, 96.0), 15, Color(0.96, 0.97, 0.98))
	label.size = Vector2(CELL.x - 20.0, 22.0)
	var climate: Dictionary = biome.get("climate", {})
	var sub := "%s · %d℃" % [String(biome.get("category", "")), int(climate.get("ambient", 15))]
	_label(sheet, sub, at + Vector2(10.0, 118.0), 12, Color(0.82, 0.85, 0.88))


func _gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([top, bottom])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 64
	return texture


func _swatch(sheet: Control, at: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = at
	rect.size = Vector2(18.0, 18.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(rect)


func _label(sheet: Control, text: String, at: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(label)
	return label


func _save(view: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty: %s" % path)
		return
	img.save_png(path)
	print("saved %s %dx%d" % [path, img.get_width(), img.get_height()])
