extends SceneTree
## 엔딩 화면 검증 하네스 — 130층 격파 상태를 만들어 HUD 위 엔딩 화면을 PNG 로 남긴다.
## `godot --path godot -s tools/shot_ending.gd` (headless 아님 — 렌더링이 필요하다)
## 결과: `godot/screenshots/ending_panel.png`
##
## 실제 문지기 전투는 ★7 파티가 필요해 상태를 직접 만든다 — 화면 배치만 보는 하네스다.

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://game/main/main.tscn") as PackedScene
	var node: Node = packed.instantiate()
	root.add_child(node)
	for i in 4:
		await process_frame

	node._field.floor = FonsFieldState.MAX_FLOOR
	node._field.ending = true
	node._field.last_gatekeeper = {"name": "무문의 파수병", "turns": 82, "survivors": 4,
		"loot": {"soul": ["최상"], "gold": 6000, "exp": 1200}}
	node._push()
	for i in 2:
		await process_frame
	var panel: Control = node.get_node_or_null("Hud/EndingPanel")
	if panel == null or not panel.visible:
		printerr("엔딩 화면이 뜨지 않았다")
		quit(1)
		return
	print("ending line: %s" % node._ending_line.text)
	await _save("res://screenshots/ending_panel.png")
	quit()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty: %s" % path)
		return
	img.save_png(path)
	print("saved %s %dx%d" % [path, img.get_width(), img.get_height()])
