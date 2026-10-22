class_name FonsPersonality
extends RefCounted
## 성격 3키워드(메인 1 + 부가 2) → **행동 선호**. 스탯은 안 건드린다 (GDD 09 §4-1 "CP 무영향").
##
## 왜 이 파일이 따로 있나
## --------------------
## 행동 점수의 M항은 두 조각이다.
##   메인 성향 → 도메인 편차   `(1 + domain_dev[도메인])`  ← GDD 05 §5-1 role 적합도 × role_base (파생)
##   메인 기질 → 행동 버릇     risk·novelty·habit·patience·care 다이얼
##   부가 2종 → 도메인 가중     선호 ×1.10 · 반대 ×0.95 · **도메인당 1회 캡** (09 §4-4 v0.8)
## 표는 `data/personalities.json` 이다 — 생성기 `tools/gen_personalities.py`.
## 여기서 수치를 새로 만들지 않는다. 없으면 push_error 하고 중립(1.0)을 돌려준다.
##
## 왜 결과가 "사람 같아" 보이나
## --------------------------
## 같은 직업·같은 스탯의 쌍둥이라도 부가 2종이 다르면 선호 도메인이 갈리고,
## 메인 기질이 다르면 **같은 상황에서 다른 판단**을 한다 (난폭은 안 물러나고 신중은 물러난다).
## 그리고 이 값은 전투력에 안 닿는다 — 강함이 아니라 **취향**이다.

const DOMAINS := ["공격", "기동", "방어·제어", "지원", "생산", "지식", "사회", "회복"]
const DIALS := ["risk", "novelty", "habit", "patience", "care"]
## 기질 다이얼이 직접 거는 도메인 — risk 는 공격, care 는 지원·회복 (나머지는 브레인이 쓴다).
const DIAL_DOMAINS := {"risk": ["공격"], "care": ["지원", "회복"]}
const SUB_SLOTS := 2
const MAX_ROLL_TRIES := 4
## 09 §4-1 M항 밴드 — 이 밖으로는 안 간다.
const M_MIN := 0.70
const M_MAX := 1.30


static func is_ready(data: Dictionary) -> bool:
	## 데이터가 브레인을 돌릴 만큼 찼는가. 빈 Dictionary 면 브레인을 안 붙인다.
	return data.get("main", {}).size() > 0 and data.get("sub", {}).size() > 0


static func roll(data: Dictionary, rng: RandomNumberGenerator, grade: int = 5,
		level: int = 1) -> Dictionary:
	## 소환 규칙 그대로 — 메인 = 가중치 롤 (몰입은 ★4+, 노련은 Lv30+), 부가 = 비복원 2종 (대척쌍 동시 배제).
	## 반환은 `{main, subs, seed}` 뿐이다 — 이걸 세이브에 넣으면 개체가 재현된다.
	var mains: Dictionary = data.get("main", {})
	var subs: Dictionary = data.get("sub", {})
	if mains.is_empty() or subs.is_empty():
		return {"main": "", "subs": [], "seed": 0}

	var pool: Array = []
	var weights: Array = []
	for name in mains:
		var row: Dictionary = mains[name]
		# 몰입은 ★4+ 전용, 노련은 Lv30+ 재롤 전용 (05 §5 · 09 §4-4 몰입 게이트).
		if name == "몰입" and grade < 4:
			continue
		if name == "노련" and level < 30:
			continue
		pool.append(name)
		weights.append(maxf(0.0, float(row.get("weight", 0))))
	if pool.is_empty():
		return {"main": "", "subs": [], "seed": 0}
	var main: String = pool[_weighted(weights, rng)]

	var names: Array = subs.keys()
	var picked: Array = []
	for attempt in MAX_ROLL_TRIES:
		picked = _roll_subs(names, rng)
		if not _collides(picked, data.get("opposite_pairs", [])):
			break
	return {"main": main, "subs": picked, "seed": int(rng.randi())}


static func _weighted(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return rng.randi_range(0, maxi(0, weights.size() - 1))
	var point := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if point <= acc:
			return i
	return weights.size() - 1


static func _roll_subs(names: Array, rng: RandomNumberGenerator) -> Array:
	## 52종 비복원 2종 — 같은 종이 두 번 나오지 않는다.
	var pool := names.duplicate()
	var out: Array = []
	for i in SUB_SLOTS:
		if pool.is_empty():
			break
		var pick := rng.randi_range(0, pool.size() - 1)
		out.append(pool[pick])
		pool.remove_at(pick)
	return out


static func _collides(picked: Array, pairs: Array) -> bool:
	for pair in pairs:
		if pair.size() < 2:
			continue
		if String(pair[0]) in picked and String(pair[1]) in picked:
			return true
	return false


static func main_of(data: Dictionary, identity: Dictionary) -> Dictionary:
	return data.get("main", {}).get(String(identity.get("main", "")), {})


static func dial(data: Dictionary, identity: Dictionary, key: String) -> float:
	## 메인 기질 다이얼. 데이터에 없는 성향이면 중립 1.0 (0 이 아니다 — 곱셈 항이다).
	var d: Dictionary = main_of(data, identity).get("dial", {})
	return float(d.get(key, 1.0))


static func domain_mult(data: Dictionary, identity: Dictionary, domain: String) -> float:
	## M항. 편차(메인) × 기질 다이얼 × 부가 2종. 부가 가중은 도메인당 한 번만 (09 v0.8).
	var dev: Dictionary = main_of(data, identity).get("domain_dev", {})
	var m := 1.0 + float(dev.get(domain, 0.0))
	for key in DIAL_DOMAINS:
		if domain in DIAL_DOMAINS[key]:
			m *= dial(data, identity, key)
	var sub: Dictionary = data.get("sub", {})
	var w: Dictionary = data.get("meta", {}).get("sub_weight", {})
	var prefer_w := float(w.get("prefer", 1.10))
	var avoid_w := float(w.get("avoid", 0.95))
	var preferred := false
	var avoided := false
	for name in identity.get("subs", []):
		var row: Dictionary = sub.get(String(name), {})
		if domain in row.get("prefer", []):
			preferred = true
		if String(row.get("avoid", "")) == domain:
			avoided = true
	if preferred:
		m *= prefer_w
	if avoided:
		m *= avoid_w
	# 밴드 상한은 GDD 09 §4-1 이 정한 값(0.7~1.3)이다. 기질 곱이 밴드를 넘으면 자른다 —
	# 취향이 아무리 세도 "다른 사람이 안 보이는" 수준까지 가면 그건 성격이 아니라 고정이다.
	return clampf(m, M_MIN, M_MAX)


static func apt_eff(data: Dictionary, identity: Dictionary, rng: RandomNumberGenerator,
		grade: int = 5) -> Dictionary:
	## 적성 13종의 효율 — `APT_TIER[티어] × 부가 가중` (09 §4-1-1 규격 그대로).
	## 티어는 7종 가중 롤 + 등급 게이트 clamp (05 §6). 전투 태그는 이 값을 안 쓴다 (A=1.0 고정).
	var tiers: Dictionary = data.get("apt_tier", {})
	var weights: Array = data.get("apt_weight", [])
	var gates: Dictionary = data.get("apt_tier_grade_gate", {})
	var domain_of: Dictionary = data.get("apt_domain", {})
	var out := {}
	for apt in domain_of.keys():
		var tier := 1
		if not weights.is_empty():
			var idx := _weighted(weights, rng)
			tier = idx + 1
		# 등급 게이트 — 명장(7)=★5+ · 장인(6)=★4+ · 숙련(5)=★3+
		for t in gates.keys():
			if tier >= int(t) and grade < int(gates[t]):
				tier = int(t) - 1
		var value := float(tiers.get(str(tier), 1.0))
		out[apt] = value * domain_mult(data, identity, String(domain_of[apt]))
	return out


static func describe(data: Dictionary, identity: Dictionary) -> String:
	## 표시용 3키워드 — "난폭 · 다정·탐욕". 데이터에 없는 이름은 빈 칸으로 두지 않고 생략한다.
	var parts: Array = []
	var main := String(identity.get("main", ""))
	if not main.is_empty():
		parts.append(main)
	var subs: Array = []
	for name in identity.get("subs", []):
		subs.append(String(name))
	if not subs.is_empty():
		parts.append("·".join(subs))
	return " · ".join(parts)
