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
	return {
		"sky": _shade(atmos, 0.55 * gain.x, 0.10 + 0.05 * gain.y),
		"ground": _shade(grass, grass.s, grass.v * 0.22),
		"ambient": _shade(atmos, 0.22 * gain.x, 0.62 * gain.y),
		"light": _shade(atmos, 0.18 * gain.x, 1.0),
		"energy": DEFAULT_ENERGY * gain.y,
		"relief": RELIEF.get(category, 1.0),
		"tints": {"grass": grass, "rock": rock},
	}


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
