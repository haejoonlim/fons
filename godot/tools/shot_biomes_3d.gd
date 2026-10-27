extends SceneTree
## 26바이옴 실렌더 — 바이옴마다 **진짜 3D 뷰**로 한 장씩.
## `godot --path godot -s tools/shot_biomes_3d.gd` (렌더링이 필요하다 — headless 아님)
## 결과: `godot/screenshots/biomes3d/<번호>_<id>.png`
##
## 왜 필요한가
## -----------
## [biome_tints.png] 는 팔레트 **값**을 칠한 비교 시트다. 실제 렌더는 하늘 재질이 선형광을
## 거치고, 지면 틴트·안개·광량이 겹치므로 값과 화면이 같지 않다. 바이옴끼리 "하늘·지면·식생이
## 눈으로 갈리는가"는 실제 렌더로만 확인된다.
##
## 스냅샷만 갈아 끼운다 — 필드 시뮬레이션은 한 번만 돌리고 `biome`/`kit`/`palette` 세 값만
## 바꿔 `apply()` 한다. 뷰 계약(§view_contract)상 뷰는 이 세 값만 읽으므로 이걸로 충분하다.

const OUT_DIR := "res://screenshots/biomes3d"


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
	# main 은 매 프레임 `_push()` 로 필드 스냅샷을 다시 적용한다 — 그대로 두면 방금 넣은
	# 바이옴이 다음 프레임에 지워져 26장이 모두 같은 장면이 된다(첫 실행 실측).
	node.set_process(false)
	node.set_physics_process(false)
	var base: Dictionary = node._field.snapshot()
	# 층 중심 탑(7.5유닛 회색 기둥)은 바이옴 에셋이 아니다 — 모든 켬에서 같은 자리에 서서
	# 랙드마크 · 프롭을 가린다. 이 시트의 판정 대상은 키트 구조와 라이팅이므로 뺀다.
	base.erase("tower")
	var biomes := _biomes()
	for i in biomes.size():
		var biome: Dictionary = biomes[i]
		var snapshot := base.duplicate(true)
		snapshot["biome"] = String(biome.get("id", ""))
		snapshot["kit"] = String(biome.get("topologyKit", ""))
		snapshot["palette"] = FonsBiomePalette.from_biome(biome)
		# 청크 메시·키트는 `apply` 한 번에 **한 청크씩** 짓는다(`CHUNK_BUILD_BUDGET`) —
		# 스트리밍 중 멈춤을 막는 예산이다. 4프레임만 돌리면 새 키트가 한 청크에만 깔려
		# "프롭이 없는 바이옴"처럼 찍힌다. 49청크를 다 채우고 찍는다.
		#
		# 카메라는 **프레임 수가 아니라 시간(delta)으로** 수렴한다(`CAMERA_FOLLOW` 지수 스무딩).
		# 60프레임만 돌리면 빠른 기계에서는 붐이 덜 쫓아와 활짝 열린 샷이, 느린 기계에서는
		# 자리 잡은 클로즈업이 나왔다(2026-10-28 실측: 같은 트리에서 두 프레이밍이 번갈아).
		# 그래서 최소 프레임(청크 예산)을 채운 뒤 카메라 변환이 멈출 때까지 돌린다.
		await _settle(view, snapshot)
		var path := "%s/%02d_%s.png" % [OUT_DIR, i + 1, String(biome.get("id", ""))]
		await _save(path)
		var palette: Dictionary = snapshot["palette"]
		print("%02d %-14s sky=%s ground=%s kit=%s" % [i + 1, String(biome.get("id", "")),
			(palette["sky"] as Color).to_html(false), (palette["ground"] as Color).to_html(false),
			String(snapshot["kit"])])
	quit()


func _settle(view: Node, snapshot: Dictionary) -> void:
	## 청크 예산 60프레임을 먼저 채우고, 그 다음 카메라가 멈출 때까지 민다.
	## 상한 1200프레임은 지형·프롭 충돌로 붐이 계속 흔들리는 경우의 탈출구다 — 그때는
	## 마지막 프레임을 쓰고 경고를 남긴다(조용히 다른 프레이밍을 찍지 않는다).
	const MIN_FRAMES := 60
	const STABLE_FRAMES := 6
	var last := Transform3D()
	var stable := 0
	for f in 1200:
		view.apply(snapshot)
		await process_frame
		if f < MIN_FRAMES:
			continue
		var camera = view.get("_camera")
		if camera == null:
			return
		var now: Transform3D = (camera as Camera3D).transform
		if now.is_equal_approx(last):
			stable += 1
			if stable >= STABLE_FRAMES:
				return
		else:
			stable = 0
		last = now
	printerr("카메라가 1200프레임 안에 멈추지 않았다 — 마지막 프레임으로 찍는다")


func _biomes() -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))
	var out: Array = []
	for group in data.get("groups", []):
		for biome in (group as Dictionary).get("biomes", []):
			out.append(biome)
	return out


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty: %s" % path)
		return
	img.save_png(path)
