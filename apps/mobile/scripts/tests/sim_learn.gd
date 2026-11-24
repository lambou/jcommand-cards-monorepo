extends SceneTree
## Builds the "knowledge" for the hard bot by self-play: a cross-entropy-method search over the weights
## of the bot's linear scoring (Bot.FEATURES). Every candidate plays seeded games against "normal"
## (1v1 and 4-player, seats rotated, same seeds for all candidates in a generation so they are
## compared fairly); the best quarter pulls the next generation toward it. Result -> data/hard_knowledge.json
##   godot --headless --path apps/mobile -s res://scripts/tests/sim_learn.gd -- train [gens] [pop] [games] [out]
##   godot --headless --path apps/mobile -s res://scripts/tests/sim_learn.gd -- eval  [games]   (current knowledge file)
const Bot := preload("res://scripts/ai/bot.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")

const SCALE := {"fin1": 12.0, "fin2": 6.0, "stuck": 6.0, "pen": 1.5, "ace": 4.0, "ace1v1": 4.0,
		"keep2": 4.0, "keepJ": 3.0, "blocker": 3.0, "follow": 1.5}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "train"
	if mode == "eval":
		Bot.load_knowledge()
		var n := int(args[1]) if args.size() > 1 else 2000
		_report("current knowledge", n)
		quit(0)
		return
	var gens := int(args[1]) if args.size() > 1 else 20
	var pop := int(args[2]) if args.size() > 2 else 24
	var games := int(args[3]) if args.size() > 3 else 150
	var out: String = args[4] if args.size() > 4 else "res://data/hard_knowledge.json"
	_train(gens, pop, games, out)
	quit(0)


func _train(gens: int, pop: int, games: int, out: String) -> void:
	var names: Array = Bot.FEATURES
	var mean := {}
	var sigma := {}
	for k in names:
		mean[k] = float(Bot.DEFAULT_W.get(k, 0.0))
		sigma[k] = float(SCALE.get(k, 2.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var elite_n := maxi(pop / 4, 3)
	var t0 := Time.get_ticks_msec()
	for gen in gens:
		var base_seed := 100000 + gen * 1000
		var cands: Array = []
		var base_fit := 0.0
		for i in pop:
			var w := {}
			for k in names:
				w[k] = mean[k] if i == 0 else mean[k] + rng.randfn() * float(sigma[k])
			Bot.W = w
			var fit := _fitness(games, base_seed)
			if i == 0:
				base_fit = fit # candidate 0 is the current mean, unperturbed
			cands.append({"w": w, "fit": fit})
		cands.sort_custom(func(a, b): return a["fit"] > b["fit"])
		for k in names:
			var vals: Array = []
			for i in elite_n:
				vals.append(float(cands[i]["w"][k]))
			var m := 0.0
			for v in vals:
				m += v
			m /= vals.size()
			var var_ := 0.0
			for v in vals:
				var_ += (v - m) * (v - m)
			var sd := sqrt(var_ / vals.size())
			mean[k] = 0.6 * mean[k] + 0.4 * m
			sigma[k] = maxf(0.5 * float(sigma[k]) + 0.5 * sd, 0.15 * float(SCALE.get(k, 2.0)))
		print("gen %2d  best %+.3f  mean-of-elite %+.3f  current-mean %+.3f  (%ds)" % [gen, cands[0]["fit"],
				_avg(cands.slice(0, elite_n)), base_fit, (Time.get_ticks_msec() - t0) / 1000])
		_save(mean, out, gen)
	Bot.W = mean
	_report("learned", 3000)
	Bot.W = Bot.DEFAULT_W.duplicate()
	_report("hand-tuned start", 3000)


func _avg(c: Array) -> float:
	var s := 0.0
	for x in c:
		s += float(x["fit"])
	return s / c.size()


## Win-rate edge over chance, summed over 1v1 and 4-player play against "normal".
func _fitness(games: int, base_seed: int) -> float:
	var w2 := _wins(games, 2, base_seed)
	var w4 := _wins(games, 4, base_seed + 500)
	return (float(w2) / games - 0.5) + (float(w4) / games - 0.25) * 2.0


func _wins(games: int, players: int, base_seed: int) -> int:
	var ids := ["A", "B", "C", "D"].slice(0, players)
	var wins := 0
	for g in games:
		var hard_id: String = ids[g % players]
		var state := CardEngine.create_game({"playerIds": ids, "seed": base_seed + g})
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + 7 * g
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


func _report(label: String, games: int) -> void:
	var line := label + ":"
	for players in [2, 3, 4]:
		var wins := _wins(games, players, 900000 + players * 10000)
		var p := float(wins) / games
		var se := sqrt(p * (1.0 - p) / games)
		line += "  %dp %.1f%% (+-%.1f, chance %.1f%%)" % [players, 100.0 * p, 196.0 * se, 100.0 / players]
	print(line)


func _save(mean: Dictionary, path: String, gen: int) -> void:
	var weights := {}
	for k in mean:
		weights[k] = snappedf(float(mean[k]), 0.001)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.stringify({"version": 1, "generation": gen, "trained_by": "tests/sim_learn.gd", "weights": weights}, "  "))
