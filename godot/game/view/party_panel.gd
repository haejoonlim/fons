class_name FonsPartyPanel
extends RefCounted
## 오른쪽 파티 칸 — 2D·3D 뷰가 같은 그림을 쓰도록 한 곳에 모았다.
##
## 다섯 줄, 번호·HP 막대·행동 한 글자. 점수·확률·이유는 여기 안 온다 (제안서 §6 — 마음속은 보이지 않는다).
## 좌표는 화면 픽셀이다. 두 뷰 모두 CanvasItem 위에 그리므로 카메라와 무관하다.

const WIDTH := 190.0
const MARGIN := 14.0
const TOP := 88.0
const ROW := 38.0
const BG := Color(0.07, 0.08, 0.10, 0.88)
const BORDER := Color(0.30, 0.34, 0.39, 1.0)
const TEXT := Color(0.86, 0.88, 0.91, 1.0)
const DIM := Color(0.52, 0.55, 0.60, 1.0)
const CONTROLLED := Color(0.85, 1.0, 0.90, 1.0)
const HP_BG := Color(0.16, 0.17, 0.20, 1.0)
const HP := Color(0.35, 0.85, 0.45, 1.0)
const HP_LOW := Color(0.90, 0.45, 0.30, 1.0)
## 동료가 위험한 조우에 닿았을 때 그 칸 — 세 번 점멸하는 동안만 켜진다.
const ALERT := Color(1.0, 0.72, 0.25, 1.0)


static func draw(canvas: Node2D, party: Array, viewport: Vector2) -> void:
	if party.is_empty():
		return
	var x := viewport.x - WIDTH - MARGIN
	var y := TOP
	var height := ROW * float(party.size())
	canvas.draw_rect(Rect2(x - 6.0, y - 10.0, WIDTH + 12.0, height + 20.0), BG)
	canvas.draw_rect(Rect2(x - 6.0, y - 10.0, WIDTH + 12.0, height + 20.0), BORDER, false, 1.5)
	var font := ThemeDB.fallback_font
	for i in party.size():
		var row: Dictionary = party[i]
		var ry := y + ROW * float(i)
		var controlled := bool(row.get("controlled", false))
		if controlled:
			canvas.draw_rect(Rect2(x - 2.0, ry - 2.0, WIDTH + 4.0, ROW - 6.0),
				CONTROLLED, false, 2.0)
		if bool(row.get("alert", false)):
			canvas.draw_rect(Rect2(x - 4.0, ry - 4.0, WIDTH + 8.0, ROW - 2.0),
				ALERT, false, 2.5)
		var text_color := TEXT if controlled else DIM
		canvas.draw_string(font, Vector2(x + 2.0, ry + 18.0), "%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)
		var max_hp := int(row.get("max_hp", 0))
		var ratio := clampf(float(row.get("hp", 0)) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0
		var bar := Rect2(x + 22.0, ry + 10.0, 74.0, 7.0)
		canvas.draw_rect(bar, HP_BG)
		canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)),
			HP_LOW if ratio < 0.35 else HP)
		canvas.draw_string(font, Vector2(x + 104.0, ry + 18.0), String(row.get("acting", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_color)
