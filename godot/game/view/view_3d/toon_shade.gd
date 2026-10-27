class_name FonsToonShade
extends RefCounted
## 툰 후보(C)의 **조명 모델** — 밝기 밴드, 태양/환경 비율, 노출, 색 균형을 여기 한 곳이 갖는다.
## 하네스(`tools/shot_shading_compare.gd`)는 이 모듈을 부르기만 한다. 채택하면 `view_3d` 가
## `_apply_palette` 뒤에 `apply()` 한 줄로 부른다.
##
## 조명은 **`light()` 가 아니라 `unshaded` + `fragment()`** 에서 계산한다. 이 렌더러에서 `light()` 의
## 확산·환경광 항이 화면에 거의 안 더해졌기 때문이다(§3.8 실측). 태양 방향·색·환경광을 uniform 으로
## 받아 밴드를 직접 계산하면 크기가 우리 손에 있다.
##
## 값은 2026-10-27 견본대 격자로 맞춘 것이다(§3.9 · 색 오차 plains 0.045 · ruins 0.053).
## **아직 채택 전이다** — 실그림자를 못 받고 지형이 안 덮인다. 채택하면 `tools/tracked_numbers.json`
## 을 먼저 거친다.

const SHADER_CODE := """
shader_type spatial;
render_mode cull_back, unshaded;

// **`light()` 를 쓰지 않는다.** 이 렌더러(`gl_compatibility`)에서 `light()` 안의 확산·환경광 항은
// 화면에 거의 안 더해지고 알베도를 안 곱하는 광택 항만 제 무게로 들어갔다(§3.8 실측: 환경광 10배에도
// 화소 불변, varying 알베도로 바꿔도 불변). 그래서 태양·환경광을 uniform 으로 받아 `fragment()` 에서
// 전부 계산한다 — 크기가 우리 손에 있고 엔진 스케일을 안 탄다. 대신 **실그림자를 못 받는다**.

// 재질의 `albedo_color` 는 sRGB 로 적혀 있다. `source_color` 힌트는 **런타임
// `set_shader_parameter` 에는 안 먹는다**(실측: 달아도 화소가 그대로) — 아래에서 직접 바꿔야 한다.
uniform vec4 albedo = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_vertex_color = false;
// 태양 — `sun_dir` 은 빛이 나아가는 방향(월드), `sun_color` 는 선형값에 세기를 곱한 것.
uniform vec3 sun_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 sun_color = vec3(1.0);
uniform float band_low = 0.45;
uniform float band_high = 0.72;
uniform float band_mid_gain = 0.82;
uniform float band_floor = 0.60;
uniform vec3 ambient_color = vec3(0.0);
uniform float fill = 1.0;
uniform float gain = 1.0;
uniform float specular_gain = 0.0;
uniform vec3 balance = vec3(1.0, 1.0, 1.0);

varying vec3 v_albedo;
varying vec3 v_normal;

void vertex() {
	// **감마를 걸지 않는다.** 이 렌더러는 `unshaded` 의 `ALBEDO` 를 화면까지 그대로 넘긴다
	// (실측: 상수 0.5 → PNG 0.502). 여기서 선형으로 바꾸면 잎 0.24 가 0.05 로 눌려 부품이 검게 죽는다
	// (실측: 관목 초록 0.05 · A 0.22).
	v_albedo = use_vertex_color ? albedo.rgb * COLOR.rgb : albedo.rgb;
	// 밴드에는 **면의 방향**만 필요하다 — 월드로 옮겨 두고 `fragment()` 에서 태양과 내적한다.
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float ndl = clamp(dot(normalize(v_normal), normalize(-sun_dir)), 0.0, 1.0);
	// 밴드는 **등진 면을 살리지 않는다** — 바닥값을 항상 더하면 태양을 등진 면도 60%를 받아
	// 전반이 두 배로 밝아지고 밝은 albedo 가 화이트로 탄다(실측: 관목 A 0.71 → C 1.00).
	// 그늘은 환경광 항이 맡는다.
	float band = step(0.0001, ndl) * (band_floor
		+ step(band_low, ndl) * (band_mid_gain - band_floor)
		+ step(band_high, ndl) * (1.0 - band_mid_gain));
	vec3 lit = v_albedo * balance * (sun_color * band * gain + ambient_color * fill);
	// 넓은 광택 — 표준 재질의 하이라이트는 **태양 색을 그대로 반사**하고 **albedo 를 안 곱한다**.
	// 이 항이 없으면 잎·풀처럼 파랑 albedo 가 낮은 면에서 색이 어긋난다.
	lit += sun_color * band * gain * specular_gain;
	ALBEDO = lit;
}
"""

## 밝기 문턱 셋과 그늘 바닥. 그늘도 `BAND_FLOOR` 만큼 태양을 받는다 — 0 으로 두면 그늘을
## 환경광으로만 메워야 해서 돌이 주황으로 물들었다(실측).
const BAND_LOW := 0.45
const BAND_HIGH := 0.72
const BAND_MID := 0.82
const BAND_FLOOR := 0.60
## 환경광 배율. 이 값이 그늘(p10)을 민다 — 1.7 에서는 그늘이 너무 어두웠고(plains p10 0.058 vs
## A 0.108), 3.4 에서는 밝은 면까지 넘쳤다. 2.6 이 두 바이옴을 A 대역에 넣는다(2026-10-28 격자).
const AMBIENT_FILL := 2.6
## 노출 — 태양 항의 크기. 0.63 이면 두 바이옴 평균이 A 대역에 든다(2026-10-28 고정 화소 격자:
## plains +2.8% · ruins +2.0%, 아래 환경광 배율까지 거친 값). 노출에는 바이옴 배율을 걸지 않는다 —
## 걸면 ruins 가 어두워져 두 바이옴이 다시 갈렸다.
const EXPOSURE := 0.63
## 바이옴 보정의 기준 태양 세기 — 온대(plains)의 값. 태양이 이보다 세면 툰이 A 보다 밝게 넘쳐
## **환경광**을 반비례해 깎는다(ruins 태양 1.23 → 배율 0.81 로 평균 +13.6% → +2.0%).
const SUN_REF := 0.99
## 깎는 하한 — 태양이 아주 약한 바이옴(어둠 0.62 · 동굴 모드 0.55)에서 배율이 무한정 작아지지 않게 막는다.
const SUN_SCALE_MIN := 0.5
## 넓은 광택 — 태양 색을 그대로 더하는 albedo 무관 하이라이트의 크기.
## 0.04 에서 관목처럼 파랑 알베도가 낮은 부품의 파랑을 A 쪽으로 올린다(색 오차 0.104 → 0.048).
const SPECULAR_GAIN := 0.035
## 색 균형 — 표준 셰이더(A)와 같은 화소에서 채널별로 맞춘 계수.
const BALANCE := Vector3(1.0, 1.0, 1.0)

## 하네스가 갈아 끼우는 값 — 바꾸면 이미 깔린 재질에 바로 반영된다(견본대에서 노출을 훑을 때 쓴다).
var exposure := EXPOSURE:
	set(value):
		exposure = value
		_refresh()
var balance := BALANCE:
	set(value):
		balance = value
		_refresh()
var specular_gain := SPECULAR_GAIN:
	set(value):
		specular_gain = value
		_refresh()
## 환경광 배율 — 광택과 **함께** 맞춰야 한다. 광택은 밝은 면을, 이 값은 그늘을 민다(§3.7).
var ambient_fill := AMBIENT_FILL:
	set(value):
		ambient_fill = value
		_refresh()
## 바이옴 보정 배율 — `setup()` 이 태양 세기에서 낸다. 환경광 항에만 곱한다(밝히지는 않는다).
var sun_scale := 1.0

var _shader: Shader
## instance_id → [노드, 덮기 전 재질 목록]. 되돌리기에만 쓴다.
var _saved: Dictionary = {}
var _cache: Dictionary = {}
## 깔아 둔 툰 재질 — 노출·색 균형을 바꾸면 여기로 밀어 넣는다.
var _materials: Array[ShaderMaterial] = []
## 바이옴 환경광 — 셰이더가 스스로 못 읽어 GDScript 에서 넘긴다.
var _ambient := Color.BLACK
## 태양 — 빛이 나아가는 방향(월드)과 선형 색×세기.
var _sun_dir := Vector3(0.0, -1.0, 0.0)
var _sun_color := Vector3.ONE


func setup(view: Node) -> void:
	## 뷰가 들고 있는 조명·환경을 읽는다. 바이옴을 갈아 끼울 때마다 다시 부른다.
	clear()
	_ambient = Color.BLACK
	_sun_color = Vector3.ZERO
	sun_scale = 1.0
	var env: Environment = view.get("_environment")
	if env != null:
		# 환경광 색은 sRGB 로 적혀 있다 — 셰이더는 선형으로 받는다.
		_ambient = (env.ambient_light_color * env.ambient_light_energy).srgb_to_linear()
	var light: DirectionalLight3D = view.get("_light")
	if light != null:
		# Godot 의 빛은 자기 `-Z` 로 나아간다. 다만 로컬 축 부호를 잘못 잡으면 `ndl` 이 전부 0 이 되어
		# 태양 항이 통째로 사라진다(실측: 확산 0 · 환경광만 남아 화면이 6배 어둡게). 태양은 항상
		# 아래로 내려쏘므로 y 부호로 강제한다.
		# 트리 밖 뷰(단위 테스트가 그렇게 만든다)는 `global_transform` 을 못 읽는다 — 지역 변환으로 대신.
		var basis := light.global_transform.basis if light.is_inside_tree() else light.transform.basis
		_sun_dir = (-basis.z).normalized()
		if _sun_dir.y > 0.0:
			_sun_dir = -_sun_dir
		var linear := light.light_color.srgb_to_linear() * light.light_energy
		_sun_color = Vector3(linear.r, linear.g, linear.b)
		# 바이옴 보정 — 태양이 기준(온대 0.99)보다 세면 **그늘 쪽(환경광)** 이 A 보다 밝아진다.
		# 실측: ruins 태양 1.23 · 보정 없이 평균 +13.6%(2026-10-28 고정 화소) → 배율 0.81 로 +2.0%.
		sun_scale = clampf(SUN_REF / maxf(light.light_energy, 0.001), SUN_SCALE_MIN, 1.0)
	_refresh()


func apply(root: Node) -> int:
	## 뿌리 아래 메시의 표준 재질을 툰 셰이더로 덮는다. 덮은 면 수를 돌려준다.
	## 색은 **지금 덮개(틴트)까지 반영한 값**을 옮겨야 바이옴 색이 사라지지 않는다.
	## 이미 덮인 면은 건너뛰지만, **다른 재질로 다시 칠해진 면은 다시 덮는다** — 바이옴을 갈아
	## 끼우면 키트가 틴트를 다시 걸고, 그때 건너뛰면 그 청크만 A 모습으로 남는다.
	if root == null:
		return 0
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var count := 0
	for instance: MeshInstance3D in _meshes(root):
		# 재질 덮개(`material_override`)가 있으면 **그것이 이긴다** — 지형 청크가 그렇다.
		# 발광(사이트 표식·유닛)과 알파(영웅 흐림)는 표준 재질에 맡긴다.
		var whole := instance.material_override
		if whole is StandardMaterial3D and _coverable(whole):
			var id := instance.get_instance_id()
			if not _saved.has(id):
				_saved[id] = [instance, _originals(instance), whole]
			instance.material_override = _material_from(whole)
			count += 1
			continue
		if whole != null:
			# 덮개가 있는데 우리 것이 아니면 **표면을 덮어도 안 보인다** — 그냥 둔다.
			continue
		for i in instance.mesh.get_surface_count():
			var current := instance.get_surface_override_material(i)
			if current is ShaderMaterial and (current as ShaderMaterial).shader == _shader:
				continue
			var id := instance.get_instance_id()
			if not _saved.has(id):
				_saved[id] = [instance, _originals(instance), whole]
			instance.set_surface_override_material(i, _material(instance, i))
			count += 1
	return count


func _coverable(material: StandardMaterial3D) -> bool:
	## 툰 셰이더에는 발광·투명 항이 없다. 표준 재질이 그 둘을 쓰고 있으면 건드리지 않는다.
	return not material.emission_enabled \
		and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED


func _originals(instance: MeshInstance3D) -> Array:
	var originals: Array = []
	for j in instance.mesh.get_surface_count():
		originals.append(instance.get_surface_override_material(j))
	return originals


func clear() -> void:
	## 덮기 전 상태로 되돌린다. 이미 사라진 노드는 건너뛴다.
	for id: Variant in _saved:
		var entry: Array = _saved[id]
		# 사라진 객체를 타입 있는 변수에 **먼저** 넣으면 대입에서 죽는다 — 무효 검사가 그 뒤에 있으면
		# `clear()` 가 통째로 터진다(실측: 하네스가 견본대를 지운 뒤). Variant 로 받아 검사부터 한다.
		var node: Variant = entry[0]
		if not is_instance_valid(node):
			continue
		var instance := node as MeshInstance3D
		var originals: Array = entry[1]
		for i in originals.size():
			if i < instance.mesh.get_surface_count():
				instance.set_surface_override_material(i, originals[i])
		instance.material_override = entry[2]
	_saved.clear()


func _refresh() -> void:
	## 노출·균형·광택을 바꾸면 이미 깔린 재질 전부에 민다. 환경광도 같이 — 바이옴을 바꾸면
	## `setup()` 이 `_ambient`·`sun_scale` 을 갈아 끼우므로, 여기서 안 밀면 지형만 이전 바이옴 빛을 받는다.
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("gain", exposure)
		material.set_shader_parameter("balance", balance)
		material.set_shader_parameter("specular_gain", specular_gain)
		material.set_shader_parameter("fill", ambient_fill * sun_scale)
		material.set_shader_parameter("ambient_color",
			Vector3(_ambient.r, _ambient.g, _ambient.b))
		material.set_shader_parameter("sun_dir", _sun_dir)
		material.set_shader_parameter("sun_color", _sun_color)


func _material(instance: MeshInstance3D, surface: int) -> ShaderMaterial:
	return _material_from(_source_material(instance, surface))


func _material_from(source: StandardMaterial3D) -> ShaderMaterial:
	var albedo := Color.WHITE
	var vertex_color := false
	if source != null:
		albedo = source.albedo_color
		vertex_color = source.vertex_color_use_as_albedo
	var key := "%s|%s|%.3f|%s|%.3f|%.3f" % [albedo.to_html(false), str(vertex_color),
		exposure, str(balance), specular_gain, ambient_fill]
	if _cache.has(key):
		return _cache[key]
	var material := _build(albedo, vertex_color)
	_cache[key] = material
	return material


func _build(albedo: Color, vertex_color: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("albedo", albedo)
	material.set_shader_parameter("use_vertex_color", vertex_color)
	material.set_shader_parameter("band_low", BAND_LOW)
	material.set_shader_parameter("band_high", BAND_HIGH)
	material.set_shader_parameter("band_mid_gain", BAND_MID)
	material.set_shader_parameter("band_floor", BAND_FLOOR)
	material.set_shader_parameter("fill", ambient_fill * sun_scale)
	material.set_shader_parameter("specular_gain", specular_gain)
	material.set_shader_parameter("gain", exposure)
	material.set_shader_parameter("balance", balance)
	material.set_shader_parameter("sun_dir", _sun_dir)
	material.set_shader_parameter("sun_color", _sun_color)
	material.set_shader_parameter("ambient_color",
		Vector3(_ambient.r, _ambient.g, _ambient.b))
	_materials.append(material)
	return material


func _source_material(instance: MeshInstance3D, surface: int) -> StandardMaterial3D:
	## 앞선 `apply()` 가 남긴 툰 재질은 원본이 아니다 — 두 번째 바퀴에서 그걸 읽으면 색이 샌다.
	var override := instance.get_surface_override_material(surface)
	if override is StandardMaterial3D:
		return override
	var base := instance.mesh.surface_get_material(surface)
	return base as StandardMaterial3D


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out
