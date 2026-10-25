class_name FonsSave
extends RefCounted
## 세이브 형식 — 사전만 받고 사전만 낸다. 파일·씬·노드를 모른다 (ADR 0008 · 설계 §3).
##
## 층은 셋이다 (ADR 0008):
##   입력      실행 시드 · 등급 · 레벨 · 시작 층   → 같은 시드면 같은 영웅이 다시 나온다
##   변한 것   층 · HP/생존 · 각인·XP·연계 · 지갑 · 영지 저장분   → 다시 만들 수 없다
##   파생      최종 스탯 · 전투 유닛 · 조우 편성 · 로그   → **넣지 않는다**
##
## 판 중간은 저장하지 않는다. 반쯤 진행한 턴을 복원하면 난수 순서가 어긋나 같은 판이 아니게 된다.

const SCHEMA := 1
## 이 빌드가 아는 최상위 키. 화이트리스트 검사가 이 목록을 쓴다.
const TOP_KEYS := ["schema", "saved_at", "data_manifest", "run", "wallet", "estate"]
const RUN_KEYS := ["seed", "grade", "level", "start_floor", "floor", "heroes"]
const HERO_KEYS := ["index", "job_id", "hp", "alive", "equipment", "brain"]
const ESTATE_KEYS := ["clock_epoch", "last_settled_day", "stores", "population", "morale",
	"shortage_days", "strike_floors_left", "unrest_floors", "recovering", "decree"]


static func to_dict(run_save: Dictionary, estate_save: Dictionary, wallet: Dictionary,
		saved_at: String = "") -> Dictionary:
	## 부르는 쪽이 자기 몫을 만들어 넘긴다. 여기서는 묶기만 한다.
	return {
		"schema": SCHEMA,
		"saved_at": saved_at if not saved_at.is_empty() else _stamp(),
		"data_manifest": "2026-10-17",
		"run": run_save,
		"wallet": wallet,
		"estate": estate_save,
	}


static func migrate(raw: Variant) -> Dictionary:
	## 반환: `{status, reason, data}`. status = "ok" | "newer" | "corrupt".
	## 더 새 버전은 **읽지 않는다** — 모르는 필드를 버리면 조용한 손실이다 (ADR 0008).
	if not (raw is Dictionary):
		return {"status": "corrupt", "reason": "JSON 최상위가 사전이 아니다", "data": {}}
	var data: Dictionary = (raw as Dictionary).duplicate(true)
	var version := int(data.get("schema", 0))
	if version > SCHEMA:
		return {"status": "newer", "reason": "더 새 판의 세이브다", "data": {}}
	if version < 1:
		data = _v0_to_v1(data)
	data["schema"] = SCHEMA
	return {"status": "ok", "reason": "", "data": data}


static func _v0_to_v1(data: Dictionary) -> Dictionary:
	## `schema` 가 없던 시절(= P5-1 이전)의 사전을 1로 올린다. 새 필드는 기본값으로 채운다.
	## 비어 있는 값을 **추정해서** 채우지 않는다 — 없는 것은 기본값이다 (ADR 0008).
	var out := data.duplicate(true)
	if not (out.get("run", null) is Dictionary):
		out["run"] = {}
	if not (out.get("wallet", null) is Dictionary):
		out["wallet"] = {}
	if not (out.get("estate", null) is Dictionary):
		out["estate"] = {}
	if not out.has("saved_at"):
		out["saved_at"] = ""
	if not out.has("data_manifest"):
		out["data_manifest"] = ""
	return out


static func _stamp() -> String:
	return Time.get_datetime_string_from_system(false, true)
