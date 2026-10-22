class_name FonsActionTags
extends RefCounted
## 행동 → 태그 기록. 스킬은 **해온 일**에서 생긴다 (GDD 09 §1·§3) — 그 "해온 일"을 세는 자리.
##
## 태그 이름은 GDD 09 §3 의 104종(8도메인 × 13) 중에서 **지금 구현된 행동에 대응하는 것만** 쓴다.
## 없는 태그를 지어내지 않는다 — 붙일 행동이 생기면 그때 GDD 표에서 꺼내 온다.
## 문맥 태그 13종도 여기서는 안 쓴다 (판정 입력이 아니라 스킬 조건 어휘라 스킬 생성 단계에서 붙는다).
##
## 왜 태그인가: 원시 로그는 세이브를 불린다. 카운터만 남기면 판정에 충분하다 (09 §2 원칙 3).
## 그래서 `unit["tags"]` 는 `{태그: 횟수}` 뿐이다 — 순서·시각·좌표를 남기지 않는다.

## 행동 → 태그. **행동 이름은 게임 쪽 어휘**고, 오른쪽이 GDD 09 §3 의 태그다.
## 한 행동이 태그 둘을 남길 수 있다 (예: 걷기는 정찰 + 영역이동).
const ACTIONS := {
	# 전투 — 공격 방식이 태그를 가른다 (`FonsBattle` 이 정한다).
	"근접공격": ["근접타격"],
	"원거리공격": ["원거리사격"],
	"마법공격": ["마법시전"],
	"처치": ["약점타격"],
	"방어": ["방어태세"],
	"치유": ["치유"],
	# 탐험 — 걷기·발견·후퇴 (`FonsExplore`).
	"걷기": ["정찰", "영역이동"],
	"발견": ["관찰"],
	"후퇴": ["후퇴"],
	"매복": ["매복"],
	# 생활 — 영지 일과(`FonsEstate`)·필드 채집.
	"채집": ["채집"],
	"벌목": ["벌목"],
	"채광": ["채광"],
	"요리": ["요리"],
	"제작": ["대장"],
	"조제": ["조제"],
	# 영지 — 하루의 일과 (`FonsEstate`). 시설 운영이 아니라 **사람이 하는 일**이다.
	"약초채집": ["약초학"],
	"운반": ["운반"],
	"청소": ["청소"],
	"자체훈련": ["자체훈련"],
	"순찰": ["순찰"],
	"기록": ["기록"],
	# 회복
	"휴식": ["휴식"],
	"요양": ["요양"],
	"명상": ["명상"],
	"식사": ["식사"],
	"장비정비": ["장비정비"],
	"독서": ["독서"],
}

## 전투 태그인지 — AI 점수의 A항(적성)이 1.0 고정인 쪽 (09 §4-1-1).
const COMBAT_TAGS := ["근접타격", "원거리사격", "마법시전", "약점타격", "방어태세", "치유",
	"후퇴", "매복"]


static func tags_for(action: String) -> Array:
	return ACTIONS.get(action, [])


static func record(unit: Dictionary, action: String) -> Array:
	## 유닛에 `tags` 카운터를 남기고 이번에 오른 태그를 돌려준다.
	## 모르는 행동은 조용히 0건이다 — 이름을 지어내지 않는다.
	var tags := tags_for(action)
	if tags.is_empty():
		return []
	if not unit.has("tags"):
		unit["tags"] = {}
	for t in tags:
		unit["tags"][t] = int(unit["tags"].get(t, 0)) + 1
	return tags


static func count(unit: Dictionary, tag: String) -> int:
	return int(unit.get("tags", {}).get(tag, 0))


static func attack_tag(unit: Dictionary) -> String:
	## 이 유닛이 때릴 때 남길 공격 태그. 마법형은 마법시전, 아니면 근접타격.
	## 원거리 판정은 무기 데이터가 있어야 갈린다 — 지금은 직업 id 로만 가른다.
	if bool(unit.get("magical", false)):
		return "마법공격"
	var job := String(unit.get("job_id", ""))
	if job in ["l1_archer", "l2_sniper", "l2_gunner"]:
		return "원거리공격"
	return "근접공격"
