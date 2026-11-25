extends SceneTree
## The dealer's hand (ui/hand3d.gd deal_step / deal_end) on its own, without a table:
##  - the index and middle fingers are curled while a card is held and straight + splayed as it is thrown,
##    while the ring and little fingers stay curled;
##  - the hand leans toward the side the card goes to;
##  - it glides (no teleporting between cards) and leaves the screen at the end;
##  - a normal draw (carry) afterwards is not affected by the dealer's spring.
##   godot --headless --fixed-fps 60 --path apps/mobile -s res://scripts/tests/test_hand_flick.gd

const Hand3D := preload("res://scripts/ui/hand3d.gd")

var failures: Array = []
var hand: Control
var card: Control


func _init() -> void:
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


## Rotation (degrees) of joint `j` of finger `i`.
func _curl(i: int, j: int) -> float:
	return rad_to_deg((hand._fingers[i]["joints"][j] as Node3D).rotation.x)


func _splay(i: int) -> float:
	return rad_to_deg((hand._fingers[i]["base"] as Node3D).rotation.z)


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await process_frame
		t += root.get_process_delta_time()


func _run() -> void:
	hand = Hand3D.new()
	root.add_child(hand)
	card = Control.new()
	card.size = Vector2(150.0, 215.0)
	card.position = Vector2(500.0, 600.0)
	card.pivot_offset = card.size / 2.0
	root.add_child(card)
	await process_frame

	# --- one throw to the right, from the top: reach 0.2 s, hold, throw (flick 0.4 s)
	hand.deal_step(card, 0.2, 0.4, true, 0, 300.0, 1.0)
	await _wait(0.2 - 0.01) # gripping the card, just before the throw starts
	var held_index: float = _curl(0, 1)
	var held_mid: float = _curl(1, 1)
	var held_ring: float = _curl(2, 1)
	var held_splay: float = _splay(0)
	_check(held_index < -60.0 and held_mid < -60.0, "holding: index/middle are curled onto the card (%.0f, %.0f)" % [held_index, held_mid])
	await _wait(0.01 + 0.4 * 0.6 + 0.03) # the throw is complete
	var thrown_index: float = _curl(0, 1)
	var thrown_mid: float = _curl(1, 1)
	var thrown_ring: float = _curl(2, 1)
	_check(thrown_index > -20.0, "thrown: the index finger is straight (%.0f)" % thrown_index)
	_check(thrown_mid > -20.0, "thrown: the middle finger is straight (%.0f)" % thrown_mid)
	_check(thrown_ring < -60.0, "thrown: the ring finger stays curled (%.0f)" % thrown_ring)
	_check(held_ring < -80.0, "holding: the ring finger is curled (%.0f)" % held_ring)
	_check(_splay(0) - held_splay > 4.0, "thrown: the index finger fans out (%.1f -> %.1f)" % [held_splay, _splay(0)])
	_check(_splay(1) < _splay(0) - 6.0, "thrown: index and middle fingers spread apart")
	_check(hand.flick > 0.95, "the throw reaches full extension")
	_check(absf(hand._aim) > 0.3, "the hand leans toward the target (aim %.2f)" % hand._aim)
	# aiming right from a top hand leans the other way from aiming left
	var aim_right: float = hand._aim

	# --- the next card, thrown the other way: the fingers relax while reaching, then extend again
	card.position = Vector2(500.0, 600.0)
	hand.deal_step(card, 0.3, 0.4, true, 0, 300.0, -1.0)
	await _wait(0.3 - 0.01)
	_check(_curl(0, 1) < -60.0, "reaching for the next card: the index finger curls again (%.0f)" % _curl(0, 1))
	await _wait(0.4 * 0.6 + 0.05)
	_check(_curl(0, 1) > -20.0, "second throw: the index finger extends again")
	_check(hand._aim * aim_right < 0.0, "a throw to the other side leans the other way (%.2f vs %.2f)" % [aim_right, hand._aim])

	# --- the throw pose is long enough to be seen at a low frame rate (the table's own timing: 0.095 s throw, 26 fps = 38 ms frames)
	hand.deal_end()
	await _wait(1.2)
	card.position = Vector2(500.0, 600.0)
	hand.deal_step(card, 0.7, 0.0952, true, 0, 300.0, 0.5)
	await _wait(0.7)
	var visible_for := 0.0
	var t_end := 0.0
	while t_end < 0.8:
		await process_frame
		var dt := root.get_process_delta_time()
		t_end += dt
		if _curl(0, 1) > -45.0 and _curl(1, 1) > -45.0:
			visible_for += dt
	_check(visible_for >= 0.2, "the first throw shows the extended fingers for at least 0.2 s (%.2f s)" % visible_for)
	_check(is_zero_approx(hand.flick) or hand.flick < 0.05, "...and relaxes afterwards (%.2f)" % hand.flick)

	# --- the card is launched BY the throw: exactly once, in the frame the fingers start to extend, and never lost
	hand.deal_end()
	await _wait(1.2)
	var launches := [0, -1.0, -1.0] # count, hand.flick when launched, time of launch
	var clock := [0.0] # an array: a lambda captures plain variables by value
	card.position = Vector2(500.0, 600.0)
	hand.deal_step(card, 0.5, 0.0952, true, 0, 300.0, 0.0, func():
		launches[0] += 1
		launches[1] = hand.flick
		launches[2] = clock[0])
	var seen_flick_at := -1.0
	while clock[0] < 1.0:
		await process_frame
		clock[0] += root.get_process_delta_time()
		if seen_flick_at < 0.0 and hand.flick > 0.0:
			seen_flick_at = clock[0]
	_check(launches[0] == 1, "the throw launches its card exactly once (%d)" % launches[0])
	_check(absf(float(launches[2]) - 0.5) < 0.06, "...at the end of the reach (%.2f s)" % float(launches[2]))
	_check(seen_flick_at >= 0.0 and absf(seen_flick_at - float(launches[2])) < 0.05, "...as the fingers start to extend (card %.2f s, fingers %.2f s)" % [float(launches[2]), seen_flick_at])
	# A throw that is cut short (the next grab, deal_end, or a draw taking over) still sends its card.
	var cut := [0]
	hand.deal_step(card, 0.6, 0.1, true, 0, 300.0, 0.0, func(): cut[0] += 1)
	await _wait(0.1)
	hand.deal_step(card, 0.2, 0.1, true, 0, 300.0, 0.0)
	_check(cut[0] == 1, "a throw interrupted by the next grab still sends its card (%d)" % cut[0])
	var cut2 := [0]
	hand.deal_step(card, 0.6, 0.1, true, 0, 300.0, 0.0, func(): cut2[0] += 1)
	await _wait(0.1)
	hand.deal_end()
	_check(cut2[0] == 1, "a throw interrupted by deal_end still sends its card (%d)" % cut2[0])
	await _wait(1.2)

	# --- gliding: the hand never jumps between frames while moving to a faraway card
	card.position = Vector2(100.0, 1200.0)
	hand.deal_step(card, 0.7, 0.3, true, 0, 300.0, 0.0) # the real first reach
	var prev: Vector2 = hand.pos
	var worst := 0.0
	var elapsed := 0.0
	while elapsed < 0.7:
		await process_frame
		var dt := root.get_process_delta_time()
		elapsed += dt
		worst = maxf(worst, (hand.pos - prev).length() / maxf(dt, 0.001) / 60.0) # px per 1/60 s
		prev = hand.pos
	_check(worst < 140.0, "the hand glides (worst %.0f px per frame)" % worst)

	# --- leaving
	hand.deal_end()
	await _wait(1.2)
	_check(not hand.visible, "the dealer's hand leaves the screen")
	_check(not hand._sp_on, "the spring is off once the hand has left")

	# --- a normal draw afterwards still works exactly as before
	card.position = Vector2(500.0, 900.0)
	hand.carry(card, 0.2, 0.3, false, 0)
	_check(not hand._sp_on, "a draw does not use the dealer's spring")
	_check(hand.visible and is_equal_approx(hand.flick, 0.0), "a draw starts with the fingers in their normal pose")
	await _wait(0.2 + 0.05)
	_check(hand.pos.distance_to(hand._grip_point(card)) < 4.0, "a draw's hand reaches the card")
	await _wait(0.3 + 0.8)
	_check(not hand.visible, "a draw's hand leaves when done")

	if failures.is_empty():
		print("PASS: dealer hand (throw pose, aim, glide, draw unaffected)")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)
