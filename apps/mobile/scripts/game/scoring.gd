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

const PENALTY_FINISH_PER_CARD := 250   # going out on a 7 (2 cards) = 500, on a Joker (4) = 1000
const PASS_ON_PER_CARD := 250          # per penalty card you added to a pile someone else took
const PASS_ON_PER_PILE_CARD := 100     # per card the victim had to draw
const WINNING_CARD := 500              # the last card of a 1st-place finish

const FIELD_MULT := {1: 1.0, 2: 1.5, 3: 2.0}      # by number of bots
const DIFFICULTY_MULT := {"easy": 0.6, "normal": 1.0, "hard": 1.25}


## Performance points used to RANK the players who got out: everything except the place-based
## base and the field/difficulty multiplier, so it is the same yardstick for every player.
## `stats` = {draws, chains, finish_rank, penalty_chains, first_out}.
static func ranking_points(stats: Dictionary) -> int:
	var r := compute(0, 0, 0, "normal", int(stats["draws"]), stats["chains"], str(stats["finish_rank"]), stats["penalty_chains"], bool(stats["first_out"]), true, true)
	return int(r["raw_bonus"])


## Running points shown during the game. Combos and passed-on penalties count as they happen; the
## finishing bonuses (clean / few draws, going out on a penalty card, first out) only once the player
## is really out, so the number never promises something that can still be lost.
static func live_points(stats: Dictionary) -> int:
	var out := str(stats["finish_rank"]) != ""
	var r := compute(0, 0, 0, "normal", int(stats["draws"]), stats["chains"], str(stats["finish_rank"]), stats["penalty_chains"], bool(stats["first_out"]), out, true)
	return int(r["raw_bonus"])


## Returns {total, mult, clean, raw_bonus, lines: [[label, points], ...]}. `draws` = voluntary bank draws.
## `finished` = the player got out (an empty hand); the one left holding cards has lost outright
## and earns no finishing bonuses. `first_out` = went out before everybody else.
static func compute(place: int, players: int, bots: int, difficulty: String, draws: int, chains: Array = [], finish_rank: String = "", penalty_chains: Array = [], first_out: bool = false, finished: bool = true, rank_only: bool = false) -> Dictionary:
	var lines: Array = []
	var base := 0
	if not rank_only:
		base = int(round(float(WIN_POINTS) * float(players - place) / float(players - 1)))
		if place == 1:
			base = WIN_POINTS
		lines.append(["Finished %s of %d" % [_ordinal(place), players], base])
	var clean := draws == 0 and finished
	var bonus := 0
	if clean:
		bonus = CLEAN_BONUS
		lines.append(["CLEAN FINISH - never drew from the bank", CLEAN_BONUS])
	elif finished:
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
	# Penalty chains you fed that ended on someone else.
	for pc in penalty_chains:
		var pts: int = PASS_ON_PER_CARD * int(pc["cards"]) + PASS_ON_PER_PILE_CARD * int(pc["pile"])
		bonus += pts
		lines.append(["Passed on a penalty (%d card%s, %d drawn)" % [int(pc["cards"]), "" if int(pc["cards"]) == 1 else "s", int(pc["pile"])], pts])
	# Finishing card: a penalty card (7 = +2, Joker = +4) as your last card, and the winning card.
	if finish_rank != "":
		var pen := Rules.penalty_of(finish_rank)
		if pen > 0:
			var pp: int = PENALTY_FINISH_PER_CARD * pen
			bonus += pp
			lines.append(["Went out on a penalty card (+%d draw)" % pen, pp])
		if first_out:
			bonus += WINNING_CARD
			lines.append(["First out", WINNING_CARD])
	var mult: float = float(FIELD_MULT.get(bots, 1.0)) * float(DIFFICULTY_MULT.get(difficulty, 1.0))
	var total := int(round(float(base + bonus) * mult))
	return {"total": total, "mult": mult, "clean": clean, "raw_bonus": bonus, "lines": lines}


static func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n
