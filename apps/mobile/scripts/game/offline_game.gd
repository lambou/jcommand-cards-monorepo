extends Node
## Offline game session: one human against bots, driven by the GDScript engine.
## The UI listens to `updated` and calls the human_* methods.

const CardEngine := preload("res://scripts/engine/engine.gd")
const Bot := preload("res://scripts/ai/bot.gd")

signal updated(events: Array)

const HUMAN_ID := "you"
const BOT_NAMES := ["Rex", "Luna", "Zed"]

var state: Dictionary = {}
var names: Dictionary = {}
var difficulty := "normal"
var bot_delay := 0.9
var rng := RandomNumberGenerator.new()

var human_draws := 0 # voluntary bank draws by the human this game (for the Clean Finish bonus)
var memory: Dictionary = {} # bot notebook (see Bot.update_memory)
var _serial := 0
var _passes := 0


func start(bot_count: int, diff: String, seed_value: int = 0) -> void:
	_serial += 1
	difficulty = diff
	var ids: Array = [HUMAN_ID]
	names = {HUMAN_ID: "You"}
	for i in range(1, bot_count + 1):
		ids.append("bot%d" % i)
		names["bot%d" % i] = BOT_NAMES[(i - 1) % BOT_NAMES.size()]
	if seed_value == 0:
		seed_value = (randi() % 2000000000) + 1
	rng.seed = seed_value
	_passes = 0
	human_draws = 0
	memory = {}
	state = CardEngine.create_game({"playerIds": ids, "seed": seed_value})
	updated.emit([])
	_bot_loop()


func stop() -> void:
	_serial += 1


func current_id() -> String:
	return state["players"][state["current"]]["id"]


func is_human_turn() -> bool:
	return not state["over"] and current_id() == HUMAN_ID


func human_play(card_id: int, chosen_suit: String = "") -> bool:
	return _human({"type": "play", "playerId": HUMAN_ID, "cardId": card_id, "chosenSuit": chosen_suit})


func human_draw() -> bool:
	return _human({"type": "draw", "playerId": HUMAN_ID})


func human_take_penalty() -> bool:
	return _human({"type": "takePenalty", "playerId": HUMAN_ID})


func _human(action: Dictionary) -> bool:
	if not is_human_turn():
		return false
	if not _apply(action):
		return false
	_bot_loop()
	return true


func _apply(action: Dictionary) -> bool:
	Bot.update_memory(memory, state, action)
	var res := CardEngine.apply_action(state, action)
	if not res["ok"]:
		return false
	state = res["state"]
	# Safety valve: if everybody keeps passing with an exhausted bank, end the game.
	for e in res["events"]:
		if e["type"] == "draw":
			if e["playerId"] == HUMAN_ID and int(e["count"]) > 0:
				human_draws += 1
			_passes = _passes + 1 if int(e["count"]) == 0 else 0
		elif e["type"] == "play":
			_passes = 0
	if _passes >= state["players"].size() * 2 and not state["over"]:
		_force_end(res["events"])
	updated.emit(res["events"])
	return true


## Ranks the remaining players by fewest cards when nobody can move any more.
func _force_end(events: Array) -> void:
	var left: Array = []
	for p in state["players"]:
		if p["status"] != "finished":
			left.append(p)
	left.sort_custom(func(a, b): return a["hand"].size() < b["hand"].size())
	for p in left:
		p["status"] = "finished"
		p["place"] = state["finishedOrder"].size() + 1
		state["finishedOrder"].append(p["id"])
	state["loser"] = left[left.size() - 1]["id"]
	state["over"] = true
	events.append({"type": "gameOver", "loser": state["loser"]})


func _bot_loop() -> void:
	_serial += 1
	var mine := _serial
	while not state["over"] and current_id() != HUMAN_ID:
		await get_tree().create_timer(bot_delay).timeout
		if mine != _serial or state["over"]:
			return
		var id := current_id()
		var act := Bot.choose_action(state, id, difficulty, rng, memory)
		_apply(act)
