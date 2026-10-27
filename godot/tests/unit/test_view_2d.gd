extends GutTest
## 2D 뷰가 심 스냅샷을 그대로 반영하는지 잠근다.
## 트리에 붙이지 않아도 mount/apply 는 동작해야 한다(헤드리스 테스트 경로).

func _entity(id: StringName, kind: String, pos: Vector3) -> Dictionary:
	return {
		"id": id,
		"asset": "%s:test" % kind,
		"pos": pos,
		"size": Vector2.ONE,
		"kind": kind,
	}

func test_mount_tracks_entities() -> void:
	var view := FonsView2D.new()
	view.mount({"tick": 0, "entities": [
		_entity(&"a", "hero", Vector3.ZERO),
		_entity(&"b", "monster", Vector3.ONE),
	]})
	assert_eq(view.entity_count(), 2)
	assert_true(view.is_mounted())
	assert_true(view.has_entity(&"a"))
	view.free()

func test_apply_replaces_whole_set() -> void:
	# 스냅샷은 증분이 아니라 전체 집합이다 — 사라진 id 가 남아 있으면 유령이 그려진다.
	var view := FonsView2D.new()
	view.mount({"tick": 0, "entities": [
		_entity(&"a", "hero", Vector3.ZERO),
		_entity(&"b", "monster", Vector3.ONE),
	]})
	view.apply({"tick": 1, "entities": [_entity(&"a", "hero", Vector3(1, 0, 0))]})
	assert_eq(view.entity_count(), 1)
	assert_false(view.has_entity(&"b"))
	view.free()

func test_unmount_clears() -> void:
	var view := FonsView2D.new()
	view.mount({"entities": [_entity(&"a", "hero", Vector3.ZERO)]})
	view.unmount()
	assert_eq(view.entity_count(), 0)
	assert_false(view.is_mounted())
	view.free()

func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func test_space_asks_for_the_next_floor() -> void:
	# 뷰는 규칙을 모른다 — 키를 의도로 바꿔 보낼 뿐이다.
	var view := FonsView2D.new()
	var got: Array = []
	view.intent.connect(func(kind, payload): got.append(kind))
	view._unhandled_input(_key(KEY_SPACE))
	view._unhandled_input(_key(KEY_R))
	view._unhandled_input(_key(KEY_A))
	assert_eq(got, [&"next_floor", &"restart"], "스페이스=다음 층 · R=재시작 · 나머지는 무시")
	view.free()


func test_field_mode_maps_c_to_the_edict() -> void:
	# C 는 칙령 — 파업을 끝내는 수단이다 (04 §3.12). 뷰는 의도만 보낸다.
	var view := FonsView2D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	var got: Array = []
	view.intent.connect(func(kind, payload): got.append(kind))
	view._unhandled_input(_key(KEY_C))
	assert_eq(got, [&"edict"], "필드: C = 칙령")
	view.free()


func test_field_mode_maps_space_to_interact_and_r_to_retreat() -> void:
	# 탐험 화면에서는 스페이스가 "다음 층"이 아니라 "조우와 싸운다"다.
	var view := FonsView2D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	var got: Array = []
	view.intent.connect(func(kind, payload): got.append(kind))
	view._unhandled_input(_key(KEY_SPACE))
	view._unhandled_input(_key(KEY_R))
	assert_eq(got, [&"interact", &"retreat"], "필드: 스페이스=조우 · R=후퇴")
	view.free()


func test_party_panel_rows_follow_the_snapshot() -> void:
	# 오른쪽 파티 칸은 심이 보낸 줄만 그린다. 줄이 사라지면 유령이 남지 않아야 한다.
	var view := FonsView2D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [], "party": [
		{"index": 0, "hp": 90, "max_hp": 100, "acting": "이동", "controlled": true, "alive": true},
		{"index": 1, "hp": 60, "max_hp": 100, "acting": "채집", "controlled": false, "alive": true},
	]})
	assert_eq(view.party_count(), 2)
	view.apply({"mode": "field", "field": Vector2(40, 28), "entities": [], "party": []})
	assert_eq(view.party_count(), 0)
	view.free()


func test_field_number_keys_switch_the_controlled_hero() -> void:
	# 뷰는 규칙을 모른다 — 숫자 키를 "조종 전환" 의도로 바꿔 보낼 뿐이다.
	var view := FonsView2D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	var got: Array = []
	view.intent.connect(func(kind, payload): got.append([kind, payload]))
	view._unhandled_input(_key(KEY_3))
	view._unhandled_input(_key(KEY_9))
	assert_eq(got.size(), 1, "1~5 만 전환 의도다")
	assert_eq(got[0][0], &"switch_hero")
	assert_eq(int(got[0][1]["index"]), 2, "3번 키 = 0부터 센 2")
	view.free()


func test_field_entities_use_the_field_scale_not_the_combat_scale() -> void:
	# 필드는 40×28 을 화면에 맞추느라 배율이 48px/unit 보다 작다.
	# 엔티티 크기에 전투 배율을 쓰면 영웅이 실제 발자국보다 세 배 크게 그려져 겹쳐 보인다.
	var view := FonsView2D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	var got := view.entity_screen_size({"size": Vector2(0.8, 0.8)})
	var field_scale := float(view.field_metrics()["scale"])
	assert_almost_eq(got.x, 0.8 * field_scale, 0.001, "필드 배율을 쓴다")
	assert_lt(got.x, 0.8 * view.pixels_per_unit, "전투 배율 48px 를 쓰면 안 된다")
	view.free()


func test_field_uses_the_biome_palette_for_background_and_ground() -> void:
	## 2D 폴백도 3D 와 같은 바이옴을 같은 색으로 불러야 한다 — 폴백에서만 다른 세계로 보이면 안 된다.
	## 다만 2D 는 지도·HUD 화면이라 명도는 화면 톤으로 옴긴다 (색상각은 그대로).
	var view := FonsView2D.new()
	var sky := Color(0.20, 0.30, 0.50)
	var ground := Color(0.10, 0.20, 0.08)
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": [],
		"palette": {"sky": sky, "ground": ground}})
	var back := view.field_background()
	assert_almost_eq(back.h, sky.h, 0.01, "배경 색상각 = 심이 준 하늘")
	assert_lt(back.v, sky.v, "밝은 하늘을 그대로 깔면 흰 글씨가 안 읽힌다 — 명도만 내린다")
	var area := view.field_area_color()
	assert_almost_eq(area.h, ground.h, 0.01, "판 색상각 = 심이 준 지면")
	assert_gt(area.v, ground.v, "지면색은 어두워서 그대로 깔면 격자가 안 보인다 — 조금 올린다")
	view.free()


func test_field_without_a_palette_keeps_the_dark_map() -> void:
	## 바이옴을 모르는 화면(전투·헤드리스)은 예전 색 그대로다.
	var view := FonsView2D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	assert_eq(view.field_background(), FonsView2D.FIELD_BG)
	assert_eq(view.field_area_color(), FonsView2D.FIELD_AREA)
	view.free()


func test_screen_position_uses_projection_and_scale() -> void:
	var view := FonsView2D.new()
	view.pixels_per_unit = 10.0
	view.origin = Vector2(100.0, 100.0)
	var got := view.screen_position(Vector3(2.0, 0.0, 3.0))
	assert_almost_eq(got.x, 120.0, 0.0001, "origin.x + x*scale")
	assert_almost_eq(got.y, 70.0, 0.0001, "origin.y - z*scale")
	view.free()


func test_tower_is_drawn_at_the_same_spot_as_the_3d_view() -> void:
	## 2D 폴백도 같은 스냅샷 표를 읽는다 — 폴백에서만 탑이 없는 세계로 보이면 안 된다.
	var view := FonsView2D.new()
	view.mount({"mode": "field", "field": Vector2(40, 28), "avatar": Vector3(20, 0, 14),
		"tower": {"pos": Vector3(20, 0, 14), "radius": 3.4, "body": 1.2}, "entities": []})
	assert_almost_eq(view.tower_radius(), 3.4, 0.001, "반경은 심이 준 값")
	view.mount({"mode": "field", "field": Vector2(40, 28), "entities": []})
	assert_almost_eq(view.tower_radius(), 0.0, 0.001, "표가 없으면 안 그린다")
	view.free()
