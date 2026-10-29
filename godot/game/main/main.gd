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
const EDICT_SCENE := "res://game/ui/edict/edict.tscn"
## 101층 기억 배분 — 한 번뿐인 선택이라 칙령처럼 HUD 위에 얹고 세계를 멈춘다.
const MEMORY_SCENE := "res://game/ui/memory/memory.tscn"
## 영지 시계를 몇 초마다 보는가. 정산 자체는 하루 한 번이라 이 값은 반응 속도만 정한다.
const CLOCK_STEP := 1.0
## 불만 게이지 색 — 평시는 파티 패널 경보와 같은 호박색, 경고는 붉은색.
const UNREST_CALM := Color(1.0, 0.72, 0.25, 1.0)
const UNREST_WARN := Color(0.90, 0.38, 0.32, 1.0)

var _field: FonsFieldState = null
var _estate: FonsEstate = null
var _view: FonsView = null
var _edict: Control = null
var _memory: Control = null
## 엔딩 화면을 이미 보여 줬나 — 기록(`ending`)은 저장에 남지만 화면은 한 번이다.
var _ending_shown := false
var _move_dir := Vector2.ZERO
var _clock_accum := 0.0

@onready var _floor_label: Label = $Hud/FloorLabel
@onready var _hint_label: Label = get_node_or_null("Hud/HintLabel")
@onready var _log_label: Label = $Hud/LogLabel
## 불만 게이지 — 민심 25 미만에서만 뜬다 (04 §3.5·§3.12). 색은 파티 패널 경보와 같은 계열.
@onready var _unrest: ColorRect = get_node_or_null("Hud/UnrestGauge")
@onready var _unrest_fill: ColorRect = get_node_or_null("Hud/UnrestGauge/Fill")
@onready var _unrest_label: Label = get_node_or_null("Hud/UnrestLabel")
## 엔딩 화면 — 130층 격파 순간에만 뜬다. 구성은 씬이 갖고, 여기는 채우고 닫는다.
@onready var _ending_panel: Control = get_node_or_null("Hud/EndingPanel")
@onready var _ending_line: Label = get_node_or_null("Hud/EndingPanel/Line")


func _ready() -> void:
	var data := _data_bundle()
	_estate = FonsEstate.new()
	_estate.start(data["estate"], FonsFieldState.START_FLOOR)
	_field = FonsFieldState.new()
	if not _restore_if_asked(data):
		_field.start(data["races"], data["monsters"], data["biomes"], SEED,
			FonsFieldState.START_FLOOR, data["job_tree"], data["equipment"],
			data["job_coef"], data["ai"], data["basics"])
	_sync_estate_floor()
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
	# 칙령 화면은 HUD 위에 얹는다 — CanvasLayer 순서상 마지막 자식이 가장 위에 그려진다.
	_edict = (load(EDICT_SCENE) as PackedScene).instantiate()
	$Hud.add_child(_edict)
	_edict.chosen.connect(_on_edict_chosen)
	_edict.closed.connect(_on_edict_closed)
	_memory = (load(MEMORY_SCENE) as PackedScene).instantiate()
	$Hud.add_child(_memory)
	_memory.chosen.connect(_on_memory_chosen)
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
	## 걷는 동안만 아바타가 움직인다. 동료는 플레이어가 서 있어도 계속 움직인다 —
	## 그래서 매 프레임 `tick` 을 돌리고, 실제로 움직였을 때만 화면을 민다.
	if _field == null:
		return
	var moved := _field.tick(delta)
	if _move_dir != Vector2.ZERO:
		_field.walk(_move_dir, delta)
		moved = true
	_tick_estate(delta)
	if moved:
		_push()


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
	_sync_estate_floor()
	var out := _estate.note_floor_cleared()
	if bool(out["strike_started"]):
		_log("파업 — 전 생산 정지 %d층" % int(out["strike"]))
	elif bool(out["strike_ended"]):
		_log("파업 끝 — 생산 재개")
	if int(out["delta"]) != 0:
		_log("민심 %+d" % int(out["delta"]))


func _sync_estate_floor() -> void:
	## 영지 층은 런 층의 파생이다 — 세이브에 따로 넣지 않고 필드 층에서 맞춘다 (ADR 0008).
	## 수확 배율(`1+floor/50`)과 칙령 10층 해금이 둘 다 이 값을 읽는다.
	if _estate != null and _field != null:
		_estate.floor = _field.floor


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
			# 문턱층(126~130)은 조우 지점이 없다 — F 가 문지기를 연다.
			if _field.contact_index() >= 0 or _field.gatekeeper_ready():
				var out := _field.engage()
				# 첫 격파 전리품 — 지갑에 넣는 것은 여기다. 영혼·exp 는 받을 곳이 아직 없다.
				if bool(out.get("first_clear", false)):
					GameState.gold += int(Dictionary(out.get("loot", {})).get("gold", 0))
			elif _field.mission_done():
				if _field.next_floor():
					_note_floor_cleared()
					_save()
		"retreat":
			_move_dir = Vector2.ZERO
			# 필드의 R 은 후퇴다. 다만 전멸한 뒤와 엔딩 화면 앞에서는 힌트가 약속한 대로 재시작이다.
			if _ending_panel != null and _ending_panel.visible:
				_restart_run()
			elif _field.winner.is_empty():
				_field.retreat()
			else:
				_restart_run()
		"switch_hero":
			# 조종을 바꾸면 범위의 중심만 옮긴다 — 성향은 각자 브레인에 남는다.
			_move_dir = Vector2.ZERO
			_field.switch_hero(int(payload.get("index", 0)))
		"edict":
			# 칙령 화면 (04 §3.7). 고르는 것은 화면, 판정은 `FonsEstate` 다.
			_toggle_edict()
			return
		"next_floor":
			# 예전 화면·테스트가 쓰던 의도 — 미션을 끝냈을 때만 실제로 넘어간다.
			if _field.next_floor():
				_note_floor_cleared()
				_save()
		"restart":
			_move_dir = Vector2.ZERO
			_restart_run()
		_:
			return
	_push()


func _restart_run() -> void:
	## 새 런 — 엔딩 화면도 닫고 처음 층으로 돌린다.
	_field.restart()
	_sync_estate_floor()
	_estate.reset_decree_cooldown()
	if _ending_panel != null:
		_ending_panel.visible = false
	if _memory != null:
		_memory.hide()
	get_tree().paused = false
	_ending_shown = false


func _push() -> void:
	if _view != null:
		_view.apply(_field.snapshot())
	_update_hud()
	_sync_ending_panel()
	_sync_memory_panel()


func _sync_memory_panel() -> void:
	## 101층에 처음 들어선 순간 한 번 — 세계를 멈추고 배분을 받는다.
	## 나누면 `memory_pending()` 이 거짓이라 다시 묻지 않는다.
	if _memory == null or _field == null or _memory.visible:
		return
	if not _field.memory_pending():
		return
	_memory.open(5)
	get_tree().paused = true


func _on_memory_chosen(attack: int, guard: int) -> void:
	## 101층 배분 — 규칙은 심이 지고, 화면은 고른 숫자만 준다.
	## 화면은 먼저 닫는다 — 배분이 거절돼도 세계가 멈춘 채로 남으면 안 된다.
	if _memory != null:
		_memory.hide()
	get_tree().paused = false
	if _field == null or not _field.allocate_memory(attack, guard):
		return
	_save()
	_push()


func _sync_ending_panel() -> void:
	## 130층을 격파한 순간에만 뜬다. 기록은 세이브에 남지만 화면은 다시 띄우지 않는다.
	## (재시작하면 층이 1로 내려가므로 저장된 기록만으로는 뜨지 않는다.)
	if _ending_panel == null or _field == null:
		return
	if _ending_shown or not _field.ending or _field.floor < FonsFieldState.MAX_FLOOR:
		return
	_ending_shown = true
	if _ending_line != null:
		_ending_line.text = _ending_summary()
	_ending_panel.visible = true


func _ending_summary() -> String:
	## 마지막 판 요약 — 이름 · 턴 · 생존 · 전리품. 판 기록이 없으면(이어하기) 이름만 적는다.
	var last: Dictionary = _field.last_gatekeeper
	# 이름은 그 판의 기록에서 먼저 읽는다 — 이어하기로 들어와도 누구와 싸웠는지가 남는다.
	var shown := String(last.get("name", ""))
	if shown.is_empty():
		shown = _field.gatekeeper_name()
	if shown.is_empty():
		shown = "마지막 문지기"
	if last.is_empty():
		return "%s%s 지나 이데아 문턱을 지났다" % [shown, _object_particle(shown)]
	var parts: Array = ["%s — %d턴" % [shown, int(last.get("turns", 0))]]
	parts.append("생존 %d/%d" % [int(last.get("survivors", 0)), _field.heroes.size()])
	var loot: Dictionary = last.get("loot", {})
	parts.append("전리품 없음" if loot.is_empty() else "gold %d" % int(loot.get("gold", 0)))
	return " · ".join(parts)


func _object_particle(word: String) -> String:
	## 목적격 조사 — 마지막 글자에 받침이 있으면 `을`, 없으면 `를`.
	## 이어하기 엔딩 문장이 이름을 그대로 붙여 `무문의 파수병를 지나` 로 나오던 것을 고친다.
	## 이름이 한글이 아니면 `를` 로 둔다 (문지기 이름은 `data/` 의 한글이다).
	if word.is_empty():
		return "를"
	var code := word.unicode_at(word.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return "를"
	return "을" if (code - 0xAC00) % 28 != 0 else "를"


func _update_hud() -> void:
	_update_unrest()
	if _floor_label != null:
		var strike := ""
		if _estate != null and _estate.is_striking():
			strike = " · 파업 %d층" % _estate.strike_floors_left
		if _estate != null:
			# 켜진 칙령은 세금·자연증가를 계속 바꾼다 — 화면에 남기지 않으면 왜 수치가 다른지 알 수 없다.
			# 2칸 시대에는 둘 다 적는다 (ADR 0011).
			var names: Array = []
			for entry in _estate.active_decrees():
				names.append(String(entry.get("name_ko", "")))
			if not names.is_empty():
				strike += " · 칙령 %s" % ", ".join(names)
		_floor_label.text = "%d층 · 섬 %d일 · %s · 생존 %d/%d · %dG · 식량 %d · 민심 %d%s" % [
			_field.floor, _estate.last_settled_day if _estate != null else 1,
			_field.floor_progress(),
			_field.party_alive(), _field.heroes.size(), GameState.gold,
			int(_estate.stores.get("food", 0)) if _estate != null else 0,
			_estate.morale if _estate != null else 50, strike
		]
	if _hint_label != null:
		var hint := _field.hint()
		if _estate != null and _estate.is_striking():
			# 파업은 전 생산이 멈춘 상태다 — 나갈 길을 그 자리에서 말한다 (04 §3.12).
			hint += " · C — 칙령"
		_hint_label.text = hint
	if _log_label != null:
		_log_label.text = "\n".join(_field.log_lines)


func _toggle_edict() -> void:
	## C — 칙령 화면. 열려 있으면 닫는다. 목록과 현재 값은 영지가 준다.
	## 고르는 동안은 세계를 멈춘다 — 화면이 위에 떠 있는데 뒤에서 층이 깨지면 안 된다.
	if _edict == null or _estate == null:
		return
	if _edict.visible:
		_edict.hide()
		get_tree().paused = false
		return
	# 칸 번호의 기준은 칸 위치다 — 빈 칸을 건너뛴 목록을 넘기면 2번 칸이 1번으로 보인다 (ADR 0011).
	_edict.open(_estate.decrees(), _estate.slot_ids(), _edict_note(),
		_estate.slot_count(), _estate.cooldown_left() > 0 and not _estate.is_striking())
	get_tree().paused = true


func _edict_note() -> String:
	## 화면 위 한 줄 — 지금 무엇이 막히는지, 혹은 왜 지금 바꿀 만한지.
	var gate := _estate.can_set_decree()
	if not bool(gate["ok"]):
		return String(gate["reason"])
	if _estate.is_striking():
		return "파업 중 — 칙령을 바꾸면 파업이 끝난다"
	if _estate.slot_count() > 1:
		return "2칸 — 칸을 골라 바꾼다"
	return "1칸 — 하나만 켜진다"


func _on_edict_chosen(id: String, slot: int) -> void:
	var out := _estate.set_decree(id, slot)
	if not bool(out["ok"]):
		_edict.set_note(String(out["reason"]))   # 화면에 이유를 남기고 다시 고르게 둔다
		return
	_edict.hide()
	get_tree().paused = false
	_log(String(out["line"]))
	_save()
	_push()


func _on_edict_closed() -> void:
	get_tree().paused = false
	_push()


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
