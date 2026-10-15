class_name FonsCombat
extends RefCounted
## Ports fons-web-ver/app/src/combat.ts DamageFormula.
## SSOT: PLAN.md §6-2, D-267 1:1. Full formula ported in Phase 2.

static func damage(atk: float, defense: float, crit_mult: float = 1.0) -> float:
	var base: float = maxf(1.0, atk - defense)
	return base * crit_mult
