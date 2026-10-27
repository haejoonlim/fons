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
## 판 바깥으로 더 뜨는 폭 — **최대 카메라 거리(30)보다 넓어야** 한다.
## 필드 가장자리에 선 캐릭터를 최대로 당겨 뒤로 빼면 카메라가 필드 밖 (최대 29.8)에 선다.
## 12 였을 때 그 자리에서 지면 끝이 보여 필드가 공중에 뜬 판으로 읽혔다 (2026-10-25 렌더).
## 플레이 경계는 그대로 40×28 이고 이 여유는 **보이는 땅**만 늘린다.
## 32 → 105×93 = 9765정점 · 19136삼각형. 1유닛 격자라 여전히 싸다.
const MARGIN := 32.0
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
## 오솔길 — 정점색으로만 긴다. 폭 1.4유닛(캐릭터 1.4폭)에 좌우 0.45씩 부드럽게 섞는다.
## 폭을 넓히면 발밑에서 화면 1/3을 길이 차지한다 — 3인칭 기본 거리 4.2에서 화면 폭이 약 7유닛이다.
const PATH_HALF := 0.7
const PATH_SOFT := 0.45
## 흙색 — 바이옴 틴트를 15% 섞어 눈·화산 지형에서도 그 바이옴의 흙으로 읽힌다.
## 너무 많이 섞으면 잔디와 대비가 죽어 멀리서 길이 안 보인다(2026-10-25 첫 렌더).
const PATH_EARTH := Color(0.58, 0.45, 0.30)

var field: Vector2
## 이 지형이 놓이는 **월드** 위치. 청크 스트리밍이 청크마다 다른 원점을 준다.
## 높이함수는 월드 좌표계의 함수다 — 원점이 달라도 이음매가 생기지 않는다.
var origin := Vector2.ZERO
## 판 바깥으로 더 뜨는 폭. 청크 메시는 0 — 이웃 청크가 그 자리를 채운다.
var margin := MARGIN
var seed_value: int
var relief: float
## 평탄화할 지점(x, z) — 조우 자리. 비어 있으면 지형 그대로다.
var flats: Array = []
## 오솔길 — `PackedVector2Array` 폴리라인의 배열. 정점색만 바꾸므로 지형 높이는 그대로다.
var trails: Array = []
var flat_radius := FLAT_RADIUS
var _flat_heights: Array = []
var _hill: FastNoiseLite
var _detail: FastNoiseLite
var _warp: FastNoiseLite
var _patch: FastNoiseLite
var _grain: FastNoiseLite


func _init(field_size: Vector2, scene_seed: int, relief_amount: float,
		flat_points: Array = [], radius: float = FLAT_RADIUS,
		trail_lines: Array = [], origin_at: Vector2 = Vector2.ZERO,
		margin_size: float = MARGIN) -> void:
	field = field_size
	origin = origin_at
	margin = margin_size
	seed_value = scene_seed
	relief = relief_amount
	flats = flat_points
	flat_radius = radius
	trails = trail_lines
	_hill = _make_noise(HILL_FREQ, HILL_OCTAVES)
	_detail = _make_noise(DETAIL_FREQ, DETAIL_OCTAVES)
	_warp = _make_noise(WARP_FREQ, 2)
	_patch = _make_noise(PATCH_FREQ, 2)
	_grain = _make_noise(GRAIN_FREQ, 1)
	# 평탄면 높이는 **원래 지형**에서 딱 한 번 재서 고정한다 — 매번 다시 재면
	# 평탄화가 자기 자신을 참조하게 된다.
	for point in flats:
		_flat_heights.append(_raw_height(point.x, point.y))


static func make_trail(field_size: Vector2, scene_seed: int) -> PackedVector2Array:
	## 필드를 세로로 가로지르는 오솔길 — 남쪽(카메라 쪽)에서 북쪽으로 세 번 꺾인다.
	## 시드가 같으면 같은 길이다 — 스크린샷·눈 검토가 흔들리지 않는다.
	var rng := RandomNumberGenerator.new()
	rng.seed = scene_seed
	var points := PackedVector2Array()
	var steps := 4
	for i in steps + 1:
		var t := float(i) / float(steps)
		var bend := 0.0
		if i > 0 and i < steps:
			bend = rng.randf_range(-1.0, 1.0) * field_size.x * 0.12
		points.append(Vector2(clampf(field_size.x * 0.45 + bend, 4.0, field_size.x - 4.0),
			field_size.y * t))
	return points


static func trail_distance(point: Vector2, trail: PackedVector2Array) -> float:
	## 폴리라인까지의 최단 거리. 선분마다 내린 발의 거리 중 최소.
	if trail.size() < 2:
		return INF
	var best := INF
	for i in trail.size() - 1:
		var a := trail[i]
		var ab := trail[i + 1] - a
		var length_squared := ab.length_squared()
		var t := 0.0 if length_squared <= 0.0 else clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
		best = minf(best, point.distance_to(a + ab * t))
	return best


func path_weight(x: float, z: float) -> float:
	## 길 위면 1, 가장자리로 갈수록 0. 정점색에서만 쓴다.
	if trails.is_empty():
		return 0.0
	var best := INF
	for trail in trails:
		best = minf(best, trail_distance(Vector2(x, z), trail))
	return 1.0 - smoothstep(PATH_HALF, PATH_HALF + PATH_SOFT, best)


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
	return int(ceil((field.x + margin * 2.0) / STEP))


func _rows() -> int:
	return int(ceil((field.y + margin * 2.0) / STEP))


func window_rect() -> Rect2:
	## 기본 창 — 필드 + 사방 여백. 카메라가 필드 끝에서 뒤로 물러나도 뜬 땅이 보인다.
	return Rect2(origin - Vector2(margin, margin), field + Vector2(margin, margin) * 2.0)


func build(base: Color, tints: Dictionary = {}) -> ArrayMesh:
	## 높이필드 한 장 — 기본 창(필드 + 여백).
	return build_region(window_rect(), base, tints)


func build_region(rect: Rect2, base: Color, tints: Dictionary = {}) -> ArrayMesh:
	## **임의 구역**의 메시. 청크 스트리밍이 청크 하나씩 뜨는 데 쓴다.
	## 높이함수는 월드 좌표의 함수라 이웃 청크와 경계 정점이 정확히 만난다 (이음새 없음).
	## 법선은 높이 함수의 기울기로 직접 계산한다 — 삼각형 격자가 법선에 새지 않는다.
	var cols := int(ceil(rect.size.x / STEP))
	var rows := int(ceil(rect.size.y / STEP))
	var heights := PackedFloat32Array()
	heights.resize((cols + 1) * (rows + 1))
	# 이 구역에 닿는 평탄 자리·길만 추린다 — 청크마다 49개 길을 전부 훑으면 정점 하나가
	# 길 49개 × 선분을 재느라 생성이 청크 수에 비례해 느려진다 (2026-10-26 실측).
	var near_flats := _near_flats(rect)
	var near_trails := _near_trails(rect)
	for j in rows + 1:
		for i in cols + 1:
			var wx := rect.position.x + i * STEP
			var wz := rect.position.y + j * STEP
			heights[j * (cols + 1) + i] = _height_local(near_flats, wx, wz)
	# 정점색 이웃 샘플은 **한 칸 바깥까지** 뜬다. 청크 경계에서 배열 끝으로 자르면
	# 기울기·오목 판정이 실제 지형이 아니라 경계값을 보아, 청크 사이에 세로 이음새가 생긴다.
	var pad := 1
	var stride := cols + 1 + pad * 2
	var raw := PackedFloat32Array()
	raw.resize(stride * (rows + 1 + pad * 2))
	for j in rows + 1 + pad * 2:
		for i in stride:
			var wx := rect.position.x + (i - pad) * STEP
			var wz := rect.position.y + (j - pad) * STEP
			raw[j * stride + i] = _raw_height(wx, wz)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rows + 1:
		for i in cols + 1:
			var x := rect.position.x + i * STEP
			var z := rect.position.y + j * STEP
			var h := heights[j * (cols + 1) + i]
			tool.set_color(_vertex_color(base, tints, raw, stride - 1, i + pad, j + pad,
				rect.position - Vector2(pad, pad) * STEP, near_trails))
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


func _near_flats(rect: Rect2) -> Array:
	## 이 구역의 높이에 영향을 주는 평탄 자리만 — [자리, 고정 높이] 쌍.
	var pad := flat_radius + FLAT_FEATHER
	var grown := rect.grow(pad)
	var out: Array = []
	for i in flats.size():
		var point: Vector2 = flats[i]
		if grown.has_point(point):
			out.append([point, float(_flat_heights[i])])
	return out


func _near_trails(rect: Rect2) -> Array:
	## 이 구역의 색에 닿는 오솔길만. 그 밖의 길은 `path_weight` 가 0 이라 결과가 같다.
	if trails.is_empty():
		return []
	var grown := rect.grow(PATH_HALF + PATH_SOFT)
	var out: Array = []
	for trail in trails:
		if _trail_touches(trail, grown):
			out.append(trail)
	return out


static func _trail_touches(trail: PackedVector2Array, rect: Rect2) -> bool:
	## 정점은 밖인데 선분이 구역을 가로지르는 경우가 있다 — 선분 상자로 본다.
	for point in trail:
		if rect.has_point(point):
			return true
	for i in trail.size() - 1:
		var a := trail[i]
		var b := trail[i + 1]
		var box := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		if rect.intersects(box):
			return true
	return false


func _height_local(near_flats: Array, x: float, z: float) -> float:
	## 구역 안 평탄 자리만 적용한 높이. 반경 밖은 이미 weight 0 이라 전역 값과 같다.
	if relief <= 0.0:
		return 0.0
	var h := _raw_height(x, z)
	for pair in near_flats:
		var point: Vector2 = pair[0]
		var away := Vector2(x - point.x, z - point.y).length()
		var weight := 1.0 - smoothstep(flat_radius, flat_radius + FLAT_FEATHER, away)
		if weight > 0.0:
			h = lerpf(h, float(pair[1]), weight)
	return h


func _path_local(near_trails: Array, x: float, z: float) -> float:
	if near_trails.is_empty():
		return 0.0
	var best := INF
	for trail in near_trails:
		best = minf(best, trail_distance(Vector2(x, z), trail))
	return 1.0 - smoothstep(PATH_HALF, PATH_HALF + PATH_SOFT, best)


func _normal_at(x: float, z: float) -> Vector3:
	# 중심차분. 2*STEP 로 나눠 유닛당 기울기를 얻는다.
	# **평탄화를 빼고** 잰다. 평탄면 정점이 모두 위를 보면 조우 자리가 밝은 원판으로 뜬다 —
	# 지형은 평평하되 명암은 주변 언덕을 따라가게 둔다(2026-10-24 렌더).
	var dx := _raw_height(x + STEP, z) - _raw_height(x - STEP, z)
	var dz := _raw_height(x, z + STEP) - _raw_height(x, z - STEP)
	return Vector3(-dx, 2.0 * STEP, -dz).normalized()


func _vertex_color(base: Color, tints: Dictionary,
		raw: PackedFloat32Array, cols: int, i: int, j: int,
		start: Vector2 = Vector2.ZERO, near_trails: Array = []) -> Color:
	## 높이 → 골은 차갑게, 능선은 따뜻하게. 경사 → 암석. 얼룩 → 한 색으로 눕지 않게.
	## 색은 전부 **평탄화를 뺀** 높이에서 낸다 — 조우를 누른 자리가 밝은 원판으로 뜨지 않게.
	var row := cols + 1
	var last_row := raw.size() / row - 1
	var here := raw[j * row + i]
	var dx := raw[j * row + mini(i + 1, cols)] - raw[j * row + maxi(i - 1, 0)]
	var dz := raw[mini(j + 1, last_row) * row + i] - raw[maxi(j - 1, 0) * row + i]
	var slope := sqrt(dx * dx + dz * dz) / (2.0 * STEP)

	var x := start.x + i * STEP
	var z := start.y + j * STEP
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
	# 오솔길 — 높이·경사보다 먼저 칠하되 돌은 위에 덮게 둔다(급경사에 난 길은 자연스럽다).
	var path_mix := _path_local(near_trails, x, z)
	if path_mix > 0.0:
		var earth := PATH_EARTH * shade
		tint = tint.lerp(earth.lerp(tint, 0.15), path_mix)
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
