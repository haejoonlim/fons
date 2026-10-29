class_name FonsScaling
extends RefCounted
## 층 난이도 — 적 스탯에 거는 유일한 배율. 규칙만 담고 상태는 없다.
##
## 정본 (전부 문서에 숫자가 있다 — 여기서 새로 만들지 않는다):
##   06 §3.2   층 스케일식 G1~G3 (1~100층)
##   확정 #52  G4 천정 101~130 — `scale = 5.8 + (f−100) × 0.05` · Lv130 캡
##   확정 #37  몬스터 레벨 = round(층 × 1.3) (표기 축 — 강도는 scale 이 담당)
##   확정 #38  Lv110+ HP 복리 ×(1−0.02)^(Lv−110) — Lv130 −33.2%
##   확정 #55  G4 HP 완화 10% (★5 봉인 해소 — sim_g4_ceiling 채택안)
##   biomes.json difficulty.mult — 바이옴 계수 (풀바다 1.00 · 화산 1.20 · 정점 1.30)
##
## 이 파일 이전에는 층 스케일을 **아무 데도 안 걸었다**. 편성 tier 만 바뀌고 스탯은 데이터 고정값이라
## 130층 실측에서 81~90층이 71~80층보다 쉬워지는 구간이 나왔다. 식은 G4 까지 문서에 다 있었다.
##
## 왜 비율 스탯은 안 곱하나
## ----------------------
## "적 스탯 = 기본 × scale × mult" 는 크기(HP·ATK·DEF·MAG·MDEF)에 대한 말이다.
## CRI·CDMG·EVA·ASPD 는 퍼센트·회수라 ×7.3 을 하면 회피 88%·치명 40% 가 되어
## 판이 확률로만 굴러간다 — 영웅 쪽 등급계수도 같은 이유로 7종을 뺀다(01 §2).

const MAX_FLOOR := 130          ## 탑 층수 (확정 #52) — 밖은 130 으로 자른다
const G4_START := 101           ## G4 천정 시작 층
const HP_LEVER_FROM_LEVEL := 110
const HP_LEVER_STEP := 0.98     ## 확정 #38 ② — Lv110+ 회당 −2%
const G4_HP_RELIEF := 0.90      ## 확정 #55 — 101층부터 적 HP ×0.90
const LEVEL_PER_FLOOR := 1.3    ## 확정 #37 — Lv = round(층 × 1.3)

## 배율을 거는 축 = 크기 스탯. 나머지(CRI·CDMG·EVA·ASPD·STA·MANA·SPD_CAST)는 그대로.
const MAGNITUDE_KEYS := ["hp", "atk", "def", "mdef", "mag"]


static func scale_for_floor(floor: int) -> float:
	## G1 2.0+f×0.03 → G2 3.5+(f−50)×0.04 → G3 5.3+(f−95)×0.10 → G4 5.8+(f−100)×0.05.
	## 구간 값이 경계에서 이어진다 (50=3.5 · 95=5.3 · 100=5.8).
	var f := clampi(floor, 1, MAX_FLOOR)
	if f <= 50:
		return 2.0 + float(f) * 0.03
	if f <= 95:
		return 3.5 + float(f - 50) * 0.04
	if f <= 100:
		return 5.3 + float(f - 95) * 0.10
	return 5.8 + float(f - 100) * 0.05


static func monster_level(floor: int) -> int:
	## 사사오입 — 85층 110.5 → 111. 50층 65 · 100층 130.
	## 만렙 Lv130 캡 (확정 #37) — 탑 밖으로 레벨이 계속 오르면 HP 손잡이가 끝없이 적을 깎는다.
	return clampi(int(floor(float(clampi(floor, 1, MAX_FLOOR)) * LEVEL_PER_FLOOR + 0.5)), 1, MAX_FLOOR)


static func hp_mult_for_level(level: int) -> float:
	## 확정 #38 ② — Lv110 부터 회당 −2% 복리. Lv130 = 0.98^20 = 0.6676.
	if level <= HP_LEVER_FROM_LEVEL:
		return 1.0
	return pow(HP_LEVER_STEP, float(level - HP_LEVER_FROM_LEVEL))


static func biome_mult(biome: Dictionary) -> float:
	## 바이옴을 모르면 1.0 — 계수가 없다고 적을 약하게 만들지 않는다.
	return float(biome.get("difficulty", {}).get("mult", 1.0))


static func scale_gatekeeper(monster: Dictionary, floor: int,
		hp_target: float = 0.0, atk_target: float = 0.0) -> Dictionary:
	## 게이트키퍼 보스 스케일 — 02 생태사전 "HP·ATK × (배치층 / bossScaleRefFloor)" (가안).
	##
	## 층 스케일을 **곱하지 않는다.** 정본 예시가 `도플갱어@5층 = 16000×5/46 ≈ HP 1739` 이고,
	## 거기에 G1(2.15)을 또 곱하면 3,739 가 되어 예시와 어깋난다. 06 §88 도 이 식을
	## "배치층 5~20 전용·선형 — G3 모디퍼와 무교차"로 적는다.
	## 바이옴 계수도 안 건다 — 06 §35 "게이트키퍼는 바이옴 밖".
	## `bossScaleRefFloor` 가 없는 보스(26~130층)는 이 식의 대상이 아니므로 일반 층 스케일을 쓴다.
	var ref := int(monster.get("spawn", {}).get("bossScaleRefFloor", 0))
		return scale_monster(monster, floor, {})
	var out := monster.duplicate(true)
	var stats: Dictionary = out.get("stats", {})
	if stats.is_empty():
		return out
	var mul := float(clampi(floor, 1, MAX_FLOOR)) / float(ref)
	# 정본 식은 `HP·ATK` 만 곱한다 — 기본 동작을 여기서 바꾸지 않는다.
	# 다만 공격 축은 **그 보스가 실제로 쓰는 스탯**이다. 마법형(aiType magic)은 `mag` 를 쓰므로
	# 목표치를 걸 때는 `atk` 가 아니라 `mag` 에 걸어야 한다 (10·20층 문지기가 여기 해당).
	var damage_key := "mag" if String(monster.get("aiType", "")) in FonsBattle.MAGICAL_AI else "atk"
	for key in ["hp", "atk"]:
		if stats.has(key):
			stats[key] = maxi(1, int(roundf(float(stats[key]) * mul)))
	# 측정·제안용 목표치 — 0 이면 정본 식 그대로다. `floor_report --gk-sweep` 이 쓴다.
	# (문지기를 일반 조우의 몇 배로 잡을지는 정본 결정이다 — 기본값을 바꾸지 않는다)
	if hp_target > 0.0:
		stats["hp"] = maxi(1, int(roundf(hp_target)))
	if atk_target > 0.0 and stats.has(damage_key):
		stats[damage_key] = maxi(1, int(roundf(atk_target)))
	out["stats"] = stats
	return out


static func scale_monster(monster: Dictionary, floor: int, biome: Dictionary,
		hp_knob: float = 1.0, atk_knob: float = 1.0) -> Dictionary:
	## 원본을 건드리지 않고 배율만 곱한 사본을 돌려준다 (편성 원본은 데이터 그대로 남는다).
	##
	## `hp_knob`·`atk_knob` 은 **측정용 손잡이**다 — 정본 곡선을 고치지 않고 민감도를 재기 위한 배율.
	## `atk_knob` 은 atk·mag 두 축에 걸린다 (적이 실제로 쓰는 피해 축이 둘이다).
	## 기본 1.0 이면 정본 그대로다. 난이도 조정이 확정되면 정본(GDD) 쪽을 먼저 고치고,
	## 이 인자는 1.0 그대로 둔다 (게임 경로가 측정 손잡이에 기대지 않게).
	var out := monster.duplicate(true)
	var stats: Dictionary = out.get("stats", {})
	if stats.is_empty():
		return out
	var f := clampi(floor, 1, MAX_FLOOR)
	var mult := scale_for_floor(f) * biome_mult(biome)
	var hp_mult := hp_mult_for_level(monster_level(f)) * maxf(0.0, hp_knob)
	if f >= G4_START:
		hp_mult *= G4_HP_RELIEF
	for key in MAGNITUDE_KEYS:
		if not stats.has(key):
			continue
		var m := mult
		if String(key) == "hp":
			m *= hp_mult
		elif String(key) == "atk" or String(key) == "mag":
			m *= atk_knob
		# 최소 1 — 배율이 0 이하로 떨어져도 적이 무피해 벽이 되지는 않는다.
		stats[key] = maxi(1, int(roundf(float(stats[key]) * m)))
	out["stats"] = stats
	return out
