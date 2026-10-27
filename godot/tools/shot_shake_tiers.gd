extends SceneTree
## 타격 흔들림 세기 비교 — 같은 카메라·같은 난수로 **약한 일격 / 강한 일격**을 나란히 잰다.
## `godot --path godot -s tools/shot_shake_tiers.gd` (실제 창 렌더)
## 결과: `godot/screenshots/shake_light.png` · `shake_heavy.png` + 프레임별 수치 표
##
## 왜 필요한가
## -----------
## 흔들림은 애니메이션이라 정지 화면 두 장으로는 차이가 안 보인다. 세기를 바꿨다는 주장은
## **프레임별 카메라 이동량(유닛)과 롤(도)** 로만 뒷받침된다. 두 판은 같은 고정 시드를 쓰므로
## 남는 차이는 배율뿐이다 — 수치가 곧 그 배율의 증거다.

const FRAMES := 12


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	ProjectSettings.set_setting("fons/view_mode", "3d")
	var light := await _run(false)
	var heavy := await _run(true)
	print("frame  light_off light_roll  heavy_off heavy_roll")
	for i in mini(light.size(), heavy.size()):
		print("%2d %10.4f %9.2f %10.4f %9.2f" % [i,
			float(light[i]["offset"]), float(light[i]["roll"]),
			float(heavy[i]["offset"]), float(heavy[i]["roll"])])
	quit()


func _run(heavy: bool) -> Array:
	var packed := load("res://game/main/main.tscn") as PackedScene
	var node: Node = packed.instantiate()
	root.add_child(node)
	for i in 5:
		await process_frame
	node.set_process(false)
	node.set_physics_process(false)
	var view: Node = node._view
	# 뷰는 트리에 있어 스스로도 `_process` 를 돈다 — 수동으로 돌리면 감쇠가 두 배로 빨라진다.
	view.set_process(false)
	var snapshot: Dictionary = node._field.snapshot()
	snapshot["mode"] = "field"
	view.apply(snapshot)
	for i in 3:
		await process_frame
	view._yaw = 0.0
	view._place_camera()
	var rest: Vector3 = view._camera.position
	snapshot["strike"] = {"seq": 1, "site": 0, "damage": 1200, "heavy": heavy}
	view.apply(snapshot)
	var out: Array = []
	var peak := 0.0
	var peak_frame := 0
	for i in FRAMES:
		view._place_camera()
		var offset: float = view._camera.position.distance_to(rest)
		var roll: float = absf(rad_to_deg(asin(clampf(view._camera.transform.basis.x.y, -1.0, 1.0))))
		out.append({"offset": offset, "roll": roll})
		if roll > peak:
			peak = roll
			peak_frame = i
		await process_frame
		view._process(1.0 / 60.0)
	# 가장 크게 기운 프레임을 남긴다 — 정지 화면에서 차이가 보이는 유일한 순간이다.
	await process_frame
	node.queue_free()
	await process_frame
	# 피크 프레임을 다시 만들어 저장한다.
	var again: Node = (load("res://game/main/main.tscn") as PackedScene).instantiate()
	root.add_child(again)
	for i in 5:
		await process_frame
	again.set_process(false)
	again.set_physics_process(false)
	var v2: Node = again._view
	v2.set_process(false)
	v2.apply(snapshot)
	for i in 3:
		await process_frame
	v2._yaw = 0.0
	v2._place_camera()
	for i in peak_frame + 1:
		v2._place_camera()
		await process_frame
		v2._process(1.0 / 60.0)
	await _save("res://screenshots/shake_%s.png" % ("heavy" if heavy else "light"))
	again.queue_free()
	await process_frame
	return out


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty: %s" % path)
		return
	img.save_png(path)
	print("saved %s" % path)
