extends SceneTree
## Headless check that every hand at a table gets its own colour, for every colour choice:
##   godot --headless --path apps/mobile -s res://scripts/tests/hand_colors.gd
## Exits non-zero on failure.

const Hand3D := preload("res://scripts/ui/hand3d.gd")
const MAX_BOTS := 3 # the menu offers 1-3 bots


func _init() -> void:
	var fails: Array = []
	var n: int = Hand3D.STYLES.size()

	# The styles themselves must all look different.
	for a in n:
		for b in range(a + 1, n):
			if Hand3D.STYLES[a][1] == Hand3D.STYLES[b][1] or Hand3D.STYLES[a][2] == Hand3D.STYLES[b][2]:
				fails.append("styles %s and %s share a glove or sleeve colour" % [Hand3D.STYLES[a][0], Hand3D.STYLES[b][0]])

	# For every choice of the player's colour and every bot count, no two seats share a style.
	for base in n + 3: # past n also covers wrap-around of a saved index
		for bots in range(1, MAX_BOTS + 1):
			var seen := {}
			for seat in bots + 1: # seat 0 = you, 1.. = bots
				var s: int = Hand3D.style_for(seat, base)
				if seen.has(s):
					fails.append("colour %d, %d bots: seats %d and %d both use style %d" % [base, bots, seen[s], seat, s])
				seen[s] = seat

	# The limit worth knowing: more players than styles cannot all differ.
	if n < MAX_BOTS + 1:
		fails.append("only %d styles for %d players" % [n, MAX_BOTS + 1])

	for f in fails:
		printerr("FAIL: ", f)
	print("HAND COLORS ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
