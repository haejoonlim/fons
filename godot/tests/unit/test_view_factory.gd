extends GutTest
## 2D/3D 선택 지점이 한 곳인지 잠근다. 3D 가 생기면 test_3d_is_not_available_yet 을 갱신한다.

func test_2d_scene_path_exists() -> void:
	assert_eq(FonsViewFactory.scene_path("2d"), "res://game/view/view_2d/view_2d.tscn")
	assert_true(ResourceLoader.exists(FonsViewFactory.scene_path("2d")), "2D 씬 파일이 실제로 있어야 한다")

func test_unknown_mode_has_no_path() -> void:
	assert_eq(FonsViewFactory.scene_path("9d"), "", "모르는 모드는 빈 경로")

func test_3d_is_not_available_yet() -> void:
	assert_null(FonsViewFactory.create("3d"), "3D 뷰는 아직 없다 — 추가하면 이 테스트를 뒤집는다")
	assert_false(FonsViewFactory.available_modes().has("3d"))

func test_creates_a_view_for_2d() -> void:
	var view := FonsViewFactory.create("2d")
	assert_not_null(view)
	assert_true(view is FonsView)
	assert_true(FonsViewFactory.available_modes().has("2d"))
	view.free()

func test_project_setting_keeps_default_mode() -> void:
	assert_eq(FonsViewFactory.configured_mode(), "2d", "fons/view_mode 는 project.godot 에 있어야 한다")
