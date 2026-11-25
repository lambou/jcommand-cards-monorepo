extends SceneTree
## The first card of a deal used to leave ~0.14 s before the dealer's throw: the game's first frame is a long hitch
## (loading), the card's timer swallowed it and the hand's tween, created a frame later, did not. Now the hand's own
## throw launches each card, so the two cannot drift apart. This stalls the first frame on purpose (real time, so
## run it WITHOUT --fixed-fps) and checks every card still leaves in the frame its throw starts.
##   godot --headless --path apps/mobile -s res://scripts/tests/test_deal_hitch.gd

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
	Settings.deal_style = DealPlan.DEALER
	Settings.hand_you = true
	Settings.hand_bots = true
	Settings.reduce_motion = false
	var t: Control = Table.new()
	root.add_child(t)
	await process_frame
	t.bots = 2
	t.difficulty = "normal"
	t._build()
	t.game.bot_delay = 99.0
	t.game.bot_delay_max = -1.0
	t.game.start(2, "normal", 1)
	OS.delay_msec(160) # the loading hitch: the next frame's delta is ~0.16 s

	var elapsed := 0.0
	var prev_flick := 0.0
	var was_rising := false
	var throws: Array = []
	var launches: Array = []
	var seen := {}
	while elapsed < 6.0:
		await process_frame
		elapsed += root.get_process_delta_time()
		var rising: bool = t.hand3d.flick > prev_flick + 0.01
		if rising and not was_rising:
			throws.append(elapsed)
		was_rising = rising
		prev_flick = t.hand3d.flick
		for f in t.fx.get_children():
			var fid: int = f.get_instance_id()
			if not seen.has(fid) and not f.has_meta("standin"):
				seen[fid] = true
				launches.append(elapsed)
	_check(throws.size() >= 3 and launches.size() >= 3, "several cards were thrown and launched (%d / %d)" % [throws.size(), launches.size()])
	var worst := 0.0
	for i in mini(throws.size(), launches.size()):
		worst = maxf(worst, absf(float(throws[i]) - float(launches[i])))
	# One frame of slack (a frame is up to ~0.05 s on a slow machine), far below the old 0.14 s.
	_check(worst < 0.08, "every card leaves with its throw, even over a loading hitch (worst gap %.3f s)" % worst)
	_check(float(launches[0]) > 0.5, "the first card is not launched before the hand has arrived (%.2f s)" % float(launches[0]))

	if failures.is_empty():
		print("PASS: deal over a loading hitch (worst gap %.3f s)" % worst)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)
