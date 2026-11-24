extends SceneTree
## Replays every tutorial chapter through the real engine, exactly as the player and Rex will play it:
##   godot --headless --path apps/mobile -s res://scripts/tests/test_tutorial.gd
## Fails when a rules change makes a lesson illegal, a spotlighted card is not in the hand, or Rex runs out of script.

const CardEngine := preload("res://scripts/engine/engine.gd")
const Cards := preload("res://scripts/engine/cards.gd")
const Tutorial := preload("res://scripts/game/tutorial.gd")

var failures: Array = []


func _init() -> void:
	var n := Tutorial.count()
	if n < 1:
		failures.append("no chapters")
	for i in n:
		_check_chapter(i)
	if failures.is_empty():
		print("PASS: %d tutorial chapters" % n)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)


func _fail(chapter: Dictionary, msg: String) -> void:
	failures.append("%s: %s" % [chapter["id"], msg])


func _hand_of(state: Dictionary, id: String) -> Array:
	for p in state["players"]:
		if p["id"] == id:
			return p["hand"]
	return []


func _card_in_hand(state: Dictionary, id: String, code: String) -> Dictionary:
	for c in _hand_of(state, id):
		if Cards.card_code(c) == code:
			return c
	return {}


func _check_chapter(index: int) -> void:
	var ch: Dictionary = Tutorial.chapters()[index]
	var seen := {}
	for code in ((ch["you"] as Array) + (ch["rex"] as Array) + (ch["bank"] as Array) + [ch["start"]]):
		if seen.has(code):
			_fail(ch, "card %s appears twice in the rigged deck" % code)
		seen[code] = true
	if (ch["you"] as Array).size() != int(ch["hand_size"]) or (ch["rex"] as Array).size() != int(ch["hand_size"]):
		_fail(ch, "hand_size does not match the hands")
		return

	var state := CardEngine.create_game({"playerIds": [Tutorial.ME, Tutorial.REX], "seed": 1,
		"settings": {"finalTurn": true, "handSize": int(ch["hand_size"])}, "deck": Tutorial.build_deck(ch)})
	# The deal must be exactly the lists in the chapter.
	for code in ch["you"]:
		if _card_in_hand(state, Tutorial.ME, code).is_empty():
			_fail(ch, "you were not dealt %s" % code)
	for code in ch["rex"]:
		if _card_in_hand(state, Tutorial.REX, code).is_empty():
			_fail(ch, "Rex was not dealt %s" % code)
	if Cards.card_code(state["stack"][0]) != ch["start"]:
		_fail(ch, "wrong start card")
	if str(state["players"][state["current"]]["id"]) != Tutorial.ME:
		_fail(ch, "you must move first")

	var session := Tutorial.new(index)
	var script: Array = (ch["rex_script"] as Array).duplicate(true)
	var guard := 0
	while not state["over"] and guard < 60:
		guard += 1
		var cur: String = state["players"][state["current"]]["id"]
		if cur == Tutorial.REX:
			if script.is_empty():
				_fail(ch, "Rex has to move but his script is empty (step %d)" % session.index)
				return
			var act := Tutorial.rex_action(script[0], state)
			if act.is_empty():
				_fail(ch, "Rex's scripted move %s cannot be built" % str(script[0]))
				return
			var res := CardEngine.apply_action(state, act)
			if not res["ok"]:
				_fail(ch, "Rex's move %s is illegal: %s" % [str(script[0]), res["error"]])
				return
			state = res["state"]
			script.pop_front()
			continue
		if session.done():
			break
		var step := session.step()
		if step["expect"] == null:
			session.advance()
			continue
		var ex: Dictionary = step["expect"]
		var act: Dictionary = {"type": str(ex["type"]), "playerId": Tutorial.ME}
		if ex["type"] == "play":
			var card := _card_in_hand(state, Tutorial.ME, str(ex["card"]))
			if card.is_empty():
				_fail(ch, "step %d: you do not hold %s" % [session.index, ex["card"]])
				return
			act["cardId"] = card["id"]
			act["chosenSuit"] = str(ex.get("suit", ""))
			if Cards.card_code(card) != str(step["target"]).trim_prefix("card:"):
				_fail(ch, "step %d: the spotlight (%s) is not on the expected card %s" % [session.index, step["target"], ex["card"]])
			if str(card["rank"]) == "J" and not ex.has("suit"):
				_fail(ch, "step %d: a J needs the suit to pick" % session.index)
		var res := CardEngine.apply_action(state, act)
		if not res["ok"]:
			_fail(ch, "step %d: the expected action is illegal: %s" % [session.index, res["error"]])
			return
		state = res["state"]
		if not session.matches(str(ex["type"]), str(ex.get("card", "")), str(ex.get("suit", ""))):
			_fail(ch, "step %d: Session.matches rejects its own expected action" % session.index)
			return
		# A different card must not move the lesson on.
		if ex["type"] == "play" and session.matches("play", "XX"):
			_fail(ch, "step %d: matches() accepted a wrong card" % session.index)
		session.advance()
	if not session.done():
		_fail(ch, "chapter ends before all steps are done (stopped at step %d)" % session.index)
	if not script.is_empty():
		_fail(ch, "Rex has %d scripted moves left over" % script.size())
	if state["over"] == false and str(state["players"][state["current"]]["id"]) != Tutorial.ME:
		_fail(ch, "the chapter must end on your turn (or at game over)")
	if str(ch["outro"]) == "":
		_fail(ch, "no outro")
