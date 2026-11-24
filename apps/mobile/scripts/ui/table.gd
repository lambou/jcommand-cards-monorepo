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
const Avatar := preload("res://scripts/ui/avatar.gd")
const AvatarView := preload("res://scripts/ui/avatar_view.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Podium := preload("res://scripts/ui/podium.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const Settings := preload("res://scripts/game/settings.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

signal quit_to_menu

const ME := "you"
const SUIT_ORDER := {"H": 0, "D": 1, "C": 2, "S": 3, "": 4}
const RANK_ORDER := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "LION"]
const FLY := 0.42 # seconds for a card to travel
const STAGGER := 0.07 # delay between cards of one batch

var game: Node
var bots := 2
var difficulty := "normal"

var bg: ColorRect
var menu_button: Button
var settings_button: Button
var opp_views: Dictionary = {}
var hand_views: Array = []
var bank_view: Control
var stack_view: Control
var required_view: Control
var you_last: Control
var you_avatar: Control
var bank_caption: Label
var stack_caption: Label
var you_caption: Label
var message_label: Label
var banner_label: Label
var fx: Control
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_relayout)


func start(p_bots: int, p_difficulty: String) -> void:
	bots = p_bots
	difficulty = p_difficulty
	_build()
	game.bot_delay = 1.15
	game.start(bots, difficulty)


# ---------------------------------------------------------------- build

func _build() -> void:
	for c in get_children():
		c.queue_free()
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
	_stack_note = ""
	_sliding = 0
	_shown_required = {}
	_alerted.clear()
	_last_alert_ms.clear()
	_was_human_turn = false
	_pending_j = -1
	over_panel = null

	bg = ColorRect.new()
	bg.color = Color(0.07, 0.33, 0.21)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	you_last = CardView.new()
	you_last.mouse_filter = Control.MOUSE_FILTER_IGNORE
	you_last.visible = false
	add_child(you_last)

	you_avatar = AvatarView.new(0)
	add_child(you_avatar)

	required_view = RequiredView.new()
	add_child(required_view)

	bank_caption = _label(30, Color(1, 1, 1, 0.85))
	stack_caption = _label(30, Color(1.0, 0.85, 0.3))
	you_caption = _label(26, Color(1, 1, 1, 0.7))
	message_label = _label(40, Color(1, 1, 1))
	banner_label = _label(44, Color(1.0, 0.85, 0.3))

	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.add_theme_font_size_override("font_size", 32)
	menu_button.custom_minimum_size = Vector2(150, 64)
	menu_button.pressed.connect(func(): game.stop(); quit_to_menu.emit())
	add_child(menu_button)

	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.add_theme_font_size_override("font_size", 32)
	settings_button.custom_minimum_size = Vector2(190, 64)
	settings_button.pressed.connect(_open_settings)
	add_child(settings_button)

	fx = Control.new() # flying cards live here, above the hand
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.z_index = 1000
	add_child(fx)

	hand_bar = Control.new() # scroll indicator for an overflowing hand
	hand_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_bar.z_index = 500
	hand_bar.draw.connect(_draw_hand_bar)
	add_child(hand_bar)

	_build_picker()
	_relayout()


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.1, 0.08))
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
	settings_button.position = Vector2(184, 14)

	# Opponents.
	var n := opp_views.size()
	var gap := 20.0
	var ow := minf(380.0, (w - 40.0 - gap * float(maxi(n - 1, 0))) / float(maxi(n, 1)))
	var oh := minf(230.0, h * 0.125)
	var total := ow * n + gap * float(maxi(n - 1, 0))
	var x := (w - total) / 2.0
	var oy := 92.0
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
	_layout_hand()


func _layout_hand() -> void:
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
		# Fan position is relative to the screen centre, so scrolling rolls cards along the arc.
		var cx := x0 + step * float(i) + hs.x / 2.0
		var o := clampf((cx - w / 2.0) / step, -6.0, 6.0)
		v.size = hs
		v.pivot_offset = Vector2(hs.x / 2.0, hs.y * 1.6)
		v.rotation_degrees = o * tilt
		var drop := minf(o * o * 2.2, 40.0) # bottom arc, capped so edge cards stay on screen
		var y := base_y + drop
		if v.lifted:
			y -= 30.0
		elif v.dimmed:
			y += 8.0
		v.position = Vector2(x0 + step * float(i), y)
		v.z_index = i


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

	# Remember where hand cards were, to launch "played" flights from there.
	var old_rects := {}
	for v in hand_views:
		old_rects[v.card["id"]] = Rect2(v.position, v.size)

	# Cards that just arrived in our hand stay hidden until their flight lands.
	var new_ids: Array = []
	for c in _find(st, ME)["hand"]:
		if first or not old_rects.has(c["id"]):
			new_ids.append(c["id"])
			_hidden[c["id"]] = true

	# The new top card appears on the stack only when its flight lands.
	_floor_held = -1
	if first:
		_floor_held = st["stack"][st["stack"].size() - 1]["id"]
	for e in events:
		if e["type"] == "play" and not Rules.rule_of(e["card"]["rank"]).get("slideUnder", false):
			_floor_held = e["card"]["id"]

	var prev_req: Dictionary = _shown_required.duplicate()
	_refresh()
	var human_turn_now: bool = game.is_human_turn()
	if human_turn_now and not _was_human_turn and not first:
		get_tree().create_timer(0.6).timeout.connect(func(): Sfx.play("turn", 0.6))
	_was_human_turn = human_turn_now

	if first:
		_animate_deal(st)
		return
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


func _who(id: String) -> String:
	return game.names.get(id, id)


func _card_text(card: Dictionary) -> String:
	if card["rank"] == "LION":
		return "%s Lion" % str(card["color"]).capitalize()
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
			return "%s finished %s!" % [_who(e["playerId"]), _ordinal(int(e["place"]))]
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
		to_c: Vector2, to_w: float, delay: float, dur: float, on_land: Callable, trail: bool = false) -> void:
	var v := CardView.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_card(card, start_face_up)
	v.size = Vector2(to_w, to_w * CardView.BASE.y / CardView.BASE.x)
	v.pivot_offset = v.size / 2.0
	v.position = from_c - v.size / 2.0
	v.scale = Vector2.ONE * (from_w / to_w)
	v.visible = false
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
	_fly(card, face_up, flip, from_c, from_w, to_c, stack_view.size.x, 0.0, FLY, func():
		_last_played[who] = card
		if slide:
			_stack_note = "%s slides a 2 under" % _who(who)
			_update_captions()
			_update_seats(game.state)
			_slide_under(card, to_c, dir, func():
				_sliding -= 1
				_stack_note = "%s slid a 2 under" % _who(who)
				_update_peek()
				_update_captions()
				_update_seats(game.state))
		else:
			_floor_held = -1
			_set_floor(card, true)
			Sfx.play("play")
			_stack_note = "%s played" % _who(who)
			_update_captions()
			_update_seats(game.state)
			_impact(card, str(e.get("chosenSuit", "")), prev_req)
			_maybe_check_alert(who), true)


## The pile lifts, the 2 slides in beneath it, and the pile settles back down.
func _slide_under(card: Dictionary, start_c: Vector2, dir: float, done: Callable) -> void:
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


## The pile shows a little thickness: up to 3 cards peeking out from underneath.
func _update_peek() -> void:
	var st: Dictionary = game.state
	var depth: int = st["stack"].size() - 1 - _sliding - (1 if _floor_held != -1 else 0)
	stack_view.peek = clampi(depth, 0, 3)
	stack_view.queue_redraw()


func _animate_draw(who: String, count: int, new_ids: Array, is_penalty: bool) -> void:
	var bank_c := _center(bank_view)
	var bank_w := bank_view.size.x
	if who == ME:
		var i := 0
		for id in new_ids:
			var hv := _hand_view(id)
			if hv == null:
				continue
			var cid: int = id
			var card: Dictionary = hv.card
			_fly(card, false, true, bank_c, bank_w, _center(hv), hv.size.x, STAGGER * i, FLY, func():
				_unhide(cid)
				Sfx.play("draw", 0.7))
			i += 1
	else:
		var n := mini(count, 10)
		for i in n:
			_fly({}, false, false, bank_c, bank_w, _seat_center(who), 70.0, STAGGER * i, FLY, func(): Sfx.play("draw", 0.45))
	if is_penalty and count > 0:
		_penalty_effect(who, count)


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
		"LION":
			Sfx.play("roar")
			Fx.ring(fx, c, Color(1.0, 0.25, 0.2, 0.9), stack_view.size.x * 1.5, 0.7, 18.0)
			Fx.burst(fx, c, Color(1.0, 0.8, 0.2), 26, 560.0)
			Fx.popup_text(fx, "LION! +%d" % pending, above, Color(1.0, 0.35, 0.3), 100)
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
func _penalty_effect(who: String, count: int) -> void:
	await get_tree().create_timer(FLY + STAGGER * float(mini(count, 10))).timeout
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
	var cur_id: String = game.current_id()
	for p in st["players"]:
		if p["id"] == ME:
			continue
		var v: Control = opp_views[p["id"]]
		var status := ""
		if p["status"] == "finished":
			status = "Out - %s" % _ordinal(int(p["place"]))
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
	if st["over"] and not _shown_over:
		_shown_over = true
		_show_over(st)


func _rebuild_hand(st: Dictionary, human_turn: bool) -> void:
	for v in hand_views:
		v.queue_free()
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
		var v := CardView.new()
		v.set_card(c, true)
		var ok: bool = legal.has(c["id"])
		v.set_flags(human_turn and not ok, human_turn and ok)
		v.pressed.connect(_on_card_pressed)
		v.dragged.connect(_on_hand_dragged)
		if _hidden.has(c["id"]):
			v.modulate.a = 0.0
		add_child(v)
		hand_views.append(v)
	_layout_hand()


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
			banner_label.text = "Block with a 7 or Lion, or take %d cards" % int(st["pending"])
		elif _in_check(me):
			banner_label.text = "CHECK! Play your last card to win"
		else:
			banner_label.text = "Your turn"
	else:
		banner_label.text = "%s is thinking..." % _who(game.current_id())


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
	_layout_hand()


func _on_card_pressed(card_id: int) -> void:
	if picker.visible or not game.is_human_turn() or _locked():
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
			_flash("Only a 7 or a Lion can block a penalty")
		else:
			_flash("You can't play that card now")
		return
	var card: Dictionary = {}
	for c in _find(st, ME)["hand"]:
		if c["id"] == card_id:
			card = c
	if Rules.rule_of(card["rank"]).get("sets", "") == "chosen":
		_pending_j = card_id
		picker.visible = true
		return
	game.human_play(card_id)


func _on_suit_chosen(suit: String) -> void:
	picker.visible = false
	if _pending_j >= 0:
		game.human_play(_pending_j, suit)
	_pending_j = -1


func _on_bank_pressed(_id: int) -> void:
	if picker.visible or _locked():
		return
	if not game.is_human_turn():
		_flash("Wait for your turn")
		return
	if int(game.state["pending"]) > 0:
		game.human_take_penalty()
	else:
		game.human_draw()


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
	var box := UI.column(26)
	over_panel.add_child(box)

	var my_place := int(_find(st, ME)["place"])
	box.add_child(UI.title("You win!" if my_place == 1 else "You finished %s" % _ordinal(my_place)))

	var pod := Podium.new()
	pod.custom_minimum_size = Vector2(minf(size.x * 0.94, 1040.0), minf(760.0, size.y * 0.42))
	pod.setup(st["finishedOrder"], game.names, ME)
	pod.first_landed.connect(func():
		Sfx.play("win" if my_place == 1 else "lose")
		if my_place == 1:
			Fx.confetti(over_panel, size.x))
	box.add_child(pod)

	box.add_child(UI.button("Play again", UI.Variant.PRIMARY, func(): start(bots, difficulty)))
	box.add_child(UI.button("Menu", UI.Variant.SECONDARY, func(): quit_to_menu.emit()))
	add_child(over_panel)
	pod.play()


func _open_settings() -> void:
	var p := SettingsPanel.new()
	p.closed.connect(p.queue_free)
	add_child(p)
