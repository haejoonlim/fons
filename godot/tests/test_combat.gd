extends GutTest
## D-267 damage formula gate. SSOT: fons-web-ver/app/src/combat.ts.

func test_damage_subtracts_defense() -> void:
	assert_almost_eq(FonsCombat.damage(100.0, 30.0), 70.0, 0.0001)

func test_damage_floors_at_one() -> void:
	assert_almost_eq(FonsCombat.damage(10.0, 50.0), 1.0, 0.0001)

func test_crit_multiplies_base() -> void:
	assert_almost_eq(FonsCombat.damage(100.0, 30.0, 2.0), 140.0, 0.0001)
