class_name FonsExplore
extends RefCounted
## 층 탐험 — **걷기 · 발견 · 후퇴**만 있는 최소 필드. 화면을 모른다 ([PLAN_2D_FIRST](../../docs/design/PLAN_2D_FIRST.md) R1).
##
## 왜 필요한가
## -----------
## 지금까지 한 층은 "편성 → 전투" 한 번이었다. 정본은 그게 아니다 (확정 #41 · D-265):
## 게이트를 지나면 **유닛을 직접 조작해 걷고**, 조우는 **접촉·발견 트리거**로 일어나며,
## 미션을 달성하면 층이 끝난다. 그리고 실패하면 **즉시 재도전**(탐험 진행 유지)이다.
## 이 파일은 그 세 동작만 구현한다 — 지형 생성·시야·연출은 없다.
##
## 수치는 원본 웹 실측값을 참고한다 (DEV_PLAN §4.3):
##   도보 4.2u/s · 접촉 반경 1.5 · 탐험 필드 40×28.
## 이 값들은 "정본 수치"가 아니라 원본 데모의 시작값이다 — 필드 크기만 우리가 정했다.
##
## 조우 편성은 `FonsEncounter` 가 진다. 여기서는 **어디에 몇 개 두는가**만 정한다.
## 조우 지점 수는 3이다 — 미션 7개(주 1 + 부 6, D-265 2차) 중 주 미션을 "조우 3곳 정리"로
## 잡을 수 있는 최소 단위다 (미션 종류 확정은 구현 후속).

const WALK_SPEED := 4.2
const CONTACT_RADIUS := 1.5
const FIELD_WIDTH := 40.0
const FIELD_DEPTH := 28.0
const SITE_COUNT := 3

var floor := 1
var required := SITE_COUNT
var avatar := Vector2.ZERO
var sites: Array = []
var cleared := 0
var retreated := 0
var log_lines: Array = []

var _monsters: Variant = null
var _biomes: Variant = null
var _rng := RandomNumberGenerator.new()


func start(monsters: Variant, biomes: Variant, floor_value: int, seed_value: int = 0) -> void:
	_monsters = monsters
	_biomes = biomes
	floor = floor_value
	_rng.seed = seed_value + floor_value
	sites = []
	cleared = 0
	retreated = 0
	avatar = Vector2.ZERO
	log_lines = []
	# 지점은 세로 3줄로 고정하고 가로만 난수로 흔든다 — 같은 시드면 같은 배치(결정론).
	for i in SITE_COUNT:
		var z := FIELD_DEPTH * (float(i) + 1.0) / float(SITE_COUNT + 1)
		var x := FIELD_WIDTH * (0.2 + 0.6 * _rng.randf())
		sites.append({"pos": Vector2(x, z), "contact_index": i, "cleared": false})


func walk(direction: Vector2, seconds: float) -> Dictionary:
	## 방향(정규화 전)과 시간으로 이동한다. 필드 밖으로는 못 나간다.
	## 반환: `contact` = 지금 닿아 있는 조우 지점 번호 (-1 이면 없음).
	avatar += direction.normalized() * WALK_SPEED * maxf(0.0, seconds)
	avatar = Vector2(clampf(avatar.x, 0.0, FIELD_WIDTH), clampf(avatar.y, 0.0, FIELD_DEPTH))
	return {"contact": contact_index()}


func walk_to(index: int, heroes: Array = []) -> Dictionary:
	## 조우 지점까지 **걸어서** 간다 — 아바타가 실제로 움직인다. 걷기 한 번이 한 구간이다.
	## 태그를 프레임마다 세면 정찰이 다른 행동을 압도한다. 행동의 단위는 의미 있는 한 걸음이라
	## 여기서는 **구간당 한 번**만 센다 (화면이 붙어도 이 함수를 부르는 쪽이 구간을 정한다).
	if index < 0 or index >= sites.size():
		return {"log": []}
	var target: Vector2 = sites[index]["pos"]
	var delta := target - avatar
	if delta.length() <= 0.001:
		return {"log": []}  # 이미 그 자리에 서 있다 — 걷지 않았으면 걷기 태그도 없다
	walk(delta, delta.length() / WALK_SPEED)
	var lines := _record_all(heroes, "걷기")
	log_lines.append_array(lines)
	return {"log": lines}


func contact_index() -> int:
	## 접촉 반경 안에서 아직 안 지운 지점. 가장 가까운 것 하나만 돌려준다.
	var best := -1
	var best_d := CONTACT_RADIUS
	for i in sites.size():
		if bool(sites[i]["cleared"]):
			continue
		var d := avatar.distance_to(sites[i]["pos"])
		if d <= best_d:
			best_d = d
			best = i
	return best


func fight(index: int, heroes: Array, rng, max_turns: int = FonsFloorRun.MAX_TURNS) -> Dictionary:
	## 조우 하나를 친다. **재도전은 새 편성**이다 — 지점은 안 지워지고, 이긴 판만 지워진다.
	## 유닛은 제자리에서 바뀌므로 `heroes` 는 호출자가 들고 있는 그 파티다 (HP 가 이어진다).
	if index < 0 or index >= sites.size() or bool(sites[index]["cleared"]):
		return {"winner": "none", "turns": 0, "log": []}
	# 조우를 마주친 것도 행동이다 — 발견 태그가 쌓여야 스킬이 그 위에서 각인된다 (09 §3).
	# 브레인이 있으면 카운터·각인 판정까지 간다 (예전에는 유닛 태그만 올라 각인에 안 닿았다).
	var found := _record_all(heroes, "발견")
	var out := FonsFloorRun.simulate(rng, _monsters, _biomes, floor,
		int(sites[index]["contact_index"]), heroes, max_turns)
	out["log"] = found + out["log"]
	log_lines.append_array(out["log"])
	if String(out["winner"]) == "ally":
		sites[index]["cleared"] = true
		cleared += 1
	return out


func retreat(heroes: Array = []) -> Dictionary:
	## 후퇴 — 입구로 돌아간다. 지운 조우는 **남는다** (D-265 "탐험 진행 유지").
	## 후퇴도 그 사람이 한 행동이라 기록한다 (09 §4-3) — 용감한 사람과 소심한 사람이
	## 같은 판에서 같은 횟수로 물러나지는 않는다.
	retreated += 1
	avatar = Vector2.ZERO
	var lines := _record_all(heroes, "후퇴")
	log_lines.append_array(lines)
	return {"log": lines}


func _record_all(heroes: Array, action: String) -> Array:
	## 여러 영웅에게 같은 행동을 남기고 "새 기술" 줄을 돌려준다.
	## 브레인이 없는 유닛은 태그 거울만 오른다 (`FonsBrain.record_action` 이 가른다).
	var lines: Array = []
	for hero in heroes:
		# 죽은 사람은 걷지도 발견하지도 후퇴하지도 않는다 — 카운터는 **한 일**만 센다.
		if not bool(hero.get("alive", true)):
			continue
		var seen := FonsBrain.record_action(hero, action)
		for born in seen["born"]:
			lines.append("%s → 새 기술 「%s」" % [String(hero.get("name", "?")), String(born)])
	return lines


func mission_done() -> bool:
	return cleared >= required


func biome() -> Dictionary:
	## 이 층이 어느 세계인가 — 판정은 조우 편성과 같은 함수가 진다 (슬롯 → 층 범위 → {}).
	return FonsEncounter.biome_for_floor(_biomes, floor)


func snapshot() -> Dictionary:
	## 뷰가 읽는 형식 — 엔티티 id 는 문자열, 위치는 `Vector3`(R2).
	var marks: Array = []
	for i in sites.size():
		var s: Dictionary = sites[i]
		marks.append({
			"id": "site:%d" % i,
			"pos": Vector3(float(s["pos"].x), 0.0, float(s["pos"].y)),
			"cleared": bool(s["cleared"]),
		})
	var world := biome()
	return {
		"floor": floor,
		"avatar": Vector3(avatar.x, 0.0, avatar.y),
		"contact": contact_index(),
		"sites": marks,
		# 뷰는 데이터를 읽지 않는다 — 어느 세계·어떤 지형 키트인지는 문자열로 받는다 (R3).
		"biome": String(world.get("id", "")),
		"kit": String(world.get("topologyKit", "")),
		"cleared": cleared,
		"required": required,
		"done": mission_done(),
		"field": Vector2(FIELD_WIDTH, FIELD_DEPTH),
		"log": log_lines.slice(maxi(0, log_lines.size() - 6)),
	}
