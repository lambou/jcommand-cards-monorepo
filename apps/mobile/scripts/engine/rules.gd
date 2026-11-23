extends RefCounted
## Loads the shared declarative rules (data/rules.json is a synced copy of
## packages/rules-spec/rules.json; the conformance runner verifies they match).

const RULES_PATH := "res://data/rules.json"

static var _spec: Dictionary = {}


static func spec() -> Dictionary:
	if _spec.is_empty():
		var f := FileAccess.open(RULES_PATH, FileAccess.READ)
		assert(f != null, "cannot open " + RULES_PATH)
		_spec = JSON.parse_string(f.get_as_text())
	return _spec


static func rule_of(rank: String) -> Dictionary:
	var ranks: Dictionary = spec()["ranks"]
	var r: Dictionary = (ranks["default"] as Dictionary).duplicate()
	if ranks.has(rank):
		r.merge(ranks[rank], true)
	return r


static func penalty_of(rank: String) -> int:
	return int(rule_of(rank).get("penalty", 0))
