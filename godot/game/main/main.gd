extends Node
## 조립 루트 — 심 스냅샷을 뷰에 밀어 넣는 유일한 곳.
##
## 심은 `FonsFieldState` 다 — 1층 탐험 필드에서 시작해 걷고, 접촉한 조우와 싸우고,
## 미션을 끝내면 다음 층으로 간다. 전투 판 자체는 `FonsFloorRun`/`FonsBattle` 그대로다.
##
## 이 파일은 2D/3D 를 모른다. `FonsViewFactory` 가 ProjectSettings(fons/view_mode)를 읽어 뷰를 정한다(R4).
## 입력은 뷰가 `intent` 로 되돌리고, 여기서 심에 반영한 뒤 스냅샷을 다시 민다.
##
## 이동은 **매 프레임** 밀어야 해서 `_move_dir` 를 들고 `_process` 에서 걷는다.
## 뷰는 키를 눌렀다 뗄 때마다 `move` 를 보내고, 이 파일은 규칙을 모른 채 방향만 넘긴다.
##
## 세이브 (2026-10-24)
## ------------------
## 타이틀이 `GameState.start_mode` 로 "새로 시작" 과 "이어하기" 를 가른다. 불러오기는
## 필드(층·영웅)와 영지 시계를 되살리고, 저장은 층을 깨거나 섬일이 바뀌거나 창을 닫을 때 돈다.
## 전투 도중은 저장하지 않는다 — 반쯤 진행한 턴을 복원하면 난수 순서가 어긋난다 (설계 §6).

const SEED := 20261020
## 영지 시계를 몇 초마다 보는가. 정산 자체는 하루 한 번이라 이 값은 반응 속도만 정한다.
const CLOCK_STEP := 1.0
## 불만 게이지 색 — 평시는 파티 패널 경보와 같은 호박색, 경고는 붉은색.
const UNREST_CALM := Color(1.0, 0.72, 0.25, 1.0)
const UNREST_WARN := Color(0.90, 0.38, 0.32, 1.0)

var _field: FonsFieldState = null
var _estate: FonsEstate = null
var _view: FonsView = null
var _move_dir := Vector2.ZERO
var _clock_accum := 0.0

@onready var _floor_label: Label = $Hud/FloorLabel
@onready var _hint_label: Label = get_node_or_null("Hud/HintLabel")
@onready var _log_label: Label = $Hud/LogLabel
## 불만 게이지 — 민심 25 미만에서만 뜬다 (04 §3.5·§3.12). 색은 파티 패널 경보와 같은 계열.
@onready var _unrest: ColorRect = get_node_or_null("Hud/UnrestGauge")
@onready var _unrest_fill: ColorRect = get_node_or_null("Hud/UnrestGauge/Fill")
@onready var _unrest_label: Label = get_node_or_null("Hud/UnrestLabel")


func _ready() -> void:
	var data := _data_bundle()
	_estate = FonsEstate.new()
	_estate.start(data["estate"], FonsFieldState.START_FLOOR)
	_field = FonsFieldState.new()
	if not _restore_if_asked(data):
		_field.start(data["races"], data["monsters"], data["biomes"], SEED,
			FonsFieldState.START_FLOOR, data["job_tree"], data["equipment"],
			data["job_coef"], data["ai"], data["basics"])
	# 시작하자마자 한 번 본다 — 미접속으로 지난 날이 있으면 여기서 한 번만 건너뛴다.
	_apply_settlement(_estate.settle(0, GameState.gold, _field.heroes))

	_view = FonsViewFactory.create()
	if _view == null:
		push_error(
			"뷰를 만들지 못했다 (mode=%s, available=%s)"
			% [FonsViewFactory.configured_mode(), FonsViewFactory.available_modes()]
		)
		return
	_view.intent.connect(_on_intent)
	add_child(_view)
	_view.mount(_field.snapshot())
	_push()


func _data_bundle() -> Dictionary:
	## DataLoader 를 한 번만 읽어 아래로 넘긴다 — 시험과 게임이 같은 묶음을 쓴다.
	return {
		"races": DataLoader.load_json("races.json"),
		"monsters": DataLoader.get_monsters(),
		"biomes": DataLoader.get_biomes(),
		"job_tree": DataLoader.load_json("job_tree.json"),
		"equipment": DataLoader.load_json("equipment.json"),
		"job_coef": DataLoader.load_json("job_coef.json"),
		"ai": {
			"personalities": DataLoader.load_json("personalities.json"),
			"profiles": DataLoader.load_json("job_ai_profiles.json"),
			"catalog": DataLoader.load_json("skills_catalog.json"),
			"legacy_pairs": DataLoader.load_json("fusion_pairs.json"),
		},
		"basics": DataLoader.load_json("basic_attacks.json"),
		"estate": DataLoader.load_json("estate.json"),
	}


func _restore_if_asked(data: Dictionary) -> bool:
	## 타이틀에서 "이어하기" 를 눌렀을 때만. 없는 파일·손상·더 새 판이면 새 게임으로 떨어진다.
	if String(GameState.start_mode) != "continue":
		return false
	var loaded := SaveManager.load_payload()
	if not bool(loaded["ok"]):
		return false
	var payload: Dictionary = loaded["data"]
	var run: Dictionary = payload.get("run", {})
	_field.configure(data["races"], data["monsters"], data["biomes"],
		int(String(run.get("seed", str(SEED)))), FonsFieldState.START_FLOOR,
		data["job_tree"], data["equipment"], data["job_coef"], data["ai"], data["basics"])
	if not _field.restore(run):
		return false
	_estate.from_save(payload.get("estate", {}))
	GameState.from_save(payload.get("wallet", {}))
	return true


func _process(delta: float) -> void:
	## 뷰가 방향을 보내는 동안만 걷는다. 벽·필드 밖은 `FonsExplore.walk` 가 자른다.
	if _field == null:
		return
	if _move_dir != Vector2.ZERO:
		_field.walk(_move_dir, delta)
		_push()
	_tick_estate(delta)


func _tick_estate(delta: float) -> void:
	## 섬일 시계 — 접속 중에만 돈다. 미접속 동안은 멈춰 있다가 돌아온 첫 틱에 한 번만 정산한다.
	## (`FonsIslandClock.tick` 이 밀린 날을 건너뛴다.)
	if _estate == null or _field == null:
		return
	_clock_accum += delta
	if _clock_accum < CLOCK_STEP:
		return
	_clock_accum = 0.0
	# 일과 → 정산. 순서를 바꾸면 그날 번 식량을 못 먹고 아사가 먼저 난다 (estate.gd 참조).
	var settled := _estate.settle(0, GameState.gold, _field.heroes)
	if not bool(settled["settle"]):
		return
	_apply_settlement(settled)
	_save()
	_push()


func _note_floor_cleared() -> void:
	## 층 클리어 — 식량이 바닥이면 민심이 준다 (04 §3.14 "식량 0: 즉시 민심 -5/층").
	## 정산(섬일)과 주기가 다른 이유는 정본이 두 주기를 나눠 두었기 때문이다 (§3.4).
	## 파업도 층 단위라 여기서 시작·종료를 알린다 (§3.5 — 민심 20 미만 3층 → 전 생산 정지 5층).
	if _estate == null or _field == null:
		return
	var out := _estate.note_floor_cleared()
	if bool(out["strike_started"]):
		_log("파업 — 전 생산 정지 %d층" % int(out["strike"]))
	elif bool(out["strike_ended"]):
		_log("파업 끝 — 생산 재개")
	if int(out["delta"]) != 0:
		_log("민심 %+d" % int(out["delta"]))


func _log(text: String) -> void:
	## 필드 로그에 한 줄 — 꼬리는 `LOG_TAIL` 만큼만 남긴다.
	_field.log_lines.append(text)
	var from := maxi(0, _field.log_lines.size() - FonsFieldState.LOG_TAIL)
	_field.log_lines = _field.log_lines.slice(from)


func _apply_settlement(settled: Dictionary) -> void:
	## 정산이 돌았을 때만 — 세금·유지비를 지갑에 반영하고 수지 줄을 화면 로그에 붙인다.
	## 식량·인구는 영지가 들고 있으므로 여기서 할 일은 지갑과 표시뿐이다.
	if not bool(settled["settle"]):
		return
	GameState.gold = int(settled["gold"])
	for line in settled["log"]:
		_field.log_lines.append(String(line))
	var from := maxi(0, _field.log_lines.size() - FonsFieldState.LOG_TAIL)
	_field.log_lines = _field.log_lines.slice(from)


func _save() -> void:
	## 저장은 층을 깼을 때·섬일이 바뀌었을 때·창을 닫을 때만. 전투 도중은 없다.
	if _field == null or _estate == null:
		return
	SaveManager.save_payload(FonsSave.to_dict(_field.to_save(), _estate.to_save(), GameState.to_save()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	match String(kind):
		"move":
			_move_dir = payload.get("dir", Vector2.ZERO)
			return
		"interact":
			if _field.contact_index() >= 0:
				_field.engage()
			elif _field.mission_done():
				if _field.next_floor():
					_note_floor_cleared()
					_save()
		"retreat":
			_move_dir = Vector2.ZERO
			_field.retreat()
		"next_floor":
			# 예전 화면·테스트가 쓰던 의도 — 미션을 끝냈을 때만 실제로 넘어간다.
			if _field.next_floor():
				_note_floor_cleared()
				_save()
		"restart":
			_move_dir = Vector2.ZERO
			_field.restart()
		_:
			return
	_push()


func _push() -> void:
	if _view != null:
		_view.apply(_field.snapshot())
	_update_hud()


func _update_hud() -> void:
	_update_unrest()
	if _floor_label != null:
		var strike := ""
		if _estate != null and _estate.is_striking():
			strike = " · 파업 %d층" % _estate.strike_floors_left
		if _estate != null:
			# 켜진 칙령은 세금·자연증가를 계속 바꾼다 — 화면에 남기지 않으면 왜 수치가 다른지 알 수 없다.
			var active := _estate.decree()
			if not active.is_empty():
				strike += " · 칙령 %s" % String(active.get("name_ko", ""))
		_floor_label.text = "%d층 · 섬 %d일 · 탐험 %d/%d · 생존 %d/%d · %dG · 식량 %d · 민심 %d%s" % [
			_field.floor, _estate.last_settled_day if _estate != null else 1,
			_field.explore.cleared, _field.explore.required,
			_field.party_alive(), _field.heroes.size(), GameState.gold,
			int(_estate.stores.get("food", 0)) if _estate != null else 0,
			_estate.morale if _estate != null else 50, strike
		]
	if _hint_label != null:
		var hint := _field.hint()
		_hint_label.text = hint
	if _log_label != null:
		_log_label.text = "\n".join(_field.log_lines)


func _update_unrest() -> void:
	## 불만 게이지 — 민심 25 미만이면 게이지, 15 이하면 경고색 (04 §3.5·§3.12).
	## 세는 것은 파업까지 남은 연속 층이라, 막대와 문구가 같은 수를 말한다.
	if _estate == null or _unrest == null or _unrest_label == null:
		return
	var view := _estate.unrest()
	var on := bool(view["visible"])
	_unrest.visible = on
	_unrest_label.visible = on
	if not on:
		return
	var color := UNREST_WARN if bool(view["warn"]) else UNREST_CALM
	var ratio := float(view["floors"]) / float(view["need"])
	if _unrest_fill != null:
		_unrest_fill.size.x = _unrest.size.x * clampf(ratio, 0.0, 1.0)
		_unrest_fill.color = color
	_unrest_label.add_theme_color_override("font_color", color)
	_unrest_label.text = "%s파업까지 %d층" % [
		"경고 · " if bool(view["warn"]) else "불만 · ",
		int(view["need"]) - int(view["floors"])]
