extends SceneTree
## Bots must not answer before the table has finished animating the last move (OfflineGame.anim_gate_ms).
## Also checks the safety nets: no gate = old pacing, and a stale far-future gate cannot stall the game.
##   godot --headless --path apps/mobile -s res://scripts/tests/test_bot_gate.gd

const OfflineGame := preload("res://scripts/game/offline_game.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")

var failures: Array = []


func _init() -> void:
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


## Starts a game, makes the human's first legal move (a bot opens some seeds: skip those) and returns the seconds
## until the next update, i.e. until a bot answered. `gate_in` s ahead is the gate set right before the human acts.
func _bot_answer_time(gate_in: float) -> float:
	var g: Node = OfflineGame.new()
	root.add_child(g)
	g.bot_delay = 0.1
	g.bot_delay_max = -1.0
	g.start(2, "normal", 7)
	# Let any opening bot move finish so it is the human's turn.
	var guard := 0
	while not g.is_human_turn() and guard < 100:
		await create_timer(0.05).timeout
		guard += 1
	var acts: Array = CardEngine.legal_actions(g.state, "you")
	var act: Dictionary = acts[0]
	var t0 := Time.get_ticks_msec()
	g.anim_gate_ms = t0 + int(gate_in * 1000.0)
	var answered := [-1.0]
	g.updated.connect(func(_e): if answered[0] < 0.0: answered[0] = float(Time.get_ticks_msec() - t0) / 1000.0)
	match act["type"]:
		"play": g.human_play(act["cardId"], "H")
		"draw": g.human_draw()
		_: g.human_take_penalty()
	answered[0] = -1.0 # ignore the human's own update; wait for the next one
	var waited := 0.0
	while answered[0] < 0.0 and waited < 8.0:
		await create_timer(0.05).timeout
		waited += 0.05
	g.queue_free()
	return answered[0]


func _run() -> void:
	await process_frame
	var free := await _bot_answer_time(0.0)
	_check(free >= 0.0 and free < 0.6, "no gate: the bot answers at its own pace (%.2f s)" % free)
	var gated := await _bot_answer_time(1.2)
	_check(gated >= 1.2, "gated: the bot waits for the animation to finish (%.2f s, gate 1.2 s)" % gated)
	var stale := await _bot_answer_time(600.0)
	_check(stale >= 0.0 and stale < 6.0, "stale far-future gate cannot stall the bots (%.2f s)" % stale)

	if failures.is_empty():
		print("PASS: bot gate (free %.2f s, gated %.2f s, stale %.2f s)" % [free, gated, stale])
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)
