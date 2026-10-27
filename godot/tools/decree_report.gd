extends SceneTree
## 칙령 2칸 조합 측정 — 30층 이후 어떤 조합이 실제로 강한가 (04 §3.7 · ADR 0011).
##
## 실행:
##   godot --headless --path godot -s tools/decree_report.gd
##
## 이 도구는 규칙을 새로 만들지 않는다. `FonsEstate` 를 그대로 돌려
## 세금·수확·민심·식량 여유·파업까지 버티는 층을 잰다. 값은 전부 `data/estate.json` 에서 온다.
##
## 전제 (측정 조건이지 정본이 아니다):
##   · 인구 60 — 지금 구현된 S1 상한 (`stages[0]`) 이다. 확장이 붙으면 이 표를 다시 뽑는다.
##   · 상한 초과 골드 — 분배주의가 상한에 닿은 뒤에도 값을 하는지 재는 열이다 (ADR 0012).
##   · 소환제단 Lv1 — 채집팀 1팀. 시설 업글이 아직 없어 실제 게임과 같은 값이다.
##   · 여름 101일 — 계절 자연증가 배율 1.0. 봄 1.5 배율이 칙령 효과와 섞이지 않게 한다.
##   · 두 칸은 이미 조립된 상태로 잰다. 실제 조립은 5층 쿨다운이 걸린다 (ADR 0011).

const FLOORS := [30, 50, 90]
const POP := 60
const CAP := 60
const START_POP := 30
const COMBOS := [
	{"name": "없음", "ids": []},
	{"name": "중상주의", "ids": ["mercantilism"]},
	{"name": "분배주의", "ids": ["distribution"]},
	{"name": "채집장려", "ids": ["gathering"]},
	{"name": "중상+분배", "ids": ["mercantilism", "distribution"]},
	{"name": "중상+채집", "ids": ["mercantilism", "gathering"]},
	{"name": "분배+채집", "ids": ["distribution", "gathering"]},
]

var _estate: Dictionary


func _initialize() -> void:
	_estate = _load("estate.json")
	_steady()
	_growth()
	_accumulated()
	_notes()
	quit()


func _steady() -> void:
	print("## 1. 정착 상태 — 인구 %d · 여름 101일 · 제단 Lv1\n" % POP)
	print("| 층 | 조합 | 민심 | 세금/일 | 상한 초과/일 | 수확/일 | 식량 필요 | 식량 여유 | 순골드/일 | 파업까지 굶주린 층 |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for floor_value in FLOORS:
		for combo in COMBOS:
			var e := _build(floor_value, combo["ids"])
			var out := _day(e)
			var tax := int(out["tax"])
			var overflow_gold := int(out.get("overflow_gold", 0))
			var harvest := int(out["harvest"].get("food", 0))
			var need := int(out["food_eaten"])
			var margin := harvest - need
			var net := tax + overflow_gold - int(out["maintenance"])
			print("| %d | %s | %d | %d | %+d | %d | %d | %+d | %+d | %d |" % [
				floor_value, String(combo["name"]), e.morale, tax, overflow_gold, harvest, need,
				margin, net, _shortage_floors(floor_value, combo["ids"])])
	print("")


func _growth() -> void:
	print("## 2. 인구 30 → 상한 %d — 분배주의 자연증가가 실제로 값을 하는가\n" % CAP)
	print("| 조합 | 자연증가 배율 | 상한 도달 |")
	print("|---|---|---|")
	for combo in COMBOS:
		var e := _build(50, combo["ids"])
		var mul := e._decree_mul("natural_growth_mul")
		print("| %s | ×%.2f | %s |" % [
			String(combo["name"]), mul, _days_to_cap(combo["ids"])])
	print("")


func _accumulated() -> void:
	## 인구 30 에서 60일. 상한만 바꿔 본다 — 확장 구현 전에도 분배주의 성장이
	## 세금 차이를 메우는지 보려는 민감도다. 상한은 시뮬레이터가 덮어쓴다 (`_stage_caps`).
	print("## 3. 60일 누적 — 인구 30 시작 · 같은 50층\n")
	print("| 조합 | 상한 60 세금 | 상한 60 상한 초과 | 상한 60 인구 | 상한 150 세금 | 상한 150 상한 초과 | 상한 150 인구 |")
	print("|---|---|---|---|---|---|---|")
	for combo in COMBOS:
		var a := _accumulate(combo["ids"], 60)
		var b := _accumulate(combo["ids"], 150)
		print("| %s | %dG | %dG | %d | %dG | %dG | %d |" % [
			String(combo["name"]), int(a["tax"]), int(a["overflow"]), int(a["pop"]),
			int(b["tax"]), int(b["overflow"]), int(b["pop"])])
	print("")


func _accumulate(ids: Array, cap: int) -> Dictionary:
	var e := _build(50, ids)
	e.population = float(START_POP)
	e._stage_caps = [cap]
	e.clock_epoch = 1000
	e.last_settled_day = 100
	e.stores["food"] = 100000000
	var tax := 0
	var overflow := 0
	for day in 60:
		var out := e.settle(1000 + (100 + day + 1) * 12343, 1000000)
		tax += int(out["tax"])
		overflow += int(out.get("overflow_gold", 0))
	return {"tax": tax, "overflow": overflow, "pop": roundi(e.population)}


func _notes() -> void:
	print("## 4. 읽는 법")
	print("- `파업까지 굶주린 층` 은 식량을 0으로 두고 `note_floor_cleared()` 를 반복해 실제로 파업이 걸린 층이다.")
	print("- 수확은 제단 Lv1 한 팀이다. 팀이 늘면 채집장려의 절대 이득도 같이 커진다.")
	print("- 인구 상한이 60 이라 분배주의 자연증가는 상한에 닿으면 멈춘다 — 대신 초과분이 골드가 된다 (ADR 0012). 표 1·3 의 `상한 초과` 열이다.")
	print("- 모든 조합의 민심은 파업 기준(20) 위다. 식량이 남는 한 -20 민심은 비용으로 작동하지 않는다.")
	print("- 실제 조립 비용은 5층 쿨다운 하나다. 두 번째 칸은 35층(또는 그 뒤)부터 켜진다 (ADR 0011).")
	print("")


func _build(floor_value: int, ids: Array) -> FonsEstate:
	## 두 칸을 이미 채운 상태를 만든다. 조립 경로(5층 쿨다운)는 `_notes` 가 따로 말한다.
	var e := FonsEstate.new()
	e.start(_estate, floor_value)
	e.population = float(POP)
	e.stores = {"food": 0, "herb": 0, "wood": 0, "ore": 0}
	for i in ids.size():
		e.floor = floor_value
		e.reset_decree_cooldown()
		var out := e.set_decree(String(ids[i]), i)
		assert(bool(out["ok"]), "조합을 세울 수 없다: %s" % String(ids[i]))
	e.floor = floor_value
	e.reset_decree_cooldown()
	return e


func _day(e: FonsEstate) -> Dictionary:
	## 하루치 정산 — 세금·수확·소비·인구증가를 실제 코어가 계산한다.
	e.clock_epoch = 1000
	e.last_settled_day = 100
	e.stores["food"] = 100000
	return e.settle(1000 + 100 * 12343, 1000000)


func _shortage_floors(floor_value: int, ids: Array) -> int:
	## 식량 0 이 계속될 때 파업까지 버티는 층. 30층을 넘기면 30으로 적는다.
	var e := _build(floor_value, ids)
	e.stores["food"] = 0
	var floors := 0
	while not e.is_striking() and floors < 30:
		e.note_floor_cleared()
		floors += 1
	return floors


func _days_to_cap(ids: Array) -> String:
	## 인구 30 에서 S1 상한 60 까지. 매일 정산하며 자연증가만 본다.
	var e := _build(50, ids)
	e.population = float(START_POP)
	e.clock_epoch = 1000
	e.last_settled_day = 100
	e.stores["food"] = 10000000
	var days := 0
	while e.population < float(CAP) and days < 60:
		days += 1
		e.settle(1000 + (100 + days) * 12343, 1000000)
	return "%d일" % days if e.population >= float(CAP) else "60일+"


func _load(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/%s" % name, FileAccess.READ)
	if f == null:
		push_error("데이터를 열지 못했다: %s" % name)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
