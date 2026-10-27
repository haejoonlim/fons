class_name FonsBiomePalette
extends RefCounted
## 바이옴 → 무대 파생색. 정본 수치(`climate.ambient` · `category`)만 읽고 26색을 손으로 고르지 않는다.
## 규칙은 [바이옴_에셋_계획](../../docs/design/바이옴_에셋_계획.md) §4 가안이다.
##
## 왜 심에 있나
## -----------
## 2D 폴백도 같은 값을 배경색·지면색으로 써야 "두 뷰가 같은 바이옴을 같은 색으로 부른다"가 지켜진다.
## 뷰마다 계산하면 언젠가 두 색이 갈라진다. 뷰는 색을 만들지 않고 심이 준 값(`palette`)을 칠한다.
##
## 파생 축 — 마인크래프트 콜로맵 방식 (2026-10-24 리서치)
## ------------------------------------------------------
## 마인크래프트는 바이옴마다 색을 손으로 고르지 않는다. 기후(온도·습도)로 콜로맵을 샘플하고,
## 그 색을 **공유 텍스처에 곱한다**. 풀과 잎은 서로 다른 콜로맵을 쓴다 — 같은 초록이 아니다.
## 바위·나무는 틴트 대상이 아니다. 그래서 여기서도 **역할별 틴트**를 낸다:
##
##   식생(grass) ← 기후: −70℃ 청록 `#80B497` 계열 · 15℃ 풀색 `#91BD59` 계열 · +60℃ 올리브 `#BFB755` 계열
##   암석(rock)  ← 기후: −70℃ 청회 · 15℃ 따뜻한 회색 · +60℃ 적갈
##   채도·명도   ← category (평온은 옅게, 극한은 진하게, 어둠은 낮게)
##   하늘·조명   ← 대기 축(기후) + 광량(category)
##
## 이전 규칙은 온도축을 회색→파랑/주황으로 이었는데, 회색과 파랑의 색상각이 같아(0.611)
## 한랭 26색 중 21색이 같은 파랑으로 접혔다. 식생은 파랑이 아니라 초록이어야 하고,
## 한랭과 고온은 청록↔올리브로 갈라져야 한다. 수치는 가안 — ART_BIBLE 확정 뒤
## [tools/tracked_numbers.json] 을 거친다.

const TEMP_MIN := -70.0
const TEMP_MAX := 60.0
## 15℃ 는 온대 기준값 — 여기를 중립으로 둔다. 전체 구간을 한 직선으로 이으면
## 15℃ 풀바다가 난색(갈색)으로 읽혔다 (2026-10-23 스크린샷).
const TEMP_NEUTRAL := 15.0

## 식생 앵커 — 실측 콜로맵 색을 그대로 쓰지 않고, 곱셈 틴트로 옮길 수 있는 채도로 눌렀다.
const GRASS_COOL := Color(0.50, 0.71, 0.59)
const GRASS_MID := Color(0.57, 0.74, 0.35)
const GRASS_HOT := Color(0.75, 0.72, 0.33)
## 암석 앵커 — 채도가 낮아 바이옴 색이 돌에 배어도 돌로 읽힌다.
const ROCK_COOL := Color(0.63, 0.70, 0.76)
const ROCK_MID := Color(0.66, 0.63, 0.56)
const ROCK_HOT := Color(0.62, 0.47, 0.38)
## 대기 앵커 — 하늘·환경광·방향광이 같은 색온도를 공유한다.
const ATMOS_COOL := Color(0.52, 0.62, 0.78)
const ATMOS_MID := Color(0.56, 0.58, 0.62)
const ATMOS_HOT := Color(0.62, 0.48, 0.34)

## 하늘은 **낮**이다. 예전 식(`0.10 + 0.05 × gain.y`)은 값이 `#1a1e25`(v 0.145)라 26바이옴이 전부
## 해 질 녘/밤으로 읽혔다 (2026-10-25 스크린샷: 천정 v 0.145 → 지평선 헤이즈 v 0.675 의
## 그라데이 = 노을 띠).
##
## 하늘만 앵커를 따로 둔다 — 대기 앵커(ATMOS)는 **조명 색온도** 축이라 고온에서 주황으로 간다.
## 그 색을 그대로 하늘에 쓰면 사막·화구가 낮이 아니라 노을로 보인다. 낮 하늘은 한랭이 청록
## 기운 도는 파랑, 온대가 옅은 파랑, 고온이 먼지 섞인 옅은 모래빛이다 (채도가 낮아 해가 뜬 시간대로 읽힌다).
const SKY_COOL := Color(0.50, 0.72, 0.86)
const SKY_MID := Color(0.66, 0.70, 0.76)
const SKY_HOT := Color(0.80, 0.76, 0.66)
## 채도는 카테고리로만 흔들어 고온 하늘이 다시 노을이 되지 않게 상한을 낮게 둔다.
## 다만 `gain.x` 를 그대로 쓰면 평온(0.55)이 너무 옅어 풀바다가 흐린 회색으로 읽힌다.
## 하늘은 카테고리 편차를 **절반만** 따라 맑음·흐림을 바이옴 밝기가 아니라 날씨로 남긴다.
const SKY_SATURATION := 0.40
const SKY_GAIN_COMPRESS := 0.5
## 밝기도 카테고리만 따른다(식생·암석과 같은 TINT_GAIN) — 기후에 맡기면 바이옴마다 낮과 밤이 갈린다.
const SKY_VALUE := 0.74

## 카테고리 → (채도 배율, 명도·광량 배율). 대비는 명도 배율이 겸한다.
const CATEGORY_GAIN := {
	"calm": Vector2(0.55, 0.90),
	"extreme": Vector2(1.15, 1.30),
	"dark": Vector2(0.40, 1.20),
	"chaos": Vector2(0.85, 1.10),
	"waterside": Vector2(0.70, 0.85),
}
const DEFAULT_GAIN := Vector2(0.80, 1.00)
## 식생·암석은 대기보다 완만하게 흔든다 — 광량까지 같이 흔들면 색이 아니라 밝기만 남는다.
const TINT_GAIN := {
	"calm": Vector2(0.85, 0.95),
	"extreme": Vector2(1.05, 1.08),
	"dark": Vector2(0.65, 0.80),
	"chaos": Vector2(1.05, 1.02),
	"waterside": Vector2(0.90, 0.80),
}
const DEFAULT_TINT_GAIN := Vector2(0.95, 1.00)
## 돌은 채도를 더 눌러야 돌로 읽힌다 — 흙·잎과 같은 배율을 쓰면 회색이 초록으로 물든다.
const ROCK_SATURATION_MAX := 0.30

## 기복 배율 — 높이필드 진폭에 곱한다. 평온은 완만하게, 극한은 크게.
## 40×28 필드·유닛 키 0.7~0.9 에서 1.35 면 진폭 ±1.4 유닛 — 2026-10-24 렌더에서
## 1.0 은 완전히 평평하게 읽혔다(카메라가 멀어 명암이 안 남는다). 계획 §11 의 0.8~1.4 상한을 쓴다.
const RELIEF := {
	"calm": 1.35,
	"waterside": 0.85,
	"chaos": 1.5,
	"dark": 1.7,
	"extreme": 2.2,
}
const DEFAULT_RELIEF := 0.0

## 라이팅 프리셋 (S4) — 색이 아니라 **광량·채움·안개**로 같은 키트를 가른다.
## 서고(평온)·미궁도시(혼돈)·침전수로(혼돈)는 키트가 같고 색도 가깝다. 그 셋을 가르는
## 마지막 축이 빛이다 — 깊은 실내는 채움광이 낮고 안개가 짙다.
## 수치는 가안이다: ART_BIBLE 확정 뒤 `tools/tracked_numbers.json` 을 거친다.
##   sun  ← 태양광 배율 (energy 에 곱한다)
##   fill ← 환경광 세기 (Environment.ambient_light_energy)
##   fog  ← 안개 거리 배율. 1보다 크면 더 짧은 거리에서 잠긴다 (짙은 안개)
const LIGHTING := {
	"calm": {"sun": 1.00, "fill": 0.95, "fog": 0.95},
	"waterside": {"sun": 0.95, "fill": 1.05, "fog": 1.30},
	"dark": {"sun": 0.62, "fill": 0.55, "fog": 1.45},
	"chaos": {"sun": 1.02, "fill": 0.85, "fog": 1.10},
	"extreme": {"sun": 1.12, "fill": 1.00, "fog": 0.85},
}
const DEFAULT_LIGHTING := {"sun": 1.00, "fill": 0.90, "fog": 1.00}
## `light:dark` 모드(동굴)는 카테고리 위에 한 번 더 얹는다 — 어둠 카테고리만으로는
## 동굴 안이 낮의 어둠과 구분되지 않는다.
const DARK_MOD := {"sun": 0.55, "fill": 0.60, "fog": 1.25}
## `light:dim` 모드(침전수로) — 지하 수로는 동굴만큼 어둡지 않지만 채광이 없고 김이 긴다.
## 미궁도시와 같은 `chaos`·같은 키트라 카테고리 프리셋만으로는 두 칸이 화면에서 붙었다
## (2026-10-28 시트). 한 단만 내려앗혀 서고 > 미궁도시 > 수로 > 동굴 순으로 세운다.
const DIM_MOD := {"sun": 0.82, "fill": 0.70, "fog": 1.30}
const LIGHT_MODS := {"dark": DARK_MOD, "dim": DIM_MOD}

## 바이옴을 모르는 화면(전투·헤드리스)의 지금 모습 — 3D 뷰가 쓰던 상수 그대로다.
const DEFAULT_SKY := Color(0.04, 0.05, 0.07, 1.0)
const DEFAULT_GROUND := Color(0.10, 0.12, 0.15, 1.0)
const DEFAULT_AMBIENT := Color(0.55, 0.60, 0.70)
const DEFAULT_LIGHT := Color(1.0, 1.0, 1.0)
const DEFAULT_ENERGY := 1.1


static func defaults() -> Dictionary:
	## 바이옴을 모르는 스냅샷에 쓰는 값. 필드가 아닌 화면의 모습이 바뀌지 않게 한다.
	return {
		"sky": DEFAULT_SKY,
		"ground": DEFAULT_GROUND,
		"ambient": DEFAULT_AMBIENT,
		"light": DEFAULT_LIGHT,
		"energy": DEFAULT_ENERGY,
		"fill": DEFAULT_LIGHTING["fill"],
		"fog": DEFAULT_LIGHTING["fog"],
		"relief": DEFAULT_RELIEF,
		"tints": {},
	}


static func from_biome(biome: Dictionary) -> Dictionary:
	## 빈 바이옴은 기본값 — 지어내지 않는다 (표기 생략 규약).
	if biome.is_empty():
		return defaults()
	var climate: Dictionary = biome.get("climate", {})
	var ambient := float(climate.get("ambient", 15.0))
	var category := String(biome.get("category", ""))
	var gain: Vector2 = CATEGORY_GAIN.get(category, DEFAULT_GAIN)
	var tint_gain: Vector2 = TINT_GAIN.get(category, DEFAULT_TINT_GAIN)
	var grass := _grade(_triple(GRASS_COOL, GRASS_MID, GRASS_HOT, ambient), tint_gain)
	var rock := _grade(_triple(ROCK_COOL, ROCK_MID, ROCK_HOT, ambient), tint_gain)
	rock.s = minf(rock.s, ROCK_SATURATION_MAX)
	var atmos := _triple(ATMOS_COOL, ATMOS_MID, ATMOS_HOT, ambient)
	var sky_anchor := _triple(SKY_COOL, SKY_MID, SKY_HOT, ambient)
	var lighting := _lighting(category, biome)
	return {
		"sky": _shade(sky_anchor, SKY_SATURATION * lerpf(gain.x, 1.0, SKY_GAIN_COMPRESS),
			SKY_VALUE * tint_gain.y),
		"ground": _shade(grass, grass.s, grass.v * 0.22),
		"ambient": _shade(atmos, 0.22 * gain.x, 0.62 * gain.y),
		"light": _shade(atmos, 0.18 * gain.x, 1.0),
		"energy": DEFAULT_ENERGY * gain.y * float(lighting["sun"]),
		"fill": float(lighting["fill"]),
		"fog": float(lighting["fog"]),
		"relief": RELIEF.get(category, 1.0),
		"tints": {"grass": grass, "rock": rock},
	}


static func _lighting(category: String, biome: Dictionary) -> Dictionary:
	## 카테고리 프리셋에 `light` 모드를 곱한다. 다른 모드(물·용암)는 색·배치가 맡고,
	## 광량을 직접 깎는 것은 `dark`(동굴)와 `dim`(수로) 둘이다 — 용암 바이옴은 밝아야 맞다.
	var preset: Dictionary = LIGHTING.get(category, DEFAULT_LIGHTING).duplicate()
	# `(x or {})` 는 bool 을 내놓는다 — GDScript 의 `or` 는 값이 아니라 진리값이다 (2026-10-26 실측).
	var difficulty: Dictionary = biome.get("difficulty", {})
	var mods: Dictionary = difficulty.get("mods", {})
	var mod: Dictionary = LIGHT_MODS.get(String(mods.get("light", "")), {})
	for key in mod:
		preset[key] = float(preset.get(key, 1.0)) * float(mod[key])
	return preset


static func _triple(cool: Color, mid: Color, hot: Color, ambient: float) -> Color:
	## 온대를 중심으로 양쪽으로 뻗는다 — 한랭은 청록, 고온은 올리브/적갈.
	if ambient >= TEMP_NEUTRAL:
		return mid.lerp(hot, clampf((ambient - TEMP_NEUTRAL) / (TEMP_MAX - TEMP_NEUTRAL), 0.0, 1.0))
	return mid.lerp(cool, clampf((TEMP_NEUTRAL - ambient) / (TEMP_NEUTRAL - TEMP_MIN), 0.0, 1.0))


static func _grade(anchor: Color, gain: Vector2) -> Color:
	## 앵커의 색상각은 유지하고 채도·명도만 카테고리로 흔든다.
	return Color.from_hsv(anchor.h, clampf(anchor.s * gain.x, 0.0, 1.0),
		clampf(anchor.v * gain.y, 0.0, 1.0))


static func _shade(tint: Color, saturation: float, value: float) -> Color:
	## 색상각은 기후가 정하고, 채도·명도는 카테고리가 깎는다.
	return Color.from_hsv(tint.h, clampf(saturation, 0.0, 1.0), clampf(value, 0.0, 1.0))
