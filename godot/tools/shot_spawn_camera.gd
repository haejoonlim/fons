extends SceneTree
## 시작 자리 카메라 전/후 실렌더 — 탑 쪽으로 시점을 돌렸을 때 붐이 접히는가.
## `godot --path godot -s tools/shot_spawn_camera.gd` (렌더링이 필요하다 — headless 아님)
## 결과: `godot/screenshots/spawn_camera/<before|after>_yaw<0|180>.png`
##
## 왜 필요한가
## -----------
## 2026-10-28 이전의 시작 자리는 탑 몸통 바로 바깥(2.6)이었다. 그 자리에서 시점을 탑 쪽으로
## 돌리면 탑 가림 원통(몸통 × 1.35 = 1.62)이 붐을 **0.68** 까지 접고, 카메라가 조종 영웅
## 몸속으로 들어가 프레임이 영웅(그리고 뒤에 선 동료)으로 가득 찬다. 그 화면이 이 도구의
## `before` 다. 자리를 탑 가림 + 카메라 기본 거리(5.82) 밖인 6.0 으로 옮긴 뒤가 `after` 다.
## 숫자만으로는 "무엇이 잘못됐는지"가 안 남는다 — 두 장을 같은 조건에서 찍어 붙인다.
##
## 기본 시점(yaw 0)도 같이 찍는다. 자리를 옮긴 대가로 뒤쪽 구도가 바뀌므로, 남쪽 가장자리에서
## 탑을 바라보는 기본 화면을 눈으로 확인해야 한다. 바이옴은 시작 자리가 탑 광장이라 동굴로 잡았다.

const OUT_DIR := "res://screenshots/spawn_camera"
const BIOME := "biome_cave"
## 2026-10-28 이전의 시작 자리 — `TOWER_BODY + 1.4`. 지금 심은 6.0 을 쓴다.
const BEFORE_SPOT := 2.6


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	ProjectSettings.set_setting("fons/view_mode", "3d")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed := load("res://game/main/main.tscn") as PackedScene
	var node: Node = packed.instantiate()
	root.add_child(node)
	for i in 5:
		await process_frame
	var view: Node = node._view
	if view == null:
		printerr("3D 뷰를 만들지 못했다 (mode=%s)" % FonsViewFactory.configured_mode())
		quit(1)
		return
	node.set_process(false)
	node.set_physics_process(false)
	var snapshot: Dictionary = node._field.snapshot()
	for group in JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))["groups"]:
		for biome in group["biomes"]:
			if String(biome.get("id", "")) != BIOME:
				continue
			snapshot["biome"] = BIOME
			snapshot["kit"] = String(biome.get("topologyKit", ""))
			snapshot["palette"] = FonsBiomePalette.from_biome(biome)
	# 탑 스냅샷은 그대로 둔다 — 뷰가 이 자리를 광장으로 삼아 프롭을 비운다 (2026-10-28).
	for f in 120:
		view.apply(snapshot)
		await process_frame
	var shots := [
		{"name": "before", "z": BEFORE_SPOT, "yaw": 0.0},
		{"name": "before", "z": BEFORE_SPOT, "yaw": 180.0},
		{"name": "after", "z": FonsExplore.SPAWN.y, "yaw": 0.0},
		{"name": "after", "z": FonsExplore.SPAWN.y, "yaw": 180.0},
	]
	for shot in shots:
		var at := Vector3(FonsExplore.SPAWN.x, 0.0, float(shot["z"]))
		snapshot["avatar"] = at
		for entity in snapshot["entities"]:
			if String((entity as Dictionary).get("id", "")) == "avatar":
				(entity as Dictionary)["pos"] = at
		var yaw := deg_to_rad(float(shot["yaw"]))
		view.set("_yaw", yaw)
		view.set("_pitch", deg_to_rad(FonsView3D.CAMERA_PITCH_DEFAULT))
		view.set("_distance", FonsView3D.CAMERA_DISTANCE)
		view.set("_boom_ready", false)
		for f in 40:
			view.apply(snapshot)
			view.set("_yaw", yaw)
			view.set("_pitch", deg_to_rad(FonsView3D.CAMERA_PITCH_DEFAULT))
			view.set("_distance", FonsView3D.CAMERA_DISTANCE)
			view.set("_boom_ready", false)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var path := "%s/%s_yaw%d.png" % [OUT_DIR, String(shot["name"]), int(shot["yaw"])]
		img.save_png(path)
		print("%s 붐 %.2f (자리 %.1f · yaw %d°)" % [path, float(view.camera_boom()),
			float(shot["z"]), int(shot["yaw"])])
	quit()
