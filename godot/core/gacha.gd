class_name FonsGacha
extends RefCounted
## 소환 규칙 — 원본 정본 수치만 담는다.
##
## 출처 (원본 클론 2026-10-17 대조):
##   확정 #32  확률표 · 추첨 = 단일 난수 vs 누적 밴드 · ★4 소프트 70회(+2%p/회)·하드 130회
##             ★5+ 하드 5,200회(★5:★6 = 5:1 교대) · 천장 전부 비공개(UI 미표기)
##   확정 #33  천장 수치는 가안 — 구조만 확정
##   확정 #11 · D-276  종족 롤 shaped 5% + legacy 20종 95% · 시작 영웅 legacy-only
##   확정 #16 / #17  티켓 130마석 · 최초 10회 무료
##
## 이전 버전은 PULLS=130("130회 소환")을 게이트로 삼고 D-265를 근거로 적었다. 둘 다 틀렸다.
## 원본에 '소환 130회'는 없고(130은 탑 층수·티켓 단가·레벨 상한·마나 앵커·★4 하드 천장),
## D-265는 층 미션 시스템이다.

## 확정 #32 — 합 100.00 (%). 등급마다 재추첨하지 않는다.
const RARITY_GRADES := ["★1", "★2", "★3", "★4", "★5", "★6"]
const RARITY_PERCENT := [70.04, 20.0, 8.7, 1.2, 0.05, 0.01]

## 확정 #16 · #17 — 마석
const TICKET_COST := 130
const FREE_SUMMONS := 10

## 확정 #32 천장 (수치 자체는 #33 가안)
const SOFT_PITY_START := 70
const SOFT_PITY_STEP := 0.02
const HARD_PITY_4 := 130
const HARD_PITY_5PLUS := 5200

## 확정 #11 · D-276 종족 롤
const SHAPED_RATE := 0.05
const LEGACY_RATE := 0.95
const LEGACY_SPECIES := 20


static func band_sum() -> float:
	var total := 0.0
	for pct in RARITY_PERCENT:
		total += pct
	return total


static func roll_rarity(u: float) -> String:
	## 단일 난수 u(0.0~1.0) 하나로 등급을 뽑는다 — 누적 밴드 방식.
	var point := u * 100.0
	var acc := 0.0
	for i in RARITY_GRADES.size():
		acc += RARITY_PERCENT[i]
		if point <= acc:
			return RARITY_GRADES[i]
	return RARITY_GRADES[RARITY_GRADES.size() - 1]


static func roll_race(u: float) -> String:
	## 종족 계열 롤 — shaped 5% 아니면 legacy 95%.
	return "shaped" if u < SHAPED_RATE else "legacy"


static func next_pity_bonus(counter: int) -> float:
	## ★4 소프트 피티 — 70회부터 회차당 +2%p. 70회 미만은 0.
	if counter < SOFT_PITY_START:
		return 0.0
	return float(counter - SOFT_PITY_START + 1) * SOFT_PITY_STEP
