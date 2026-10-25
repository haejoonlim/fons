class_name FonsIslandClock
extends RefCounted
## 섬일 시계 — 날짜는 세지 않고 기기 시계에서 계산한다.
##
## 정본: GDD 04 §3.13 — 섬 시간 = 기기 현실 시간 × 7. 섬 1일 = 현실 86400/7초.
## 계절: [ADR 0009](../docs/adr/0009-season-on-island-days.md) — 90섬일 한 계절, 365섬일 한 해,
## 남는 5일은 겨울이 받는다. `months` 표기는 폐기됐다.
##
## 왜 순수 계산인가
## ---------------
## 정산은 "하루 한 번"이라는 규칙 하나에 달려 있다. 그 규칙이 틀리면 미접속 21일 뒤에
## 21일치 세금이 몰려오거나, 반대로 한 번도 안 돌아 영지가 멈춘다. 파일·씬·노드를 모르는
## 계산으로 두어야 GUT 이 가짜 시계로 경계를 넘겨 볼 수 있다.
##
## 저장하는 것은 기준점 둘뿐이다 (`clock_epoch`·`last_settled_day`). 날짜 자체는 저장하지 않는다.

## 배속 — 현실 1초에 섬 7초.
const SPEED := 7
const REAL_DAY_SECONDS := 86400
const YEAR_DAYS := 365
const SEASON_DAYS := 90


static func day_at(clock_epoch: int, now: int) -> int:
	## 1일부터 센다. 기기 시계를 뒤로 돌려도 1 아래로 내려가지 않는다.
	## 정수 나눗셈이 아니라 floori 를 쓴다 — epoch 가 커져도 float 정밀도(2^53) 안이다.
	var elapsed := maxi(0, now - clock_epoch)
	return 1 + floori(float(elapsed * SPEED) / float(REAL_DAY_SECONDS))


static func tick(clock_epoch: int, now: int, last_settled_day: int) -> Dictionary:
	## 한 번 부르면 그 순간의 날짜와 "정산할 때인가"를 낸다.
	## 정산은 **한 번**이다 — 여러 날이 뛰어도 밀린 날을 반복하지 않는다.
	## 근거: 04 §3.3 "미접속 기간은 수확 공백일 뿐 — 손실·적립 없음" · §3.13 "접속보너스 없음".
	## 몰아 정산은 세금·수확·인구증가를 적립하고, 몰아 부과는 식량·유지비·아사를 몰고 온다.
	var day := day_at(clock_epoch, now)
	var due := day > last_settled_day
	return {
		"day": day,
		"settle": due,
		## 정산했다면 그날로 당긴다 — 밀린 날은 건너뛴다.
		"last_settled_day": day if due else last_settled_day,
	}


static func day_in_year(day: int) -> int:
	## 365일 주기 — 366일째는 1일째(봄)다.
	return posmod(day - 1, YEAR_DAYS) + 1


static func season_of(day: int, seasons: Array) -> Dictionary:
	## 데이터의 `island_days` 범위로 고른다. 계절 수치의 정본은 `data/estate.json` 이다 (ADR 0002).
	var d := day_in_year(day)
	for season in seasons:
		var span: Array = season.get("island_days", [])
		if span.size() >= 2 and d >= int(span[0]) and d <= int(span[1]):
			return season
	return seasons[0] if not seasons.is_empty() else {}
