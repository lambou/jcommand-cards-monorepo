extends Control
## Playground for the "take a real card off the bank and flip it" draw. Nothing here touches the game:
## run it with   godot --path apps/mobile -- --flipplay
## Tap the bank (or Draw 1 / Draw 3): the top card is lifted off the pile, turned over in the air and lands
## in your row. Tweak the glove, reduce motion, flight time and slow motion, then tell me what feels right.
## The flip itself lives in card_flip.gd, which is what the table will call once this is approved.

const CardView := preload("res://scripts/ui/card_view.gd")
const CardFlip := preload("res://scripts/ui/card_flip.gd")
const Hand3D := preload("res://scripts/ui/hand3d.gd")
const Settings := preload("res://scripts/game/settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

const REACH := 0.3 # same as the table: how long the glove takes to reach the card
const STAGGER := 0.09
const PILE_PER_LAYER := 8 # cards in the bank per visible layer of thickness

var fly_time := 0.55
var glove_on := true
var reduce_on := false

var bg: TableBg
var bank: CardView
var bank_caption: Label
var fx: Control
var hand3d: Control
var row: Control
var bar: VBoxContainer
var status: Label

var deck: Array = []
var hand: Array = [] # CardViews in your row (some hidden while their flyer is in the air)
var _busy := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.load_settings()
	if Sfx.instance == null: # run on its own (F6) there is no Main to provide the sounds
		add_child(Sfx.new())
	_rng.randomize()

	bg = TableBg.new()
	bg.style = Settings.table_style % TableBg.STYLES.size()
	add_child(bg)

	bank = CardView.new()
	bank.set_card({}, false)
	bank.pressed.connect(func(_id): draw_cards(1))
	add_child(bank)
	bank_caption = _label(34, Color(1, 1, 1, 0.9))

	row = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	fx = Control.new() # flying cards, above the row
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.z_index = 1000
	add_child(fx)

	hand3d = Hand3D.new()
	hand3d.z_index = 1001
	add_child(hand3d)

	_build_bar()
	resized.connect(_relayout)
	reset()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- UI

func _label(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(cb)
	return b


func _check(text: String, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.custom_minimum_size = Vector2(0, 80)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_font_size_override("font_size", 32)
	c.toggled.connect(cb)
	return c


func _slider(text: String, lo: float, hi: float, v: float, cb: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("font_size", 30)
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 60)
	var val := Label.new()
	val.custom_minimum_size = Vector2(110, 0)
	val.add_theme_font_size_override("font_size", 30)
	val.text = "%.2f" % v
	hb.add_child(s)
	hb.add_child(val)
	s.value_changed.connect(func(x: float):
		val.text = "%.2f" % x
		cb.call(x))
	return hb


func _build_bar() -> void:
	bar = VBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	status = _label(28, Color(1, 1, 1, 0.7))
	bar.add_child(_slider("Flight time (s)", CardFlip.min_duration(), 1.2, fly_time, func(x): fly_time = x))
	bar.add_child(_slider("Slow motion", 0.1, 1.0, 1.0, func(x): Engine.time_scale = x))
	var checks := HBoxContainer.new()
	checks.add_child(_check("3D glove", glove_on, func(on): glove_on = on))
	checks.add_child(_check("Reduce motion", reduce_on, func(on): reduce_on = on))
	bar.add_child(checks)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button("Draw 1", func(): draw_cards(1)))
	buttons.add_child(_button("Draw 3", func(): draw_cards(3)))
	buttons.add_child(_button("Reset", reset))
	bar.add_child(buttons)


func _relayout() -> void:
	if bank == null:
		return
	var w := size.x
	var h := size.y
	var bw := minf(250.0, w * 0.24)
	bank.size = Vector2(bw, bw * CardView.BASE.y / CardView.BASE.x)
	bank.position = Vector2(w / 2.0 - bank.size.x / 2.0, h * 0.18)
	bank_caption.size = Vector2(bw + 160.0, 44.0)
	bank_caption.position = Vector2(bank.position.x - 80.0, bank.position.y + bank.size.y + 40.0)
	bar.size = Vector2(w - 60.0, 0.0)
	bar.position = Vector2(30.0, h - bar.get_combined_minimum_size().y - 30.0)
	status.size = Vector2(w, 40.0)
	status.position = Vector2(0.0, bar.position.y - 46.0)
	_layout_row()
	bank.queue_redraw()


func _hand_size() -> Vector2:
	var cw := minf(190.0, size.x * 0.18)
	return Vector2(cw, cw * CardView.BASE.y / CardView.BASE.x)


func _slot_center(i: int, n: int) -> Vector2:
	var hs := _hand_size()
	var step := minf(hs.x * 0.72, (size.x - 80.0 - hs.x) / maxf(float(n - 1), 1.0))
	var span := step * float(n - 1)
	var y := bar.position.y - hs.y / 2.0 - 90.0
	return Vector2(size.x / 2.0 - span / 2.0 + step * float(i), y)


## Puts the row's cards in their slots. With `animate`, cards from `from_index` on are placed at once (they
## are hidden under their flyer) and the earlier ones slide aside to make room.
func _layout_row(animate: bool = false, from_index: int = 0) -> void:
	var hs := _hand_size()
	for i in hand.size():
		var v: CardView = hand[i]
		v.size = hs
		v.z_index = i
		var to := _slot_center(i, hand.size()) - hs / 2.0
		if animate and i < from_index:
			create_tween().tween_property(v, "position", to, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			v.position = to


# ---------------------------------------------------------------- the draw

func reset() -> void:
	for c in fx.get_children():
		c.queue_free()
	for v in hand:
		v.queue_free()
	hand.clear()
	deck.clear()
	var id := 0
	for s in ["S", "H", "D", "C"]:
		for r in ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]:
			deck.append({"id": id, "rank": r, "suit": s})
			id += 1
	deck.append({"id": id, "rank": "JOKER", "color": "red"})
	deck.append({"id": id + 1, "rank": "JOKER", "color": "black"})
	# Fisher-Yates with our own rng so Reset reshuffles.
	for i in range(deck.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	_busy = false
	_shown_remaining = deck.size()
	_update_bank()
	_relayout()


func _update_bank() -> void:
	bank.peek = clampi(ceili(float(deck.size()) / PILE_PER_LAYER) - 1, 0, 3)
	bank.visible = not deck.is_empty()
	bank.queue_redraw()
	bank_caption.text = "Bank: %d" % deck.size() if not deck.is_empty() else "Bank empty - Reset"


## Takes the real top card(s) off the bank and flies them, flipping, into the row.
func draw_cards(count: int) -> void:
	var n := mini(count, deck.size())
	if _busy or n <= 0:
		return
	_busy = true
	var grab := glove_on and not reduce_on
	var lead := REACH if grab else 0.0
	var hs := _hand_size()
	var from_c := bank.position + bank.size / 2.0
	var from_scale := bank.size.x / hs.x

	var cards: Array = []
	for i in n:
		cards.append(deck.pop_back())
	var first_slot := hand.size()
	for i in n: # reserve each card's slot in the row; hidden until its flyer lands
		var hv := CardView.new()
		hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hv.set_card(cards[i], true)
		hv.visible = false
		row.add_child(hv)
		hand.append(hv)
	_layout_row(true, first_slot)

	var first: Control = null
	for i in n:
		var card: Dictionary = cards[i]
		var hv: CardView = hand[first_slot + i]
		var to_c := _slot_center(first_slot + i, hand.size())
		var v := CardView.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_card(card, false)
		v.size = hs
		v.pivot_offset = hs / 2.0
		v.position = from_c - hs / 2.0
		v.scale = Vector2.ONE * from_scale
		v.visible = grab and i == 0 # the glove is still reaching for the first one
		fx.add_child(v)
		if i == 0:
			first = v
		var delay := lead + STAGGER * float(i)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			v.visible = true
			_lift_from_bank()
			Sfx.play("draw", 0.7)
			# One tween does the peel, the travel and the right-handed turn.
			CardFlip.run(self, v, card, fly_time, from_scale, from_c, to_c, reduce_on))
		tw.tween_interval(fly_time)
		tw.tween_callback(func():
			hv.visible = true
			v.queue_free()
			if i == n - 1:
				_busy = false)
	if grab:
		# One hand animation per draw, however many cards: it carries (and turns over) the first card, stays
		# out of the way while the rest land, then lets go. No grip pulses - they read as the fingers blinking.
		hand3d.carry(first, REACH, fly_time + STAGGER * float(n - 1) + 0.05, false, Settings.hand_color)
	status.text = "Drew %d" % n
	_shown_remaining = deck.size() + n


## The pile shrinks one card at a time, as each card is actually lifted off it.
var _shown_remaining := 0


func _lift_from_bank() -> void:
	_shown_remaining = maxi(_shown_remaining - 1, 0)
	bank.peek = clampi(ceili(float(_shown_remaining) / PILE_PER_LAYER) - 1, 0, 3)
	bank.visible = _shown_remaining > 0
	bank.queue_redraw()
	if not reduce_on: # the next card rises a little as the top one leaves, and the count pulses
		bank.pivot_offset = bank.size / 2.0
		var bump := create_tween()
		bump.tween_property(bank, "scale", Vector2.ONE * 1.06, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		bump.tween_property(bank, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bank_caption.pivot_offset = bank_caption.size / 2.0
		var pulse := create_tween()
		pulse.tween_property(bank_caption, "scale", Vector2.ONE * 1.25, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		pulse.parallel().tween_property(bank_caption, "modulate", Color(1.0, 0.85, 0.3), 0.12)
		pulse.tween_property(bank_caption, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse.parallel().tween_property(bank_caption, "modulate", Color.WHITE, 0.4)
	bank_caption.text = "Bank: %d" % _shown_remaining if _shown_remaining > 0 else "Bank empty - Reset"


# ---------------------------------------------------------------- screenshots

## `--flipshot=<file.png>`: a frame sequence of one draw in slow motion, saved as <file>_<n>.png.
func capture(path: String) -> void:
	# Run with `--fixed-fps 60` so each frame is exactly 1/60 s of game time: frames are then evenly spaced.
	await get_tree().create_timer(0.5).timeout
	draw_cards(1)
	var base := path.get_basename()
	for _i in 22: # skip the glove's reach: the peel starts at about 0.3 s
		await get_tree().process_frame
	for i in 32:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%02d.png" % [base, i])
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit()
