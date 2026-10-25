extends GutTest
## 2D/3D 선택 지점이 한 곳인지 잠근다.

func test_2d_scene_path_exists() -> void:
	assert_eq(FonsViewFactory.scene_path("2d"), "res://game/view/view_2d/view_2d.tscn")
	assert_true(ResourceLoader.exists(FonsViewFactory.scene_path("2d")), "2D 씬 파일이 실제로 있어야 한다")

func test_unknown_mode_has_no_path() -> void:
	assert_eq(FonsViewFactory.scene_path("9d"), "", "모르는 모드는 빈 경로")

func test_3d_scene_path_exists() -> void:
	assert_eq(FonsViewFactory.scene_path("3d"), "res://game/view/view_3d/view_3d.tscn")
	assert_true(ResourceLoader.exists(FonsViewFactory.scene_path("3d")), "3D 씬 파일이 실제로 있어야 한다")
	assert_true(FonsViewFactory.available_modes().has("3d"))


func test_creates_a_view_for_3d() -> void:
	var view := FonsViewFactory.create("3d")
	assert_not_null(view)
	assert_true(view is FonsView3D, "3D 모드는 FonsView3D 를 만든다")
	view.free()

func test_creates_a_view_for_2d() -> void:
	var view := FonsViewFactory.create("2d")
	assert_not_null(view)
	assert_true(view is FonsView)
	assert_true(FonsViewFactory.available_modes().has("2d"))
	view.free()

func test_project_setting_keeps_default_mode() -> void:
	# 2026-10-25 기본 뷰를 3D 로 올렸다 — 지형·프롭 작업이 3D 씬에 있다. 2D 는 폴백으로 남는다.
	assert_eq(FonsViewFactory.configured_mode(), "3d", "fons/view_mode 는 project.godot 에 있어야 한다")
