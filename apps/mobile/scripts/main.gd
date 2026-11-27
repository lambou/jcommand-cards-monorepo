extends Control
## Root: switches between the menu and the table.
## Debug flags (after `--`):
##   --selftest              play full games through the real UI handlers; exit code 0 = pass
##   --shot=<file.png> [--bots=N]   save <file>_a/_b/_c.png: mid-deal, a card mid-flight, settled
##   --tutorialtest          plays every tutorial chapter through the real UI handlers; exit code 0 = pass
##   --taptest               the same with real touch and mouse events only (hit-testing, overlay, suit picker)
##   --tutorialshot=<file.png>   the same, saving <file>_c<chapter>_s<step>[_nudge|_picker] / _outro screenshots
##   --howtoshot=<file.png> / --welcomeshot=<file.png>   the "How to play" chooser / the first-launch invitation
##   --menushot=<file.png>   screenshot of the menu
##   --transitionshot=<file.png>   frames of the menu -> game screen transition
##   --bootshot=<file.png>   <file>_splash.png / _loading.png of the start-up sequence
##   --boardshot=<file.png>  leaderboard screen with sample scores (writes user://leaderboard.cfg)
##   --suitshot=<file.png>   the J suit picker (3D suits), then the PLAY pill spinning to a new suit
##   --revealshot=<file.png> <file>_before.png / _after0..4.png: the table, then a suit change
##   --comboshot=<file.png>  <file>_x2/_x3/_jackpot.png: a chain of Aces with the combo feedback
##   --gamemovie[=bots]      a whole unrigged game (default 2 bots) with the hard bot AI playing the human seat through the real UI handlers; record with --write-movie, prints REEL_START/REEL_END and the final place
##   --combomovie            the same chain, paced for a promo clip; record with `--write-movie out.avi --fixed-fps 30`, prints REEL_START/REEL_END frame numbers
##   --bonusshot=<file.png>  <file>_pass.png / _out.png: pass-on, then going out on a 7 to win
##   --outshot=<file.png>    the table with one bot already out (how a finished seat looks)
##   --penalty=N             a 2-bot game where you take an N-card penalty on your first turn, then play on (to try the draw animation)
##   --drawshot=<file.png>   <file>_0.. of the 3D hand dealing a 4-card penalty (--pending=N sets the size, 0 = a one-card draw; --frames=N)
##   --replayshot=<file.png> <file>_0/_mid/_end.png: replay of the newest record in user://games_test (made by tests/test_record_replay.gd)
##   --flipplay              playground for the bank draw: a real card lifted off the pile and flipped (ui/flip_playground.gd)
##   --flipshot=<file.png>   <file>_00.. slow-motion frames of one playground draw
##   --loaderplay            playground for the logo loader: spinning / progress / finish (ui/logo_loader.gd)
##   --loadershot=<file.png> <file>_spin0..3 / _p30/_p60/_p100 / _bare.png of the loader playground
##   --uitheme=<name>        run any screen with another design-system theme: felt / lagoon / sky / dusk / ember (ui/ui_themes.gd)
##   --dsplay                design-system playground: every ui_kit component, Current vs proposed look (ui/design_playground.gd)
##   --dsshot=<file.png>     <file>_<theme>_00.. of the whole playground page + _scrollpage, per theme
##   --dealplay              playground for the opening deal: flying cards / dealer hand / packets (ui/deal_playground.gd)
##   --dealshot=<file.png>   <file>_00.. frames of one playground deal ([--dealmode=0..2] [--players=N] [--cards=N])
##   --modelview             free-turn inspector for all 3D models (drag to rotate; see ui/model_view.gd)
##   --modelviewshot=<file.png>   <file>_0/_90/_180/_270.png of the inspector at four turn angles

const UI := preload("res://scripts/ui/ui_kit.gd")
const Boot := preload("res://scripts/ui/boot.gd")
const Menu := preload("res://scripts/ui/menu.gd")
const Table := preload("res://scripts/ui/table.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const Settings := preload("res://scripts/game/settings.gd")
const Recorder := preload("res://scripts/game/recorder.gd")
const Tutorial := preload("res://scripts/game/tutorial.gd")

var _current: Control
var _transition: Node   # the iris wipe between screens (player navigation only; debug runs swap instantly)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.load_settings()
	# Debug runs (selftest, screenshots) must not touch the player's saved games.
	Recorder.enabled = OS.get_cmdline_user_args().is_empty()
	add_child(Sfx.new())
	add_child(preload("res://scripts/ui/ui_feel.gd").new())
	_transition = preload("res://scripts/ui/transition.gd").new()
	add_child(_transition)
	for a in OS.get_cmdline_user_args():   # debug: run with another design-system theme (ui_themes.gd)
		if a.begins_with("--uitheme="):
			UI.apply_theme(a.substr(10))
	var shot := ""
	var podium_path := ""
	var bots := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
		elif a.begins_with("--table="):
			Settings.table_style = int(a.substr(8)) # this run only; not saved
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
		elif a.begins_with("--outshot="):
			_outshot(a.substr(10))
			return
		elif a == "--flipplay":
			_swap(preload("res://scripts/ui/flip_playground.gd").new())
			return
		elif a.begins_with("--flipshot="):
			var fp := preload("res://scripts/ui/flip_playground.gd").new()
			_swap(fp)
			fp.capture(a.substr(11))
			return
		elif a == "--loaderplay":
			_swap(preload("res://scripts/ui/loader_playground.gd").new())
			return
		elif a.begins_with("--loadershot="):
			var lp := preload("res://scripts/ui/loader_playground.gd").new()
			_swap(lp)
			lp.capture(a.substr(13))
			return
		elif a == "--dsplay":
			_swap(preload("res://scripts/ui/design_playground.gd").new())
			return
		elif a.begins_with("--dsshot="):
			var dsp := preload("res://scripts/ui/design_playground.gd").new()
			_swap(dsp)
			dsp.capture(a.substr(9))
			return
		elif a == "--dealplay":
			_swap(preload("res://scripts/ui/deal_playground.gd").new())
			return
		elif a.begins_with("--dealshot="):
			var dp := preload("res://scripts/ui/deal_playground.gd").new()
			_swap(dp)
			dp.capture(a.substr(11))
			return
		elif a == "--modelview":
			_swap(preload("res://scripts/ui/model_view.gd").new())
			return
		elif a.begins_with("--replayshot="):
			_replayshot(a.substr(13))
			return
		elif a.begins_with("--modelviewshot="):
			_modelviewshot(a.substr(16))
			return
		elif a.begins_with("--suitshot="):
			_suitshot(a.substr(11))
			return
		elif a.begins_with("--revealshot="):
			_revealshot(a.substr(13))
			return
		elif a.begins_with("--comboshot="):
			_comboshot(a.substr(12))
			return
		elif a.begins_with("--combomovie"):
			_combomovie()
			return
		elif a.begins_with("--gamemovie"):
			_gamemovie(int(a.get_slice("=", 1)) if "=" in a else 2)
			return
		elif a.begins_with("--bonusshot="):
			_bonusshot(a.substr(12))
			return
		elif a.begins_with("--reactshot="):
			_reactshot(a.substr(12))
			return
		elif a.begins_with("--howtoshot=") or a.begins_with("--welcomeshot="):
			_show_menu()
			if a.begins_with("--howtoshot="):
				_current._show_howto()
			else:
				_current._show_welcome()
			await get_tree().create_timer(0.6).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(a.find("=") + 1))
			get_tree().quit()
			return
		elif a == "--taptest":
			_taptest()
			return
		elif a == "--tutorialtest":
			_tutorialtest("")
			return
		elif a.begins_with("--tutorialshot="):
			_tutorialtest(a.substr(15))
			return
		elif a.begins_with("--slideshot="):
			_slideshot(a.substr(12))
			return
		elif a.begins_with("--penalty="):
			_penalty_play(int(a.substr(10)))
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
		elif a.begins_with("--bootshot="):
			var b := Boot.new()
			_swap(b)
			await get_tree().create_timer(1.0).timeout
			_save(a.substr(11), "_splash")
			# Then the loading screen from the moment it appears until it hands over: <file>_l00.. 0.15 s apart.
			await get_tree().create_timer(1.15).timeout
			for i in 24:
				_save(a.substr(11), "_l%02d" % i)
				if i == 7:
					_save(a.substr(11), "_loading")
				await get_tree().create_timer(0.15).timeout
			get_tree().quit()
			return
		elif a.begins_with("--transitionshot="):
			# Menu -> game through the iris: <file>_00.. frames 0.05 s apart (cover, logo, reveal).
			_show_menu()
			await get_tree().create_timer(1.2).timeout
			_go(_start_game.bind(2, "normal"))
			for i in 24:
				_save(a.substr(17), "_%02d" % i)
				await get_tree().create_timer(0.05).timeout
			get_tree().quit()
			return
		elif a.begins_with("--menushot="):
			_show_menu()
			await get_tree().create_timer(1.4).timeout   # let the buttons finish rising in
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
		_boot()


## Splash + loading screen, then the menu.
func _boot() -> void:
	var b := Boot.new()
	b.finished.connect(_go.bind(_show_menu))
	_swap(b)


func _swap(node: Control) -> void:
	if _current != null:
		_current.queue_free()
	_current = node
	add_child(node)


## Player navigation: the transition covers the screen, `build` swaps in the next one, then it opens.
func _go(build: Callable) -> void:
	_transition.go(build)


func _show_menu(notice: String = "") -> void:
	var m := Menu.new()
	m.notice = notice
	m.start_requested.connect(func(b, d): _go(_start_game.bind(b, d)))
	m.resume_requested.connect(func(path): _go(_resume_game.bind(path)))
	m.replay_requested.connect(func(path): _go(_replay_game.bind(path)))
	m.tutorial_requested.connect(func(ch): _go(_start_tutorial.bind(ch)))
	_swap(m)


func _resume_game(path: String) -> void:
	var rec := Recorder.load_record(path)
	if not rec["ok"]:
		_show_menu("Could not resume: %s" % rec["error"])
		return
	var t := Table.new()
	t.quit_to_menu.connect(_go.bind(_show_menu))
	t.play_again_requested.connect(func(b, d): _go(_start_game.bind(b, d)))
	_swap(t)
	var res := t.resume(rec)
	if not res["ok"]:
		Recorder.delete(path)
		_show_menu("Could not resume: %s. The saved game was removed." % res["error"])


func _replay_game(path: String) -> void:
	var rec := Recorder.load_record(path)
	if not rec["ok"]:
		_show_menu("Could not replay: %s" % rec["error"])
		return
	var t := Table.new()
	t.quit_to_menu.connect(_go.bind(_show_menu))
	t.play_again_requested.connect(func(b, d): _go(_start_game.bind(b, d)))
	_swap(t)
	var res := t.replay(rec)
	if not res["ok"]:
		_show_menu("Could not replay: %s" % res["error"])


func _start_game(bots: int, difficulty: String) -> Table:
	var t := Table.new()
	t.quit_to_menu.connect(_go.bind(_show_menu))
	t.play_again_requested.connect(func(b, d): _go(_start_game.bind(b, d)))
	_swap(t)
	t.start(bots, difficulty)
	return t


## Tutorial chapter `chapter` (0-based) with Rex. Its chapter-end buttons come back here.
func _start_tutorial(chapter: int) -> Table:
	var t := Table.new()
	t.quit_to_menu.connect(_go.bind(_show_menu))
	t.play_again_requested.connect(func(b, d): _go(_start_game.bind(b, d)))
	t.tutorial_chapter_requested.connect(func(ch): _go(_start_tutorial.bind(ch)))
	t.tutorial_play_requested.connect(_go.bind(_start_game.bind(1, "easy")))
	_swap(t)
	t.start_tutorial(chapter)
	return t


## Plays every tutorial chapter through the real UI handlers (taps, Next, suit picker), also trying wrong taps
## that must be refused. With a path it saves a screenshot of every step. Exit code 0 = pass.
func _tutorialtest(path: String) -> void:
	var ok := true
	for chapter in Tutorial.count():
		var t := _start_tutorial(chapter)
		t.game.bot_delay = 0.3
		var finished := await _drive_tutorial(t, path, chapter)
		print("tutorial chapter %d: %s" % [chapter + 1, "ok" if finished else "FAILED at step %d" % t.tutorial.index])
		if not finished:
			ok = false
		await get_tree().create_timer(0.8).timeout # outro pops in
		var outro_issues: Array = t.coach.layout_issues()
		if not outro_issues.is_empty():
			push_error("chapter %d outro at %s: %s" % [chapter + 1, str(t.size), "; ".join(outro_issues)])
			ok = false
		if path != "":
			_save(path, "_c%d_outro" % chapter)
	print("TUTORIAL ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


## One tap as the OS would deliver it ("touch" = a finger, "mouse" = a PC click) at a point in table coordinates.
func _tap(p: Vector2, kind: String) -> void:
	var wp := get_window().get_final_transform() * p # table (stretched) coordinates -> window pixels
	for down in [true, false]:
		if kind == "touch":
			var e := InputEventScreenTouch.new()
			e.index = 0
			e.position = wp
			e.pressed = down
			Input.parse_input_event(e)
		else:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.position = wp
			e.global_position = wp
			e.pressed = down
			e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			Input.parse_input_event(e)
		await get_tree().create_timer(0.08).timeout


## Plays every tutorial chapter with real taps/clicks only (hit-testing, fanned cards, the coach overlay on top,
## the suit picker), for both a touch screen and a mouse. Exit code 0 = pass.
func _taptest() -> void:
	var ok := true
	for kind in ["touch", "mouse"]:
		for chapter in Tutorial.count():
			var t := _start_tutorial(chapter)
			t.game.bot_delay = 0.3
			var done := await _drive_taps(t, kind)
			print("%s taps, chapter %d: %s" % [kind, chapter + 1, "ok" if done else "FAILED at step %d" % t.tutorial.index])
			ok = ok and done
	print("TAPTEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _drive_taps(t: Table, kind: String) -> bool:
	var started := Time.get_ticks_msec()
	var last := -1
	var tries := 0
	while Time.get_ticks_msec() - started < 60000:
		await get_tree().process_frame
		if t.coach.outro_visible():
			# The chapter-end buttons must be tappable too: "Replay chapter" restarts, so just check Menu is reachable.
			return true
		if not t.coach.active or t.tutorial.done():
			continue
		await get_tree().create_timer(0.7).timeout
		if not t.coach.active or t.tutorial.done():
			continue
		var idx: int = t.tutorial.index
		if idx != last:
			last = idx
			tries = 0
		tries += 1
		if tries > 6:
			push_error("tap had no effect at step %d" % idx)
			return false
		var s: Dictionary = t.tutorial.step()
		if s["expect"] == null:
			var nb: Control = t.coach._next
			await _tap(nb.global_position + nb.size / 2.0, kind)
			if t.coach.active and t.coach._typing != null and t.coach._typing.is_running():
				await _tap(nb.global_position + nb.size / 2.0, kind) # the first tap finished the sentence
			continue
		var ex: Dictionary = s["expect"]
		if ex["type"] == "play":
			for v in t.hand_views:
				if t.Cards.card_code(v.card) == str(ex["card"]):
					await _tap(v.get_global_transform() * Vector2(v.size.x * 0.22, v.size.y * 0.4), kind)
			if t.picker.visible:
				await get_tree().create_timer(0.5).timeout
				var b: Control = t.picker_buttons[str(ex["suit"])]
				await _tap(b.get_global_rect().get_center(), kind)
		else:
			await _tap(t.bank_view.get_global_rect().get_center(), kind)
	return false


func _drive_tutorial(t: Table, path: String, chapter: int) -> bool:
	var started := Time.get_ticks_msec()
	var shot_step := -1
	var wrong_tried := -1
	while Time.get_ticks_msec() - started < 60000:
		await get_tree().process_frame
		if t.coach.outro_visible():
			return true
		if not t.coach.active or t.tutorial.done():
			continue
		await get_tree().create_timer(0.7).timeout # the bubble pops in and Rex finishes the line
		if not t.coach.active or t.tutorial.done():
			continue
		var idx: int = t.tutorial.index
		var s: Dictionary = t.tutorial.step()
		var issues: Array = t.coach.layout_issues()
		if not issues.is_empty():
			push_error("chapter %d step %d at %s: %s" % [chapter + 1, idx, str(t.size), "; ".join(issues)])
			return false
		if path != "" and shot_step != idx:
			shot_step = idx
			_save(path, "_c%d_s%d" % [chapter, idx])
		if s["expect"] == null:
			t._on_coach_next()
			continue
		var ex: Dictionary = s["expect"]
		# A wrong tap must change nothing (and Rex nudges).
		if wrong_tried != idx:
			wrong_tried = idx
			var before := JSON.stringify(t.game.state)
			if ex["type"] == "play":
				t._on_bank_pressed(-1)
			elif not t.hand_views.is_empty():
				t._on_card_pressed(t.hand_views[0].card["id"])
			if JSON.stringify(t.game.state) != before or t.tutorial.index != idx:
				push_error("a wrong tap changed the game at step %d" % idx)
				return false
			if path != "":
				await get_tree().create_timer(0.3).timeout
				_save(path, "_c%d_s%d_nudge" % [chapter, idx])
		if ex["type"] == "play":
			var id := -1
			for v in t.hand_views:
				if t.Cards.card_code(v.card) == str(ex["card"]):
					id = v.card["id"]
			if id < 0:
				push_error("expected card %s is not in the hand" % ex["card"])
				return false
			t._on_card_pressed(id)
			if t.picker.visible:
				var wrong := "H" if str(ex["suit"]) != "H" else "S"
				t._on_suit_chosen(wrong)
				if not t.picker.visible or t.tutorial.index != idx:
					push_error("a wrong suit was accepted at step %d" % idx)
					return false
				await get_tree().create_timer(0.3).timeout
				if path != "":
					_save(path, "_c%d_s%d_picker" % [chapter, idx])
				t._on_suit_chosen(str(ex["suit"]))
		else:
			t._on_bank_pressed(-1)
	return false


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


## Switches the required suit mid-game and captures the table before, then frame by frame after.
func _revealshot(path: String) -> void:
	var t := _start_game(2, "normal")
	t.game.bot_delay = 30.0 # keep the bots out of the way
	t.game.rng.seed = 5
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	t.game.state["required"] = {"kind": "suit", "suit": "H"}
	t.game.updated.emit([])
	await get_tree().create_timer(1.0).timeout
	_save(path, "_before")
	t.game.state["required"] = {"kind": "suit", "suit": "S"}
	t.game.updated.emit([])
	var i := 0
	for m in [0.6, 0.9, 0.6, 0.9, 1.0]:
		await get_tree().create_timer(m).timeout
		_save(path, "_after%d" % i)
		i += 1
	get_tree().quit()


## `--penalty=N`: a normal 2-bot game in which, on your first turn, you are handed an N-card penalty and take
## it (a few seconds after the turn starts, so you can watch). The game then carries on for you to test.
func _penalty_play(count: int) -> void:
	var t := _start_game(2, "normal")
	t.game.rng.seed = 5
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(2.5).timeout
	t.game.state["pending"] = count
	t.game.updated.emit([])
	await get_tree().create_timer(1.5).timeout
	t.game.human_take_penalty()


## Forces a penalty on the human (4 cards unless --pending=N) and captures the 3D hand dealing the cards in.
func _drawshot(path: String) -> void:
	var t := _start_game(2, "normal")
	t.game.bot_delay = 5.0 # keep the bots out of the way
	t.game.rng.seed = 5
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.0).timeout
	var pending := 4 # --pending=N: size of the penalty (0 = an ordinary one-card draw)
	var frames := 6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pending="):
			pending = int(a.substr(10))
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
	if pending > 0:
		t.game.state["pending"] = pending
		t.game.updated.emit([])
	await get_tree().create_timer(0.3).timeout
	if pending > 0:
		t.game.human_take_penalty()
	else:
		t.game.human_draw()
	var i := 0
	for k in frames:
		await get_tree().create_timer(0.25 if frames > 6 else [0.25, 0.2, 0.2, 0.2, 0.3, 0.6][k]).timeout
		_save(path, "_%02d" % i)
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
	# --fxcard=2|7|JOKER|A|J picks which special card to inject and play (default 2).
	var which := "2"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fxcard="):
			which = a.substr(9)
	var cards := {
		"2": {"id": 999, "rank": "2", "suit": "S", "color": "black"},
		"7": {"id": 999, "rank": "7", "suit": "H", "color": "red"},
		"JOKER": {"id": 999, "rank": "JOKER", "suit": "", "color": "red"},
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


## Rigs a 1v1 game so you hold four Aces, plays them in a row and captures each combo popup.
func _comboshot(path: String) -> void:
	var t := _start_game(1, "normal")
	t.game.bot_delay = 99.0
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.0).timeout
	var st: Dictionary = t.game.state
	st["required"] = {"kind": "free"}
	st["pending"] = 0
	var hand: Array = st["players"][0]["hand"]
	hand.clear()
	var suits := {"H": "red", "D": "red", "C": "black", "S": "black"}
	var id := 9001
	for su in suits:
		hand.append({"id": id, "rank": "A", "suit": su, "color": suits[su]})
		id += 1
	hand.append({"id": id, "rank": "5", "suit": "H", "color": "red"})
	hand.append({"id": id + 1, "rank": "9", "suit": "S", "color": "black"})
	st["current"] = 0
	t.game.updated.emit([])
	await get_tree().create_timer(0.6).timeout
	var names := ["", "_x2", "_x3", "_jackpot", "_jackpot_follow"]
	for i in 4:
		t.game.human_play(9001 + i)
		await get_tree().create_timer(0.95 if i > 0 else 0.7).timeout
		if i > 0:
			_save(path, names[i])
	t.game.human_play(id)
	await get_tree().create_timer(0.95).timeout
	_save(path, names[4])
	get_tree().quit()


## Promo reel: three Aces back to back (x2, x3 combos), then the black Joker - the lion roars and Rex takes 4.
## Meant for `godot --write-movie reel.avi --fixed-fps 30 -- --combomovie`; the printed frame numbers let you trim the deal.
##
## Every move obeys the real rules and the position is never forced: we only swap REAL cards of the dealt deck into
## the human hand (so no card exists twice) and keep Rex free of 7s/Jokers so he really has to draw. The state's
## `required`, `pending` and `stack` are untouched. Each play is checked against the engine's own legal actions and
## the script exits with an error if any step is not legal. Sequence, with R = the suit the dealt pile asks for:
##   Ace of R   (Ace on the required suit)  -> sets suit R,  skips Rex
##   Ace of X   (Ace on an Ace, same rank)   -> sets suit X,  skips Rex   (x2 combo)
##   Ace of B   (Ace on an Ace, B is black)  -> sets suit B,  skips Rex   (x3 combo)
##   Black Joker (black on a black suit)     -> Rex must take 4
func _combomovie() -> void:
	const CardEngine := preload("res://scripts/engine/engine.gd")
	var t := _start_game(1, "normal")
	t.game.bot_delay = 99.0
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.4).timeout
	var st: Dictionary = t.game.state
	var req: Dictionary = st["required"]
	# Find a legal chain in THIS deal: three distinct Aces not on the pile, the first playable on the pile (the required
	# suit, or any Ace if the pile top is itself an Ace or the opening card made it free), the last one black so the
	# black Joker can follow it. If this deal has none, exit with code 2 and let the caller deal again.
	var stack_top: Dictionary = st["stack"][st["stack"].size() - 1]
	var any_first: bool = req["kind"] == "free" or stack_top["rank"] == "A"
	var avail: Array = []
	for su in ["H", "D", "C", "S"]:
		var on_pile := false
		for c in st["stack"]:
			if c["rank"] == "A" and c["suit"] == su:
				on_pile = true
		if not on_pile:
			avail.append(su)
	var chain: Array = []
	for f in avail:
		if not (any_first or (req["kind"] == "suit" and req["suit"] == f)):
			continue
		for m in avail:
			for l in avail:
				if chain.is_empty() and f != m and m != l and f != l and (l == "C" or l == "S"):
					chain = [f, m, l]
	if chain.is_empty():
		print("REEL_NO_CHAIN required=", req, " pile top=", stack_top["rank"], stack_top["suit"])
		get_tree().quit(2)
		return
	# Pull the real cards we need out of wherever they are (bank or Rex's hand), parking the old human hand in the bank.
	var human: Dictionary = st["players"][0]
	var rex: Dictionary = st["players"][1]
	var bank: Array = st["bank"]
	var wanted: Array = []
	for su in chain:
		wanted.append({"rank": "A", "suit": su})
	wanted.append({"rank": "JOKER", "color": "black"})
	wanted.append({"rank": "5", "suit": "H"})
	wanted.append({"rank": "9", "suit": "S"})
	var new_hand: Array = []
	for w in wanted:
		var found := {}
		for pool in [human["hand"], bank, rex["hand"]]:
			for c in pool:
				if c["rank"] == w["rank"] and (w.get("suit", c["suit"]) == c["suit"]) and (w.get("color", c["color"]) == c["color"]):
					found = c
					break
			if not found.is_empty():
				pool.erase(found)
				break
		if found.is_empty():
			push_error("reel: card %s not available (it is on the pile)" % str(w))
			get_tree().quit(1)
			return
		new_hand.append(found)
	for c in human["hand"]:
		bank.push_back(c)
	human["hand"] = new_hand
	# Rex must have no 7 or Joker (he could answer the Joker with one); swap any for harmless bank cards.
	for c in rex["hand"].duplicate():
		if c["rank"] == "7" or c["rank"] == "JOKER":
			rex["hand"].erase(c)
			for bc in bank:
				if bc["rank"] != "7" and bc["rank"] != "JOKER" and bc["rank"] != "A" and bc["rank"] != "2":
					bank.erase(bc)
					rex["hand"].append(bc)
					break
			bank.push_back(c)
	t.game.updated.emit([])
	await get_tree().create_timer(0.5).timeout
	print("REEL_START ", Engine.get_frames_drawn(), " chain ", chain)
	var order := [new_hand[0], new_hand[1], new_hand[2], new_hand[3]]
	for c in order:
		var legal := false
		for a in CardEngine.legal_actions(t.game.state, "you"):
			if a["type"] == "play" and a["cardId"] == c["id"]:
				legal = true
		if not legal:
			push_error("reel: %s %s is NOT legal here (required %s, pending %s)" % [c["rank"], c["suit"], str(t.game.state["required"]), str(t.game.state["pending"])])
			get_tree().quit(1)
			return
		print("PLAY ", c["rank"], c["suit"], c["color"], " required=", t.game.state["required"], " ok=", t.game.human_play(c["id"]))
		await get_tree().create_timer(0.8 if c["rank"] == "A" else 1.9).timeout
	var pen: Dictionary = {"type": "takePenalty", "playerId": "bot1"}
	var rex_legal := false
	for a in CardEngine.legal_actions(t.game.state, "bot1"):
		if a["type"] == "takePenalty":
			rex_legal = true
	print("REX takes penalty legal=", rex_legal, " pending=", t.game.state["pending"])
	if not rex_legal:
		get_tree().quit(1)
		return
	t.game._apply(pen)
	await get_tree().create_timer(1.5).timeout
	print("REEL_END ", Engine.get_frames_drawn())
	get_tree().quit()


## A full, unrigged game for a promo video: the "hard" bot AI plays the human seat through the same UI handlers a
## finger would use (card tap, suit picker, bank tap), pausing like a person would between moves. Nothing in the
## game state is touched, so every move is legal by construction. Exit code 0 when the human finished first,
## 2 when not (the caller can simply record another game), 3 on a timeout.
func _gamemovie(bots: int) -> void:
	const Bot := preload("res://scripts/ai/bot.gd")
	var t := _start_game(bots, "normal")
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	print("REEL_START ", Engine.get_frames_drawn())
	var elapsed := 0.0
	while not t.game.state["over"] and elapsed < 420.0:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if t._locked() or not t.game.is_human_turn() or t.game.state["players"][0]["status"] == "finished":
			continue
		# Think a moment like a person (1.0 - 1.7 s), then re-check it is still our turn.
		await get_tree().create_timer(randf_range(1.0, 1.7)).timeout
		elapsed += 1.4
		if t._locked() or not t.game.is_human_turn():
			continue
		var act: Dictionary = Bot.choose_action(t.game.state, "you", "hard", t.game.rng, t.game.memory)
		match act["type"]:
			"play":
				t._on_card_pressed(int(act["cardId"]))
				if t.picker.visible:
					t._on_suit_chosen(str(act.get("chosenSuit", "H")))
			_:
				t._on_bank_pressed(-1)
	if not t.game.state["over"]:
		print("GAME_TIMEOUT")
		get_tree().quit(3)
		return
	await get_tree().create_timer(5.0).timeout   # let the last cards land and the results screen fade in
	var order: Array = t.game.state["finishedOrder"]
	var place := order.find("you") + 1
	print("GAME_RESULT place=", place, " order=", order)
	print("REEL_END ", Engine.get_frames_drawn())
	get_tree().quit(0 if place == 1 else 2)


## Rigged 1v1 hands: first a 7 the bot has to take (pass-on), then a lone 7 to go out and win.
func _bonusshot(path: String) -> void:
	for scene in ["pass", "out"]:
		var t := _start_game(1, "normal")
		t.game.bot_delay = 99.0
		while t._locked() or not t.game.is_human_turn():
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.8).timeout
		var st: Dictionary = t.game.state
		st["required"] = {"kind": "suit", "suit": "H"}
		st["pending"] = 0
		var hand: Array = st["players"][0]["hand"]
		hand.clear()
		hand.append({"id": 9001, "rank": "7", "suit": "H", "color": "red"})
		if scene == "pass":
			hand.append({"id": 9002, "rank": "5", "suit": "H", "color": "red"})
			hand.append({"id": 9003, "rank": "9", "suit": "S", "color": "black"})
		st["current"] = 0
		t.game.updated.emit([])
		await get_tree().create_timer(0.6).timeout
		t.game.human_play(9001)
		await get_tree().create_timer(0.8).timeout
		t.game._apply({"type": "takePenalty", "playerId": "bot1"})
		await get_tree().create_timer(1.35 if scene == "pass" else 0.75).timeout
		_save(path, "_" + scene)
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


## Two bots: Luna has gone out (her last card shown), Rex is still playing.
func _outshot(path: String) -> void:
	var t := _start_game(2, "normal")
	t.game.bot_delay = 99.0 # freeze the bots
	while t._locked() or not t.game.is_human_turn():
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.0).timeout
	var st: Dictionary = t.game.state
	var luna: Dictionary = st["players"][2]
	t._last_played[luna["id"]] = luna["hand"][0]
	luna["hand"] = []
	luna["status"] = "finished"
	t.game.updated.emit([])
	await get_tree().create_timer(0.6).timeout
	_save(path, "")
	get_tree().quit()


func _replayshot(path: String) -> void:
	Recorder.dir = "user://games_test"
	var recs := Recorder.list().filter(func(r): return r["finished"])
	if recs.is_empty():
		push_error("no records: run tests/test_record_replay.gd first")
		get_tree().quit(1)
		return
	var rec: Dictionary = recs[0]
	var t := Table.new()
	_swap(t)
	t.replay(rec)
	await get_tree().create_timer(1.2).timeout
	_save(path, "_0")
	var n: int = t.game.replay_count()
	for i in n / 2:
		t._replay_step()
		await get_tree().create_timer(0.05).timeout
	t._replay_update()
	await get_tree().create_timer(1.0).timeout
	_save(path, "_mid")
	t.game.replay_seek(n)
	t._replay_update()
	await get_tree().create_timer(1.0).timeout
	_save(path, "_end")
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
