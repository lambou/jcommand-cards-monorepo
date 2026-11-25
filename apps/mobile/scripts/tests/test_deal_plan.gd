extends SceneTree
## The deal choreography (game/deal_plan.gd) is plain data, so its rules are checked without a scene:
##   godot --headless --path apps/mobile -s res://scripts/tests/test_deal_plan.gd

const DealPlan := preload("res://scripts/game/deal_plan.gd")
const Settings := preload("res://scripts/game/settings.gd")

var failures: Array = []


func _init() -> void:
	var ids := ["you", "bot1", "bot2"]
	_check(DealPlan.dealer_of(ids, 0) == "bot2", "the last mover deals when player 0 starts")
	_check(DealPlan.dealer_of(ids, 1) == "you", "the dealer is the one before the first mover")
	_check(DealPlan.turn_order(ids, 1) == ["bot1", "bot2", "you"], "turn order starts with the first mover")

	for style in [DealPlan.FLY, DealPlan.DEALER, DealPlan.PACKETS]:
		for glove in [false, true]:
			_check_plan(style, glove, ids, 7)
			_check_plan(style, glove, ["you", "bot1"], 5)

	# Round-robin hands the first card to the first mover and the last to the dealer; packets go one player at a time.
	var rr := DealPlan.build(DealPlan.DEALER, ids, 3, true)
	_check(rr["steps"][0]["seat"] == "you" and rr["steps"][2]["seat"] == "bot2", "round-robin starts left of the dealer")
	var pk := DealPlan.build(DealPlan.PACKETS, ids, 3, false)
	_check(pk["steps"][0]["seat"] == "you" and pk["steps"][2]["seat"] == "you" and pk["steps"][3]["seat"] == "bot1",
		"a packet is one player's whole hand")
	# Only the dealer style with a hand has a hand to move.
	_check(DealPlan.build(DealPlan.DEALER, ids, 3, false)["steps"][0]["grab"] < 0.0, "no glove, no grab")
	_check(DealPlan.build(DealPlan.FLY, ids, 3, true)["steps"][0]["grab"] < 0.0, "flying cards never use the hand")
	_check(DealPlan.build(DealPlan.DEALER, ids, 3, true)["steps"][0]["grab"] >= 0.0, "the dealer's hand grabs")

	_check_pacing(ids)
	_check_settings()

	if failures.is_empty():
		print("PASS: deal plan")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _check_plan(style: int, glove: bool, ids: Array, hand_size: int) -> void:
	var tag := "style %d glove %s %d players" % [style, str(glove), ids.size()]
	var plan := DealPlan.build(style, ids, hand_size, glove)
	var steps: Array = plan["steps"]
	_check(steps.size() == ids.size() * hand_size, tag + ": every player gets hand_size cards")
	var per := {}
	var prev := -1.0
	for s in steps:
		per[s["seat"]] = int(per.get(s["seat"], 0)) + 1
		_check(float(s["send"]) >= prev, tag + ": cards are sent in order")
		prev = s["send"]
		if float(s["grab"]) >= 0.0:
			_check(float(s["grab"]) < float(s["send"]), tag + ": the hand grabs before it sends")
	for id in ids:
		_check(int(per.get(id, 0)) == hand_size, tag + ": %s gets %d cards" % [id, hand_size])
	_check(float(plan["start"]["send"]) > prev, tag + ": the starting card comes after the last card")
	if style == DealPlan.DEALER and glove:
		_check(float(plan["release"]) > float(plan["start"]["send"]), tag + ": the hand leaves after the starting card")
	else:
		_check(float(plan["release"]) < 0.0, tag + ": no hand to release")


## The dealer's hand sends a card every `cycle` seconds, evenly, and the whole deal scales with the pace.
func _check_pacing(ids: Array) -> void:
	var plan := DealPlan.build(DealPlan.DEALER, ids, 7, true)
	var steps: Array = plan["steps"]
	for i in range(1, steps.size()):
		var gap: float = float(steps[i]["send"]) - float(steps[i - 1]["send"])
		_check(absf(gap - DealPlan.CYCLE) < 0.0001, "dealer cards are evenly paced (gap %.3f at card %d)" % [gap, i])
		_check(float(steps[i]["grab"]) > float(steps[i - 1]["send"]), "the hand reaches for the next card after sending the last")
	var fast := DealPlan.build(DealPlan.DEALER, ids, 7, true, 0.2)
	var slow := DealPlan.build(DealPlan.DEALER, ids, 7, true, 0.4)
	_check(float(slow["start"]["send"]) > float(fast["start"]["send"]) * 1.7, "a slower pace makes a longer deal")
	_check(float(plan["flick"]) > 0.0 and float(plan["flick"]) < DealPlan.CYCLE * DealPlan.HOLD, "the throw fits inside the hold, before the next grab")
	for i in range(1, steps.size()):
		_check(float(steps[i]["grab"]) - float(steps[i - 1]["send"]) >= float(plan["flick"]), "the next grab never cuts a throw short")
	# Without a hand it keeps the same rhythm; flying cards are the quick all-at-once deal.
	var nohand := DealPlan.build(DealPlan.DEALER, ids, 7, false)
	_check(absf(float(nohand["steps"][1]["send"]) - float(nohand["steps"][0]["send"]) - DealPlan.CYCLE) < 0.0001, "no hand: same pace")
	var fly := DealPlan.build(DealPlan.FLY, ids, 7, false)
	_check(float(fly["start"]["send"]) < float(plan["start"]["send"]), "flying cards are the fastest deal")
	_check(absf(float(fly["steps"][1]["send"]) - float(fly["steps"][0]["send"]) - DealPlan.STAGGER) < 0.0001, "flying cards use the stagger")


func _check_settings() -> void:
	_check(Settings.DEAL_STYLES.size() == 3, "three deal styles")
	_check(Settings.DEAL_STYLES[DealPlan.FLY] == "Flying cards" and Settings.DEAL_STYLES[DealPlan.DEALER] == "Dealer hand" 			and Settings.DEAL_STYLES[DealPlan.PACKETS] == "Packets", "the style list matches the plan's constants")
	_check(Settings.deal_style == DealPlan.DEALER, "the default style is the dealer hand")
