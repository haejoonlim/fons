extends SceneTree
## 영웅 몸통 3종(guard·scout·mystic) × 영웅 색 실렌더.
## `godot --path godot -s tools/shot_heroes_3d.gd` (렌더링 필요 — headless 아님)
## 결과: `godot/screenshots/heroes3d.png`
##
## 왜 필요한가
## -----------
## 테스트는 대역 선택·틴트 대상·높이만 잠근다. 셋이 한 화면에서 갈리는지, 몸통 색을
## 곱했을 때 눈·장비가 살아 있는지는 렌더로만 보인다.
## 세로 = 대역, 가로 = (따뜻한 색 · 차가운 색 · 초록 · 아바타 기본색).

const OUT := "res://screenshots/heroes3d.png"
const BANDS := ["guard", "scout", "mystic"]
const COLORS := [
	Color(0.86, 0.34, 0.28), Color(0.30, 0.52, 0.90), Color(0.36, 0.72, 0.40),
	Color(0.55, 0.45, 0.95),
]
const SPACING := 2.0
const ROW_SPACING := 3.4


func _initialize() -> void:
	_build_stage()
	var camera := _camera()
	var rows := BANDS.size()
	var columns := COLORS.size()
	for r in rows:
		for c in columns:
			var band: String = BANDS[r]
			var scene := FonsHeroBody.scene(band)
			if scene == null:
				printerr("몸통 씬 없음: %s" % band)
				quit(1)
				return
			var node: Node3D = scene.instantiate()
			FonsHeroBody.apply(node, COLORS[c])
			node.position = Vector3(
				(float(c) - (columns - 1) * 0.5) * SPACING, 0.0,
				(float(r) - (rows - 1) * 0.5) * ROW_SPACING)
			root.add_child(node)
	for i in 4:
		await process_frame
	_label("영웅 몸통 3종 — 대역 × 영웅 색", Vector2(24.0, 16.0), 22)
	for r in rows:
		var row_z := (float(r) - (rows - 1) * 0.5) * ROW_SPACING
		var at := camera.unproject_position(Vector3(
			-(columns - 1) * 0.5 * SPACING - 1.6, 0.9, row_z))
		_label(BANDS[r], at + Vector2(-4.0, -10.0), 18)
	for i in 2:
		await process_frame
	await _save()
	quit()


func _build_stage() -> void:
	root.size = Vector2i(1280, 720)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = env
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.16, 0.18)
	material.roughness = 1.0
	ground.material_override = material
	ground.position.y = -0.02
	root.add_child(ground)


func _camera() -> Camera3D:
	var camera := Camera3D.new()
	# 직교 투영 — 같은 대역끼리 화면에서 나란히 서야 색 차이만 눈에 들어온다.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.6
	camera.position = Vector3(0.0, 6.0, 9.4)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.95, 0.0))
	camera.current = true
	root.add_child(camera)
	return camera


func _label(text: String, at: Vector2, size: int) -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)


func _save() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty")
		return
	img.save_png(OUT)
	print("saved %s %dx%d" % [OUT, img.get_width(), img.get_height()])
