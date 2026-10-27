class_name FonsHpBar
extends RefCounted
## HP 바 — 2D 는 엔티티 사각형 아래에, 3D 는 투영된 머리 위에 **같은 그림**을 그린다.
##
## 그래서 어디에 놓을지(앵커)는 뷰가 정하고, 모양·비율·색은 여기가 진다.
## 심이 `hp`·`max_hp` 를 실어 보낸 엔티티만 그린다 — 없으면 아무것도 안 그린다.
##
## 좌표는 화면 픽셀이다. 3D 뷰도 `Camera3D.unproject_position` 으로 픽셀을 만들어 여기 넘긴다
## (월드 쿼드로 그리면 카메라 배율에 따라 두께가 흔들린다).

const HEIGHT := 6.0
## 2D — 엔티티 사각형 아래 여백.
const GAP := 4.0
## 3D — 투영된 머리 위 여백. 앵커에 붙이면 몸통을 덮는다.
const LIFT := 6.0
const BG := Color(0.12, 0.12, 0.14, 0.9)
const FG := Color(0.32, 0.85, 0.42)
const BORDER := Color(0.10, 0.10, 0.12, 0.9)


static func has_bar(entity: Dictionary) -> bool:
	return int(entity.get("max_hp", 0)) > 0


static func ratio(entity: Dictionary) -> float:
	var max_hp := int(entity.get("max_hp", 0))
	if max_hp <= 0:
		return 0.0
	return clampf(float(entity.get("hp", 0)) / float(max_hp), 0.0, 1.0)


static func bar_rect(top_left: Vector2, width: float) -> Rect2:
	return Rect2(top_left, Vector2(width, HEIGHT))


static func fill_rect(bar: Rect2, entity: Dictionary) -> Rect2:
	return Rect2(bar.position, Vector2(bar.size.x * ratio(entity), bar.size.y))


## 2D — 사각형 아래 모서리에서 시작한다.
static func top_left_below(anchor: Vector2, width: float) -> Vector2:
	return anchor + Vector2(-width * 0.5, GAP)


## 3D — 투영된 머리 지점에서 위로 올린다.
static func top_left_above(anchor: Vector2, width: float) -> Vector2:
	return anchor + Vector2(-width * 0.5, -HEIGHT - LIFT)


static func draw(canvas: Node2D, top_left: Vector2, width: float, entity: Dictionary) -> void:
	if not has_bar(entity):
		return
	var bar := bar_rect(top_left, width)
	canvas.draw_rect(bar, BG)
	var fill := fill_rect(bar, entity)
	if fill.size.x > 0.0:
		canvas.draw_rect(fill, FG)
	canvas.draw_rect(bar, BORDER, false, 1.0)
