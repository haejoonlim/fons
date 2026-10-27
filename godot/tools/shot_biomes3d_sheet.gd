extends SceneTree
## 26바이옴 실렌더 접합 시트 — `screenshots/biomes3d/*.png` 를 한 장에 늘어놓는다.
## `godot --path godot -s tools/shot_biomes3d_sheet.gd` (파일만 읽으므로 headless 로도 된다)
## 결과: `godot/screenshots/biomes3d_sheet.png`
## 칸 이름은 파일명 그대로 — 각 바이옴의 개별 원본은 `screenshots/biomes3d/` 에 남는다.

const SRC := "res://screenshots/biomes3d"
const OUT := "res://screenshots/biomes3d_sheet.png"
const CELL := Vector2(384.0, 216.0)
const GAP := 6.0
const MARGIN := 6.0
const HEADER := 40.0
const COLUMNS := 5


func _initialize() -> void:
	var files := _files()
	if files.is_empty():
		printerr("no shots in %s" % SRC)
		quit(1)
		return
	var rows := ceili(float(files.size()) / float(COLUMNS))
	var size := Vector2i(
		int(MARGIN * 2.0 + CELL.x * COLUMNS + GAP * (COLUMNS - 1)),
		int(HEADER + MARGIN * 2.0 + (CELL.y + 22.0) * rows + GAP * (rows - 1)))
	var view := SubViewport.new()
	view.size = size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var sheet := Control.new()
	sheet.size = Vector2(size)
	view.add_child(sheet)
	var back := ColorRect.new()
	back.color = Color(0.063, 0.063, 0.07)
	back.size = sheet.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(back)
	_label(sheet, "26바이옴 실렌더 — 구조 · 프롭 · 라이팅 (1280×720 씩)", Vector2(MARGIN, 8.0), 18)
	for i in files.size():
		_cell(sheet, i, files[i])
	for i in 3:
		await process_frame
	await _save(view)
	quit()


func _files() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(SRC)
	if dir == null:
		return out
	for name in dir.get_files():
		if name.ends_with(".png"):
			out.append(name)
	out.sort()
	return out


func _cell(sheet: Control, index: int, name: String) -> void:
	var at := Vector2(MARGIN + float(index % COLUMNS) * (CELL.x + GAP),
		HEADER + MARGIN + float(index / COLUMNS) * (CELL.y + 22.0 + GAP))
	var image := Image.load_from_file("%s/%s" % [SRC, name])
	if image == null:
		return
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = at
	rect.size = CELL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(rect)
	_label(sheet, name.get_basename().replace("_", " "), at + Vector2(3.0, CELL.y + 2.0), 13)


func _label(sheet: Control, text: String, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.91, 0.92, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(label)
	return label


func _save(view: SubViewport) -> void:
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty")
		return
	img.save_png(OUT)
	print("saved %s %dx%d" % [OUT, img.get_width(), img.get_height()])
