class_name FonsExplore
extends RefCounted
## 층 탐험 — **걷기 · 발견 · 후퇴**만 있는 최소 필드. 화면을 모른다 ([PLAN_2D_FIRST](../../docs/design/PLAN_2D_FIRST.md) R1).
##
## 2026-10-26 — **무한맵 1단계**. 좌표가 필드(0..40, 0..28)에서 **월드 좌표**로 바뀌었다.
## 아바타는 어디로든 걷고, 조우는 40×28 **청크**마다 3곳씩 시드로 생성된다. 청크는
## 아바타 주변 `ACTIVE_RADIUS` 만큼만 살아 있고, 그 밖은 다시 걸어가면 같은 자리·같은 편성으로
## 되살아난다 (시드 = 층 + 청크 좌표). 지운 조우는 월드 키로 남아 재진입해도 지워진 채다.
##
## 왜 클램프를 지웠나
## ------------------
## "지금 맵이 한정되어 있다"는 피드백. 경계만 넓히면 또 경계가 보인다 — 마인크래프트처럼
## 끝이 없으려면 심이 **좌표를 제한하지 않아야** 한다. 뷰는 아바타 주변 청크만 그린다.
##
## 탑·소환진은 **월드 원점(0,0)** 이다. 청크 (0,0) 의 한가운데라 어디를 걷다 돌아와도 같은 자리다.
##
## 수치는 원본 웹 실측값을 참고한다 (DEV_PLAN §4.3):
##   도보 4.2u/s · 접촉 반경 1.5 · 청크 40×28.
## 조우 편성은 `FonsEncounter` 가 진다. 여기서는 **어디에 몇 개 두는가**만 정한다.

const WALK_SPEED := 4.2
const CONTACT_RADIUS := 1.5
## 청크 = 예전 "필드" 한 판. 무한맵은 이 크기로 이어 붙인다.
const CHUNK_WIDTH := 40.0
const CHUNK_DEPTH := 28.0
## 이전 이름 — 뷰 계약(`field`)과 테스트가 쓰던 값. 뜻은 이제 "청크 크기"다.
const FIELD_WIDTH := CHUNK_WIDTH
const FIELD_DEPTH := CHUNK_DEPTH
## 청크마다 두는 조우 수.
const SITE_COUNT := 3
## 아바타 주변 몇 청크를 살릴까. 1 이면 3×3 = 최대 27조우가 활성이다.
const ACTIVE_RADIUS := 1
## 탑·소환진 — 월드 원점. 반경은 소환진 바깥 고리, `body` 는 탑 몸통.
const TOWER_RADIUS := 3.4
const TOWER_BODY := 1.2
## 탑 주변 이 반경에는 조우를 두지 않는다 — 소환진 위에서 싸우면 랜드마크가 전장이 된다.
const TOWER_CLEAR := 6.0
## 시작·후퇴 자리 — 탑 **몸통 바로 바깥**, 소환진 안쪽. 원점에 그대로 세우면 3인칭 카메라가
## 탑기둥 안에서 시작해 화면이 돌 하나로 가린다 (2026-10-26 렌더).
const SPAWN := Vector2(0.0, TOWER_BODY + 1.4)
## 활성 청크를 이만큼 벗어나면 캐시에서 버린다 (지운 조우는 키로 남으므로 안전하다).
const CACHE_RADIUS := 3

var floor := 1
var required := SITE_COUNT
## 월드 좌표. 경계가 없다.
var avatar := Vector2.ZERO
## 지금 활성 청크들의 조우 — 월드 좌표. 순서는 청크 순서라 같은 자리에서는 안 흔들린다.
var sites: Array = []
var cleared := 0
var retreated := 0
var log_lines: Array = []

var _monsters: Variant = null
var _biomes: Variant = null
var _seed := 0
## 청크 → 조우 배열 캐시. 지운 상태가 여기 남는다 (재진입해도 유지).
var _chunk_sites: Dictionary = {}
## 지운 조우의 월드 키 — 캐시를 버려도 지워진 채로 되살아난다.
var _cleared_keys: Dictionary = {}
var _center := Vector2i.ZERO


func start(monsters: Variant, biomes: Variant, floor_value: int, seed_value: int = 0) -> void:
	_monsters = monsters
	_biomes = biomes
	floor = floor_value
	_seed = seed_value
	_chunk_sites.clear()
	_cleared_keys.clear()
	cleared = 0
	retreated = 0
	avatar = SPAWN
	log_lines = []
	_center = chunk_of(avatar)
	_refresh_sites()


static func chunk_of(point: Vector2) -> Vector2i:
	## 점이 속한 청크. 청크 (0,0) 이 x∈[-20,20)·y∈[-14,14) 라 **원점이 그 한가운데**다.
	return Vector2i(floori((point.x + CHUNK_WIDTH * 0.5) / CHUNK_WIDTH),
		floori((point.y + CHUNK_DEPTH * 0.5) / CHUNK_DEPTH))


static func chunk_origin(chunk: Vector2i) -> Vector2:
	## 청크의 남서 모서리 (월드 좌표).
	return Vector2(float(chunk.x) * CHUNK_WIDTH - CHUNK_WIDTH * 0.5,
		float(chunk.y) * CHUNK_DEPTH - CHUNK_DEPTH * 0.5)


func active_chunks() -> Array:
	## 지금 살아 있는 청크의 **남서 모서리**들. 뷰는 이 목록만 그린다.
	var out: Array = []
	for dz in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			var at := chunk_origin(_center + Vector2i(dx, dz))
			out.append(Vector3(at.x, 0.0, at.y))
	return out


func walk(direction: Vector2, seconds: float) -> Dictionary:
	## 방향(정규화 전)과 시간으로 이동한다. **경계 없음** — 청크를 넘으면 활성 목록만 갈린다.
	## 반환: `contact` = 지금 닿아 있는 조우 번호 (-1 이면 없음), `log` = 이번에 새로 적은 줄.
	avatar += direction.normalized() * WALK_SPEED * maxf(0.0, seconds)
	_rebase()
	var touched := contact_index()
	var lines: Array = []
	# 처음 닿은 조우만 적는다. 프레임마다 적으면 로그가 접촉으로 밀린다 (08 §4).
	if touched >= 0 and not bool(sites[touched].get("seen", false)):
		sites[touched]["seen"] = true
		var line := "접촉 — %s" % String(sites[touched].get("chain", ""))
		log_lines.append(line)
		lines.append(line)
	return {"contact": touched, "log": lines}


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
	## 접촉 반경 안에서 아직 안 지운 조우. 가장 가까운 것 하나만 돌려준다.
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
	var found := _record_all(heroes, "발견")
	var out := FonsFloorRun.simulate(rng, _monsters, _biomes, floor,
		int(sites[index].get("contact_index", 0)), heroes, max_turns)
	out["log"] = found + out["log"]
	log_lines.append_array(out["log"])
	if String(out["winner"]) == "ally":
		sites[index]["cleared"] = true
		_cleared_keys[String(sites[index]["key"])] = true
		cleared += 1
	return out


func retreat(heroes: Array = []) -> Dictionary:
	## 후퇴 — **탑(월드 원점)으로** 돌아간다. 지운 조우는 남는다 (D-265 "탐험 진행 유지").
	## 후퇴도 그 사람이 한 행동이라 기록한다 (09 §4-3).
	retreated += 1
	avatar = SPAWN
	_rebase()
	var lines := _record_all(heroes, "후퇴")
	log_lines.append_array(lines)
	return {"log": lines}


func mission_done() -> bool:
	return cleared >= required


func biome() -> Dictionary:
	## 이 층이 어느 세계인가 — 판정은 조우 편성과 같은 함수가 진다 (슬롯 → 층 범위 → {}).
	return FonsEncounter.biome_for_floor(_biomes, floor)


func tower_pos() -> Vector2:
	## 탑·소환진의 자리 — **월드 원점**. 청크 (0,0) 의 한가운데다.
	return Vector2.ZERO


func tower_mark() -> Dictionary:
	## 뷰가 읽는 탑 표 — 심은 메시를 모르고 자리와 반경만 준다.
	var at := tower_pos()
	return {"pos": Vector3(at.x, 0.0, at.y), "radius": TOWER_RADIUS, "body": TOWER_BODY}


func snapshot() -> Dictionary:
	## 뷰가 읽는 형식 — 엔티티 id 는 문자열, 위치는 `Vector3`(R2). 좌표는 전부 월드다.
	var marks: Array = []
	for i in sites.size():
		var s: Dictionary = sites[i]
		marks.append({
			"id": "site:%d" % i,
			"pos": Vector3(float(s["pos"].x), 0.0, float(s["pos"].y)),
			"cleared": bool(s["cleared"]),
			# 출현표 — 이 조우가 어느 사슬층인지. 편성과 같은 함수가 정한다 (08 §4).
			"chain": String(s.get("chain", "")),
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
		# `field` 는 이제 **청크 크기**다. 뷰는 이 크기로 타일을 뜬다.
		"field": Vector2(CHUNK_WIDTH, CHUNK_DEPTH),
		"chunks": active_chunks(),
		"tower": tower_mark(),
		"log": log_lines.slice(maxi(0, log_lines.size() - 6)),
	}


func _rebase() -> void:
	## 아바타가 새 청크로 넘어갔을 때만 다시 만든다 — 걷는 동안 매 프레임 목록을 새로 짜지 않는다.
	var now := chunk_of(avatar)
	if now == _center:
		return
	_center = now
	_refresh_sites()


func _refresh_sites() -> void:
	## 활성 청크의 조우를 한 줄로 펼친다. 청크 캐시는 안 버리면 무한히 자라므로 멀어진 것을 버린다.
	sites = []
	for dz in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			sites.append_array(_chunk_sites_of(_center + Vector2i(dx, dz)))
	_prune()


func _prune() -> void:
	for key in _chunk_sites.keys():
		var chunk: Vector2i = key
		if absi(chunk.x - _center.x) > CACHE_RADIUS or absi(chunk.y - _center.y) > CACHE_RADIUS:
			_chunk_sites.erase(key)


func _chunk_sites_of(chunk: Vector2i) -> Array:
	if _chunk_sites.has(chunk):
		return _chunk_sites[chunk]
	if FonsEncounter.is_combatless_biome(biome()):
		## 일반 조우가 없는 층(이데아 문턱 · #59) — 지우는 대상도 없으니 조우를 만들지 않는다.
		## 빈 편성으로 하나 띄우면 `fight` 가 승리 판정을 못 해 그 조우가 영원히 안 지워진다.
		_chunk_sites[chunk] = []
		return []
	var rng := RandomNumberGenerator.new()
	# 시드 = 층 + 청크 좌표. 같은 청크는 언제 돌아와도 같은 자리·같은 편성이다.
	rng.seed = _seed + floor * 7919 + chunk.x * 104729 + chunk.y * 15485863
	var origin := chunk_origin(chunk)
	var out: Array = []
	var guard := 0
	while out.size() < SITE_COUNT and guard < 32:
		guard += 1
		var local := Vector2(rng.randf_range(0.18, 0.82) * CHUNK_WIDTH,
			rng.randf_range(0.15, 0.85) * CHUNK_DEPTH)
		var at := origin + local
		if at.length() < TOWER_CLEAR:
			continue  # 탑 자리는 비운다
		var index := out.size()
		var key := "%d,%d,%d" % [chunk.x, chunk.y, index]
		# 편성을 미리 잡아 둔다 — 조우는 싸우기 전부터 어떤 사슬층인지 안다.
		# 전투(`FonsFloorRun`)도 **같은 함수·같은 접촉 번호**로 편성을 만들어 결과가 어긋나지 않는다.
		var party := FonsEncounter.build_party(_monsters, _biomes, floor, index)
		out.append({
			"pos": at,
			"chunk": chunk,
			"index": index,
			"contact_index": index,
			"key": key,
			"chain": FonsEncounter.chain_line(party),
			"seen": false,
			"cleared": _cleared_keys.has(key),
		})
	_chunk_sites[chunk] = out
	return out


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
