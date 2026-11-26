extends SceneTree
## A bot's seat must not show a card before the card has flown there: not while dealing, and not when it draws from
## the bank (the seat's count only goes up as each flight lands).
##   godot --headless --path apps/mobile -s res://scripts/tests/test_bot_draw_count.gd

const Table := preload("res://scripts/ui/table.gd")
const Settings := preload("res://scripts/game/settings.gd")
const DealPlan := preload("res://scripts/game/deal_plan.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")

var failures: Array = []


func _init() -> void:
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _flyers(t: Control) -> int:
	var n := 0
	for f in t.fx.get_children():
		if f is Control and f.visible and not f.has_meta("standin"):
			n += 1
	return n


## x of every drawn fan card of the bot's seat right now.
func _fan_xs(t: Control) -> Array:
	var v: Control = t.opp_views["bot1"]
	var fan_w: float = v.mini_rect().position.x - 28.0
	var xs: Array = []
	for i in mini(v.count, v.FAN_MAX):
		xs.append(v._fan_x(i, maxf(v.lay_n, float(i + 1)), fan_w))
	return xs


## Largest one-frame move of a card that was already there (the newcomer has no previous position).
func _jump(prev: Array, cur: Array) -> float:
	var worst := 0.0
	for i in mini(prev.size(), cur.size()):
		worst = maxf(worst, absf(float(cur[i]) - float(prev[i])))
	return worst


func _run() -> void:
	await process_frame
	Settings.load_settings()
	Settings.deal_style = DealPlan.FLY
	Settings.reduce_motion = false
	var t: Control = Table.new()
	root.add_child(t)
	await process_frame
	t.bots = 1
	t.difficulty = "normal"
	t._build()
	t.game.bot_delay = 99.0 # we drive the bot by hand
	t.game.bot_delay_max = -1.0
	t.game.start(1, "normal", 3)
	var hand_n: int = (t.game.state["players"][1]["hand"] as Array).size()

	# 1. The deal: the bot's count climbs card by card and never starts at its full hand.
	var seen: Array = []
	var worst_deal := 0.0
	var prev_xs: Array = []
	var elapsed := 0.0
	while t._dealing and elapsed < 10.0:
		await process_frame
		elapsed += root.get_process_delta_time()
		seen.append(int(t.opp_views["bot1"].count))
		var xs := _fan_xs(t)
		worst_deal = maxf(worst_deal, _jump(prev_xs, xs))
		prev_xs = xs
	_check(seen.size() > 5 and int(seen[0]) < hand_n, "deal: the bot's seat does not start with its full hand (first %s of %d)" % [str(seen[0] if seen.size() > 0 else -1), hand_n])
	var mono := true
	for i in range(1, seen.size()):
		if int(seen[i]) < int(seen[i - 1]):
			mono = false
	_check(mono, "deal: the bot's count only ever goes up")
	_check(worst_deal < 8.0, "deal: no fan card jumps (worst %.1f px in one frame)" % worst_deal)
	await create_timer(0.3).timeout
	_check(int(t.opp_views["bot1"].count) == hand_n, "deal: the bot ends with its full hand (%d)" % int(t.opp_views["bot1"].count))

	# 2. A bot draw: the count stays until the card lands.
	if t.game.is_human_turn():
		var acts: Array = CardEngine.legal_actions(t.game.state, "you")
		var a: Dictionary = acts[0]
		if a["type"] == "play":
			t.game.human_play(a["cardId"], "H")
		elif a["type"] == "draw":
			t.game.human_draw()
		else:
			t.game.human_take_penalty()
		await create_timer(2.0).timeout
	var before: int = int(t.opp_views["bot1"].count)
	var actual_before: int = (t.game.state["players"][1]["hand"] as Array).size()
	if t.game.current_id() == "bot1":
		var legal: Array = CardEngine.legal_actions(t.game.state, "bot1")
		var act := {}
		for a in legal:
			if a["type"] == "draw" or a["type"] == "takePenalty":
				act = a
		if act.is_empty():
			print("SKIP: the bot had no draw action in this position")
		else:
			t.game._apply(act)
			var actual_after: int = (t.game.state["players"][1]["hand"] as Array).size()
			var gained := actual_after - actual_before
			await process_frame
			var early := 0
			var guard := 0
			var worst_draw := 0.0
			var prev_d := _fan_xs(t)
			var landed := false
			while guard < 300:
				var c: int = int(t.opp_views["bot1"].count)
				if _flyers(t) > 0 and c > before:
					early += 1
				if c == before + gained:
					landed = true
					break
				await process_frame
				var cur_d := _fan_xs(t)
				worst_draw = maxf(worst_draw, _jump(prev_d, cur_d))
				prev_d = cur_d
				guard += 1
			_check(gained > 0, "the bot drew at least one card (%d)" % gained)
			_check(early == 0, "draw: the seat never shows a card while one is still flying (%d early frames)" % early)
			var tail := 0.0
			while tail < 0.5: # keep watching while the other cards glide into their new places
				await process_frame
				tail += root.get_process_delta_time()
				var cur_t := _fan_xs(t)
				worst_draw = maxf(worst_draw, _jump(prev_d, cur_t))
				prev_d = cur_t
			_check(worst_draw < 8.0, "draw: no fan card jumps (worst %.1f px in one frame)" % worst_draw)
			_check(landed, "draw: the seat ends with the drawn card(s) counted")
	else:
		print("SKIP: not the bot's turn after the human move")

	if failures.is_empty():
		print("PASS: bot seat counts follow the flights")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)
