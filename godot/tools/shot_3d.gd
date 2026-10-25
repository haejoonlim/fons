extends SceneTree
## 3D 뷰 골격 검증 하네스 — `fons/view_mode` 를 3d 로 바꿔 main.tscn 을 띄운다.
## `godot --path godot -s tools/shot_3d.gd` (headless 아님 — 렌더링이 필요하다)
## 결과: `godot/screenshots/explore_3d.png`

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	ProjectSettings.set_setting("fons/view_mode", "3d")
	var packed := load("res://game/main/main.tscn") as PackedScene
	var node: Node = packed.instantiate()
	root.add_child(node)
	for i in 5:
		await process_frame
	if node._view == null:
		printerr("3D 뷰를 만들지 못했다 (mode=%s)" % FonsViewFactory.configured_mode())
		quit(1)
		return
	print("view=%s · entities=%d" % [node._view.get_class(), node._view.entity_count()])
	await _save("res://screenshots/explore_3d.png")
	quit()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty: %s" % path)
		return
	img.save_png(path)
	print("saved %s %dx%d" % [path, img.get_width(), img.get_height()])
