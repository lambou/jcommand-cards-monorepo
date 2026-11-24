extends SceneTree
## Headless check that the gripping hand really pinches: the thumb tip touches both the index and the middle
## fingertip (their end caps meet), the other two fingers are curled in, and the thumb is open when the hand is:
##   godot --headless --path apps/mobile -s res://scripts/tests/hand_pinch.gd
## Exits non-zero on failure.

const Hand3D := preload("res://scripts/ui/hand3d.gd")


func _init() -> void:
	var hand := Hand3D.new()
	root.add_child(hand)
	await process_frame # _ready builds the 3D hand
	var fails: Array = []

	hand.grip = 1.0
	hand._apply_pose()
	var thumb := _tip(hand._thumb_joints, Hand3D.THUMB_LEN)
	var thumb_r := _end_r(Hand3D.THUMB_R, Hand3D.THUMB_LEN.size())
	for k in [0, 1]: # index, middle
		var def: Dictionary = Hand3D.FINGERS[k]
		var tip := _tip(hand._fingers[k]["joints"], def["len"])
		var reach := thumb_r + _end_r(float(def["r"]), (def["len"] as Array).size())
		var d := thumb.distance_to(tip)
		print("thumb -> finger %d: %.1f (touching at %.1f)" % [k, d, reach])
		if d > reach: # the end caps do not meet
			fails.append("thumb tip is %.1f from finger %d's tip, they only touch within %.1f" % [d, k, reach])
		if d < reach * 0.5: # swallowed by the finger
			fails.append("thumb tip sinks into finger %d (%.1f of %.1f)" % [k, d, reach])

	# Ring and little finger tucked into the palm: curled by more than a right angle in total.
	for k in [2, 3]:
		var total := 0.0
		for j in 3:
			total += absf(rad_to_deg((hand._fingers[k]["joints"][j] as Node3D).rotation.x))
		if total < 180.0:
			fails.append("finger %d is only curled %.0f degrees" % [k, total])

	hand.grip = 0.0
	hand._apply_pose()
	var open_gap := _tip(hand._thumb_joints, Hand3D.THUMB_LEN).distance_to(_tip(hand._fingers[0]["joints"], Hand3D.FINGERS[0]["len"]))
	if open_gap < 60.0:
		fails.append("the open hand's thumb is already near the index finger (%.1f)" % open_gap)

	for f in fails:
		printerr("FAIL: ", f)
	print("HAND PINCH ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


## Centre of the end cap of a chain of segments (the last joint's origin plus its length along its own axis).
func _tip(joints: Array, lens: Array) -> Vector3:
	var last: Node3D = joints[joints.size() - 1]
	return last.global_transform * Vector3(0, float(lens[lens.size() - 1]), 0)


func _end_r(r: float, segments: int) -> float:
	return r * (1.0 - 0.07 * float(segments - 1))
