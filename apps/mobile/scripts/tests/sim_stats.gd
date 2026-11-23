extends SceneTree
const Bot := preload("res://scripts/ai/bot.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")

func _init() -> void:
	for players in [2, 3, 4]:
		var ids := ["A", "B", "C", "D"].slice(0, players)
		var plays := 0; var draws := 0; var pens := 0; var pen_cards := 0; var turns := 0
		var hand_sum := 0; var by_rank := {}; var games := 60; var done := 0
		for g in games:
			var state := CardEngine.create_game({"playerIds": ids, "seed": 500 + g})
			var rng := RandomNumberGenerator.new(); rng.seed = g
			var t := 0
			while not state["over"] and t < 1500:
				var id: String = state["players"][state["current"]]["id"]
				var act := Bot.choose_action(state, id, "normal", rng)
				hand_sum += state["players"][state["current"]]["hand"].size()
				match act["type"]:
					"play":
						plays += 1
						for c in state["players"][state["current"]]["hand"]:
							if c["id"] == act["cardId"]:
								by_rank[c["rank"]] = int(by_rank.get(c["rank"], 0)) + 1
					"draw": draws += 1
					"takePenalty":
						pens += 1; pen_cards += int(state["pending"])
				state = CardEngine.apply_action(state, act)["state"]
				t += 1; turns += 1
			if state["over"]: done += 1
		print("%dp: turns/game %d  plays %.0f%% draws %.0f%% penalties %.0f%% (avg size %.1f)  avg hand %.1f" % [
			players, turns / games, 100.0*plays/turns, 100.0*draws/turns, 100.0*pens/turns, float(pen_cards)/maxi(pens,1), float(hand_sum)/turns])
		print("   plays by rank: ", by_rank)
	quit(0)
