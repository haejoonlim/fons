extends SceneTree
## 임시 검증 하네스 — main.tscn 을 실제 창에 띄워 탐험 필드를 PNG 로 남긴다.
## `godot --path godot -s tools/shot_explore.gd` (headless 아님 — 렌더링이 필요하다)
## 결과: `godot/screenshots/explore_{contact,after_fight,retreat}.png`

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://game/main/main.tscn") as PackedScene
	var node: Node = packed.instantiate()
	root.add_child(node)
	for i in 4:
		await process_frame

	# ① 걸어서 첫 조우에 닿는다 — 순간이동이 아니라 `move` 의도로 실제 걷는다.
	# (게임에서 WASD 를 누르는 것과 같은 경로: 뷰 → intent → main → FonsFieldState.walk)
	var site: Dictionary = node._field.explore.sites[0]
	var delta: Vector2 = site["pos"] - node._field.explore.avatar
	node._on_intent(&"move", {"dir": delta.normalized()})
	node._process(delta.length() / FonsExplore.WALK_SPEED)
	node._on_intent(&"move", {"dir": Vector2.ZERO})
	print("walked to %s · contact=%d" % [str(node._field.explore.avatar), node._field.contact_index()])
	await _save("res://screenshots/explore_contact.png")

	# ② 스페이스 — 조우 전투. 지운 지점과 전투 로그가 남는다.
	node._on_intent(&"interact", {})
	for i in 3:
		await process_frame
	await _save("res://screenshots/explore_after_fight.png")

	# ③ R — 후퇴. 입구로 돌아가되 지운 조우는 남는다.
	node._on_intent(&"retreat", {})
	for i in 2:
		await process_frame
	await _save("res://screenshots/explore_retreat.png")
	print("saved 3 shots · cleared=%d" % node._field.explore.cleared)
	quit()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty: %s" % path)
		return
	img.save_png(path)
	print("saved %s %dx%d" % [path, img.get_width(), img.get_height()])
