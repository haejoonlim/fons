class_name FonsBasicAttacks
extends RefCounted
## 직업별 기본 공격 102종 (34직업 × 3) — `data/basic_attacks.json`.
##
## 왜 직업별인가
## ------------
## 이전 전투는 맨손 한 가지(`attack_tag`)뿐이었다. 그래서 같은 스탯이면 34직업이
## **같은 손**으로 싸웠고, 직업 키워드 축은 스탯에만 붙고 행동에는 닿지 않았다.
## 원본 36차 재설계가 이 자리를 직업마다 세 갈래로 나눴다 — 공격 · 지원 · 제어.
##
## 쿨 표기
## --------
## 데이터 `cool` 은 **초**다 (원본 액션 쿨과 같은 단위). 전투는 턴으로 돌므로
## `FonsSkillEffect.cooldown_turns` 와 같은 2.5초/턴 환산을 쓴다. 최소 1턴.
##
## 위력
## ----
## `power` 는 행동 한 번의 피해 배율이다. 0 = 피해 없음(지원·제어), 1.0 = 맨손과 같다.
## 전투는 `skill_pct`(퍼센트 가산)를 쓰므로 `(power - 1) × 100` 으로 옮긴다.
## 지원·제어 중 치유·보호막·도발은 `FonsStatus` 가 실제 효과를 건다. 나머지 태그는
## 아직 기본 피해다 — 없는 상태 모델을 흉내내지 않는다.

const TURN_SECONDS := 2.5
const PER_JOB := 3
## 직업 id 가 없는 유닛(테스트 더미)은 무명자 풀을 쓴다 — 빈손으로 되돌리지 않는다.
const FALLBACK_JOB := "l1_nameless"


static func pool(data: Dictionary, job_id: String) -> Array:
	var jobs: Dictionary = data.get("jobs", data)
	if jobs.has(job_id):
		return jobs[job_id]
	return jobs.get(FALLBACK_JOB, [])


static func cooldown_turns(cool_seconds: float) -> int:
	return maxi(1, int(ceil(maxf(0.0, cool_seconds) / TURN_SECONDS)))


static func action(entry: Dictionary) -> Dictionary:
	var power := float(entry.get("power", 0.0))
	return {
		"id": String(entry.get("id", "")),
		"name": String(entry.get("name", "")),
		"tag": String(entry.get("tag", "")),
		"domain": String(entry.get("domain", "공격")),
		"pct": maxf(0.0, (power - 1.0) * 100.0),
		"cd": cooldown_turns(float(entry.get("cool", 0.0))),
		"left": 0,
	}


static func install(unit: Dictionary, data: Dictionary) -> void:
	## 유닛에 이 직업의 세 갈래를 붙인다. 사본을 넣는다 — 쿨타임은 유닛 상태다.
	if data.is_empty():
		return
	var out: Array = []
	for entry in pool(data, String(unit.get("job_id", ""))):
		out.append(action(entry))
	unit["basics"] = out


static func consume(unit: Dictionary, basic_id: String) -> float:
	## 고른 기본 공격의 쿨을 걸고 이번 행동의 피해 가산(%)을 돌려준다.
	for b in unit.get("basics", []):
		if String(b.get("id", "")) != basic_id:
			continue
		if int(b.get("left", 0)) > 0:
			return 0.0
		b["left"] = int(b.get("cd", 1))
		return float(b.get("pct", 0.0))
	return 0.0


static func tick(unit: Dictionary) -> void:
	for b in unit.get("basics", []):
		b["left"] = maxi(0, int(b.get("left", 0)) - 1)
