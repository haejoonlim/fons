extends SceneTree
## 벽 앞 카메라 실렌더 — 탑 벽(1.62) 바로 바깥 2.6 에 서서 시점을 벽 쪽으로 돌렸을 때.
## `godot --path godot -s tools/shot_wall_camera.gd` (렌더링이 필요하다 — headless 아님)
## 결과: `godot/screenshots/wall_camera/<before|after>_yaw<0|180>.png`
##
## 왜 이 자리인가
## -------------
## 2.6 은 2026-10-28 이전의 시작 자리 — 탑 가림 원통 바로 바깥이라 시점을 벽 쪽(yaw 180)으로
## 돌리면 옛 규칙은 붐을 **0.68** 까지 접었다. 카메라가 조종 영웅 몸속으로 들어가 프레임이
## 영웅(그리고 뒤에 선 동료)으로 가득 찬다. `before` 는 그 규칙으로 찍은 같은 화면이고,
## `after` 는 붐을 접는 대신 옆으로 도는 규칙(2026-10-28)으로 찍은 같은 화면이다.
## yaw 0 은 기본 구도 대조 — 탑이 앞에 선 남쪽 가장자리 화면.
##
## 같은 하네스를 옛 커밋의 작업 트리에서도 돌린다(`git worktree add`). 그래서 스윙 접근자
## (`camera_swing`)는 `has_method` 로 확인하고 찍는다 — 옛 코드에는 없다.

const OUT_DIR := "res://screenshots/wall_camera"
const BIOME := "biome_cave"
## 옛 시작 자리이자 벽 앞 자리 — `TOWER_BODY + 1.4`.
const SPOT := 2.6
const YAWS := [0.0, 180.0]


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	ProjectSettings.set_setting("fons/view_mode", "3d")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed := load("res://game/main/main.tscn") as PackedScene
	if packed == null:
		printerr("main.tscn 을 못 읽었다")
		quit(1)
		return
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
	var tag := "after" if view.has_method("camera_swing") else "before"
	for yaw_deg in YAWS:
		var at := Vector3(FonsExplore.SPAWN.x, 0.0, SPOT)
		snapshot["avatar"] = at
		for entity in snapshot["entities"]:
			if String((entity as Dictionary).get("id", "")) == "avatar":
				(entity as Dictionary)["pos"] = at
		var yaw := deg_to_rad(float(yaw_deg))
		# 40프레임 동안 같은 시점을 다시 박아 넣는다 — 붐·스윙이 목표로 붙을 때까지.
		for f in 40:
			view.apply(snapshot)
			view.set("_yaw", yaw)
			view.set("_pitch", deg_to_rad(FonsView3D.CAMERA_PITCH_DEFAULT))
			view.set("_distance", FonsView3D.CAMERA_DISTANCE)
			view.set("_boom_ready", false)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var path := "%s/%s_yaw%d.png" % [OUT_DIR, tag, int(yaw_deg)]
		img.save_png(path)
		var swing := rad_to_deg(float(view.call("camera_swing"))) if view.has_method("camera_swing") else 0.0
		print("%s — 붐 %.2f (자리 %.1f · yaw %d° · 스윙 %.0f°)" % [path, float(view.call("camera_boom")),
			SPOT, int(yaw_deg), swing])
	quit()
