extends GutTest
## 툰 후보의 조명 모듈 — 재질을 덮고, 되돌리고, 값을 바꾸면 이미 깔린 재질까지 따라오는지 잠근다.
## **색·밝기 자체는 여기서 안 잰다** — 렌더가 필요하므로 견본대 하네스(`tools/shot_shading_compare.gd`)가
## 같은 화소에서 A 와 나란히 잰다. 여기서 잠그는 것은 계약이다: 덮기·되돌리기·값 반영·색 옮기기.


func _box(color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child_autofree(instance)
	return instance


func test_apply_covers_and_clear_restores() -> void:
	var shade := FonsToonShade.new()
	var instance := _box(Color(0.3, 0.4, 0.2))
	assert_eq(shade.apply(instance), 1, "면 하나를 덮는다")
	var covered := instance.get_surface_override_material(0)
	assert_true(covered is ShaderMaterial, "덮개가 툰 재질")
	var material := covered as ShaderMaterial
	assert_eq(material.shader.code, FonsToonShade.SHADER_CODE, "후보 셰이더가 걸린다")
	assert_eq(material.get_shader_parameter("albedo"), Color(0.3, 0.4, 0.2), "색은 지금 재질 값을 옮긴다")
	assert_almost_eq(float(material.get_shader_parameter("band_low")), FonsToonShade.BAND_LOW, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter("fill")), FonsToonShade.AMBIENT_FILL, 0.0001)
	shade.clear()
	assert_null(instance.get_surface_override_material(0), "되돌리면 원래 덮개(없음)로 돌아간다")


func test_exposure_and_specular_reach_live_materials() -> void:
	## 견본대가 노출·광택을 훑을 때 이 경로로 값을 바꾼다 — 안 닿으면 표가 모두 같은 줄이 된다.
	var shade := FonsToonShade.new()
	var instance := _box(Color.WHITE)
	shade.apply(instance)
	var material := instance.get_surface_override_material(0) as ShaderMaterial
	assert_almost_eq(float(material.get_shader_parameter("gain")), FonsToonShade.EXPOSURE, 0.0001)
	shade.exposure = 1.5
	shade.specular_gain = 0.002
	shade.ambient_fill = 1.8
	assert_almost_eq(float(material.get_shader_parameter("gain")), 1.5, 0.0001, "노출이 깔린 재질에 반영된다")
	assert_almost_eq(float(material.get_shader_parameter("specular_gain")), 0.002, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter("fill")), 1.8, 0.0001, "환경광 배율도 같이 따라온다")


func test_second_apply_does_not_save_the_toon_material() -> void:
	## 두 번째 덮기가 툰 재질을 \"원본\"으로 저장하면 되돌리기가 안 돌아온다.
	var shade := FonsToonShade.new()
	var instance := _box(Color(0.2, 0.2, 0.2))
	shade.apply(instance)
	shade.apply(instance)
	shade.clear()
	assert_null(instance.get_surface_override_material(0), "두 번 덮어도 원본으로 돌아간다")


func test_material_override_is_covered_and_restored() -> void:
	## 지형 청크는 표면 덮개가 아니라 재질 덮개를 쓴다 — 그쪽도 덮여야 지형이 툰이 된다.
	var shade := FonsToonShade.new()
	var instance := _box(Color.WHITE)
	var base := StandardMaterial3D.new()
	base.albedo_color = Color(0.2, 0.3, 0.1)
	base.vertex_color_use_as_albedo = true
	instance.material_override = base
	assert_eq(shade.apply(instance), 1, "재질 덮개 한 개를 덮는다")
	var made := instance.material_override as ShaderMaterial
	assert_true(made is ShaderMaterial, "툰 재질로 바뀐다")
	assert_true(bool(made.get_shader_parameter("use_vertex_color")), "정점색 사용 여부를 옮긴다")
	shade.clear()
	assert_eq(instance.material_override, base, "되돌리면 원래 재질로 돌아간다")


func test_emissive_and_transparent_materials_are_left_alone() -> void:
	## 툰 셰이더에는 발광·투명 항이 없다. 표식·유닛의 발광과 영웅 물림을 덮으면 모습이 망가진다.
	var shade := FonsToonShade.new()
	for material in [_glowing(), _faded()]:
		var instance := _box(Color.WHITE)
		instance.material_override = material
		assert_eq(shade.apply(instance), 0, "덮지 않는다")
		assert_eq(instance.material_override, material, "원래 재질 그대로")


class StubView:
	extends Node

	var _light: DirectionalLight3D
	var _environment: Environment


func test_setup_scales_down_when_the_sun_is_stronger_than_the_reference() -> void:
	## 태양이 기준(온대 0.99)보다 센 바이옴은 노출·환경광을 함께 깎는다. ruins(태양 1.23)가
	## 보정 없이 A 보다 16% 밝게 넘쳤다 — 2026-10-28 재측정에서 두 축을 같이 내렸다.
	var shade := FonsToonShade.new()
	var view := StubView.new()
	add_child_autofree(view)
	var light := DirectionalLight3D.new()
	light.light_energy = 1.23
	view.add_child(light)
	view._light = light
	shade.setup(view)
	assert_almost_eq(shade.sun_scale, FonsToonShade.SUN_REF / 1.23, 0.001, "태양 세기에 반비례해 깎는다")
	var instance := _box(Color.WHITE)
	shade.apply(instance)
	var material := instance.get_surface_override_material(0) as ShaderMaterial
	assert_almost_eq(float(material.get_shader_parameter("gain")),
		FonsToonShade.EXPOSURE, 0.001, "노출은 건드리지 않는다")
	assert_almost_eq(float(material.get_shader_parameter("fill")),
		FonsToonShade.AMBIENT_FILL * shade.sun_scale, 0.001, "환경광에만 배율이 곱해진다")


func test_sun_scale_stays_inside_the_guard_rails() -> void:
	## 상한 1.0 — 기준보다 약한 태양은 밝히지 않는다. 하한 0.5 — 아주 센 태양에서도 그 밑으로는 안 간다.
	var shade := FonsToonShade.new()
	var view := StubView.new()
	add_child_autofree(view)
	var light := DirectionalLight3D.new()
	view.add_child(light)
	view._light = light
	light.light_energy = 0.1
	shade.setup(view)
	assert_almost_eq(shade.sun_scale, 1.0, 0.001, "약한 태양은 그대로 둔다")
	light.light_energy = 2.5
	shade.setup(view)
	assert_almost_eq(shade.sun_scale, FonsToonShade.SUN_SCALE_MIN, 0.001, "아주 센 태양은 하한에서 멈춘다")


func _glowing() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = Color(0.2, 0.2, 0.2)
	return material


func _faded() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func test_setup_without_environment_keeps_zero_ambient() -> void:
	var shade := FonsToonShade.new()
	var view := Node.new()
	add_child_autofree(view)
	shade.setup(view)
	var instance := _box(Color.WHITE)
	shade.apply(instance)
	var material := instance.get_surface_override_material(0) as ShaderMaterial
	assert_eq(material.get_shader_parameter("ambient_color"), Vector3.ZERO,
		"환경이 없는 뷰에서는 환경광을 안 더한다")


func test_clear_survives_a_freed_node() -> void:
	## 하네스는 견본대를 찍고 지운다 — 그 뒤 `clear()` 가 죽으면 다음 바이옴을 못 찍는다.
	var shade := FonsToonShade.new()
	var instance := _box(Color.WHITE)
	shade.apply(instance)
	instance.free()
	shade.clear()
	assert_true(true, "사라진 노드는 건너뛴다")
