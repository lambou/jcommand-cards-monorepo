extends RefCounted
## Bot players. Pure functions over an engine state; deterministic given the rng.
## Difficulties: "easy" (mostly random), "normal" (heuristic) and "hard" (counts unseen cards, remembers
## suits players could not match, models the next player, plans its last cards). Hard scores each play
## as a weighted sum of features; the weights in data/hard_knowledge.json were learned by self-play
## (tests/sim_learn.gd): ~55% in 1v1 against "normal" (chance 50%), ~37% with 3 players (33%), ~27% with 4
## (25%). The edge is small because only ~1/3 of turns offer a real choice
## (tests/sim_choices.gd), and even seeing the opponent's real hand (Bot.oracle) only reaches ~62%.

const Cards := preload("res://scripts/engine/cards.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")
const Rules := preload("res://scripts/engine/rules.gd")


## `memory` is the table-wide notebook kept by the caller (see update_memory); only "hard" reads it.
static func choose_action(state: Dictionary, player_id: String, difficulty: String, rng: RandomNumberGenerator, memory: Dictionary = {}) -> Dictionary:
	var acts := CardEngine.legal_actions(state, player_id)
	assert(not acts.is_empty(), "bot has no legal action")
	var fallback: Dictionary = acts[acts.size() - 1] # draw / takePenalty is always last
	var plays: Array = []
	for a in acts:
		if a["type"] == "play":
			plays.append(a)
	if plays.is_empty():
		return fallback
	if difficulty == "easy":
		return _easy(state, plays, fallback, rng)
	if difficulty == "hard":
		return _hard(state, player_id, plays, rng, memory)
	return _normal(state, player_id, plays, fallback, rng)


static func _easy(state: Dictionary, plays: Array, fallback: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if int(state["pending"]) > 0:
		# Often forgets it can pass the penalty on.
		if rng.randf() < 0.7:
			return plays[rng.randi() % plays.size()]
		return fallback
	if rng.randf() < 0.12:
		return fallback # random voluntary draw
	return plays[rng.randi() % plays.size()]


static func _normal(state: Dictionary, player_id: String, plays: Array, fallback: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var me := _player(state, player_id)
	var hand: Array = me["hand"]
	var next_hand := _next_hand_size(state)
	var active := _active_count(state)
	var pending := int(state["pending"]) > 0

	if pending:
		# Pass it on. Against a nearly-empty opponent hit hard, otherwise use the weaker card.
		var best: Dictionary = plays[0]
		var best_pen := 999
		var hit_hard := next_hand <= 3
		if hit_hard:
			best_pen = -1
		for a in plays:
			var pen := Rules.penalty_of(_card_in(hand, a["cardId"])["rank"])
			if (hit_hard and pen > best_pen) or (not hit_hard and pen < best_pen):
				best = a
				best_pen = pen
		return best

	var best_play: Dictionary = plays[0]
	var best_score := -INF
	for a in plays:
		var card := _card_in(hand, a["cardId"])
		var sc := _score(hand, card, str(a.get("chosenSuit", "")), next_hand, active, rng)
		if sc > best_score:
			best_score = sc
			best_play = a
	return best_play


static func _score(hand: Array, card: Dictionary, chosen: String, next_hand: int, active: int, rng: RandomNumberGenerator) -> float:
	var rest: Array = hand.filter(func(c): return c["id"] != card["id"])
	if rest.is_empty():
		return 1000.0
	var suits := _suit_counts(rest)
	var s := 0.0
	match card["rank"]:
		"2":
			# Escape card: keep it unless the hand is nearly gone.
			s = 2.0 + (8.0 if rest.size() <= 2 else 0.0)
		"J":
			s = 6.0 + 3.0 * float(suits.get(chosen, 0))
		"7", "JOKER":
			var blockers := 0
			for c in rest:
				if Rules.penalty_of(c["rank"]) > 0:
					blockers += 1
			s = 5.0
			if next_hand <= 3:
				s += 8.0
			if blockers == 0:
				s -= 3.0 # last defence against incoming penalties
			if card["rank"] == "JOKER":
				var col := 0
				for c in rest:
					if c["color"] == card["color"]:
						col += 1
				s += 1.5 * float(col)
			else:
				s += 2.0 * float(suits.get(card["suit"], 0))
		"A":
			s = 6.0
			if next_hand <= 3:
				s += 7.0
			if active == 2:
				s += 5.0 # in 1v1 a Stop means we play again
			s += 1.0 * float(suits.get(card["suit"], 0))
		_:
			s = 10.0 + 2.0 * float(suits.get(card["suit"], 0))
	return s + rng.randf() # tie-break noise


# ---------------------------------------------------------------- helpers

static func _suit_counts(cards: Array) -> Dictionary:
	var d := {}
	for c in cards:
		if c["suit"] != "":
			d[c["suit"]] = int(d.get(c["suit"], 0)) + 1
	return d


static func _card_in(hand: Array, id: int) -> Dictionary:
	for c in hand:
		if c["id"] == id:
			return c
	return {}


static func _player(state: Dictionary, id: String) -> Dictionary:
	for p in state["players"]:
		if p["id"] == id:
			return p
	return {}


static func _active_count(state: Dictionary) -> int:
	var n := 0
	for p in state["players"]:
		if p["status"] != "finished":
			n += 1
	return n


static func _next_hand_size(state: Dictionary) -> int:
	var n: int = state["players"].size()
	for i in range(1, n + 1):
		var p: Dictionary = state["players"][(int(state["current"]) + i) % n]
		if p["status"] != "finished":
			return p["hand"].size()
	return 99


# ================================================================ hard

## Call BEFORE applying `action` to `state`. Keeps a notebook of who (probably) holds no cards of a
## suit: a player who drew voluntarily although they had no legal play lacked the required suit.
## Playing a suit, or taking a penalty (new cards), clears that note.
static func update_memory(memory: Dictionary, state: Dictionary, action: Dictionary) -> void:
	if not memory.has("void"):
		memory["void"] = {}
	var voids: Dictionary = memory["void"]
	var pid: String = action["playerId"]
	var pv: Dictionary = voids.get(pid, {})
	match action["type"]:
		"draw":
			var had_play := false
			for a in CardEngine.legal_actions(state, pid):
				if a["type"] == "play":
					had_play = true
					break
			if not had_play:
				var req: Dictionary = state["required"]
				if req["kind"] == "suit":
					pv[req["suit"]] = true
				elif req["kind"] == "color":
					for suit in Cards.SUITS:
						if Cards.suit_color(suit) == req["color"]:
							pv[suit] = true
		"takePenalty":
			pv = {}
		"play":
			var card := _card_in(_player(state, pid)["hand"], action["cardId"])
			if not card.is_empty() and card["suit"] != "":
				pv.erase(card["suit"])
	voids[pid] = pv


## EXPERIMENT ONLY: when true, "hard" is given the next player's real hand instead of estimating it
## (an upper bound for what perfect card memory could ever be worth). Never set in the game.
static var oracle := false

## Where the learned weights live (written by tests/sim_learn.gd, loaded lazily).
const KNOWLEDGE_PATH := "res://data/hard_knowledge.json"

## Feature names in the order _features() returns them. W maps name -> weight; a missing name is 0.
const FEATURES := [
	"stuck", "pen", "ace", "ace1v1", "keep2", "keepJ", "blocker", "follow", "fin1", "fin2", "cover",
	"samesuit", "jsuit", "blockers_left", "two_pending", "sj_urgent", "pen_raw",
	"r2", "rJ", "r7", "rJOKER", "rA", "ace_late", "dump_big",
]

## Hand-tuned starting point (what the experiments in sim_tune.gd settled on); training starts here.
const DEFAULT_W := {
	"stuck": 12.0, "pen": 2.2, "ace": 7.0, "ace1v1": 6.0, "keep2": -7.0, "keepJ": -3.0,
	"blocker": -3.0, "follow": 1.8, "fin1": 38.0, "fin2": 9.0, "cover": 0.0,
}

## Active weights. sim_learn.gd overrides this while training.
static var W: Dictionary = {}
static var _loaded := false


static func load_knowledge() -> void:
	_loaded = true
	W = DEFAULT_W.duplicate()
	if FileAccess.file_exists(KNOWLEDGE_PATH):
		var f := FileAccess.open(KNOWLEDGE_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary and d.has("weights"):
			W = {}
			for k in d["weights"]:
				W[k] = float(d["weights"][k])


static func _hard(state: Dictionary, player_id: String, plays: Array, rng: RandomNumberGenerator, memory: Dictionary) -> Dictionary:
	if not _loaded:
		load_knowledge()
	var me := _player(state, player_id)
	var hand: Array = me["hand"]
	var nx := _next_player(state)
	var pool := _unseen_for(state, hand, nx, memory)
	var active := _active_count(state)
	var best: Dictionary = plays[0]
	var best_score := -INF
	for a in plays:
		var card := _card_in(hand, a["cardId"])
		var sc := _hard_score(state, hand, card, str(a.get("chosenSuit", "")), active, nx, pool, rng)
		if sc > best_score:
			best_score = sc
			best = a
	return best


static func _hard_score(state: Dictionary, hand: Array, card: Dictionary, chosen: String, active: int,
		nx: Dictionary, pool: Array, rng: RandomNumberGenerator) -> float:
	var rest: Array = hand.filter(func(c): return c["id"] != card["id"])
	var total_pen := int(state["pending"]) + Rules.penalty_of(card["rank"])
	if rest.is_empty():
		# Out of cards. A penalty card only wins if the next player cannot answer it.
		if total_pen == 0:
			return 1000.0
		return 300.0 + 700.0 * (1.0 - _p_block(pool, nx["hand"].size()))
	var f := _features(state, hand, rest, card, chosen, active, nx, pool)
	var s := 10.0
	for k in f:
		s += float(W.get(k, 0.0)) * float(f[k])
	return s + rng.randf() * 0.4


static func _p_block(pool: Array, n_opp: int) -> float:
	var pen_cards := 0
	for c in pool:
		if Rules.penalty_of(c["rank"]) > 0:
			pen_cards += 1
	var share := float(pen_cards) / maxf(float(pool.size()), 1.0)
	return 1.0 - pow(1.0 - share, float(maxi(n_opp, 0)))


## Describes playing `card` (leaving `rest` in hand) as name -> value. All the "knowledge" is in how
## the weights W combine these.
static func _features(state: Dictionary, hand: Array, rest: Array, card: Dictionary, chosen: String,
		active: int, nx: Dictionary, pool: Array) -> Dictionary:
	var rule := Rules.rule_of(card["rank"])
	var pen := int(rule.get("penalty", 0))
	var total_pen := int(state["pending"]) + pen
	var n_opp: int = nx["hand"].size()
	var rank: String = card["rank"]

	# What the table will require after this play.
	var req_suit := ""
	var req_color := ""
	var floor_rank: String = rank
	match rule.get("sets", "suit"):
		"suit":
			req_suit = card["suit"]
		"color":
			req_color = card["color"]
		"chosen":
			req_suit = chosen
		"none":
			var cur: Dictionary = state["required"]
			req_suit = str(cur.get("suit", ""))
			req_color = str(cur.get("color", ""))
			var stack: Array = state["stack"]
			floor_rank = stack[stack.size() - 1]["rank"]

	var urgency := 1.0 if n_opp <= 2 else (0.7 if n_opp <= 4 else 0.45)
	var f := {}
	var big := rest.size() > 2

	# Pressure on the next player.
	if total_pen > 0:
		f["pen"] = urgency * float(total_pen) * (1.0 - _p_block(pool, n_opp))
		f["pen_raw"] = float(total_pen)
	elif rank == "A":
		f["ace"] = urgency
		f["ace1v1"] = 1.0 if active == 2 else 0.0
	else:
		f["stuck"] = urgency * (1.0 - _p_can_play(pool, req_suit, req_color, floor_rank, n_opp))

	# Which card it is (flexible cards are worth keeping while the hand is big).
	match rank:
		"2":
			f["r2"] = 1.0
			f["keep2"] = 1.0 if big else 0.0
			if int(state["pending"]) > 0:
				f["two_pending"] = 1.0
		"J":
			f["rJ"] = 1.0
			f["keepJ"] = 1.0 if big else 0.0
			f["jsuit"] = float(_suit_counts(rest).get(chosen, 0))
		"7", "JOKER":
			f["r7" if rank == "7" else "rJOKER"] = 1.0
			f["sj_urgent"] = urgency
		"A":
			f["rA"] = 1.0
			if rest.size() <= 3:
				f["ace_late"] = 1.0
	var blockers := 0
	for c in rest:
		if Rules.penalty_of(c["rank"]) > 0:
			blockers += 1
	if (rank == "7" or rank == "JOKER") and blockers == 0:
		f["blocker"] = 1.0
	f["blockers_left"] = float(blockers)
	if rank != "2" and rank != "J" and pen == 0 and rank != "A":
		f["dump_big"] = float(rest.size())

	# Cards in hand that can follow this play (same suit/colour, or the same rank to switch).
	var follow := 0
	var samesuit := 0
	var seen := {}
	var twos := 0
	for c in rest:
		if _playable_on(c, req_suit, req_color, floor_rank, true):
			follow += 1
		if req_suit != "" and c["suit"] == req_suit:
			samesuit += 1
		if c["rank"] == "2":
			twos += 1
		elif c["suit"] != "":
			seen[c["suit"]] = true
	f["follow"] = float(follow)
	f["samesuit"] = float(samesuit)
	f["cover"] = float(seen.size() + (1 if twos > 0 else 0))

	# Endgame: what is left must be able to finish.
	if rest.size() == 1:
		f["fin1"] = _finish_quality(rest[0], active)
	elif rest.size() == 2:
		f["fin2"] = _finish_quality(rest[0], active) + _finish_quality(rest[1], active)
	return f



## How reliably a last card can be played out (2 always; an Ace can never finish a 1v1).
static func _finish_quality(c: Dictionary, active: int) -> float:
	match c["rank"]:
		"2":
			return 1.0
		"J":
			return 0.75
		"A":
			return -0.6 if active == 2 else 0.7
		"7":
			return 0.5
		"JOKER":
			return 0.45
	return 0.5


## Could card `c` be played on a pile that requires req_suit / req_color with top rank floor_rank?
static func _playable_on(c: Dictionary, req_suit: String, req_color: String, floor_rank: String, ignore_two: bool = false) -> bool:
	if c["rank"] == "2":
		return not ignore_two
	if req_suit != "":
		if c["suit"] == req_suit:
			return true
		if c["suit"] == "" and Cards.suit_color(req_suit) == c["color"]:
			return true
	elif req_color != "":
		if c["color"] == req_color:
			return true
	return c["rank"] == floor_rank


## Chance that a player holding n unseen-pool cards has at least one playable card.
static func _p_can_play(pool: Array, req_suit: String, req_color: String, floor_rank: String, n: int) -> float:
	if pool.is_empty() or n <= 0:
		return 0.0
	var ok := 0
	for c in pool:
		if _playable_on(c, req_suit, req_color, floor_rank):
			ok += 1
	if oracle:
		return 1.0 if ok > 0 else 0.0
	var p := float(ok) / float(pool.size())
	return 1.0 - pow(1.0 - p, float(n))


## Every card the bot has not seen: opponents' hands + the bank (minus suits the next player is
## known to lack).
static func _unseen_for(state: Dictionary, hand: Array, nx: Dictionary, memory: Dictionary) -> Array:
	if oracle:
		return (nx["hand"] as Array).duplicate()
	var known := {}
	for c in hand:
		known[c["id"]] = true
	for c in state["stack"]:
		known[c["id"]] = true
	var voids: Dictionary = (memory.get("void", {}) as Dictionary).get(nx["id"], {})
	var pool: Array = []
	for c in Cards.create_deck():
		if known.has(c["id"]):
			continue
		if c["suit"] != "" and voids.has(c["suit"]):
			continue
		if c["suit"] == "":
			var all_void := true
			for suit in Cards.SUITS:
				if Cards.suit_color(suit) == c["color"] and not voids.has(suit):
					all_void = false
			if all_void:
				continue
		pool.append(c)
	return pool


static func _next_player(state: Dictionary) -> Dictionary:
	var n: int = state["players"].size()
	for i in range(1, n + 1):
		var p: Dictionary = state["players"][(int(state["current"]) + i) % n]
		if p["status"] != "finished":
			return p
	return state["players"][state["current"]]
