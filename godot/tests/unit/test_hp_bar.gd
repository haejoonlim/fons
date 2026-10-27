extends GutTest
## HP 바 — 2D 는 엔티티 사각형 아래, 3D 는 머리 위 투영 지점에 같은 그림을 그린다.
## 그래서 모양·비율 규칙은 뷰가 아니라 `FonsHpBar` 가 진다. 여기서 그 규칙만 잠근다.


func test_entity_without_max_hp_has_no_bar() -> void:
	assert_false(FonsHpBar.has_bar({"hp": 10}), "max_hp 가 없으면 바를 그리지 않는다")
	assert_false(FonsHpBar.has_bar({"hp": 10, "max_hp": 0}), "0 은 나눗셈이 아니다")
	assert_true(FonsHpBar.has_bar({"hp": 10, "max_hp": 100}))


func test_ratio_clamps_to_one_bar() -> void:
	assert_almost_eq(FonsHpBar.ratio({"hp": 40, "max_hp": 100}), 0.4, 0.0001)
	assert_eq(FonsHpBar.ratio({"hp": 250, "max_hp": 100}), 1.0, "넘치는 HP 는 바 밖으로 나가지 않는다")
	assert_eq(FonsHpBar.ratio({"hp": -10, "max_hp": 100}), 0.0)


func test_bar_rect_is_the_same_height_as_2d() -> void:
	var bar := FonsHpBar.bar_rect(Vector2(10, 20), 60.0)
	assert_eq(bar.position, Vector2(10, 20), "호출자가 정한 좌상단을 그대로 쓴다")
	assert_eq(bar.size, Vector2(60.0, 6.0), "2D 와 같은 6px 높이")


func test_fill_follows_the_hp_ratio() -> void:
	var bar := FonsHpBar.bar_rect(Vector2.ZERO, 60.0)
	assert_almost_eq(FonsHpBar.fill_rect(bar, {"hp": 40, "max_hp": 100}).size.x, 24.0, 0.0001,
		"40% 면 폭도 40%")
	assert_eq(FonsHpBar.fill_rect(bar, {"hp": 0, "max_hp": 100}).size.x, 0.0)


func test_3d_bars_are_lifted_above_the_anchor() -> void:
	# 3D 는 투영된 머리 위에 바를 놓는다 — 앵커를 그대로 쓰면 몸통을 덮는다.
	var top_left := FonsHpBar.top_left_above(Vector2(100, 100), 40.0)
	assert_eq(top_left, Vector2(80.0, 100.0 - FonsHpBar.HEIGHT - FonsHpBar.LIFT))
	assert_lt(top_left.y, 100.0, "화면에서 위로 올라간다")
