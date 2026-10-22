class_name FonsEquipment
extends RefCounted
## 장비 합산 — `data/equipment.json` 39종.
##
## 원본 `EquipmentSystem.EquippedStats` 는 착용 장비 스탯을 **더한다** (곱하지 않는다).
## 강화는 기본치 × (1 + 0.10 × 단계) — `equipment.json meta.enhancePctPerLevel` (원본 대조).
##
## 장비 스탯은 영웅 필드스탯에 **계수(등급·레벨) 뒤 가산**으로 들어간다 — 원본
## `BattleSystem.AddHero` 가 `stats.Hp * lvMul + equipment.Hp` 로 계산한다 (원본 대조 · ADR 0005).
##
## 데이터 키는 소문자(`hp`·`atk`·`spd_cast`…)이고 영웅 축은 대문자다. 축 대응은
## `FonsHeroStats.BASE_KEYS` 하나만 쓴다 — 여기서 표를 다시 적으면 조용히 어긋난다.
## 영웅 13축에 없는 데이터 축(`spd_cast`)은 합산에서 빠진다.

const ENHANCE_PCT_PER_LEVEL := 0.10


static func loadout(equipment: Dictionary, grade: int = 3) -> Array:
	## 슬롯마다 그 등급의 첫 장비 하나. 그 등급 장비가 없는 슬롯(`face`)은 건너뛴다 —
	## 없는 칸에 값을 지어내지 않는다.
	var items: Array = []
	for slot in equipment.get("slots", []):
		for item in equipment.get("equipment", []):
			if String(item.get("slot", "")) == String(slot) and int(item.get("grade", 0)) == grade:
				items.append(item)
				break
	return items


static func stats_for(items: Array, enhance: int = 0) -> Dictionary:
	## 13축 가산 합. 키는 영웅 축 이름(대문자)이고, 장비가 없는 축은 0 이다.
	var mul := 1.0 + ENHANCE_PCT_PER_LEVEL * float(enhance)
	var out: Dictionary = {}
	for axis in FonsHeroStats.AXES:
		out[axis] = 0.0
	for item in items:
		var s: Dictionary = item.get("stats", {})
		for axis in FonsHeroStats.AXES:
			var key := String(FonsHeroStats.BASE_KEYS[axis])
			out[axis] = float(out[axis]) + float(s.get(key, 0)) * mul
	return out


static func from_grade(equipment: Dictionary, grade: int = 3, enhance: int = 0) -> Dictionary:
	## 한 줄짜리 편의 — 등급 장비 한 벌의 13축 합.
	return stats_for(loadout(equipment, grade), enhance)
