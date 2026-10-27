extends GutTest
## 융합 게이트 — 세 심사자가 0.62 를 넘겨야 새 스킬이 태어난다 (GDD 09 §6).
##
## 이 파일이 잠그는 것:
##   · Rule 은 점수가 아니라 **탈락**이다 (증거 3회 미만·부모 미각인·층당 성장 예산·32개 상한 → 후보 제거)
##   · Neural 이 낮으면 **보류**(defer) — 탈락이 아니다. 반복이 쌓이면 다시 온다
##   · JEV 가 낮으면 보류 — 문맥이 안 맞는 밤에는 태어나지 않는다
##   · 0.62 경계에서 뒤집힌다
##   · 태어난 스킬 이름은 **카탈로그에 있는 이름**이다 (고유명사를 새로 만들지 않는다)

const A_ID := 195   # 월영추진 — 돌진 · 매복 (D)
const B_ID := 1     # 빙결강타 — 근접타격 (D)


func _data() -> Dictionary:
	return DataLoader.load_json("personalities.json")


func _job() -> Dictionary:
	return DataLoader.load_json("job_ai_profiles.json")["profiles"]["l2_breaker"]


func _catalog() -> Array:
	return DataLoader.load_json("skills_catalog.json")["skills"]


func _row(id: int) -> Dictionary:
	for skill in _catalog():
		if int(skill["id"]) == int(id):
			return skill
	return {}


func _brain(with_parents: bool = true, stages: int = 5, links: int = 6,
		history: Array = []) -> FonsBrain:
	var b := FonsBrain.new()
	b.setup({"main": "교활", "subs": ["재치", "책략"], "seed": 5}, _data(), _job(), "선봉",
		_catalog(), 5)
	if with_parents:
		for id in [A_ID, B_ID]:
			var skill := _row(id)
			b.book[str(id)] = {"name": String(skill["name"]), "rarity": int(skill["rarity"]),
				"domain": String(skill["domain"]), "tags": skill["tags"],
				"context": String(skill["context"]), "stage": stages, "level": 1, "xp": 0}
			b.recent_skills.append(str(id))
	var key := "%s|%s" % [String(_row(A_ID)["name"]), String(_row(B_ID)["name"])]
	b.links[key] = links
	if links > 0:
		b.link_sessions[key] = links
	for tag in history:
		b.recent.append(tag)
	return b


func _pair(b: FonsBrain) -> Dictionary:
	var key := "%s|%s" % [String(_row(A_ID)["name"]), String(_row(B_ID)["name"])]
	var parts := key.split("|")
	return {"key": key, "a": parts[0], "b": parts[1], "evidence": int(b.link_sessions.get(key, 0))}


func test_rule_rejects_without_both_parents_engraved() -> void:
	var b := _brain(false, 5, 6)
	var v := FonsFusion.evaluate(_pair(b), b, {"night": true}, _catalog())
	assert_eq(String(v["state"]), "reject")
	assert_string_contains(String(v["reason"]), "각인")


func test_rule_rejects_under_three_sessions() -> void:
	var b := _brain(true, 5, 2)
	var v := FonsFusion.evaluate(_pair(b), b, {}, _catalog())
	assert_eq(String(v["state"]), "reject")
	assert_string_contains(String(v["reason"]), "증거")


func test_rule_rejects_at_the_32_skill_cap() -> void:
	var b := _brain(true, 5, 6)
	for i in 32:
		b.book["filler_%d" % i] = {"name": "filler", "rarity": 1, "tags": [],
			"stage": 1, "level": 1, "xp": 0}
	var v := FonsFusion.evaluate(_pair(b), b, {}, _catalog())
	assert_eq(String(v["state"]), "reject")
	assert_string_contains(String(v["reason"]), "상한")


func test_rule_rejects_when_the_floor_growth_budget_is_spent() -> void:
	## 40층 예산은 22. 32 상한 전에 융합도 멈춰야 책이 넘치지 않는다.
	## 130층 예산은 32 — 40층 이후에도 9층마다 한 칸이 열린다.
	var b := _brain(true, 5, 6)
	b.floor = 40
	while b.book.size() < FonsSkillBook.growth_limit(40):
		b.book["filler_%d" % b.book.size()] = {"name": "filler", "rarity": 1, "tags": [],
			"stage": 1, "level": 1, "xp": 0}
	var v := FonsFusion.evaluate(_pair(b), b, {}, _catalog())
	assert_eq(String(v["state"]), "reject")
	assert_string_contains(String(v["reason"]), "성장 예산")
	b.floor = 48
	var blocked := FonsFusion.evaluate(_pair(b), b, {}, _catalog())
	assert_string_contains(String(blocked["reason"]), "성장 예산", "46~48층은 아직 같은 칸")
	b.floor = 49
	var open := FonsFusion.evaluate(_pair(b), b, {}, _catalog())
	assert_ne(String(open["reason"]), "성장 예산 소진 (층당 상한)", "49층 예산 23 — 다시 자리가 난다")


func test_low_neural_defers_not_rejects() -> void:
	var b := _brain(true, 1, 3, [])   # 자라지 않은 스킬 · 최근 습관 없음
	var v := FonsFusion.evaluate(_pair(b), b, {}, _catalog())
	assert_eq(String(v["state"]), "defer", "탈락이 아니라 보류 — 반복이 쌓이면 다시 온다")
	assert_string_contains(String(v["reason"]), "손맛")


func test_low_jev_defers() -> void:
	# 자식 후보를 문맥이 있는 스킬로 고정하고, 그 문맥이 지금 상황과 어긋나게 둔다.
	var b := _brain(true, 5, 6, ["매복", "근접타격", "매복", "근접타격"])
	var child := {"context": "야간", "tags": ["매복"]}
	var off := FonsFusion.jev_score(child, {"night": false})
	var on := FonsFusion.jev_score(child, {"night": true})
	assert_almost_eq(off, 0.7 * 0.2 + 0.3 * 0.5, 0.001, "문맥 불일치 = 0.29")
	assert_almost_eq(on, 0.7 * 1.0 + 0.3 * 0.5, 0.001, "문맥 일치 = 0.85")
	assert_lt(off, 0.40, "불일치는 보류 임계 아래")


func test_neural_counts_a_dominant_pair_not_just_a_common_tag() -> void:
	# 같은 태그를 많이 쓴 것과 "A 다음엔 B"가 버릇인 것은 다르다.
	var b := _brain(true, 5, 3, ["매복", "근접타격", "매복", "근접타격", "매복", "근접타격"])
	var a := String(_row(A_ID)["name"])
	var s := String(_row(B_ID)["name"])
	var focused := FonsFusion.neural_score(b, a, b.book[str(A_ID)], s, b.book[str(B_ID)])
	for i in 9:
		b.link_sessions["%s|다른기술%d" % [a, i]] = 3
	var scattered := FonsFusion.neural_score(b, a, b.book[str(A_ID)], s, b.book[str(B_ID)])
	assert_gt(focused, scattered, "같은 3회라도 A→B 비중이 높아야 손맛이 세다")
	assert_gt(focused, FonsFusion.NEURAL_FLOOR, "지배적인 짝은 문턱을 넘는다")
	assert_lt(scattered, FonsFusion.NEURAL_FLOOR, "여러 기술로 흩어진 짝은 문턱 아래")


func test_threshold_flips_at_062() -> void:
	# 0.4×1.0 + 0.35×n + 0.25×j ≥ 0.62 → 0.35n + 0.25j ≥ 0.22
	var need := (FonsFusion.THRESHOLD - FonsFusion.WEIGHT_RULE) / FonsFusion.WEIGHT_NEURAL
	assert_almost_eq(need, 0.6286, 0.001, "Rule 만점이면 Neural 이 0.63 은 넘어야 한다")


func test_a_well_practised_pair_fuses_into_a_catalog_skill() -> void:
	var b := _brain(true, 5, 6, ["매복", "근접타격", "매복", "근접타격", "매복", "근접타격"])
	var v := FonsFusion.evaluate(_pair(b), b, {"night": true, "jev": 0.8}, _catalog())
	assert_gt(float(v["total"]), FonsFusion.THRESHOLD, "합계 %.3f" % float(v["total"]))
	assert_eq(String(v["state"]), "fuse")
	var names: Array = []
	for skill in _catalog():
		names.append(String(skill["name"]))
	assert_true(String(v["child"]) in names, "태어난 이름은 카탈로그 정본: %s" % String(v["child"]))
	var before := b.book.size()
	assert_true(FonsFusion.apply(b, v), "적용된다")
	assert_eq(b.book.size(), before + 1, "부모는 사라지지 않는다 (09 §6)")
	assert_eq(b.fusions.size(), 1)


func test_place_context_reads_the_biome_not_an_empty_dictionary() -> void:
	# 실제 런에서는 `{}` 가 아니라 지금 층의 세계가 들어와야 JEV 가 산다.
	var biomes: Dictionary = DataLoader.load_json("biomes.json")
	var plain := FonsFusion.place_context(biomes, 1)
	var sea := FonsFusion.place_context(biomes, 15)
	var cave := FonsFusion.place_context(biomes, 40)
	var gate := FonsFusion.place_context(biomes, 5)
	assert_eq(String(plain["biome"]), "biome_plains", "1층은 풀바다")
	assert_true(bool(sea.get("water", false)), "15층 원천연안은 수중 문맥")
	assert_true(bool(cave.get("night", false)), "40층 동굴은 어둠 문맥")
	assert_true(bool(cave.get("obstacle", false)), "동굴은 장애물 문맥")
	assert_true(bool(gate.get("boss", false)), "5층은 게이트키퍼층")
	var child := {"context": "수중", "tags": ["마법시전"]}
	assert_gt(FonsFusion.jev_score(child, sea), FonsFusion.jev_score(child, plain), "물가에서만 수중 기술이 맞다")


func test_candidates_are_sorted_by_evidence() -> void:
	var b := _brain(true, 5, 0)
	b.link_sessions["정찰|매복"] = 5
	b.link_sessions["매복|근접타격"] = 9
	b.link_sessions["후퇴|정찰"] = 1
	b.links["정찰|매복"] = 5
	b.links["매복|근접타격"] = 9
	b.links["후퇴|정찰"] = 1
	var cands := FonsFusion.candidates(b, _catalog())
	assert_eq(cands.size(), 2, "증거 3회 미만은 후보가 아니다")
	assert_eq(String(cands[0]["key"]), "매복|근접타격", "증거 많은 것이 먼저")
