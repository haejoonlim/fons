extends GutTest
## 계절 순환 모델 — 파이썬 시뮬(sim/ecology.py)과 **같은 궤적**인지 잠근다.
##
## 비교 기준값은 `godot/tests/fixtures/ecology_parity.json` 이다. 그 파일은
## `./.venv/bin/python sim/ecology.py --write-fixture` 가 만들고, 게이트 `ecosim` 의
## P-1 검사가 "지금 계산과 같은가"를 매번 확인한다. 그래서 이 테스트가 실패하면
## 둘 중 하나다 — GDScript 포팅이 틀렸거나, 모델을 고치고 픽스처를 다시 안 뽑았다.
##
## 모델 상수는 `data/ecology_model.json` 하나에 있고 두 언어가 같이 읽는다.

const FIXTURE := "res://tests/fixtures/ecology_parity.json"


func _fixture() -> Dictionary:
	var f := FileAccess.open(FIXTURE, FileAccess.READ)
	assert_not_null(f, "패리티 픽스처가 없다 — sim/ecology.py --write-fixture")
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	assert_true(parsed is Dictionary, "패리티 픽스처가 JSON 객체가 아니다")
	return parsed if parsed is Dictionary else {}


func test_model_rows_sum_to_one() -> void:
	# 마르코프 행이 확률분포가 아니면 계절 전이가 합 1 이 아니게 되고,
	# 개체수가 매 계절 조용히 줄거나 늘어난다.
	var model := FonsEcology.load_model()
	assert_false(model.is_empty(), "data/ecology_model.json 을 읽었다")
	for row in model["markov"]:
		assert_almost_eq(float(row[0]) + float(row[1]) + float(row[2]), 1.0, 1e-9)


func test_kb_split_stays_in_trophic_band() -> void:
	# 10% 법칙 — S-2 와 같은 계약(0.03~0.55)을 런타임 쪽에서도 본다.
	var fx := _fixture()
	var model := FonsEcology.load_model()
	var kb := FonsEcology.k_alloc(float(fx["scenario"]["k"]), fx["species"], model)
	var low := 0.0
	var high := 0.0
	for m in fx["species"]:
		var value := float(kb[String(m["id"])])
		if bool(m["pred"]):
			high += value
		else:
			low += value
	assert_gt(low, 0.0, "하위층 K 가 있다")
	var ratio := high / low
	assert_between(ratio, 0.03, 0.55, "포식/피식 K 비율이 10% 법칙 밴드 안")


func test_matches_python_trajectory() -> void:
	var fx := _fixture()
	if fx.is_empty():
		return
	var model := FonsEcology.load_model()
	var scenario: Dictionary = fx["scenario"]
	var members: Array = fx["species"]
	var hist := FonsEcology.simulate(members, float(scenario["k"]), fx["climate"],
		int(scenario["seasons"]), int(scenario["seed"]), model)
	var want: Array = fx["pop"]

	assert_eq(hist.size(), want.size(), "계절 수가 픽스처와 같다")
	var worst := 0.0
	var worst_at := ""
	for season in mini(hist.size(), want.size()):
		var row: Array = want[season]
		for i in mini(members.size(), row.size()):
			var id := String(members[i]["id"])
			var expected := float(row[i])
			var got := float(hist[season]["pop"][id])
			var diff := absf(got - expected) / maxf(1.0, absf(expected))
			if diff > worst:
				worst = diff
				worst_at = "%s %d계절째 (py %.6f · gd %.6f)" % [id, season, expected, got]
	assert_lt(worst, 1e-6, "파이썬과 같은 궤적 (최대 차이 %.10f — %s)" % [worst, worst_at])


func test_same_seed_same_trajectory() -> void:
	# 런타임 결정론 — 시드를 고정하면 같은 계절 열이 나온다.
	var fx := _fixture()
	if fx.is_empty():
		return
	var model := FonsEcology.load_model()
	var scenario: Dictionary = fx["scenario"]
	var a := FonsEcology.simulate(fx["species"], float(scenario["k"]), fx["climate"],
		int(scenario["seasons"]), int(scenario["seed"]), model)
	var b := FonsEcology.simulate(fx["species"], float(scenario["k"]), fx["climate"],
		int(scenario["seasons"]), int(scenario["seed"]), model)
	assert_eq(a, b)
