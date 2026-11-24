extends RefCounted
## Score for one finished game (human's view). Pure functions, no state.
##
## Base points by finishing place, then a bonus, then a multiplier for the field size and difficulty.
## CLEAN FINISH: getting out of the game without ever tapping the bank to draw (forced penalty
## draws do not count against you). It is worth 3x a win and applies to any place except last.

const Rules := preload("res://scripts/engine/rules.gd")

const WIN_POINTS := 1000
const CLEAN_BONUS := 3000
const FEW_DRAWS_MAX := 200   # bonus for a game with few voluntary draws
const FEW_DRAWS_STEP := 50   # lost per voluntary draw

# COMBOS: cards played back to back by the same player (Aces skip the opponent in 1v1).
const COMBO_POINTS := {2: 150, 3: 400, 4: 900}   # by chain length; 5+ uses COMBO_LONG
const COMBO_LONG := 2000                          # 5 cards, +1000 per extra card
const JACKPOT_4_ACES := 3000                      # all four Aces in one chain
const JACKPOT_FOLLOWUP := 2000                    # ...and another card played right after

const PENALTY_FINISH_PER_CARD := 250   # going out on a 7 (2 cards) = 500, on a Lion (4) = 1000
const WINNING_CARD := 500              # the last card of a 1st-place finish

const FIELD_MULT := {1: 1.0, 2: 1.5, 3: 2.0}      # by number of bots
const DIFFICULTY_MULT := {"easy": 0.6, "normal": 1.0}


## Returns {total, mult, clean, lines: [[label, points], ...]}. `draws` = voluntary bank draws.
static func compute(place: int, players: int, bots: int, difficulty: String, draws: int, chains: Array = [], finish_rank: String = "") -> Dictionary:
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
	for c in chains:
		var n := int(c["len"])
		if n < 2:
			continue
		var pts: int = int(COMBO_POINTS[n]) if COMBO_POINTS.has(n) else COMBO_LONG + 1000 * (n - 5)
		bonus += pts
		lines.append(["Combo x%d" % n, pts])
		if int(c["aces"]) >= 4:
			var jp := JACKPOT_4_ACES + (JACKPOT_FOLLOWUP if n > 4 else 0)
			bonus += jp
			lines.append(["JACKPOT - four Aces%s" % (" + a follow-up card" if n > 4 else ""), jp])
	# Finishing card: a penalty card (7 = +2, Lion = +4) as your last card, and the winning card.
	if finish_rank != "":
		var pen := Rules.penalty_of(finish_rank)
		if pen > 0:
			var pp: int = PENALTY_FINISH_PER_CARD * pen
			bonus += pp
			lines.append(["Went out on a penalty card (+%d draw)" % pen, pp])
		if place == 1:
			bonus += WINNING_CARD
			lines.append(["Winning card", WINNING_CARD])
	var mult: float = float(FIELD_MULT.get(bots, 1.0)) * float(DIFFICULTY_MULT.get(difficulty, 1.0))
	var total := int(round(float(base + bonus) * mult))
	return {"total": total, "mult": mult, "clean": clean, "lines": lines}


static func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n
