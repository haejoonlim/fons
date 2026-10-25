extends GutTest
## 필드 파티 — 5인이 함께 걷고, 플레이어는 한 명만 조종한다 (제안서 §6).
##
## 이 파일이 잠그는 것:
##   · 파티는 5인 · 조종은 한 명 · 나머지는 그 주변 범위 안에 머문다
##   · 조종을 바꾸면 아바타와 범위의 중심이 그 영웅으로 옮겨간다
##   · 층을 넘거나 재시작해도 파티가 필드 밖으로 새지 않는다


func _field() -> FonsFieldState:
	var field := FonsFieldState.new()
	field.start(DataLoader.load_json("races.json"), DataLoader.get_monsters(),
		DataLoader.get_biomes(), 20261022, 1,
		DataLoader.load_json("job_tree.json"), DataLoader.load_json("equipment.json"),
		DataLoader.load_json("job_coef.json"), _ai())
	return field


func _ai() -> Dictionary:
	return {
		"personalities": DataLoader.load_json("personalities.json"),
		"profiles": DataLoader.load_json("job_ai_profiles.json"),
		"catalog": DataLoader.load_json("skills_catalog.json"),
		"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
	}


func test_party_has_five_heroes_and_one_controlled() -> void:
	var field := _field()
	assert_eq(field.heroes.size(), 5, "정본 파티는 5인 (확정 #3)")
	assert_eq(field.party_pos.size(), 5, "필드 위 좌표도 5개")
	assert_eq(field.controlled, 0, "처음 조종은 첫 번째 영웅")
	assert_eq(field.explore.avatar, field.party_pos[0], "아바타가 조종 영웅의 자리다")
	var snapshot := field.snapshot()
	var controlled := 0
	for entity in snapshot["entities"]:
		if String(entity["id"]) == "avatar":
			controlled += 1
	assert_eq(controlled, 1, "조종 표시는 한 명뿐")


func test_snapshot_carries_an_asset_key_per_hero() -> void:
	## R3 — 심은 대상물을 문자열 키로만 가리킨다. 필드 스냅샷도 영웅마다 키를 실어야
	## 3D 뷰가 같은 키를 각자 해석해 다섯을 구분해 그릴 수 있다.
	var field := _field()
	var assets: Array = []
	for entity in field.snapshot()["entities"]:
		var id := String(entity["id"])
		if id != "avatar" and not id.begins_with("hero:"):
			continue
		var asset := String(entity.get("asset", ""))
		assert_true(asset.begins_with("hero:"), "%s 에 에셋 키가 있다" % id)
		assets.append(asset)
	assert_eq(assets.size(), 5, "조종 1 + 동료 4")
	var unique := {}
	for asset in assets:
		unique[asset] = true
	assert_eq(unique.size(), 5, "다섯 키가 서로 다르다 — 아니면 3D 에서 같은 모습이 된다")


func test_snapshot_carries_the_biome_and_its_derived_palette() -> void:
	## 뷰는 데이터를 읽지 않는다 — 심이 바이옴 이름과 파생색을 함께 실어 보낸다 (계획서 §5).
	var field := _field()
	var snapshot := field.snapshot()
	assert_eq(String(snapshot["biome"]), "biome_plains", "1층 = 슬롯 1 풀바다")
	assert_eq(String(snapshot["kit"]), "topo_natural_surface")
	var biome := FonsEncounter.biome_for_floor(DataLoader.get_biomes(), snapshot["floor"])
	assert_eq(snapshot["palette"], FonsBiomePalette.from_biome(biome),
		"같은 바이옴 = 같은 지면·조명색")


func test_switching_moves_the_avatar_and_the_radius_center() -> void:
	var field := _field()
	var before: Vector2 = field.party_pos[3]
	assert_true(field.switch_hero(3), "3번 영웅으로 전환")
	assert_eq(field.controlled, 3)
	assert_eq(field.explore.avatar, before, "아바타가 그 영웅의 자리로 간다")
	assert_false(field.switch_hero(3), "같은 영웅을 다시 고르면 아무 일도 없다")
	assert_false(field.switch_hero(9), "없는 자리는 무시한다")
	assert_eq(field.controlled, 3)
	var snapshot := field.snapshot()
	assert_eq(snapshot["controlled"], 3)
	assert_almost_eq(float(snapshot["radius"]), FonsFieldState.PARTY_RADIUS, 0.001)


func test_allies_stay_inside_the_radius_while_the_player_walks() -> void:
	var field := _field()
	# 플레이어를 필드 반대편으로 몰고 간다.
	for i in 20:
		field.walk(Vector2(1.0, 1.0), 0.5)
		field.tick(0.5)
	var center: Vector2 = field.explore.avatar
	for i in field.party_pos.size():
		if i == field.controlled:
			continue
		assert_lte(field.party_pos[i].distance_to(center), FonsFieldState.PARTY_RADIUS + 0.5,
			"%d번 동료가 범위 밖으로 나갔다" % (i + 1))
		assert_gte(field.party_pos[i].x, 0.0)
		assert_lte(field.party_pos[i].x, FonsExplore.FIELD_WIDTH)
		assert_gte(field.party_pos[i].y, 0.0)
		assert_lte(field.party_pos[i].y, FonsExplore.FIELD_DEPTH)


func test_allies_actually_move_on_their_own() -> void:
	var field := _field()
	var before: Array = field.party_pos.duplicate()
	for i in 10:
		field.tick(0.5)
	var moved := false
	for i in field.party_pos.size():
		if i != field.controlled and field.party_pos[i].distance_to(before[i]) > 0.1:
			moved = true
	assert_true(moved, "가만히 있어도 동료는 움직인다")


func test_snapshot_carries_party_status_for_the_right_panel() -> void:
	var field := _field()
	field.switch_hero(1)
	var snapshot := field.snapshot()
	var party: Array = snapshot["party"]
	assert_eq(party.size(), 5, "HUD 는 다섯 줄을 그린다")
	var controlled_rows := 0
	for row in party:
		assert_true(row.has("hp") and row.has("max_hp"), "HP 막대에 필요한 값")
		assert_false(String(row["acting"]).is_empty(), "지금 무엇을 하는지 한 글자")
		if bool(row["controlled"]):
			controlled_rows += 1
	assert_eq(controlled_rows, 1, "조종 테두리는 한 줄만")
	assert_true(bool(party[1]["controlled"]), "전환한 영웅이 조종 중")


func test_allies_choose_gather_or_rest_on_their_own() -> void:
	var field := _field()
	var seen := {}
	for i in 80:
		field.tick(0.5)
		for row in field.snapshot()["party"]:
			seen[String(row["acting"])] = true
	assert_true(seen.has("채집") or seen.has("휴식"),
		"동료가 이동만 하지 않고 스스로 채집·휴식을 고른다 (본 상태: %s)" % str(seen.keys()))
	var tagged := false
	for i in range(1, field.heroes.size()):
		var counters := _counters(field.heroes[i])
		if int(counters.get("채집", 0)) > 0 or int(counters.get("휴식", 0)) > 0:
			tagged = true
	assert_true(tagged, "고른 행동이 그 영웅의 태그로 쌓인다")
	var controlled := _counters(field.heroes[field.controlled])
	assert_eq(int(controlled.get("채집", 0)), 0, "조종 중인 영웅은 대신 움직여 주지 않는다")
	assert_eq(int(controlled.get("휴식", 0)), 0)


func _counters(hero: Dictionary) -> Dictionary:
	## 브레인이 붙은 영웅은 카운터가 정본이고, 없으면 유닛의 태그 거울을 본다.
	if FonsBrain.attached(hero):
		return hero["brain"].counters
	return hero.get("tags", {})


func _pulses(field: FonsFieldState, index: int, ticks: int) -> int:
	## 점멸의 상승 모서리만 센다 — 켜짐/꺼짐을 한 번으로 세면 두 배가 된다.
	var rises := 0
	var was := false
	for k in ticks:
		field.tick(0.1)
		var now := bool(field.snapshot()["party"][index]["alert"])
		if now and not was:
			rises += 1
		was = now
	return rises


func test_ally_touching_an_encounter_blinks_three_times() -> void:
	var field := _field()
	var index := 1
	var site: Dictionary = field.explore.sites[0]
	field.party_pos[index] = site["pos"]
	assert_eq(_pulses(field, index, 20), 3, "위험 신호는 세 번만 — 재촉이 아니라 제안")


func test_same_encounter_never_signals_twice() -> void:
	var field := _field()
	var index := 1
	var site: Dictionary = field.explore.sites[0]
	field.party_pos[index] = site["pos"]
	_pulses(field, index, 20)
	# 멀어졌다가 같은 조우로 돌아와도 다시 안 빛난다.
	field.party_pos[index] = Vector2.ZERO
	field.tick(0.2)
	field.party_pos[index] = site["pos"]
	assert_eq(_pulses(field, index, 20), 0, "같은 조우는 한 번만")


func test_controlled_hero_does_not_blink() -> void:
	var field := _field()
	var site: Dictionary = field.explore.sites[0]
	field.explore.avatar = site["pos"]
	field.party_pos[field.controlled] = site["pos"]
	assert_eq(_pulses(field, field.controlled, 20), 0, "플레이어가 이미 그 자리에 있으면 알릴 것이 없다")


class EngageBrain extends FonsBrain:
	## 교전/후퇴 판단만 강제하고, 전투 중 수·대상 판단은 부모에게 넘긴다.
	func decide(candidates: Array, ctx: Dictionary) -> Dictionary:
		if candidates.size() > 0 and String(candidates[0].get("action", "")) == "교전":
			return candidates[0]
		return super.decide(candidates, ctx)


class RetreatBrain extends FonsBrain:
	func decide(candidates: Array, ctx: Dictionary) -> Dictionary:
		if candidates.size() > 1 and String(candidates[0].get("action", "")) == "교전":
			return candidates[1]
		return super.decide(candidates, ctx)


func _with_brain(field: FonsFieldState, index: int, script: GDScript) -> void:
	## 기존 브레인의 성격·데이터는 그대로 물려받고 판단 규칙만 바꾼다.
	var old: FonsBrain = field.heroes[index]["brain"]
	var stub: FonsBrain = script.new()
	stub.setup(old.identity, old.data, old.job_profile, old.role, old.catalog_by_id.values(), 1)
	field.heroes[index]["brain"] = stub


func test_ally_brain_engaging_runs_a_real_fight() -> void:
	var field := _field()
	var index := 1
	_with_brain(field, index, EngageBrain)
	field.party_pos[index] = field.explore.sites[0]["pos"]
	field.tick(0.1)
	assert_eq(field.explore.cleared, 0, "ٱ찾자마자 싸우지 않는다 — 1.5초 준비")
	assert_eq(String(field.snapshot()["party"][index]["acting"]), "교전", "패널에 교전이 뜬다")
	for i in 20:
		field.tick(0.1)
	assert_eq(field.explore.cleared, 1, "준비가 끝나면 실제 전투가 돌아 조우가 지워진다")
	assert_gt(field.log_lines.size(), 0, "전투 로그가 필드 로그로 온다")


func test_ally_brain_retreating_is_not_a_battle() -> void:
	var field := _field()
	var index := 1
	_with_brain(field, index, RetreatBrain)
	field.party_pos[index] = field.explore.sites[0]["pos"]
	field.tick(0.1)
	assert_eq(field.explore.cleared, 0, "후퇴를 고르면 안 싸온다")
	assert_eq(String(field.snapshot()["party"][index]["acting"]), "후퇴")
	assert_gt(int(_counters(field.heroes[index]).get("후퇴", 0)), 0, "물러난 것도 그 영웅의 기록")


func test_one_encounter_is_decided_once_not_by_every_ally() -> void:
	var field := _field()
	_with_brain(field, 1, RetreatBrain)
	field.party_pos[1] = field.explore.sites[0]["pos"]
	field.tick(0.1)
	assert_eq(field.explore.cleared, 0)
	# 한 동료가 물러나기로 한 조우를 다른 동료가 다시 붙지 않는다.
	_with_brain(field, 2, EngageBrain)
	field.party_pos[2] = field.explore.sites[0]["pos"]
	field.tick(0.1)
	assert_eq(field.explore.cleared, 0, "한 조우는 한 번만 판단한다")


func test_allies_on_the_same_spot_split_apart() -> void:
	var field := _field()
	for j in field.party_pos.size():
		if j != 1 and j != 2:
			field._ally_state[j] = "휴식"
			field._ally_timer[j] = 99.0
	field._ally_state[1] = "휴식"
	field._ally_timer[1] = 99.0
	field._ally_state[2] = "휴식"
	field._ally_timer[2] = 99.0
	field.party_pos[1] = Vector2(10.0, 10.0)
	field.party_pos[2] = Vector2(10.0, 10.0)
	field.tick(0.05)
	assert_gt(field.party_pos[1].distance_to(field.party_pos[2]), 0.1,
		"같은 좌표에 겹친 동료는 갈라진다 — 다섯이 한 칸에 쌓이면 안 된다")


func test_engage_reports_the_strike_for_the_view() -> void:
	## 연출은 스냅샷만 읽는다 — 교전이 있었다는 사실과 그 자리·피해를 심이 실어 보낸다.
	var field := _field()
	assert_eq(int(field.snapshot()["strike"]["seq"]), 0, "교전 전에는 연출이 없다")
	field.explore.avatar = field.explore.sites[0]["pos"]
	field.party_pos[field.controlled] = field.explore.avatar
	var out := field.engage()
	assert_true(out.has("last_hit"), "마지막 일격의 피해를 돌려준다")
	var snapshot := field.snapshot()
	assert_eq(int(snapshot["strike"]["seq"]), 1, "교전 한 번 = 연출 한 번")
	assert_eq(int(snapshot["strike"]["site"]), 0, "연출은 그 조우 자리에")
	assert_eq(int(snapshot["strike"]["damage"]), int(out["last_hit"]), "화면 숫자 = 로그 마지막 일격")
	assert_gt(int(out["last_hit"]), 0, "때렸으면 피해가 0 보다 크다")


func test_engage_does_nothing_after_a_wipe() -> void:
	var field := _field()
	for hero in field.heroes:
		hero["alive"] = false
	field._update_winner()
	field.explore.avatar = field.explore.sites[0]["pos"]
	assert_true(field.engage().is_empty(), "전멸 뒤에는 싸울 수 없다")
	assert_eq(field.explore.cleared, 0)


func test_retreat_cancels_a_preparing_ally_battle() -> void:
	var field := _field()
	_with_brain(field, 1, EngageBrain)
	field.party_pos[1] = field.explore.sites[0]["pos"]
	field.tick(0.1)
	assert_eq(String(field.snapshot()["party"][1]["acting"]), "교전")
	assert_string_contains(field.hint(), "교전 준비", "힌트가 준비 중임을 알린다")
	field.retreat()
	field.tick(2.0)
	assert_eq(field.explore.cleared, 0, "R 로 물리면 준비 중인 교전도 취소된다")
	assert_eq(String(field.snapshot()["party"][1]["acting"]), "이동")


func test_tick_reports_change_while_the_warning_blinks() -> void:
	# 동료가 서 있는 채로 점멸하면 이동이 없다 — 그래도 화면을 다시 밀어야 깜박인다.
	var field := _field()
	_with_brain(field, 1, EngageBrain)
	# 나머지는 붙잡아 둔다 — 동료가 걷고 있어서 우연히 참이 되면 검사가 아니다.
	for j in field.party_pos.size():
		if j != field.controlled and j != 1:
			field._ally_state[j] = "휴식"
			field._ally_timer[j] = 99.0
	field.party_pos[1] = field.explore.sites[0]["pos"]
	field.tick(0.1)
	assert_true(field.tick(0.1), "점멸 중에는 tick 이 변경을 알린다")


func test_next_floor_and_restart_keep_the_party_inside_the_field() -> void:
	var field := _field()
	field.switch_hero(2)
	for i in field.explore.sites.size():
		field.explore.avatar = field.explore.sites[i]["pos"]
		field.engage()
	assert_true(field.next_floor(), "미션을 끝내면 다음 층")
	assert_eq(field.controlled, 2, "층을 넘어도 조종은 유지된다")
	assert_eq(field.party_pos.size(), 5)
	field.restart()
	assert_eq(field.controlled, 0, "재시작은 첫 영웅으로 돌린다")
	assert_eq(field.explore.avatar, field.party_pos[0])
