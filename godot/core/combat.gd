class_name FonsCombat
extends RefCounted
## 데미지·관통·위치보정·회피·치명타 — 확정 #6.
##
## 정본 셋이 같은 식을 말한다:
##   확정 #6 / DEV_PLAN §데미지   감소율 = DEF / (DEF + 200)
##   원본 `Battle/DamageFormula.cs`  Compute · PositionMultiplier · TryEvade · ApplyCrit
##   웹 `fons-web-ver/app/src/combat.ts`  compute · positionMultiplier · resolvePhysical
##
## 2026-10-18 이전 이 파일은 `max(1, ATK − DEF)` 였다. 그 식은 위 셋 어디에도 없다.
## FX 감소식이 아니라 감산식이라, 방어가 높은 적에게 피해가 1로 붙는 구간이 정반대로 뒤집혀 있었다.
##
## 38차: 회피(EVA) 판정은 **있다** — 웹 정본 `resolvePhysical` 이 회피 → 치명타 순서로 굴린다.
## 확정된 건 "회피율 폐지" 가 아니라 영웅 스탯 축에서 EVA 를 MS 로 바꾼 것이고, 적 `stats.eva` 는 남아 있다.

## 기준 이동속도(단위/초) — MS 100% 일 때의 값.
const BASE_SPEED := 3.0

const DEF_CONST := 200.0
## 00 L15 (#6) 위치 D-182 — 가산(측면|배후 택1 + 고지대) 후 커버 곱. 최대 ×1.40.
const FLANK_BONUS := 0.1
const BACK_BONUS := 0.25
const HIGH_GROUND_BONUS := 0.15
const COVER_MUL := 0.75


static func bankers_round(x: float) -> int:
	# C# `Math.Round(double)` 기본값 = ToEven. 51.5 → 52 · 50.5 → 50.
	# GDScript `round()` 는 0.5 를 위로 올리므로 정본과 어긋난다.
	var f := floorf(x)
	var d := x - f
	if d < 0.5:
		return int(f)
	if d > 0.5:
		return int(f) + 1
	return int(f) if int(f) % 2 == 0 else int(f) + 1


static func compute(atk: float, defense: float, penetration: float = 0.0,
		position_multiplier: float = 1.0) -> int:
	if atk <= 0.0:
		return 0
	var d := maxf(0.0, defense)
	var pen := clampf(penetration, 0.0, 1.0)
	var eff_def := d * (1.0 - pen)
	var mitigation := eff_def / (eff_def + DEF_CONST)
	var dealt := atk * (1.0 - mitigation) * position_multiplier
	return maxi(1, bankers_round(dealt))


static func position_multiplier(angle: String, high_ground: bool, in_cover: bool) -> float:
	var add := 0.0
	if angle == "back":
		add = BACK_BONUS
	elif angle == "flank":
		add = FLANK_BONUS
	if high_ground:
		add += HIGH_GROUND_BONUS
	var mul := 1.0 + add
	if in_cover:
		mul *= COVER_MUL
	return mul


static func try_evade(eva: float, roll: float) -> bool:
	# 원본 `Random.Next(100)` = 0..99 균등 → floor(roll×100) 과 같은 분포.
	# roll 은 [0,1) 난수 하나 — 회피가 먼저 굴리고, 빗나가면 치명타는 굴리지 않는다.
	if eva <= 0.0:
		return false
	return int(floorf(roll * 100.0)) < clampi(int(eva), 0, 100)


static func try_crit(cri: float, roll: float) -> bool:
	if cri <= 0.0:
		return false
	return int(floorf(roll * 100.0)) < clampi(int(cri), 0, 100)


static func apply_crit(base: int, cdmg: float) -> int:
	# cdmg 100 → ×2.0 (05 §7). 상한 500.
	if cdmg <= 0.0:
		return base
	var mul := 1.0 + clampf(cdmg, 0.0, 500.0) / 100.0
	return bankers_round(base * mul)


static func resolve_physical(atk: float, defense: float, pen: float, eva: float, cri: float,
		cdmg: float, position_multiplier_value: float, roll_evade: float, roll_crit: float) -> Dictionary:
	# pen 은 퍼센트(0~100) — 웹 정본이 `pen / 100` 으로 넘긴다.
	if try_evade(eva, roll_evade):
		return {"damage": 0, "evaded": true, "critical": false}
	var dmg := compute(atk, defense, pen / 100.0, position_multiplier_value)
	var crit := try_crit(cri, roll_crit)
	return {"damage": apply_crit(dmg, cdmg) if crit else dmg, "evaded": false, "critical": crit}


static func resolve_magical(mag: float, mdef: float, eva: float, cri: float, cdmg: float,
		position_multiplier_value: float, mpen: float, roll_evade: float, roll_crit: float) -> Dictionary:
	# 마법관통(mpen)은 이미 0~1 실수다 — 34차에 `ResolveMagical` 의 관통 0f 박기를 고쳤다.
	if try_evade(eva, roll_evade):
		return {"damage": 0, "evaded": true, "critical": false}
	var dmg := compute(mag, mdef, clampf(mpen, 0.0, 1.0), position_multiplier_value)
	var crit := try_crit(cri, roll_crit)
	return {"damage": apply_crit(dmg, cdmg) if crit else dmg, "evaded": false, "critical": crit}


static func move_distance(stats: Dictionary, seconds: float) -> float:
	## 초당 이동 거리 × 시간. MS 는 퍼센트(100 = 기준)다.
	var speed := BASE_SPEED * (float(stats.get("MS", 100.0)) / 100.0)
	return speed * maxf(0.0, seconds)
