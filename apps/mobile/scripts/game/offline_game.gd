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
var human_chains: Array = [] # [{len, aces}] runs of consecutive plays by the human (combo bonus)
var memory: Dictionary = {} # bot notebook (see Bot.update_memory)
var human_finish_rank := "" # rank of the card that got the human out ("" until they finish)
var _human_last_rank := ""
var _chain_player := ""
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
	human_chains = []
	human_finish_rank = ""
	_human_last_rank = ""
	_chain_player = ""
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
		_track_chain(e)
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


## A chain is consecutive plays by one player with nobody else acting in between
## (in practice: Aces skipping the opponent in 1v1). Only the human's chains score.
func _track_chain(e: Dictionary) -> void:
	var t: String = e["type"]
	if t == "play" and e["playerId"] == HUMAN_ID:
		_human_last_rank = e["card"]["rank"]
	elif t == "finish" and e["playerId"] == HUMAN_ID:
		human_finish_rank = _human_last_rank   # confirmed exit: the card that emptied the hand
	if t != "play" and t != "draw" and t != "penaltyTaken":
		return
	var pid: String = e["playerId"]
	if t != "play":
		_chain_player = ""
		return
	var is_ace: bool = e["card"]["rank"] == "A"
	if pid == _chain_player:
		if pid == HUMAN_ID:
			var c: Dictionary = human_chains[human_chains.size() - 1]
			c["len"] += 1
			c["aces"] += 1 if is_ace else 0
	else:
		_chain_player = pid
		if pid == HUMAN_ID:
			human_chains.append({"len": 1, "aces": 1 if is_ace else 0})


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
