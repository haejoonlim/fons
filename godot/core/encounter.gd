class_name FonsEncounter
extends RefCounted
## 06 §3.4 생태 조우 편성 — habitat 1차 · 온도 2차 · 인접 블록 폴백 · 접촉 회전.
##
## 원본은 Unity C# `EcologyEncounter` 다. 이 저장소에는 포팅이 없어서 **130층 중 어느 층의
## 조우도 계산할 수 없었다** (06 §3.4 각주 "godot/에 GDScript로 다시 만든다(미이식)").
##
## 왜 `spawn.floors` 를 안 쓰나
## ---------------------------
## 그 필드는 v7.12 의 "불연속 출현 층"이다 — 늑대 [2,3,4] 는 2·3·4층에서만 나온다는 뜻이지
## 2~4층 구간이 아니다. 원본 런타임이 이걸 범위로 읽어 **130층 중 73층이 후보 0** 이었다.
## 06 §3.4 는 후보를 `ecology.habitat ∩ biome.habitat` 로만 정의하고 `spawn.floors` 는
## "기록용 참조로 강등" 했다. 여기서도 읽지 않는다 — `level` 도 마찬가지다(같은 각주).
##
## 계약
## ----
##   후보   일반+엘리트 (`mode` = encounter·elite). `world`(비전투)와 `boss`(게이트키퍼 별도)는 제외.
##   1차    habitat 교집합 — 그 바이옴에 사는 종만.
##   폴백   후보 < 4종이면 층대 ±1블록 바이옴의 풀을 병합 (빈 편성 금지).
##   2차    온도 band — habitat 이 1차, 온도가 2차. **폴백 뒤에** 건다.
##          elemental·guardian·undead 는 면역(환경 그 자체이거나 생체가 아니다).
##   편성   3~5종 · 중심 tier 은 층 스케일(바이옴 층 구간 ÷ 최고 tier) · 접촉 번호는
##          **같은 tier 거리 그룹 안에서만** 순서를 돌린다(§3.7).
##
## 폴백 뒤에 habitat 을 다시 걸지 않는 이유: 폴백은 "이웃 바이옴의 풀"을 빌리는 장치라
## 빌려온 종은 원래 habitat 과 정의상 겹치지 않는다. 다시 거르면 폴백이 항상 무의미해진다.

const BLOCK_FLOORS := 5     ## 5층 = 블록 1개 (26블록 = 130층)
const MAX_FLOOR := 130      ## 확정 #52 — 탑 층수
const TIER_MAX := 5         ## monsters.json tier 는 1~5
const POOL_MIN := 4         ## §3.4 G/I — 이보다 적으면 인접 블록 병합
const PARTY_MIN := 3        ## §3.4 H — 3~5종
const PARTY_MAX := 5
const IMMUNE_ROLES := ["elemental", "guardian", "undead"]   ## §3.5-2 온도 면역


static func block_for_floor(floor: int) -> int:
	return int((floor - 1) / BLOCK_FLOORS) + 1


static func _monster_list(all: Variant) -> Array:
	# 호출자는 DataLoader.get_monsters() 를 그대로 넘긴다 ({"monsters": [...]}) — 배열도 받는다.
	if all is Dictionary:
		return all.get("monsters", [])
	if all is Array:
		return all
	return []


static func _biome_list(biomes: Variant) -> Array:
	if biomes is Dictionary:
		return biomes.get("groups", [])
	if biomes is Array:
		return biomes
	return []


static func biome_for_floor(biomes: Variant, floor: int) -> Dictionary:
	# ① 블록(slots[0]) 조회 → ② slots 없으면 floors 범위 폴백 → ③ 없으면 {} (표기 생략 규약).
	if floor < 1:
		return {}
	var block := block_for_floor(floor)
	for group in _biome_list(biomes):
		for biome in group.get("biomes", []):
			var slots: Array = biome.get("slots", [])
			if not slots.is_empty() and int(slots[0]) == block:
				return biome
	for group in _biome_list(biomes):
		for biome in group.get("biomes", []):
			var floors: Array = biome.get("floors", [])
			if floors.size() >= 2 and floor >= int(floors[0]) and floor <= int(floors[1]):
				return biome
	return {}


static func biome_floor_range(biome: Dictionary) -> Array:
	# [최소층, 최대층] — 중심 tier 계산이 쓴다. 슬롯이 정본, 없으면 floors.
	var slots: Array = biome.get("slots", [])
	if not slots.is_empty() and int(slots[0]) >= 1:
		var lo := (int(slots[0]) - 1) * BLOCK_FLOORS + 1
		return [lo, lo + BLOCK_FLOORS - 1]
	var floors: Array = biome.get("floors", [])
	if floors.size() >= 2:
		return [int(floors[0]), int(floors[1])]
	return []


static func shares_habitat(monster: Dictionary, biome: Dictionary) -> bool:
	var mine: Array = monster.get("ecology", {}).get("habitat", [])
	var theirs: Array = biome.get("habitat", [])
	for a in mine:
		if String(a).is_empty():
			continue
		for b in theirs:
			if String(a) == String(b):
				return true
	return false


static func is_temperature_immune(monster: Dictionary) -> bool:
	return String(monster.get("ecology", {}).get("role", "")) in IMMUNE_ROLES


static func temperature_fits(monster: Dictionary, biome: Dictionary) -> bool:
	# 근거가 없으면 통과시킨다 — 정보가 없다고 탈락시키면 편성이 빈다.
	if is_temperature_immune(monster):
		return true
	var band: Array = biome.get("climate", {}).get("band", [])
	if band.size() < 2:
		return true
	var temp: Dictionary = monster.get("ecology", {}).get("temperature", {})
	if temp.is_empty():
		return true
	return not (float(temp.get("max", 0)) < float(band[0]) or float(temp.get("min", 0)) > float(band[1]))


static func _collect_habitat_pool(all: Variant, biome: Dictionary) -> Array:
	var pool := []
	if biome.is_empty():
		return pool
	for m in _monster_list(all):
		var mode := String(m.get("spawn", {}).get("mode", ""))
		if mode != "encounter" and mode != "elite":
			continue        # world(비전투) · boss(게이트키퍼 경로) 제외
		if shares_habitat(m, biome):
			pool.append(m)
	return pool


static func target_tier(floor: int) -> int:
	## 깊이에 맞는 tier — 06 §3.4 식(층 구간 ÷ 최고 tier)을 바이옴 5층이 아니라 **탑 전체**에 건다.
	## 130 ÷ 5 = 26 → 1~26 tier1 · 27~52 tier2 · 53~78 tier3 · 79~104 tier4 · 105~130 tier5.
	## 새 수치가 아니다: 나누는 수는 확정 #52 의 130층과 monsters.json 의 tier 최고값 5 둘이다.
	## 바이옴별로 나누면 5층짜리 구간이 tier 1~상한을 다 돌아 **블록마다 초기화**한다 —
	## 76층(tier1)이 75층(tier3)보다 쉽고, 101층(tier1)이 100층(tier4)보다 쉬웠던 이유다.
	var span := maxi(1, int(MAX_FLOOR / TIER_MAX))
	return clampi(int((clampi(floor, 1, MAX_FLOOR) - 1) / span) + 1, 1, TIER_MAX)


static func _max_tier(pool: Array) -> int:
	var top := 0
	for m in pool:
		top = maxi(top, int(m.get("tier", 1)))
	return top


static func _merge_neighbor_pools(pool: Array, all: Variant, biomes: Variant, floor: int) -> void:
	## 06 §3.4 G/I — 층대 ±1블록 바이옴 풀 병합. 원래 후보는 지우지 않는다(중복 id 만 막는다).
	var biome := biome_for_floor(biomes, floor)
	var seen := {}
	for m in pool:
		seen[String(m["id"])] = true
	for neighbor in [floor - BLOCK_FLOORS, floor + BLOCK_FLOORS]:
		if neighbor < 1:
			continue
		var other := biome_for_floor(biomes, neighbor)
		if other.is_empty() or String(other.get("id", "")) == String(biome.get("id", "")):
			continue
		for m in _collect_habitat_pool(all, other):
			var id := String(m["id"])
			if seen.has(id):
				continue
			seen[id] = true
			pool.append(m)


static func plan_for_floor(all: Variant, biomes: Variant, floor: int) -> Dictionary:
	var biome := biome_for_floor(biomes, floor)
	var pool := _collect_habitat_pool(all, biome)
	var plan := {
		"floor": floor,
		"biome_id": String(biome.get("id", "")),
		"pool_before_fallback": pool.size(),
		"fallback_used": false,
		"tier_shortfall_used": false,
		"target_tier": target_tier(floor),
		"candidates": [],
		"temperature_emptied": false,
	}

	if pool.size() < POOL_MIN:
		plan["fallback_used"] = true
		_merge_neighbor_pools(pool, all, biomes, floor)

	# tier 가 모자란 바이옴은 이웃에서 번린다 — 같은 이유(빈 편성 금지)의 연장이다.
	# 깊은 층에 tier 3~4 종밖에 없는 바이옴이 오면, 그 층 혼자만 쉽게 뚫린다.
	# 06 §3.2 "실질 강도는 tier × scale" 이 성립하려면 중심 tier 에 도달할 수 있어야 한다.
	var target := target_tier(floor)
	if _max_tier(pool) < target:
		plan["tier_shortfall_used"] = true
		_merge_neighbor_pools(pool, all, biomes, floor)

	# 2차 게이트는 폴백 **뒤** — 폴백이 온도 탈락을 메우는 역할도 하므로 순서가 결과를 바꾼다.
	var candidates := []
	for m in pool:
		if temperature_fits(m, biome):
			candidates.append(m)
	plan["candidates"] = candidates
	plan["temperature_emptied"] = candidates.is_empty()
	return plan


static func party_size(candidate_count: int) -> int:
	if candidate_count < PARTY_MIN:
		return PARTY_MIN
	if candidate_count > PARTY_MAX:
		return PARTY_MAX
	return candidate_count


static func center_tier_for_floor(biomes: Variant, floor: int, candidates: Array) -> int:
	# "층 스케일에 맞는 tier 중심" — 바이옴 5층 구간의 지역 사다리와 **탑 전체의 깊이 목표** 중
	# 높은 쪽이다. 지역 사다리만 쓰면 블록마다 tier 1 로 되돌아가고, 깊이 목표만 쓰면
	# 블록 안 5층이 같은 편성이 된다. 둘을 합치면 블록 안의 변화는 남기고 바닥은 깊이에 맞힌다.
	if candidates.is_empty():
		return 1
	var biome := biome_for_floor(biomes, floor)
	var span := biome_floor_range(biome)
	if span.size() < 2 or int(span[1]) <= int(span[0]):
		return _median_tier(candidates)
	var lo := int(span[0])
	var hi := int(span[1])
	var top := 1
	for m in candidates:
		top = maxi(top, int(m.get("tier", 1)))
	var size := maxi(1, int((hi - lo + 1) / top))
	for t in range(1, top + 1):
		var a := maxi(lo, lo + size * (top - 1)) if t == top else lo + size * (t - 1)
		var b := hi if t == top else lo + size * t - 1
		if floor >= a and floor <= b:
			return maxi(t, target_tier(floor))
	return maxi(top, target_tier(floor))


static func _median_tier(candidates: Array) -> int:
	var tiers := []
	for m in candidates:
		tiers.append(int(m.get("tier", 1)))
	if tiers.is_empty():
		return 1
	tiers.sort()
	var mid := tiers.size() / 2
	if tiers.size() % 2 == 1:
		return tiers[mid]
	return int((tiers[mid - 1] + tiers[mid]) / 2)


static func select_by_floor_center(candidates: Array, k: int, biomes: Variant, floor: int,
		contact_index: int = 0) -> Array:
	if candidates.is_empty() or k <= 0:
		return []
	if candidates.size() <= k:
		return candidates.duplicate()

	var center := center_tier_for_floor(biomes, floor, candidates)
	var ordered := candidates.duplicate()
	ordered.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))

	var dist := {}
	for m in ordered:
		dist[String(m["id"])] = absi(int(m.get("tier", 1)) - center)

	# tier 거리별 그룹 안에서만 접촉 번호로 회전 — 중심 tier 우선순위는 보존된다.
	var rank := {}
	var nearest := 99
	for m in ordered:
		nearest = mini(nearest, dist[String(m["id"])])
	for d in range(nearest, nearest + 5):
		var group := []
		for m in ordered:
			if dist[String(m["id"])] == d:
				group.append(m)
		if group.is_empty():
			continue
		var n := group.size()
		var shift := ((contact_index % n) + n) % n
		for i in range(n):
			rank[String(group[i]["id"])] = (i - shift + n) % n

	ordered.sort_custom(func(a, b):
		var da: int = dist[String(a["id"])]
		var db: int = dist[String(b["id"])]
		if da != db:
			return da < db
		return int(rank[String(a["id"])]) < int(rank[String(b["id"])])
	)
	return ordered.slice(0, k)


## 게이트키퍼 — 층 문지기 경로. 일반 편성(`encounter`·`elite`)과 **별개 축**이다.
##
## 정본: 02 조우 모드 "`boss`(보스 후보 · 게이트키퍼층 5/10/15/20에서 tier4 이상 1체)".
## 그래서 일반 편성 풀에서 `boss` 를 뺴 놓았고(위 `_collect_habitat_pool`), 여기서 따로 집는다.
## 인원은 1체다 — "1체"가 정본이고, 일반 조우의 3~5종과 섞지 않는다.
const GATEKEEPER_FLOORS := [5, 10, 15, 20]
## 계층문지기 경계 — 65/66 · 105/106 (biomes.json meta.tierGatekeepers).
## 이 두 곳은 `monsters.json` 에 상대가 없다 (26블록 §10 "G4 6종 문서 전용") — 측정은 경계층
## 일반 조우를 대리로 쓰고, 표에 그렇게 적는다.
const LAYER_BOUNDARIES := [65, 66, 105, 106]


static func gatekeeper_for_floor(all: Variant, floor: int) -> Dictionary:
	## `spawn.mode == "boss"` 이고 `spawn.floors` 에 그 층이 있는 몬스터. 없으면 {}.
	## 같은 층에 문지기가 둘 이상이면 데이터 순서 첫 번째를 쓴다 (46·50층처럼 겹치는 층이 있다).
	for m in _monster_list(all):
		var spawn: Dictionary = m.get("spawn", {})
		if String(spawn.get("mode", "")) != "boss":
			continue
		for f in spawn.get("floors", []):
			if int(f) == floor:
				return m
	return {}


static func is_gatekeeper_floor(floor: int) -> bool:
	return floor in GATEKEEPER_FLOORS


static func build_party(all: Variant, biomes: Variant, floor: int, contact_index: int = 0) -> Array:
	var plan := plan_for_floor(all, biomes, floor)
	var candidates: Array = plan["candidates"]
	if candidates.is_empty():
		return []
	return select_by_floor_center(candidates, party_size(candidates.size()), biomes, floor, contact_index)
