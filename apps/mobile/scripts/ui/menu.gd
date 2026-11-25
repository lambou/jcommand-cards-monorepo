extends Control
## Start screen: pick the number of bots and their difficulty.

signal start_requested(bots: int, difficulty: String)
signal resume_requested(path: String)
signal replay_requested(path: String)
signal tutorial_requested(chapter: int)

const Tutorial := preload("res://scripts/game/tutorial.gd")
const Settings := preload("res://scripts/game/settings.gd")
const Avatar := preload("res://scripts/ui/avatar.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const LeaderboardPanel := preload("res://scripts/ui/leaderboard_panel.gd")
const HistoryPanel := preload("res://scripts/ui/history_panel.gd")
const Recorder := preload("res://scripts/game/recorder.gd")
const MenuBackdrop := preload("res://scripts/ui/menu_backdrop.gd")

const RULES_TEXT := """GOAL
Be the first to play all your cards.

YOUR TURN
Play a card of the required suit, or tap the bank to draw one card (that ends your turn).

SPECIAL CARDS
7 - next player draws 2. A 7 can be played on any Joker.
Joker - next player draws 4. Red Joker goes on red cards, black on black. After a Joker, play any card of its color.
Penalties stack: answer a 7 or Joker with another 7 or Joker (any suit) to pass the total on.
2 - goes on anything and slides under the pile; nothing changes.
J - you choose the next suit. A J can go on another J.
Ace (Stop) - skips the next player. An Ace can go on another Ace.

SCORING
Points for your finishing place, multiplied for more opponents and for the difficulty (Easy less, Hard more). Finish without ever drawing from the bank (a CLEAN FINISH) for 3000 bonus points. Forced penalty draws do not count against you.

ENDING
In a 2-player game you cannot finish on an Ace, and a last 7 or Joker only wins if the opponent cannot answer it."""

var bots := 2
var difficulty := "normal"
var notice := "" # shown above the buttons, e.g. why a game could not be resumed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())

	var saved := Recorder.in_progress()
	# A saved game adds a second big button; tighten the gaps so it all still fits without scrolling.
	var box := UI.column(UI.SPACE_M if saved.is_empty() else UI.SPACE_S + 4)
	add_child(box)
	box.add_child(UI.brand_header("J-COMMAND"))
	box.add_child(UI.tagline("Shed your cards. Stop the others."))
	box.add_child(UI.spacer(20 if saved.is_empty() else 0))

	var card := UI.panel()
	card[0].custom_minimum_size.x = UI.MENU_W
	card[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # the logo + title row is wider; keep the menu block narrower
	box.add_child(card[0])
	card[1].add_child(UI.heading("Opponents"))
	card[1].add_child(UI.choice_row(["1", "2", "3"], 1, func(i): bots = i + 1, true))
	card[1].add_child(UI.spacer(6))
	card[1].add_child(UI.heading("Difficulty"))
	card[1].add_child(UI.choice_row(["Easy", "Normal", "Hard"], 1, func(i): difficulty = ["easy", "normal", "hard"][i], true))

	box.add_child(UI.spacer(10))
	if notice != "":
		box.add_child(UI.hint(notice, UI.MENU_W))
	var buttons: Array[Button] = []
	if not saved.is_empty():
		var path: String = saved["path"]
		buttons.append(UI.button("Resume game", UI.Variant.PRIMARY, func(): resume_requested.emit(path), true))
	buttons.append(UI.button("PLAY", UI.Variant.PRIMARY, func(): start_requested.emit(bots, difficulty), true))
	buttons.append(UI.button("Leaderboard", UI.Variant.SECONDARY, _show_leaderboard))
	buttons.append(UI.button("History", UI.Variant.SECONDARY, _show_history))
	buttons.append(UI.button("How to play", UI.Variant.SECONDARY, _show_howto))
	buttons.append(UI.button("Settings", UI.Variant.TERTIARY, _show_settings))
	for b in buttons:
		b.custom_minimum_size.x = UI.MENU_W
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(b)
		b.modulate.a = 0.0   # hidden until the entrance animation lifts it in
	_pill_up.call_deferred(buttons)
	# First launch only (debug runs and screenshots skip it): offer the tutorial once, never force it.
	if Recorder.enabled and not Settings.tutorial_seen:
		Settings.tutorial_seen = true
		Settings.save()
		_show_welcome.call_deferred()


## Opening animation: the buttons (Resume/PLAY down to Settings) rise one after another from the
## bottom of the screen and settle into place with a small overshoot. Waits a frame so the column
## has laid them out, then tweens each from below the screen edge back to its resting position.
func _pill_up(buttons: Array[Button]) -> void:
	await get_tree().process_frame
	var screen_h := get_viewport_rect().size.y
	for i in buttons.size():
		var b := buttons[i]
		if not is_instance_valid(b):
			continue
		var rest := b.position.y
		b.position.y = rest + screen_h - b.global_position.y + 40.0   # start just below the bottom edge
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var delay := 0.08 * i
		var t := b.create_tween().set_parallel()
		t.tween_property(b, "position:y", rest, 0.55).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "modulate:a", 1.0, 0.25).set_delay(delay)
		t.chain().tween_callback(func(): b.mouse_filter = Control.MOUSE_FILTER_STOP)


## "How to play": learn by playing the tutorial chapters with Rex, or read the rules.
func _show_howto() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(UI.background())
	var page := UI.scroll_page("How to play", "Close", func(): UI.slide_out(overlay))
	overlay.add_child(page["scroll"])
	overlay.add_child(page["header"])
	overlay.add_child(page["footer"])
	var content: VBoxContainer = page["content"]
	content.add_child(UI.hint("Learn by playing, with Rex. Each chapter takes about a minute.", 900))
	var card := UI.panel()
	content.add_child(card[0])
	var chapters := Tutorial.chapters()
	for i in chapters.size():
		var ch: Dictionary = chapters[i]
		var done := Settings.tutorial_chapter_done(str(ch["id"]))
		var b := UI.button("%s%d. %s" % ["✓ " if done else "", i + 1, ch["title"]], UI.Variant.PRIMARY if i == _next_chapter() else UI.Variant.SECONDARY,
			func(): tutorial_requested.emit(i))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card[1].add_child(b)
		card[1].add_child(UI.hint(str(ch["blurb"])))
	content.add_child(UI.spacer(UI.SPACE_S))
	var rules := UI.button("Read the rules", UI.Variant.TERTIARY, _show_rules)
	rules.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(rules)
	add_child(overlay)
	UI.slide_in(overlay)


## The first chapter that is not finished yet (the highlighted one in the chooser).
func _next_chapter() -> int:
	var chapters := Tutorial.chapters()
	for i in chapters.size():
		if not Settings.tutorial_chapter_done(str(chapters[i]["id"])):
			return i
	return 0


## One-time invitation shown over the menu the first time the game is opened.
func _show_welcome() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = UI.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.popup_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UI.SPACE_S)
	panel.add_child(box)
	var face := Control.new()
	face.custom_minimum_size = Vector2(190, 190)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func():
		Avatar.draw_avatar(face, 1, face.size / 2.0, 90.0, Color(1.0, 0.82, 0.2), 6.0, true))
	face.set_process(true)
	box.add_child(face)
	box.add_child(UI.title("New here?", 80))
	var text := UI.body("I'm Rex. Learn J-Command by playing a few quick hands with me - about 3 minutes.", 760)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	box.add_child(UI.spacer(UI.SPACE_S))
	var go := CenterContainer.new()
	go.add_child(UI.button("Teach me!", UI.Variant.PRIMARY, func(): tutorial_requested.emit(0)))
	box.add_child(go)
	var later := CenterContainer.new()
	later.add_child(UI.button("Maybe later", UI.Variant.TERTIARY, overlay.queue_free))
	box.add_child(later)
	add_child(overlay)
	# The vector avatars animate, so keep redrawing while the invitation is up.
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	timer.timeout.connect(face.queue_redraw)
	overlay.add_child(timer)


func _show_rules() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(UI.background())
	var page := UI.scroll_page("How to play", "Close", func(): UI.slide_out(overlay))
	overlay.add_child(page["scroll"])
	overlay.add_child(page["header"])
	overlay.add_child(page["footer"])
	page["content"].add_child(UI.body(RULES_TEXT, 900))
	add_child(overlay)
	UI.slide_in(overlay)


func _show_leaderboard() -> void:
	var p := LeaderboardPanel.new()
	p.closed.connect(UI.slide_out.bind(p))
	add_child(p)
	UI.slide_in(p)


func _show_history() -> void:
	var p := HistoryPanel.new()
	p.closed.connect(UI.slide_out.bind(p))
	p.replay_requested.connect(func(path): replay_requested.emit(path))
	add_child(p)
	UI.slide_in(p)


func _show_settings() -> void:
	var p := SettingsPanel.new()
	p.closed.connect(UI.slide_out.bind(p))
	add_child(p)
	UI.slide_in(p)
