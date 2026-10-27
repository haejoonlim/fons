class_name FonsEcology
extends RefCounted
## 계절 순환 모델 — 07 §8 의 로지스틱 + 로트카-볼테라 + 마르코프 12시즌.
##
## 정본은 원본 저장소 `design-docs/_tools/audit_sim.py` 이고, 이 클래스는 그 1:1 포팅이다
## (원본 대조). 상수는 `res://data/ecology_model.json` 하나를 읽는다 — 파이썬 게이트
## (`sim/ecology.py`) 와 같은 파일을 읽으므로 두 언어에 같은 숫자를 두 번 적지 않는다.
##
## 파리티는 `godot/tests/unit/test_ecology.gd` 가 잠근다. 그 테스트는
## `sim/ecology.py --write-fixture` 가 만든 궤적과 여기서 나온 궤적을 비교한다.
##
## 이 클래스가 하지 않는 것: 종·바이옴 데이터 조립(어떤 종이 어느 바이옴에 사는가).
## 그건 `data/biomes.json` 의 habitat 과 `sim/foodweb.py` 의 `ecosystem()` 이 정한다.
## 여기는 "넘겨받은 종 목록을 몇 계절 돌린다" 만 한다.

const MODEL_PATH := "res://data/ecology_model.json"


class LCG extends RefCounted:
	## 원본과 같은 선형 합동 난수 — 시드를 고정하면 궤적이 재현된다.
	var s: int = 1

	func _init(seed_value: int) -> void:
		s = seed_value

	func randf_next() -> float:
		s = (s * 1103515245 + 12345) & 0x7FFFFFFF
		return float(s) / 2147483647.0


static func load_model(path: String = MODEL_PATH) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("생태 모델 상수를 열지 못했다: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func k_alloc(k_total: float, members: Array, model: Dictionary) -> Dictionary:
	## Kb — 하위 55% · 포식 10%, 종수로 나누고 바닥(5·2).
	## 원본 `round` 는 파이썬 반올림이라 .5 에서 짝수로 간다. 여기 roundf 는 0.5 를 올린다 —
	## K×비율/종수가 정확히 .5 가 되는 경우에만 갈리므로, 그런 K 가 생기면 이 줄을 고친다.
	var low := 0
	var high := 0
	for m in members:
		if bool(m.get("pred", false)):
			high += 1
		else:
			low += 1
	var kb := {}
	for m in members:
		var id := String(m.get("id", ""))
		if bool(m.get("pred", false)):
			kb[id] = maxf(float(model["k_high_floor"]),
				roundf(k_total * float(model["k_high_share"]) / float(maxi(1, high))))
		else:
			kb[id] = maxf(float(model["k_low_floor"]),
				roundf(k_total * float(model["k_low_share"]) / float(maxi(1, low))))
	return kb


static func simulate(members: Array, k_total: float, climate: Dictionary,
		seasons: int, seed: int, model: Dictionary) -> Array:
	## 원본 run() — 계절마다 마르코프 → φ → K·r·d → 400스텝.
	## 돌려주는 것: [{ "nm": 계절 이름, "pop": {종 id: 개체수} }, ...] (첫 칸은 초기값).
	var rng := LCG.new(seed)
	var kb := k_alloc(k_total, members, model)
	var st: Array = []
	var index := {}
	for i in members.size():
		var m: Dictionary = members[i]
		st.append({"s": m, "N": float(kb[String(m["id"])]) * float(model["initial_fraction"]),
			"ext": false, "r": 0.0, "K": 0.0, "d": 0.0})
		index[String(m["id"])] = i
	var prey_of: Array = []
	for o in st:
		var prey: Array = []
		for p in (o["s"] as Dictionary).get("prey", []):
			if index.has(String(p)):
				prey.append(int(index[String(p)]))
		prey_of.append(prey)

	var t0 := float(climate.get("ambient", 15.0))
	var band: Array = climate.get("band", [0, 30])
	var bw := float(band[1]) - float(band[0])
	var names: Array = model["season_names"]
	var matrix: Array = model["markov"]
	var dt := float(model["dt"])
	var steps := int(model["steps"])
	var offset := float(model["anomaly_offset"])
	var phi_floor := float(model["k_phi_floor"])
	var phi_span := float(model["k_phi_span"])
	var d_base := float(model["d_base"])
	var d_food := float(model["d_food"])
	var d_phi := float(model["d_phi"])
	var d_max := float(model["d_max"])
	var d_weight := float(model["d_weight"])
	var loss_base := float(model["loss_base"])
	var loss_agg := float(model["loss_agg"])
	var loss_half := float(model["loss_half"])
	var extinct_at := float(model["extinction"])
	var cap := float(model["cap"])

	var anom := 1
	var hist: Array = [{"nm": String(names[1]), "pop": _snapshot(st)}]
	for season in seasons:
		var row: Array = matrix[anom]
		var u := rng.randf_next()
		anom = 0 if u < float(row[0]) else (1 if u < float(row[0]) + float(row[1]) else 2)
		var temp := t0
		if anom == 0:
			temp -= offset * bw
		elif anom == 2:
			temp += offset * bw
		for o in st:
			if bool(o["ext"]):
				continue
			var s: Dictionary = o["s"]
			var tl := float(s.get("tl", 15.0))
			var tw := float(s.get("tw", 15.0))
			var phi := exp(-pow((temp - tl) / tw, 2.0))
			o["r"] = maxf(float(model["r_floor"]), float(s.get("rep", 0.5)) * phi)
			o["K"] = maxf(2.0, float(kb[String(s["id"])]) * (phi_floor + phi_span * phi))
			o["d"] = minf(d_max, d_base + float(s.get("food", 0.4)) * d_food * (1.0 + d_phi * (1.0 - phi)))
		for _step in steps:
			for i in st.size():
				var o: Dictionary = st[i]
				if bool(o["ext"]):
					continue
				var s: Dictionary = o["s"]
				var loss := 0.0
				for j in prey_of[i]:
					var q: Dictionary = st[int(j)]
					if bool(q["ext"]):
						continue
					loss += (loss_base + loss_agg * float(s.get("agg", 0.3))) \
						* float(q["N"]) / (loss_half + float(q["N"]))
				var n := float(o["N"])
				var dn := float(o["r"]) * n * (1.0 - n / float(o["K"])) - loss * n - float(o["d"]) * n * d_weight
				o["N"] = maxf(0.0, n + dn * dt)
		for o in st:
			if float(o["N"]) < extinct_at:
				o["ext"] = true
				o["N"] = 0.0
			elif not bool(o["ext"]) and float(o["N"]) > float(o["K"]) * cap:
				o["N"] = float(o["K"]) * cap
		if season < seasons - 1:
			for o in st:
				if bool(o["ext"]) and rng.randf_next() < float(model["migration_chance"]):
					o["ext"] = false
					o["N"] = float(kb[String((o["s"] as Dictionary)["id"])]) \
						* float(model["migration_base"]) + float(model["migration_floor"])
		hist.append({"nm": String(names[anom]), "pop": _snapshot(st)})
	return hist


static func _snapshot(st: Array) -> Dictionary:
	var pop := {}
	for o in st:
		pop[String((o["s"] as Dictionary)["id"])] = float(o["N"])
	return pop
