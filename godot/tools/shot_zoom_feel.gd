extends SceneTree
## 실플레이 하네스 — 휠 줌·시점 회전 감도를 진짜 게임 루프에서 잰다.
## `godot --path godot --fixed-fps 60 -s tools/shot_zoom_feel.gd` (창 모드 — headless 아님)
## 스텝을 60fps 로 고정하는 이유는 `shot_wall_feel.gd` 와 같다.
##
## 재는 것 넷:
##   1) 휠 한 칸의 배율과 범위 끝 (2.8~30) — 한 칸씩 4프레임 간격으로 돌려 본다.
##   2) 빠른 휠 8칸 — 줌은 스무딩을 건너뛰고 다음 프레임에 붙는다(`_boom_ready`). 그 대가로
##      프레임당 카메라가 몇 유닛 튀는지, 그리고 지형·프롭 아래로 새는지.
##   3) 마우스 1픽셀 = 몇 도 — 실제 `_unhandled_input` 경로로 넣는다.
##   4) Q/E 회전 — 실제 키 입력으로 초당 몇 도.
## 자리·시점은 탑 반대쪽(남쪽)으로 고정한다 — 붐이 탑 원통에 끊기면 휠 몫이 안 보인다.


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	ProjectSettings.set_setting("fons/view_mode", "3d")
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
	view._yaw = PI
	# 시작 자리는 광장 가장자리라 프롭이 붐을 4.2 남짓에 묶는다(아래 첫 출력이 그 값이다).
	# 휠 몫을 보려면 트인 쪽으로 걸어 나가야 한다 — 탑에서 멀어지는 남쪽.
	var walked := 0
	while node._field.explore.avatar.y < 15.0 and walked < 200:
		view.set_mouse_capture(false)
		node._on_intent("move", {"dir": Vector2(0, 1)})
		await process_frame
		walked += 1
	node._on_intent("move", {"dir": Vector2.ZERO})
	for i in 30:
		await process_frame
	var dir := Vector3(0.0, sin(view._pitch), cos(view._pitch) * -1.0)
	print("트인 자리 (%.1f, %.1f) · 걷기 %d프레임 · 기본 거리 %.2f · 붐 %.2f · 남쪽 자유 거리 %.2f" % [
		node._field.explore.avatar.x, node._field.explore.avatar.y, walked,
		view.camera_distance(), view.camera_boom(),
		view.camera_free_distance(view.camera_focus(), dir, FonsView3D.CAMERA_DISTANCE_MAX)])
	await _wheel_ladder(view)
	await _wheel_burst(view, dir)
	await _mouse_pixels(view)
	await _key_turn(view)
	quit()


func _wheel_ladder(view: Node) -> void:
	## 한 칸씩(4프레임 간격) 돌려 배율이 실제로 곱셈인지, 범위 끝이 어디인지 본다.
	var prev: float = view.camera_distance()
	var ratios: Array = []
	for i in 22:
		_wheel(view, true)
		for j in 4:
			await process_frame
		var now: float = view.camera_distance()
		if ratios.size() < 22 and prev > 0.0:
			ratios.append("x%.3f" % (now / prev))
		prev = now
	print("가까이 22칸 (4프레임 간격): 끝 거리 %.2f (최소 %.1f) · 배율 %s" % [
		view.camera_distance(), FonsView3D.CAMERA_DISTANCE_MIN,
		" ".join(ratios.slice(0, 6)) + " … " + ratios[-1]])
	var here: float = view.camera_distance()
	for i in 22:
		_wheel(view, false)
		for j in 4:
			await process_frame
	print("멀리 22칸: 끝 거리 %.2f (최대 %.1f) · 가까이 끝에서 %.2f → %.2f" % [
		view.camera_distance(), FonsView3D.CAMERA_DISTANCE_MAX, here, view.camera_distance()])


func _wheel_burst(view: Node, dir: Vector3) -> void:
	## 빠른 휠 — 8칸을 8프레임 연속으로. 줌이 스무딩을 건너뛰므로 점프가 프레임당 얼마인지 잰다.
	for i in 30:
		await process_frame
	var before: float = view.camera_distance()
	var prev_pos: Vector3 = view._camera.position
	var max_step := 0.0
	var step_at := 0
	for i in 8:
		_wheel(view, true)
		await process_frame
		var pos: Vector3 = view._camera.position
		var step: float = pos.distance_to(prev_pos)
		if step > max_step:
			max_step = step
			step_at = i + 1
		prev_pos = pos
	print("빠른 휠 8칸 (요청 %.2f → %.2f): 프레임당 카메라 이동 최대 %.2f유닛 (그 %d번째 프레임) · 붐 %.2f · 자유 거리 %.2f" % [
		before, view.camera_distance(), max_step, step_at, view.camera_boom(),
		view.camera_free_distance(view.camera_focus(), dir, FonsView3D.CAMERA_DISTANCE_MAX)])
	var ground := 0
	for i in 40:
		await process_frame
		if view._camera.position.y < view.terrain_height(view._camera.position.x, view._camera.position.z):
			ground += 1
	print("휠 뒤 40프레임 — 카메라가 지형 아래로 들어간 프레임 %d" % ground)


func _mouse_pixels(view: Node) -> void:
	## 실제 입력 경로(`_unhandled_input`)로 100px 를 넣고 yaw 변화를 본다.
	view.set_mouse_capture(true)
	for i in 4:
		await process_frame
	var before: float = view.camera_yaw()
	view._unhandled_input(_motion(Vector2(100.0, 0.0)))
	var dx: float = rad_to_deg(absf(wrapf(view.camera_yaw() - before, -PI, PI)))
	var before_y: float = view._pitch
	view._unhandled_input(_motion(Vector2(0.0, 100.0)))
	var dy: float = rad_to_deg(absf(view._pitch - before_y))
	view.set_mouse_capture(false)
	print("마우스 100px 가로 %.2f° (%.3f°/px) · 세로 %.2f° (%.3f°/px) — 상수 %.4f 라디안/px" % [
		dx, dx / 100.0, dy, dy / 100.0, FonsView3D.CAMERA_SENSITIVITY])


func _key_turn(view: Node) -> void:
	## Q 를 실제 키 이벤트로 누르고 60프레임 동안 yaw 가 몇 도 도는지.
	var before: float = view.camera_yaw()
	var press := InputEventKey.new()
	press.keycode = KEY_Q
	press.pressed = true
	Input.parse_input_event(press)
	var frames := 0
	for i in 60:
		await process_frame
		if Input.is_key_pressed(KEY_Q):
			frames += 1
	var release := InputEventKey.new()
	release.keycode = KEY_Q
	release.pressed = false
	Input.parse_input_event(release)
	var turned: float = rad_to_deg(absf(wrapf(view.camera_yaw() - before, -PI, PI)))
	if frames == 0:
		print("Q/E 회전 — 키 상태를 스크립트로 못 누른다(입력 장치 몫). 상수 %.1f 라디안/초 = %.0f°/s" % [
			FonsView3D.CAMERA_KEY_TURN, rad_to_deg(FonsView3D.CAMERA_KEY_TURN)])
		return
	print("Q 1초: yaw %.1f° (%.0f°/s) · 키가 눌린 프레임 %d" % [turned, turned, frames])


func _wheel(view: Node, closer: bool) -> void:
	var button := InputEventMouseButton.new()
	button.pressed = true
	button.button_index = MOUSE_BUTTON_WHEEL_UP if closer else MOUSE_BUTTON_WHEEL_DOWN
	view._unhandled_input(button)


func _motion(relative: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	return motion
