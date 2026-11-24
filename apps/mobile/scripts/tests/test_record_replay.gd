extends SceneTree
## Recording, resume and replay: a recorded game must rebuild exactly, and a resumed game must finish
## exactly like the original. Run: godot --headless --path apps/mobile -s res://scripts/tests/test_record_replay.gd

const OfflineGame := preload("res://scripts/game/offline_game.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")
const Recorder := preload("res://scripts/game/recorder.gd")

var _fails := 0
var _snaps: Array = [] # fingerprint after N actions, N = index


func _check(label: String, cond: bool) -> void:
	print(("ok   " if cond else "FAIL ") + label)
	if not cond:
		_fails += 1


func _init() -> void:
	await process_frame # the tree must be running before nodes are added
	await _run()
	quit(1 if _fails > 0 else 0)


func _print(g: OfflineGame) -> String:
	return JSON.stringify([g.state, g.stats, g.memory, g.points, g.is_draw, str(g.rng.state)], "", true).sha256_text()


## Deterministic human: depends on the state only (first play, else the first legal action).
func _human_act(g: OfflineGame) -> void:
	var acts := CardEngine.legal_actions(g.state, OfflineGame.HUMAN_ID)
	var pick: Dictionary = acts[0]
	for a in acts:
		if a["type"] == "play":
			pick = a
			break
	match pick["type"]:
		"play": g.human_play(int(pick["cardId"]), str(pick.get("chosenSuit", "")))
		"draw": g.human_draw()
		_: g.human_take_penalty()


func _drive(g: OfflineGame) -> void:
	var guard := 0
	while not g.state["over"] and guard < 6000:
		guard += 1
		if g.is_human_turn():
			_human_act(g)
		else:
			await process_frame


func _new_game() -> OfflineGame:
	var g := OfflineGame.new()
	g.bot_delay = 0.0
	root.add_child(g)
	return g


func _run() -> void:
	Recorder.dir = "user://games_test"
	if DirAccess.dir_exists_absolute(Recorder.dir):
		for f in DirAccess.get_files_at(Recorder.dir):
			DirAccess.remove_absolute(Recorder.dir + "/" + f)

	# 1. Play a full game while fingerprinting the state after every action.
	var a := _new_game()
	a.updated.connect(func(_e): _snaps.append(_print(a)))
	a.start(2, "normal", 4242)
	await _drive(a)
	var final_print := _print(a)
	_check("1: game finished", a.state["over"])
	var recs := Recorder.list()
	_check("1: one finished record on disk", recs.size() == 1 and recs[0]["finished"])
	var rec: Dictionary = recs[0]
	var n: int = rec["actions"].size()
	_check("1: one fingerprint per action (+ the deal)", _snaps.size() == n + 1)
	_check("1: footer matches the result", rec["footer"]["placing"] == a.state["finishedOrder"])

	# 2. Restoring at any cut point gives exactly the state the original had there.
	var b := _new_game()
	var ok := true
	for k in [0, 1, n / 3, n / 2, n - 1, n]:
		var res := b.restore(rec, k)
		ok = ok and res["ok"] and _print(b) == _snaps[k]
	_check("2: restore(k) == original after k actions", ok)

	# 3. Resume from the middle: the rest of the game plays out identically (bot RNG included).
	var cut := n / 2
	var partial := rec.duplicate()
	partial["actions"] = (rec["actions"] as Array).slice(0, cut)
	partial["footer"] = {}
	partial["finished"] = false
	# Work on a copy of the file so the original stays intact for the replay test.
	partial["path"] = Recorder.dir + "/partial.jsonl"
	var pf := FileAccess.open(partial["path"], FileAccess.WRITE)
	pf.store_line(JSON.stringify(rec["header"]))
	for x in partial["actions"]:
		pf.store_line(JSON.stringify(x))
	pf.store_string("{\"kind\":\"a\",\"i\":99,\"t") # torn last line, as after a crash
	pf.close()
	var loaded := Recorder.load_record(partial["path"])
	_check("3: torn last line is dropped", loaded["ok"] and loaded["actions"].size() == cut and not loaded["finished"])
	var c := _new_game()
	var res := c.resume(loaded)
	_check("3: resume accepted", res["ok"])
	await _drive(c)
	_check("3: resumed game ends exactly like the original", _print(c) == final_print)
	var after := Recorder.load_record(partial["path"])
	_check("3: resumed record is complete and consistent", after["finished"] and after["actions"].size() == n)

	# 4. A changed ruleset refuses to resume.
	var stale := loaded.duplicate(true)
	stale["header"]["rules_hash"] = "deadbeef"
	_check("4: rules mismatch refused", not _new_game().resume(stale)["ok"])

	# 5. Replay: stepping forward reaches the final state; seeking back and forth is exact.
	var r := _new_game()
	_check("5: replay starts at the deal", r.start_replay(rec)["ok"] and _print(r) == _snaps[0])
	_check("5: replay has no human turn", not r.is_human_turn())
	var stepped := 0
	while r.replay_next():
		stepped += 1
	_check("5: stepping through all actions", stepped == n and _print(r) == final_print)
	r.replay_seek(n / 4)
	_check("5: seek back", _print(r) == _snaps[n / 4] and r.replay_cursor == n / 4)
	r.replay_seek(n / 4 + 1)
	_check("5: step forward by seek", _print(r) == _snaps[n / 4 + 1])

	# 6. Pruning keeps a bounded history and only one unfinished game.
	for i in 25:
		var g := _new_game()
		g.start(1, "easy", 100 + i)
		await _drive(g)
		await process_frame
	var left := Recorder.list()
	_check("6: history capped at %d" % Recorder.MAX_FINISHED, left.size() <= Recorder.MAX_FINISHED + 1)

	print("FAILED: %d" % _fails if _fails > 0 else "ALL PASSED")
