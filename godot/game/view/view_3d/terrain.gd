class_name FonsTerrain
extends RefCounted
## 연속 높이필드 — 필드 하나를 **한 장의 메시**로 뜬다. 타일을 이어 붙이지 않는다.
##
## 왜 한 장인가
## ------------
## 5유닛 판때기를 이어 붙이면 판마다 법선이 따로 계산된다. 색을 같게 발라도
## 가장자리에서 조명이 끊겨 격자로 읽힌다 (2026-10-24 렌더 판정).
## 정점을 공유하면 법선도 공유되므로 경계가 생길 자리가 없다.
##
## 높이는 **월드 좌표의 함수**다. 메시도, 유닛 발밑 높이도, 프롭 자리도 같은 함수를 부른다 —
## 따로 계산하면 유닛이 땅에 뜨거나 박힌다.
##
## 축은 셋이고, 마인크래프트 콜로맵처럼 **역할별**로 나눈다:
##   큰 결  ← fBm 3옥타브, 주파수 0.03 (≈33유닛 파장) — 언덕·안부
##   잔 결  ← fBm 2옥타브, 주파수 0.09 — 지표의 미세한 흔들림
##   변위   ← domain warp 2.4유닛 — 노이즈 결이 규칙적으로 보이지 않게 흐트러뜨린다
## 기복 크기는 `relief` 하나로 곱한다. 카테고리가 정한다(`FonsBiomePalette`).
##
## 색은 굽지 않고 **정점색**으로 넣는다. 높이(따뜻한 능선 ↔ 차가운 골)와
## 경사(가파르면 암석)로 갈라지므로, 바이옴 지면색 하나로도 지형이 읽힌다.
##
## 조우 지점은 평평하게 누른다. 원기둥·유닛 밑동이 경사에 뜨면 지형이 아니라
## 오브젝트가 붕 뜬 것으로 읽힌다. 반경 안은 한 높이로, 그 밖 2유닛은 부드럽게 잇는다.

## 정점 간격 — 1유닛. 40×28 이면 41×29 = 1189정점, 삼각형 2240장. 충분히 싸다.
const STEP := 1.0
## 판 바깥으로 더 뜨는 폭. 3인칭 카메라가 필드 밖으로 나가므로, 지면이 거기서 끝나면
## 허공이 보인다. 플레이 경계는 그대로 40×28 이고 이 여유는 **보이는 땅**만 늘린다.
const MARGIN := 12.0
## 큰 결 — 0.03 은 33유닛 파장. 필드 폭 40 에 결이 하나 남짓 걸린다.
const HILL_FREQ := 0.03
const HILL_OCTAVES := 3
const HILL_GAIN := 0.78
## 잔 결 — 큰 결의 3배 주파수. 0.78 + 0.30 = 1.08 이 최대 진폭 배율.
const DETAIL_FREQ := 0.09
const DETAIL_OCTAVES := 2
const DETAIL_GAIN := 0.30
## domain warp — 2.4유닛이면 33유닛 파장의 7% 라 결이 흐트러지되 모양은 남는다.
const WARP_FREQ := 0.02
const WARP_AMOUNT := 2.4
## 색 축 — 높이·경사·큰 얼룩. 얼룩은 지면이 한 색으로 눕지 않게 한다.
const PATCH_FREQ := 0.055
const PATCH_GAIN := 0.14
## 잔얼룩 — 2~3유닛 결. 넓은 명암이 얼룩으로 보이지 않게 색에 입자를 넣는다.
const GRAIN_FREQ := 0.35
const GRAIN_GAIN := 0.06
## 골·능선 음영 — 이웃보다 낮으면 어둡고 높으면 밝다. 조명이 약해도 기복이 읽히게 한다.
const CONCAVE_GAIN := 0.9
const CONCAVE_MIN := -0.16
const CONCAVE_MAX := 0.12
## 조우 지점 평탄 반경 — 원기둥 지름(1.5)과 유닛 크기를 넣고도 여유가 남는 폭.
const FLAT_RADIUS := 3.0
## 평탄면과 원래 지형을 잇는 폭. 0 이면 계단이 생긴다.
const FLAT_FEATHER := 2.0
## 이 기울기(유닛당 높이차)를 넘으면 암석으로 민다.
## 실측: 이 지형의 기울기는 p50 0.07 · p90 0.12 · 최대 0.18 이다. 0.13 이면 상위 5% 언저리만 돌로 읽힌다.
const ROCK_SLOPE := 0.16
## 경사 축은 넓게 퍼지지 않는다 — 문턱을 딱 자르면 정점 하나가 바뀔 때 사각 얼룩이 생긴다.
## 0.05 폭으로 부드럽게 넘긴다.
const ROCK_SOFT := 0.05
## 암석은 식생과 **명도가 같아야** 한다. 어둡게 두면 경사가 그림자 얼룩으로 읽힌다(2026-10-24 렌더).
const ROCK_DRY := Color(0.64, 0.62, 0.57)
const ROCK_MAX := 0.40

var field: Vector2
var seed_value: int
var relief: float
## 평탄화할 지점(x, z) — 조우 자리. 비어 있으면 지형 그대로다.
var flats: Array = []
var flat_radius := FLAT_RADIUS
var _flat_heights: Array = []
var _hill: FastNoiseLite
var _detail: FastNoiseLite
var _warp: FastNoiseLite
var _patch: FastNoiseLite
var _grain: FastNoiseLite


func _init(field_size: Vector2, scene_seed: int, relief_amount: float,
		flat_points: Array = [], radius: float = FLAT_RADIUS) -> void:
	field = field_size
	seed_value = scene_seed
	relief = relief_amount
	flats = flat_points
	flat_radius = radius
	_hill = _make_noise(HILL_FREQ, HILL_OCTAVES)
	_detail = _make_noise(DETAIL_FREQ, DETAIL_OCTAVES)
	_warp = _make_noise(WARP_FREQ, 2)
	_patch = _make_noise(PATCH_FREQ, 2)
	_grain = _make_noise(GRAIN_FREQ, 1)
	# 평탄면 높이는 **원래 지형**에서 딱 한 번 재서 고정한다 — 매번 다시 재면
	# 평탄화가 자기 자신을 참조하게 된다.
	for point in flats:
		_flat_heights.append(_raw_height(point.x, point.y))


func _make_noise(frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0
	return noise


func height_at(x: float, z: float) -> float:
	## 메시·유닛·프롭이 모두 이 함수를 부른다 — 높이의 정본은 하나다.
	if relief <= 0.0:
		return 0.0
	var h := _raw_height(x, z)
	for i in flats.size():
		var point: Vector2 = flats[i]
		var away := Vector2(x - point.x, z - point.y).length()
		var weight := 1.0 - smoothstep(flat_radius, flat_radius + FLAT_FEATHER, away)
		if weight > 0.0:
			h = lerpf(h, float(_flat_heights[i]), weight)
	return h


func _raw_height(x: float, z: float) -> float:
	## 평탄화를 모르는 원래 높이 — 평탄면 기준값을 여기서 뜬다.
	var wx := x + _warp.get_noise_2d(x, z) * WARP_AMOUNT
	var wz := z + _warp.get_noise_2d(z + 137.0, x - 61.0) * WARP_AMOUNT
	var h := _hill.get_noise_2d(wx, wz) * HILL_GAIN + _detail.get_noise_2d(wx, wz) * DETAIL_GAIN
	return h * relief


func vertex_count() -> int:
	return (_cols() + 1) * (_rows() + 1)


func _cols() -> int:
	return int(ceil((field.x + MARGIN * 2.0) / STEP))


func _rows() -> int:
	return int(ceil((field.y + MARGIN * 2.0) / STEP))


func build(base: Color, tints: Dictionary = {}) -> ArrayMesh:
	## 높이필드 한 장. 법선은 높이 함수의 기울기로 직접 계산한다 — 삼각형 격자가
	## 법선에 새지 않아 플랫 셰이딩처럼 면이 드러나지 않는다.
	var cols := _cols()
	var rows := _rows()
	var heights := PackedFloat32Array()
	var raw := PackedFloat32Array()
	heights.resize((cols + 1) * (rows + 1))
	raw.resize((cols + 1) * (rows + 1))
	for j in rows + 1:
		for i in cols + 1:
			heights[j * (cols + 1) + i] = height_at(i * STEP - MARGIN, j * STEP - MARGIN)
			raw[j * (cols + 1) + i] = _raw_height(i * STEP - MARGIN, j * STEP - MARGIN)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rows + 1:
		for i in cols + 1:
			var x := i * STEP - MARGIN
			var z := j * STEP - MARGIN
			var h := heights[j * (cols + 1) + i]
			tool.set_color(_vertex_color(base, tints, raw, cols, i, j))
			tool.set_normal(_normal_at(x, z))
			tool.add_vertex(Vector3(x, h, z))
	for j in rows:
		for i in cols:
			var a := j * (cols + 1) + i
			var b := a + 1
			var c := a + (cols + 1)
			var d := c + 1
			# 앞면이 위(+Y)를 향하는 감기 순서 — 반대로 감으면 지면이 통째로 컬링된다.
			for index in [a, b, c, b, d, c]:
				tool.add_index(index)
	return tool.commit()


func _normal_at(x: float, z: float) -> Vector3:
	# 중심차분. 2*STEP 로 나눠 유닛당 기울기를 얻는다.
	# **평탄화를 빼고** 잰다. 평탄면 정점이 모두 위를 보면 조우 자리가 밝은 원판으로 뜬다 —
	# 지형은 평평하되 명암은 주변 언덕을 따라가게 둔다(2026-10-24 렌더).
	var dx := _raw_height(x + STEP, z) - _raw_height(x - STEP, z)
	var dz := _raw_height(x, z + STEP) - _raw_height(x, z - STEP)
	return Vector3(-dx, 2.0 * STEP, -dz).normalized()


func _vertex_color(base: Color, tints: Dictionary,
		raw: PackedFloat32Array, cols: int, i: int, j: int) -> Color:
	## 높이 → 골은 차갑게, 능선은 따뜻하게. 경사 → 암석. 얼룩 → 한 색으로 눕지 않게.
	## 색은 전부 **평탄화를 뺀** 높이에서 낸다 — 조우를 누른 자리가 밝은 원판으로 뜨지 않게.
	var row := cols + 1
	var last_row := raw.size() / row - 1
	var here := raw[j * row + i]
	var dx := raw[j * row + mini(i + 1, cols)] - raw[j * row + maxi(i - 1, 0)]
	var dz := raw[mini(j + 1, last_row) * row + i] - raw[maxi(j - 1, 0) * row + i]
	var slope := sqrt(dx * dx + dz * dz) / (2.0 * STEP)

	var x := i * STEP - MARGIN
	var z := j * STEP - MARGIN
	var patch := _patch.get_noise_2d(x, z) * 0.5 + 0.5
	var grain := _grain.get_noise_2d(x, z) * 0.5 + 0.5
	var shade := 1.0 - PATCH_GAIN * 0.5 + PATCH_GAIN * patch
	shade *= 1.0 - GRAIN_GAIN * 0.5 + GRAIN_GAIN * grain
	# 볼록·오목 — 주변 평균과의 차이. 부드러운 땅에서도 능선과 골이 남는다.
	var around := (raw[j * row + mini(i + 1, cols)] + raw[j * row + maxi(i - 1, 0)]
		+ raw[mini(j + 1, last_row) * row + i] + raw[maxi(j - 1, 0) * row + i]) * 0.25
	shade *= 1.0 + clampf((around - here) * CONCAVE_GAIN, CONCAVE_MIN, CONCAVE_MAX)
	# 얼룩은 명도만이 아니라 **색**을 바꾼다 — 값만 흔들면 한 색 판에 얼룩이 앉은 것으로 보인다.
	# 마른 어깨(누렇게, 채도 낮게) ↔ 습한 골(짙게, 채도 높게).
	var dry := Color.from_hsv(base.h + 0.035, maxf(0.0, base.s - 0.16), minf(1.0, base.v * 1.06))
	var wet := Color.from_hsv(base.h - 0.015, minf(1.0, base.s + 0.10), base.v * 0.86)
	var tint := dry.lerp(wet, patch)
	tint = tint * shade
	var span := maxf(relief, 0.001)
	if here < 0.0:
		tint = tint.lerp(Color.from_hsv(base.h, minf(1.0, base.s + 0.06), base.v * 0.90), minf(1.0, -here / span) * 0.5)
	else:
		tint = tint.lerp(Color.from_hsv(base.h + 0.02, base.s * 0.92, base.v * 1.10), minf(1.0, here / span) * 0.5)
	var rock := ROCK_DRY
	var rock_tint: Variant = tints.get("rock", null)
	if rock_tint is Color:
		# 곱하면 돌이 너무 어두워진다 — 명도는 ROCK_DRY 근처에 붙잡고 색온도만 받는다.
		rock = Color(rock.r * (rock_tint as Color).r, rock.g * (rock_tint as Color).g,
			rock.b * (rock_tint as Color).b).lerp(ROCK_DRY, 0.6)
	var weight := smoothstep(ROCK_SLOPE, ROCK_SLOPE + ROCK_SOFT, slope) * ROCK_MAX
	if weight > 0.0:
		tint = tint.lerp(rock, weight)
	# 색은 sRGB 로 굽는다. 재질의 `vertex_color_is_srgb` 가 한 번만 선형으로 바꾼다 —
	# 여기서 또 바꾸면 감마가 두 번 걸려 어두운 얼룩이 생긴다(2026-10-24 렌더).
	return tint


static func default_relief() -> float:
	## 바이옴을 모르는 화면(전투·헤드리스)은 지금처럼 평평하게 둔다.
	return 0.0
