extends Control
## The game table: opponents on top, bank + stack in the middle, your hand at the bottom.
## Cards animate between those places; each seat previews the last card its player played.

const CardEngine := preload("res://scripts/engine/engine.gd")
const Rules := preload("res://scripts/engine/rules.gd")
const Cards := preload("res://scripts/engine/cards.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")
const CardView := preload("res://scripts/ui/card_view.gd")
const OpponentView := preload("res://scripts/ui/opponent_view.gd")
const RequiredView := preload("res://scripts/ui/required_view.gd")
const SuitButton := preload("res://scripts/ui/suit_button.gd")
const OfflineGame := preload("res://scripts/game/offline_game.gd")
const Fx := preload("res://scripts/ui/fx.gd")
const SuitReveal := preload("res://scripts/ui/suit_reveal.gd")
const CardLights := preload("res://scripts/ui/card_lights.gd")
const Avatar := preload("res://scripts/ui/avatar.gd")
const AvatarView := preload("res://scripts/ui/avatar_view.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Scoring := preload("res://scripts/game/scoring.gd")
const Leaderboard := preload("res://scripts/game/leaderboard.gd")
const Podium := preload("res://scripts/ui/podium.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const Settings := preload("res://scripts/game/settings.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const Hand3D := preload("res://scripts/ui/hand3d.gd")
const Reactions := preload("res://scripts/game/reactions.gd")
const ReactionBubble := preload("res://scripts/ui/reaction_bubble.gd")
const ReactionMenu := preload("res://scripts/ui/reaction_menu.gd")
const Tutorial := preload("res://scripts/game/tutorial.gd")
const Coach := preload("res://scripts/ui/coach.gd")

signal quit_to_menu
signal tutorial_chapter_requested(index: int) # chapter-end buttons: next chapter / replay this one
signal tutorial_play_requested # after the last chapter: start a real game

const ME := "you"
const SUIT_ORDER := {"H": 0, "D": 1, "C": 2, "S": 3, "": 4}
const RANK_ORDER := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "JOKER"]
const FLY := 0.42 # seconds for a card to travel
const STAGGER := 0.07 # delay between cards of one batch
const REACH := 0.3 # seconds the 3D hand takes to reach a card before it flies
const HURRY_AFTER_MS := 14000 # a bot nudges you when your turn has taken this long
const BOT_SAY_GAP_MS := 2200 # at most one bot sticker per this many ms, so the table stays calm
const SLIDE_UNDER_TIME := 0.5 # lift 0.16 + slide 0.3, then the hand lets go as the pile lowers

var game: Node
var bots := 2
var difficulty := "normal"

var bg: TableBg
var menu_button: Button
var settings_button: Button
var opp_views: Dictionary = {}
var hand_views: Array = []
var bank_view: Control
var stack_view: Control
var suit_lights: Control # chasing lights on the pile's top card while it is the one that changed the suit
var _lights_card_id := -1
var required_view: Control
var you_last: Control
var you_avatar: Control
var bank_caption: Label
var stack_caption: Label
var you_caption: Label
var you_points: Label # your running points, under your avatar
var message_label: Label
var banner_label: Label
var fx: Control
var hand3d: Control
var picker: Control
var over_panel: Control

var _pending_j := -1
var _log: Array = []
var _last_floor_id := -1
var _floor_held := -1
var _flash_serial := 0
var _shown_over := false
var _dealt := false
var _lock_until := 0
# Turn indicator queue: the seat highlight / "X is thinking" banner follow the real current player
# only once the animations of the previous move have finished. Entries are {cur, at (msec)}.
var _shown_cur := ""
var _turn_queue: Array = []
var _turn_gate_ms := 0 # when the last queued turn change is due
var _turn_serial := 0 # bumped on reset so stale timers do nothing
var _hidden: Dictionary = {} # card id -> true: hand cards still "in flight"
var _last_played: Dictionary = {} # player id -> card
var _stack_note := ""
var _sliding := 0 # 2s currently sliding under the pile
var _shown_required: Dictionary = {}
var _alerted: Dictionary = {} # players whose CHECK alert already fired
var _last_alert_ms: Dictionary = {}
var _was_human_turn := false
var _hand_scroll := 0.0 # px the hand fan is shifted by swiping (0 = centred)
var _hand_max_scroll := 0.0
var _hand_visible_frac := 1.0 # share of the whole hand that fits on screen
var hand_bar: Control
var react_menu: Control

# Tutorial mode (see game/tutorial.gd): null in a normal game, so nothing below changes real play.
var tutorial: Tutorial = null
var coach: Control # Rex's overlay (ui/coach.gd)
var picker_buttons: Dictionary = {} # suit -> its button in the J picker, so the coach can spotlight one
var _outro_shown := false

var _react_bubbles: Dictionary = {} # seat id -> the sticker currently showing there
var _react_last_ms: Dictionary = {} # seat id -> when it last sent a reaction
var _last_bot_say_ms := -100000
var _react_epoch := 0 # bumped on every new game so late bot timers do nothing
var _react_rng := RandomNumberGenerator.new() # separate from the game RNG on purpose
var _react_human_turn := false
var _react_turn_ms := 0
var _hurried := false
var _hold_layout := 0.0 # seconds the hand fan waits before closing a gap

const REPLAY_STEP := 1.3 # seconds per action at 1x
const REPLAY_SPEEDS := [0.5, 1.0, 2.0, 4.0]
var replay_bar: Control
var _replay_play: Button
var _replay_speed_btn: Button
var _replay_label: Label
var _replay_playing := false
var _replay_speed := 1
var _replay_accum := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_relayout)


func start(p_bots: int, p_difficulty: String) -> void:
	tutorial = null
	bots = p_bots
	difficulty = p_difficulty
	_build()
	game.bot_delay = 1.0
	game.bot_delay_max = 2.0
	game.start(bots, difficulty)


## Plays tutorial chapter `index` (0-based) against Rex, with Rex coaching. Nothing is recorded or scored.
func start_tutorial(index: int) -> void:
	tutorial = Tutorial.new(index)
	bots = 1
	difficulty = "easy"
	_build()
	game.bot_delay = 1.1
	game.bot_delay_max = -1.0
	opp_views[Tutorial.REX].avatar_index = Coach.REX_STYLE
	if you_avatar.avatar_index == Coach.REX_STYLE: # you picked Rex's look: don't be your own opponent
		you_avatar.avatar_index = 0
	coach = Coach.new()
	coach.next_pressed.connect(_on_coach_next)
	coach.outro_next.connect(func():
		if tutorial.is_last_chapter():
			tutorial_play_requested.emit()
		else:
			tutorial_chapter_requested.emit(tutorial.chapter_index + 1))
	coach.outro_replay.connect(func(): tutorial_chapter_requested.emit(tutorial.chapter_index))
	coach.outro_menu.connect(func(): quit_to_menu.emit())
	add_child(coach)
	_relayout()
	game.start_tutorial(tutorial.chapter, "Rex")


## Continues a saved, unfinished game. Returns {ok} or {ok:false, error}.
func resume(rec: Dictionary) -> Dictionary:
	tutorial = null
	bots = (rec["header"]["player_ids"] as Array).size() - 1
	difficulty = str(rec["header"]["difficulty"])
	_build()
	game.bot_delay = 1.0
	game.bot_delay_max = 2.0
	return game.resume(rec)


## Watches a recorded game: no input, transport controls at the top.
func replay(rec: Dictionary) -> Dictionary:
	tutorial = null
	bots = (rec["header"]["player_ids"] as Array).size() - 1
	difficulty = str(rec["header"]["difficulty"])
	_build()
	var res: Dictionary = game.start_replay(rec)
	if res["ok"]:
		_build_replay_bar()
		_relayout()
	return res


# ---------------------------------------------------------------- build

func _build() -> void:
	for c in get_children():
		c.queue_free()
	coach = null
	picker_buttons.clear()
	_outro_shown = false
	opp_views.clear()
	hand_views.clear()
	_log.clear()
	_hidden.clear()
	_last_played.clear()
	_last_floor_id = -1
	_floor_held = -1
	_shown_over = false
	_dealt = false
	_lock_until = 0
	_shown_cur = ""
	_turn_queue.clear()
	_turn_gate_ms = 0
	_turn_serial += 1
	_stack_note = ""
	_sliding = 0
	_shown_required = {}
	_alerted.clear()
	_last_alert_ms.clear()
	_react_bubbles.clear()
	_react_last_ms.clear()
	_last_bot_say_ms = -100000
	_react_epoch += 1
	_react_rng.randomize()
	_react_human_turn = false
	_hurried = false
	_was_human_turn = false
	_pending_j = -1
	over_panel = null

	Settings.load_settings()
	bg = TableBg.new()
	bg.style = Settings.table_style % TableBg.STYLES.size()
	add_child(bg)

	game = OfflineGame.new()
	add_child(game)
	game.updated.connect(_on_updated)

	for i in range(1, bots + 1):
		var v := OpponentView.new()
		v.avatar_index = Avatar.index_for("bot%d" % i)
		opp_views["bot%d" % i] = v
		add_child(v)

	bank_view = CardView.new()
	bank_view.set_card({}, false)
	bank_view.pressed.connect(_on_bank_pressed)
	add_child(bank_view)

	stack_view = CardView.new()
	stack_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_view.visible = false
	stack_view.z_index = 5 # slid-under 2s travel beneath it
	add_child(stack_view)
	suit_lights = CardLights.new()
	suit_lights.visible = false
	suit_lights.z_index = 6
	add_child(suit_lights)

	you_last = CardView.new()
	you_last.mouse_filter = Control.MOUSE_FILTER_IGNORE
	you_last.visible = false
	add_child(you_last)

	you_avatar = AvatarView.new(Avatar.index_for("you"))
	add_child(you_avatar)

	required_view = RequiredView.new()
	add_child(required_view)

	bank_caption = _label(30, Color(1, 1, 1, 0.85))
	stack_caption = _label(30, Color(1.0, 0.85, 0.3))
	you_caption = _label(26, Color(1, 1, 1, 0.7))
	you_points = _label(30, Color(1, 1, 1, 0.85))
	message_label = _label(40, Color(1, 1, 1))
	banner_label = _label(44, Color(1.0, 0.85, 0.3))

	menu_button = UI.icon_button("home", func(): game.stop(); quit_to_menu.emit(), UI.Variant.SECONDARY, TableBg.current_theme()["button"])
	add_child(menu_button)

	settings_button = UI.icon_button("gear", _open_settings, UI.Variant.SECONDARY, TableBg.current_theme()["button"])
	add_child(settings_button)

	fx = Control.new() # flying cards live here, above the hand
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.z_index = 1000
	add_child(fx)

	hand3d = Hand3D.new() # the 3D hand that picks up and plays your cards
	hand3d.z_index = 1001
	add_child(hand3d)

	hand_bar = Control.new() # scroll indicator for an overflowing hand
	hand_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_bar.z_index = 500
	hand_bar.draw.connect(_draw_hand_bar)
	add_child(hand_bar)

	react_menu = ReactionMenu.new()
	react_menu.picked.connect(_on_react_picked)
	add_child(react_menu)

	_build_picker()
	_relayout()


func _build_replay_bar() -> void:
	replay_bar = HBoxContainer.new()
	replay_bar.add_theme_constant_override("separation", 10)
	var hb := replay_bar as HBoxContainer
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	for spec in [["|<", 90, func(): _replay_pause(); game.replay_seek(0); _replay_update()],
			["<", 90, func(): _replay_pause(); game.replay_seek(game.replay_cursor - 1); _replay_update()]]:
		hb.add_child(_replay_button(spec[0], spec[1], spec[2]))
	_replay_play = _replay_button("PLAY", 170, func():
		_replay_playing = not _replay_playing
		if _replay_playing and game.replay_cursor >= game.replay_count():
			game.replay_seek(0)
		_replay_update())
	hb.add_child(_replay_play)
	hb.add_child(_replay_button(">", 90, func(): _replay_pause(); _replay_step(); _replay_update()))
	_replay_speed_btn = _replay_button("1x", 100, func():
		_replay_speed = (_replay_speed + 1) % REPLAY_SPEEDS.size()
		_replay_update())
	hb.add_child(_replay_speed_btn)
	_replay_label = _label(34, Color(1, 1, 1, 0.9))
	_replay_label.custom_minimum_size = Vector2(140, 90)
	remove_child(_replay_label)
	hb.add_child(_replay_label)
	add_child(replay_bar)
	_replay_update()


func _replay_button(text: String, w: float, on_press: Callable) -> Button:
	var b := UI.pill(text, false, Vector2(w, 90), 40)
	b.pressed.connect(on_press)
	return b


func _replay_pause() -> void:
	_replay_playing = false


## One action forward with animation, plus the stickers that were sent right after it.
func _replay_step() -> void:
	if not game.replay_next():
		return
	var speed: float = REPLAY_SPEEDS[_replay_speed]
	for r in game.replay_reactions_after(game.replay_cursor):
		var who := str(r["from"])
		var id := str(r["id"])
		get_tree().create_timer(minf(float(r["delay"]) / 1000.0, 2.0) / speed).timeout.connect(func(): show_reaction(who, id))


func _replay_update() -> void:
	_replay_play.text = "PAUSE" if _replay_playing else "PLAY"
	_replay_speed_btn.text = "%sx" % str(REPLAY_SPEEDS[_replay_speed])
	_replay_label.text = "%d/%d" % [game.replay_cursor, game.replay_count()]


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", TableBg.current_theme()["ink"])
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _build_picker() -> void:
	picker = Control.new()
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.visible = false
	picker.z_index = 2000
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(center)

	# Felt-green card panel with a gold rim and a soft drop shadow.
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.22, 0.15)
	ps.set_corner_radius_all(44)
	ps.set_border_width_all(6)
	ps.border_color = Color(0.93, 0.76, 0.28)
	ps.shadow_color = Color(0, 0, 0, 0.55)
	ps.shadow_size = 40
	ps.shadow_offset = Vector2(0, 14)
	ps.content_margin_left = 54
	ps.content_margin_right = 54
	ps.content_margin_top = 40
	ps.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var font := preload("res://assets/fonts/LilitaOne-Regular.ttf")
	var title := Label.new()
	title.text = "Choose the next suit"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.07))
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Your Jack changes the suit in play"
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	box.add_child(gap)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for s in ["H", "D", "C", "S"]:
		var b := SuitButton.new(s)
		b.chosen.connect(_on_suit_chosen)
		picker_buttons[s] = b
		row.add_child(b)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	box.add_child(gap2)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.add_theme_font_override("font", font)
	cancel.add_theme_font_size_override("font_size", 36)
	cancel.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	cancel.add_theme_color_override("font_hover_color", Color.WHITE)
	cancel.custom_minimum_size = Vector2(220, 70)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(35)
		sb.bg_color = Color(1, 1, 1, 0.14 if state == "hover" or state == "pressed" else 0.07)
		sb.set_border_width_all(3)
		sb.border_color = Color(1, 1, 1, 0.35)
		if state == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
		cancel.add_theme_stylebox_override(state, sb)
	cancel.pressed.connect(func(): picker.visible = false; _pending_j = -1)
	box.add_child(cancel)
	add_child(picker)

	# Pop-in whenever the picker is shown.
	picker.visibility_changed.connect(func():
		if not picker.visible or Settings.reduce():
			return
		panel.pivot_offset = panel.size / 2.0
		panel.scale = Vector2(0.86, 0.86)
		picker.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(picker, "modulate:a", 1.0, 0.18)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


# ---------------------------------------------------------------- layout

func _hand_card_size() -> Vector2:
	var hw := minf(180.0, size.x * 0.17)
	return Vector2(hw, hw * CardView.BASE.y / CardView.BASE.x)


func _pile_card_size() -> Vector2:
	var cw := minf(250.0, size.x * 0.24)
	return Vector2(cw, cw * CardView.BASE.y / CardView.BASE.x)


func _relayout() -> void:
	if bank_view == null:
		return
	var w := size.x
	var h := size.y
	menu_button.position = Vector2(20, 14)
	if replay_bar != null:
		replay_bar.position = Vector2(UI.ICON_BTN + 40.0, 24.0)
		replay_bar.size = Vector2(w - 2.0 * (UI.ICON_BTN + 40.0), 90.0)
	settings_button.position = Vector2(w - 20.0 - UI.ICON_BTN, 14)

	# Opponents.
	var n := opp_views.size()
	var gap := 20.0
	var ow := minf(380.0, (w - 40.0 - gap * float(maxi(n - 1, 0))) / float(maxi(n, 1)))
	var oh := minf(230.0, h * 0.125)
	var total := ow * n + gap * float(maxi(n - 1, 0))
	var x := (w - total) / 2.0
	var oy := 140.0
	for id in opp_views:
		var v: Control = opp_views[id]
		v.size = Vector2(ow, oh)
		v.position = Vector2(x, oy)
		v.queue_redraw()
		x += ow + gap

	# Bank + stack, centred in the free space between opponents and hand.
	var cs := _pile_card_size()
	var hs := _hand_card_size()
	var free_top := oy + oh
	var free_bottom := h - hs.y - 150.0
	var block_h := cs.y + 80.0 + required_view.size.y + 100.0 + 110.0
	var cy := free_top + maxf((free_bottom - free_top - block_h) / 2.0, 20.0)
	bank_view.size = cs
	bank_view.position = Vector2(w / 2.0 - cs.x - 36, cy)
	stack_view.size = cs
	stack_view.position = Vector2(w / 2.0 + 36, cy)
	stack_view.pivot_offset = cs / 2.0
	bank_view.queue_redraw()
	stack_view.queue_redraw()
	# Captions sit below the pile's peeking cards (up to 3 offset ~6px*k, scaled) and above it in z.
	var cap_y := cy + cs.y + 30.0
	bank_caption.z_index = 10
	stack_caption.z_index = 10
	bank_caption.position = Vector2(bank_view.position.x - 40, cap_y)
	bank_caption.size = Vector2(cs.x + 80, 44)
	stack_caption.position = Vector2(stack_view.position.x - 60, cap_y)
	stack_caption.size = Vector2(cs.x + 120, 44)

	# Your own last-played card, left of the bank.
	var ms := Vector2(76, 76 * CardView.BASE.y / CardView.BASE.x)
	you_last.size = ms
	you_last.position = Vector2(maxf(bank_view.position.x - ms.x - 24.0, 10.0), cy + (cs.y - ms.y) / 2.0)
	you_last.queue_redraw()
	you_caption.position = Vector2(you_last.position.x - 40, you_last.position.y + ms.y + 2)
	you_caption.size = Vector2(ms.x + 80, 34)

	required_view.position = Vector2((w - required_view.size.x) / 2.0, cy + cs.y + 80)
	required_view.pivot_offset = required_view.size / 2.0
	message_label.position = Vector2(40, required_view.position.y + 100)
	message_label.size = Vector2(w - 80, 110)

	banner_label.size = Vector2(w - 60, 70)
	banner_label.position = Vector2(30, h - hs.y - 150)
	you_avatar.size = Vector2(104, 104)
	you_avatar.position = Vector2(24, h - hs.y - 215)
	you_points.size = Vector2(190, 38)
	you_points.position = Vector2(you_avatar.position.x + 52.0 - 95.0, you_avatar.position.y + 106.0)
	react_menu.place(Vector2(w - 24.0 - ReactionMenu.BTN, h - hs.y - 215.0), size)
	if coach != null:
		coach.bottom_limit = h - hs.y - 235.0 # keeps Rex's bubble off your avatar, the banner and the hand
	_layout_hand()


## Fans the hand out. With `smooth`, cards glide to their new slots (see _process); `delay` keeps the
## existing cards where they are for that long first (e.g. while the 3D hand reaches for one).
func _layout_hand(smooth: bool = false, delay: float = 0.0) -> void:
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func():
			if is_inside_tree():
				_layout_hand(true))
	var w := size.x
	var h := size.y
	var hs := _hand_card_size()
	var n := hand_views.size()
	if n == 0:
		return
	# Generous side margin: edge cards are rotated and dropped by the arc, so they
	# need extra room to be seen fully when scrolled to either end.
	var avail := w - 200.0
	# Fixed, readable overlap. If the hand is wider than the screen it scrolls by swipe.
	var step := hs.x * 0.5
	var total := hs.x + step * float(n - 1)
	var max_scroll := maxf((total - avail) / 2.0, 0.0)
	_hand_scroll = clampf(_hand_scroll, -max_scroll, max_scroll)
	_hand_max_scroll = max_scroll
	_hand_visible_frac = minf(avail / total, 1.0)
	if hand_bar != null:
		hand_bar.queue_redraw()
	var x0 := (w - total) / 2.0 + _hand_scroll
	var base_y := h - hs.y - 40.0
	var tilt := minf(5.0, 36.0 / maxf(float(n), 1.0))
	for i in n:
		var v: Control = hand_views[i]
		var placed: bool = v.has_meta("placed")
		if delay > 0.0 and placed:
			continue # keeps its current slot until the delayed layout runs
		# Fan position is relative to the screen centre, so scrolling rolls cards along the arc.
		var cx := x0 + step * float(i) + hs.x / 2.0
		var o := clampf((cx - w / 2.0) / step, -6.0, 6.0)
		v.size = hs
		v.pivot_offset = Vector2(hs.x / 2.0, hs.y * 1.6)
		var drop := minf(o * o * 2.2, 40.0) # bottom arc, capped so edge cards stay on screen
		var y := base_y + drop
		if v.lifted:
			y -= 30.0
		elif v.dimmed:
			y += 8.0
		var target := Vector2(x0 + step * float(i), y)
		var target_rot := deg_to_rad(o * tilt)
		v.set_meta("tp", target)
		v.set_meta("tr", target_rot)
		if not smooth or not placed:
			v.position = target
			v.rotation = target_rot
			v.set_meta("placed", true)
		v.z_index = i
	# Mouse picking follows scene-tree order (not z_index), so keep the tree order
	# equal to the visual stacking or clicks land on the card behind.
	var par: Node = hand_views[0].get_parent()
	if par != null:
		var lo := par.get_child_count()
		for hv in hand_views:
			if hv.get_parent() == par:
				lo = mini(lo, hv.get_index())
		for i in n:
			var hv: Control = hand_views[i]
			if hv.get_parent() == par:
				par.move_child(hv, lo + i)


# ---------------------------------------------------------------- game events

func _on_updated(events: Array) -> void:
	for e in events:
		var line := _describe(e)
		if line != "":
			_log.append(line)
	while _log.size() > 3:
		_log.pop_front()

	var st: Dictionary = game.state
	var first := not _dealt
	_dealt = true
	# A resumed game is already mid-play: show its state as it is instead of dealing it out again.
	var resumed := first and not _is_fresh_deal(st)
	if resumed:
		first = false
		var top: Dictionary = st["stack"][st["stack"].size() - 1]
		_floor_held = -1
		_set_floor(top, false)

	# Remember where hand cards were, to launch "played" flights from there.
	var old_rects := {}
	for v in hand_views:
		old_rects[v.card["id"]] = Rect2(v.position, v.size)

	# Cards that just arrived in our hand stay hidden until their flight lands.
	var new_ids: Array = []
	for c in _find(st, ME)["hand"]:
		if first or (not resumed and not old_rects.has(c["id"])):
			new_ids.append(c["id"])
			_hidden[c["id"]] = true

	# The new top card appears on the stack only when its flight lands.
	_floor_held = -1
	if first:
		_floor_held = st["stack"][st["stack"].size() - 1]["id"]
	for e in events:
		if e["type"] == "play" and not Rules.rule_of(e["card"]["rank"]).get("slideUnder", false):
			_floor_held = e["card"]["id"]

	# While the 3D hand reaches for a card, the rest of the hand stays put, then closes the gap smoothly.
	_hold_layout = 0.0
	if not first and _hand_ok():
		for e in events:
			if e["type"] == "play" and e["playerId"] == ME:
				_hold_layout = REACH

	var prev_req: Dictionary = _shown_required.duplicate()
	_queue_turn(events, first or resumed)
	_refresh()
	_tutorial_on_events(events)
	var human_turn_now: bool = game.is_human_turn()
	if human_turn_now and not _was_human_turn and not first:
		get_tree().create_timer(0.6).timeout.connect(func(): Sfx.play("turn", 0.6))
	_was_human_turn = human_turn_now

	if first:
		_animate_deal(st)
		return
	if not game.replay_mode: # a replay shows the stickers that were really sent
		_react_to_events(events)
	for e in events:
		match e["type"]:
			"play":
				_animate_play(e, old_rects, prev_req)
			"draw":
				_animate_draw(e["playerId"], int(e["count"]), new_ids, false)
			"penaltyTaken":
				_animate_draw(e["playerId"], int(e["count"]), new_ids, true)
			"skip":
				_flash_seat(e["playerId"])
				_stop_sign_later(e["playerId"])
			"combo":
				_combo_effect(e)
			"bonus":
				_bonus_effect(e)


# ---------------------------------------------------------------- turn indicator queue

## Rough time the animations for these events take; the longest one wins since they run together.
func _events_anim_time(events: Array) -> float:
	var t := 0.0
	for e in events:
		var d := 0.0
		match e["type"]:
			"play":
				d = FLY + 0.1 + (REACH if _hand_ok(e["playerId"] != ME) else 0.0)
				if Rules.rule_of(e["card"]["rank"]).get("slideUnder", false):
					d += 0.7 # lift, slide, settle
			"draw":
				if int(e["count"]) > 0:
					d = REACH + FLY + STAGGER * float(mini(int(e["count"]), 10))
			"penaltyTaken":
				d = REACH + FLY + STAGGER * float(mini(int(e["count"]), 10)) + 0.35 # + the red "+N cards"
			"skip":
				d = FLY + 0.35
			"combo":
				d = REACH + FLY + 0.3
		t = maxf(t, d)
	return t


## Registers a turn change. The shown player switches once everything queued before it, plus this
## move's own animations, is done. Safe for bursts of updates (e.g. over a network): changes apply in order.
func _queue_turn(events: Array, instant: bool) -> void:
	var cur: String = game.current_id()
	var now := Time.get_ticks_msec()
	if instant or game.bot_delay < 0.05 or game.replay_mode:
		_turn_queue.clear()
		_turn_serial += 1
		_shown_cur = cur
		_turn_gate_ms = now
		return
	var at := maxi(now, _turn_gate_ms) + int(_events_anim_time(events) * 1000.0)
	_turn_gate_ms = at
	if _turn_queue.is_empty() and at <= now:
		_shown_cur = cur
		return
	_turn_queue.append({"cur": cur, "at": at})
	var serial := _turn_serial
	get_tree().create_timer(maxf(0.0, float(at - now) / 1000.0)).timeout.connect(func(): _advance_turn(serial))


func _advance_turn(serial: int) -> void:
	if serial != _turn_serial or game == null or not is_inside_tree() or game.state.is_empty():
		return
	var now := Time.get_ticks_msec()
	var changed := false
	while not _turn_queue.is_empty() and int(_turn_queue[0]["at"]) <= now + 5:
		_shown_cur = _turn_queue.pop_front()["cur"]
		changed = true
	if changed:
		_update_seats(game.state)
		_update_banner(game.state, game.is_human_turn())
	if not _turn_queue.is_empty(): # woke up early (or the head isn't due yet): never leave entries stranded
		var wait := maxf(0.02, float(int(_turn_queue[0]["at"]) - Time.get_ticks_msec()) / 1000.0)
		get_tree().create_timer(wait).timeout.connect(func(): _advance_turn(serial))


func _who(id: String) -> String:
	return game.names.get(id, id)


func _card_text(card: Dictionary) -> String:
	if card["rank"] == "JOKER":
		return "%s Joker" % str(card["color"]).capitalize()
	return "%s of %s" % [card["rank"], CardArt.SUIT_NAMES[card["suit"]]]


func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n


func _describe(e: Dictionary) -> String:
	match e["type"]:
		"play":
			var t := "%s played %s" % [_who(e["playerId"]), _card_text(e["card"])]
			var cs := str(e.get("chosenSuit", ""))
			if cs != "":
				t += " and chose %s" % CardArt.SUIT_NAMES[cs]
			return t
		"draw":
			if int(e["count"]) == 0:
				return "%s passed (nothing left to draw)" % _who(e["playerId"])
			return "%s drew a card" % _who(e["playerId"])
		"penaltyTaken":
			return "%s took %d cards!" % [_who(e["playerId"]), int(e["count"])]
		"skip":
			return "%s skipped!" % _who(e["playerId"])
		"refill":
			return "The bank was refilled from the stack"
		"provisionalFinish":
			return "%s is out of cards (if no one blocks)" % _who(e["playerId"])
		"finish":
			return "%s is out!" % _who(e["playerId"])
		"finalTurn":
			return "%s has one last turn!" % _who(e["playerId"])
	return ""


# ---------------------------------------------------------------- animation

func _center(c: Control) -> Vector2:
	return c.position + c.size / 2.0


func _seat_center(id: String) -> Vector2:
	if id == ME:
		var hs := _hand_card_size()
		return Vector2(size.x / 2.0, size.y - hs.y / 2.0 - 30.0)
	return _center(opp_views[id])


## Flies a card from one place to another inside the fx layer. `flip` turns it face-up mid-flight.
func _fly(card: Dictionary, start_face_up: bool, flip: bool, from_c: Vector2, from_w: float,
		to_c: Vector2, to_w: float, delay: float, dur: float, on_land: Callable, trail: bool = false,
		early_show: bool = false) -> Control:
	var v := CardView.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_card(card, start_face_up)
	v.size = Vector2(to_w, to_w * CardView.BASE.y / CardView.BASE.x)
	v.pivot_offset = v.size / 2.0
	v.position = from_c - v.size / 2.0
	v.scale = Vector2.ONE * (from_w / to_w)
	v.visible = early_show # shown while the 3D hand is still reaching for it
	var streak: Line2D = null
	if trail and not Settings.reduce():
		streak = Line2D.new()
		streak.width = 22.0
		streak.begin_cap_mode = Line2D.LINE_CAP_ROUND
		streak.end_cap_mode = Line2D.LINE_CAP_ROUND
		var tg := Gradient.new()
		tg.set_color(0, Color(1, 1, 1, 0.0))
		tg.set_color(1, Color(1.0, 0.92, 0.6, 0.55))
		streak.gradient = tg
		fx.add_child(streak)
	fx.add_child(v)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func(): v.visible = true)
	tw.tween_property(v, "position", to_c - v.size / 2.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(v, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if flip:
		tw.parallel().tween_callback(func(): v.set_card(card, true)).set_delay(dur * 0.45)
	if streak != null:
		tw.parallel().tween_method(_extend_trail.bind(streak, from_c, to_c), 0.0, 1.0, dur)
	tw.tween_callback(func():
		if on_land.is_valid():
			on_land.call()
		v.queue_free()
		if streak != null:
			create_tween().tween_property(streak, "modulate:a", 0.0, 0.2)
			get_tree().create_timer(0.25).timeout.connect(streak.queue_free))
	return v


func _is_fresh_deal(st: Dictionary) -> bool:
	if (st["stack"] as Array).size() != 1:
		return false
	var hs := int(st["settings"]["handSize"])
	for p in st["players"]:
		if (p["hand"] as Array).size() != hs:
			return false
	return true


func _animate_deal(st: Dictionary) -> void:
	var bank_c := _center(bank_view)
	var bank_w := bank_view.size.x
	var hand_size := int(st["settings"]["handSize"])
	var idx := 0
	for r in hand_size:
		for p in st["players"]:
			var card: Dictionary = p["hand"][r]
			var delay := STAGGER * idx
			if p["id"] == ME:
				var hv := _hand_view(card["id"])
				if hv != null:
					var cid: int = card["id"]
					_fly(card, false, true, bank_c, bank_w, _center(hv), hv.size.x, delay, FLY, func():
						_unhide(cid)
						Sfx.play("deal", 0.45))
			else:
				_fly({}, false, false, bank_c, bank_w, _seat_center(p["id"]), 70.0, delay, FLY, func(): Sfx.play("deal", 0.3))
			idx += 1
	# Then the starting card is turned over onto the stack.
	var floor_card: Dictionary = st["stack"][st["stack"].size() - 1]
	var d := STAGGER * idx + 0.1
	_fly(floor_card, false, true, bank_c, bank_w, _center(stack_view), stack_view.size.x, d, FLY + 0.1, func():
		_floor_held = -1
		_set_floor(floor_card, false)
		_stack_note = "Starting card"
		_update_captions())
	_lock_until = Time.get_ticks_msec() + int((d + FLY + 0.2) * 1000.0)


func _animate_play(e: Dictionary, old_rects: Dictionary, prev_req: Dictionary) -> void:
	var who: String = e["playerId"]
	var card: Dictionary = e["card"]
	var slide: bool = Rules.rule_of(card["rank"]).get("slideUnder", false)
	var from_c: Vector2
	var from_w: float
	var face_up := true
	var flip := false
	if who == ME and old_rects.has(card["id"]):
		var r: Rect2 = old_rects[card["id"]]
		from_c = r.position + r.size / 2.0
		from_w = r.size.x
	else:
		from_c = _seat_center(who)
		from_w = 70.0
		face_up = false
		flip = true
	var to_c := _center(stack_view)
	var dir := 1.0 if from_c.y > to_c.y else -1.0 # 2s approach from the side they came from
	if slide:
		# Stop just outside the stack; the slide-under finishes the job.
		to_c += Vector2(0, dir * stack_view.size.y * 0.9)
		_sliding += 1
	var grab := (who == ME and old_rects.has(card["id"]) and _hand_ok(false)) or (who != ME and _hand_ok(true))
	var flight := _fly(card, face_up, flip, from_c, from_w, to_c, stack_view.size.x, REACH if grab else 0.0, FLY, func():
		_last_played[who] = card
		if slide:
			_stack_note = "%s slides a 2 under" % _who(who)
			_update_captions()
			_update_seats(game.state)
			var under := _slide_under(card, to_c, dir, func():
				_sliding -= 1
				_stack_note = "%s slid a 2 under" % _who(who)
				_update_peek()
				_update_captions()
				_update_seats(game.state))
			if grab:
				# The hand keeps hold and pushes the 2 under the lifted pile, leaving as the pile settles.
				hand3d.hand_over(under, SLIDE_UNDER_TIME)
		else:
			_floor_held = -1
			_set_floor(card, true)
			Sfx.play("play")
			_stack_note = "%s played" % _who(who)
			_update_captions()
			_update_seats(game.state)
			_impact(card, str(e.get("chosenSuit", "")), prev_req)
			_maybe_check_alert(who), true, grab)
	if grab:
		# A sliding 2 keeps the hand on it past the landing (hand_over takes it from there).
		hand3d.carry(flight, REACH, FLY + (6.0 if slide else 0.0), who != ME, _hand_style(who))


## The 3D hand is skipped when motion is reduced.
## Your hand uses the colour from settings; each bot gets the next ones along, so they all differ.
func _hand_style(who: String) -> int:
	return Hand3D.style_for(0 if who == ME else int(who.trim_prefix("bot")), Settings.hand_color)


func _hand_ok(bots: bool = false) -> bool:
	return hand3d != null and Settings.hands(bots)


## The pile lifts, the 2 slides in beneath it, and the pile settles back down.
func _slide_under(card: Dictionary, start_c: Vector2, dir: float, done: Callable) -> Control:
	Sfx.play("slide")
	var cs := stack_view.size
	var rest := stack_view.position
	var calm := Settings.reduce()
	var under := CardView.new()
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.set_card(card, true)
	under.size = cs
	under.position = start_c - cs / 2.0
	under.z_index = 3 # below the stack (z 5), above the table
	add_child(under)

	var tw := create_tween()
	# 1. Lift the pile (and tilt it a touch) to make room.
	tw.tween_property(stack_view, "position:y", rest.y - (0.0 if calm else 38.0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(stack_view, "scale", Vector2.ONE if calm else Vector2(1.06, 1.06), 0.16)
	tw.parallel().tween_property(stack_view, "rotation_degrees", 0.0 if calm else -2.5 * dir, 0.16)
	# 2. Slide the 2 in underneath.
	tw.tween_property(under, "position", rest + Vector2(-12, 12), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# 3. Lower the pile back down onto it.
	tw.tween_property(stack_view, "position:y", rest.y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(stack_view, "scale", Vector2.ONE, 0.18)
	tw.parallel().tween_property(stack_view, "rotation_degrees", 0.0, 0.18)
	tw.parallel().tween_property(under, "modulate:a", 0.0, 0.18).set_delay(0.08)
	tw.tween_callback(func():
		under.queue_free()
		if done.is_valid():
			done.call())
	return under


## The pile shows a little thickness: up to 3 cards peeking out from underneath.
func _update_peek() -> void:
	var st: Dictionary = game.state
	var depth: int = st["stack"].size() - 1 - _sliding - (1 if _floor_held != -1 else 0)
	stack_view.peek = clampi(depth, 0, 3)
	stack_view.queue_redraw()


func _animate_draw(who: String, count: int, new_ids: Array, is_penalty: bool) -> void:
	var bank_c := _center(bank_view)
	var bank_w := bank_view.size.x
	var bot := who != ME
	var n := mini(count, 10) if bot else new_ids.size()
	# A hand grabs the top card of the bank and carries it over; on a bigger draw (a penalty) it stays
	# at the destination and squeezes once for each further card as it lands.
	var grab := n > 0 and _hand_ok(bot)
	var lead := REACH if grab else 0.0
	var first: Control = null
	if not bot:
		var i := 0
		for id in new_ids:
			var hv := _hand_view(id)
			if hv == null:
				continue
			var cid: int = id
			var card: Dictionary = hv.card
			var flight := _fly(card, false, true, bank_c, bank_w, _center(hv), hv.size.x, lead + STAGGER * i, FLY, func():
				_unhide(cid)
				Sfx.play("draw", 0.7), false, grab and i == 0)
			if i == 0:
				first = flight
			i += 1
	else:
		for i in n:
			var flight := _fly({}, false, false, bank_c, bank_w, _seat_center(who), 70.0, lead + STAGGER * i, FLY, func(): Sfx.play("draw", 0.45), false, grab and i == 0)
			if i == 0:
				first = flight
	if grab and first != null:
		hand3d.carry(first, REACH, FLY + STAGGER * float(n - 1) + 0.05, bot, _hand_style(who))
		if n > 1:
			hand3d.pulse(n - 1, STAGGER, REACH + FLY)
	if is_penalty and count > 0:
		_penalty_effect(who, count, lead)


func _extend_trail(f: float, streak: Line2D, from_c: Vector2, to_c: Vector2) -> void:
	streak.add_point(from_c.lerp(to_c, 1.0 - pow(1.0 - f, 3.0)))
	if streak.get_point_count() > 12:
		streak.remove_point(0)


## Impact effects when a card lands on the stack.
func _impact(card: Dictionary, chosen: String, prev_req: Dictionary) -> void:
	var c := _center(stack_view)
	var rank: String = card["rank"]
	var sparks := Color(1.0, 0.45, 0.4) if card["color"] == "red" else Color(0.85, 0.9, 1.0)
	Fx.ring(fx, c, Color(1.0, 0.85, 0.3, 0.9), stack_view.size.x * 0.85, 0.5, 12.0)
	Fx.burst(fx, c, sparks, 14)
	var above := c + Vector2(0, -stack_view.size.y * 0.62)
	var pending := int(game.state["pending"])
	match rank:
		"7":
			Sfx.play("thump")
			Fx.ring(fx, c, Color(1.0, 0.25, 0.2, 0.9), stack_view.size.x * 1.2, 0.6, 14.0)
			Fx.popup_text(fx, "+%d" % pending, above, Color(1.0, 0.35, 0.3), 96)
		"JOKER":
			Sfx.play("roar")
			stack_view.anim_joker()
			Fx.ring(fx, c, Color(1.0, 0.25, 0.2, 0.9), stack_view.size.x * 1.5, 0.7, 18.0)
			Fx.burst(fx, c, Color(1.0, 0.8, 0.2), 26, 560.0)
			Fx.popup_text(fx, "JOKER! +%d" % pending, above, Color(1.0, 0.35, 0.3), 100)
			Fx.shake(self, 16.0, 0.45)
			Fx.flash(fx, Color(1.0, 0.1, 0.1), 0.22, 0.5)
		"J":
			if chosen != "":
				Fx.popup_text(fx, "%s!" % CardArt.SUIT_NAMES[chosen], above, Color(1.0, 0.85, 0.23), 84)
		_:
			# A rank match that switched the suit: say which suit is wanted now.
			if card["suit"] != "" and prev_req.get("kind", "") == "suit" and prev_req["suit"] != card["suit"]:
				Fx.popup_text(fx, "%s!" % CardArt.SUIT_NAMES[card["suit"]], above, Color(1.0, 0.85, 0.23), 72)


## Red "+N" and a flash for whoever just took a penalty (after the cards have flown in).
func _penalty_effect(who: String, count: int, lead: float = 0.0) -> void:
	await get_tree().create_timer(lead + FLY + STAGGER * float(mini(count, 10))).timeout
	if not is_inside_tree() or fx == null:
		return
	Sfx.play("penalty", 1.0 if who == ME else 0.6)
	var c := _seat_center(who)
	if who == ME:
		c.y -= 150.0
		Fx.flash(fx, Color(1.0, 0.1, 0.1), 0.3, 0.6)
		Fx.shake(self, 10.0, 0.3)
	else:
		_flash_seat(who)
	Fx.popup_text(fx, "+%d cards" % count, c, Color(1.0, 0.4, 0.35), 80)


## Feedback for the non-combo score bonuses (see the "bonus" events in offline_game.gd).
func _bonus_effect(e: Dictionary) -> void:
	var gold := Color(1.0, 0.85, 0.2)
	var pts := "+%d" % int(e["points"])
	match e["kind"]:
		"pass_on":
			# After the victim's cards have landed, a gold tag floats above their red "+N cards".
			var victim: String = e["victim"]
			await get_tree().create_timer(REACH + FLY + STAGGER * float(mini(int(e["pile"]), 10)) + 0.35).timeout
			if not is_inside_tree() or fx == null:
				return
			Sfx.play("bonus_pass")
			var c := _seat_center(victim)
			c.y += -260.0 if victim == ME else 135.0 # clear of their red "+N cards"
			Fx.burst(fx, c, gold, 18, 360.0, 0.6)
			Fx.popup_text(fx, "%s PASSED ON" % pts, c, gold, 60, 40.0, 1.5)
		"penalty_finish", "winning_card":
			await get_tree().create_timer(0.3).timeout
			if not is_inside_tree() or fx == null:
				return
			var c := Vector2(size.x * 0.30, size.y * 0.69) # same spot as the combo popups
			if e["kind"] == "penalty_finish":
				Sfx.play("bonus_out")
				Fx.flash(fx, Color(1.0, 0.97, 0.78), 0.3, 0.6)
				var what := "A 7" if e["rank"] == "7" else "A JOKER"
				_combo_labels.append(Fx.popup_text(fx, "%s WENT OUT ON %s" % [pts, what], c, gold, 52, 100.0, 1.6))
			else:
				c.y += 90.0
				Fx.burst(fx, c, gold, 20, 400.0, 0.6)
				_combo_labels.append(Fx.popup_text(fx, "%s FIRST OUT" % pts, c, Color(1.0, 0.95, 0.7), 56, 100.0, 1.6))


var _combo_labels: Array = [] # popups of the latest combo, replaced by the next one


## Score feedback for a chain of plays: a growing "COMBO xN" over the pile, and a full jackpot
## show when the fourth Ace lands. Waits for the card to land first.
func _combo_effect(e: Dictionary) -> void:
	await get_tree().create_timer(REACH + FLY).timeout
	if not is_inside_tree() or fx == null:
		return
	var n := int(e["len"])
	# Below the pile: clear of the suit announcement above it and the opponent's seat.
	var c := Vector2(size.x * 0.30, size.y * 0.69) # left of the 3D hand's arm
	for old in _combo_labels:
		if is_instance_valid(old):
			old.queue_free() # a new combo replaces the previous popup instead of overlapping it
	_combo_labels.clear()
	if bool(e["fresh"]):
		Sfx.play("jackpot")
		Fx.flash(fx, Color(1.0, 0.97, 0.78), 0.55, 0.9)
		Fx.shake(self, 18.0, 0.5)
		Fx.confetti(fx, size.x)
		Fx.burst(fx, _center(stack_view), Color(1.0, 0.85, 0.2), 40, 620.0, 0.9)
		c.y -= size.y * 0.06
		_combo_labels.append(Fx.popup_text(fx, "JACKPOT!", c, Color(1.0, 0.85, 0.2), 108, 140.0, 1.8))
		_combo_labels.append(Fx.popup_text(fx, "FOUR ACES", c + Vector2(0, 120), Color(1.0, 0.95, 0.7), 64, 100.0, 1.6))
	elif bool(e["jackpot"]) and n > 4:
		Sfx.play("combo_5")
		Fx.burst(fx, _center(stack_view), Color(1.0, 0.85, 0.2), 24, 480.0, 0.7)
		_combo_labels.append(Fx.popup_text(fx, "JACKPOT x%d" % n, c, Color(1.0, 0.85, 0.2), 80, 110.0, 1.4))
	else:
		Sfx.play("combo_%d" % clampi(n, 2, 5))
		var hue := clampf(float(n - 2) / 3.0, 0.0, 1.0)
		var col := Color(1.0, 0.9, 0.35).lerp(Color(1.0, 0.45, 0.2), hue)
		Fx.burst(fx, _center(stack_view), col, 8 + 4 * n, 300.0 + 40.0 * float(n), 0.5)
		_combo_labels.append(Fx.popup_text(fx, "COMBO x%d" % n, c, col, 64 + 12 * mini(n, 5), 100.0, 1.2))


func _stop_sign_later(id: String) -> void:
	await get_tree().create_timer(FLY + 0.05).timeout
	if not is_inside_tree() or fx == null:
		return
	var c := _seat_center(id)
	if id == ME:
		c.y -= 170.0
	Sfx.play("stop")
	Fx.stop_sign(fx, c)


## "Check": a player is down to exactly one card.
func _in_check(p: Dictionary) -> bool:
	return p["status"] == "playing" and p["hand"].size() == 1


## Keeps your own badge in sync and re-arms the alert for anyone who is no longer in check.
func _update_check_state(st: Dictionary) -> void:
	for p in st["players"]:
		if not _in_check(p):
			_alerted.erase(p["id"])
	you_avatar.check = _in_check(_find(st, ME)) and not st["over"]


## The one-time announcement, fired when the card that left a player on one card has landed.
## Calm on purpose: a soft edge vignette, one ring and one short line of text. No shake, no flash.
func _maybe_check_alert(who: String) -> void:
	var p := _find(game.state, who)
	if p.is_empty() or not _in_check(p) or _alerted.has(who) or game.state["over"]:
		return
	_alerted[who] = true
	var now := Time.get_ticks_msec()
	var repeat: bool = now - int(_last_alert_ms.get(who, -100000)) < 10000
	_last_alert_ms[who] = now
	Sfx.play("check") # the chime plays even on a quick re-fire
	_bot_react("saw_check", "", 1.0, who)

	var c := _seat_center(who)
	if who == ME:
		c.y -= 100.0
	Fx.ring(fx, c, Color(1.0, 0.3, 0.25, 0.9), 200.0, 0.6, 10.0)
	if repeat:
		return # a quick re-fire only gets the ring; the seat badge already says it

	Fx.vignette(fx, Color(1.0, 0.12, 0.1), 0.28, 0.7)
	# Show the text in the empty band between the table and your hand, clear of the cards.
	var band_top := message_label.position.y + message_label.size.y
	var y := (band_top + banner_label.position.y) / 2.0 - 20.0
	var who_text := "You have" if who == ME else "%s has" % _who(who)
	Fx.popup_text(fx, "CHECK!", Vector2(size.x / 2.0, y), Color(1.0, 0.32, 0.27), 100, 24.0, 1.1)
	Fx.popup_text(fx, "%s ONE card left!" % who_text, Vector2(size.x / 2.0, y + 72.0), Color.WHITE, 40, 14.0, 1.1)


func _flash_seat(id: String) -> void:
	if id == ME:
		banner_label.text = "You are skipped!"
		return
	if Settings.reduce():
		return
	var v: Control = opp_views[id]
	v.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(v, "modulate", Color.WHITE, 0.9)


func _hand_view(card_id: int) -> Control:
	for v in hand_views:
		if v.card["id"] == card_id:
			return v
	return null


func _unhide(card_id: int) -> void:
	_hidden.erase(card_id)
	var v := _hand_view(card_id)
	if v != null:
		v.modulate.a = 1.0


func _set_floor(card: Dictionary, pop: bool) -> void:
	stack_view.set_card(card, true)
	stack_view.visible = true
	_last_floor_id = card["id"]
	if card["id"] != _lights_card_id:
		suit_lights.hide_lights() # a new card covers the one that had the lights
	_update_peek()
	if pop and not Settings.reduce():
		stack_view.scale = Vector2(1.14, 1.14)
		create_tween().tween_property(stack_view, "scale", Vector2.ONE, 0.2)


# ---------------------------------------------------------------- refresh

func _update_captions() -> void:
	stack_caption.text = _stack_note
	var mine: Dictionary = _last_played.get(ME, {})
	you_last.visible = not mine.is_empty()
	if not mine.is_empty():
		you_last.set_card(mine, true)
		you_last.set_flags(false, mine["id"] == _last_floor_id)
		you_caption.text = "Your last" if mine["id"] != _last_floor_id else "On top"
	else:
		you_caption.text = ""


func _update_seats(st: Dictionary) -> void:
	var cur_id: String = _shown_cur if _shown_cur != "" else game.current_id()
	var pts: Dictionary = game.live_points()
	var best := 0
	for id in pts:
		best = maxi(best, int(pts[id]))
	var my_pts := int(pts.get(ME, 0))
	you_points.text = "%d pts" % my_pts
	you_points.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if (best > 0 and my_pts == best) else Color(1, 1, 1, 0.85))
	for p in st["players"]:
		if p["id"] == ME:
			continue
		opp_views[p["id"]].points = int(pts.get(p["id"], 0))
		opp_views[p["id"]].leading = best > 0 and int(pts.get(p["id"], 0)) == best
		var v: Control = opp_views[p["id"]]
		var status := ""
		if p["status"] == "finished":
			status = "Out" if p["hand"].is_empty() else "Lost"
		elif p["status"] == "provisional":
			status = "Last card played!"
		var last: Dictionary = _last_played.get(p["id"], {})
		var on_top: bool = not last.is_empty() and last["id"] == _last_floor_id
		v.update_info(_who(p["id"]), p["hand"].size(), (cur_id == p["id"]) and not st["over"], status, last, on_top, _in_check(p) and not st["over"])
	_update_captions()
	_update_check_state(st)


func _refresh() -> void:
	var st: Dictionary = game.state
	var human_turn: bool = game.is_human_turn()
	_update_seats(st)
	_update_peek()
	you_avatar.active = human_turn

	var floor_card: Dictionary = st["stack"][st["stack"].size() - 1]
	if floor_card["id"] != _last_floor_id and floor_card["id"] != _floor_held:
		_set_floor(floor_card, _last_floor_id != -1)

	var pending := int(st["pending"])
	bank_view.set_flags(false, human_turn, ("+%d" % pending) if pending > 0 else "")
	if human_turn and pending > 0:
		bank_caption.text = "Tap to take %d" % pending
	elif human_turn:
		bank_caption.text = "Tap to draw 1"
	else:
		bank_caption.text = "Bank: %d" % st["bank"].size()
	required_view.set_required(st["required"])
	if _shown_required != st["required"]:
		if not _shown_required.is_empty() and not Settings.reduce():
			required_view.scale = Vector2(1.25, 1.25)
			create_tween().tween_property(required_view, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# Suit change: sparks + ring in the suit's colour around the spinning 3D suit.
			# A different suit is now wanted: show it big, like a collectible.
			if st["required"]["kind"] == "suit" and (_shown_required.get("kind", "") != "suit" or _shown_required["suit"] != st["required"]["suit"]):
				# Wait for the card that caused it to reach and land on the pile first.
				var cause_id: int = st["stack"][st["stack"].size() - 1]["id"]
				SuitReveal.new().start(fx, st["required"]["suit"], REACH + FLY + 0.45, stack_view, func():
					# Only if that card is still on top (nobody has covered it during the delay).
					if _last_floor_id == cause_id:
						_lights_card_id = cause_id
						suit_lights.show_on(stack_view, SuitReveal.DUR)) # ends with the suit animation
			if st["required"]["kind"] != "free":
				var fx_col: Color = Color(1.0, 0.82, 0.2)
				if st["required"]["kind"] == "suit":
					fx_col = CardArt.suit_color(st["required"]["suit"]).lerp(Color.WHITE, 0.35)
				var fx_c: Vector2 = required_view.position + required_view.size * Vector2(0.62, 0.5)
				Fx.ring(self, fx_c, fx_col, 90.0, 0.55, 8.0)
				Fx.burst(self, fx_c, fx_col, 14, 300.0, 0.5)
		_shown_required = (st["required"] as Dictionary).duplicate()

	message_label.text = "\n".join(_log.slice(maxi(_log.size() - 2, 0)))
	_rebuild_hand(st, human_turn)
	_update_banner(st, human_turn)
	var can_react: bool = Settings.show_reactions and not st["over"] and not game.replay_mode and tutorial == null
	react_menu.visible = can_react
	if not can_react:
		react_menu.close()
	if st["over"] and not _shown_over:
		_shown_over = true
		if game.replay_mode:
			_flash("Game over")
		elif tutorial == null: # a tutorial chapter ends with Rex's wrap-up instead of the results screen
			_show_over(st)


## Cards glide to their slots instead of snapping when the hand changes or is swiped.
func _process(delta: float) -> void:
	_watch_human_turn()
	_tutorial_tick()
	if _replay_playing:
		_replay_accum += delta * float(REPLAY_SPEEDS[_replay_speed])
		if _replay_accum >= REPLAY_STEP:
			_replay_accum = 0.0
			_replay_step()
			if game.replay_cursor >= game.replay_count():
				_replay_playing = false
			_replay_update()
	var k := 1.0 - exp(-delta * 14.0)
	for v in hand_views:
		if not v.has_meta("tp"):
			continue
		var tp: Vector2 = v.get_meta("tp")
		var tr: float = v.get_meta("tr")
		v.position = v.position.lerp(tp, k)
		v.rotation = lerp_angle(v.rotation, tr, k)
		if v.position.distance_squared_to(tp) < 0.04:
			v.position = tp
			v.rotation = tr


# ---------------------------------------------------------------- reactions

## Where a seat's sticker appears: the free top-right corner of an opponent's seat (so their
## avatar and name stay readable), or just above-right of your avatar.
func _reaction_anchor(who: String) -> Vector2:
	if who == ME:
		return you_avatar.position + you_avatar.size / 2.0 + Vector2(78.0, -78.0)
	var v: Control = opp_views[who]
	return v.position + Vector2(v.size.x - 64.0, 38.0)


## Shows a reaction sticker for a seat. Returns false when it is ignored (unknown id or the
## seat is still cooling down). Online play will call this for reactions received from others.
func show_reaction(who: String, id: String) -> bool:
	if fx == null or not Reactions.is_valid(id) or (who != ME and not opp_views.has(who)):
		return false
	var now := Time.get_ticks_msec()
	if now - int(_react_last_ms.get(who, -100000)) < int(Reactions.COOLDOWN * 1000.0):
		return false
	_react_last_ms[who] = now
	if not game.replay_mode:
		game.record_reaction(who, id)
	var old = _react_bubbles.get(who)
	if old != null and is_instance_valid(old):
		old.queue_free()
	var c := _reaction_anchor(who)
	_react_bubbles[who] = ReactionBubble.spawn(fx, id, c, 62.0 if who == ME else 52.0)
	Sfx.play(str(Reactions.info(id)["sound"]), 0.85 if who == ME else 0.6)
	return true


func _on_react_picked(id: String) -> void:
	if not show_reaction(ME, id):
		return
	react_menu.start_cooldown(Reactions.COOLDOWN)
	# Now and then a bot answers.
	var reply := Reactions.bot_reply(id, _react_rng)
	var who := _random_bot("")
	if reply != "" and who != "":
		_bot_say(reply, who, 0.9)


func _random_bot(exclude: String) -> String:
	var ids: Array = []
	for id in opp_views:
		if id != exclude:
			ids.append(id)
	if ids.is_empty():
		return ""
	return ids[_react_rng.randi() % ids.size()]


## A bot reacts to `situation` (see Reactions.SITUATIONS) if it feels like it. `bot_id` "" picks
## any bot except `exclude`.
func _bot_react(situation: String, bot_id: String = "", delay: float = 0.8, exclude: String = "") -> void:
	if not Settings.show_reactions:
		return
	var who := bot_id if bot_id != "" else _random_bot(exclude)
	if who == "" or not opp_views.has(who):
		return
	_bot_say(Reactions.bot_pick(situation, who, _react_rng), who, delay)


func _bot_say(id: String, bot_id: String, delay: float) -> void:
	if id == "" or not Settings.show_reactions:
		return
	var epoch := _react_epoch
	await get_tree().create_timer(delay + _react_rng.randf() * 0.5).timeout
	if epoch != _react_epoch or not is_inside_tree() or over_panel != null or not Settings.show_reactions:
		return
	var now := Time.get_ticks_msec()
	if now - _last_bot_say_ms < BOT_SAY_GAP_MS:
		return
	if show_reaction(bot_id, id):
		_last_bot_say_ms = now


## Bots comment on what just happened. Timings leave room for the cards to land first.
func _react_to_events(events: Array) -> void:
	if tutorial != null:
		return # Rex is busy teaching: no stickers
	for e in events:
		match e["type"]:
			"penaltyTaken":
				if e["playerId"] == ME:
					_bot_react("human_penalty", "", 1.5)
				else:
					_bot_react("took_penalty", e["playerId"], 1.5)
			"play":
				var rank: String = e["card"]["rank"]
				if rank == "7" or rank == "JOKER":
					if e["playerId"] != ME:
						_bot_react("big_play", e["playerId"], 0.8)
					var victim: String = game.current_id()
					if victim != e["playerId"] and victim != ME and not game.state["over"]:
						_bot_react("hit_by_attack", victim, 1.3)
			"skip":
				if e["playerId"] != ME:
					_bot_react("hit_by_attack", e["playerId"], 1.0)
			"finish":
				if e["playerId"] == ME:
					_bot_react("human_out", "", 1.0)
				else:
					_bot_react("went_out", e["playerId"], 0.9)


## When it has been your turn for a long time, a bot politely tells you to hurry up.
func _watch_human_turn() -> void:
	if game == null or game.state.is_empty() or not _dealt or tutorial != null:
		return
	var mine: bool = game.is_human_turn()
	var now := Time.get_ticks_msec()
	if mine != _react_human_turn:
		_react_human_turn = mine
		_react_turn_ms = now
		_hurried = false
	elif mine and not _hurried and over_panel == null and not picker.visible and now - _react_turn_ms > HURRY_AFTER_MS:
		_hurried = true
		_bot_react("slow_human", "", 0.0)



func _rebuild_hand(st: Dictionary, human_turn: bool) -> void:
	# Keep the views of cards that are still in hand so they can glide to their new slots.
	var old := {}
	for v in hand_views:
		old[v.card["id"]] = v
	hand_views.clear()
	var me: Dictionary = _find(st, ME)
	var legal := {}
	if human_turn:
		for a in CardEngine.legal_actions(st, ME):
			if a["type"] == "play":
				legal[a["cardId"]] = true
	var cards: Array = (me["hand"] as Array).duplicate()
	cards.sort_custom(_card_less)
	for c in cards:
		var v: Control = old.get(c["id"])
		var ok: bool = legal.has(c["id"])
		if v != null:
			old.erase(c["id"])
		else:
			v = CardView.new()
			v.set_card(c, true)
			v.pressed.connect(_on_card_pressed)
			v.dragged.connect(_on_hand_dragged)
			if _hidden.has(c["id"]):
				v.modulate.a = 0.0
			add_child(v)
		v.set_flags(human_turn and not ok, human_turn and ok)
		hand_views.append(v)
	for gone in old.values(): # the played card: its flight node takes over from here
		gone.queue_free()
	_layout_hand(true, _hold_layout)
	_hold_layout = 0.0


func _card_less(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = SUIT_ORDER[a["suit"]]
	var sb: int = SUIT_ORDER[b["suit"]]
	if sa != sb:
		return sa < sb
	return RANK_ORDER.find(a["rank"]) < RANK_ORDER.find(b["rank"])


func _find(st: Dictionary, id: String) -> Dictionary:
	for p in st["players"]:
		if p["id"] == id:
			return p
	return {}


func _update_banner(st: Dictionary, human_turn: bool) -> void:
	if st["over"]:
		banner_label.text = ""
		return
	var me: Dictionary = _find(st, ME)
	if me["status"] == "finished":
		banner_label.text = "You're out! Watching the rest..."
	elif human_turn:
		if int(st["pending"]) > 0:
			banner_label.text = "Block with a 7 or Joker, or take %d cards" % int(st["pending"])
		elif bool(st.get("finalTurn", false)):
			banner_label.text = "LAST CHANCE! Play your last card or you lose"
		elif me["hand"].is_empty():
			banner_label.text = "No cards left - draw from the bank"
		elif _in_check(me):
			var last_rule: Dictionary = Rules.rule_of(me["hand"][0]["rank"])
			var stop_blocked: bool = bool(last_rule.get("cannotFinishWhenTwoPlayersLeft", false)) \
					and CardEngine._unfinished_count(st) <= 2
			if stop_blocked:
				banner_label.text = "A Stop can't take you out - play it, then draw"
			else:
				banner_label.text = "CHECK! Play your last card to go out"
		else:
			banner_label.text = "Your turn"
	elif game.replay_mode:
		banner_label.text = "%s to move" % _who(game.current_id())
	else:
		banner_label.text = "%s is thinking..." % _who(_shown_cur if _shown_cur != "" else game.current_id())


# ---------------------------------------------------------------- input

func _locked() -> bool:
	# Test mode (instant bots) never locks.
	return game.bot_delay >= 0.05 and Time.get_ticks_msec() < _lock_until


func _flash(text: String) -> void:
	_flash_serial += 1
	var mine := _flash_serial
	message_label.text = text
	await get_tree().create_timer(1.6).timeout
	if mine == _flash_serial and game != null:
		message_label.text = "\n".join(_log.slice(maxi(_log.size() - 2, 0)))


## Slim track under the hand plus edge chevrons, shown only when cards are off-screen.
func _draw_hand_bar() -> void:
	if _hand_max_scroll <= 0.5 or hand_views.is_empty():
		return
	var w := size.x
	var h := size.y
	var track_w := 180.0
	var track := Rect2((w - track_w) / 2.0, h - 22.0, track_w, 8.0)
	hand_bar.draw_rect(track, Color(1, 1, 1, 0.22))
	var thumb_w := maxf(track_w * _hand_visible_frac, 30.0)
	# Positive scroll = fan moved right = earlier (left) cards revealed.
	var t := 0.5 - _hand_scroll / (2.0 * _hand_max_scroll)
	var thumb := Rect2(track.position.x + (track_w - thumb_w) * t, track.position.y, thumb_w, track.size.y)
	hand_bar.draw_rect(thumb, Color(1.0, 0.82, 0.25, 0.95))

	# Chevrons at the screen edges where more cards are hidden.
	var cy := h - _hand_card_size().y * 0.55
	var col := Color(1, 1, 1, 0.75)
	if _hand_scroll < _hand_max_scroll - 1.0: # more cards to the left
		hand_bar.draw_colored_polygon(PackedVector2Array([Vector2(26, cy), Vector2(48, cy - 24), Vector2(48, cy + 24)]), col)
	if _hand_scroll > -_hand_max_scroll + 1.0: # more cards to the right
		hand_bar.draw_colored_polygon(PackedVector2Array([Vector2(w - 26, cy), Vector2(w - 48, cy - 24), Vector2(w - 48, cy + 24)]), col)


func _on_hand_dragged(dx: float) -> void:
	_hand_scroll += dx
	_layout_hand(true)


func _on_card_pressed(card_id: int) -> void:
	if picker.visible or not game.is_human_turn() or _locked() or _tutorial_waiting():
		return
	var st: Dictionary = game.state
	var can := false
	for a in CardEngine.legal_actions(st, ME):
		if a["type"] == "play" and a["cardId"] == card_id:
			can = true
			break
	if not can:
		Sfx.play("nope", 0.8)
		if int(st["pending"]) > 0:
			_flash("Only a 7 or a Joker can block a penalty")
		else:
			_flash("You can't play that card now")
		return
	var card: Dictionary = {}
	for c in _find(st, ME)["hand"]:
		if c["id"] == card_id:
			card = c
	if tutorial != null and not tutorial.wants_card(Cards.card_code(card)):
		Sfx.play("nope", 0.8)
		coach.nudge(_tutorial_nudge())
		return
	if Rules.rule_of(card["rank"]).get("sets", "") == "chosen":
		_pending_j = card_id
		picker.visible = true
		return
	game.human_play(card_id)


func _on_suit_chosen(suit: String) -> void:
	if tutorial != null and _pending_j >= 0:
		var pending_card: Dictionary = {}
		for c in _find(game.state, ME)["hand"]:
			if c["id"] == _pending_j:
				pending_card = c
		if pending_card.is_empty() or not tutorial.matches("play", Cards.card_code(pending_card), suit):
			Sfx.play("nope", 0.8)
			coach.nudge(_tutorial_nudge()) # the picker stays open
			return
	picker.visible = false
	if _pending_j >= 0:
		game.human_play(_pending_j, suit)
	_pending_j = -1


func _on_bank_pressed(_id: int) -> void:
	if picker.visible or _locked() or _tutorial_waiting():
		return
	if not game.is_human_turn():
		_flash("Wait for your turn")
		return
	if tutorial != null and not tutorial.matches("takePenalty" if int(game.state["pending"]) > 0 else "draw"):
		Sfx.play("nope", 0.8)
		coach.nudge(_tutorial_nudge())
		return
	if int(game.state["pending"]) > 0:
		game.human_take_penalty()
	else:
		game.human_draw()


# ---------------------------------------------------------------- tutorial

## True while a tutorial is running but Rex has no step up for the player to act on (yet): input is ignored.
func _tutorial_waiting() -> bool:
	return tutorial != null and (coach == null or not coach.active)


func _tutorial_nudge() -> String:
	var s := tutorial.step()
	if s.is_empty():
		return ""
	if not tutorial.expects_action():
		return "Tap Next to keep going."
	if picker.visible and str(s["picker_nudge"]) != "":
		return str(s["picker_nudge"])
	return str(s["nudge"]) if str(s["nudge"]) != "" else "Follow my lead!"


## Nothing is flying, sliding or queued: the board is at rest, so Rex can talk without covering an animation.
func _settled() -> bool:
	return not _locked() and _turn_queue.is_empty() and _sliding == 0 and _hidden.is_empty() and _floor_held == -1


## The player's own action moves the lesson on.
func _tutorial_on_events(events: Array) -> void:
	if tutorial == null or coach == null:
		return
	for e in events:
		if str(e.get("playerId", "")) != ME:
			continue
		var done := false
		match e["type"]:
			"play": done = tutorial.matches("play", Cards.card_code(e["card"]), str(e.get("chosenSuit", "")))
			"draw": done = tutorial.matches("draw")
			"penaltyTaken": done = tutorial.matches("takePenalty")
		if done:
			tutorial.advance()
			coach.hide_step()


func _on_coach_next() -> void:
	if tutorial == null or not coach.active or tutorial.expects_action():
		return
	tutorial.advance()
	coach.hide_step()


## Where Rex's spotlight goes for a step target (see game/tutorial.gd), in Table coordinates.
func _tutorial_target(key: String) -> Rect2:
	match key:
		"pile": return Rect2(stack_view.position, stack_view.size)
		"bank": return Rect2(bank_view.position, bank_view.size)
		"required": return Rect2(required_view.position, required_view.size)
		"rex": return Rect2(opp_views[Tutorial.REX].position, opp_views[Tutorial.REX].size)
	if key.begins_with("card:"):
		for v in hand_views:
			if Cards.card_code(v.card) == key.substr(5):
				return _bounds(v)
	return Rect2()


## The on-screen box of a control, including its rotation (hand cards are fanned).
func _bounds(c: Control) -> Rect2:
	var xf := c.get_global_transform()
	var pts := [xf * Vector2.ZERO, xf * Vector2(c.size.x, 0.0), xf * c.size, xf * Vector2(0.0, c.size.y)]
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return Rect2(r.position - global_position, r.size)


## Once per frame: show the next step when the board is at rest and it is your turn, keep the spotlight on its
## target, and wrap the chapter up when the last step is done.
func _tutorial_tick() -> void:
	if tutorial == null or coach == null or game == null or game.state.is_empty() or not _dealt or coach.outro_visible():
		return
	banner_label.visible = not coach.active # Rex says it better, and the arrow would sit on top of it
	if coach.active:
		var s := tutorial.step()
		if s.is_empty():
			return
		var key := str(s["target"])
		if picker.visible and tutorial.expects_action() and (s["expect"] as Dictionary).has("suit"):
			coach.set_say(str(s["picker_say"]))
			var b: Control = picker_buttons[str((s["expect"] as Dictionary)["suit"])]
			coach.target = Rect2(b.get_global_rect().position - global_position, b.size)
		else:
			coach.set_say(str(s["say"]))
			coach.target = _tutorial_target(key)
		return
	if not _settled():
		return
	var st: Dictionary = game.state
	var my_turn: bool = game.is_human_turn() and _shown_cur == ME
	if tutorial.done():
		if (my_turn or st["over"]) and not _outro_shown:
			_tutorial_finish()
	elif my_turn:
		var step := tutorial.step()
		coach.show_step(str(step["say"]), step["expect"] == null)


func _tutorial_finish() -> void:
	_outro_shown = true
	game.stop() # Rex stops moving: the chapter is over
	Settings.mark_tutorial_done(str(tutorial.chapter["id"]))
	coach.show_outro("Chapter %d done!" % (tutorial.chapter_index + 1), str(tutorial.chapter["outro"]),
		"Play a real game" if tutorial.is_last_chapter() else "Next chapter")


# ---------------------------------------------------------------- game over

func _show_over(st: Dictionary) -> void:
	# Let the last card land before the results cover the table.
	await get_tree().create_timer(0.0 if game.bot_delay < 0.05 else 0.9).timeout
	if game == null or not is_inside_tree():
		return
	over_panel = Control.new()
	over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_panel.z_index = 2000
	over_panel.add_child(UI.background())
	var my_place := int(_find(st, ME)["place"])
	var i_got_out: bool = _find(st, ME)["hand"].is_empty()
	var title := "You lost" # left holding cards: lost outright, points don't matter
	if i_got_out:
		if my_place == 1:
			title = "It's a draw!" if game.is_draw else "You win!"
		else:
			title = "You finished %s" % _ordinal(my_place)
	var page := UI.scroll_page(title, "", Callable())
	over_panel.add_child(page["scroll"])
	over_panel.add_child(page["header"])
	over_panel.add_child(page["footer"])
	var box: VBoxContainer = page["content"]

	var result := Scoring.compute(my_place, st["players"].size(), bots, difficulty, game.human_draws, game.human_chains, game.human_finish_rank, game.human_penalty_chains, game.human_first_out, i_got_out)
	var rank := Leaderboard.add(int(result["total"]), my_place, st["players"].size(), difficulty, bool(result["clean"]))

	var pod := Podium.new()
	pod.custom_minimum_size = Vector2(minf(size.x * 0.94, 1040.0), minf(620.0, size.y * 0.32))
	var scores := {}
	for p in st["players"]:
		var s: Dictionary = game.stats[p["id"]]
		scores[p["id"]] = int(Scoring.compute(int(p["place"]), st["players"].size(), bots, difficulty, int(s["draws"]), s["chains"],
				str(s["finish_rank"]), s["penalty_chains"], bool(s["first_out"]), p["hand"].is_empty())["total"])
	pod.setup(st["finishedOrder"], game.names, ME, scores)
	pod.first_landed.connect(func():
		Sfx.play("win" if (my_place == 1 and i_got_out) else "lose")
		if my_place == 1 and i_got_out:
			Fx.confetti(over_panel, size.x))
	pod.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(pod)

	box.add_child(_score_panel(result, rank))
	var footer_box: VBoxContainer = page["footer_box"]
	for b in [UI.button("Play again", UI.Variant.PRIMARY, func(): start(bots, difficulty)),
			UI.button("Menu", UI.Variant.SECONDARY, func(): quit_to_menu.emit())]:
		var c := CenterContainer.new()
		c.add_child(b)
		footer_box.add_child(c)
	add_child(over_panel)
	pod.play()


## Score breakdown card shown under the podium on the results screen.
func _score_panel(result: Dictionary, rank: int) -> Control:
	var card := UI.panel(UI.SPACE_S)
	card[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL   # fills the page content width
	var inner: VBoxContainer = card[1]
	for line in result["lines"]:
		var row := HBoxContainer.new()
		var name_l := UI.body(str(line[0]), 0.0, UI.FONT_HINT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name_l)
		row.add_child(UI.body("+%d" % int(line[1]), 0.0, UI.FONT_HINT))
		inner.add_child(row)
	if not is_equal_approx(float(result["mult"]), 1.0):
		inner.add_child(UI.hint("x%s for %d opponents, %s" % [str(snappedf(float(result["mult"]), 0.01)), bots, difficulty]))
	inner.add_child(UI.title("%d pts" % int(result["total"]), UI.FONT_H1))
	var note := ""
	if bool(result["clean"]):
		note = "Clean finish!"
	if rank == 1:
		note = (note + " " if note != "" else "") + "New #1 on the leaderboard"
	elif rank > 0:
		note = (note + " " if note != "" else "") + "Leaderboard rank #%d" % rank
	if note != "":
		inner.add_child(UI.heading(note))
	return card[0]


func _open_settings() -> void:
	var p := SettingsPanel.new()
	p.closed.connect(p.queue_free)
	add_child(p)
