class_name FonsBrain
extends RefCounted
## 영웅 한 명의 **판단**. 명령을 기다리는 말이 아니라 "이 사람은 이렇게 행동한다"를 계산한다.
##
## 정본 식 (GDD 09 §4-1)
## -------------------
##   Score(a) = B × S × M(성격) × A(적성) × K(스킬) × C(문맥) × R(습관) × J(직업) × Kw × X + ε
##
## 이 파일이 실제로 계산하는 항
##   B   1.0 — 역할 일치 가중은 J 가 이미 진다 (두 번 걸지 않는다)
##   S   행동 스탯 ÷ 파티 평균, 0.8~1.2 로 자름 (스탯이 판단을 지배하지 않게)
##   M   `FonsPersonality.domain_mult` — 메인 편차 × 기질 × 부가 2종
##   A   `apt_eff[적성]` — **생활 태그만**. 전투 태그는 1.0 (09 §4-1-1)
##   K   `FonsSkillBook.factor` — 자란 스킬이 그 행동을 더 좋아하게 만든다
##   C   문맥 — 저체력·아군부상·적 다수·적 저체력·야간
##   R   습관 — 최근 10행동 중 같은 태그 비중 × 기질 habit, + 연속 반복 피로
##   J   `job_ai_profiles` 도메인 가중 × favored_tags 1.10 × banned_tags 0
##   P   연습 열기 — `FonsSkillBook.heat_bias` (쓴 기술 +최대 15% 선택 가중). 정본에 없는 가안
##   Kw  **1.0** — 데이터에 `keyword_tags` 가 없다. 없는 값을 지어내지 않는다
##   X   1.0 — 소환수 없음
##   ε   개체 시드 ±10% — novelty 다이얼이 폭을 키운다 (같은 개체는 같은 성향)
##
## "사람처럼" 만드는 네 장치 (09 §4-2) — 전부 여기 있다
##   ① 성격 3키워드가 도메인 취향을 가른다 (M)          ② 개체 시드 노이즈 (ε)
##   ③ 습관이 굳는다 (R + 링 버퍼)                       ④ 문맥마다 같은 사람이 다르게 군다 (C)
## 그리고 선택은 **소프트맥스**다. 늘 최고점만 고르면 사람이 아니라 계산기다 —
## 대개는 제일 좋아하는 것을 고르되, 가끔 두 번째를 고른다 (온도 = novelty).
##
## 저장: 카운터·링 버퍼·스킬북·연계 카운트뿐이다 (원칙 3 — 원시 로그 없음).

const RING := 10              ## 습관 판정 창 (최근 N행동)
const SKILL_RING := 8         ## 융합 판정 창 (최근 N스킬)
const NOISE := 0.10           ## ε 기본 폭 ±10%
const STAT_MIN := 0.80
const STAT_MAX := 1.20
const FATIGUE_FROM := 4       ## 같은 태그 4연속부터 지루해진다
const FATIGUE_STEP := 0.04
const FATIGUE_FLOOR := 0.85
const BASE_TEMP := 0.10

var identity: Dictionary = {}
var data: Dictionary = {}
var job_profile: Dictionary = {}
var role := ""
var catalog_by_id: Dictionary = {}
var apt: Dictionary = {}

var counters: Dictionary = {}     ## 행동 태그 + 문맥 태그 → 횟수 (09 §4-3)
var recent: Array = []            ## 최근 태그 링 버퍼
var recent_skills: Array = []     ## 최근 스킬 id 링 버퍼 — 융합의 "요즘 번갈아 쓰는가" (09 §6)
var book: Dictionary = {}         ## 스킬 id → {stage, level, xp, ...}
var links: Dictionary = {}        ## "A|B" → 이어 쓴 횟수 (스킬 이름 기준)
var link_sessions: Dictionary = {} ## "A|B" → **서로 다른 판**에서 함께 쓴 횟수 (융합의 반복 증거)
var floor := 1                    ## 지금 판의 층 — 세션 경계 (같은 판 안의 반복은 한 번으로 센다)
var _link_floor: Dictionary = {}
var born: Array = []              ## 각인된 스킬 이름 (로그)
var fusions: Array = []           ## 융합으로 얻은 스킬 id
var last_tag := ""
var last_skill := ""              ## 직전에 쓴 스킬 id — 연계는 **스킬과 스킬 사이**다 (09 §6)
var streak := 0                   ## 같은 태그 연속 횟수
var decisions := {}               ## 태그 → 고른 횟수 (개체 성향 계측용)

var _rng := RandomNumberGenerator.new()


func setup(identity_value: Dictionary, data_value: Dictionary, job: Dictionary,
		role_value: String, catalog: Array, seed_value: int = 0) -> void:
	identity = identity_value
	data = data_value
	job_profile = job
	role = role_value
	catalog_by_id = FonsSkillBook.by_id(catalog)
	_rng.seed = seed_value
	if seed_value == 0:
		_rng.seed = int(identity.get("seed", 1))
	if FonsPersonality.is_ready(data):
		apt = FonsPersonality.apt_eff(data, identity, _rng, 5)


func is_ready() -> bool:
	return not identity.is_empty() and FonsPersonality.is_ready(data)


static func attached(unit: Dictionary) -> bool:
	return unit.get("brain", null) is FonsBrain


static func record_action(unit: Dictionary, action_name: String) -> Dictionary:
	## 행동 이름 하나를 그 영웅의 기록으로 남긴다 — 전투·탐험·영지가 **같은 문**을 쓴다.
	## 브레인이 붙은 영웅은 카운터와 각인 판정까지 가고(09 §4-3), 없으면 유닛 태그 거울만 오른다.
	## 반환: `{tags, born}` — 부르는 쪽이 "새 기술"을 로그에 남길 수 있게.
	var names := FonsActionTags.tags_for(action_name)
	if names.is_empty():
		return {"tags": [], "born": []}
	var born: Array = []
	if attached(unit):
		var brain: FonsBrain = unit["brain"]
		var seen := brain.commit({"action": action_name, "tag": String(names[0]),
			"tags": names.slice(1)})
		born = seen.get("born", [])
		brain.mirror(unit)
	else:
		FonsActionTags.record(unit, action_name)
	return {"tags": names, "born": born}


static func attach(unit: Dictionary, identity_value: Dictionary, data_value: Dictionary,
		job: Dictionary, role_value: String, catalog: Array, seed_value: int = 0) -> FonsBrain:
	## 유닛에 판단을 붙인다. 이미 있으면 그대로 돌려준다 (재부착 금지 — 카운터가 날아간다).
	if attached(unit):
		return unit["brain"]
	var b := FonsBrain.new()
	b.setup(identity_value, data_value, job, role_value, catalog, seed_value)
	unit["brain"] = b
	unit["personality"] = identity_value.get("main", "")
	unit["traits"] = identity_value.get("subs", [])
	return b


## ── 점수 ────────────────────────────────────────────────────────────────

func score(action: Dictionary, ctx: Dictionary) -> Dictionary:
	## 한 후보의 점수와 **항별 내역**. 내역을 돌려주는 이유: 밸런스 도구가 "왜 이 선택인가"를
	## 설명할 수 있어야 한다 (숫자만 남으면 조정할 때 어느 항을 만질지 모른다).
	var tag := String(action.get("tag", ""))
	var domain := String(action.get("domain", ""))
	var breakdown := {
		"B": 1.0, "S": _stat_factor(action, ctx), "M": 1.0, "A": 1.0,
		"K": 1.0, "C": 1.0, "R": 1.0, "J": 1.0, "P": 1.0, "noise": 1.0,
	}
	# P — 연습 열기. 기술 후보만 bias 를 싣고, 맨손·생활 행동은 1.0 이다.
	breakdown["P"] = clampf(float(action.get("bias", 1.0)), 0.0, 2.0)
	breakdown["M"] = FonsPersonality.domain_mult(data, identity, domain)
	breakdown["A"] = _apt_factor(action)
	breakdown["K"] = _skill_factor(action, tag)
	breakdown["C"] = context_factor(tag, ctx) * _target_factor(action, ctx)
	breakdown["R"] = routine_factor(tag)
	breakdown["J"] = job_factor(tag, domain)
	var value := 1.0
	for key in ["B", "S", "M", "A", "K", "C", "R", "J", "P"]:
		value *= float(breakdown[key])
	breakdown["noise"] = 1.0 + _noise()
	value *= float(breakdown["noise"])
	breakdown["total"] = value
	return breakdown


func _stat_factor(action: Dictionary, ctx: Dictionary) -> float:
	var stat := String(action.get("stat", ""))
	if stat.is_empty():
		return 1.0
	var mine := float(action.get("stat_value", 0.0))
	var avg := float(ctx.get("party_avg", {}).get(stat, 0.0))
	if mine <= 0.0 or avg <= 0.0:
		return 1.0
	return clampf(mine / avg, STAT_MIN, STAT_MAX)


func _skill_factor(action: Dictionary, tag: String) -> float:
	## K항 — **이번에 쓸 기술**이 자랐으면 그만큼 좋아한다 (자기강화 루프).
	## 기술이 정해지지 않은 맨손 행동은 그 태그를 쓰는 기술들의 단계 합을 본다.
	var id := String(action.get("skill_id", ""))
	if not id.is_empty() and book.has(id):
		return 1.0 + FonsSkillBook.K_STEP * float(int(book[id].get("stage", 1)))
	return FonsSkillBook.factor(book, tag)


func _apt_factor(action: Dictionary) -> float:
	## A항 — 생활 태그만 적성 효율을 쓴다. 전투는 1.0 (적성은 생활 전용 — 05 §6).
	if FonsActionTags.COMBAT_TAGS.has(String(action.get("tag", ""))):
		return 1.0
	var apt_name := String(action.get("apt", ""))
	if apt_name.is_empty():
		return 1.0
	return float(apt.get(apt_name, 1.0))


func _target_factor(action: Dictionary, ctx: Dictionary) -> float:
	## 대상 취향 — 사람은 "약한 놈 마무리"와 "센 놈 먼저" 사이에서 성격대로 기운다.
	## risk 가 높으면 마무리 쪽, 낮으면 위협 제거 쪽. 폭은 ±10% 로 작게 둔다 (판단을 지배하지 않게).
	var risk := FonsPersonality.dial(data, identity, "risk")
	var mul := 1.0
	if bool(action.get("low_hp", false)):
		mul *= 1.0 + 0.25 * (risk - 1.0)
	if bool(action.get("high_threat", false)):
		mul *= 1.0 + 0.20 * (1.0 - risk)
	if bool(ctx.get("boss", false)):
		mul *= 1.0 + 0.10 * (risk - 1.0)
	return mul


func context_factor(tag: String, ctx: Dictionary) -> float:
	## 문맥 13종 중 지금 계산할 수 있는 다섯 — 09 §4-1 C항.
	## 값은 GDD 예시(아군부상 치유 ×2 · 적 다수 광역 ×1.5 · 자기 저체력 후퇴 ×2)를 그대로 쓴다.
	var mul := 1.0
	var hp := float(ctx.get("hp_ratio", 1.0))
	var risk := FonsPersonality.dial(data, identity, "risk")
	var care := FonsPersonality.dial(data, identity, "care")
	if hp < 0.35 and tag in ["후퇴", "방어태세", "휴식"]:
		# 소심한 사람은 더 일찍 물러나고, 격정·난폭은 늦게 물러난다 (기질이 임계를 옮긴다).
		mul *= 2.0 / risk
	if bool(ctx.get("ally_hurt", false)) and tag in ["치유", "보호막", "아군보호"]:
		mul *= 2.0 * care * 0.5 + 1.0   # care 1.35 → ×2.35 · 0.85 → ×1.85 (기질이 폭을 정한다)
	if int(ctx.get("enemy_count", 0)) >= 3 and tag == "광역살포":
		mul *= 1.5
	if bool(ctx.get("enemy_low", false)) and tag in ["약점타격", "관통공격"]:
		mul *= 1.3
	if bool(ctx.get("night", false)) and tag in ["매복", "잠행", "은신"]:
		mul *= 1.3
	return mul


func routine_factor(tag: String) -> float:
	## R항 — "이 애는 매번 먼저 정찰하는 애" 를 만드는 항.
	## 최근 창 안의 비중이 높을수록 좋아하고, 4연속부터는 지루해진다 (사람은 같은 것만 못 한다).
	if recent.is_empty():
		return 1.0
	var hits := 0
	for t in recent:
		if String(t) == tag:
			hits += 1
	var share := float(hits) / float(recent.size())
	var habit := FonsPersonality.dial(data, identity, "habit")
	var mul := 1.0 + 0.15 * share * habit
	if tag == last_tag and streak >= FATIGUE_FROM:
		mul *= maxf(FATIGUE_FLOOR, 1.0 - FATIGUE_STEP * float(streak - FATIGUE_FROM + 1))
	return mul


func job_factor(tag: String, domain: String) -> float:
	## J항 — 직업이 좋아하는 도메인. favored_tags 는 +10%, banned_tags 는 **0** (성향 차단).
	var domains: Dictionary = job_profile.get("domains", {})
	var mul := float(domains.get(domain, 1.0))
	if String(tag) in job_profile.get("favored_tags", []):
		mul *= 1.10
	if String(tag) in job_profile.get("banned_tags", []):
		mul = 0.0
	return mul


func _noise() -> float:
	## ε — 개체 고유 노이즈. 같은 시드·같은 상황이면 같은 개체는 같은 쪽으로 기운다.
	## novelty 기질이 높으면 폭이 넓다 (낭만·교활은 변덕스럽고, 고집·성실은 일정하다).
	var novelty := FonsPersonality.dial(data, identity, "novelty")
	return (_rng.randf() * 2.0 - 1.0) * NOISE * novelty


## ── 선택 ────────────────────────────────────────────────────────────────

func temperature() -> float:
	## 소프트맥스 온도. 낮으면 계산기(늘 최고점), 높으면 즉흥.
	return BASE_TEMP * FonsPersonality.dial(data, identity, "novelty")


func decide(candidates: Array, ctx: Dictionary) -> Dictionary:
	## 후보 중 하나를 고른다. 반환: 후보 + `breakdown`.
	## 후보가 없으면 빈 Dictionary — 부르는 쪽이 "할 일이 없다"를 구분할 수 있어야 한다.
	var scored: Array = []
	for action in candidates:
		var row: Dictionary = action.duplicate()
		row["breakdown"] = score(action, ctx)
		scored.append(row)
	if scored.is_empty():
		return {}
	# 소프트맥스 — 지수 폭주를 막으려 최고점을 뺀다 (softmax 불변성).
	var top := -INF
	for row in scored:
		top = maxf(top, float(row["breakdown"]["total"]))
	var temp := maxf(0.02, temperature())
	var weights: Array = []
	var total := 0.0
	for row in scored:
		var w := exp((float(row["breakdown"]["total"]) - top) / temp)
		weights.append(w)
		total += w
	var point := _rng.randf() * total
	var acc := 0.0
	for i in scored.size():
		acc += float(weights[i])
		if point <= acc:
			return scored[i]
	return scored[scored.size() - 1]


func commit(action: Dictionary) -> Dictionary:
	## 고른 행동을 **기록**한다. 반환: 이번에 오른 태그 · 새로 각인된 스킬.
	## 카운터는 브레인이 정본이고 유닛의 `tags` 는 같은 값의 거울이다 (예전 도구가 읽는다).
	var tags: Array = []
	var tag := String(action.get("tag", ""))
	if not tag.is_empty():
		tags.append(tag)
		counters[tag] = int(counters.get(tag, 0)) + 1
		_push_recent(tag)
		track_decision(tag)
	var extra: Array = action.get("tags", [])
	for t in extra:
		var name := String(t)
		if name.is_empty() or name == tag:
			continue
		tags.append(name)
		counters[name] = int(counters.get(name, 0)) + 1
	var skill_id := String(action.get("skill_id", ""))
	if not skill_id.is_empty() and book.has(skill_id):
		FonsSkillBook.add_use(book, skill_id)
		link_skills(last_skill, skill_id)
		last_skill = skill_id
		recent_skills.append(skill_id)
		while recent_skills.size() > SKILL_RING:
			recent_skills.pop_front()
	var born_now := FonsSkillBook.try_engrave(book, counters, catalog_by_id.values(), _rng,
		FonsSkillBook.ENGRAVE_CHANCE, _domain_weights(), floor)
	born.append_array(born_now)
	return {"tags": tags, "born": born_now}


func track_decision(tag: String) -> void:
	decisions[tag] = int(decisions.get(tag, 0)) + 1


func link_skills(previous: String, current: String) -> void:
	## 연계 증거 — **스킬 A 다음에 스킬 B** 를 쓴 횟수. 융합 Rule 의 "같은 연계 3회"가 이 값이다 (09 §6).
	## 태그가 아니라 스킬인 이유: 융합은 "행동 두 개"가 아니라 "기술 두 개" 사이에서 태어난다.
	if previous.is_empty() or current.is_empty() or previous == current:
		return
	var key := "%s|%s" % [_name_of(previous), _name_of(current)]
	links[key] = int(links.get(key, 0)) + 1
	# 반복 증거는 **판 단위**다. 한 판에서 스무 번 번갈아 쓴 것은 "3번 반복"이 아니다 —
	# GDD 09 §6 의 3회는 서로 다른 전투에서 세 번이라는 뜻으로 읽는다 (한 판 = 한 세션).
	if int(_link_floor.get(key, -999)) != floor:
		_link_floor[key] = floor
		link_sessions[key] = int(link_sessions.get(key, 0)) + 1


func _name_of(skill_id: String) -> String:
	if book.has(skill_id):
		return String(book[skill_id].get("name", skill_id))
	return skill_id


func _domain_weights() -> Dictionary:
	## 각인 후보 정렬용 — 그 영웅이 좋아하는 도메인의 기술을 먼저 깨우친다.
	var out := {}
	for domain in FonsPersonality.DOMAINS:
		out[domain] = FonsPersonality.domain_mult(data, identity, domain)
	return out


func _push_recent(tag: String) -> void:
	streak = streak + 1 if tag == last_tag else 1
	last_tag = tag
	recent.append(tag)
	while recent.size() > RING:
		recent.pop_front()


func note_context(ctx: Dictionary) -> void:
	## 문맥 태그 13종을 센다. 스킬 조건 어휘지만 **각인 합계에는 들어간다**
	## (L 은 태그 910 + 문맥 26 = 936 — 09 §5).
	var pairs := {"night": "야간", "crowd": "다수적", "obstacle": "장애물",
		"ally_hurt": "아군부상", "enemy_low": "적저체력", "self_low": "자기저체력",
		"boss": "보스급", "ranged": "장거리", "close": "밀착", "water": "수중"}
	for key in pairs:
		if bool(ctx.get(key, false)):
			var tag := String(pairs[key])
			counters[tag] = int(counters.get(tag, 0)) + 1
	note_text_total()


func note_text_total() -> void:
	## 각인 판정은 `counters` 합계를 본다 — 여기서는 아무것도 하지 않는다(가독성용 훅).
	pass


func mirror(unit: Dictionary) -> void:
	## 브레인 카운터 → 유닛 `tags` 거울. 예전 도구(`FonsActionTags.count`)가 같은 숫자를 본다.
	unit["tags"] = counters.duplicate()


func sync_unit(unit: Dictionary) -> void:
	## 각인된 스킬을 유닛의 전투 목록에 올린다 — "스킬 = 행동 언락" (09 §4-2 장치 1).
	## 이미 올라온 id 는 건드리지 않는다 (쿨타임은 유닛 상태다).
	if book.is_empty():
		return
	if not unit.has("skills"):
		unit["skills"] = []
	var have := {}
	for s in unit["skills"]:
		var sid := String(s.get("id", ""))
		have[sid] = true
		if book.has(sid):
			s["heat"] = float(book[sid].get("heat", 0.0))
	for id in book:
		if have.has(String(id)):
			continue
		var entry: Dictionary = book[id]
		if float(entry.get("cool_base", 0.0)) <= 0.0:
			continue
		var skill := {"effect_kind": entry.get("effect_kind", ""), "effect_base": entry.get("effect_base", 0.0),
			"cool_base": entry.get("cool_base", 0.0)}
		if not FonsSkillEffect.is_combat_skill(skill):
			continue
		unit["skills"].append({
			"id": String(id),
			"name": String(entry.get("name", "")),
			"tags": entry.get("tags", []),
			"domain": String(entry.get("domain", "공격")),
			"pct": FonsSkillEffect.effect_pct(skill, int(entry.get("stage", 1)), int(entry.get("level", 1))),
			"cd": FonsSkillEffect.cooldown_turns(skill, int(entry.get("stage", 1))),
			"left": 0,
			"heat": float(entry.get("heat", 0.0)),
		})
		have[String(id)] = true


func tag_share(tag: String) -> float:
	var hits := 0
	for t in recent:
		if String(t) == tag:
			hits += 1
	return float(hits) / float(maxi(1, recent.size()))


func describe() -> String:
	## 사람이 읽는 요약 — "난폭 · 다정·탐욕 — 근접타격 41 · 정찰 12 · 스킬 1".
	var head := FonsPersonality.describe(data, identity)
	var top_tag := ""
	var top_n := 0
	for tag in counters:
		if int(counters[tag]) > top_n:
			top_n = int(counters[tag])
			top_tag = String(tag)
	return "%s — %s %d · 스킬 %d · 연계 %d" % [head, top_tag, top_n, book.size(), links.size()]
