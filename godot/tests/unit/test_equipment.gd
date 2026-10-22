extends GutTest
## 장비 합산 — `data/equipment.json` 39종을 영웅 스탯 앞에 세운다.
##
## 원본 `EquipmentSystem.EquippedStats` 는 착용 장비 스탯을 **더한다** (곱하지 않는다).
## 강화는 기본치 × (1 + 0.10 × 단계) — `equipment.json meta.enhancePctPerLevel` (원본 대조).

var _data: Dictionary


func before_all() -> void:
	_data = DataLoader.load_json("equipment.json")


func test_loadout_fills_every_slot_that_has_an_item() -> void:
	var items := FonsEquipment.loadout(_data, 3)
	# 13슬롯 중 `face` 만 그 등급 장비가 없다 — 없는 칸을 지어내지 않는다.
	assert_eq(items.size(), 12, "3등급 12칸")
	var slots := {}
	for item in items:
		assert_eq(int(item["grade"]), 3, "전부 3등급")
		assert_false(slots.has(item["slot"]), "한 슬롯에 하나: %s" % item["slot"])
		slots[item["slot"]] = true
	assert_false(slots.has("face"), "face 는 데이터에 없다")


func test_stats_are_summed_per_axis() -> void:
	var items := [{"stats": {"atk": 5, "hp": 10}}, {"stats": {"atk": 12, "def": 3}}]
	var st := FonsEquipment.stats_for(items)
	assert_almost_eq(st["ATK"], 17.0, 0.001, "같은 축은 더한다")
	assert_almost_eq(st["HP"], 10.0, 0.001)
	assert_almost_eq(st["DEF"], 3.0, 0.001)
	assert_eq(st.size(), FonsHeroStats.AXES.size(), "13축 전부 키가 있다 (없으면 0)")


func test_enhance_multiplies_the_base() -> void:
	var items := [{"stats": {"atk": 10}}]
	var plain := FonsEquipment.stats_for(items, 0)
	var plus5 := FonsEquipment.stats_for(items, 5)
	assert_almost_eq(plain["ATK"], 10.0, 0.001)
	assert_almost_eq(plus5["ATK"], 15.0, 0.001, "강화 5단계 = +50%")


func test_higher_grade_gear_is_stronger() -> void:
	var low := FonsEquipment.stats_for(FonsEquipment.loadout(_data, 1))
	var high := FonsEquipment.stats_for(FonsEquipment.loadout(_data, 3))
	assert_gt(float(high["ATK"]), float(low["ATK"]), "3등급 무기가 1등급보다 강하다")
	assert_gt(float(high["HP"]), float(low["HP"]), "방어구도 같다")
