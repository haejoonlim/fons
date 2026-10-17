extends Node
## Canonical game state. Ports fons-web-ver/app/src/game.ts state machine.
## title -> summon -> combat -> result -> estate -> tower loop.

enum Phase { TITLE, SUMMON, COMBAT, RESULT, ESTATE, TOWER }

var phase: Phase = Phase.TITLE
var run_seed: int = 0
var pull_count: int = 0
var gold: int = 0

signal phase_changed(next: Phase)

func set_phase(next: Phase) -> void:
	phase = next
	phase_changed.emit(next)

func reset_run(seed: int) -> void:
	run_seed = seed
	pull_count = 0
	gold = 0
	set_phase(Phase.TITLE)
