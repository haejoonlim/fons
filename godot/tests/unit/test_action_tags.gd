extends GutTest
## 행동 → 태그 — 스킬이 "해온 일"에서 생기려면 먼저 셈이 있어야 한다 (GDD 09 §3).


func test_known_actions_map_to_gdd_tags() -> void:
	assert_eq(FonsActionTags.tags_for("걷기"), ["정찰", "영역이동"])
	assert_eq(FonsActionTags.tags_for("채집"), ["채집"])
	assert_eq(FonsActionTags.tags_for("없는행동"), [], "모르는 행동은 태그를 안 지어낸다")


func test_record_counts_per_unit_without_logs() -> void:
	var a := {"name": "가"}
	var b := {"name": "나"}
	FonsActionTags.record(a, "걷기")
	FonsActionTags.record(a, "걷기")
	FonsActionTags.record(b, "채집")
	assert_eq(FonsActionTags.count(a, "정찰"), 2)
	assert_eq(FonsActionTags.count(a, "영역이동"), 2, "한 행동이 태그 둘을 남긴다")
	assert_eq(FonsActionTags.count(b, "채집"), 1)
	assert_eq(FonsActionTags.count(b, "정찰"), 0, "다른 유닛과 섞이지 않는다")
	assert_eq(a["tags"].keys().size(), 2, "카운터만 남는다 — 순서·시각 없음")


func test_life_actions_map_to_gdd_section_3_tags() -> void:
	# 영지 일과가 쓰는 이름 — 오른쪽은 09 §3 의 생활 태그다 (새 태그를 만들지 않는다).
	assert_eq(FonsActionTags.tags_for("약초채집"), ["약초학"])
	assert_eq(FonsActionTags.tags_for("운반"), ["운반"])
	assert_eq(FonsActionTags.tags_for("청소"), ["청소"])
	assert_eq(FonsActionTags.tags_for("자체훈련"), ["자체훈련"])
	assert_eq(FonsActionTags.tags_for("순찰"), ["순찰"])
	assert_eq(FonsActionTags.tags_for("기록"), ["기록"])
	assert_eq(FonsActionTags.tags_for("장비정비"), ["장비정비"])
	assert_eq(FonsActionTags.tags_for("독서"), ["독서"])


func test_attack_tag_follows_the_attack_type() -> void:
	assert_eq(FonsActionTags.attack_tag({"magical": true}), "마법공격")
	assert_eq(FonsActionTags.attack_tag({"magical": false, "job_id": "l1_archer"}), "원거리공격")
	assert_eq(FonsActionTags.attack_tag({"magical": false, "job_id": "l1_guardian"}), "근접공격")
