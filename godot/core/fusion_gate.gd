class_name FonsFusion
extends RefCounted
## 융합 심사 — 세 명의 심사자가 0.62 를 넘겨야 새 스킬이 태어난다 (GDD 09 §6).
##
##   0.4 × Rule + 0.35 × Neural Policy + 0.25 × JEV ≥ 0.62
##
## 세 심사자는 서로 다른 것을 본다 — 이 분리가 이 시스템의 전부다.
##   **Rule (0.40)**   딱 떨어지는 조건. **통과/탈락**이고 점수가 아니다 — 하나라도 어기면 후보가 지워진다
##                    (0.4 를 깎는 것과 후보를 지우는 것은 다르다).
##                    반복 증거 3회 · 두 부모 모두 각인 · 자식 레어도 = max+1 · 보유 32개 상한
##   **Neural (0.35)** 그 영웅의 손맛 — K(자란 스킬)와 R(최근 습관)의 합성. 처음 보는 조합은 점수를 못 받는다
##   **JEV (0.25)**    지금 이 세계인가 — 스킬의 문맥 태그(야간·다수적…)가 지금 상황과 맞는가,
##                    그리고 스토리 상태(`ctx.jev`, 0~1)가 뒤에서 밀어 주는가
##
## 왜 JEV 실패가 "탈락"이 아니라 "보류"인가:
##   플레이어가 이유를 알 수 없는 탈락은 그냥 버그로 보인다. 문맥이 안 맞으면 **미루고**,
##   맞는 밤·맞는 바이옴이 오면 그때 태어난다 (09 §6 "후속 생성으로 미룬다").
##
## 이름을 새로 만들지 않는 이유:
##   고유명사는 등록 없이 만들 수 없다 (AGENTS.md §1). 그래서 융합은 **이미 카탈로그에 있는**
##   자식 스킬을 "발견"한다 — 태그가 겹치고 레어도가 맞는 것 중 아직 없는 것.
##   `fusion_pairs.json` 117쌍은 이름 힌트로만 쓴다 (레거시 호환 — 09 v0.4).

const WEIGHT_RULE := 0.40
const WEIGHT_NEURAL := 0.35
const WEIGHT_JEV := 0.25
const THRESHOLD := 0.62
const MIN_EVIDENCE := 3
## 손맛 문턱 — 증거 3회만으로는 부족하고, 그 짝이 실제 버릇이어야 한다.
## 정본 0.62 식 위에 얹는 **가드**다 (09 §6 은 "Neural 이 낮으면 보류"만 적고 값을 정하지 않았다).
const NEURAL_FLOOR := 0.70

const CAP := 32
const JEV_NEUTRAL := 0.50
const JEV_MATCH := 1.00
const JEV_MISMATCH := 0.20


static func pair_key(a: String, b: String) -> String:
	## 연계 키는 **방향이 있다** (A→B ≠ B→A). 무엇을 먼저 했는지가 버릇이기 때문이다.
	return "%s|%s" % [a, b]


static func _name_of(brain, skill_id: String) -> String:
	if brain.book.has(skill_id):
		return String(brain.book[skill_id].get("name", skill_id))
	return skill_id


static func candidates(brain, catalog: Array) -> Array:
	## 지금 심사대에 오를 수 있는 연계 — 반복 증거가 3회 이상인 것만.
	## 정렬은 증거 내림차순, 같으면 키 오름차순 (결정론).
	var out: Array = []
	if brain == null:
		return out
	for key in brain.links:
		if int(brain.link_sessions.get(String(key), 0)) < MIN_EVIDENCE:
			continue
		var parts := String(key).split("|")
		if parts.size() != 2:
			continue
		out.append({"key": String(key), "a": parts[0], "b": parts[1],
			"evidence": int(brain.links[key])})
	out.sort_custom(func(x, y):
		if int(x["evidence"]) != int(y["evidence"]):
			return int(x["evidence"]) > int(y["evidence"])
		return String(x["key"]) < String(y["key"]))
	return out


static func skill_id_by_name(brain, name: String) -> String:
	for id in brain.book:
		if String(brain.book[id].get("name", "")) == name:
			return String(id)
	return ""


static func evaluate(pair: Dictionary, brain, ctx: Dictionary, catalog: Array,
		legacy_pairs: Array = []) -> Dictionary:
	## 한 연계를 심사한다. 반환은 항상 같은 모양이다 — `state` ∈ fuse / defer / reject.
	var a := String(pair.get("a", ""))
	var b := String(pair.get("b", ""))
	var id_a := skill_id_by_name(brain, a)
	var id_b := skill_id_by_name(brain, b)
	var out := {
		"key": String(pair.get("key", pair_key(a, b))), "a": a, "b": b,
		"evidence": int(pair.get("evidence", 0)),
		"state": "reject", "rule": 0.0, "neural": 0.0, "jev": 0.0, "total": 0.0,
		"child": "", "child_id": "", "reason": "",
	}

	# ── Rule — 탈락은 여기서 끝난다 ─────────────────────────────────────
	var reject := _rule_reject(brain, id_a, id_b, int(pair.get("evidence", 0)))
	if not reject.is_empty():
		out["reason"] = reject
		return out
	out["rule"] = 1.0

	var entry_a: Dictionary = brain.book[id_a]
	var entry_b: Dictionary = brain.book[id_b]
	var want_rarity := mini(6, maxi(int(entry_a.get("rarity", 1)), int(entry_b.get("rarity", 1))) + 1)
	var child := _pick_child(catalog, entry_a, entry_b, want_rarity, brain, legacy_pairs)
	if child.is_empty():
		out["reason"] = "자식 후보 없음 (레어도 %d · 태그 겹침 없음 · 이미 보유)" % want_rarity
		return out
	out["child"] = String(child.get("name", ""))
	out["child_id"] = str(child.get("id", ""))
	out["child_row"] = child

	# ── Neural Policy — 이 영웅이 원래 그렇게 싸워 왔는가 ────────────────
	out["neural"] = neural_score(brain, String(entry_a.get("name", "")), entry_a,
		String(entry_b.get("name", "")), entry_b)

	# ── JEV — 지금 이 세계인가 ─────────────────────────────────────────
	out["jev"] = jev_score(child, ctx)

	out["total"] = WEIGHT_RULE * float(out["rule"]) + WEIGHT_NEURAL * float(out["neural"]) \
		+ WEIGHT_JEV * float(out["jev"])

	if float(out["neural"]) < NEURAL_FLOOR:
		out["state"] = "defer"
		out["reason"] = "손맛 부족 — 이 조합을 아직 자주 쓰지 않는다 (neural %.2f)" % float(out["neural"])
		return out
	if float(out["jev"]) < 0.40:
		out["state"] = "defer"
		out["reason"] = "문맥 불일치 — 지금 상황이 아니다 (jev %.2f)" % float(out["jev"])
		return out
	if float(out["total"]) < THRESHOLD:
		out["state"] = "defer"
		out["reason"] = "합계 미달 (%.3f < %.2f) — 반복이 더 쌓이면 열린다" % [float(out["total"]), THRESHOLD]
		return out
	out["state"] = "fuse"
	return out


static func _rule_reject(brain, id_a: String, id_b: String, evidence: int) -> String:
	if brain == null:
		return "브레인 없음"
	if brain.book.size() >= mini(CAP, FonsSkillBook.growth_limit(int(brain.floor))):
		return "성장 예산 소진 (층당 상한)"
	if id_a.is_empty() or id_b.is_empty():
		return "부모가 아직 각인되지 않았다"
	if evidence < MIN_EVIDENCE:
		return "반복 증거 부족 (%d < %d)" % [evidence, MIN_EVIDENCE]
	# 지금도 번갈아 쓰고 있는가 — 한때 같이 썼던 기술은 "요즘 손에 붙은" 것이 아니다.
	# 이 조건이 없으면 40층만 올라가도 융합이 수십 번 터져 발견이 일상이 된다.
	if not (id_a in brain.recent_skills and id_b in brain.recent_skills):
		return "요즘 번갈아 쓰지 않는다 (최근 스킬 창 밖)"
	# 반복 증거는 **서로 다른 판 3회**다 (한 판에서 스무 번 번갈아 쓴 것은 1회).
	if int(brain.link_sessions.get(pair_key(_name_of(brain, id_a), _name_of(brain, id_b)), 0)) < MIN_EVIDENCE:
		return "여러 판에서 함께 쓴 적이 부족하다 (3판 미만)"
	return ""


static func _pick_child(catalog: Array, entry_a: Dictionary, entry_b: Dictionary,
		want_rarity: int, brain, legacy_pairs: Array) -> Dictionary:
	## 자식 = 카탈로그에서 **레어도가 맞고 부모 태그와 겹치며 아직 없는** 스킬.
	## 겹침이 큰 것 → id 가 작은 것 순 (결정론). 레거시 쌍에 이름 힌트가 있으면 그 이름을 먼저 본다.
	var tags: Array = []
	for t in entry_a.get("tags", []):
		tags.append(String(t))
	for t in entry_b.get("tags", []):
		if not String(t) in tags:
			tags.append(String(t))
	var hinted := _hint_name(legacy_pairs, String(entry_a.get("name", "")), String(entry_b.get("name", "")))
	var best: Dictionary = {}
	var best_score := -1
	for skill in catalog:
		if int(skill.get("rarity", 0)) != want_rarity:
			continue
		var id := str(skill.get("id", ""))
		if brain.book.has(id) or id in brain.fusions:
			continue
		var overlap := 0
		for t in skill.get("tags", []):
			if String(t) in tags:
				overlap += 1
		if overlap <= 0:
			continue
		var s := overlap
		if not hinted.is_empty() and String(skill.get("name", "")) == hinted:
			s += 10
		if s > best_score or (s == best_score and str(skill.get("id", "")) < str(best.get("id", ""))):
			best_score = s
			best = skill
	return best


static func _hint_name(legacy_pairs: Array, a: String, b: String) -> String:
	for pair in legacy_pairs:
		var p1 := String(pair.get("parent1", ""))
		var p2 := String(pair.get("parent2", ""))
		if (p1 == a and p2 == b) or (p1 == b and p2 == a):
			return String(pair.get("child_name", ""))
	return ""


static func neural_score(brain, name_a: String, entry_a: Dictionary,
		name_b: String, entry_b: Dictionary) -> float:
	## Neural Policy — "이 사람이 그 두 기술을 **습관처럼** 이어 쓰는가".
	##   K_norm    = (K − 1) / 0.5  — 자란 기술일수록 손에 붙어 있다
	##   pair_norm = A→B가 A의 **모든 연계 중 차지하는 비중** ×2 (절반 이상이면 포화)
	##   R_norm    = 두 기술 태그가 최근 창에서 차지하는 비중
	##   evidence  = A→B 반복 세션 / 10
	##
	## 왜 '그 태그를 많이 썼다'만으로는 부족한가:
	##   태그 비중만 보면 같은 태그를 쓰는 **아무 기술 조합**이나 습관으로 인정된다.
	##   사람의 버릇은 "A를 쓰면 B"라는 **방향 있는 짝**이다 — 그 비중을 절반 가까이 넣는다.
	var k := 0.0
	for t in entry_a.get("tags", []):
		k = maxf(k, FonsSkillBook.factor(brain.book, String(t)))
	for t in entry_b.get("tags", []):
		k = maxf(k, FonsSkillBook.factor(brain.book, String(t)))
	var k_norm := clampf((k - 1.0) / 0.5, 0.0, 1.0)
	var pair_norm := clampf(_pair_rate(brain, name_a, name_b) * 2.0, 0.0, 1.0)
	var r_norm := 0.0
	var n := 0
	for t in entry_a.get("tags", []):
		r_norm += brain.tag_share(String(t))
		n += 1
	for t in entry_b.get("tags", []):
		r_norm += brain.tag_share(String(t))
		n += 1
	if n > 0:
		r_norm = r_norm / float(n)
	r_norm = clampf(r_norm * 2.0, 0.0, 1.0)
	var evidence := clampf(float(int(brain.links.get(pair_key(name_a, name_b), 0))) / 10.0, 0.0, 1.0)
	return clampf(0.25 * k_norm + 0.45 * pair_norm + 0.15 * r_norm + 0.15 * evidence, 0.0, 1.0)


static func _pair_rate(brain, name_a: String, name_b: String) -> float:
	## A 다음에 B가 나온 세션 수 ÷ A 다음에 **무엇이든** 나온 세션 수.
	## 3판 중 3번 B면 1.0, 10가지 기술로 흩어지면 0.1 — "버릇"의 강도다.
	var pair := int(brain.link_sessions.get(pair_key(name_a, name_b), 0))
	var from_a := 0
	var prefix := name_a + "|"
	for key in brain.link_sessions:
		if String(key).begins_with(prefix):
			from_a += int(brain.link_sessions[key])
	if from_a <= 0:
		return 0.0
	return float(pair) / float(from_a)


static func place_context(biomes: Variant, floor: int) -> Dictionary:
	## 지금 발을 딛고 있는 세계 — JEV 의 절반은 "어느 바이옴인가"다 (09 §6 스토리 조건).
	## 바이옴 데이터의 `habitat`·`category` 만 읽어 문맥 태그로 옮긴다. 새 이름을 만들지 않는다.
	## (게이트키퍼층은 보스급, 어둠 바이옴은 야간, 숲·동굴은 장애물, 물가는 수중 …)
	## 여기서 정한 것은 **번역**이지 수치가 아니다 — 수치는 여전히 09 §6 의 0.62 다.
	var biome := FonsEncounter.biome_for_floor(biomes, floor)
	var out := {
		"floor": floor,
		"biome": String(biome.get("id", "")),
		"category": String(biome.get("category", "")),
	}
	var habitat: Array = biome.get("habitat", [])
	if String(biome.get("category", "")) == "waterside" or _any(habitat,
			["ocean", "coral", "deep_ocean", "trench", "river", "swamp", "frostsea"]):
		out["water"] = true
	if _any(habitat, ["forest", "jungle", "cave", "mine", "underground", "ruins", "dungeon"]):
		out["obstacle"] = true
	if _any(habitat, ["cave", "mine", "underground", "sewer", "trench"]):
		out["narrow"] = true
	if _any(habitat, ["sky", "storm", "astral", "skylapse"]):
		out["air"] = true
	if String(biome.get("category", "")) == "dark":
		out["night"] = true
	if floor in FonsEncounter.GATEKEEPER_FLOORS:
		out["boss"] = true
	return out


static func _any(have: Array, want: Array) -> bool:
	for value in want:
		if value in have:
			return true
	return false


static func jev_score(child: Dictionary, ctx: Dictionary) -> float:
	## JEV — 스킬의 문맥 태그가 지금 상황과 맞는가 + 스토리 상태.
	## 문맥이 없는 스킬은 중립(0.5)이다 — 어디서나 쓸 수 있는 기술이니 막지도 밀지도 않는다.
	var context := String(child.get("context", ""))
	var score := JEV_NEUTRAL
	if not context.is_empty():
		score = JEV_MATCH if _context_live(context, ctx) else JEV_MISMATCH
	var story := clampf(float(ctx.get("jev", JEV_NEUTRAL)), 0.0, 1.0)
	return clampf(0.7 * score + 0.3 * story, 0.0, 1.0)


static func _context_live(context: String, ctx: Dictionary) -> bool:
	## 문맥 태그 13종 → 지금 상황. 브레인이 세는 것과 같은 이름을 쓴다.
	var map := {"야간": "night", "다수적": "crowd", "장애물": "obstacle",
		"아군부상": "ally_hurt", "적저체력": "enemy_low", "자기저체력": "self_low",
		"공중": "air", "수중": "water", "협소": "narrow", "장거리": "ranged",
		"밀착": "close", "무리생물": "pack", "보스급": "boss"}
	return bool(ctx.get(String(map.get(context, "")), false))


static func run_for_party(heroes: Array, ctx: Dictionary, catalog: Array,
		legacy_pairs: Array = []) -> Array:
	## 한 판이 끝난 뒤 파티 전원의 연계를 심사한다. 반환: `[{name, hero}]` — 로그·표시용.
	## 심사는 **부수효과가 없다** — 통과한 것만 적용된다 (보류는 아무 일도 안 일어난다).
	var born: Array = []
	for hero in heroes:
		if not FonsBrain.attached(hero):
			continue
		var brain = hero["brain"]
		# 한 판에 한 번만 — "발견의 순간"이 매 턴 오면 발견이 아니다.
		for pair in candidates(brain, catalog):
			var verdict := evaluate(pair, brain, ctx, catalog, legacy_pairs)
			if String(verdict["state"]) != "fuse":
				continue
			if apply(brain, verdict):
				brain.sync_unit(hero)
				born.append({"hero": String(hero.get("name", "?")), "name": String(verdict["child"])})
				break
	return born


static func apply(brain, verdict: Dictionary) -> bool:
	## 심사를 통과한 스킬을 영웅의 손에 넣는다. 부모는 사라지지 않는다 (09 §6 리스크 완화).
	if String(verdict.get("state", "")) != "fuse":
		return false
	var id := String(verdict.get("child_id", ""))
	if id.is_empty():
		return false
	var row: Dictionary = verdict.get("child_row", {})
	brain.book[id] = {
		"name": String(verdict.get("child", "")),
		"rarity": int(row.get("rarity", 1)),
		"domain": String(row.get("domain", "")),
		"tags": row.get("tags", []),
		"context": String(row.get("context", "")),
		"effect_kind": String(row.get("effect_kind", "")),
		"effect_base": float(row.get("effect_base", 0.0)),
		"cool_base": float(row.get("cool_base", 0.0)),
		"stage": 1, "level": 1, "xp": 0, "fused": true,
	}
	brain.fusions.append(id)
	return true
