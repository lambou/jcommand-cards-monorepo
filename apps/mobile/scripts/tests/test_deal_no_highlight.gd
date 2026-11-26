extends SceneTree
## While the opening deal runs, your cards must not be lifted/dimmed as playable: they light up only once the
## starting card has landed.
##   godot --headless --path apps/mobile -s res://scripts/tests/test_deal_no_highlight.gd

const Table := preload("res://scripts/ui/table.gd")
const Settings := preload("res://scripts/game/settings.gd")
const DealPlan := preload("res://scripts/game/deal_plan.gd")

var failures: Array = []


func _init() -> void:
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _run() -> void:
	await process_frame
	Settings.load_settings()
	Settings.deal_style = DealPlan.FLY
	Settings.reduce_motion = false
	var t: Control = Table.new()
	root.add_child(t)
	await process_frame
	t.bots = 2
	t.difficulty = "normal"
	t._build()
	t.game.bot_delay = 99.0
	t.game.bot_delay_max = -1.0
	t.game.start(2, "normal", 3) # seed 3: you open, so the engine says "your turn" from the first frame

	var lit_during := 0
	var frames_during := 0
	var elapsed := 0.0
	while t._dealing and elapsed < 10.0:
		await process_frame
		elapsed += root.get_process_delta_time()
		frames_during += 1
		if not t._dealing:
			break # the landing frame itself: lighting up here is the point
		for v in t.hand_views:
			if v.lifted or v.dimmed:
				lit_during += 1
	_check(frames_during > 5, "the deal ran for several frames (%d)" % frames_during)
	_check(lit_during == 0, "no hand card is lifted/dimmed during the deal (%d flagged frames)" % lit_during)
	_check(not t._dealing, "the deal finished")
	await process_frame
	var lit_after := 0
	for v in t.hand_views:
		if v.lifted or v.dimmed:
			lit_after += 1
	if t.game.is_human_turn():
		_check(lit_after == t.hand_views.size() and lit_after > 0, "after the deal every card is lifted or dimmed (%d/%d)" % [lit_after, t.hand_views.size()])

	if failures.is_empty():
		print("PASS: no highlight during the deal (%d frames), lit after (%d cards)" % [frames_during, lit_after])
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)
