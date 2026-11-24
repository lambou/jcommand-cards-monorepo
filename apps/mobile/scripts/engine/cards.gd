extends RefCounted
## Cards are plain dictionaries: {id:int, rank:String, suit:String, color:String}.
## Jokers have rank "JOKER" and suit "".

const Rules := preload("res://scripts/engine/rules.gd")

const SUITS := ["H", "D", "C", "S"]


static func suit_color(suit: String) -> String:
	return "red" if (suit == "H" or suit == "D") else "black"


static func create_deck() -> Array:
	var cards: Array = []
	var id := 0
	var deck: Dictionary = Rules.spec()["deck"]
	for suit in deck["suits"]:
		for rank in deck["ranks"]:
			cards.append({"id": id, "rank": rank, "suit": suit, "color": suit_color(suit)})
			id += 1
	for color in deck["jokers"]:
		cards.append({"id": id, "rank": "JOKER", "suit": "", "color": color})
		id += 1
	return cards


## "7H", "10S", "AD", "JR" (red joker), "JB" (black joker).
static func card_code(card: Dictionary) -> String:
	if card["rank"] == "JOKER":
		return "JR" if card["color"] == "red" else "JB"
	return str(card["rank"]) + str(card["suit"])


static func parse_card(code: String, id: int) -> Dictionary:
	if code == "JR":
		return {"id": id, "rank": "JOKER", "suit": "", "color": "red"}
	if code == "JB":
		return {"id": id, "rank": "JOKER", "suit": "", "color": "black"}
	var suit := code.substr(code.length() - 1)
	var rank := code.substr(0, code.length() - 1)
	assert(SUITS.has(suit) and (Rules.spec()["deck"]["ranks"] as Array).has(rank), "Bad card code: " + code)
	return {"id": id, "rank": rank, "suit": suit, "color": suit_color(suit)}
