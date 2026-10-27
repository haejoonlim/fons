extends SceneTree
## 지평선 검수 하네스 — 아주 먼 프롭이 하늘보다 밝게 남아 옅은 실루엣으로 뜨는지 본다.
## `godot --path godot --fixed-fps 60 -s tools/shot_horizon.gd` (창 모드 — headless 아님)
##
## 트인 자리로 걸어가(0, 15) 네 방향을 찍어 `screenshots/horizon_check/` 에 남긴다.
## 판정은 **눈**이다 — 2026-10-26 「4방향 검수」와 같은 자·같은 기준.
## 수치 보조를 붙여 봤지만 지평선 검출이 탑·HUD 에 걸린다(행 분산으로 찾으면 탑에서
## 일찍 걸리고, 화면 좌표로 계산하면 피치 가정이 틀린다). 숫자는 도구를 안 믿는다.
##
## 배경 — 프롭은 안개 span 의 `KIT_CULL_RATIO`(0.762 = 79% 젖는 자리)에서 꺼진다.
## 그 전에는 100%(안개 끝)까지 두어 지평선 위에 옅은 실루엣이 떴다(2026-10-26).
## 이 하네스는 그 자리가 실제로 비었는지 다시 보는 몫이다.
const OUT_DIR := "res://screenshots/horizon_check"
const YAWS := [0, 90, 180, 270]


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	ProjectSettings.set_setting("fons/view_mode", "3d")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var node: Node = (load("res://game/main/main.tscn") as PackedScene).instantiate()
	root.add_child(node)
	for i in 5:
		await process_frame
	var view: Node = node._view
	if view == null:
		printerr("3D 뷰를 만들지 못했다")
		quit(1)
		return
	view.set_mouse_capture(false)
	# 트인 남쪽으로 걷는다 — 탑·광장 프롭에서 멀어져야 먼 프롭이 화면에 든다.
	var walked := 0
	node._on_intent("move", {"dir": Vector2(0, 1)})
	while node._field.explore.avatar.y < 15.0 and walked < 200:
		view.set_mouse_capture(false)
		await process_frame
		walked += 1
	node._on_intent("move", {"dir": Vector2.ZERO})
	print("자리 (%.1f, %.1f) · 걷기 %d프레임 · 프롭 컬링 %.3f (안개 span 대비)" % [
		node._field.explore.avatar.x, node._field.explore.avatar.y, walked,
		FonsView3D.KIT_CULL_RATIO])
	for degrees in YAWS:
		view._yaw = deg_to_rad(float(degrees))
		# 청크는 프레임당 1개씩 짓는다 — 네 방향을 도는 동안 새 고리가 다 서도록 넉넉히.
		for i in 140:
			view.set_mouse_capture(false)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var path := "%s/yaw%03d.png" % [OUT_DIR, degrees]
		img.save_png(ProjectSettings.globalize_path(path))
		print("yaw %3d° → %s" % [degrees, path])
	quit()
