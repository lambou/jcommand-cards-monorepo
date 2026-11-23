extends SceneTree
## Tunes the "hard" bot against "normal": paired seeds, seats alternate so first-move advantage cancels.
##   godot --headless --path apps/mobile -s res://scripts/tests/sim_tune.gd -- [games] [players]
const Bot := preload("res://scripts/ai/bot.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")

var _defaults := {}


func _init() -> void:
	var games := 300
	var players := 2
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		games = int(args[0])
	if args.size() > 1:
		players = int(args[1])
	_defaults = (Bot.P as Dictionary).duplicate()
	var variants := [
		["baseline", {}],
		["no stuck", {"stuck": 0.0}],
		["no pen", {"pen": 0.0}],
		["no ace", {"ace": 0.0, "ace1v1": 0.0}],
		["no keep2/J", {"keep2": 0.0, "keepJ": 0.0}],
		["no blocker", {"blocker": 0.0}],
		["no follow", {"follow": 0.0}],
		["no endgame", {"fin1": 0.0, "fin2": 0.0}],
		["cover 3", {"cover": 3.0}],
		["cover 3, no follow", {"cover": 3.0, "follow": 0.0}],
		["cover 6, no follow", {"cover": 6.0, "follow": 0.0}],
	]
	if args.size() > 2 and args[2] == "oracle":
		variants = [
			["oracle (sees opp hand)", {"oracle": true}],
			["oracle, stuck x3", {"oracle": true, "stuck": 36.0}],
			["oracle, stuck x3, pen x3", {"oracle": true, "stuck": 36.0, "pen": 6.6}],
		]
	elif args.size() > 2 and args[2] == "extreme":
		variants = [
			["hoard 2s and Js", {"keep2": 25.0, "keepJ": 12.0}],
			["stuck x3", {"stuck": 36.0}],
			["penalties x3", {"pen": 6.6}],
			["guard blockers", {"blocker": 12.0}],
			["endgame x2", {"fin1": 80.0, "fin2": 20.0}],
			["follow x3", {"follow": 5.4}],
			["ace x3", {"ace": 21.0, "ace1v1": 18.0}],
			["dump 2s/Js early", {"keep2": -10.0, "keepJ": -6.0}],
		]
	elif args.size() > 2:
		var only := []
		for v in variants:
			if args[2] in v[0]:
				only.append(v)
		variants = only
	print("hard vs normal, %dp, %d games per variant (chance = %.0f%%)" % [players, games, 100.0 / players])
	for v in variants:
		Bot.P = _defaults.duplicate()
		Bot.oracle = bool(v[1].get("oracle", false))
		for k in v[1]:
			if k != "oracle":
				Bot.P[k] = v[1][k]
		var wins := _run(games, players)
		print("%-22s hard wins %3d / %d = %.1f%%" % [v[0], wins, games, 100.0 * wins / games])
	Bot.P = _defaults
	Bot.oracle = false
	quit(0)


func _run(games: int, players: int) -> int:
	var ids := ["A", "B", "C", "D"].slice(0, players)
	var wins := 0
	for g in games:
		var hard_id: String = ids[g % players]
		var state := CardEngine.create_game({"playerIds": ids, "seed": 5000 + g})
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + g
		var memory := {}
		var turns := 0
		while not state["over"] and turns < 1500:
			var id: String = state["players"][state["current"]]["id"]
			var act := Bot.choose_action(state, id, "hard" if id == hard_id else "normal", rng, memory)
			Bot.update_memory(memory, state, act)
			state = CardEngine.apply_action(state, act)["state"]
			turns += 1
		if state["over"] and state["finishedOrder"][0] == hard_id:
			wins += 1
	return wins
