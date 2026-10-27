extends SceneTree
## S5b 실렌더 — **실제 조우 미리보기**를 그 층의 필드에서 본다.
## `godot --path godot -s tools/shot_encounter_3d.gd` (렌더링 필요 — headless 아님)
## 결과: `godot/screenshots/encounter3d/<층>_<바이옴>_wide|close.png`
##
## 왜 필요한가
## -----------
## `creatures3d.png` 는 회색 바닥 위 격자다 — 키트 지형·안개·영웅 색과 함께 섰을 때
## 몸통이 묻히는지가 그 시트로는 안 보인다.
## 이 하네스는 게임 경로를 그대로 쓴다: `_field.snapshot()` 이 조우 지점 둘레에 세우는
## 미리보기 엔티티를 **그리지 않고** 받아서 뷰에 넘긴다. 하네스가 편성을 만들지 않는다.
##
## 층은 `_field.start()` 로 실제로 그 층에서 다시 시작하고, 아바타만 조우 지점 앞으로
## 순간이동시킨다 (걷는 입력을 흉내 내면 사선으로 흘러 지점을 놓친다). 동료 자리도 같이 민다.

const OUT_DIR := "res://screenshots/encounter3d"
## 낮은 층(대역 둘) · 중간 층 · 깊은 층(tier 5) — 배율과 색이 갈리는지 보려면 층이 갈려야 한다.
const FLOORS := [1, 45, 95]
## 아바타를 조우 지점에서 얼마나 떨어뜨리는가 — 미리보기(반경 2.4)가 아바타 앞에 서고
## 기본 카메라(4.2) 안에 다섯이 들어오는 거리.
const VIEW_GAP := 6.0
## 카메라를 옆으로 돌려 아바타(초록 캡슐)가 편성 가운데를 가리지 않게 한다.
const CAMERA_TURN := 0.62
## 시점을 살짝 올려 본다 — 능선이 뒤 생물을 가린다 (95층 실측).
const CAMERA_RISE := 0.18
## 청크 메시·키트는 `apply` 한 번에 한 청크씩 짓는다 — 한 층을 다 깔고 찍는다.
const BUILD_FRAMES := 60


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
	# main 은 매 프레임 필드 스냅샷을 다시 민다 — 그대로 두면 순간이동이 다음 프레임에 되돌아간다.
	node.set_process(false)
	node.set_physics_process(false)
	var data: Dictionary = node._data_bundle()
	for floor in FLOORS:
		node._field.start(data["races"], data["monsters"], data["biomes"], int(node.SEED), floor,
			data["job_tree"], data["equipment"], data["job_coef"], data["ai"], data["basics"])
		var base: Dictionary = _walk_to_encounter(node._field)
		if base.is_empty():
			printerr("%d층에 조우 지점이 없다" % floor)
			quit(1)
			return
		var monsters := _monsters_of(base)
		if monsters.is_empty():
			printerr("%d층 미리보기가 비었다 — 스냅샷이 생물을 싣지 않는다" % floor)
			quit(1)
			return
		# 7.5유닛 회색 탑과 소환진은 이 판정의 대상이 아니다 — 아바타 뒤를 가린다 (바이옴 시트와 같은 처리).
		base.erase("tower")
		# 층마다 카메라를 기본 거리로 되돌린다. `zoom` 은 누적이라 위 층에서 당긴 거리가
		# 그대로 남아 다음 층의 "기본" 이 된다 (실측: 45층 wide 와 close 가 같은 파일).
		view.unmount()
		view.mount(base)
		# 카메라를 **먼저** 돌린다 — HP 바는 `apply` 가 그리는 순간의 카메라로 화면 좌표를 낸다.
		view.orbit(CAMERA_TURN, CAMERA_RISE)
		for i in BUILD_FRAMES:
			view.apply(base)
			await process_frame
		var biome := String(base.get("biome", ""))
		var stem := "%s/%03d_%s" % [OUT_DIR, floor, biome]
		_label("%d층 · %s · 조우 미리보기 %d종" % [floor, biome, monsters.size()],
			Vector2(20.0, 548.0), 20)
		_label(_party_line(monsters), Vector2(20.0, 578.0), 15)
		await _save(stem + "_wide.png")
		# 기본 카메라는 4.2미터 뒤 — 몸통이 화면에서 몇 픽셀인지 보려면 한 단계 붙인다.
		# 7 스텝은 최소 거리(2.8)로 잘려 동료 상자 안으로 들어간다 (실측). 2 스텝 = 3.18.
		view.zoom(2.0)
		for i in 24:
			view.apply(base)
			await process_frame
		await _save(stem + "_close.png")
		print("%d층 %s — %s" % [floor, biome, _party_line(monsters)])
	quit()


func _walk_to_encounter(field: FonsFieldState) -> Dictionary:
	## 아바타와 동료를 가장 가까운 조우 지점 앞으로 옮긴다. 심을 고치지 않고 좌표만 민다.
	var site := _nearest_site(field)
	if site.is_empty():
		return {}
	var back := Vector3(sin(CAMERA_TURN), 0.0, cos(CAMERA_TURN)).normalized()
	var target := Vector2(site["pos"].x, site["pos"].y) \
		+ Vector2(back.x, back.z) * VIEW_GAP
	var delta := target - field.explore.avatar
	field.explore.avatar = target
	for i in field.party_pos.size():
		field.party_pos[i] = field.party_pos[i] + delta
	return field.snapshot()


func _nearest_site(field: FonsFieldState) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for entity in field.explore.sites:
		var site: Dictionary = entity
		var d := field.explore.avatar.distance_to(site["pos"])
		if d < best_d:
			best_d = d
			best = site
	return best


func _monsters_of(snapshot: Dictionary) -> Array:
	var out: Array = []
	for entity in snapshot.get("entities", []):
		if String((entity as Dictionary).get("kind", "")) == "monster":
			out.append(entity)
	return out


func _party_line(monsters: Array) -> String:
	var parts: Array = []
	for entry in monsters:
		var entity: Dictionary = entry
		var id := String(entity.get("asset", "")).trim_prefix("monster:")
		parts.append("%s(%s)" % [String(entity.get("name", id)), FonsMonsterBody.band_for(id)])
	return " · ".join(parts)


func _label(text: String, at: Vector2, size: int) -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.94, 0.95, 0.97))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty: %s" % path)
		return
	img.save_png(path)
	print("saved %s %dx%d" % [path, img.get_width(), img.get_height()])
