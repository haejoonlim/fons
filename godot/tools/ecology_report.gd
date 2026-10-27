extends SceneTree
## 생태 출현표 — 130층 조우 편성이 어느 사슬층으로 채워지는가 (08 §4 · 06 §3.4).
##
## 실행:
##   godot --headless --path godot -s tools/ecology_report.gd
##   godot --headless --path godot -s tools/ecology_report.gd -- --biomes   # 바이옴별 후보 분포
##   godot --headless --path godot -s tools/ecology_report.gd -- --full      # 편성 종명까지
##   godot --headless --path godot -s tools/ecology_report.gd -- --skip=id,... # 승격 전 지표 재현
##   godot --headless --path godot -s tools/ecology_report.gd -- --borrow-no-food # 이웃 차용에서 먹이층 제외
##
## 이 도구는 규칙을 만들지 않는다. `FonsEncounter` 를 그대로 돌려 **지금 데이터가 내는 표**를
## 찍는다. 편성은 층과 접촉 번호만으로 정해지므로(시드 없음) 이 표는 정적이다 — 같은 데이터면
## 같은 표다. 바뀐 것은 데이터나 편성 규칙뿐이다.
##
## 왜 재는가: 08 §3 은 마커 접촉 로그와 사슬 사냥을 **그 층 편성 풀의 먹이층**에 건다.
## 먹이층이 없는 층에서는 그 미션이 성립하지 않는다. 그 층이 몇 개인지 세는 것이 이 표의 목적이다.

const FLOORS := 130
const CONTACTS := 3   ## 청크마다 조우 3곳 (`FonsExplore.SITE_COUNT`) — 접촉 번호 0..2

var _monsters: Variant
var _biomes: Variant


func _initialize() -> void:
	_monsters = _load("monsters.json").get("monsters", [])
	_biomes = _load("biomes.json")
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--skip="):
			# 측정용 — 이 id 들을 빼고 센다. 승격 전 편성 지표를 같은 규칙으로 다시 재는 데 쓴다.
			var skip: Array = arg.split("=", true, 1)[1].split(",")
			var kept: Array = []
			for m in _monsters:
				if not String(m.get("id", "")) in skip:
					kept.append(m)
			_monsters = kept
	if "--borrow-no-food" in args:
		# 이웃 풀에서 먹이층을 빼고 빌았을 때 먹이층 0 이 다시 생기는지 본다.
		FonsEncounter.borrow_skips_food = true
	if "--biomes" in args:
		_biome_table()
	else:
		_floor_table("--full" in args)
		_summary()
		_biome_table()
	quit()


func _floor_table(full: bool) -> void:
	print("생태 출현표 — 130층 조우 편성 (접촉 0 · 08 §4 사슬층)")
	print("%3s %-9s %2s %2s %2s %2s %2s  %s" % ["층", "바이옴", "인원", "먹이", "포식", "분해", "밖", "편성"])
	for floor in range(1, FLOORS + 1):
		if _no_combat(floor):
			## 일반 조우가 없는 층 — 편성이 비는 게 규칙이다. 표에는 그렇게 적고 집계에서 뺀다.
			print("%3d %-9s %2s %2s %2s %2s %2s  일반 조우 없음" % [floor,
				String(FonsEncounter.biome_for_floor(_biomes, floor).get("name", "")), "-", "-", "-", "-", "-"])
			continue
		var party := FonsEncounter.build_party(_monsters, _biomes, floor, 0)
		var counts := FonsEncounter.chain_counts(party)
		var world := FonsEncounter.biome_for_floor(_biomes, floor)
		var names: Array = []
		if full:
			for m in party:
				names.append(String(m.get("name", m.get("id", "?"))))
		print("%3d %-9s %2d %2d %2d %2d %2d  %s" % [
			floor, String(world.get("name", "")), party.size(),
			int(counts[FonsEncounter.CHAIN_FOOD]), int(counts[FonsEncounter.CHAIN_PREDATOR]),
			int(counts[FonsEncounter.CHAIN_DECOMPOSER]), int(counts[FonsEncounter.CHAIN_NONE]),
			" · ".join(PackedStringArray(names)) if full else FonsEncounter.chain_line(party)])


func _summary() -> void:
	## 조우 단위와 층 단위를 같이 센다 — "한 층에 먹이층이 없다"는 말은 셋 다 없을 때만 참이다.
	var no_food_parties := 0
	var no_food_floors: Array = []
	var no_predator_parties := 0
	var no_predator_floors: Array = []
	var outside_parties := 0
	var outside_floors: Array = []
	var totals := {FonsEncounter.CHAIN_FOOD: 0, FonsEncounter.CHAIN_PREDATOR: 0,
		FonsEncounter.CHAIN_DECOMPOSER: 0, FonsEncounter.CHAIN_NONE: 0}
	var parties := 0
	var species := 0
	var exempt_floors: Array = []
	for floor in range(1, FLOORS + 1):
		if _no_combat(floor):
			exempt_floors.append(floor)
			continue
		var all_no_food := true
		var all_no_predator := true
		var all_outside := true
		for contact in CONTACTS:
			var party := FonsEncounter.build_party(_monsters, _biomes, floor, contact)
			var counts := FonsEncounter.chain_counts(party)
			parties += 1
			species += party.size()
			for key in totals.keys():
				totals[key] = int(totals[key]) + int(counts[key])
			if int(counts[FonsEncounter.CHAIN_FOOD]) == 0:
				no_food_parties += 1
			else:
				all_no_food = false
			if int(counts[FonsEncounter.CHAIN_PREDATOR]) == 0:
				no_predator_parties += 1
			else:
				all_no_predator = false
			if party.size() - int(counts[FonsEncounter.CHAIN_NONE]) > 0:
				all_outside = false
			else:
				outside_parties += 1
		if all_no_food:
			no_food_floors.append(floor)
		if all_no_predator:
			no_predator_floors.append(floor)
		if all_outside:
			outside_floors.append(floor)

	print("")
	print("요약 — 편성 %d개(층 %d × 접촉 %d − 일반 조우 없음 %d층 × %d) · 평균 %.1f종" % [parties, FLOORS, CONTACTS,
		exempt_floors.size(), CONTACTS, float(species) / float(maxi(1, parties))])
	print("  일반 조우 없음(면제) 층 %d: %s" % [exempt_floors.size(), str(exempt_floors)])
	print("  사슬 집계: 먹이 %d · 포식 %d · 분해 %d · 그물 밖 %d" % [
		int(totals[FonsEncounter.CHAIN_FOOD]), int(totals[FonsEncounter.CHAIN_PREDATOR]),
		int(totals[FonsEncounter.CHAIN_DECOMPOSER]), int(totals[FonsEncounter.CHAIN_NONE])])
	print("  먹이층 0 인 조우 %d/%d · 세 조우가 다 그런 층 %d" % [no_food_parties, parties, no_food_floors.size()])
	print("  포식층 0 인 조우 %d/%d · 세 조우가 다 그런 층 %d" % [no_predator_parties, parties, no_predator_floors.size()])
	print("  그물 밖뿐인 조우 %d/%d · 세 조우가 다 그런 층 %d: %s" % [outside_parties, parties,
		outside_floors.size(), str(outside_floors)])
	print("  먹이층 0 인 층: %s" % str(no_food_floors))

	# 고칠 수 있는 몫과 데이터가 모자란 몫을 가른다 — 편성 규칙 문제인지 데이터 문제인지.
	var fixable: Array = []
	var data_gap: Array = []
	for floor in range(1, FLOORS + 1):
		if _no_combat(floor):
			continue
		var pool_food := 0
		for m in FonsEncounter.plan_for_floor(_monsters, _biomes, floor)["candidates"]:
			if FonsEncounter.chain_role(m) == FonsEncounter.CHAIN_FOOD:
				pool_food += 1
		if pool_food == 0:
			if floor in no_food_floors:
				data_gap.append(floor)
		elif floor in no_food_floors:
			fixable.append(floor)
	print("  후보에 먹이층이 있는데 편성에 없는 층(규칙으로 고칠 몫) %d: %s" % [fixable.size(), str(fixable)])
	print("  후보에 먹이층이 아예 없는 층(데이터가 모자란 몫) %d: %s" % [data_gap.size(), str(data_gap)])
	_swap_table()


func _swap_table() -> void:
	## 먹이층 보장(`_ensure_food_layer`)이 무엇을 바꿔 놓았는지 — 빠진 종 → 들어온 종, HP 합 변화.
	## 승률을 대신하지 않는다. 난이도가 어느 방향으로 얼마나 움직였는지만 보인다.
	print("")
	print("먹이층 보장이 바꿈 — 양보 전/후 (접촉 0, 원본 스탯 합)")
	var changed := 0
	for floor in range(1, FLOORS + 1):
		if _no_combat(floor):
			continue
		var candidates: Array = FonsEncounter.plan_for_floor(_monsters, _biomes, floor)["candidates"]
		if candidates.is_empty():
			continue
		var raw := FonsEncounter.select_by_floor_center(candidates,
			FonsEncounter.party_size(candidates.size()), _biomes, floor, 0)
		var party := FonsEncounter.build_party(_monsters, _biomes, floor, 0)
		var raw_ids := raw.map(func(m): return String(m["id"]))
		var ids := party.map(func(m): return String(m["id"]))
		if str(raw_ids) == str(ids):
			continue
		changed += 1
		var dropped: Array = []
		var added: Array = []
		for m in raw:
			if not (String(m["id"]) in ids):
				dropped.append(m)
		for m in party:
			if not (String(m["id"]) in raw_ids):
				added.append(m)
		print("  %3d층 %s → %s · HP 합 %d → %d (%+.0f%%)" % [floor,
			_str_species(dropped), _str_species(added), _hp(raw), _hp(party),
			100.0 * (float(_hp(party)) - float(_hp(raw))) / float(maxi(1, _hp(raw)))])
	print("  양보가 일어난 층 %d" % changed)


func _no_combat(floor: int) -> bool:
	return FonsEncounter.is_combatless_biome(FonsEncounter.biome_for_floor(_biomes, floor))


func _hp(party: Array) -> int:
	var total := 0
	for m in party:
		total += int(m.get("stats", {}).get("hp", 0))
	return total


func _str_species(party: Array) -> String:
	var names: Array = []
	for m in party:
		names.append("%s(t%d)" % [String(m.get("name", m.get("id", "?"))), int(m.get("tier", 1))])
	return ", ".join(PackedStringArray(names)) if not names.is_empty() else "-"


func _biome_table() -> void:
	## 바이옴별 후보 풀의 사슬 분포 — 편성이 비는 이유는 대개 여기서 보인다.
	print("")
	print("바이옴별 후보 풀 (06 §3.4 habitat ∩ 일반+엘리트)")
	print("%2s %-9s %3s %2s %2s %2s %2s" % ["슬롯", "바이옴", "후보", "먹이", "포식", "분해", "밖"])
	for group in _biomes.get("groups", []):
		for biome in group.get("biomes", []):
			var pool: Array = []
			for m in _monsters:
				var mode := String(m.get("spawn", {}).get("mode", ""))
				if mode != "encounter" and mode != "elite":
					continue
				if FonsEncounter.shares_habitat(m, biome):
					pool.append(m)
			var counts := FonsEncounter.chain_counts(pool)
			var slots: Array = biome.get("slots", [])
			## 일반 조우가 없는 바이옴은 후보가 있어도 편성이 비는 게 규칙이다 — 그렇게 적는다.
			var exempt := " 일반 조우 없음" if FonsEncounter.is_combatless_biome(biome) else ""
			print("%2s %-9s %3d %2d %2d %2d %2d%s" % [
				str(int(slots[0])) if not slots.is_empty() else "-",
				String(biome.get("name", "")), pool.size(),
				int(counts[FonsEncounter.CHAIN_FOOD]), int(counts[FonsEncounter.CHAIN_PREDATOR]),
				int(counts[FonsEncounter.CHAIN_DECOMPOSER]), int(counts[FonsEncounter.CHAIN_NONE]), exempt])


func _load(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/%s" % name, FileAccess.READ)
	if f == null:
		push_error("데이터를 열지 못했다: %s" % name)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
