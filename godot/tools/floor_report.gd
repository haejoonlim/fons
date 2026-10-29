extends SceneTree
## 130층 승률표 + 난이도 손잡이 스윕.
##
## 실행:
##   godot --headless --path godot -s tools/floor_report.gd           # 표 (성장 축 있음/없음)
##   godot --headless --path godot -s tools/floor_report.gd -- --sweep # 격자 탐색
##   godot --headless --path godot -s tools/floor_report.gd -- --power # 영웅 총 전투력 배율 스윕
##   godot --headless --path godot -s tools/floor_report.gd -- --power --turns=50
##   godot --headless --path godot -s tools/floor_report.gd -- --power --grades=5 --muls=1.5,2,2.5,3
##   godot --headless --path godot -s tools/floor_report.gd -- --floors --power-mul=2
##   godot --headless --path godot -s tools/floor_report.gd -- --atk=mon_x:1.2   # 종별 공격 배율
##   godot --headless --path godot -s tools/floor_report.gd -- --biome=biome_x:1.1 # 바이옴 계수 배율
##   godot --headless --path godot -s tools/floor_report.gd -- --hp=mon_x:0.31     # 종별 HP 배율
##   godot --headless --path godot -s tools/floor_report.gd -- --hp-band=111-120:0.8  # 층 대역 한정 HP 배율
##   godot --headless --path godot -s tools/floor_report.gd -- --atk-band=111-120:0.8 # 층 대역 한정 공격(atk·mag) 배율
##   godot --headless --path godot -s tools/floor_report.gd -- --trials=10          # 층마다 시드 10개로 반복
##   godot --headless --path godot -s tools/floor_report.gd -- --borrow-no-food   # 이웃 풀에서 먹이층 제외
##   godot --headless --path godot -s tools/floor_report.gd -- --gk --party-seed=1  # 층마다 같은 파티로 문지기 표
##   godot --headless --path godot -s tools/floor_report.gd -- --party=5 --party-shield=2  # 아군 보호막 직업 최소 수
##   godot --headless --path godot -s tools/floor_report.gd -- --party-tank=1 --party-heal=1  # 수호·치유 최소 수
##
## `--party-seed=N` 은 **층 사이를 비교하는 표**용이다. 기본 0 이면 지금까지처럼 층마다
## 다른 파티(시드 = 층)를 뽑는다. 그러면 121 행과 124 행의 차이에 보스 차이와 파티 차이가
## 섞인다 — 121 침묵의 군주 무승부가 그렇게 만들어진 값이다(2026-10-28 실측,
## `docs/design/121_침묵의_군주_교착.md`). N>0 이면 모든 층이 그 시드의 파티를 쓴다.
##
## 이건 게임 코드가 아니라 **측정 도구**다. 층 난이도 곡선을 바꿀 때마다 이 표를 다시 뽑는다.
## 영웅은 층마다 **만피로 새로** 만든다 — HP 를 이어 가면 "그 층이 어려운가"와
## "앞 층에서 닳았나"가 섞인다. 시드는 층 번호다.
##
## 손잡이는 둘이다.
##   `hp_knob`  — 적 HP 에만 곱하는 배율. **정본 곡선을 고치지 않는다** (기본 1.0 = 정본).
##   `max_turns` — 한 판 턴 상한. 정본에 없는 값이라 우리가 정한다 (기본 30).
##
## `--jobs=N` 은 **과거 상태 재현용**이다. 2026-10-22 이전에는 파티가 5인인데 직업은 4개만
## 뽑혀서 다섯 번째가 무직이었다. 그 상태의 표를 같은 조건으로 다시 뽑아 비교할 때 쓴다.
## (`--party=5 --jobs=4` = 고치기 전, `--party=5` = 지금)
## 상층 승률이 단조롭게 내려가는 조합을 찾는 데 쓴다.

const BANDS := [[1, 10], [11, 20], [21, 30], [31, 40], [41, 50], [51, 60], [61, 70],
	[71, 80], [81, 90], [91, 100], [101, 110], [111, 120], [121, 130]]

var _races: Dictionary
var _monsters: Variant
var _biomes: Variant
var _job_tree: Dictionary
var _job_coef: Dictionary
var _equipment: Dictionary
var _basics: Dictionary
## 한 판 턴 상한. 원본에는 없다(원본 대조) — 판은 한쪽이 죽으면 끝난다.
## 여기서는 무한 루프만 막는 안전 가드로 쓴다. `--turns=N` 으로 바꿔 잰다.
var _cap := 999
## 영웅 등급. 정본 소환 분포의 기대등급은 ★5 부근이라 기본값이 ★5 다 (확정 #32).
## `--grade=6`·`--grade=7` 로 상위 등급 전제를 잰다 (★7 은 소환 미출현 · 초월진화 전용 — 확정 #7).
var _grade := 5
## 파티 인원. 정본은 5인이다 (확정 #3). 4인은 2D 배치 기준으로 먼저 잡힌 값이라 둘을 비교해 잰다.
var _party := FonsRunState.PARTY_SIZE
## 측정용 — 파티의 아군 보호막·수호·치유 직업 최소 수. 0 이면 정본 그대로다.
var _party_shield := 0
var _party_tank := 0
var _party_heal := 0
## 영웅 파티 시드. 0 = 층마다 다른 파티(시드 = 층, 기존 동작). N>0 = 모든 층이 같은 파티.
## 층 사이를 비교하는 표(문지기 표·층별 표)에서 보스/층 차이와 파티 차이를 가를 때 쓴다.
var _party_seed := 0
## 키워드 직업을 앞에서 몇 개만 쓸지. 0 = 데이터 그대로 (지금 동작).
## 5인 파티에서 4를 주면 고치기 전(다섯 번째 무직) 표를 재현한다.
var _jobs_cap := 0
## 영웅 레벨. 0 이면 **층에서 기대되는 레벨**(`round(층×1.3)` — 확정 #37 몬스터 레벨과 같은 앵커:
## 50층=Lv65 · 100층=Lv130). 지금까지의 표는 항상 Lv130 이었는데, 그러면 5층 문지기를
## Lv130 파티가 때리므로 "그 층이 어려운가"를 안 잴다. `--level=auto` 로 켜진다.
var _level := 130
## 장착 스킬 수 — 피해 계열만 센다 (`FonsSkillEffect.COMBAT_KINDS`). 0 이면 스킬 없음.
## `--skill-rarity=1..6` 로 레어도(D~L)를 고른다. 0 이면 카탈로그 순서.
var _skills := 0
var _skill_rarity := 0
## 스킬은 스탯이 아니라 **행동 한 번의 피해**를 올린다 (GDD 09 §5-2).
## 단계는 그 스킬의 단계 상한(= 레어도+1), 레벨은 13 이다.
var _catalog: Array = []
## 영웅 AI 끄기 — 성격·판단이 승률표를 얼마나 움직이는지 비교할 때 쓴다.
## 이 도구의 표는 **AI 켜진 상태**가 기본이다: 게임에서 실제로 도는 판과 같아야 한다.
var _no_ai := false
var _personalities: Dictionary = {}
var _profiles: Dictionary = {}
var _legacy_pairs: Dictionary = {}
## 게이트키퍼 배수 스윕 — HP 는 일반 조우 HP 합의 배수, ATK 는 일반 한 마리 평균의 배수.
## 0 이면 정본 식 그대로다 (`--gk-atk=0`).
var _gk_trials := 20
var _gk_atk := 0.0
var _gk_ratios: Array = [1.0, 1.5, 2.0]
## 측정용 — 이 id 들을 편성 풀에서 뺀다. 특정 승격종이 승률을 얼마나 옮겼는지 가를 때만 쓴다.
## 빈 배열이면 데이터 그대로다 (게임 경로는 이 도구를 안 쓴다).
var _skip: Array = []
## 측정용 — 종별 공격 축(atk·mag) 배율. `--atk=mon_x:1.2,mon_y:1.4`.
## 승격종 공격력을 올렸을 때 그 대역만 되돌아가는지 잴 때 쓴다 (게임 경로는 안 쓴다).
var _atk_scales := {}
## 측정용 — 바이옴 계수(`difficulty.mult`) 배율. `--biome=biome_x:1.1`.
## 바이옴 계수 한 칸으로 같은 대역을 되돌릴 수 있는지 재는 손잡이다.
var _biome_scales := {}
## 측정용 — 종별 HP 배율. `--hp=mon_x:0.31`. 승격 피식자의 무게를 되돌리는 안을 잴 때 쓴다.
var _hp_scales := {}
## 측정용 — **층 대역** HP 배율. `--hp-band=111-120:0.8` (쉼표로 여러 구간).
## 한 대역이 바이옴 둘에 걸칠 수 있어(111~115 형상군락 · 116~120 마른 지맥) 바이옴 손잡이로는 못 잰다.
var _band_hp: Array = []
## 측정용 — 층 대역 **공격**(atk·mag) 배율. `--atk-band=111-120:0.5`.
## 적 피해만 내려서 "아군이 죽는 것이 병목인가"를 가른다.
var _band_atk: Array = []
## 파워 스윕 범위 — `--muls=1.5,2,3` · `--grades=5`. 비우면 도구 기본값 전체.
var _power_muls: Array = []
var _power_grades: Array = []
## 층별 표(`--floors`)에 걸 총량 배율. 1.0 이면 정본 그대로다.
var _power_mul := 1.0
## 측정용 — 영웅 **화력**(ATK·MAG)만 배율. `--hero-atk=1.02`. HP·DEF 는 안 건드린다.
var _hero_atk := 1.0
## 측정용 — 101층 기억 배분. `--memory=5:5`. 0:0 이면 배분 없음(기존 표 그대로).
var _memory_attack := 0
var _memory_guard := 0
## 측정용 — 층마다 다른 시드로 몇 판 볼지. 기본 1 = 지금까지의 표(시드 = 층 번호).
## 경계값이 한 시드에 걸려 있지 않은지 볼 때 쓴다 (`--trials=10`).
var _trials := 1


func _initialize() -> void:
	_races = _load("races.json")
	_monsters = _load("monsters.json")
	_biomes = _load("biomes.json")
	_job_tree = _load("job_tree.json")
	_job_coef = _load("job_coef.json")

	_equipment = _load("equipment.json")
	_basics = _load("basic_attacks.json")
	_catalog = _load("skills_catalog.json").get("skills", [])
	_personalities = _load("personalities.json")
	_profiles = _load("job_ai_profiles.json")
	_legacy_pairs = _load("fusion_pairs.json")

	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--turns="):
			_cap = int(arg.split("=")[1])
		elif arg.begins_with("--grade="):
			_grade = int(arg.split("=")[1])
		elif arg.begins_with("--party="):
			_party = int(arg.split("=")[1])
		elif arg.begins_with("--party-shield="):
			_party_shield = maxi(0, int(arg.split("=")[1]))
		elif arg.begins_with("--party-tank="):
			_party_tank = maxi(0, int(arg.split("=")[1]))
		elif arg.begins_with("--party-heal="):
			_party_heal = maxi(0, int(arg.split("=")[1]))
		elif arg.begins_with("--jobs="):
			_jobs_cap = int(arg.split("=")[1])
		elif arg.begins_with("--skills="):
			_skills = int(arg.split("=")[1])
		elif arg.begins_with("--skill-rarity="):
			_skill_rarity = int(arg.split("=")[1])
		elif arg == "--no-ai":
			_no_ai = true
		elif arg == "--level=auto":
			_level = 0
		elif arg == "--raw-party":
			# 먹이층 보장 **전** 편성 재현 — A/B 에서 규칙 하나만 바꿔 잰다.
			FonsEncounter.food_layer_guard = false
		elif arg.begins_with("--enemy-cap="):
			# 편성 인원 상한만 고정 — 후보 4↔5 효과를 먹이층 역할과 가른다.
			FonsEncounter.party_cap = int(arg.split("=")[1])
		elif arg.begins_with("--skip="):
			# 특정 승격종을 풀에서 빼고 잰다 — 승률 변화의 출처를 가른다.
			for id in arg.split("=")[1].split(","):
				if not String(id).is_empty():
					_skip.append(String(id))
		elif arg.begins_with("--atk="):
			_atk_scales = _pairs(arg.split("=", true, 1)[1])
		elif arg.begins_with("--biome="):
			_biome_scales = _pairs(arg.split("=", true, 1)[1])
		elif arg.begins_with("--hp="):
			_hp_scales = _pairs(arg.split("=", true, 1)[1])
		elif arg.begins_with("--hp-band="):
			_band_hp = _band_muls(arg.split("=", true, 1)[1])
		elif arg.begins_with("--atk-band="):
			_band_atk = _band_muls(arg.split("=", true, 1)[1])
		elif arg.begins_with("--trials="):
			_trials = maxi(1, int(arg.split("=")[1]))
		elif arg == "--borrow-no-food":
			FonsEncounter.borrow_skips_food = true
		elif arg.begins_with("--muls="):
			for part in arg.split("=", true, 1)[1].split(","):
				_power_muls.append(float(part))
		elif arg.begins_with("--grades="):
			for part in arg.split("=", true, 1)[1].split(","):
				_power_grades.append(int(part))
		elif arg.begins_with("--power-mul="):
			_power_mul = float(arg.split("=", true, 1)[1])
		elif arg.begins_with("--hero-atk="):
			_hero_atk = float(arg.split("=", true, 1)[1])
		elif arg.begins_with("--memory="):
			# 게임과 같은 경계로 건다 — 101층부터 (FonsRunState.MEMORY_FLOOR).
			var kv := arg.split("=", true, 1)[1].split(":")
			if kv.size() == 2:
				_memory_attack = maxi(0, int(kv[0]))
				_memory_guard = maxi(0, int(kv[1]))
		elif arg.begins_with("--level="):
			_level = int(arg.split("=")[1])
		elif arg.begins_with("--gk-trials="):
			_gk_trials = maxi(1, int(arg.split("=")[1]))
		elif arg.begins_with("--gk-atk="):
			_gk_atk = float(arg.split("=")[1])
		elif arg.begins_with("--gk-ratios="):
			_gk_ratios = []
			for part in arg.split("=")[1].split(","):
				_gk_ratios.append(float(part))
		elif arg.begins_with("--party-seed="):
			_party_seed = maxi(0, int(arg.split("=")[1]))
	# 인자를 다 읽은 **뒤에** 자른다 — 앞에서 자르면 `--jobs=` 가 아직 안 읽혀 있다.
	if _jobs_cap > 0:
		_job_tree = _tree_with_jobs(_job_tree, _jobs_cap)
	if not _skip.is_empty():
		var kept: Array = []
		for m in _monsters.get("monsters", []):
			if not String(m.get("id", "")) in _skip:
				kept.append(m)
		_monsters["monsters"] = kept
	_apply_scales()
	if "--sweep" in args:
		_sweep()
		quit()
		return
	if "--power" in args:
		_power()
		quit()
		return
	if "--gk-sweep" in args:
		_gk_sweep()
		quit()
		return
	if "--gk" in args:
		_gk()
		quit()
		return
	if "--floors" in args:
		_floors()
		quit()
		return

	var bare := _measure({}, {}, 1.0, _cap, {})
	var grown := _measure(_job_tree, _equipment, 1.0, _cap, _job_coef)

	print("| 층 대역 | 승 | 패 | 무승부 | 면제 | 평균 턴 | 없이 (승/패/무/면) | 없이 평균 턴 |")
	print("|---|---|---|---|---|---|---|---|")
	for i in BANDS.size():
		var b: Array = BANDS[i]
		var g: Dictionary = grown[i]
		var o: Dictionary = bare[i]
		var n := float(b[1] - b[0] + 1)
		print("| %d~%d | %d | %d | %d | %d | %.1f | %d/%d/%d/%d | %.1f |" % [
			b[0], b[1], g["w"], g["l"], g["d"], g["n"], float(g["turns"]) / n,
			o["w"], o["l"], o["d"], o["n"], float(o["turns"]) / n,
		])
	print("")
	print("합계 — 성장 축 있음: 승 %d · 패 %d · 무 %d · 면제 %d / 없음: 승 %d · 패 %d · 무 %d · 면제 %d" % [
		_sum(grown, "w"), _sum(grown, "l"), _sum(grown, "d"), _sum(grown, "n"),
		_sum(bare, "w"), _sum(bare, "l"), _sum(bare, "d"), _sum(bare, "n"),
	])
	print("면제 = 일반 조우가 없는 층(이데아 문턱 126~130 · `noCombat`). 승/패 어느 쪽도 아니다.")
	print("영웅 1인 — %s" % _hero_delta())
	quit()


func _sweep() -> void:
	## 거꾸로 오르는 구간(inversion)이 적을수록 단조롭다. 무승부도 따로 센다 —
	## 턴 상한에 걸린 판은 이긴 것도 진 것도 아니라 곡선을 흐린다.
	var caps := [20, 25, 30, 40, 50]
	var hps := [0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4]
	var results: Array = []
	for cap in caps:
		for hp in hps:
			var rows := _measure(_job_tree, _equipment, float(hp), int(cap), _job_coef)
			results.append({
				"hp": hp, "cap": cap, "rows": rows,
				"inv": _inversions(rows), "wins": _sum(rows, "w"), "draws": _sum(rows, "d"),
			})
	# 전 격자를 출력한다 — 상위 몇 줄만 보면 "HP 를 낮춰도 승수가 안 변한다" 같은 사실이 가려진다.
	results.sort_custom(func(a, b):
		if float(a["hp"]) != float(b["hp"]):
			return float(a["hp"]) < float(b["hp"])
		return int(a["cap"]) < int(b["cap"])
	)
	print("| 적 HP 배율 | 턴 상한 | 거꾸로 오르는 구간 | 합계 승 | 합계 무 | 대역 승 (1~10 → 121~130) |")
	print("|---|---|---|---|---|---|")
	for r in results:
		var per_band: Array = []
		for row in r["rows"]:
			per_band.append(int(row["w"]))
		print("| %.1f | %d | %d | %d | %d | %s |" % [
			float(r["hp"]), int(r["cap"]), int(r["inv"]), int(r["wins"]), int(r["draws"]),
			"/".join(per_band.map(func(v): return str(v))),
		])


func _power() -> void:
	## 영웅 **총 전투력 배율** 스윕 — statMod 같은 재배분이 아니라 총량을 몇 배로 만드는지 본다.
	## 91~130 을 열려면 총량이 몇 배 필요할지 잰다. 배율은 전 축(ATK·DEF·MAG·MDEF·PEN·CRI·CDMG·HP)에 건다.
	## 등급 ★5(기본)·★7 두 줄을 함께 본다 — 어느 등급을 전제로 하느냐가 정본 결정이다.
	## `--turns=N` 으로 한 판 턴 상한을 바꿀 수 있다 (기본 30 — 정본에 없는 값).
	var cap := _cap
	print("| 등급 | 총량 배율 | 대역 승 (1~10 → 121~130) | 합계 승 | 역전 | 무 | 면제 | 턴 상한 %d |" % cap)
	var muls: Array = _power_muls if not _power_muls.is_empty() else [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 6.0, 8.0]
	var grades: Array = _power_grades if not _power_grades.is_empty() else [5, 7]
	for grade in grades:
		for mul in muls:
			var rows := _measure_power(grade, float(mul), cap)
			var parts: Array = []
			for row in rows:
				parts.append(str(int(row["w"])))
			print("| ★%d | ×%.1f | %s | %d | %d | %d | %d | %d |" % [
				grade, float(mul), "/".join(parts), _sum(rows, "w"), _inversions(rows),
				_sum(rows, "d"), _sum(rows, "n"), cap])


func _measure_power(grade: int, mul: float, cap: int) -> Array:
	## 총량 배율만 바꾼 파티로 대역 승수를 잰다. 카드 규칙은 정본(일반 L2 3장) 그대로.
	var rows: Array = []
	for i in BANDS.size():
		rows.append({"w": 0, "l": 0, "d": 0, "n": 0, "turns": 0.0})
	for floor in range(1, 131):
		var heroes := FonsRunState.heroes_from(_races, _job_tree, _equipment, grade, 130, floor, _job_coef, 0, FonsRunState.PARTY_SIZE, _ai(), _basics, _party_shield, _party_tank, _party_heal)
		_scale_power(heroes, mul)
		var rng := RandomNumberGenerator.new()
		rng.seed = floor
		var out := FonsFloorRun.simulate(rng, _monsters, _biomes, floor, 0, heroes, cap)
		var row: Dictionary = rows[_band_index(floor)]
		match String(out["winner"]):
			"ally": row["w"] = int(row["w"]) + 1
			"enemy": row["l"] = int(row["l"]) + 1
			"none": row["n"] = int(row["n"]) + 1
			_: row["d"] = int(row["d"]) + 1
		row["turns"] = float(row["turns"]) + float(out["turns"])
	return rows


func _apply_memory(heroes: Array, floor: int) -> void:
	## 101층 배분을 이미 만든 파티에 건다 — 게임 경로와 같은 함수·같은 경계다.
	if _memory_attack + _memory_guard <= 0 or floor < FonsRunState.MEMORY_FLOOR:
		return
	FonsRunState.apply_memory_to_party(heroes, _memory_attack, _memory_guard)


func _scale_hero_atk(heroes: Array) -> void:
	## 측정용 — 화력만 올린다. `_scale_power` 와 달리 HP·DEF 는 그대로다.
	if is_equal_approx(_hero_atk, 1.0):
		return
	for h in heroes:
		h["atk"] = float(h.get("atk", 0.0)) * _hero_atk
		h["mag"] = float(h.get("mag", 0.0)) * _hero_atk


func _scale_power(heroes: Array, mul: float) -> void:
	## 측정용 — 영웅 총량 배율. 전 축(ATK·DEF·MAG·MDEF·PEN·CRI·CDMG·HP)에 같은 배율을 건다.
	## 1.0 이면 그대로다 (게임 경로는 이 함수를 안 쓴다).
	if is_equal_approx(mul, 1.0):
		return
	for h in heroes:
		for key in ["atk", "def", "mag", "mdef", "pen", "cri", "cdmg"]:
			h[key] = float(h.get(key, 0.0)) * mul
		h["maxHp"] = int(roundf(float(h.get("maxHp", 0)) * mul))
		h["hp"] = h["maxHp"]


func _equip(heroes: Array) -> void:
	## 측정용 장착 — 파티원 전원이 같은 규격을 받는다. 장착하지 않으면 전투는 예전과 똑같이 돈다.
	if _skills <= 0:
		return
	var loadout := FonsSkillEffect.loadout(_catalog, _skills, _skill_rarity)
	for h in heroes:
		FonsSkillEffect.attach(h, loadout)


func _level_for(floor: int) -> int:
	## `--level=auto` 면 층 기대 레벨, 아니면 고정 레벨.
	return FonsScaling.monster_level(floor) if _level <= 0 else _level


func _hero_seed(floor: int) -> int:
	## `--party-seed=N` 이면 모든 층이 그 파티를 쓴다. 0 이면 층마다 다른 파티(기존).
	return _party_seed if _party_seed > 0 else floor


func _gk() -> void:
	## 게이트키퍼 전투 경로 — 5·10·15·20층은 **보스 1체**(02 조우 모드 `boss`).
	## 일반 조우(3~5종)와 섞지 않는다 — 정본이 그렇게 나눠 놓았다.
	## 65/66·105/106 경계의 계층문지기는 `monsters.json` 에 상대가 없다 (26블록 §10 문서 전용).
	## 그 네 층은 **일반 조우를 대리로** 재고 표에 그렇게 적는다.
	print("### 게이트키퍼층 (보스 1체)")
	print("| 층 | 문지기 | tier | HP | ATK | 같은 층 일반 조우 HP | 문지기/일반 | 결과 | 턴 | 생존 |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	var wins := 0
	var total := 0
	for floor in range(1, 131):
		var gk := FonsEncounter.gatekeeper_for_floor(_monsters, floor, _biomes)
		if gk.is_empty():
			continue
		var built := FonsFloorRun.build_gatekeeper(_monsters, _biomes, floor)
		var hero_party := FonsRunState.heroes_from(_races, _job_tree, _equipment, _grade,
			_level_for(floor), _hero_seed(floor), _job_coef, 0, _party, _ai(), _basics, _party_shield, _party_tank, _party_heal)
		_equip(hero_party)
		_scale_hero_atk(hero_party)
		var rng := RandomNumberGenerator.new()
		rng.seed = floor
		var out := FonsFloorRun.run(rng, hero_party, built["party"], floor, _cap)
		var alive := 0
		for h in hero_party:
			if bool(h.get("alive", false)):
				alive += 1
		total += 1
		if String(out["winner"]) == "ally":
			wins += 1
		var unit: Dictionary = built["party"][0]
		var normal_hp := 0
		for m in FonsEncounter.build_party(_monsters, _biomes, floor, 0):
			normal_hp += int(roundf(float(m.get("stats", {}).get("hp", 0)) \
				* FonsScaling.scale_for_floor(floor) * FonsScaling.biome_mult(_biomes)))
		var ratio := float(unit["maxHp"]) / maxf(1.0, float(normal_hp))
		print("| %d | %s | %d | %d | %.0f | %d | ×%.2f | %s | %d | %d/%d |" % [
			floor, String(gk.get("name", "?")), int(gk.get("tier", 0)),
			int(unit["maxHp"]), float(unit["atk"]), normal_hp, ratio, String(out["winner"]),
			int(out["turns"]), alive, hero_party.size(),
		])
	print("")
	print("문지기 승 %d / %d (★%d · %d인 · %s · 가드 %d)" % [
		wins, total, _grade, _party, "층 기대 레벨" if _level <= 0 else "Lv%d" % _level, _cap])
	print("")
	print("### 계층문지기 경계 — 상대 데이터 없음 · 일반 조우 대리")
	print("| 층 | 근거 | 문지기 | 결과 | 턴 | 생존 |")
	print("|---|---|---|---|---|---|")
	for floor in FonsEncounter.LAYER_BOUNDARIES:
		var hero_party := FonsRunState.heroes_from(_races, _job_tree, _equipment, _grade,
			_level_for(floor), _hero_seed(floor), _job_coef, 0, _party, _ai(), _basics, _party_shield, _party_tank, _party_heal)
		_equip(hero_party)
		var rng := RandomNumberGenerator.new()
		rng.seed = floor
		var out := FonsFloorRun.simulate(rng, _monsters, _biomes, floor, 0, hero_party, _cap)
		var alive := 0
		for h in hero_party:
			if bool(h.get("alive", false)):
				alive += 1
		var gk := FonsEncounter.gatekeeper_for_floor(_monsters, floor, _biomes)
		print("| %d | %s | %s | %s | %d | %d/%d |" % [
			floor, "일반 조우", "없음" if gk.is_empty() else String(gk.get("name", "")),
			String(out["winner"]), int(out["turns"]), alive, hero_party.size(),
		])


func _gk_sweep() -> void:
	## 5·10·15·20층 문지기를 **일반 조우의 몇 배**로 잡을지 재는 표.
	## HP 배수는 일반 조우 HP **합계** 기준, ATK 배수는 일반 **한 마리 평균** 기준이다.
	## (합계 ATK 를 기준으로 잡으면 단일 개체가 5인 분산 공격을 한 몸에 받아 과도하게 세진다)
	print("### 게이트키퍼 배수 스윕 — %d시드/층 · ★%d · %d인 · %s" % [
		_gk_trials, _grade, _party, "층 기대 레벨" if _level <= 0 else "Lv%d" % _level])
	print("| HP 배수 | 층 | 승률 | 평균 턴 | 평균 생존 | 문지기 HP | 문지기 ATK | 일반 HP | HP 비율 |")
	print("|---|---|---|---|---|---|---|---|---|")
	for ratio in _gk_ratios:
		var rates: Array = []
		for floor in FonsEncounter.GATEKEEPER_FLOORS:
			var normal := FonsFloorRun.normal_encounter_stats(_monsters, _biomes, floor)
			var wins := 0
			var turns := 0.0
			var survivors := 0.0
			var boss_hp := 0
			var boss_atk := 0.0
			for t in _gk_trials:
				var built := FonsFloorRun.build_gatekeeper(_monsters, _biomes, floor, float(ratio), _gk_atk)
				var unit: Dictionary = built["party"][0]
				boss_hp = int(unit.get("maxHp", 0))
				boss_atk = float(unit.get("mag", 0)) if bool(unit.get("magical", false)) else float(unit.get("atk", 0))
				var heroes := FonsRunState.heroes_from(_races, _job_tree, _equipment, _grade,
					_level_for(floor), _hero_seed(t * 7919 + floor), _job_coef, 0, _party, _ai(), _basics, _party_shield, _party_tank, _party_heal)
				_equip(heroes)
				var rng := RandomNumberGenerator.new()
				rng.seed = t * 104729 + floor
				var out := FonsFloorRun.run(rng, heroes, built["party"], floor, _cap)
				if String(out["winner"]) == "ally":
					wins += 1
				turns += float(out["turns"])
				for h in heroes:
					if bool(h.get("alive", false)):
						survivors += 1.0
			var rate := 100.0 * float(wins) / float(_gk_trials)
			rates.append(rate)
			print("| ×%.1f | %d | %.0f%% | %.1f | %.1f/%d | %d | %.0f | %d | ×%.2f |" % [
				float(ratio), floor, rate, turns / float(_gk_trials),
				survivors / float(_gk_trials), _party, boss_hp, boss_atk, int(normal["hp"]),
				float(boss_hp) / maxf(1.0, float(normal["hp"])),
			])
		var inv := 0
		for i in rates.size() - 1:
			if float(rates[i]) < float(rates[i + 1]):
				inv += 1
		print("| ×%.1f | **대역 역전** | %d | | | | | | |" % [float(ratio), inv])
	print("")


func _floors() -> void:
	## 층별 내역 — 대역 표에서 보이는 꺾임이 어느 층·바이옴에서 나오는지 본다.
	print("| 층 | 결과 | 턴 | 생존 | 바이옴 | 바이옴 계수 | 중심 tier | 편성 tier | 적 수 | 적 HP 합 |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for floor in range(1, 131):
		var heroes := FonsRunState.heroes_from(_races, _job_tree, _equipment, _grade, _level_for(floor), _hero_seed(floor), _job_coef, 0, _party, _ai(), _basics, _party_shield, _party_tank, _party_heal)
		_scale_power(heroes, _power_mul)
		_scale_hero_atk(heroes)
		_apply_memory(heroes, floor)
		var rng := RandomNumberGenerator.new()
		rng.seed = floor
		var out := FonsFloorRun.simulate(rng, _monsters, _biomes, floor, 0, heroes, _cap,
			_band_mul_for(_band_hp, floor), _band_mul_for(_band_atk, floor))
		var biome := FonsEncounter.biome_for_floor(_biomes, floor)
		var hp_sum := 0
		for e in out["enemies"]:
			hp_sum += int(e.get("maxHp", 0))
		var alive := 0
		for h in heroes:
			if bool(h.get("alive", false)):
				alive += 1
		var plan := FonsEncounter.plan_for_floor(_monsters, _biomes, floor)
		var center := FonsEncounter.center_tier_for_floor(_biomes, floor, plan["candidates"])
		# 편성 tier 는 전투 유닛이 아니라 편성 원본에서 읽는다 (전투 유닛에는 tier 가 없다).
		var tiers: Array = []
		for m in FonsEncounter.build_party(_monsters, _biomes, floor, 0):
			tiers.append(int(m.get("tier", 0)))
		tiers.sort()
		print("| %d | %s | %d | %d/4 | %s | %.2f | %d | %s | %d | %d |" % [
			floor, "면제" if String(out["winner"]) == "none" else String(out["winner"]), int(out["turns"]), alive,
			String(biome.get("id", "?")), FonsScaling.biome_mult(biome),
			center, "/".join(tiers.map(func(v): return str(v))),
			out["party_size"], hp_sum,
		])


func _band_muls(text: String) -> Array:
	## `111-120:0.8,121-130:1.0` → [[111, 120, 0.8], [121, 130, 1.0]].
	## `_pairs` 와 같은 태도 — 잘못된 조각은 버리고, 하나도 못 읽으면 실패로 남긴다.
	var out: Array = []
	for part in text.split(","):
		var kv := String(part).split(":")
		if kv.size() != 2:
			continue
		var ends := String(kv[0]).split("-")
		if ends.size() != 2:
			continue
		var lo := int(ends[0])
		var hi := int(ends[1])
		if hi < lo:
			continue
		out.append([lo, hi, float(kv[1])])
	if out.is_empty():
		push_error("대역 배율 인자를 읽지 못했다: %s" % text)
	return out


func _band_mul_for(bands: Array, floor: int) -> float:
	## 그 층에 걸린 대역 배율의 곱. 비어 있으면 1.0 — 정본 그대로다.
	var mul := 1.0
	for b in bands:
		if floor >= int(b[0]) and floor <= int(b[1]):
			mul *= float(b[2])
	return mul


func _pairs(text: String) -> Dictionary:
	## `id:mult,id:mult` → {id: mult}. 잘못된 조각은 버린다 — 측정 도구라 조용히 넘어가면 안 되므로
	## 하나도 못 읽으면 실패로 남긴다.
	var out := {}
	for part in text.split(","):
		var kv := String(part).split(":")
		if kv.size() == 2:
			out[String(kv[0])] = float(kv[1])
	if out.is_empty():
		push_error("배율 인자를 읽지 못했다: %s" % text)
	return out


func _apply_scales() -> void:
	## 측정용 배율을 **메모리 사본**에만 건다. 원본 JSON 은 안 건드린다.
	for m in _monsters.get("monsters", []):
		var mul := float(_atk_scales.get(String(m.get("id", "")), 1.0))
		if is_equal_approx(mul, 1.0):
			continue
		var stats: Dictionary = m.get("stats", {})
		for key in ["atk", "mag"]:
			if stats.has(key):
				stats[key] = maxi(1, int(roundf(float(stats[key]) * mul)))
	for m in _monsters.get("monsters", []):
		var hp_mul := float(_hp_scales.get(String(m.get("id", "")), 1.0))
		if is_equal_approx(hp_mul, 1.0):
			continue
		var stats: Dictionary = m.get("stats", {})
		if stats.has("hp"):
			stats["hp"] = maxi(1, int(roundf(float(stats["hp"]) * hp_mul)))
	for group in _biomes.get("groups", []):
		for b in group.get("biomes", []):
			var mul := float(_biome_scales.get(String(b.get("id", "")), 1.0))
			if is_equal_approx(mul, 1.0):
				continue
			var diff: Dictionary = b.get("difficulty", {})
			diff["mult"] = float(diff.get("mult", 1.0)) * mul
			b["difficulty"] = diff


func _tree_with_jobs(tree: Dictionary, cap: int) -> Dictionary:
	## 측정용 사본 — 키워드 직업을 앞에서 cap 개만 남기고 나머지의 키워드를 비운다.
	## `keyword_jobs` 가 cap 개만 돌려주므로, 5인 파티의 남는 자리는 직업 없이 만들어진다.
	var out := tree.duplicate(true)
	var seen := 0
	for job in out.get("jobs", []):
		if job.get("keywords", []).is_empty():
			continue
		seen += 1
		if seen > cap:
			job["keywords"] = []
	return out


func _inversions(rows: Array) -> int:
	## 층이 깊어지는데 승수가 늘어나는 구간의 수. 0 이면 단조 감소다.
	var n := 0
	for i in rows.size() - 1:
		if int(rows[i]["w"]) < int(rows[i + 1]["w"]):
			n += 1
	return n


func _measure(job_tree: Dictionary, equipment: Dictionary,
		hp_knob: float = 1.0, max_turns: int = FonsFloorRun.MAX_TURNS,
		job_coef: Dictionary = {}) -> Array:
	## 대역 순서대로 한 줄씩. Dictionary 키에 Array 를 쓰지 않는다 — 조회가 엉뚱한 줄로 갈 수 있다.
	var rows: Array = []
	for i in BANDS.size():
		rows.append({"w": 0, "l": 0, "d": 0, "n": 0, "turns": 0.0})
	for floor in range(1, 131):
		var row: Dictionary = rows[_band_index(floor)]
		for t in _trials:
			# 시드는 층과 회차로 가른다 — 같은 층을 다른 판으로 보되 조건은 그대로다.
			var heroes := FonsRunState.heroes_from(_races, job_tree, equipment, _grade,
				_level_for(floor), _hero_seed(floor + t * 7919), job_coef, 0, _party, _ai(), _basics, _party_shield, _party_tank, _party_heal)
			_equip(heroes)
			_scale_hero_atk(heroes)
			_apply_memory(heroes, floor)
			var rng := RandomNumberGenerator.new()
			rng.seed = floor + t * 104729
			var out := FonsFloorRun.simulate(rng, _monsters, _biomes, floor, 0, heroes, max_turns,
				hp_knob * _band_mul_for(_band_hp, floor), _band_mul_for(_band_atk, floor))
			_match_row(row, out)
	return rows


func _match_row(row: Dictionary, out: Dictionary) -> void:
	## 한 판을 대역 줄에 더한다. `--trials` 가 1 이면 예전과 같은 값이다.
	## 턴은 회차로 나눠 더한다 — 대역 평균이 "한 판 평균"으로 남는다.
	match String(out["winner"]):
		"ally":
			row["w"] = int(row["w"]) + 1
		"enemy":
			row["l"] = int(row["l"]) + 1
		"none":
			row["n"] = int(row["n"]) + 1
		_:
			row["d"] = int(row["d"]) + 1
	row["turns"] = float(row["turns"]) + float(out["turns"]) / float(_trials)


func _hero_delta() -> String:
	## 성장 축이 숫자로 얼마나 오르는지 — 승패가 그대로여도 이 줄이 효과의 크기를 말한다.
	var bare: Dictionary = FonsRunState.heroes_from(_races, {}, {}, 5, 130, 1)[0]
	var grown: Dictionary = FonsRunState.heroes_from(_races, _job_tree, _equipment, 5, 130, 1, _job_coef, 0, FonsRunState.PARTY_SIZE, {}, _basics)[0]
	return "HP %d→%d (%+.1f%%) · ATK %.0f→%.0f (%+.1f%%) · DEF %.0f→%.0f (%+.1f%%)" % [
		int(bare["maxHp"]), int(grown["maxHp"]),
		100.0 * (float(grown["maxHp"]) / float(bare["maxHp"]) - 1.0),
		float(bare["atk"]), float(grown["atk"]),
		100.0 * (float(grown["atk"]) / float(bare["atk"]) - 1.0),
		float(bare["def"]), float(grown["def"]),
		100.0 * (float(grown["def"]) / maxf(1.0, float(bare["def"])) - 1.0),
	]


func _ai() -> Dictionary:
	## 브레인이 읽는 묶음 — 성격·직업 프로필·카탈로그·레거시 융합 힌트.
	if _no_ai:
		return {}
	return {"personalities": _personalities, "profiles": _profiles,
		"catalog": {"skills": _catalog}, "legacy_pairs": _legacy_pairs}


func _band_index(floor: int) -> int:
	for i in BANDS.size():
		if floor >= int(BANDS[i][0]) and floor <= int(BANDS[i][1]):
			return i
	return BANDS.size() - 1


func _sum(rows: Array, key: String) -> int:
	var n := 0
	for row in rows:
		n += int(row[key])
	return n


func _load(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/%s" % name, FileAccess.READ)
	if f == null:
		push_error("데이터를 열지 못했다: %s" % name)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
