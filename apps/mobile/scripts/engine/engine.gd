extends RefCounted
## GDScript port of packages/engine/src/engine.ts. Keep the two in lockstep;
## the shared scenarios in packages/rules-spec are the contract.
##
## State is a plain Dictionary (same shape as the TypeScript GameState):
##   players: [{id, hand:[card], status:"playing"|"provisional"|"finished", place:int|null}]
##   bank, stack: [card]  (last element = top; slid-under 2s sit at index 0 of stack)
##   required: {kind:"free"} | {kind:"suit", suit} | {kind:"color", color}
##   pending:int, current:int, settings:{handSize, reshuffleOnRefill}, rngState:int,
##   finishedOrder:[id], provisionalOrder:[id], over:bool, loser:String|null
##
## Actions:
##   {type:"play", playerId, cardId, chosenSuit?}, {type:"draw", playerId}, {type:"takePenalty", playerId}
## Results:
##   {ok:true, state, events} | {ok:false, error}

const Rules := preload("res://scripts/engine/rules.gd")
const Cards := preload("res://scripts/engine/cards.gd")
const Rng := preload("res://scripts/engine/rng.gd")


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}


# ---------------------------------------------------------------- setup

## opts: {playerIds:Array, settings?:Dictionary, seed?:int, deck?:Array[card]}
## A supplied deck is not shuffled; its last element is dealt first.
static func create_game(opts: Dictionary) -> Dictionary:
	var settings: Dictionary = (Rules.spec()["defaultSettings"] as Dictionary).duplicate()
	if opts.has("settings"):
		settings.merge(opts["settings"], true)
	settings["handSize"] = int(settings["handSize"])
	var ids: Array = opts["playerIds"]
	var n := ids.size()
	assert(n >= 2 and n <= 10, "2-10 players required")

	var box := {"s": int(opts.get("seed", 1)) & 0xFFFFFFFF}
	var deck: Array
	if opts.has("deck"):
		deck = (opts["deck"] as Array).duplicate(true)
	else:
		deck = Cards.create_deck()
		Rng.shuffle_in_place(deck, box)
	assert(n * int(settings["handSize"]) + 2 <= deck.size(), "Too many players for the deck")

	var players: Array = []
	for id in ids:
		players.append({"id": id, "hand": [], "status": "playing", "place": null})
	for r in int(settings["handSize"]):
		for p in players:
			p["hand"].append(deck.pop_back())

	# Flip the starting card. Redeal-type cards go to the bottom of the bank.
	var start: Dictionary = deck.pop_back()
	while Rules.rule_of(start["rank"]).get("onStart", "") == "redeal":
		deck.push_front(start)
		start = deck.pop_back()

	var start_rule := Rules.rule_of(start["rank"])
	var required: Dictionary
	if start_rule.get("onStart", "") == "free":
		required = {"kind": "free"}
	else:
		required = {"kind": "suit", "suit": start["suit"]}

	var state := {
		"players": players,
		"bank": deck,
		"stack": [start],
		"required": required,
		"pending": 0,
		"current": 0,
		"settings": settings,
		"rngState": box["s"],
		"finishedOrder": [],
		"provisionalOrder": [],
		"over": false,
		"loser": null,
	}
	if start_rule.get("onStart", "") == "skipFirst":
		for k in int(start_rule.get("skipNext", 1)):
			state["current"] = _next_unfinished(state, state["current"])
	return state


# ---------------------------------------------------------------- queries

static func _matches_required(card: Dictionary, req: Dictionary) -> bool:
	match req["kind"]:
		"free":
			return true
		"color":
			return card["color"] == req["color"]
		"suit":
			if card["suit"] != "":
				return card["suit"] == req["suit"]
			return card["color"] == Cards.suit_color(req["suit"])
	return false


static func _unfinished_count(s: Dictionary) -> int:
	var c := 0
	for p in s["players"]:
		if p["status"] != "finished":
			c += 1
	return c


static func is_playable(s: Dictionary, hand: Array, card: Dictionary) -> bool:
	if int(s["pending"]) > 0:
		return Rules.penalty_of(card["rank"]) > 0
	var rule := Rules.rule_of(card["rank"])
	if rule.get("cannotFinishWhenTwoPlayersLeft", false) and hand.size() == 1 and _unfinished_count(s) == 2:
		return false
	var stack: Array = s["stack"]
	var floor_card: Dictionary = stack[stack.size() - 1]
	match rule["playOn"]:
		"any":
			return true
		"required":
			if _matches_required(card, s["required"]):
				return true
			return bool(s["settings"].get("matchRank", false)) and bool(rule.get("matchRank", true)) and floor_card["rank"] == card["rank"]
		"requiredOrSameRank":
			return _matches_required(card, s["required"]) or floor_card["rank"] == card["rank"]
	return false


static func legal_actions(s: Dictionary, player_id: String) -> Array:
	var out: Array = []
	if s["over"]:
		return out
	var p: Dictionary = s["players"][s["current"]]
	if p["id"] != player_id:
		return out
	for card in p["hand"]:
		if not is_playable(s, p["hand"], card):
			continue
		if Rules.rule_of(card["rank"]).get("sets", "") == "chosen":
			for suit in Cards.SUITS:
				out.append({"type": "play", "playerId": player_id, "cardId": card["id"], "chosenSuit": suit})
		else:
			out.append({"type": "play", "playerId": player_id, "cardId": card["id"]})
	if int(s["pending"]) > 0:
		out.append({"type": "takePenalty", "playerId": player_id})
	else:
		out.append({"type": "draw", "playerId": player_id})
	return out


# ---------------------------------------------------------------- helpers

static func _next_unfinished(s: Dictionary, from: int) -> int:
	var n: int = s["players"].size()
	for i in range(1, n + 1):
		var idx := (from + i) % n
		if s["players"][idx]["status"] != "finished":
			return idx
	return from


## Returns the drawn card, or null when no card is available.
static func _draw_one(s: Dictionary, events: Array):
	var bank: Array = s["bank"]
	if bank.is_empty():
		var stack: Array = s["stack"]
		if stack.size() <= 1:
			return null
		var floor_card = stack.pop_back()
		var rest: Array = stack
		s["stack"] = [floor_card]
		var reshuffle: bool = s["settings"]["reshuffleOnRefill"]
		if reshuffle:
			var box := {"s": int(s["rngState"])}
			Rng.shuffle_in_place(rest, box)
			s["rngState"] = box["s"]
			s["bank"] = rest
		else:
			# Turn the pile over: the old bottom becomes the top of the bank.
			rest.reverse()
			s["bank"] = rest
		events.append({"type": "refill", "reshuffled": reshuffle})
		bank = s["bank"]
	if bank.is_empty():
		return null
	return bank.pop_back()


static func _confirm_finish(s: Dictionary, p: Dictionary, events: Array) -> void:
	p["status"] = "finished"
	p["place"] = s["finishedOrder"].size() + 1
	s["finishedOrder"].append(p["id"])
	events.append({"type": "finish", "playerId": p["id"], "place": p["place"]})


## Ends the game when at most one player is still in. Returns true if over.
static func _check_over(s: Dictionary, events: Array) -> bool:
	var left: Array = []
	for p in s["players"]:
		if p["status"] != "finished":
			left.append(p)
	if left.size() > 1:
		return false
	s["over"] = true
	s["provisionalOrder"] = []
	if left.size() == 1:
		var last: Dictionary = left[0]
		last["status"] = "finished"
		last["place"] = s["finishedOrder"].size() + 1
		s["finishedOrder"].append(last["id"])
		s["loser"] = last["id"]
	events.append({"type": "gameOver", "loser": s["loser"]})
	return true


static func _find_player(s: Dictionary, id: String) -> Dictionary:
	for p in s["players"]:
		if p["id"] == id:
			return p
	return {}


# ---------------------------------------------------------------- apply

static func apply_action(state: Dictionary, action: Dictionary) -> Dictionary:
	if state["over"]:
		return _fail("game_over")
	var s: Dictionary = state.duplicate(true)
	var events: Array = []
	var cur: Dictionary = s["players"][s["current"]]
	if cur["id"] != action["playerId"]:
		return _fail("not_your_turn")
	match action["type"]:
		"play":
			return _do_play(s, cur, action, events)
		"draw":
			return _do_draw(s, cur, events)
		"takePenalty":
			return _do_take_penalty(s, cur, events)
	return _fail("unknown_action")


static func _do_play(s: Dictionary, cur: Dictionary, action: Dictionary, events: Array) -> Dictionary:
	var hand: Array = cur["hand"]
	var idx := -1
	for i in hand.size():
		if hand[i]["id"] == action["cardId"]:
			idx = i
			break
	if idx < 0:
		return _fail("card_not_in_hand")
	var card: Dictionary = hand[idx]
	if not is_playable(s, hand, card):
		return _fail("illegal_play")
	var rule := Rules.rule_of(card["rank"])
	var chosen: String = str(action.get("chosenSuit", ""))
	if rule["sets"] == "chosen" and not Cards.SUITS.has(chosen):
		return _fail("suit_required")

	hand.remove_at(idx)
	if rule.get("slideUnder", false):
		s["stack"].push_front(card)
	else:
		s["stack"].push_back(card)

	match rule["sets"]:
		"suit":
			s["required"] = {"kind": "suit", "suit": card["suit"]}
		"color":
			s["required"] = {"kind": "color", "color": card["color"]}
		"chosen":
			s["required"] = {"kind": "suit", "suit": chosen}
		"none":
			pass
	var penalty := int(rule.get("penalty", 0))
	s["pending"] = int(s["pending"]) + penalty
	events.append({"type": "play", "playerId": cur["id"], "card": card, "chosenSuit": chosen})

	if hand.is_empty():
		if penalty > 0:
			cur["status"] = "provisional"
			s["provisionalOrder"].append(cur["id"])
			events.append({"type": "provisionalFinish", "playerId": cur["id"]})
		else:
			_confirm_finish(s, cur, events)
	if _check_over(s, events):
		return {"ok": true, "state": s, "events": events}

	var nxt := _next_unfinished(s, s["current"])
	for k in int(rule.get("skipNext", 0)):
		events.append({"type": "skip", "playerId": s["players"][nxt]["id"]})
		nxt = _next_unfinished(s, nxt)
	s["current"] = nxt
	return {"ok": true, "state": s, "events": events}


static func _do_draw(s: Dictionary, cur: Dictionary, events: Array) -> Dictionary:
	if int(s["pending"]) > 0:
		return _fail("must_take_penalty")
	var card = _draw_one(s, events)
	if card != null:
		cur["hand"].append(card)
	events.append({"type": "draw", "playerId": cur["id"], "count": 1 if card != null else 0})
	s["current"] = _next_unfinished(s, s["current"])
	return {"ok": true, "state": s, "events": events}


static func _do_take_penalty(s: Dictionary, cur: Dictionary, events: Array) -> Dictionary:
	var pending := int(s["pending"])
	if pending <= 0:
		return _fail("no_penalty")
	var drawn := 0
	for i in pending:
		var card = _draw_one(s, events)
		if card == null:
			break
		cur["hand"].append(card)
		drawn += 1
	s["pending"] = 0
	events.append({"type": "penaltyTaken", "playerId": cur["id"], "count": drawn})

	# The taker (if they had provisionally finished) is back in the game; every
	# other provisional finisher is now confirmed, in the order they finished.
	if cur["status"] == "provisional":
		cur["status"] = "playing"
	for id in s["provisionalOrder"]:
		var p := _find_player(s, id)
		if p["id"] != cur["id"]:
			_confirm_finish(s, p, events)
	s["provisionalOrder"] = []
	if cur["hand"].is_empty():
		_confirm_finish(s, cur, events) # bank exhausted edge case

	if _check_over(s, events):
		return {"ok": true, "state": s, "events": events}
	s["current"] = _next_unfinished(s, s["current"])
	return {"ok": true, "state": s, "events": events}
