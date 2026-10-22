extends GutTest
## 층 스케일 — 06 §3.2 층 스케일식 + 확정 #38(HP 손잡이) + 확정 #52(G4 천정).
##
## 이 파일이 잠그는 것:
##   · 구간 경계가 이어진다 (50/51·95/96·100/101 에서 값이 튀지 않는다)
##   · GDD 앵커 표(1층 2.03 · 50층 3.5 · 100층 5.8)와 숫자가 같다
##   · 130층 전 구간에서 단조 비감소 — 층이 깊어지는데 쉬워지는 구간이 없다
##   · 바이옴 계수는 데이터(`biomes.json difficulty.mult`)에서 온다
##   · 비율 스탯(CRI·EVA 등)은 배율을 곱하지 않는다 (관통·회피가 100% 를 넘으면 판이 깨진다)

const EPS := 0.0001


func test_curve_matches_gdd_anchors() -> void:
	# 06 §3.2 앵커 표: Lv1 ≈ 1층 2.03 · 33 ≈ 25층 2.76 · 65 ≈ 50층 3.50 · 130 ≈ 100층 5.80
	assert_almost_eq(FonsScaling.scale_for_floor(1), 2.03, EPS, "1층")
	assert_almost_eq(FonsScaling.scale_for_floor(25), 2.75, EPS, "25층 — 2.0 + 25×0.03")
	assert_almost_eq(FonsScaling.scale_for_floor(50), 3.50, EPS, "50층")
	assert_almost_eq(FonsScaling.scale_for_floor(75), 4.50, EPS, "75층 — 3.5 + 25×0.04")
	assert_almost_eq(FonsScaling.scale_for_floor(100), 5.80, EPS, "100층")


func test_g4_ceiling_extends_to_130() -> void:
	# 확정 #52 — G4 천정: scale = 5.8 + (f−100)×0.05
	assert_almost_eq(FonsScaling.scale_for_floor(101), 5.85, EPS, "101층")
	assert_almost_eq(FonsScaling.scale_for_floor(115), 6.55, EPS, "115층")
	assert_almost_eq(FonsScaling.scale_for_floor(130), 7.30, EPS, "130층 — 런 완주")


func test_segments_join_without_a_jump() -> void:
	assert_almost_eq(FonsScaling.scale_for_floor(50), FonsScaling.scale_for_floor(51) - 0.04, EPS)
	assert_almost_eq(FonsScaling.scale_for_floor(95), FonsScaling.scale_for_floor(96) - 0.10, EPS)
	assert_almost_eq(FonsScaling.scale_for_floor(100), FonsScaling.scale_for_floor(101) - 0.05, EPS)


func test_scale_never_decreases_over_130_floors() -> void:
	var previous := 0.0
	for floor in range(1, 131):
		var scale := FonsScaling.scale_for_floor(floor)
		assert_true(scale > previous, "%d층 스케일 %f 가 이전 층 %f 보다 작다" % [floor, scale, previous])
		previous = scale


func test_floor_is_clamped_to_the_tower() -> void:
	assert_almost_eq(FonsScaling.scale_for_floor(0), FonsScaling.scale_for_floor(1), EPS, "0층 = 1층")
	assert_almost_eq(FonsScaling.scale_for_floor(999), FonsScaling.scale_for_floor(130), EPS,
		"탑 밖 = 130층 (없는 구간을 외삽하지 않는다)")


func test_monster_level_rounds_half_up() -> void:
	# 확정 #37 — Lv = round(층 × 1.3). 50층 Lv65 · 100층 Lv130 · 85층 110.5 → 111
	assert_eq(FonsScaling.monster_level(1), 1)
	assert_eq(FonsScaling.monster_level(50), 65)
	assert_eq(FonsScaling.monster_level(85), 111)
	assert_eq(FonsScaling.monster_level(100), 130)


func test_monster_level_caps_at_130() -> void:
	# 만렙 Lv130 (확정 #37) — 캡이 없으면 101~130층에서 HP 손잡이가 계속 깎아 천정이 오히려 내려간다.
	assert_eq(FonsScaling.monster_level(130), 130)
	assert_eq(FonsScaling.monster_level(200), 130)


func test_high_level_hp_lever() -> void:
	# 확정 #38 ② — 몬스터 Lv110+ HP 복리 ×(1−0.02)^(Lv−110). Lv130 = −33.2%
	assert_almost_eq(FonsScaling.hp_mult_for_level(110), 1.0, EPS, "Lv110 까지는 손잡이 없음")
	assert_almost_eq(FonsScaling.hp_mult_for_level(120), pow(0.98, 10), EPS)
	assert_almost_eq(FonsScaling.hp_mult_for_level(130), pow(0.98, 20), EPS)
	assert_almost_eq(FonsScaling.hp_mult_for_level(130), 0.6676, 0.001, "Lv130 −33.2%")


func test_biome_coefficient_comes_from_data() -> void:
	var biomes: Dictionary = DataLoader.get_biomes()
	var plains := FonsEncounter.biome_for_floor(biomes, 1)
	assert_almost_eq(FonsScaling.biome_mult(plains), 1.0, EPS, "풀바다 = 기준 1.00")
	var volcano := FonsEncounter.biome_for_floor(biomes, 100)
	if not volcano.is_empty():
		assert_almost_eq(FonsScaling.biome_mult(volcano), float(volcano["difficulty"]["mult"]), EPS,
			"바이옴 계수는 데이터 값 그대로")
	assert_almost_eq(FonsScaling.biome_mult({}), 1.0, EPS, "바이옴을 모르면 계수도 없다 (1.0)")


func test_scaled_monster_stats() -> void:
	var monster := {
		"id": "test", "name": "시험체", "tier": 1,
		"stats": {"hp": 1000, "atk": 100, "def": 50, "mdef": 40, "mag": 20,
			"eva": 10, "cri": 5, "cdmg": 160, "aspd": 10, "sta": 80},
	}
	var floor := 50
	var biome := FonsEncounter.biome_for_floor(DataLoader.get_biomes(), floor)
	var mult := FonsScaling.scale_for_floor(floor) * FonsScaling.biome_mult(biome)
	var scaled := FonsScaling.scale_monster(monster, floor, biome)
	var stats: Dictionary = scaled["stats"]
	assert_eq(scaled["id"], "test", "원본 필드는 그대로")
	assert_eq(int(stats["hp"]), int(roundf(1000.0 * mult)), "HP = 기본 × scale × 바이옴")
	assert_eq(int(stats["atk"]), int(roundf(100.0 * mult)), "ATK = 기본 × scale × 바이옴")
	assert_eq(int(stats["def"]), int(roundf(50.0 * mult)), "DEF = 기본 × scale × 바이옴")
	assert_eq(int(stats["mdef"]), int(roundf(40.0 * mult)), "MDEF = 기본 × scale × 바이옴")
	assert_eq(int(stats["mag"]), int(roundf(20.0 * mult)), "MAG = 기본 × scale × 바이옴")
	assert_eq(stats["eva"], 10, "회피율(%)은 배율을 안 곱한다")
	assert_eq(stats["cri"], 5, "치명타율(%)은 배율을 안 곱한다")
	assert_eq(stats["cdmg"], 160, "치명타 피해(%)는 배율을 안 곱한다")
	assert_eq(stats["aspd"], 10, "공격속도는 배율을 안 곱한다")


func test_scaling_does_not_touch_the_source_monster() -> void:
	var monster := {"id": "test", "name": "시험체", "stats": {"hp": 1000, "atk": 100}}
	FonsScaling.scale_monster(monster, 100, {})
	assert_eq(int(monster["stats"]["hp"]), 1000, "원본 Dictionary 는 그대로여야 한다")


func test_g4_hp_relief_applies_only_in_the_ceiling() -> void:
	# 확정 #55 — G4 시뮬은 HP 완화 10% 채택 (★5 봉인 해소). 101층부터.
	var monster := {"id": "test", "name": "시험체", "stats": {"hp": 10000, "atk": 100}}
	var before := FonsScaling.scale_monster(monster, 100, {})
	var after := FonsScaling.scale_monster(monster, 101, {})
	var level := FonsScaling.monster_level(101)
	var expected_before := 10000.0 * FonsScaling.scale_for_floor(100) * FonsScaling.hp_mult_for_level(
		FonsScaling.monster_level(100))
	var expected_after := 10000.0 * FonsScaling.scale_for_floor(101) * FonsScaling.hp_mult_for_level(level) \
		* FonsScaling.G4_HP_RELIEF
	assert_eq(int(before["stats"]["hp"]), int(roundf(expected_before)), "100층에는 완화 없음")
	assert_eq(int(after["stats"]["hp"]), int(roundf(expected_after)), "101층부터 HP ×0.90")
	assert_almost_eq(FonsScaling.G4_HP_RELIEF, 0.90, EPS)


func test_real_monster_is_scaled_at_the_ceiling() -> void:
	# 실제 데이터로 130층까지 — 데이터 기본값이 그대로 들어가지 않는지 잠근다.
	var monsters: Array = DataLoader.get_monsters()["monsters"]
	var monster: Dictionary = monsters[0]
	var floor := 130
	var biome := FonsEncounter.biome_for_floor(DataLoader.get_biomes(), floor)
	var scaled: Dictionary = FonsScaling.scale_monster(monster, floor, biome)
	var base: Dictionary = monster["stats"]
	var expected := float(base["hp"]) * FonsScaling.scale_for_floor(floor) \
		* FonsScaling.biome_mult(biome) * FonsScaling.hp_mult_for_level(130) * FonsScaling.G4_HP_RELIEF
	assert_eq(int(scaled["stats"]["hp"]), int(roundf(expected)), "%s HP" % monster["name"])
	assert_gt(int(scaled["stats"]["hp"]), int(base["hp"]), "130층에서는 기본 HP 보다 커야 한다")
	assert_eq(FonsScaling.biome_mult(biome), 1.0, "G4 는 신규 바이옴 계수 없이 scale 곡선만 (확정 #52)")


func test_hp_knob_changes_only_enemy_hp() -> void:
	# 측정 손잡이 — 정본 곡선은 1.0 그대로 두고, 배율은 HP 에만 건다.
	var monsters: Array = DataLoader.get_monsters()["monsters"]
	var monster: Dictionary = monsters[0]
	var biome := FonsEncounter.biome_for_floor(DataLoader.get_biomes(), 50)
	var canon: Dictionary = FonsScaling.scale_monster(monster, 50, biome)
	var doubled: Dictionary = FonsScaling.scale_monster(monster, 50, biome, 2.0)
	assert_almost_eq(float(doubled["stats"]["hp"]), float(canon["stats"]["hp"]) * 2.0, 2.0,
		"손잡이 2.0 이면 적 HP 만 두 배")
	assert_eq(int(doubled["stats"]["atk"]), int(canon["stats"]["atk"]), "ATK 는 그대로")
	assert_eq(int(doubled["stats"]["def"]), int(canon["stats"]["def"]), "DEF 도 그대로")
