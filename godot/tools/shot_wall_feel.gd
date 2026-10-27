extends SceneTree
## 실플레이 하네스 — 진짜 게임 루프를 창 모드로 돌리며 탑까지 걸어가 시점을 벽으로 돌린다.
## `godot --path godot -s tools/shot_wall_feel.gd` (실시간 — headless 아님)
## 결과: `screenshots/wall_feel/sheet.png` + 프레임별 카메라 수치 출력
##
## 재는 것 — 스윙이 도는 동안 **카메라 방향이 프레임당 몇 도를 도는가**와 **붐이 몇 유닛 움직이는가**.
## 견줄 값은 내 손이 돌리는 속도(느린 턴 60°/s · 손목 휙 360°/s)와 옛 규칙의 이음매(0.083유닛).
## 바이옴은 손대지 않는다 — 1층 실제 배치(프롭·조우)에서 보는 것이 목적이다.
##
## 왜 합성 스윕(`test_view_3d`)만으로는 부족한가 — 그쪽은 `_place_camera(delta)` 를 직접 부른다.
## 2026-10-28: 스냅샷을 미는 `apply` 가 매 프레임 카메라를 `delta = 0` 으로 놓아 스무딩을
## 통째로 스냅으로 덮는 결함을 이 하네스가 잡았다(합성 스윕은 초록이었다).

const OUT_DIR := "res://screenshots/wall_feel"
## [이름, 초, 프레임당 yaw 변화(도)]
const STEPS := [
	["벽으로 60°/s", 3.0, 1.0],
	["벽 앞에 멈춤", 2.5, 0.0],
	["휙 돌아나감 360°/s", 1.0, -6.0],
	["멈춤 (풀리는 중)", 1.5, 0.0],
	["휙 다시 벽으로", 0.6, 6.0],
	["벽 앞에 멈춤", 2.5, 0.0],
]


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
	var shots: Array = []
	var frame := 0
	var prev_yaw := 0.0
	var prev_boom := -1.0
	var max_turn := 0.0
	var max_boom := 0.0
	var at_step := ""
	var hidden := 0
	var min_boom := INF
	var hide_lo := INF
	var hide_hi := 0.0
	var dts: Array = []
	var t0 := Time.get_ticks_usec()
	# ── 1단계: 탑까지 걷는다 (실제 move 의도 — 속도·조향 전부 게임 경로).
	var walked := 0
	while node._field.explore.avatar.y > 2.9 and walked < 200:
		view.set_mouse_capture(false)
		node._on_intent("move", {"dir": Vector2(0, -1)})
		await process_frame
		walked += 1
	node._on_intent("move", {"dir": Vector2.ZERO})
	print("걷기 %d프레임 → 자리 (%.1f, %.1f)" % [walked, node._field.explore.avatar.x,
		node._field.explore.avatar.y])
	# ── 2단계: 시점을 벽으로 돌린다 (실제 orbit 경로 — 마우스가 부르는 그 함수).
	for step in STEPS:
		var name := String(step[0])
		var per_frame := deg_to_rad(float(step[2]))
		var step_hidden := 0
		var step_min := INF
		for i in int(float(step[1]) * 60.0):
			view.set_mouse_capture(false)
			if per_frame != 0.0:
				view.orbit(per_frame, 0.0)
			await process_frame
			var now := Time.get_ticks_usec()
			dts.append(float(now - t0) / 1000000.0)
			t0 = now
			var yaw: float = view.camera_yaw()
			var swing: float = view.camera_swing()
			var boom: float = view.camera_boom()
			if prev_boom >= 0.0:
				var turn := absf(rad_to_deg(wrapf(yaw + swing - prev_yaw, -PI, PI)))
				if turn > max_turn:
					max_turn = turn
					at_step = name
				max_boom = maxf(max_boom, absf(boom - prev_boom))
				if turn > 15.0 or absf(boom - prev_boom) > 0.4:
					print("    큰 프레임 %d (%s) — yaw %.0f° · 스윙 %.0f° (%.1f°/프레임 · 실시간 %.0fms) · 붐 %.2f → %.2f" % [
						frame, name, rad_to_deg(yaw), rad_to_deg(swing), turn, dts[-1] * 1000.0, prev_boom, boom])
			prev_yaw = yaw + swing
			prev_boom = boom
			min_boom = minf(min_boom, boom)
			step_min = minf(step_min, boom)
			if boom < FonsView3D.CAMERA_AVATAR_FADE_NEAR:
				hidden += 1
				step_hidden += 1
				hide_lo = minf(hide_lo, boom)
				hide_hi = maxf(hide_hi, boom)
			frame += 1
			if frame % 40 == 0:
				await RenderingServer.frame_post_draw
				shots.append({"step": name, "yaw": yaw, "swing": swing, "boom": boom,
					"img": root.get_texture().get_image()})
		var here: Vector2 = node._field.explore.avatar
		print("  %-20s 자리 (%.1f, %.1f) · 붐 %.2f (최단 %.2f) · 스윙 %.0f° · yaw %.0f° · 영웅 사라진 프레임 %d" % [
			name, here.x, here.y, view.camera_boom(), step_min, rad_to_deg(view.camera_swing()),
			rad_to_deg(view.camera_yaw()), step_hidden])
	dts.sort()
	print("카메라 방향 최대 회전 %.1f°/프레임 (%s) · 프레임당 최대 붐 변화 %.3f유닛" % [max_turn, at_step, max_boom])
	print("붐 최단 %.2f · 영웅이 사라진 프레임 %d/%d (붐 %.2f~%.2f)" % [min_boom, hidden, frame,
		0.0 if hide_lo == INF else hide_lo, hide_hi])
	print("프레임 간격 — 최소 %.0fms · 중간 %.0fms · 최대 %.0fms (평균 %.0f fps)" % [dts[0] * 1000.0,
		dts[dts.size() / 2] * 1000.0, dts[-1] * 1000.0, float(frame) / maxf(0.001, dts.reduce(func(a, b): return a + b, 0.0))])
	await _sheet(shots)
	quit()


func _sheet(shots: Array) -> void:
	## 프레임을 한 장에 늘어놓는다 — 팬이 어떻게 읽히는지 눈으로 보려고.
	var cell := Vector2(426.0, 240.0)
	var cols := 4
	var gap := 4.0
	var rows := ceili(float(shots.size()) / float(cols))
	var size := Vector2i(int(cell.x * cols + gap * (cols + 1)), int(cell.y * rows + gap * (rows + 1) + 26.0))
	var view := SubViewport.new()
	view.size = size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var sheet := Control.new()
	sheet.size = Vector2(size)
	view.add_child(sheet)
	var back := ColorRect.new()
	back.color = Color(0.06, 0.06, 0.07)
	back.size = sheet.size
	sheet.add_child(back)
	for i in shots.size():
		var rect := TextureRect.new()
		rect.texture = ImageTexture.create_from_image(shots[i]["img"])
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.position = Vector2(gap + float(i % cols) * (cell.x + gap), float(i / cols) * (cell.y + gap))
		rect.size = cell
		sheet.add_child(rect)
		var label := Label.new()
		label.text = "붐 %.2f 스윙 %.0f°" % [float(shots[i]["boom"]), rad_to_deg(float(shots[i]["swing"]))]
		label.position = rect.position + Vector2(4.0, cell.y + 2.0)
		label.add_theme_font_size_override("font_size", 12)
		sheet.add_child(label)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image()
	img.save_png("%s/sheet.png" % OUT_DIR)
	print("시트 %d장 → %s/sheet.png" % [shots.size(), OUT_DIR])
