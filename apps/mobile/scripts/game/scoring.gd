extends RefCounted
## Score for one finished game (human's view). Pure functions, no state.
##
## Base points by finishing place, then a bonus, then a multiplier for the field size and difficulty.
## CLEAN FINISH: getting out of the game without ever tapping the bank to draw (forced penalty
## draws do not count against you). It is worth 3x a win and applies to any place except last.

const WIN_POINTS := 1000
const CLEAN_BONUS := 3000
const FEW_DRAWS_MAX := 200   # bonus for a game with few voluntary draws
const FEW_DRAWS_STEP := 50   # lost per voluntary draw

const FIELD_MULT := {1: 1.0, 2: 1.5, 3: 2.0}      # by number of bots
const DIFFICULTY_MULT := {"easy": 0.6, "normal": 1.0}


## Returns {total, mult, clean, lines: [[label, points], ...]}. `draws` = voluntary bank draws.
static func compute(place: int, players: int, bots: int, difficulty: String, draws: int) -> Dictionary:
	var lines: Array = []
	var base := int(round(float(WIN_POINTS) * float(players - place) / float(players - 1)))
	if place == 1:
		base = WIN_POINTS
	lines.append(["Finished %s of %d" % [_ordinal(place), players], base])
	var clean := draws == 0 and place < players
	var bonus := 0
	if clean:
		bonus = CLEAN_BONUS
		lines.append(["CLEAN FINISH - never drew from the bank", CLEAN_BONUS])
	elif place < players:
		bonus = maxi(0, FEW_DRAWS_MAX - FEW_DRAWS_STEP * draws)
		if bonus > 0:
			lines.append(["Few draws (%d)" % draws, bonus])
	var mult: float = float(FIELD_MULT.get(bots, 1.0)) * float(DIFFICULTY_MULT.get(difficulty, 1.0))
	var total := int(round(float(base + bonus) * mult))
	return {"total": total, "mult": mult, "clean": clean, "lines": lines}


static func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n
