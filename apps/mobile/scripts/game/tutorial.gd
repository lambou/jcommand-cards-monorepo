extends RefCounted
## The playable tutorial: four short chapters, each a rigged 1v1 hand against Rex.
## This file is UI-free data plus the step logic, so tests can replay every chapter headless
## (tests/test_tutorial.gd) and fail the moment a rules change breaks a lesson.
##
## A chapter is {id, title, blurb, hand_size, you, rex, start, bank, rex_script, steps, outro}:
##   you / rex   hand cards as codes ("7H", "10S", "JR" red joker, "JB" black joker)
##   start       the starting card, bank = the cards drawn from the bank, in drawing order
##   rex_script  what Rex does on his turns, in order: {play:"10H"} | {draw:true} | {take:true}
##   steps       what Rex says; see below
##   outro       what Rex says when the chapter is done
##
## A step is {say, target, expect, nudge, when}:
##   say      Rex's line
##   target   what to spotlight: "" | "pile" | "required" | "bank" | "rex" | "card:9H" (while the J picker is open, its expected suit)
##   expect   null = a read step (the player taps Next), else the one action that moves on:
##            {type:"play", card:"9H", suit?:"D"} | {type:"draw"} | {type:"takePenalty"}
##   nudge    what Rex says when the player does something else
##   when     "turn" (default): shown once it is your turn and the board has settled

const Cards := preload("res://scripts/engine/cards.gd")
const Rules := preload("res://scripts/engine/rules.gd")
const Scoring := preload("res://scripts/game/scoring.gd")

const ME := "you"
const REX := "bot1"

var chapter: Dictionary = {}
var chapter_index := 0
var index := 0 # the current step; == steps.size() once the chapter is done


func _init(p_chapter_index: int = 0) -> void:
	chapter_index = clampi(p_chapter_index, 0, count() - 1)
	chapter = chapters()[chapter_index]


static func count() -> int:
	return chapters().size()


func steps() -> Array:
	return chapter["steps"]


func done() -> bool:
	return index >= steps().size()


func step() -> Dictionary:
	return {} if done() else steps()[index]


func advance() -> void:
	index += 1


func is_last_chapter() -> bool:
	return chapter_index >= count() - 1


## True when the current step is waiting for the player to do something on the table.
func expects_action() -> bool:
	return not done() and step()["expect"] != null


## Does this human action match what the current step is waiting for?
## `card_code` is the played card (Cards.card_code) for plays, else "".
func matches(action_type: String, card_code: String = "", suit: String = "") -> bool:
	if not expects_action():
		return false
	var ex: Dictionary = step()["expect"]
	if str(ex["type"]) != action_type:
		return false
	if action_type == "play":
		if str(ex["card"]) != card_code:
			return false
		if ex.has("suit") and str(ex["suit"]) != suit:
			return false
	return true


## The J step needs the picked suit too: does this card open the picker at this step?
func wants_card(card_code: String) -> bool:
	return expects_action() and str(step()["expect"]["type"]) == "play" and str(step()["expect"]["card"]) == card_code


# ---------------------------------------------------------------- the rigged deal

## A deck for Engine.create_game: it deals from the END, one card each in turn (you, Rex, you, Rex ...),
## then flips the start card, and the bank is drawn from the end too. Card ids are unique.
static func build_deck(c: Dictionary) -> Array:
	var codes: Array = []
	var bank: Array = (c["bank"] as Array).duplicate()
	bank.reverse() # bottom of the deck first, so it is drawn last
	codes.append_array(bank)
	codes.append(c["start"])
	var dealt: Array = []
	var you: Array = c["you"]
	var rex: Array = c["rex"]
	for i in you.size():
		dealt.append(you[i])
		dealt.append(rex[i])
	dealt.reverse()
	codes.append_array(dealt)
	var deck: Array = []
	for i in codes.size():
		deck.append(Cards.parse_card(str(codes[i]), i))
	return deck


## Rex's next scripted move resolved against the live state: a legal engine action, or {} to let the bot AI decide.
static func rex_action(script_entry: Dictionary, state: Dictionary) -> Dictionary:
	if script_entry.has("take"):
		return {"type": "takePenalty", "playerId": REX}
	if script_entry.has("draw"):
		return {"type": "draw", "playerId": REX}
	if script_entry.has("play"):
		for p in state["players"]:
			if p["id"] != REX:
				continue
			for card in p["hand"]:
				if Cards.card_code(card) == str(script_entry["play"]):
					return {"type": "play", "playerId": REX, "cardId": card["id"], "chosenSuit": str(script_entry.get("suit", ""))}
	return {}


# ---------------------------------------------------------------- chapters

## `picker_say` / `picker_nudge`: what Rex says instead while the J's suit picker is open.
static func _step(say: String, target: String = "", expect = null, nudge: String = "", picker_say: String = "", picker_nudge: String = "") -> Dictionary:
	return {"say": say, "target": target, "expect": expect, "nudge": nudge, "when": "turn",
		"picker_say": picker_say, "picker_nudge": picker_nudge}


static func _play(card: String, suit: String = "") -> Dictionary:
	var a := {"type": "play", "card": card}
	if suit != "":
		a["suit"] = suit
	return a


static func chapters() -> Array:
	var seven := Rules.penalty_of("7")
	var joker := Rules.penalty_of("JOKER")
	return [
		{
			"id": "basics", "title": "The basics", "blurb": "Match the pile, or draw",
			"hand_size": 5,
			"you": ["9H", "4S", "KD", "QC", "5C"],
			"rex": ["10H", "8H", "3S", "6D", "AC"],
			"start": "6H",
			"bank": ["3H", "9S", "10C", "4D", "KS", "8D"],
			"rex_script": [{"play": "10H"}, {"play": "8H"}, {"draw": true}],
			"steps": [
				_step("Hi, I'm Rex! Let's learn Zapko. The goal is simple: be the first to get rid of all your cards."),
				_step("This is the pile. The badge says hearts, so you must play a heart - or a card with the same number as the one on top.", "required"),
				_step("You have one heart: the 9. Tap it to play it.", "card:9H", _play("9H"), "Not that one - tap the glowing 9 of hearts."),
				_step("Hearts are still wanted, and you have none. No match means you draw. Tap the bank.", "bank", {"type": "draw"}, "Tap the bank to draw a card."),
				_step("Drawing ends your turn - so only draw when you have to. Rex plays, and now you hold a heart! Play it.", "card:3H", _play("3H"), "Tap the glowing 3 of hearts."),
			],
			"outro": "That's the core of the game: match the suit or the number, otherwise draw. Next: the cards that hit back.",
		},
		{
			"id": "penalties", "title": "7s and Jokers", "blurb": "Make your rival draw",
			"hand_size": 5,
			"you": ["7D", "7H", "9D", "4C", "QS"],
			"rex": ["JR", "6C", "KS", "3C", "8S"],
			"start": "5D",
			"bank": ["2C", "4H", "6S", "10C", "3D", "5S", "9C", "8C"],
			"rex_script": [{"take": true}, {"play": "JR"}, {"take": true}],
			"steps": [
				_step("Some cards are weapons. A 7 makes the next player draw %d cards. Diamonds are wanted - play your 7 of diamonds!" % seven, "card:7D", _play("7D"), "Tap the glowing 7 of diamonds."),
				_step("Rex has no answer, so he took %d cards. Now play any diamond to keep going - the 9." % seven, "card:9D", _play("9D"), "Tap the glowing 9 of diamonds."),
				_step("Uh-oh, my red Joker! A Joker makes you draw %d. You could take them with the bank - but you can also block with a 7 or a Joker and pass it on. Block with your 7 of hearts!" % joker, "card:7H", _play("7H"), "Tap the glowing 7 of hearts to block."),
			],
			"outro": "Penalties stack: every 7 or Joker you add makes the pile bigger for whoever can't answer. Rex just took %d cards!" % (joker + seven),
		},
		{
			"id": "specials", "title": "J, Ace and 2", "blurb": "Change suit, skip, slide",
			"hand_size": 5,
			"you": ["JS", "AD", "2C", "9C", "5H"],
			"rex": ["4D", "6C", "KH", "3S", "10C"],
			"start": "8S",
			"bank": ["5D", "9H", "6H", "QD"],
			"rex_script": [{"play": "4D"}, {"draw": true}],
			"steps": [
				_step("The Jack is the boss of suits. Spades are wanted, so your J of spades fits. Tap it!", "card:JS", _play("JS", "D"), "Tap the glowing J of spades.",
					"Now you choose the next suit. Pick diamonds - you'll see why in a second.", "Pick diamonds for this lesson."),
				_step("Rex had to follow diamonds - you chose it! Now the Ace is a Stop: it skips Rex, so you go again. Play your Ace of diamonds.", "card:AD", _play("AD"), "Tap the glowing Ace of diamonds."),
				_step("Rex was skipped. And the 2 is a free pass: it goes on anything and slides under the pile, changing nothing. Play it!", "card:2C", _play("2C"), "Tap the glowing 2 of clubs."),
			],
			"outro": "Jack: pick the suit. Ace: skip the next player. 2: a free card that changes nothing. You'll love them when you're stuck.",
		},
		{
			"id": "winning", "title": "Winning", "blurb": "Go out, score points",
			"hand_size": 3,
			"you": ["QH", "8H", "5H"],
			"rex": ["9S", "4C", "KD"],
			"start": "3H",
			"bank": ["6S", "10C", "5D"],
			"rex_script": [{"draw": true}, {"draw": true}],
			"steps": [
				_step("Let's finish a game! You have three hearts and hearts are wanted. Start with the Queen.", "card:QH", _play("QH"), "Tap the glowing Queen of hearts."),
				_step("Good. Rex can't play, so he drew. Keep going - the 8.", "card:8H", _play("8H"), "Tap the glowing 8 of hearts."),
				_step("One card left - everyone sees CHECK! Play your last card to go out and win.", "card:5H", _play("5H"), "Tap the glowing 5 of hearts to go out."),
			],
			"outro": "You went out first - and you never drew from the bank, so that's a CLEAN FINISH: +%d points on top of the %d for winning. Score more with combos of Aces and by passing penalties on. Good luck out there!" % [Scoring.CLEAN_BONUS, Scoring.WIN_POINTS],
		},
	]
