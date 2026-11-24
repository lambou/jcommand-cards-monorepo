extends Control
## Root: switches between the menu and the table.
## Debug flags (after `--`):
##   --selftest              play full games through the real UI handlers; exit code 0 = pass
##   --shot=<file.png> [--bots=N]   save <file>_a/_b/_c.png: mid-deal, a card mid-flight, settled
##   --menushot=<file.png>   screenshot of the menu
##   --boardshot=<file.png>  leaderboard screen with sample scores (writes user://leaderboard.cfg)
##   --suitshot=<file.png>   the J suit picker (3D suits), then the PLAY pill spinning to a new suit
##   --drawshot=<file.png>   <file>_0.. of the 3D hand dealing a 4-card penalty
##   --modelview             free-turn inspector for all 3D models (drag to rotate; see ui/model_view.gd)
##   --modelviewshot=<file.png>   <file>_0/_90/_180/_270.png of the inspector at four turn angles

const Menu := preload("res://scripts/ui/menu.gd")
const Table := preload("res://scripts/ui/table.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const Settings := preload("res://scripts/game/settings.gd")

var _current: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.load_settings()
	add_child(Sfx.new())
	var shot := ""
	var podium_path := ""
	var bots := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
		elif a == "--reduce":
			Settings.reduce_motion = true # this run only; not saved
		elif a.begins_with("--settingsshot="):
			_show_menu()
			var panel := preload("res://scripts/ui/settings_panel.gd").new()
			_current.add_child(panel)
			await get_tree().create_timer(0.5).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(15))
			get_tree().quit()
			return
		elif a.begins_with("--exportsounds="):
			Sfx.instance.export_all(a.substr(15))
			get_tree().quit()
			return
		elif a.begins_with("--podiumshot="):
			podium_path = a.substr(13)
		elif a.begins_with("--checkshot="):
			_checkshot(a.substr(12))
			return
		elif a == "--modelview":
			_swap(preload("res://scripts/ui/model_view.gd").new())
			return
		elif a.begins_with("--modelviewshot="):
			_modelviewshot(a.substr(16))
			return
		elif a.begins_with("--suitshot="):
			_suitshot(a.substr(11))
			return
		elif a.begins_with("--reactshot="):
			_reactshot(a.substr(12))
			return
		elif a.begins_with("--slideshot="):
			_slideshot(a.substr(12))
			return
		elif a.begins_with("--drawshot="):
			_drawshot(a.substr(11))
			return
		elif a.begins_with("--boardshot="):
			var LB := preload("res://scripts/game/leaderboard.gd")
			LB.add(9000, 1, 3, "normal", true)
			LB.add(2000, 1, 4, "normal", false)
			LB.add(650, 2, 3, "easy", false)
			_show_menu()
			var lp := preload("res://scripts/ui/leaderboard_panel.gd").new()
			_current.add_child(lp)
			await get_tree().create_timer(0.5).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(12))
			get_tree().quit()
			return
		elif a.begins_with("--menushot="):
			_show_menu()
			await get_tree().create_timer(0.4).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(11))
			get_tree().quit()
			return
	if podium_path != "":
		_podiumshot(podium_path, bots)
		return
	if "--selftest" in OS.get_cmdline_user_args():
		_selftest()
	elif shot != "":
		_autoshot(shot, bots)
	else:
		_show_menu()


func _swap(node: Control) -> void:
	if _current != null:
		_current.queue_free()
	_current = node
	add_child(node)


func _show_menu() -> void:
	var m := Menu.new()
	m.start_requested.connect(_start_game)
	_swap(m)


func _start_game(bots: int, difficulty: String) -> Table:
	var t := Table.new()
	t.quit_to_menu.connect(_show_menu)
	_swap(t)
	t.start(bots, difficulty)
	return t


## Plays full games through the real UI handlers (card taps, bank taps, suit picker).
func _selftest() -> void:
	var ok := true
	for bots in [1, 2, 3]:
		var t := _start_game(bots, "normal")
		t.game.bot_delay = 0.0
		t.game.rng.seed = 100 + bots
		var steps := 0
		var jacks := 0
		while not t.game.state["over"] and steps < 4000:
			await get_tree().process_frame
			steps += 1
			if not t.game.is_human_turn():
				continue
			var st: Dictionary = t.game.state
			var acts := t.CardEngine.legal_actions(st, "you")
			var play_ids := []
			for a in acts:
				if a["type"] == "play" and not play_ids.has(a["cardId"]):
					play_ids.append(a["cardId"])
			if play_ids.is_empty():
				t._on_bank_pressed(-1)
			else:
				var id: int = play_ids[steps % play_ids.size()]
				t._on_card_pressed(id)
				if t.picker.visible:
					jacks += 1
					t._on_suit_chosen(["H", "D", "C", "S"][jacks % 4])
		await get_tree().create_timer(4.0).timeout # let every flight land and the results screen appear
		var over: bool = t.game.state["over"]
		print("selftest bots=%d over=%s steps=%d jack-picks=%d overlay=%s stray-flyers=%d" % [
			bots, over, steps, jacks, t.over_panel != null, t.fx.get_child_count()])
		if not over or t.over_panel == null or t.fx.get_child_count() != 0:
			ok = false
	print("SELFTEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _save(path: String, suffix: String) -> void:
	var p := path.get_basename() + suffix + ".png"
	get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)


func _modelviewshot(path: String) -> void:
	var v := preload("res://scripts/ui/model_view.gd").new()
	_swap(v)
	await get_tree().create_timer(0.5).timeout
	for a in [0, 90, 180, 270]:
		v.angle = float(a)
		await get_tree().create_timer(0.2).timeout
		_save(path, "_%d" % a)
	get_tree().quit()


## Opens the J suit picker, then picks a suit and captures the PLAY pill spinning in the new suit.
func _suitshot(path: String) -> void:
	var t := _start_game(2, "normal")
	t.game.bot_delay = 5.0
	t.game.rng.seed = 5
	await get_tree().create_timer(3.5).timeout   # let the deal finish
	t.picker.visible = true
	await get_tree().create_timer(0.4).timeout
	_save(path, "_picker")
	t.picker.visible = false
	t.game.state["required"] = {"kind": "suit", "suit": "S"}
	t.game.updated.emit([])
	for i in 4:
		await get_tree().create_timer(0.18).timeout
		_save(path, "_pill%d" % i)
	get_tree().quit()


## Forces a 4-card penalty on the human and captures the 3D hand dealing the cards in.
func _drawshot(path: String) -> void:
	var t := _start_game(2, "normal")
	t.game.bot_delay = 5.0 # keep the bots out of the way
	t.game.rng.seed = 5
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.0).timeout
	t.game.state["pending"] = 4
	t.game.updated.emit([])
	await get_tree().create_timer(0.3).timeout
	t.game.human_take_penalty()
	var i := 0
	for m in [0.25, 0.2, 0.2, 0.2, 0.3, 0.6]:
		await get_tree().create_timer(m).timeout
		_save(path, "_%d" % i)
		i += 1
	get_tree().quit()


## Gives the human a 2, plays it, and captures the slide-under animation frame by frame.
func _slideshot(path: String) -> void:
	var t := _start_game(2, "normal")
	t.game.bot_delay = 5.0 # keep the bots out of the way
	t.game.rng.seed = 5
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.0).timeout
	# --fxcard=2|7|LION|A|J picks which special card to inject and play (default 2).
	var which := "2"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fxcard="):
			which = a.substr(9)
	var cards := {
		"2": {"id": 999, "rank": "2", "suit": "S", "color": "black"},
		"7": {"id": 999, "rank": "7", "suit": "H", "color": "red"},
		"LION": {"id": 999, "rank": "LION", "suit": "", "color": "red"},
		"A": {"id": 999, "rank": "A", "suit": "S", "color": "black"},
		"J": {"id": 999, "rank": "J", "suit": "S", "color": "black"},
	}
	t.game.state["required"] = {"kind": "free"}
	t.game.state["players"][0]["hand"].append(cards[which])
	t.game.updated.emit([])
	await get_tree().create_timer(0.3).timeout
	t.game.human_play(999, "D" if which == "J" else "")
	var marks := [0.22, 0.2, 0.2, 0.2, 0.2, 0.5]
	var i := 0
	for m in marks:
		await get_tree().create_timer(m).timeout
		_save(path, "_%d" % i)
		i += 1
	get_tree().quit()


## Plays a whole game instantly (human picks the first legal play), then captures the podium rising.
func _podiumshot(path: String, bots: int) -> void:
	var t := _start_game(bots, "normal")
	t.game.bot_delay = 0.0
	t.game.rng.seed = 11
	var steps := 0
	while not t.game.state["over"] and steps < 6000:
		await get_tree().process_frame
		steps += 1
		if t.game.is_human_turn():
			var acts := t.CardEngine.legal_actions(t.game.state, "you")
			var pick: Dictionary = acts[acts.size() - 1]
			for a in acts:
				if a["type"] == "play":
					pick = a
					break
			match pick["type"]:
				"play": t.game.human_play(pick["cardId"], "H" if pick.has("chosenSuit") else "")
				"draw": t.game.human_draw()
				"takePenalty": t.game.human_take_penalty()
	await get_tree().create_timer(4.5).timeout # flights land, results screen builds
	_save(path, "_0")
	await get_tree().create_timer(0.5).timeout
	_save(path, "_1")
	await get_tree().create_timer(1.2).timeout
	_save(path, "_2")
	await get_tree().create_timer(1.5).timeout
	_save(path, "_3")
	get_tree().quit()


## Forces Rex down to one card and captures the CHECK alert, then the persistent warnings.
## Screenshots of the reaction stickers on the real table: bots reacting, then the picker open.
func _reactshot(path: String) -> void:
	var t := _start_game(3, "normal")
	t.game.bot_delay = 99.0 # we drive the bots by hand
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.0).timeout
	t.show_reaction("bot1", "angry")
	t.show_reaction("bot2", "laugh")
	t.show_reaction("bot3", "hurry")
	t.show_reaction("you", "gg")
	await get_tree().create_timer(0.55).timeout
	_save(path, "_stickers")
	await get_tree().create_timer(2.4).timeout
	t.react_menu.open()
	await get_tree().create_timer(0.6).timeout
	_save(path, "_menu")
	get_tree().quit()


func _checkshot(path: String) -> void:
	var t := _start_game(2, "normal")
	t.game.bot_delay = 99.0 # we drive the bots by hand
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.0).timeout
	var st: Dictionary = t.game.state
	st["required"] = {"kind": "free"}
	var rex: Dictionary = st["players"][1]
	rex["hand"] = rex["hand"].slice(0, 2)
	st["current"] = 1
	t.game.updated.emit([])
	await get_tree().create_timer(0.3).timeout
	t.game._apply({"type": "play", "playerId": "bot1", "cardId": rex["hand"][0]["id"]})
	var marks := [0.25, 0.25, 0.3, 0.4, 1.2, 1.0]
	var i := 0
	for m in marks:
		await get_tree().create_timer(m).timeout
		_save(path, "_%d" % i)
		i += 1
	get_tree().quit()


func _autoshot(path: String, bots: int) -> void:
	var t := _start_game(bots, "normal")
	t.game.bot_delay = 0.3
	t.game.rng.seed = 5
	await get_tree().create_timer(0.75).timeout
	_save(path, "_a") # cards flying out during the deal
	var guard := 0
	while (t._locked() or not t.game.is_human_turn()) and not t.game.state["over"] and guard < 400:
		await get_tree().create_timer(0.05).timeout
		guard += 1
	await get_tree().create_timer(0.8).timeout
	# Play one card (or draw) and catch it mid-flight.
	var acts := t.CardEngine.legal_actions(t.game.state, "you")
	var pick: Dictionary = acts[acts.size() - 1]
	for a in acts:
		if a["type"] == "play":
			pick = a
			break
	match pick["type"]:
		"play": t.game.human_play(pick["cardId"], str(pick.get("chosenSuit", "")))
		"draw": t.game.human_draw()
		"takePenalty": t.game.human_take_penalty()
	await get_tree().create_timer(0.2).timeout
	_save(path, "_b")
	# Let a couple of bot turns happen, then catch a bot's card in flight.
	await get_tree().create_timer(1.2).timeout
	_save(path, "_c")
	get_tree().quit()
