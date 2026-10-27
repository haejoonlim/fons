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
##
## 시점 — 한 발 물러나 찍는다 (`DISTANCE_SCALE`). 기본 거리에서는 파티 바로 옆 바위가 프레임을
## 절반씩 먹었다(동굴 08, 2026-10-28 시트). 각도를 돌려 피하려 했지만 소용없었다: 7각도로
## 찍어 보니 파티가 랜드마크 바위에 둘러싸여 어느 쪽이든 벽이 서고, -60°/-90° 는 붐이 접혀
## 파티가 화면에서 사라졌다. 거리를 1.4배로 늘리면 같은 바위가 화면을 덮는 벽이 아니라 중경
## 물체가 된다. yaw 는 기본(0°) 그대로 — 돌리면 해가 등지는 역광이 되어 광량 비교가 흔들린다.

const OUT_DIR := "res://screenshots/biomes3d"
## 촬영 거리. 기본 `CAMERA_DISTANCE` 는 4.2 인데, 그 거리에서는 파티 바로 옆 바위가 화면
## 왼쪽 40% 를 덮었다(2026-10-28 동굴 7각도 실측). 15.0 은 그 실측에서 고른 값이다 —
## 바위가 중경 물체로 내려앉고 파티·지형·안개가 한 화면에 읽힌다. 게임 줌 상한은 30.0 이라
## 이 거리도 플레이어가 낼 수 있는 시점이다.
const DISTANCE := 15.0


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
		await _settle(view, snapshot, DISTANCE)
		var path := "%s/%02d_%s.png" % [OUT_DIR, i + 1, String(biome.get("id", ""))]
		await _save(path)
		var palette: Dictionary = snapshot["palette"]
		var camera = view.get("_camera")
		var boom := float(view.camera_distance())
		var origin: Vector3 = (camera as Camera3D).global_position if camera != null else Vector3.ZERO
		print("%02d %-14s sky=%s ground=%s dist=%.1f cam=(%.1f,%.1f,%.1f) kit=%s" % [i + 1, String(biome.get("id", "")),
			(palette["sky"] as Color).to_html(false), (palette["ground"] as Color).to_html(false),
			boom, origin.x, origin.y, origin.z, String(snapshot["kit"])])
	quit()


func _settle(view: Node, snapshot: Dictionary, distance: float) -> void:
	## 청크 예산 60프레임을 먼저 채우고, 그 다음 카메라가 멈출 때까지 민다.
	## 상한 1200프레임은 지형·프롭 충돌로 붐이 계속 흔들리는 경우의 탈출구다 — 그때는
	## 마지막 프레임을 쓰고 경고를 남긴다(조용히 다른 프레이밍을 찍지 않는다).
	const MIN_FRAMES := 60
	const STABLE_FRAMES := 12
	## 프레임 간 이동 허용치. 정확히 같기를 기다리면 파티 대기 동작 때문에 26칸이 상한까지
	## 돌아 19분이 걸렸다(2026-10-28 실측). 0.01 은 화면에서 구분되지 않는 폭이다.
	const SETTLED := 0.01
	var last := Transform3D()
	var stable := 0
	for f in 900:
		view.apply(snapshot)
		# 거리는 매 프레임 같은 값으로 다시 세운다(스냅샷 적용이 카메라를 건드릴 수 있다).
		view.set("_distance", distance)
		# 붐 스무딩을 끈다(`_smooth_boom` 이 목표로 바로 붙는다). 켜 두면 거리 변경 뒤 수렴이
		# 느려 안정 판정이 상한까지 돌았다(2026-10-28 실측). 참조가 고정이라 화면은 같다.
		view.set("_boom_ready", false)
		await process_frame
		if f < MIN_FRAMES:
			continue
		var camera = view.get("_camera")
		if camera == null:
			return
		var now: Transform3D = (camera as Camera3D).transform
		if now.origin.distance_to(last.origin) < SETTLED:
			stable += 1
			if stable >= STABLE_FRAMES:
				return
		else:
			stable = 0
		last = now
	printerr("카메라가 900프레임 안에 멈추지 않았다 — 마지막 프레임으로 찍는다")


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
