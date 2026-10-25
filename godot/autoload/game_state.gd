extends Node
## Canonical game state. Ports fons-web-ver/app/src/game.ts state machine.
## title -> summon -> combat -> result -> estate -> tower loop.

enum Phase { TITLE, SUMMON, COMBAT, RESULT, ESTATE, TOWER }

var phase: Phase = Phase.TITLE
var run_seed: int = 0
var pull_count: int = 0
var gold: int = 0
## 타이틀이 정한다 — "new" 또는 "continue". 메인 씬은 이것만 보고 불러올지 결정한다.
var start_mode := "new"

signal phase_changed(next: Phase)

func set_phase(next: Phase) -> void:
	phase = next
	phase_changed.emit(next)

func reset_run(seed: int) -> void:
	run_seed = seed
	pull_count = 0
	gold = 0
	set_phase(Phase.TITLE)


func to_save() -> Dictionary:
	## 지갑만 저장한다 — `phase` 는 화면 상태라 불러오면 타이틀에서 다시 시작한다.
	return {"gold": gold, "pull_count": pull_count}


func from_save(saved: Dictionary) -> void:
	gold = int(saved.get("gold", gold))
	pull_count = int(saved.get("pull_count", pull_count))
