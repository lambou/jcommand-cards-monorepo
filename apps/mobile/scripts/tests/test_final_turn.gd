extends SceneTree
## Final turn rule: when only one player is left and their single card is playable they get one last
## turn (playing it = both out); otherwise they have lost outright.
## Run: godot --headless --path apps/mobile -s res://scripts/tests/test_final_turn.gd

const CardEngine := preload("res://scripts/engine/engine.gd")
const Cards := preload("res://scripts/engine/cards.gd")

var _fails := 0


func _game(a: String, b: String, b_extra: String = "") -> Dictionary:
	var deck := [Cards.parse_card("2D", 0), Cards.parse_card("5H", 1), Cards.parse_card(b, 2), Cards.parse_card(a, 3)]
	var st := CardEngine.create_game({"playerIds": ["A", "B"], "deck": deck, "settings": {"handSize": 1, "finalTurn": true}})
	if b_extra != "":
		st["players"][1]["hand"].append(Cards.parse_card(b_extra, 4))
	return st


func _check(label: String, cond: bool) -> void:
	print(("ok   " if cond else "FAIL ") + label)
	if not cond:
		_fails += 1


func _init() -> void:
	# 1. B holds one playable card: gets a last turn, plays it, both out.
	var st := _game("9H", "3H")
	var r := CardEngine.apply_action(st, {"type": "play", "playerId": "A", "cardId": 3})
	_check("1: game continues after A goes out", r["ok"] and not r["state"]["over"] and r["state"]["current"] == 1)
	r = CardEngine.apply_action(r["state"], {"type": "play", "playerId": "B", "cardId": 2})
	_check("1: B plays its last card -> over, nobody lost", r["state"]["over"] and r["state"]["loser"] == null)
	_check("1: both out", r["state"]["finishedOrder"] == ["A", "B"])

	# 2. B's single card cannot be played: lost immediately.
	st = _game("9H", "3S")
	r = CardEngine.apply_action(st, {"type": "play", "playerId": "A", "cardId": 3})
	_check("2: unplayable single card -> over, B lost", r["state"]["over"] and r["state"]["loser"] == "B")

	# 3. B has two cards: lost immediately even if one is playable.
	st = _game("9H", "3H", "4H")
	r = CardEngine.apply_action(st, {"type": "play", "playerId": "A", "cardId": 3})
	_check("3: two cards -> over, B lost", r["state"]["over"] and r["state"]["loser"] == "B")

	# 4. B draws on its last turn instead of playing: lost.
	st = _game("9H", "3H")
	r = CardEngine.apply_action(st, {"type": "play", "playerId": "A", "cardId": 3})
	r = CardEngine.apply_action(r["state"], {"type": "draw", "playerId": "B"})
	_check("4: drawing on the last turn -> over, B lost", r["state"]["over"] and r["state"]["loser"] == "B")

	# 5. An Ace can't be the finishing card with two or fewer left: lost.
	st = _game("9H", "AH")
	r = CardEngine.apply_action(st, {"type": "play", "playerId": "A", "cardId": 3})
	_check("5: last card is an Ace -> over, B lost", r["state"]["over"] and r["state"]["loser"] == "B")

	# 6. B goes out on a 7 as its last card: confirmed finish, nobody to take it.
	st = _game("9H", "7H")
	r = CardEngine.apply_action(st, {"type": "play", "playerId": "A", "cardId": 3})
	r = CardEngine.apply_action(r["state"], {"type": "play", "playerId": "B", "cardId": 2})
	_check("6: B out on a 7 -> over, nobody lost, both out", r["state"]["over"] and r["state"]["loser"] == null and r["state"]["finishedOrder"] == ["A", "B"])

	# 7. Rule off (default): old behaviour, game ends as soon as A is out.
	var deck := [Cards.parse_card("2D", 0), Cards.parse_card("5H", 1), Cards.parse_card("3H", 2), Cards.parse_card("9H", 3)]
	st = CardEngine.create_game({"playerIds": ["A", "B"], "deck": deck, "settings": {"handSize": 1}})
	r = CardEngine.apply_action(st, {"type": "play", "playerId": "A", "cardId": 3})
	_check("7: finalTurn off -> over at once", r["state"]["over"] and r["state"]["loser"] == "B")

	# 8. 1v1: an Ace (Stop) as the last card is playable but does not take you out. The opponent is
	#    skipped, you hold no cards, must draw, and the turn then passes on.
	deck = [Cards.parse_card("2D", 0), Cards.parse_card("5H", 1), Cards.parse_card("AH", 2), Cards.parse_card("9H", 3)]
	st = CardEngine.create_game({"playerIds": ["A", "B"], "deck": deck, "settings": {"handSize": 1}})
	st["current"] = 1
	var acts := CardEngine.legal_actions(st, "B")
	var can_play := false
	for a in acts:
		if a["type"] == "play":
			can_play = true
	_check("8: last-card Ace is playable in a 1v1", can_play)
	r = CardEngine.apply_action(st, {"type": "play", "playerId": "B", "cardId": 2})
	_check("8: Ace does not take B out, game continues", r["ok"] and not r["state"]["over"] and r["state"]["players"][1]["status"] == "playing")
	_check("8: A skipped, B keeps the turn with no cards", r["state"]["current"] == 1 and r["state"]["players"][1]["hand"].is_empty())
	r = CardEngine.apply_action(r["state"], {"type": "draw", "playerId": "B"})
	_check("8: B draws and the turn passes to A", r["ok"] and r["state"]["current"] == 0 and r["state"]["players"][1]["hand"].size() == 1)

	print("FINAL TURN:%s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
