extends GutTest
## 스킬북 — 09 §5 의 각인·성장 규칙이 카탈로그 정본 위에서 그대로 도는가.
##
## 이 파일이 잠그는 것:
##   · 각인 조건 = **태그 최소치 전부** + **합계 임계** (둘 중 하나만으로는 안 된다)
##   · 보유 상한 32 · 50% 판정 (실패해도 재화 없이 다시)
##   · 레벨 = 13 × 현재 레벨 XP · 13레벨에서 단계 승격 + 리셋 · 상한 단계에서 XP 정지
##   · K항 = 1 + 0.05 × 관련 스킬 단계 합


func _catalog() -> Array:
	return DataLoader.load_json("skills_catalog.json")["skills"]


func _rng(seed_value: int = 3) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _d_entry(rarity: int = 1) -> Dictionary:
	return {"name": "시험참", "rarity": rarity, "domain": "공격", "tags": ["근접타격"],
		"context": "", "stage": 1, "level": 1, "xp": 0}


func test_engrave_needs_both_tag_minimums_and_total() -> void:
	var catalog := _catalog()
	# 성광타격(2) = 근접타격 13 최소 + 합계 39. 근접타격만 13 이면 합계가 모자라 안 된다.
	var star: Dictionary = catalog.filter(func(s): return int(s["id"]) == 2)[0]
	assert_eq(star["engrave_threshold"], 39)
	assert_false(FonsSkillBook.meets(star, {"근접타격": 13}, 13), "태그 최소치만으로는 각인이 아니다 — 합계 39")
	var total_short := FonsSkillBook.total_xp({"근접타격": 13})
	assert_lt(total_short, 39)
	assert_false(FonsSkillBook.meets(star, {"근접타격": 13}, total_short), "합계가 모자라면 각인 아님")
	assert_true(FonsSkillBook.meets(star, {"근접타격": 13, "야간": 26}, 39), "문맥이 합계를 채운다")
	assert_false(FonsSkillBook.meets(star, {"근접타격": 5, "야간": 26}, 31), "태그 최소치 미달")


func test_engrave_picks_real_catalog_skills_under_the_cap() -> void:
	var catalog := _catalog()
	var book := {}
	var counters := {"근접타격": 13}
	var born := FonsSkillBook.try_engrave(book, counters, catalog, _rng(), 1.0)
	assert_eq(born.size(), 1, "한 번에 하나만 깨운다 — 발견의 순간")
	for id in book:
		assert_eq(String(book[id]["name"]), String(born[0]))
		assert_true(catalog.any(func(s): return String(s["name"]) == String(born[0])), "카탈로그에 있는 이름만")
	# 조건이 여러 기술을 열어도 **한 번에 하나**씩만 는다.
	var many := {"근접타격": 400, "야간": 40}
	var deep := {}
	for i in 3:
		var one := FonsSkillBook.try_engrave(deep, many, catalog, _rng(i + 1), 1.0)
		assert_eq(one.size(), 1, "%d번째 호출도 하나" % (i + 1))
	assert_eq(deep.size(), 3, "호출 3번 = 기술 3개")
	assert_eq(FonsSkillBook.eligible(deep, many, catalog).size() + 3,
		FonsSkillBook.eligible({}, many, catalog).size(), "이미 가진 것은 후보에서 빠진다")


func test_engrave_never_exceeds_32() -> void:
	var catalog := _catalog()
	var book := {}
	for i in FonsSkillBook.CAP:
		book["dummy_%d" % i] = _d_entry()
	var born := FonsSkillBook.try_engrave(book, {"근접타격": 999}, catalog, _rng(), 1.0)
	assert_eq(born.size(), 0, "32개면 더 각인하지 않는다 (09 §6)")
	assert_eq(book.size(), FonsSkillBook.CAP)


func test_fifty_percent_roll_can_fail_without_cost() -> void:
	var catalog := _catalog()
	var book := {}
	var born := FonsSkillBook.try_engrave(book, {"근접타격": 13}, catalog, _rng(), 0.0)
	assert_eq(born.size(), 0, "판정 실패 — 재화는 들지 않는다")
	assert_eq(book.size(), 0)
	# 다음 시도에서 성공할 수 있다 (같은 카운터로 다시 부른다).
	var again := FonsSkillBook.try_engrave(book, {"근접타격": 13}, catalog, _rng(), 1.0)
	assert_gt(again.size(), 0, "도달 후 반복 판정 (09 §5)")


func test_level_needs_13_times_current_level_and_promotes_at_13() -> void:
	var book := {"a": _d_entry(3)}   # C → 상한 4단계
	for i in 12:
		FonsSkillBook.add_use(book, "a")
	assert_eq(int(book["a"]["level"]), 1, "12 XP 로는 레벨 1")
	FonsSkillBook.add_use(book, "a")
	assert_eq(int(book["a"]["level"]), 2, "13 XP 에 레벨 2")
	assert_eq(int(book["a"]["xp"]), 0, "필요 XP 만큼 차감")
	for i in 13 * 2:
		FonsSkillBook.add_use(book, "a")
	assert_eq(int(book["a"]["level"]), 3, "레벨 3")


func test_stage_promotion_resets_level_and_caps_at_rarity_plus_one() -> void:
	var book := {"a": _d_entry(1)}   # D → 상한 중급(2단계)
	# 13레벨 도달 = 13×(1+2+…+12) = 1,014 XP. 그 다음 13레벨 칸(13×13=169)을 채우면 승격한다.
	for i in 13 * 78:
		FonsSkillBook.add_use(book, "a")
	assert_eq(int(book["a"]["level"]), 13, "1,014 XP 에 13레벨")
	assert_eq(int(book["a"]["stage"]), 1, "아직 승격 전")
	for i in 13 * 13:
		FonsSkillBook.add_use(book, "a")
	assert_eq(int(book["a"]["stage"]), 2, "13레벨 달성 → 단계 승격")
	assert_eq(int(book["a"]["level"]), 1, "레벨 1 리셋")
	assert_eq(int(book["a"]["xp"]), 0)
	# 상한 단계(D=2)의 13레벨에서 XP 가 멈춘다 — 융합으로만 상한을 넘는다.
	book["a"]["level"] = 13
	book["a"]["xp"] = 0
	for i in 5:
		FonsSkillBook.add_use(book, "a")
	assert_eq(int(book["a"]["stage"]), 2, "상한 단계에서는 더 승격하지 않는다")
	assert_eq(int(book["a"]["xp"]), 0, "상한 13레벨이면 XP 정지")


func test_practice_heat_prefers_what_was_just_used() -> void:
	# 같은 단계·같은 태그라도 요즘 쓴 기술이 선택에서 앞선다. 안 쓴 기술은 식지만 지워지지는 않는다.
	var book := {"a": _d_entry(3), "b": _d_entry(3)}
	for i in 4:
		FonsSkillBook.add_use(book, "a")
	assert_gt(float(book["a"]["heat"]), float(book["b"]["heat"]), "쓴 기술이 뜨겁다")
	var hot_a := float(book["a"]["heat"])
	for i in 30:
		FonsSkillBook.add_use(book, "b")
	assert_gt(float(book["b"]["heat"]), float(book["a"]["heat"]), "안 쓴 쪽은 식는다")
	assert_lt(float(book["a"]["heat"]), hot_a)
	assert_almost_eq(FonsSkillBook.heat_bias(0.0), 1.0, 0.001, "차가우면 가중 없음")
	assert_almost_eq(FonsSkillBook.heat_bias(FonsSkillBook.HEAT_CAP),
		1.0 + FonsSkillBook.HEAT_BIAS, 0.001, "뜨거우면 +15% 상한")


func test_k_factor_grows_with_stages_of_that_tag() -> void:
	var book := {"a": _d_entry(1), "b": _d_entry(2)}
	book["b"]["tags"] = ["근접타격", "연속타격"]
	assert_almost_eq(FonsSkillBook.factor(book, "근접타격"), 1.10, 0.001, "1+0.05×(1+1)")
	assert_almost_eq(FonsSkillBook.factor(book, "연속타격"), 1.05, 0.001)
	assert_almost_eq(FonsSkillBook.factor(book, "마법시전"), 1.00, 0.001, "안 쓴 태그는 중립")
	book["a"]["stage"] = 5
	assert_almost_eq(FonsSkillBook.factor(book, "근접타격"), 1.30, 0.001)
	assert_eq(FonsSkillBook.skills_for_tag(book, "근접타격").size(), 2)
