extends RefCounted
## Game recorder: an append-only JSONL log of one game, saved in user://games/<game_id>.jsonl.
## Because the engine is deterministic, the header (seed, players, difficulty, settings) plus the
## ordered actions are enough to replay the game or to resume it where it stopped.
##
## One JSON object per line, told apart by "kind":
##   "h" header   {version, game_id, started_at, seed, difficulty, player_ids, names, settings, rules_hash, bot_version}
##   "a" action   {i, t, action, rng}   t = ms since the game started, rng = bot RNG state AFTER the action (a string:
##                                      it is 64-bit and JSON numbers are doubles)
##   "r" reaction {t, from, id}         cosmetic only, never fed to the engine
##   "f" footer   {status, placing, points, is_draw, actions}   present only once the game is over
## A game without a footer is in progress and can be resumed. A half-written last line (crash) is dropped on load.

const VERSION := 1
const MAX_FINISHED := 20

## Debug runs (selftest, screenshots, tests) turn recording off so they never touch the player's games.
static var enabled := true
static var dir := "user://games"

var path := ""
var game_id := ""
var _file: FileAccess
var _t0 := 0
var _seq := 0


# ---------------------------------------------------------------- writing

## Starts a new record; `header` gets "kind", "version" and "game_id" filled in.
func begin(header: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	game_id = "%d_%d" % [int(Time.get_unix_time_from_system()), int(header.get("seed", 0))]
	path = "%s/%s.jsonl" % [dir, game_id]
	header["kind"] = "h"
	header["version"] = VERSION
	header["game_id"] = game_id
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		return false
	_t0 = Time.get_ticks_msec()
	_seq = 0
	_line(header)
	return true


## Continues an unfinished record. The file is rewritten from what parsed cleanly first, so a torn
## last line can never glue itself to the next append.
func reopen(rec: Dictionary) -> bool:
	path = str(rec["path"])
	game_id = str(rec["header"]["game_id"])
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_line(JSON.stringify(rec["header"]))
	var last_t := 0
	for a in rec["actions"]:
		f.store_line(JSON.stringify(a))
		last_t = int(a.get("t", 0))
	for r in rec["reactions"]:
		f.store_line(JSON.stringify(r))
	f.close()
	DirAccess.rename_absolute(tmp, path)
	_file = FileAccess.open(path, FileAccess.READ_WRITE)
	if _file == null:
		return false
	_file.seek_end()
	_seq = (rec["actions"] as Array).size()
	_t0 = Time.get_ticks_msec() - last_t
	return true


func add_action(action: Dictionary, rng_state: int) -> void:
	_line({"kind": "a", "i": _seq, "t": Time.get_ticks_msec() - _t0, "action": action, "rng": str(rng_state)})
	_seq += 1


func add_reaction(from: String, id: String) -> void:
	_line({"kind": "r", "t": Time.get_ticks_msec() - _t0, "from": from, "id": id})


func finish(footer: Dictionary) -> void:
	footer["kind"] = "f"
	footer["status"] = "finished"
	footer["actions"] = _seq
	_line(footer)
	close()


func close() -> void:
	if _file != null:
		_file.close()
		_file = null


func _line(d: Dictionary) -> void:
	if _file == null:
		return
	_file.store_line(JSON.stringify(d))
	_file.flush() # a crash loses at most the line being written


# ---------------------------------------------------------------- reading

## Parses a record. {ok:true, path, header, actions:[{i,t,action,rng}], reactions:[], footer:{}|empty, finished}
## or {ok:false, error}. Action ids are turned back into ints.
static func load_record(p: String) -> Dictionary:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "cannot open record"}
	var header := {}
	var actions: Array = []
	var reactions: Array = []
	var footer := {}
	while not f.eof_reached():
		var txt := f.get_line().strip_edges()
		if txt == "":
			continue
		var parser := JSON.new()
		if parser.parse(txt) != OK: # no error spam for a torn line
			break
		var d = parser.data
		if typeof(d) != TYPE_DICTIONARY:
			break # torn last line: keep what we have
		match d.get("kind", ""):
			"h":
				header = d
			"a":
				var act: Dictionary = d["action"]
				if act.has("cardId"):
					act["cardId"] = int(act["cardId"])
				actions.append(d)
			"r":
				reactions.append(d)
			"f":
				footer = d
	if header.is_empty():
		return {"ok": false, "error": "record has no header"}
	if int(header.get("version", 0)) > VERSION:
		return {"ok": false, "error": "record was made by a newer version"}
	return {"ok": true, "path": p, "header": header, "actions": actions, "reactions": reactions,
		"footer": footer, "finished": not footer.is_empty()}


## Fingerprint of the rules a game was played under; a resume is refused if it changed.
static func rules_hash(spec: Dictionary) -> String:
	return JSON.stringify(spec, "", true).sha256_text().substr(0, 16)


## All readable records, newest first.
static func list() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for name in DirAccess.get_files_at(dir):
		if not name.ends_with(".jsonl"):
			continue
		var rec := load_record(dir + "/" + name)
		if rec["ok"]:
			out.append(rec)
	out.sort_custom(func(a, b): return int(a["header"]["started_at"]) > int(b["header"]["started_at"]))
	return out


## The unfinished game that can be resumed, or {}.
static func in_progress() -> Dictionary:
	for rec in list():
		if not rec["finished"]:
			return rec
	return {}


## Deletes unfinished records (only one game is kept resumable) and the oldest finished ones.
static func prune() -> void:
	var finished := 0
	for rec in list():
		if not rec["finished"]:
			DirAccess.remove_absolute(rec["path"])
		else:
			finished += 1
			if finished > MAX_FINISHED:
				DirAccess.remove_absolute(rec["path"])


static func delete(p: String) -> void:
	DirAccess.remove_absolute(p)
