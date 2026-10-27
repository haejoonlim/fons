extends GutTest
## 섬일 시계 — 미접속 후 정산이 **한 번만** 도는지 잠근다.
##
## 이 검사가 없으면 미접속 21일 뒤에 21일치 세금·식량·인구증가가 몰려온다.
## 04 §3.3 "미접속 기간은 수확 공백일 뿐 — 손실·적립 없음" 과 §3.13 "접속보너스 없음" 이
## 둘 다 금지하는 일이다. 그래서 "정산 1회"는 취향이 아니라 정본 규칙이다.

## 섬 1일 ≈ 현실 86400/7초. 반올림한 12343초를 쓴다 (floori 계산과 같아진다).
const DAY := 12343


func test_day_starts_at_one() -> void:
	assert_eq(FonsIslandClock.day_at(1000, 1000), 1, "시작한 순간은 1일")
	assert_eq(FonsIslandClock.day_at(1000, 1000 + DAY - 1), 1, "경계 직전은 아직 1일")
	assert_eq(FonsIslandClock.day_at(1000, 1000 + DAY), 2, "경계를 넘으면 2일")


func test_offline_three_weeks_settles_once() -> void:
	var epoch := 1000
	var last := 1
	var later: int = epoch + 21 * DAY
	var first := FonsIslandClock.tick(epoch, later, last)
	assert_true(bool(first["settle"]), "21일이 지났으면 정산할 때다")
	assert_eq(int(first["day"]), 22, "1일 + 21일")
	assert_eq(int(first["last_settled_day"]), 22, "밀린 날은 건너뛰고 그날로 당긴다")
	var again := FonsIslandClock.tick(epoch, later, int(first["last_settled_day"]))
	assert_false(bool(again["settle"]), "같은 날을 두 번 정산하지 않는다")


func test_online_days_settle_each_boundary() -> void:
	# 접속 중이면 경계마다 한 번씩 — "한 번만"이 "하루 한 번"이라는 뜻임을 같이 잠근다.
	var epoch := 0
	var last := 1
	var count := 0
	for day in range(1, 8):
		var result := FonsIslandClock.tick(epoch, day * DAY, last)
		if bool(result["settle"]):
			count += 1
		last = int(result["last_settled_day"])
	assert_eq(count, 7, "7일을 접속해 있으면 7회")


func test_clock_rollback_does_not_settle() -> void:
	# 기기 시계를 뒤로 돌려도 날짜가 1 아래로 내려가지 않고, 정산도 돌지 않는다.
	var epoch := 100000
	var result := FonsIslandClock.tick(epoch, epoch - 5000, 3)
	assert_eq(int(result["day"]), 1)
	assert_false(bool(result["settle"]), "지난 날을 다시 정산하지 않는다")


func test_estate_settles_once_per_island_day() -> void:
	## 영지가 실제로 정산을 부르는 자리 — 시계만 돌고, 밀린 날은 건너뛴다.
	var estate := FonsEstate.new()
	estate.start(DataLoader.load_json("estate.json"), 1)
	estate.clock_epoch = 1000
	estate.last_settled_day = 1
	assert_false(bool(estate.settle(1500)["settle"]), "첫 섬일")
	assert_true(bool(estate.settle(1000 + DAY)["settle"]), "경계를 넘으면 정산")
	assert_eq(estate.last_settled_day, 2)
	assert_false(bool(estate.settle(1000 + DAY + 500)["settle"]), "같은 섬일에 두 번 없음")
	var offline := estate.settle(1000 + 21 * DAY)
	assert_true(bool(offline["settle"]), "미접속 뒤에도 한 번")
	assert_eq(int(offline["day"]), 22)
	assert_eq(estate.last_settled_day, 22)
	assert_false(bool(estate.settle(1000 + 21 * DAY)["settle"]), "그 한 번이 전부")


func test_season_follows_island_days_from_data() -> void:
	# ADR 0009 — 계절은 섬일 90일 단위. 수치는 `data/estate.json` 이 정본이다.
	var seasons: Array = DataLoader.load_json("estate.json")["farming"]["seasons"]
	assert_eq(String(FonsIslandClock.season_of(1, seasons)["id"]), "spring")
	assert_eq(String(FonsIslandClock.season_of(90, seasons)["id"]), "spring")
	assert_eq(String(FonsIslandClock.season_of(91, seasons)["id"]), "summer")
	assert_eq(String(FonsIslandClock.season_of(181, seasons)["id"]), "autumn")
	assert_eq(String(FonsIslandClock.season_of(271, seasons)["id"]), "winter")
	assert_eq(String(FonsIslandClock.season_of(365, seasons)["id"]), "winter")
	assert_eq(String(FonsIslandClock.season_of(366, seasons)["id"]), "spring", "365일 다음은 봄")
