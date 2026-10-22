class_name FonsJobCoef
extends RefCounted
## 직업계수 — 05 §4 표를 현행 7직업 트리에 붙인 것. 정본은 `data/job_coef.json`.
##
## 왜 표를 데이터로 옮겼나:
##   05 §4 의 원표는 13직업(구 트리) 기준이라 현행 `job_tree.json`(L1 7 · L2 26)과 1:1 이 아니다.
##   대응은 `sim/center/sims/gen_job_coef.py` 가 만든다 — L2 계수는 `gacha_test.JOB_COEF_L2`,
##   L1 계수는 `gacha_test.JOB_COEF` 에서 집는다. 두 표의 키가 이름이라 매칭도 이름으로 하고,
##   이름이 없는 자리(무명자·티어 미지정)만 `fallbacks` 에 이유를 적는다. 손으로 잇지 않는다.
##
## 두 겹의 배율:
##   `coef`  7축(HP·ATK·DEF·ASPD·MAG·MDEF·CRI) — 개별 직업값
##   `tier`  전직 난이도 A/B/C → **6축**(CRI 제외)에 √티어. 원본 `apply_tier_to_stats` 와 같은 축 집합이다.
##   두 번 곱하는 이유는 원본이 그렇게 하기 때문이다 — 계수표 값은 티어 이전 값이고,
##   전직 1스텝이 √티어를 한 번 더 건다 (05 §8-1 · 확정 #39 계열).
##
## 없는 직업은 **중립 1.0** 이다. 0 이 아니다 — 빠진 id 로 영웅이 사라지면 그게 더 나쁘다.

const AXES := ["HP", "ATK", "DEF", "ASPD", "MAG", "MDEF", "CRI"]
## 전직 티어가 걸리는 축 — CRI 는 비율 축이라 제외한다 (`gacha_test.apply_tier_to_stats`).
const TIER_AXES := ["HP", "ATK", "DEF", "ASPD", "MAG", "MDEF"]


static func row_of(table: Dictionary, job_id: String) -> Dictionary:
	## L1 · L2 어느 쪽에 있든 그 행을 돌려준다. 없으면 빈 사전.
	for key in ["l1", "l2"]:
		var group: Dictionary = table.get(key, {})
		if group.has(job_id):
			return group[job_id]
	return {}


static func multipliers(table: Dictionary, job_id: String) -> Dictionary:
	## 7축 배율 (티어 √ 포함). `FonsHeroStats.field_stats` 의 `job_mod` 인자로 그대로 넘긴다.
	var out := {}
	for axis in AXES:
		out[axis] = 1.0
	var row := row_of(table, job_id)
	if row.is_empty():
		return out
	var root := 1.0
	if row.has("tier"):
		var tier_mul: Dictionary = table.get("tierMul", {})
		root = sqrt(float(tier_mul.get(String(row["tier"]), 1.0)))
	var coef: Array = row.get("coef", [])
	var scaled := row.has("tier")
	for i in AXES.size():
		var axis: String = AXES[i]
		var v: float = float(coef[i]) if i < coef.size() else 1.0
		out[axis] = v * root if scaled and TIER_AXES.has(axis) else v
	return out


static func has_job(table: Dictionary, job_id: String) -> bool:
	return not row_of(table, job_id).is_empty()
