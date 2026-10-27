extends SceneTree
## 셰이딩 후보 A·B·C 실렌더 대조 — 같은 키트 부품을 같은 조명·같은 카메라로 세 번 찍는다.
## `godot --path godot -s tools/shot_shading_compare.gd` (렌더링이 필요하다 — headless 아님)
## 결과: `screenshots/shading/<바이옴>_<후보>_<구도>.png` 12장 + 시트 2장
##
## 후보 (docs/art/셰이딩_조각수_선택지.md §1)
##   a_current — 지금 그대로. 상자는 면 법선, 구·원기둥·원뿔은 생성기의 해석적 법선(스무스)
##   b_flat    — 부품 전부 면 법선. 잎·바위가 각져 보이는지 본다. 지형은 안 건드린다(후보 정의)
##   c_toon    — 밝기 세 단. 조명 모델(밴드·태양/환경 비율·노출·색 균형)은 **뷰 계층이 갖는다** —
##               `game/view/view_3d/toon_shade.gd`(FonsToonShade). 하네스는 그 모듈을 불러 세우고
##               같은 화소에서 A 와 밝기·색을 잰다. gl_compatibility 에서 도는지도 여기서 갈린다.
##
## 왜 게임 카메라를 안 쓰나 — 필드에 흩어진 프롭은 화면에 몇 개만 들어오고 영웅·조우 표식이
## 앞을 가려 세 후보의 차이가 안 보인다(첫 실행 실측: 3장이 같은 그림). 대신 키트 부품 다섯을
## **견본대**로 세워 놓고, 게임의 하늘·태양·안개는 그대로 쓰면서 카메라만 고정한다.
##
## 바이옴 둘을 쓰는 이유 — 자연 표면은 구·원기둥(각짐이 보인다), 도시 폐허는 상자·원기둥
## (뭉갬이 보인다). 한 키트로는 두 판정 기준 중 하나만 보인다.

const OUT_DIR := "res://screenshots/shading"
const KIT_DIR := "res://assets/art/models/%s.glb"
const BIOMES := ["biome_plains", "biome_ruins"]
const VARIANTS := ["a_current", "b_flat", "c_toon"]
## 보정으로 훑을 [태양 노출, 넓은 광택, 환경광 배율] 셋. 정한 값은 모듈(`FonsToonShade`)이 갖는다.
## 광택 항은 태양 색(푸른 #d8e5ff)을 albedo 무관하게 더한다 — 잎·풀의 파랑이 여기서 산다.
## 광택은 밝은 면을, 환경광은 그늘(p10)을 민다 — 한 값씩 따로 맞출 수 없어 격자로 훑는다.
const CALIBRATION := [
	[0.63, 0.035, 2.6], [0.63, 0.035, 2.0], [0.63, 0.035, 3.2],
	[0.54, 0.035, 2.6], [0.72, 0.035, 2.6],
]
## 견본대 — [부품 prefix, 개수]. 랜드마크는 늘 첫 자리(근접 구도의 기준).
const LINEUP := [["landmark_", 1], ["height_", 2], ["prop_", 2]]
const SPACING := 3.6
## 견본대 중심 — 필드(40×28) 한가운데. 사방 여유(32) 안이라 지형이 깔린다.
const CENTER := Vector2(20.0, 14.0)
## 먼 구도 — 다섯 부품이 한 화면에. 각 부품이 화면 세로의 1/8 쯤.
const FAR_BACK := 15.0
const FAR_HEIGHT := 4.6
## 근접 구도 — 앞 두 부품(랜드마크·높이)만. 잎·바위의 면이 갈리는지 보는 자리.
## 부품 간격(3.6)보다 뒤로 물러야 큰 부품(둔덕 반지름 2.4)이 화면을 다 덮지 않는다.
const NEAR_BACK := 6.6
const NEAR_HEIGHT := 3.0
## 후보 C 의 조명 모델(밴드·태양/환경 비율·노출·색 균형)은 뷰 계층이 갖는다 —
## `game/view/view_3d/toon_shade.gd` (FonsToonShade). 하네스는 사양을 들고 있지 않고
## 뷰와 같은 모듈을 불러서 잰다. 여기서 정한 목표는 평균은 A 와 같게, p10(그늘)은 A 의 0.9배 이상.
const CELL := Vector2(480.0, 270.0)
const GAP := 6.0
const MARGIN := 6.0
const HEADER := 34.0
const ROW_LABEL := 20.0

## 원본 상태 — 후보를 바꿀 때마다 여기로 되돌린다.
var _base_meshes: Dictionary = {}
var _base_overrides: Dictionary = {}
## 후보 C 의 조명 모델 — 뷰 계층과 같은 모듈을 쓴다.
var _shade := FonsToonShade.new()
var _lineup: Node3D = null
## 견본대가 선 지면 높이와 근접 구도의 가로 위치 — 카메라를 이 기준으로 세운다.
var _ground := 0.0
var _near_x := CENTER.x
var _main: Node = null


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
	_main = node
	root.add_child(node)
	for i in 5:
		await process_frame
	var view: Node = node._view
	var cam: Camera3D = view._camera if view != null else null
	if view == null or cam == null:
		printerr("3D 뷰를 만들지 못했다 (mode=%s)" % FonsViewFactory.configured_mode())
		quit(1)
		return
	# main 은 매 프레임 스냅샷을 다시 민다 — 그대로 두면 방금 넣은 바이옴이 다음 프레임에 지워진다.
	# 뷰도 멈춘다: 매 프레임 카메라를 다시 세우므로 견본대 구도를 직접 잡으려면 필요하다.
	node.set_process(false)
	node.set_physics_process(false)
	view.set_process(false)
	view.set_physics_process(false)
	var base: Dictionary = node._field.snapshot()
	print("view=%s · 바이옴 %d · 후보 %d" % [view.get_class(), BIOMES.size(), VARIANTS.size()])
	for biome_id in BIOMES:
		var biome := _biome(biome_id)
		if biome.is_empty():
			printerr("바이옴을 못 찾았다: %s" % biome_id)
			quit(1)
			return
		var snapshot := base.duplicate(true)
		snapshot["biome"] = biome_id
		snapshot["kit"] = String(biome.get("topologyKit", ""))
		snapshot["palette"] = FonsBiomePalette.from_biome(biome)
		view.apply(snapshot)
		for f in 6:
			await process_frame
		_hide_game(view)
		# 툰 모델이 뷰의 조명·환경을 읽는다 — 바이옴을 갈아 끼울 때마다 다시.
		_shade.setup(view)
		print("%s · 태양 %s x %.2f · 환경 %s x %.2f" % [biome_id,
			view._light.light_color.to_html(false), view._light.light_energy,
			view._environment.ambient_light_color.to_html(false),
			view._environment.ambient_light_energy])
		if not _build_lineup(view, String(snapshot["kit"])):
			printerr("견본대를 못 세웠다: %s (kit=%s)" % [biome_id, snapshot["kit"]])
			quit(1)
			return
		_capture_base(_lineup)
		# 견본대를 감춘 한 장 — 기준 화소를 잡는 바탕이다(아래 _shoot 주석).
		_lineup.visible = false
		var empty := await _both(cam, biome_id, "lineup", false)
		_lineup.visible = true
		await _shoot(cam, biome_id, empty)
		_restore()
		await _sheet(biome_id)
		if _lineup != null:
			_lineup.queue_free()
			_lineup = null
	quit()


func _shoot(cam: Camera3D, biome_id: String, empty: Image) -> void:
	## 후보를 하나씩 찍는다. C 는 A 와 **같은 화소**에서 그늘·평균을 재어 기록한다 — 안 맞추면
	## 셰이딩 모양이 아니라 노출 차이를 보게 되고, 판정이 "툰은 어둡다"로 끝나 버린다(첫 렌더 실측).
	## 기준 화소는 **셰이딩이 바뀐 곳**(두 그림이 다른 화소)이다 — 화면 평균을 쓰면 지형이 절반을
	## 차지해 부품의 밝기 차이가 묻힌다(앞선 실측: 지형 포함하면 차이가 1/10 로 줄었다).
	var img_a: Image = null
	for variant in ["a_current", "b_flat"]:
		_restore()
		_apply(variant)
		var img := await _both(cam, biome_id, variant)
		if variant == "a_current":
			img_a = img
	# 노출은 모듈이 정한 값(1.1)으로 고정한다. 노출로 평균을 맞추면 태양 항만 커져 색이 틀어진다 —
	# 회색 돌이 따뜻하게 물들었다(실측: A (0.27 0.28 0.28) → C (0.29 0.27 0.23)). 색이 정본이다.
	print("툰 모델 — 밴드 %.2f/%.2f 중간 %.2f 바닥 %.2f · 환경광 x%.1f · 노출 %.2f · 광택 %.4f · 균형 %s · 태양 보정 x%.3f"
		% [FonsToonShade.BAND_LOW, FonsToonShade.BAND_HIGH, FonsToonShade.BAND_MID,
			FonsToonShade.BAND_FLOOR, _shade.ambient_fill,
			_shade.exposure, _shade.specular_gain, str(_shade.balance), _shade.sun_scale])
	# 기준 화소 — **견본대가 차지한 자리**를, 견본대를 감춘 같은 구도와 견주어 잡는다.
	# 예전에는 C 의 첫 그림과 A 의 차이로 잡았는데, 화소 집합이 C 값에 따라 달라져서
	# 값 조합끼리 비교가 안 됐다(2026-10-28 실측: 같은 값·다른 실행에서 A 평균이 0.198/0.182 로 갈렸다).
	var coords: Array = _mask_stats(empty, img_a).get("coords", [])
	# 행을 훑기 전에 C 를 한 번 깔아 둔다 — 행은 값만 갈아 끼우고 `_refresh()` 가 깔린 재질에 민다.
	# (이 한 줄을 빼면 다섯 행이 모두 A 를 찍는다 — 2026-10-28 실측으로 겪었다.)
	_restore()
	_apply("c_toon")
	# 노출 보정 — 밴드 셰이더는 표준 셰이더보다 어둡다(C 평균이 A 의 0.83배 · 실측). 그대로 찍으면
	# 셰이딩이 아니라 노출 차이를 보게 된다. 몇 노출을 훑어 **A 와 같은 화소**의 평균·색을 찍는다.
	for pair: Array in CALIBRATION:
		_shade.exposure = pair[0]
		_shade.specular_gain = pair[1]
		_shade.ambient_fill = pair[2]

		var shot := await _both(cam, biome_id, "c_toon", false)
		var table := _mask_stats(img_a, shot, coords)
		var rgb: Vector3 = table.get("rgb_c", Vector3.ZERO)
		# 그늘(p10)과 밝은 면(p90)을 같이 찍는다 — 평균만 보면 광택을 올린 판과 환경광을 올린 판이 같아 보인다.
		print("   노출 %.2f 광택 %.4f 환경 %.1f · C 평균 %.3f (A %.3f) p10 %.3f (A %.3f) p90 %.3f (A %.3f) · 색 (%.3f %.3f %.3f) · 오차 %+.3f"
			% [pair[0], pair[1], pair[2], float(table["mean_c"]), float(table["mean_a"]),
				float(table["p10_c"]), float(table["p10_a"]),
				float(table["p90_c"]), float(table["p90_a"]),
				rgb.x, rgb.y, rgb.z, (rgb - (table["rgb_a"] as Vector3)).length()])
	_shade.exposure = FonsToonShade.EXPOSURE
	_shade.specular_gain = FonsToonShade.SPECULAR_GAIN
	_shade.ambient_fill = FonsToonShade.AMBIENT_FILL
	_restore()
	_apply("c_toon")
	var fin_c := await _both(cam, biome_id, "c_toon")
	var fin := _mask_stats(img_a, fin_c, coords)
	var rgb_a: Vector3 = fin.get("rgb_a", Vector3.ZERO)
	var rgb_c: Vector3 = fin.get("rgb_c", Vector3.ZERO)
	print("%s · 바뀜 화소 %d · A 평균 %.3f p10 %.3f p90 %.3f · C 평균 %.3f p10 %.3f p90 %.3f"
		% [biome_id, int(fin["count"]), float(fin["mean_a"]), float(fin["p10_a"]),
			float(fin["p90_a"]), float(fin["mean_c"]), float(fin["p10_c"]), float(fin["p90_c"])])
	# 색은 세 자리로 찍는다 — 균형 계수를 여기서 되잡는다.
	print("   색 · A (%.3f %.3f %.3f) / C (%.3f %.3f %.3f) · 오차 %+.3f"
		% [rgb_a.x, rgb_a.y, rgb_a.z, rgb_c.x, rgb_c.y, rgb_c.z,
			(rgb_c - rgb_a).length()])


func _both(cam: Camera3D, biome_id: String, variant: String, save := true) -> Image:
	## 같은 후보의 두 구도(기본 거리·근접). `save=false` 는 밝기만 재는 패스다.
	## 돌려주는 그림은 **근접 구도** — 재는 화소(`coords`)가 그 구도에서 잡힌다.
	cam.global_position = Vector3(CENTER.x, _ground + FAR_HEIGHT, CENTER.y + FAR_BACK)
	cam.look_at(Vector3(CENTER.x, _ground + 1.6, CENTER.y))
	for f in 4:
		await process_frame
	if save:
		await _save("%s/%s_%s_far.png" % [OUT_DIR, biome_id, variant])
	cam.global_position = Vector3(_near_x, _ground + NEAR_HEIGHT, CENTER.y + NEAR_BACK)
	cam.look_at(Vector3(_near_x, _ground + 1.7, CENTER.y))
	for f in 4:
		await process_frame
	if save:
		return await _save("%s/%s_%s_near.png" % [OUT_DIR, biome_id, variant])
	return await _grab()


func _hide_game(view: Node) -> void:
	## 게임이 깐 프롭·영웅·몬스터를 감춘다 — 견본대만 남겨야 세 후보의 차이가 보인다.
	## HUD(층 라벨·스탯 판·표식)도 같이 감춘다. 화면 오른쪽을 판이 덮으면 시트에서 부품을 가린다.
	if view._kit_root is Node3D:
		(view._kit_root as Node3D).visible = false
	if view._entities_root is Node3D:
		(view._entities_root as Node3D).visible = false
	var hud := _main.get_node_or_null("Hud") if _main != null else null
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	# 뷰가 따로 얹는 "Overlay" 레이어 — 파티 칸과 HP 바. 견본대와 무관하다.
	var overlay := view.get_node_or_null("Overlay")
	if overlay is CanvasLayer:
		(overlay as CanvasLayer).visible = false


func _build_lineup(view: Node, kit: String) -> bool:
	## 키트 `.glb` 의 부품을 한 줄로 세운다. 피벗이 바닥 중앙이라 지형 높이에 그대로 앉는다.
	## 색은 게임과 같게 role 틴트를 건다 — 바이옴 색이 빠지면 두 바이옴이 같은 회색이 된다.
	var packed := load(KIT_DIR % kit) as PackedScene
	if packed == null:
		return false
	var source := packed.instantiate()
	var parts := _collect(source)
	if parts.is_empty():
		source.free()
		return false
	var root := Node3D.new()
	root.name = "ShadingLineup"
	var world: Node3D = view._world
	world.add_child(root)
	var picks: Array = []
	for family in LINEUP:
		var prefix: String = family[0]
		var want: int = family[1]
		for i in mini(want, (parts[prefix] as Array).size()):
			picks.append(parts[prefix][i])
	var span := SPACING * float(maxi(picks.size() - 1, 1))
	var tints: Dictionary = view.current_kit_tints()
	_ground = view.terrain_height(CENTER.x, CENTER.y)
	_near_x = CENTER.x - span * 0.5 + SPACING * 0.5
	for i in picks.size():
		var part: Node3D = (picks[i] as Node3D).duplicate()
		root.add_child(part)
		var x := CENTER.x - span * 0.5 + SPACING * float(i)
		part.position = Vector3(x - CENTER.x, view.terrain_height(x, CENTER.y), 0.0)
		part.rotation_degrees.y = 0.0
	FonsBiomeKit._tint_node(root, tints, {})
	root.position = Vector3(CENTER.x, 0.0, CENTER.y)
	_lineup = root
	source.free()
	return true


func _collect(node: Node) -> Dictionary:
	## glTF 임포트는 부품을 루트 바로 아래에 두지 않을 수 있다 — 끝까지 내려가며 모은다.
	var out := {"landmark_": [], "height_": [], "prop_": []}
	return _collect_into(node, out)


func _collect_into(node: Node, out: Dictionary) -> Dictionary:
	for child in node.get_children():
		var part_name := String(child.name)
		var matched := false
		for prefix in out:
			if part_name.begins_with(prefix):
				out[prefix].append(child)
				matched = true
				break
		if not matched:
			out = _collect_into(child, out)
	return out


func _capture_base(root: Node) -> void:
	## 후보를 갈아 끼우기 전의 메시·재질 덮개를 기억한다. 되돌리기가 없으면 두 번째 후보부터
	## 앞 후보가 남긴 상태 위에 겹쳐 찍혀 세 장이 서로 다른 조건의 그림이 된다.
	_base_meshes.clear()
	_base_overrides.clear()
	for instance in _meshes(root):
		_base_meshes[instance.get_instance_id()] = instance.mesh
		var overrides: Array = []
		for i in instance.mesh.get_surface_count():
			overrides.append(instance.get_surface_override_material(i))
		_base_overrides[instance.get_instance_id()] = overrides


func _restore() -> void:
	if _lineup == null:
		return
	_shade.clear()
	for instance in _meshes(_lineup):
		var id: int = instance.get_instance_id()
		if _base_meshes.has(id):
			instance.mesh = _base_meshes[id]
		if not _base_overrides.has(id):
			continue
		var overrides: Array = _base_overrides[id]
		for i in overrides.size():
			if instance.mesh != null and i < instance.mesh.get_surface_count():
				instance.set_surface_override_material(i, overrides[i])


func _apply(variant: String) -> void:
	if _lineup == null:
		return
	match variant:
		"a_current":
			pass
		"b_flat":
			# 부품만 편다. 지형은 후보 정의상 그대로 — 높이 함수 중심차분 법선을 유지한다.
			for instance in _meshes(_lineup):
				instance.mesh = _flat_mesh(instance.mesh)
		"c_toon":
			_shade.apply(_lineup)


func _packed(value: Variant, fallback: Variant) -> Variant:
	## 서피스에 없는 속성은 null 로 온다 — 타입 있는 배열에 그대로 넣으면 대입에서 죽는다.
	return value if value != null else fallback


func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out


func _flat_mesh(mesh: ArrayMesh) -> ArrayMesh:
	## 면마다 정점을 복제하고 그 면의 기하 법선을 넣는다 = 플랫 셰이딩.
	## 부호는 원래 정점 법선의 합으로 정한다 — 감기 순서를 뒤집으면 앞면이 컬링된다.
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = _packed(arrays[Mesh.ARRAY_VERTEX], PackedVector3Array())
		var normals: PackedVector3Array = _packed(arrays[Mesh.ARRAY_NORMAL], PackedVector3Array())
		var indices: PackedInt32Array = _packed(arrays[Mesh.ARRAY_INDEX], PackedInt32Array())
		var colors: PackedColorArray = _packed(arrays[Mesh.ARRAY_COLOR], PackedColorArray())
		var uvs: PackedVector2Array = _packed(arrays[Mesh.ARRAY_TEX_UV], PackedVector2Array())
		if verts.is_empty():
			continue
		var count := indices.size() if indices.size() > 0 else verts.size()
		var flat_verts := PackedVector3Array()
		var flat_normals := PackedVector3Array()
		var flat_colors := PackedColorArray()
		var flat_uvs := PackedVector2Array()
		for t in range(0, count - 2, 3):
			var a: int = indices[t] if indices.size() > 0 else t
			var b: int = indices[t + 1] if indices.size() > 0 else t + 1
			var c: int = indices[t + 2] if indices.size() > 0 else t + 2
			var p0 := verts[a]
			var p1 := verts[b]
			var p2 := verts[c]
			var face := (p1 - p0).cross(p2 - p0)
			if face.length_squared() > 0.0:
				face = face.normalized()
			var hint := normals[a] + normals[b] + normals[c]
			if hint.length_squared() > 0.0 and face.dot(hint) < 0.0:
				face = -face
			for index in [a, b, c]:
				flat_verts.append(verts[index])
				flat_normals.append(face)
				if colors.size() > 0:
					flat_colors.append(colors[index])
				if uvs.size() > 0:
					flat_uvs.append(uvs[index])
		var out_arrays := []
		out_arrays.resize(Mesh.ARRAY_MAX)
		out_arrays[Mesh.ARRAY_VERTEX] = flat_verts
		out_arrays[Mesh.ARRAY_NORMAL] = flat_normals
		if flat_colors.size() > 0:
			out_arrays[Mesh.ARRAY_COLOR] = flat_colors
		if flat_uvs.size() > 0:
			out_arrays[Mesh.ARRAY_TEX_UV] = flat_uvs
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
		out.surface_set_material(s, mesh.surface_get_material(s))
	return out


func _biome(id: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))
	for group in data.get("groups", []):
		for biome in (group as Dictionary).get("biomes", []):
			if String((biome as Dictionary).get("id", "")) == id:
				return biome
	return {}


func _save(path: String) -> Image:
	var img: Image = await _grab()
	if img == null or img.is_empty():
		printerr("viewport texture empty: %s" % path)
		return img
	img.save_png(path)
	print("저장 %s" % path)
	return img


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _mask_stats(a: Image, c: Image, coords: Array = []) -> Dictionary:
	## 두 그림이 다른 화소만 모아 명도 분포를 잰다 — 부품이 있는 곳이 그 자리다.
	## 문턱 0.02(sRGB 차이)는 안티에일리어싱 잡음과 실제 셰이딩 변화를 가르는 하네스 값.
	## 재는 값은 **선형광**이다 — 셰이더가 선형으로 더하므로 계수도 그 단위에서 내야 한다.
	var la: Array[float] = []
	var lc: Array[float] = []
	if a == null or c == null or a.is_empty() or c.is_empty():
		return {"count": 0}
	if coords.is_empty():
		for y in range(0, a.get_height(), 2):
			for x in range(0, a.get_width(), 2):
				if absf(a.get_pixel(x, y).get_luminance() - c.get_pixel(x, y).get_luminance()) > 0.02:
					coords.append(Vector2i(x, y))
	var sum_a := Vector3.ZERO
	var sum_c := Vector3.ZERO
	for at in coords:
		var ca := a.get_pixel(at.x, at.y)
		var cc := c.get_pixel(at.x, at.y)
		la.append(ca.srgb_to_linear().get_luminance())
		lc.append(cc.srgb_to_linear().get_luminance())
		sum_a += Vector3(ca.r, ca.g, ca.b)
		sum_c += Vector3(cc.r, cc.g, cc.b)
	if la.is_empty():
		return {"count": 0, "mean_a_lin": 0.0, "mean_c_lin": 0.0}
	la.sort()
	lc.sort()
	var n := float(maxi(coords.size(), 1))
	return {"count": la.size(), "coords": coords, "mean_a_lin": _mean(la), "mean_c_lin": _mean(lc),
		"rgb_a": sum_a / n, "rgb_c": sum_c / n,
		"mean_a": _to_srgb(_mean(la)), "mean_c": _to_srgb(_mean(lc)),
		"p10_a": _to_srgb(_at(la, 0.10)), "p10_c": _to_srgb(_at(lc, 0.10)),
		"p90_a": _to_srgb(_at(la, 0.90)), "p90_c": _to_srgb(_at(lc, 0.90))}


func _to_srgb(linear: float) -> float:
	## 화면에 보이는 값으로 되돌린다 — 판정 문턱을 눈이 보는 단위로 적기 위해서다.
	return Color(linear, linear, linear).linear_to_srgb().r


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / float(maxi(values.size(), 1))


func _at(values: Array[float], fraction: float) -> float:
	return values[clampi(int(float(values.size() - 1) * fraction), 0, values.size() - 1)]


func _sheet(biome_id: String) -> void:
	## 후보 3열 × 구도 2행. 파일만 읽는다 — 3D 상태와 무관하다.
	var rows := ["near", "far"]
	var size := Vector2i(
		int(MARGIN * 2.0 + CELL.x * VARIANTS.size() + GAP * (VARIANTS.size() - 1)),
		int(HEADER + MARGIN * 2.0 + (CELL.y + ROW_LABEL) * rows.size() + GAP))
	var sheet_view := SubViewport.new()
	sheet_view.size = size
	sheet_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet_view)
	var sheet := Control.new()
	sheet.size = Vector2(size)
	sheet_view.add_child(sheet)
	var back := ColorRect.new()
	back.color = Color(0.063, 0.063, 0.07)
	back.size = sheet.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(back)
	_label(sheet, "%s — 셰이딩 후보 (위: 근접 · 아래: 기본 거리)" % biome_id,
		Vector2(MARGIN, 7.0), 17)
	for r in rows.size():
		for c in VARIANTS.size():
			_cell(sheet, "%s/%s_%s_%s.png" % [OUT_DIR, biome_id, VARIANTS[c], rows[r]],
				Vector2(MARGIN + float(c) * (CELL.x + GAP),
					HEADER + MARGIN + float(r) * (CELL.y + ROW_LABEL + GAP)))
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sheet_view.get_texture().get_image()
	var out := "%s/%s_sheet.png" % [OUT_DIR, biome_id]
	img.save_png(out)
	print("시트 %s %dx%d" % [out, img.get_width(), img.get_height()])
	sheet_view.queue_free()


func _cell(sheet: Control, path: String, at: Vector2) -> void:
	var image := Image.load_from_file(path)
	if image == null:
		printerr("칸 이미지를 못 읽었다: %s" % path)
		return
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = at
	rect.size = CELL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(rect)
	_label(sheet, path.get_file().get_basename(), at + Vector2(3.0, CELL.y + 1.0), 12)


func _label(sheet: Control, text: String, at: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.91, 0.92, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(label)
