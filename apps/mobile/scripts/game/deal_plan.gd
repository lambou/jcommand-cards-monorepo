extends RefCounted
## The choreography of the opening deal as plain data: who gets which card, and when the dealer's hand grips it
## and sends it. No nodes, no tweens, nothing about drawing: the table (and the deal playground) just carry the
## plan out, so the deal can change without touching how cards are drawn, and the plan can be tested headless
## (scripts/tests/test_deal_plan.gd).
##
## Styles match Settings.DEAL_STYLES: FLY = every card flies at once, DEALER = the dealer's hand flicks them out
## one at a time, PACKETS = each player gets their whole hand in a quick burst.

const FLY := 0
const DEALER := 1
const PACKETS := 2

const CYCLE := 0.34 # seconds per card with the dealer's hand (and the breath between packets)
const STAGGER := 0.07 # FLY: delay between cards
const FIRST_REACH := 0.7 # the dealer's hand coming in for the first card
const START_REACH := 0.25 # ... and for the starting card
const PACKET_GAP := 0.06 # PACKETS: delay between cards of one packet
## Share of a card's time the hand spends throwing; the rest it spends gliding back to the bank for the next
## card. The throw (`flick`) always fits inside the hold, so the next grab never cuts it short.
const HOLD := 0.3


## Ids in turn order, the player who moves first at the front.
static func turn_order(ids: Array, first: int) -> Array:
	return ids.slice(first) + ids.slice(0, first)


## The dealer is the player who moves last (the one before the first mover).
static func dealer_of(ids: Array, first: int) -> Variant:
	return ids[posmod(first - 1, ids.size())]


## Builds the plan. Times are seconds from the start of the deal.
##   steps: [{seat, round, grab, send}] in dealing order. `send` is when the card leaves the bank; `grab` is when
##          the dealer's hand starts reaching for it (-1 when there is no hand).
##   start: {grab, send}  the starting card, turned over onto the stack after the last card.
##   release: when the dealer's hand lets go and leaves (-1 when there is no hand).
##   flick: how long the hand holds a card after sending it.
## `ids` is in turn order (see turn_order). `glove` only matters for DEALER.
static func build(style: int, ids: Array, hand_size: int, glove: bool, cycle: float = CYCLE,
		stagger: float = STAGGER) -> Dictionary:
	var hand := style == DEALER and glove
	var plan := {"steps": [], "flick": cycle * HOLD * 0.9, "release": -1.0}
	var order: Array = [] # [seat, round]
	if style == PACKETS:
		for id in ids:
			for r in hand_size:
				order.append([id, r])
	else:
		for r in hand_size:
			for id in ids:
				order.append([id, r])
	var cursor := 0.0 # DEALER / PACKETS: when the next card is sent
	for idx in order.size():
		var send := stagger * idx
		var grab := -1.0
		match style:
			DEALER:
				if hand:
					var reach := FIRST_REACH if idx == 0 else cycle * (1.0 - HOLD)
					grab = cursor
					send = cursor + reach
					cursor = send + cycle * HOLD
				else:
					send = cursor
					cursor += cycle
			PACKETS:
				send = cursor
				cursor += cycle * 1.4 if order[idx][1] == hand_size - 1 else PACKET_GAP
		plan["steps"].append({"seat": order[idx][0], "round": order[idx][1], "grab": grab, "send": send})
	var start_send := stagger * order.size() + 0.1
	var start_grab := -1.0
	if style != FLY:
		start_send = cursor + (START_REACH if hand else 0.1)
		if hand:
			start_grab = cursor
			plan["release"] = start_send + 0.1
	plan["start"] = {"grab": start_grab, "send": start_send}
	return plan
