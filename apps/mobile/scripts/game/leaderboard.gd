extends RefCounted
## Local leaderboard (top scores on this device), saved in user://leaderboard.cfg.

const PATH := "user://leaderboard.cfg"
const MAX_ENTRIES := 20

static var _entries: Array = []
static var _loaded := false


static func entries() -> Array:
	_load()
	return _entries


## Records a finished game. Returns the 1-based rank of the new entry, or 0 if it missed the board.
static func add(score: int, place: int, players: int, difficulty: String, clean: bool) -> int:
	_load()
	var e := {"score": score, "place": place, "players": players, "difficulty": difficulty,
		"clean": clean, "date": Time.get_date_string_from_system()}
	# Newer entries rank below older ones with the same score.
	var idx := _entries.size()
	for i in _entries.size():
		if score > int(_entries[i]["score"]):
			idx = i
			break
	_games += 1
	if place == 1:
		_wins += 1
	if clean:
		_cleans += 1
	if score <= 0 or idx >= MAX_ENTRIES: # last place (0 pts) never makes the board
		_save()
		return 0
	_entries.insert(idx, e)
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	_save()
	return idx + 1


static var _games := 0
static var _wins := 0
static var _cleans := 0


## {games, wins, cleans, best}
static func stats() -> Dictionary:
	_load()
	return {"games": _games, "wins": _wins, "cleans": _cleans,
		"best": int(_entries[0]["score"]) if not _entries.is_empty() else 0}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	_entries = cfg.get_value("board", "entries", [])
	_games = int(cfg.get_value("stats", "games", 0))
	_wins = int(cfg.get_value("stats", "wins", 0))
	_cleans = int(cfg.get_value("stats", "cleans", 0))


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("board", "entries", _entries)
	cfg.set_value("stats", "games", _games)
	cfg.set_value("stats", "wins", _wins)
	cfg.set_value("stats", "cleans", _cleans)
	cfg.save(PATH)
