extends GutTest
## 데미지 계약 — 정본은 확정 #6 · 원본 `DamageFormula.cs` · 웹 `combat.ts` 셋이 같은 식이다.
##
##   감소율 = DEF / (DEF + 200)
##   피해   = ATK × (1 − 감소율) × 위치보정     (최소 1, 뱅커스 반올림)
##   관통   = (DEF × (1 − pen)) / (DEF × (1 − pen) + 200)
##
## 2026-10-18 이전 `combat.gd` 는 `ATK − DEF` 였다. 그 식은 위 셋 어디에도 없고,
## 이 테스트 파일이 그 값을 그대로 잠그고 있었다 — 게이트가 틀린 식을 인증한 상태다.

const EPS := 0.0001


func test_mitigation_uses_def_over_def_plus_200() -> void:
	# 100 × (1 − 30/230) = 86.956… → 87
	assert_eq(FonsCombat.compute(100.0, 30.0), 87)


func test_zero_defense_deals_full_attack() -> void:
	assert_eq(FonsCombat.compute(100.0, 0.0), 100)


func test_damage_floors_at_one() -> void:
	assert_eq(FonsCombat.compute(10.0, 5000.0), 1)


func test_zero_attack_deals_nothing() -> void:
	assert_eq(FonsCombat.compute(0.0, 30.0), 0)


func test_negative_defense_is_treated_as_zero() -> void:
	assert_eq(FonsCombat.compute(100.0, -50.0), 100)


func test_penetration_reduces_effective_defense() -> void:
	# 30 × (1 − 0.5) = 15 → 100 × (1 − 15/215) = 93.02 → 93
	assert_eq(FonsCombat.compute(100.0, 30.0, 0.5), 93)


func test_penetration_is_clamped_to_zero_and_one() -> void:
	assert_eq(FonsCombat.compute(100.0, 30.0, -3.0), FonsCombat.compute(100.0, 30.0, 0.0))
	assert_eq(FonsCombat.compute(100.0, 30.0, 9.0), FonsCombat.compute(100.0, 30.0, 1.0))


func test_position_multiplier_applies_after_mitigation() -> void:
	# 86.956… × 1.25 = 108.69 → 109
	assert_eq(FonsCombat.compute(100.0, 30.0, 0.0, 1.25), 109)


func test_rounding_is_bankers() -> void:
	# DEF 200 → 감소율 0.5 · ATK 101 → 50.5 · ATK 103 → 51.5
	# C# Math.Round 기본값(ToEven)과 같아야 한다 — 51 / 52 로 반올림하면 정본과 어긋난다.
	assert_eq(FonsCombat.compute(101.0, 200.0), 50)
	assert_eq(FonsCombat.compute(103.0, 200.0), 52)


func test_position_multiplier_table() -> void:
	assert_almost_eq(FonsCombat.position_multiplier("front", false, false), 1.0, EPS)
	assert_almost_eq(FonsCombat.position_multiplier("flank", false, false), 1.1, EPS)
	assert_almost_eq(FonsCombat.position_multiplier("back", false, false), 1.25, EPS)
	assert_almost_eq(FonsCombat.position_multiplier("front", true, false), 1.15, EPS)
	assert_almost_eq(FonsCombat.position_multiplier("back", true, false), 1.4, EPS, "최대 ×1.40")
	assert_almost_eq(FonsCombat.position_multiplier("front", false, true), 0.75, EPS)
	assert_almost_eq(FonsCombat.position_multiplier("back", true, true), 1.05, EPS, "가산 후 곱")


func test_evade_roll_thresholds() -> void:
	# Math.floor(rng()*100) < eva — 0.12 롤은 12 로 내림되고 eva 12 에서는 맞지 않는다(빗나감 아님).
	assert_false(FonsCombat.try_evade(12.0, 0.12), "12 < 12 는 거짓")
	assert_true(FonsCombat.try_evade(12.0, 0.119), "11 < 12 는 참")
	assert_false(FonsCombat.try_evade(0.0, 0.0), "eva 0 은 항상 맞는다")
	assert_true(FonsCombat.try_evade(100.0, 0.999), "eva 100 은 항상 빗나간다")


func test_crit_multiplier_is_cdmg_percent() -> void:
	# cdmg 100 → ×2.0 (05 §7)
	assert_eq(FonsCombat.apply_crit(87, 100.0), 174)
	assert_eq(FonsCombat.apply_crit(87, 0.0), 87, "cdmg 0 은 배율 없음")


func test_physical_resolution_consumes_evade_before_crit() -> void:
	var evaded := FonsCombat.resolve_physical(100.0, 30.0, 0.0, 50.0, 100.0, 100.0, 1.0, 0.0, 0.0)
	assert_true(evaded["evaded"], "eva 50 · 롤 0.0 은 빗나감")
	assert_eq(evaded["damage"], 0)
	assert_false(evaded["critical"], "빗나가면 치명타 판정을 하지 않는다")

	var hit := FonsCombat.resolve_physical(100.0, 30.0, 0.0, 0.0, 100.0, 100.0, 1.0, 0.5, 0.0)
	assert_false(hit["evaded"])
	assert_true(hit["critical"], "cri 100 · 롤 0.0 은 치명타")
	assert_eq(hit["damage"], 174, "87 × 2.0")


func test_magical_resolution_uses_mdef_and_mpen() -> void:
	# 마법관통은 0~1 실수다(물리 pen 은 퍼센트 0~100).
	# MAG 200 · MDEF 200 · mpen 0.5 → 유효 100 → 200 × (1 − 100/300) = 133.3 → 133
	var out := FonsCombat.resolve_magical(200.0, 200.0, 0.0, 0.0, 0.0, 1.0, 0.5, 0.0, 0.9)
	assert_false(out["evaded"])
	assert_false(out["critical"])
	assert_eq(out["damage"], 133)


func test_move_distance_uses_ms_percent() -> void:
	assert_almost_eq(FonsCombat.move_distance({"MS": 100.0}, 1.0), FonsCombat.BASE_SPEED, EPS)
	assert_almost_eq(FonsCombat.move_distance({"MS": 150.0}, 2.0), FonsCombat.BASE_SPEED * 3.0, EPS)
