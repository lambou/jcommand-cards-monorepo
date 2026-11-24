extends RefCounted
## The quick-reaction set: ten emoji stickers sent during a game, plus the rules bots use to
## react. Only the `id` ever travels over the network (online play will relay `{type, from, id}`),
## so everything else here is local presentation data.
##
## Bot reactions use their own RandomNumberGenerator, never the game's, so the deterministic
## game flow (seeded deals, bot decisions) is not affected by whether anyone reacts.

const LIST := [
	{"id": "gg", "name": "Good game", "caption": "GG!", "sound": "react_cheer"},
	{"id": "laugh", "name": "Haha", "caption": "", "sound": "react_laugh"},
	{"id": "wow", "name": "Wow", "caption": "", "sound": "react_wow"},
	{"id": "clap", "name": "Well played", "caption": "", "sound": "react_cheer"},
	{"id": "cool", "name": "Cool", "caption": "", "sound": "react_pop"},
	{"id": "think", "name": "Hmm", "caption": "HMM...", "sound": "react_think"},
	{"id": "oops", "name": "Oops", "caption": "OOPS!", "sound": "react_oops"},
	{"id": "sad", "name": "Ouch", "caption": "", "sound": "react_sad"},
	{"id": "angry", "name": "Grr", "caption": "", "sound": "react_angry"},
	{"id": "hurry", "name": "Hurry up", "caption": "HURRY UP!", "sound": "react_hurry"},
]

const COOLDOWN := 1.6 # seconds before the same sender may react again
const SEAT_SHOW := 1.7 # seconds a sticker stays on screen

## What each bot leans towards: id -> {reaction id: weight}. Rex is cocky, Luna friendly, Zed dry.
const TASTE := {
	"bot1": {"laugh": 3.0, "cool": 3.0, "angry": 2.0, "hurry": 2.0, "gg": 1.0, "wow": 1.0},
	"bot2": {"gg": 3.0, "clap": 3.0, "wow": 2.0, "oops": 2.0, "sad": 2.0, "laugh": 1.0},
	"bot3": {"think": 3.0, "cool": 2.0, "wow": 2.0, "sad": 2.0, "angry": 1.0, "oops": 1.0},
}

## Per situation: the reactions that make sense (bots take the ones they like most) and the
## chance that a bot actually speaks up. Kept below 1 so the table is lively, not noisy.
const SITUATIONS := {
	"took_penalty": {"pool": ["sad", "angry", "oops"], "chance": 0.55},
	"human_penalty": {"pool": ["laugh", "oops", "sad", "wow"], "chance": 0.4},
	"hit_by_attack": {"pool": ["angry", "wow", "sad"], "chance": 0.5},
	"big_play": {"pool": ["cool", "laugh", "wow"], "chance": 0.45},
	"saw_check": {"pool": ["wow", "think"], "chance": 0.4},
	"went_out": {"pool": ["cool", "gg", "clap"], "chance": 0.7},
	"human_out": {"pool": ["clap", "gg", "wow"], "chance": 0.6},
	"slow_human": {"pool": ["hurry"], "chance": 1.0},
}

## When you send one of these, a bot may answer with one of the listed replies.
const REPLIES := {
	"gg": ["gg", "clap"],
	"clap": ["cool", "gg"],
	"laugh": ["laugh", "oops"],
	"angry": ["oops", "wow", "laugh"],
	"sad": ["oops", "think"],
	"hurry": ["oops", "think"],
	"cool": ["wow", "laugh"],
	"wow": ["cool"],
	"oops": ["laugh", "gg"],
	"think": ["think"],
}


static func ids() -> Array:
	var out: Array = []
	for r in LIST:
		out.append(r["id"])
	return out


static func is_valid(id: String) -> bool:
	for r in LIST:
		if r["id"] == id:
			return true
	return false


static func info(id: String) -> Dictionary:
	for r in LIST:
		if r["id"] == id:
			return r
	return {}


## A bot's reaction for a situation, or "" when it keeps quiet. `rng` is the reaction RNG.
static func bot_pick(situation: String, bot_id: String, rng: RandomNumberGenerator) -> String:
	var s: Dictionary = SITUATIONS.get(situation, {})
	if s.is_empty() or rng.randf() > float(s["chance"]):
		return ""
	var taste: Dictionary = TASTE.get(bot_id, {})
	var pool: Array = s["pool"]
	var total := 0.0
	for id in pool:
		total += float(taste.get(id, 0.6))
	var roll := rng.randf() * total
	for id in pool:
		roll -= float(taste.get(id, 0.6))
		if roll <= 0.0:
			return id
	return pool[pool.size() - 1]


## A bot's answer to a reaction the human just sent, or "".
static func bot_reply(to_id: String, rng: RandomNumberGenerator, chance: float = 0.4) -> String:
	var options: Array = REPLIES.get(to_id, [])
	if options.is_empty() or rng.randf() > chance:
		return ""
	return options[rng.randi() % options.size()]
