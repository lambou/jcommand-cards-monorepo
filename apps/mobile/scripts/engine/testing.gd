extends RefCounted
## Scenario / deal runners mirroring packages/engine/src/testing.ts.

const Rules := preload("res://scripts/engine/rules.gd")
const Cards := preload("res://scripts/engine/cards.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")


static func required_to_string(r: Dictionary) -> String:
	if r["kind"] == "free":
		return "free"
	return r["suit"] if r["kind"] == "suit" else r["color"]


static func _parse_required(s: String) -> Dictionary:
	if s == "free":
		return {"kind": "free"}
	if s == "red" or s == "black":
		return {"kind": "color", "color": s}
	return {"kind": "suit", "suit": s}


## Normalises JSON numbers (floats) to ints where integral, so comparisons work.
static func _norm(v):
	if v is float and v == floor(v):
		return int(v)
	if v is Array:
		var out := []
		for x in v:
			out.append(_norm(x))
		return out
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _norm(v[k])
		return d
	return v


static func build_state(setup: Dictionary) -> Dictionary:
	var next_id := 0
	var stack: Array = []
	for code in setup["stack"]:
		stack.append(Cards.parse_card(code, next_id))
		next_id += 1
	var top: Dictionary = stack[stack.size() - 1]
	var required: Dictionary
	if setup.has("required"):
		required = _parse_required(setup["required"])
	elif top["suit"] != "":
		required = {"kind": "suit", "suit": top["suit"]}
	else:
		required = {"kind": "color", "color": top["color"]}
	var players: Array = []
	for id in setup["players"]:
		var hand: Array = []
		for code in (setup.get("hands", {}) as Dictionary).get(id, []):
			hand.append(Cards.parse_card(code, next_id))
			next_id += 1
		players.append({"id": id, "hand": hand, "status": "playing", "place": null})
	# setup.bank is top-first; state.bank keeps the top at the end.
	var bank: Array = []
	for code in setup.get("bank", []):
		bank.append(Cards.parse_card(code, next_id))
		next_id += 1
	bank.reverse()
	var settings: Dictionary = (Rules.spec()["defaultSettings"] as Dictionary).duplicate()
	if setup.has("settings"):
		settings.merge(setup["settings"], true)
	settings["handSize"] = int(settings["handSize"])
	var current_id: String = setup.get("current", setup["players"][0])
	return {
		"players": players,
		"bank": bank,
		"stack": stack,
		"required": required,
		"pending": int(setup.get("pending", 0)),
		"current": maxi(0, (setup["players"] as Array).find(current_id)),
		"settings": settings,
		"rngState": 1,
		"finishedOrder": [],
		"provisionalOrder": [],
		"over": false,
		"loser": null,
	}


static func _codes(cards: Array) -> Array:
	var out := []
	for c in cards:
		out.append(Cards.card_code(c))
	return out


static func _sorted(arr: Array) -> Array:
	var a := arr.duplicate()
	a.sort()
	return a


static func _eq(label: String, what: String, got, want, out: Array) -> void:
	if JSON.stringify(_norm(got)) != JSON.stringify(_norm(want)):
		out.append("%s: %s: expected %s, got %s" % [label, what, JSON.stringify(_norm(want)), JSON.stringify(_norm(got))])


static func _player(state: Dictionary, id: String) -> Dictionary:
	for p in state["players"]:
		if p["id"] == id:
			return p
	return {}


static func _check(state: Dictionary, e: Dictionary, label: String, out: Array) -> void:
	var stack: Array = state["stack"]
	if e.has("current"):
		_eq(label, "current", state["players"][state["current"]]["id"], e["current"], out)
	if e.has("pending"):
		_eq(label, "pending", state["pending"], e["pending"], out)
	if e.has("required"):
		_eq(label, "required", required_to_string(state["required"]), e["required"], out)
	if e.has("over"):
		_eq(label, "over", state["over"], e["over"], out)
	if e.has("loser"):
		_eq(label, "loser", state["loser"], e["loser"], out)
	if e.has("stackTop"):
		_eq(label, "stackTop", Cards.card_code(stack[stack.size() - 1]), e["stackTop"], out)
	if e.has("stackBottom"):
		_eq(label, "stackBottom", Cards.card_code(stack[0]), e["stackBottom"], out)
	if e.has("stackSize"):
		_eq(label, "stackSize", stack.size(), e["stackSize"], out)
	if e.has("bankSize"):
		_eq(label, "bankSize", state["bank"].size(), e["bankSize"], out)
	if e.has("bank"):
		var top_first := _codes(state["bank"])
		top_first.reverse()
		_eq(label, "bank", top_first, e["bank"], out)
	for id in e.get("handSizes", {}):
		_eq(label, "handSize(%s)" % id, _player(state, id)["hand"].size(), e["handSizes"][id], out)
	for id in e.get("hands", {}):
		_eq(label, "hand(%s)" % id, _sorted(_codes(_player(state, id)["hand"])), _sorted(e["hands"][id]), out)
	for id in e.get("places", {}):
		_eq(label, "place(%s)" % id, _player(state, id)["place"], e["places"][id], out)
	for id in e.get("statuses", {}):
		_eq(label, "status(%s)" % id, _player(state, id)["status"], e["statuses"][id], out)
	if e.has("finishedOrder"):
		_eq(label, "finishedOrder", state["finishedOrder"], e["finishedOrder"], out)


## Runs a scenario; returns a list of failure messages (empty = pass).
static func run_scenario(sc: Dictionary) -> Array:
	var failures: Array = []
	var state := build_state(sc["setup"])
	var i := 0
	for step in sc["steps"]:
		i += 1
		var label := "%s step %d (%s %s%s)" % [sc["name"], i, step["player"], step["action"], (" " + step["card"]) if step.has("card") else ""]
		var action: Dictionary
		if step["action"] == "play":
			var p := _player(state, step["player"])
			var found := -1
			for c in p["hand"]:
				if Cards.card_code(c) == step["card"]:
					found = c["id"]
					break
			if found < 0:
				failures.append("%s: card not in hand (scenario bug)" % label)
				continue
			action = {"type": "play", "playerId": step["player"], "cardId": found, "chosenSuit": step.get("suit", "")}
		else:
			action = {"type": step["action"], "playerId": step["player"]}
		var res := CardEngine.apply_action(state, action)
		if step.get("expectError", false):
			if res["ok"]:
				failures.append("%s: expected an error but action succeeded" % label)
			continue
		if not res["ok"]:
			failures.append("%s: unexpected error %s" % [label, res["error"]])
			continue
		state = res["state"]
		if step.has("expect"):
			_check(state, step["expect"], label, failures)
	return failures


## Deal cases: {name, playerIds, seed?, deck?:[codes first-dealt-first], settings?, expect:{...}}
static func run_deal(d: Dictionary) -> Array:
	var failures: Array = []
	var opts := {"playerIds": d["playerIds"]}
	if d.has("seed"):
		opts["seed"] = int(d["seed"])
	if d.has("settings"):
		opts["settings"] = d["settings"]
	if d.has("deck"):
		var deck: Array = []
		var codes: Array = d["deck"]
		for i in codes.size():
			deck.append(Cards.parse_card(codes[i], i))
		deck.reverse() # engine deals from the end
		opts["deck"] = deck
	var state := CardEngine.create_game(opts)
	var e: Dictionary = d["expect"]
	var label: String = "deal " + d["name"]
	for id in e.get("hands", {}):
		_eq(label, "hand(%s)" % id, _codes(_player(state, id)["hand"]), e["hands"][id], failures)
	var rest := e.duplicate()
	rest.erase("hands")
	rest.erase("bankTop")
	rest.erase("bankBottom")
	_check(state, rest, label, failures)
	if e.has("bankTop"):
		var top_first := _codes(state["bank"])
		top_first.reverse()
		_eq(label, "bankTop", top_first.slice(0, (e["bankTop"] as Array).size()), e["bankTop"], failures)
	if e.has("bankBottom"):
		_eq(label, "bankBottom", _codes(state["bank"]).slice(0, (e["bankBottom"] as Array).size()), e["bankBottom"], failures)
	return failures



## Deterministic pseudo-random playout (identical policy to playoutSummary in testing.ts).
## Returns {state, steps}.
static func playout_summary(p: Dictionary) -> Dictionary:
	var opts := {"playerIds": p["playerIds"], "seed": int(p["seed"])}
	if p.has("settings"):
		opts["settings"] = p["settings"]
	var state := CardEngine.create_game(opts)
	var pick := int(p["seed"])
	var steps := 0
	var max_steps := int(p["maxSteps"])
	while not state["over"] and steps < max_steps:
		var acts := CardEngine.legal_actions(state, state["players"][state["current"]]["id"])
		pick = (pick * 1103515245 + 12345) & 0xFFFFFFFF
		var plays: Array = []
		var others: Array = []
		for a in acts:
			if a["type"] == "play":
				plays.append(a)
			else:
				others.append(a)
		var pool: Array = others
		if plays.size() > 0 and ((pick >> 8) % 8) != 0:
			pool = plays
		elif others.is_empty():
			pool = plays
		var res := CardEngine.apply_action(state, pool[pick % pool.size()])
		assert(res["ok"], "legal action rejected: " + str(res.get("error", "")))
		state = res["state"]
		steps += 1
	return {"state": state, "steps": steps}


static func run_playout(p: Dictionary) -> Array:
	var failures: Array = []
	var r := playout_summary(p)
	var label: String = "playout " + p["name"]
	_check(r["state"], p["expect"], label, failures)
	_eq(label, "steps", r["steps"], p["expect"]["steps"], failures)
	return failures
