extends Node
## Offline game session: one human against bots, driven by the GDScript engine.
## The UI listens to `updated` and calls the human_* methods.

const CardEngine := preload("res://scripts/engine/engine.gd")
const Bot := preload("res://scripts/ai/bot.gd")
const Rules := preload("res://scripts/engine/rules.gd")
const Scoring := preload("res://scripts/game/scoring.gd")

signal updated(events: Array)

const HUMAN_ID := "you"
const BOT_NAMES := ["Rex", "Luna", "Zed"]

var state: Dictionary = {}
var names: Dictionary = {}
var difficulty := "normal"
var bot_delay := 0.9
var rng := RandomNumberGenerator.new()

## Score stats for EVERY player (points decide the final ranking, so bots need them too):
##   id -> {draws: voluntary bank draws, chains: [{len, aces}], penalty_chains: [{cards, pile}],
##          finish_rank: rank of the card that got them out ("" until they do), first_out: bool, last_rank}
var stats: Dictionary = {}
var points: Dictionary = {} # id -> ranking points, filled in when the game ends
var is_draw := false # the top places were tied on points
var memory: Dictionary = {} # bot notebook (see Bot.update_memory)
var human_draws: int:
	get: return int(stats[HUMAN_ID]["draws"])
var human_chains: Array:
	get: return stats[HUMAN_ID]["chains"]
var human_penalty_chains: Array:
	get: return stats[HUMAN_ID]["penalty_chains"]
var human_finish_rank: String:
	get: return str(stats[HUMAN_ID]["finish_rank"])
var human_first_out: bool:
	get: return bool(stats[HUMAN_ID]["first_out"])
var _pile: Dictionary = {} # id -> penalty cards they added to the pile currently pending
var _anyone_out := false
var _chain_player := ""
var _bonus_events: Array = [] # "bonus" events queued by _track_chain, appended to the turn's events
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
	stats = {}
	for id in ids:
		stats[id] = {"draws": 0, "chains": [], "penalty_chains": [], "finish_rank": "", "first_out": false, "last_rank": ""}
	points = {}
	is_draw = false
	_pile = {}
	_anyone_out = false
	_bonus_events = []
	_chain_player = ""
	memory = {}
	state = CardEngine.create_game({"playerIds": ids, "seed": seed_value, "settings": {"finalTurn": true}})
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
	var extra: Array = []
	for e in res["events"]:
		var bonus_event := _track_chain(e)
		if not bonus_event.is_empty():
			extra.append(bonus_event)
		if e["type"] == "draw":
			if int(e["count"]) > 0:
				stats[e["playerId"]]["draws"] += 1
			_passes = _passes + 1 if int(e["count"]) == 0 else 0
		elif e["type"] == "play":
			_passes = 0
	extra.append_array(_bonus_events)
	_bonus_events.clear()
	res["events"].append_array(extra)
	if _passes >= state["players"].size() * 2 and not state["over"]:
		_force_end(res["events"])
	if state["over"]:
		_rank_by_points()
	updated.emit(res["events"])
	return true


## Final standings. Players who got out (empty hand) are ranked by points, best first; equal points
## share the place (a draw). Anyone left holding cards has lost outright - points don't matter -
## and sits below everybody who got out, in the order the engine already gave them.
func _rank_by_points() -> void:
	var winners: Array = []
	var losers: Array = []
	for id in state["finishedOrder"]:
		var p := _player(id)
		if p["hand"].is_empty():
			winners.append(id)
			points[id] = Scoring.ranking_points(stats[id])
		else:
			losers.append(id)
	var order := winners.duplicate()
	# Stable on ties: whoever got out first stays ahead in the list (the place itself is shared).
	var out_order: Array = state["finishedOrder"].duplicate()
	order.sort_custom(func(a, b):
		if int(points[a]) != int(points[b]):
			return int(points[a]) > int(points[b])
		return out_order.find(a) < out_order.find(b))
	var place := 0
	var prev := -1
	for i in order.size():
		var id: String = order[i]
		if i == 0 or int(points[id]) != prev:
			place = i + 1
		prev = int(points[id])
		_player(id)["place"] = place
	for j in losers.size():
		_player(losers[j])["place"] = order.size() + j + 1
	state["finishedOrder"] = order + losers
	is_draw = order.size() > 1 and int(_player(order[0])["place"]) == int(_player(order[1])["place"])


## Running points for every player (see Scoring.live_points).
func live_points() -> Dictionary:
	var out := {}
	for id in stats:
		out[id] = Scoring.live_points(stats[id])
	return out


func _player(id: String) -> Dictionary:
	for p in state["players"]:
		if p["id"] == id:
			return p
	return {}


## A chain is consecutive plays by one player with nobody else acting in between
## (in practice: Aces skipping the opponent in 1v1). Only the human's chains score.
## Returns a "combo" event ({len, aces, jackpot, fresh}) when the human extends a chain, else {}.
func _track_chain(e: Dictionary) -> Dictionary:
	var t: String = e["type"]
	if t == "play":
		var st: Dictionary = stats[e["playerId"]]
		st["last_rank"] = e["card"]["rank"]
		if Rules.penalty_of(st["last_rank"]) > 0:
			_pile[e["playerId"]] = int(_pile.get(e["playerId"], 0)) + 1
	elif t == "penaltyTaken":
		# Whoever takes the pile ends the chain; it pays everyone else who fed it.
		for fid in _pile:
			if fid == e["playerId"] or int(_pile[fid]) <= 0:
				continue
			var n := int(_pile[fid])
			stats[fid]["penalty_chains"].append({"cards": n, "pile": int(e["count"])})
			if fid == HUMAN_ID:
				_bonus_events.append({"type": "bonus", "kind": "pass_on", "victim": e["playerId"], "cards": n,
					"pile": int(e["count"]),
					"points": Scoring.PASS_ON_PER_CARD * n + Scoring.PASS_ON_PER_PILE_CARD * int(e["count"])})
		_pile.clear()
	elif t == "finish":
		var fid: String = e["playerId"]
		var st: Dictionary = stats[fid]
		st["finish_rank"] = st["last_rank"]   # confirmed exit: the card that emptied the hand
		st["first_out"] = not _anyone_out
		_anyone_out = true
		if fid == HUMAN_ID:
			var pen := Rules.penalty_of(st["finish_rank"])
			if pen > 0:
				_bonus_events.append({"type": "bonus", "kind": "penalty_finish", "rank": st["finish_rank"], "pen": pen,
					"points": Scoring.PENALTY_FINISH_PER_CARD * pen})
			if st["first_out"]:
				_bonus_events.append({"type": "bonus", "kind": "winning_card", "points": Scoring.WINNING_CARD})
	if t != "play" and t != "draw" and t != "penaltyTaken":
		return {}
	var pid: String = e["playerId"]
	if t != "play":
		_chain_player = ""
		return {}
	var is_ace: bool = e["card"]["rank"] == "A"
	if pid == _chain_player:
		var chains: Array = stats[pid]["chains"]
		var c: Dictionary = chains[chains.size() - 1]
		c["len"] += 1
		c["aces"] += 1 if is_ace else 0
		if pid == HUMAN_ID: # only the human gets the on-screen combo show
			return {"type": "combo", "playerId": pid, "len": c["len"], "aces": c["aces"],
				"jackpot": c["aces"] >= 4, "fresh": is_ace and c["aces"] == 4}
	else:
		_chain_player = pid
		stats[pid]["chains"].append({"len": 1, "aces": 1 if is_ace else 0})
	return {}


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
