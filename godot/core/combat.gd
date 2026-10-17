class_name FonsCombat
extends RefCounted
## Ports fons-web-ver/app/src/combat.ts DamageFormula.
## SSOT: PLAN.md §6-2, D-267 1:1. Full formula ported in Phase 2.
##
## 38차: 회피(EVA) 판정은 없다 — 맞으면 맞는다. 대신 민첩이 이동속도(MS)를 올린다.
## 이동속도는 `races.json` meta.heroBaseStats.ms = 100% 기준이고, 여기 BASE_SPEED 에 곱한다.

## 기준 이동속도(단위/초) — MS 100% 일 때의 값.
const BASE_SPEED := 3.0

static func damage(atk: float, defense: float, crit_mult: float = 1.0) -> float:
	var base: float = maxf(1.0, atk - defense)
	return base * crit_mult

static func move_distance(stats: Dictionary, seconds: float) -> float:
	## 초당 이동 거리 × 시간. MS 는 퍼센트(100 = 기준)다.
	var speed := BASE_SPEED * (float(stats.get("MS", 100.0)) / 100.0)
	return speed * maxf(0.0, seconds)
