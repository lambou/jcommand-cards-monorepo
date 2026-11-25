extends SceneTree
## The opening deal in the real table, for every deal style x 1..3 bots, with and without the 3D hand:
##  - every card lands (your hand is complete and visible, the starting card is on the stack, no flyer is left over);
##  - the engine state is untouched by the animation (hand sizes, whose turn it is);
##  - the dealer's hand is only used by the dealer style, comes from the dealer's side (top for a bot, bottom for
##    you) and has left the screen when it is over;
##  - the deal is smooth: the hand and every flying card move continuously (no jumps between frames);
##  - drawing a card afterwards (the glove's other job) still works and leaves nothing behind.
##   godot --headless --fixed-fps 60 --path apps/mobile -s res://scripts/tests/test_deal_table.gd
## (--fixed-fps makes it run as fast as it can with exact frame times; without it it runs in real time.)

const Table := preload("res://scripts/ui/table.gd")
const Settings := preload("res://scripts/game/settings.gd")
const DealPlan := preload("res://scripts/game/deal_plan.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")

const MAX_STEP := 115.0 # px per 1/60 s (6900 px/s): the longest glide (the hand coming in or leaving) stays under this
const MAX_FLYER := 140.0 # a card launched with the table's ease-out flight starts at about 120 px/frame (unchanged flight code)
const TIMEOUT := 40.0

var failures: Array = []
var _cases := 0


func _init() -> void:
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _run() -> void:
	await process_frame
	Settings.load_settings() # first, or the first call into Settings reloads the player's saved settings over ours
	Settings.hand_you = true
	Settings.hand_bots = true
	Settings.reduce_motion = false
	# first = who moves first: 0 = you (a bot deals, its hand comes from the top), 1 = the first bot (you deal, your hand
	# comes from the bottom).
	for style in [DealPlan.FLY, DealPlan.DEALER, DealPlan.PACKETS]:
		for bots in [1, 2, 3]:
			for first in [0, 1]:
				await _case(style, bots, true, first)
	# The dealer style without a hand (reduce motion, or both hand settings off) still deals, with no glove.
	Settings.reduce_motion = true
	await _case(DealPlan.DEALER, 2, false, 0)
	Settings.reduce_motion = false
	Settings.hand_you = false
	Settings.hand_bots = false
	await _case(DealPlan.DEALER, 2, false, 1)
	Settings.hand_you = true
	Settings.hand_bots = true

	if failures.is_empty():
		print("PASS: deal in the table (%d cases)" % _cases)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)


## A game seed where the player at index `first` moves first (the engine picks the first player from the seed).
func _seed_for(bots: int, first: int) -> int:
	var ids: Array = ["you"]
	for i in range(1, bots + 1):
		ids.append("bot%d" % i)
	for seed_value in range(1, 500):
		var g: Dictionary = CardEngine.create_game({"playerIds": ids, "seed": seed_value, "settings": {"finalTurn": true}})
		if int(g["current"]) == first:
			return seed_value
	return 1


## Runs the sim for `seconds` (frame time from the engine, so --fixed-fps or real time both work).
func _case(style: int, bots: int, glove_expected: bool, first: int) -> void:
	_cases += 1
	var tag := "%s, %d bots, %s first%s" % [Settings.DEAL_STYLES[style], bots, "you" if first == 0 else "bot1", 			"" if glove_expected else ", no hand"]
	Settings.deal_style = style
	var t: Control = Table.new()
	root.add_child(t)
	await process_frame
	# Table.start() without its bot timers: the bots must stay out of the way, and we choose who moves first.
	t.bots = bots
	t.difficulty = "normal"
	t._build()
	t.game.bot_delay = 99.0
	t.game.bot_delay_max = -1.0
	t.game.start(bots, "normal", _seed_for(bots, first))
	var st: Dictionary = t.game.state
	var hand_size := int(st["settings"]["handSize"])
	var hands_before := {}
	for p in st["players"]:
		hands_before[p["id"]] = (p["hand"] as Array).size()
	var current_before := int(st["current"])
	var ids: Array = []
	for p in st["players"]:
		ids.append(p["id"])
	var dealer: String = DealPlan.dealer_of(ids, current_before)
	var plan := DealPlan.build(style, DealPlan.turn_order(ids, current_before), hand_size, glove_expected and style == DealPlan.DEALER)

	var hand_seen := false
	var hand_wrong_side := false
	var worst_hand := 0.0
	var worst_info := ""
	var worst_flyer := 0.0
	var flick_starts: Array = [] # times the throw pose began (flick leaves 0)
	var launches: Array = [] # times a dealt card started to move away from the bank
	var prev_flick := 0.0
	var was_rising := false
	var launched := {} # flyer instance id -> true
	var prev_hand := Vector2.INF
	var last_pos := {} # flyer instance id -> its position last frame
	var elapsed := 0.0
	var settled := 0.0
	while elapsed < TIMEOUT:
		await process_frame
		var dt := root.get_process_delta_time()
		elapsed += dt
		var k := 1.0 / 60.0 / maxf(dt, 0.0001) # scales a per-frame step to "per 1/60 s"
		if t.hand3d.visible:
			hand_seen = true
			if t.hand3d._dir != (1.0 if dealer == "you" else -1.0):
				hand_wrong_side = true
			if prev_hand.is_finite():
				var step_len: float = (t.hand3d.pos - prev_hand).length() * k
				if step_len > worst_hand:
					worst_hand = step_len
					worst_info = "t=%.2f from %s to %s follow=%s" % [elapsed, str(prev_hand), str(t.hand3d.pos), str(t.hand3d._follow != null)]
			prev_hand = t.hand3d.pos
		else:
			prev_hand = Vector2.INF
		# a throw begins where the pose starts to rise (it does not fall back to 0 between two quick cards)
		var rising: bool = t.hand3d.flick > prev_flick + 0.01
		if rising and not was_rising:
			flick_starts.append(elapsed)
		was_rising = rising
		prev_flick = t.hand3d.flick
		var seen := {}
		for f in t.fx.get_children():
			if not (f is Control):
				continue
			var fid: int = f.get_instance_id()
			# a launch = a real flyer shows up (not the stand-in card the hand holds)
			if glove_expected and style == DealPlan.DEALER and not launched.has(fid) and not f.has_meta("standin"):
				launched[fid] = true
				launches.append(elapsed)
			if f.visible:
				seen[fid] = true
				if last_pos.has(fid):
					worst_flyer = maxf(worst_flyer, ((f as Control).position - last_pos[fid]).length() * k)
				last_pos[fid] = (f as Control).position
		for gone in last_pos.keys():
			if not seen.has(gone):
				last_pos.erase(gone)
		if t.fx.get_child_count() == 0 and not t.hand3d.visible:
			settled += dt
			if settled > 0.3:
				break
		else:
			settled = 0.0
	_check(elapsed < TIMEOUT, "%s: the deal finishes (%.1f s)" % [tag, elapsed])
	var expected := float(plan["start"]["send"])
	_check(elapsed >= expected, "%s: it does not end before its plan (%.1f s < %.1f s)" % [tag, elapsed, expected])

	# Everything landed.
	_check(t.fx.get_child_count() == 0, "%s: no flyer is left over" % tag)
	var shown := 0
	for hv in t.hand_views:
		if is_instance_valid(hv) and hv.visible:
			shown += 1
	_check(shown == hand_size, "%s: all %d of your cards are shown (%d)" % [tag, hand_size, shown])
	_check(t._floor_held == -1, "%s: the starting card landed on the stack" % tag)
	# The animation never touches the game.
	var st2: Dictionary = t.game.state
	_check(int(st2["current"]) == current_before, "%s: it is still the first player's turn (was %d, now %d)" % [tag, current_before, int(st2["current"])])
	for p in st2["players"]:
		_check((p["hand"] as Array).size() == int(hands_before[p["id"]]), "%s: %s still has the same cards" % [tag, p["id"]])

	# One clock: every card leaves in the frame its throw begins, so the fingers always move with the card.
	if style == DealPlan.DEALER and glove_expected:
		var cards := (hand_size * (bots + 1)) + 1
		_check(flick_starts.size() >= cards - 1, "%s: every card has a throw (%d throws for %d cards)" % [tag, flick_starts.size(), cards])
		var worst_gap := 0.0
		for i in mini(flick_starts.size(), launches.size()):
			worst_gap = maxf(worst_gap, absf(float(flick_starts[i]) - float(launches[i])))
		_check(worst_gap < 0.05, "%s: each card leaves when its throw starts (worst gap %.3f s; throws %s launches %s)" % [tag, worst_gap, str(flick_starts.slice(0, 6)), str(launches.slice(0, 6))])
		_check(launches.size() >= cards - 1, "%s: every card was launched by a throw (%d of %d)" % [tag, launches.size(), cards])

	# The glove: dealer style only, from the dealer's side, gone afterwards, moving smoothly.
	if style == DealPlan.DEALER and glove_expected:
		_check(hand_seen, "%s: the dealer's hand appears" % tag)
		_check(not hand_wrong_side, "%s: the hand comes from the dealer's side (%s)" % [tag, dealer])
	else:
		_check(not hand_seen, "%s: no hand is used" % tag)
	_check(worst_hand < MAX_STEP, "%s: the hand moves smoothly (worst %.0f px/frame, %s)" % [tag, worst_hand, worst_info])
	_check(worst_flyer < MAX_FLYER, "%s: the cards fly smoothly (worst %.0f px/frame)" % [tag, worst_flyer])

	# A fresh deal is recognised as one (a resumed or replayed game is not dealt again).
	_check(t._is_fresh_deal(t.game.state), "%s: the dealt state counts as a fresh deal" % tag)

	# Drawing afterwards: the glove's other job is unaffected (when it is your turn).
	if t.game.is_human_turn():
		t._lock_until = 0
		var before: int = (t.game.state["players"][0]["hand"] as Array).size()
		t._on_bank_pressed(-1)
		var after_t := 0.0
		while after_t < 3.0:
			await process_frame
			after_t += root.get_process_delta_time()
		var after: int = (t.game.state["players"][0]["hand"] as Array).size()
		_check(after == before + 1, "%s: drawing still draws a card (%d -> %d)" % [tag, before, after])
		_check(not t._is_fresh_deal(t.game.state), "%s: once a card was drawn it is no longer a fresh deal" % tag)
		_check(t.fx.get_child_count() == 0, "%s: a draw leaves no flyer behind" % tag)
		_check(not t.hand3d.visible and not t.hand3d._sp_on, "%s: a draw's hand has left, spring off" % tag)

	t.queue_free()
	await process_frame
