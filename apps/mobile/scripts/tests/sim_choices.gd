extends SceneTree
## How much room is there for skill? Counts, per decision, how many different cards a player could
## legally play. godot --headless --path apps/mobile -s res://scripts/tests/sim_choices.gd -- [games]
const Bot := preload("res://scripts/ai/bot.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")


func _init() -> void:
	var games := 100
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		games = int(args[0])
	for players in [2, 3, 4]:
		var ids := ["A", "B", "C", "D"].slice(0, players)
		var decisions := 0
		var forced_draw := 0
		var one_card := 0
		var many := 0
		var pending_turns := 0
		var plays_total := 0
		for g in games:
			var state := CardEngine.create_game({"playerIds": ids, "seed": 8000 + g})
			var rng := RandomNumberGenerator.new()
			rng.seed = g
			var memory := {}
			var turns := 0
			while not state["over"] and turns < 1500:
				var id: String = state["players"][state["current"]]["id"]
				var distinct := {}
				for a in CardEngine.legal_actions(state, id):
					if a["type"] == "play":
						distinct[a["cardId"]] = true
				decisions += 1
				if int(state["pending"]) > 0:
					pending_turns += 1
				if distinct.is_empty():
					forced_draw += 1
				elif distinct.size() == 1:
					one_card += 1
				else:
					many += 1
				plays_total += distinct.size()
				var act := Bot.choose_action(state, id, "normal", rng, memory)
				Bot.update_memory(memory, state, act)
				state = CardEngine.apply_action(state, act)["state"]
				turns += 1
		print("%dp: %d decisions | no playable card %.0f%% | exactly one card %.0f%% | a real choice (2+ cards) %.0f%% | avg playable cards %.2f | facing a penalty %.0f%%" % [
			players, decisions, 100.0 * forced_draw / decisions, 100.0 * one_card / decisions,
			100.0 * many / decisions, float(plays_total) / decisions, 100.0 * pending_turns / decisions])
	quit(0)
