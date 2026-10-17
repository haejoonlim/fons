extends GutTest
## 심의 Vector3 → 2D 화면 투영. 3D 전환의 핵심 계약이라 따로 잠근다.

func test_xz_projection_is_top_down() -> void:
	# 기본 평면: x 오른쪽, z 앞 → 화면 아래(부호 반전)
	var got := FonsProjection.to_screen(Vector3(1.0, 2.0, 3.0))
	assert_almost_eq(got.x, 1.0, 0.0001, "x 는 그대로")
	assert_almost_eq(got.y, -3.0, 0.0001, "z 는 부호 반전")

func test_xy_projection_is_side_on() -> void:
	var got := FonsProjection.to_screen(Vector3(1.0, 2.0, 3.0), FonsProjection.Axes.XY)
	assert_almost_eq(got.x, 1.0, 0.0001, "x 는 그대로")
	assert_almost_eq(got.y, -2.0, 0.0001, "y 는 부호 반전")

func test_origin_maps_to_zero() -> void:
	assert_eq(FonsProjection.to_screen(Vector3.ZERO), Vector2.ZERO)
	assert_eq(FonsProjection.to_screen(Vector3.ZERO, FonsProjection.Axes.XY), Vector2.ZERO)
