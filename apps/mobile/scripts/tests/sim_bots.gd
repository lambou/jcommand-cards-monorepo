extends SceneTree
## Bot-vs-bot simulation: godot --headless --path apps/mobile -s res://scripts/tests/sim_bots.gd [-- games]
const Bot := preload("res://scripts/ai/bot.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")


func _init() -> void:
	var games := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		games = int(args[0])
	for players in [2, 3, 4]:
		for diffs in [["hard", "normal"], ["hard", "easy"], ["normal", "normal"]]:
			_run(games, players, diffs)
	quit(0)


func _run(games: int, players: int, diffs: Array) -> void:
	var ids := ["A", "B", "C", "D"].slice(0, players)
	var finished := 0
	var total_turns := 0
	var max_turns := 0
	var wins := {"A": 0}
	var stalled := 0
	for g in games:
		var state := CardEngine.create_game({"playerIds": ids, "seed": 1000 + g})
		var rng := RandomNumberGenerator.new()
		var memory := {}
		rng.seed = 77 + g
		var turns := 0
		var noop := 0
		while not state["over"] and turns < 1500:
			var id: String = state["players"][state["current"]]["id"]
			var diff: String = diffs[0] if id == "A" else diffs[1]
			var act := Bot.choose_action(state, id, diff, rng, memory)
			Bot.update_memory(memory, state, act)
			var bank_before: int = state["bank"].size() + state["stack"].size()
			var res := CardEngine.apply_action(state, act)
			assert(res["ok"], "bot chose illegal action: %s" % str(act))
			state = res["state"]
			turns += 1
		if state["over"]:
			finished += 1
			total_turns += turns
			max_turns = maxi(max_turns, turns)
			if state["finishedOrder"][0] == "A":
				wins["A"] += 1
		else:
			stalled += 1
	print("%dp  A=%s others=%s : finished %d/%d, avg turns %d, max %d, A won %d" % [
		players, diffs[0], diffs[1], finished, games, total_turns / maxi(finished, 1), max_turns, wins["A"]])
