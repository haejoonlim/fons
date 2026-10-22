extends GutTest
## 성격 3키워드 — 표가 온전한가, 롤이 정본 규칙을 지키는가, M항이 방향을 만드는가.
##
## 이 파일이 잠그는 것:
##   · 13 메인 · 52 부가 · 26 대척쌍이 데이터에 전부 있다
##   · 롤이 결정론이고, 몰입(★4+)·노련(Lv30+) 게이트를 지키며, 대척쌍을 같이 뽑지 않는다
##   · M항이 **방향**을 만든다 (난폭 > 신중 in 공격, 헌신 > 난폭 in 지원)
##   · 성격은 스탯을 안 건드린다 — 여기서 만든 값은 배율일 뿐 CP 경로에 없다

const MAIN_COUNT := 13
const SUB_COUNT := 52
const PAIR_COUNT := 26


func _data() -> Dictionary:
	return DataLoader.load_json("personalities.json")


func _identity(main: String, subs: Array, seed_value: int = 3) -> Dictionary:
	return {"main": main, "subs": subs, "seed": seed_value}


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_table_has_every_registered_name() -> void:
	var d := _data()
	assert_eq(d["main"].size(), MAIN_COUNT, "메인 13종")
	assert_eq(d["sub"].size(), SUB_COUNT, "부가 52종")
	assert_eq(d["opposite_pairs"].size(), PAIR_COUNT, "대척쌍 26쌍")
	assert_eq(d["apt_domain"].size(), 13, "적성 13종")
	for name in d["main"]:
		var row: Dictionary = d["main"][name]
		assert_true(row.has("domain_dev") and row.has("dial"), "%s 에 편차·기질이 있다" % name)
		for key in FonsPersonality.DIALS:
			assert_true(row["dial"].has(key), "%s · %s 다이얼" % [name, key])
		for domain in FonsPersonality.DOMAINS:
			assert_true(row["domain_dev"].has(domain), "%s · %s 편차" % [name, domain])


func test_domain_mult_stays_inside_the_gdd_band() -> void:
	# 09 §4-1 — M 은 0.7~1.3 밴드. 부가 가중까지 곱한 최악값이 밴드 안이어야 한다.
	var d := _data()
	var lo := 9.0
	var hi := 0.0
	for name in d["main"]:
		for sub in ["호기심", "탐욕"]:
			var id := _identity(name, [sub])
			for domain in FonsPersonality.DOMAINS:
				var m: float = FonsPersonality.domain_mult(d, id, domain)
				lo = minf(lo, m)
				hi = maxf(hi, m)
	assert_between(lo, 0.70, 1.00, "최저 M 이 밴드 안 (실측 %.3f)" % lo)
	assert_between(hi, 1.00, 1.30, "최고 M 이 밴드 안 (실측 %.3f)" % hi)


func test_same_seed_rolls_the_same_person() -> void:
	var d := _data()
	var a := FonsPersonality.roll(d, _rng(42), 5, 1)
	var b := FonsPersonality.roll(d, _rng(42), 5, 1)
	assert_eq(a["main"], b["main"])
	assert_eq(a["subs"], b["subs"], "같은 시드면 같은 부가 2종")
	assert_eq(a["seed"], b["seed"])


func test_roll_is_diverse_and_never_pairs_opposites() -> void:
	var d := _data()
	var rng := _rng(7)
	var seen := {}
	var runs := 400
	for i in runs:
		var id := FonsPersonality.roll(d, rng, 5, 1)
		seen[id["main"]] = true
		assert_eq(id["subs"].size(), 2, "부가 2종")
		for pair in d["opposite_pairs"]:
			assert_false(pair[0] in id["subs"] and pair[1] in id["subs"],
				"대척쌍 %s ↔ %s 는 같이 안 나온다" % [pair[0], pair[1]])
	assert_gte(seen.size(), 10, "%d회 롤에서 메인 %d종 등장" % [runs, seen.size()])


func test_immersion_gate_and_veteran_gate() -> void:
	var d := _data()
	var rng := _rng(11)
	var mains := {}
	for i in 600:
		mains[FonsPersonality.roll(d, rng, 3, 1)["main"]] = true
	assert_false(mains.has("몰입"), "★3 이하에서는 몰입이 안 나온다 (05 §5 게이트)")
	assert_false(mains.has("노련"), "Lv30 미만에서는 노련이 안 나온다")
	var mains5 := {}
	for i in 600:
		mains5[FonsPersonality.roll(d, rng, 5, 1)["main"]] = true
	assert_true(mains5.has("몰입"), "★5 에서는 몰입이 나온다")


func test_main_temperament_tilts_the_domain() -> void:
	var d := _data()
	var rage := _identity("난폭", ["격정", "충동"])
	var careful := _identity("신중", ["관조", "침울"])
	assert_gt(FonsPersonality.domain_mult(d, rage, "공격"),
		FonsPersonality.domain_mult(d, careful, "공격"), "난폭이 공격을 더 좋아한다")
	assert_gt(FonsPersonality.domain_mult(d, careful, "방어·제어"),
		FonsPersonality.domain_mult(d, rage, "방어·제어"), "신중이 방어를 더 좋아한다")
	var devotion := _identity("헌신", ["다정", "온후"])
	assert_gt(FonsPersonality.domain_mult(d, devotion, "지원"),
		FonsPersonality.domain_mult(d, rage, "지원"), "헌신이 지원을 더 좋아한다")


func test_sub_traits_add_and_cap_once() -> void:
	# 호기심은 지식·지식을 선호한다 — 도메인당 1회 캡이라 ×1.21 이 아니라 ×1.10 이다 (09 v0.8).
	var d := _data()
	var plain := _identity("용감", ["낙천", "다정"])
	var curious := _identity("용감", ["호기심", "세심"])
	var w := float(d["meta"]["sub_weight"]["prefer"])
	var plain_m: float = FonsPersonality.domain_mult(d, plain, "지식")
	var curious_m: float = FonsPersonality.domain_mult(d, curious, "지식")
	var ratio := curious_m / plain_m
	assert_almost_eq(ratio, w, 0.02, "중복 선호도 도메인당 1회만 (실측 ×%.3f)" % ratio)


func test_apt_eff_is_rolled_and_gated() -> void:
	var d := _data()
	var id := _identity("성실", ["근면", "꾸준"])
	var low := FonsPersonality.apt_eff(d, id, _rng(5), 3)
	var high := FonsPersonality.apt_eff(d, id, _rng(5), 7)
	assert_eq(low.size(), 13, "적성 13종 전부")
	for apt in low:
		assert_between(float(low[apt]), 0.85, 2.53, "%s 효율 범위" % apt)
	# 같은 시드라도 등급 게이트가 다르면 값이 갈릴 수 있다 — 상위 등급이 더 높다.
	var better := 0
	for apt in low:
		if float(high[apt]) > float(low[apt]):
			better += 1
	assert_gt(better, 0, "★7 이 ★3 보다 높은 적성이 있다 (등급 게이트)")

func test_empty_data_does_not_break_the_caller() -> void:
	assert_false(FonsPersonality.is_ready({}))
	assert_almost_eq(FonsPersonality.domain_mult({}, _identity("용감", []), "공격"), 1.0, 0.001)
	assert_almost_eq(FonsPersonality.dial({}, _identity("용감", []), "risk"), 1.0, 0.001)
