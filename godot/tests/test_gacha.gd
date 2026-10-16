extends GutTest
## 소환 규칙이 원본 정본 수치와 같은지 검사한다.
## 출처: 원본 확정 #32(확률표·천장)·#33(천장 가안)·#11·D-276(종족 롤)·#16(단가) — 2026-10-17 대조.

func test_band_sum_is_100_percent() -> void:
	assert_almost_eq(FonsGacha.band_sum(), 100.0, 0.0001, "확정 #32 확률표 합 100%")

func test_roll_rarity_uses_cumulative_bands() -> void:
	# 등급마다 재추첨하면 ★4+ 가 33배 과소출현했던 결함(확정 #32)을 막는다.
	assert_eq(FonsGacha.roll_rarity(0.0), "★1", "0 ~ 70.04%")
	assert_eq(FonsGacha.roll_rarity(0.5), "★1")
	assert_eq(FonsGacha.roll_rarity(0.70), "★1")
	assert_eq(FonsGacha.roll_rarity(0.75), "★2", "70.04 ~ 90.04%")
	assert_eq(FonsGacha.roll_rarity(0.95), "★3", "90.04 ~ 98.74%")
	assert_eq(FonsGacha.roll_rarity(0.99), "★4", "98.74 ~ 99.94%")
	assert_eq(FonsGacha.roll_rarity(0.9998), "★5", "99.94 ~ 99.99%")
	assert_eq(FonsGacha.roll_rarity(0.99995), "★6", "99.99 ~ 100%")

func test_race_roll_split() -> void:
	# 확정 #11 · D-276 — shaped 5% + legacy 20종 95%
	assert_eq(FonsGacha.roll_race(0.0), "shaped")
	assert_eq(FonsGacha.roll_race(0.049), "shaped")
	assert_eq(FonsGacha.roll_race(0.05), "legacy")
	assert_almost_eq(FonsGacha.LEGACY_RATE, 0.95, 0.0001)
	assert_eq(FonsGacha.LEGACY_SPECIES, 20)

func test_ticket_and_pity_constants() -> void:
	# 확정 #16 · #32 — 단가와 천장은 원본 수치 그대로 (천장 수치는 #33 가안)
	assert_eq(FonsGacha.TICKET_COST, 130, "티켓 130마석")
	assert_eq(FonsGacha.HARD_PITY_4, 130, "★4 하드 천장 130회")
	assert_eq(FonsGacha.HARD_PITY_5PLUS, 5200, "★5+ 하드 천장 5,200회")
	assert_eq(FonsGacha.SOFT_PITY_START, 70, "★4 소프트 시작 70회")
	assert_almost_eq(FonsGacha.SOFT_PITY_STEP, 0.02, 0.0001, "회차당 +2%p")

func test_soft_pity_starts_at_70() -> void:
	assert_almost_eq(FonsGacha.next_pity_bonus(69), 0.0, 0.0001, "70회 미만은 보너스 없음")
	assert_almost_eq(FonsGacha.next_pity_bonus(70), 0.02, 0.0001, "70회째 +2%p")
	assert_almost_eq(FonsGacha.next_pity_bonus(71), 0.04, 0.0001, "누적 가산")
