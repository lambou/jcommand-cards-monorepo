extends Control
## Playground for the opening deal. Nothing here touches the game: run it with
##   godot --path apps/mobile -- --dealplay
## Pick a style, how many players and how many cards each, then press Deal. Three ways to deal:
##   Flying cards  - what the table does today: every card flies from the bank at once, round-robin.
##   Dealer hand   - the last bot (the dealer) reaches in from the top, stays by the bank and flicks one card at a time to each seat.
##   Packets       - each player in turn gets their whole hand in one quick burst.
## Tweak the speed, flight time and slow motion, then tell me which one feels right. The winner moves into
## the table (see Table._animate_deal); the dealer glove is Hand3D.deal_step / deal_end.

const CardView := preload("res://scripts/ui/card_view.gd")
const CardFlip := preload("res://scripts/ui/card_flip.gd")
const Hand3D := preload("res://scripts/ui/hand3d.gd")
const Settings := preload("res://scripts/game/settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const DealPlan := preload("res://scripts/game/deal_plan.gd")

const PILE_PER_LAYER := 8
const MODES := Settings.DEAL_STYLES

var mode := Settings.deal_style # DealPlan.FLY / DEALER / PACKETS
var players := 3 # you + bots
var hand_size := 7
var sec_per_card := 0.3 # the pace; each style turns it into its own rhythm
var fly_time := 0.55
var reduce_on := false

var bg: TableBg
var bank: CardView
var stack: CardView
var bank_caption: Label
var stack_caption: Label
var fx: Control
var hand3d: Control
var row: Control
var bar: VBoxContainer
var status: Label
var mode_buttons: Array = []

var deck: Array = []
var hand: Array = [] # your CardViews, all slots laid out from the start, each shown as its card lands
var seat_views: Array = [] # bots' face-down stacks (index 0 = first bot)
var seat_labels: Array = []
var seat_counts: Array = [] # bots' cards so far
var _busy := false
var _gen := 0 # bumped by Reset / Deal so a run in progress stops
var _shown_remaining := 0
var _rng := RandomNumberGenerator.new()
var _t0 := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.load_settings()
	if Sfx.instance == null:
		add_child(Sfx.new())
	_rng.randomize()

	bg = TableBg.new()
	bg.style = Settings.table_style % TableBg.STYLES.size()
	add_child(bg)

	bank = CardView.new()
	bank.set_card({}, false)
	bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bank)
	bank_caption = _label(32, Color(1, 1, 1, 0.9))
	stack = CardView.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	stack_caption = _label(32, Color(1, 1, 1, 0.9))

	row = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	fx = Control.new()
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


func _button(text: String, cb: Callable, h: float = 88.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(cb)
	return b


func _slider(text: String, lo: float, hi: float, step: float, v: float, fmt: String, cb: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(330, 0)
	l.add_theme_font_size_override("font_size", 28)
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 54)
	var val := Label.new()
	val.custom_minimum_size = Vector2(100, 0)
	val.add_theme_font_size_override("font_size", 28)
	val.text = fmt % v
	hb.add_child(s)
	hb.add_child(val)
	s.value_changed.connect(func(x: float):
		val.text = fmt % x
		cb.call(x))
	return hb


func _build_bar() -> void:
	bar = VBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	status = _label(28, Color(1, 1, 1, 0.75))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	for i in MODES.size():
		var b := _button(MODES[i], func(): _set_mode(i))
		b.toggle_mode = true
		modes.add_child(b)
		mode_buttons.append(b)
	bar.add_child(modes)
	_set_mode(mode)
	bar.add_child(_slider("Players (you + bots)", 2, 4, 1, players, "%d", func(x): players = int(x); reset()))
	bar.add_child(_slider("Cards each", 3, 10, 1, hand_size, "%d", func(x): hand_size = int(x); reset()))
	bar.add_child(_slider("Seconds per card", 0.1, 0.7, 0.01, sec_per_card, "%.2f", func(x): sec_per_card = x))
	bar.add_child(_slider("Flight time (s)", CardFlip.min_duration(), 1.2, 0.01, fly_time, "%.2f", func(x): fly_time = x))
	bar.add_child(_slider("Slow motion", 0.1, 1.0, 0.01, 1.0, "%.2f", func(x): Engine.time_scale = x))
	var checks := CheckButton.new()
	checks.text = "Reduce motion (no glove, no spin)"
	checks.custom_minimum_size = Vector2(0, 70)
	checks.add_theme_font_size_override("font_size", 28)
	checks.toggled.connect(func(on): reduce_on = on)
	bar.add_child(checks)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button("Deal", deal, 100.0))
	buttons.add_child(_button("Reset", reset, 100.0))
	bar.add_child(buttons)


func _set_mode(i: int) -> void:
	mode = i
	for k in mode_buttons.size():
		mode_buttons[k].button_pressed = (k == i)


# ---------------------------------------------------------------- layout

func _relayout() -> void:
	if bank == null:
		return
	var w := size.x
	var h := size.y
	bar.size = Vector2(w - 60.0, 0.0)
	bar.position = Vector2(30.0, h - bar.get_combined_minimum_size().y - 24.0)
	status.size = Vector2(w, 40.0)
	status.position = Vector2(0.0, bar.position.y - 44.0)
	var bw := minf(220.0, w * 0.21)
	bank.size = Vector2(bw, bw * CardView.BASE.y / CardView.BASE.x)
	stack.size = bank.size
	var mid_y := h * 0.33
	bank.position = Vector2(w * 0.38 - bw / 2.0, mid_y - bank.size.y / 2.0)
	stack.position = Vector2(w * 0.62 - bw / 2.0, mid_y - bank.size.y / 2.0)
	bank_caption.size = Vector2(bw + 160.0, 44.0)
	bank_caption.position = Vector2(bank.position.x - 80.0, bank.position.y + bank.size.y + 30.0)
	stack_caption.size = bank_caption.size
	stack_caption.position = Vector2(stack.position.x - 80.0, stack.position.y + stack.size.y + 8.0)
	_layout_seats()
	_layout_row()
	bank.queue_redraw()


func _bot_count() -> int:
	return players - 1


func _seat_center(i: int) -> Vector2: # a bot's stack
	return Vector2(size.x * float(i + 1) / float(_bot_count() + 1), size.y * 0.115)


func _seat_size() -> Vector2:
	return Vector2(120.0, 120.0 * CardView.BASE.y / CardView.BASE.x)


func _layout_seats() -> void:
	for i in seat_views.size():
		var v: CardView = seat_views[i]
		v.size = _seat_size()
		v.position = _seat_center(i) - v.size / 2.0
		var l: Label = seat_labels[i]
		l.size = Vector2(300.0, 40.0)
		l.position = Vector2(_seat_center(i).x - 150.0, v.position.y + v.size.y + 6.0)


func _hand_size_px() -> Vector2:
	var cw := minf(170.0, size.x * 0.17)
	return Vector2(cw, cw * CardView.BASE.y / CardView.BASE.x)


func _slot_center(i: int) -> Vector2:
	var hs := _hand_size_px()
	var n := maxi(hand_size, 2)
	var step := minf(hs.x * 0.72, (size.x - 80.0 - hs.x) / float(n - 1))
	var span := step * float(n - 1)
	return Vector2(size.x / 2.0 - span / 2.0 + step * float(i), bar.position.y - hs.y / 2.0 - 80.0)


func _layout_row() -> void:
	var hs := _hand_size_px()
	for i in hand.size():
		var v: CardView = hand[i]
		v.size = hs
		v.z_index = i
		v.position = _slot_center(i) - hs / 2.0


func _bank_c() -> Vector2:
	return bank.position + bank.size / 2.0


# ---------------------------------------------------------------- state

func reset() -> void:
	_gen += 1
	_busy = false
	if hand3d != null:
		hand3d.deal_end()
	for c in fx.get_children():
		c.queue_free()
	for v in hand:
		v.queue_free()
	hand.clear()
	for v in seat_views:
		v.queue_free()
	for l in seat_labels:
		l.queue_free()
	seat_views.clear()
	seat_labels.clear()
	seat_counts.clear()
	for i in _bot_count():
		var v := CardView.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_card({}, false)
		v.peek = 0
		v.visible = false
		add_child(v)
		seat_views.append(v)
		seat_counts.append(0)
		seat_labels.append(_label(28, Color(1, 1, 1, 0.85)))
		_update_seat(i)
	for i in hand_size:
		var hv := CardView.new()
		hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hv.visible = false
		row.add_child(hv)
		hand.append(hv)
	deck.clear()
	var id := 0
	for s in ["S", "H", "D", "C"]:
		for r in ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]:
			deck.append({"id": id, "rank": r, "suit": s})
			id += 1
	deck.append({"id": id, "rank": "JOKER", "color": "red"})
	deck.append({"id": id + 1, "rank": "JOKER", "color": "black"})
	for i in range(deck.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	_shown_remaining = deck.size()
	stack.visible = false
	stack_caption.text = ""
	status.text = "%d players, %d cards each (%d cards dealt)" % [players, hand_size, players * hand_size]
	_update_bank()
	_relayout()


func _update_bank() -> void:
	bank.peek = clampi(ceili(float(_shown_remaining) / PILE_PER_LAYER) - 1, 0, 3)
	bank.visible = _shown_remaining > 0
	bank.queue_redraw()
	bank_caption.text = "Bank: %d" % _shown_remaining


func _update_seat(i: int) -> void:
	var n: int = seat_counts[i]
	seat_views[i].visible = n > 0
	seat_views[i].peek = clampi(ceili(float(n) / 3.0) - 1, 0, 3)
	seat_views[i].queue_redraw()
	seat_labels[i].text = "Bot %d: %d" % [i + 1, n]


func _lift_from_bank() -> void:
	_shown_remaining = maxi(_shown_remaining - 1, 0)
	_update_bank()
	if not reduce_on:
		bank.pivot_offset = bank.size / 2.0
		var bump := create_tween()
		bump.tween_property(bank, "scale", Vector2.ONE * 1.05, 0.06)
		bump.tween_property(bank, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- the deal

## A face-down card sitting on the bank, ready to be sent.
func _flyer(to_w: float) -> Control:
	var v := CardView.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_card({}, false)
	v.size = Vector2(to_w, to_w * CardView.BASE.y / CardView.BASE.x)
	v.pivot_offset = v.size / 2.0
	v.position = _bank_c() - v.size / 2.0
	v.scale = Vector2.ONE * (bank.size.x / to_w)
	fx.add_child(v)
	return v


## Sends `v` from the bank to seat `seat` (slot `slot` of your row for seat 0).
func _send(v: Control, seat: int, slot: int, card: Dictionary) -> void:
	_lift_from_bank()
	Sfx.play("draw", 0.4)
	var from_scale := bank.size.x / v.size.x
	if seat == 0:
		var to_c := _slot_center(slot)
		var dur := maxf(fly_time, CardFlip.min_duration())
		CardFlip.run(self, v, card, dur, from_scale, _bank_c(), to_c, reduce_on)
		_land_later(v, dur, func():
			hand[slot].set_card(card, true)
			hand[slot].visible = true
			Sfx.play("deal", 0.45))
	else:
		var i := seat - 1
		var to_c := _seat_center(i)
		var dur := fly_time * 0.8
		var tw := v.create_tween().set_parallel(true)
		tw.tween_property(v, "position", to_c - v.size / 2.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "scale", _seat_size() / v.size, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if not reduce_on: # a little flick as it leaves the hand
			var spin := _rng.randf_range(-0.35, 0.35)
			tw.tween_method(func(t: float): v.rotation = spin * sin(t * PI), 0.0, 1.0, dur)
		_land_later(v, dur, func():
			seat_counts[i] += 1
			_update_seat(i)
			Sfx.play("deal", 0.3))


func _land_later(v: Control, dur: float, on_land: Callable) -> void:
	var gen := _gen
	await get_tree().create_timer(dur).timeout
	if gen == _gen:
		on_land.call()
	if is_instance_valid(v):
		v.queue_free()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


## Carries out the same plan the table does (game/deal_plan.gd): seat 0 is you, the last seat deals.
func deal() -> void:
	reset()
	_busy = true
	_t0 = Time.get_ticks_msec()
	var gen := _gen
	var glove := mode == DealPlan.DEALER and not reduce_on
	var seats: Array = range(players)
	var dealer: int = DealPlan.dealer_of(seats, 0)
	var plan := DealPlan.build(mode, DealPlan.turn_order(seats, 0), hand_size, glove, sec_per_card, sec_per_card * 0.3)
	var style := Hand3D.style_for(dealer, Settings.hand_color)
	var origin_x := _seat_center(dealer - 1).x
	var now := 0.0
	var taken := {} # seat -> cards sent so far (the slot in your row)
	for step in plan["steps"]:
		var seat: int = step["seat"]
		var slot := int(taken.get(seat, 0))
		taken[seat] = slot + 1
		var card: Dictionary = deck.pop_back() if seat == 0 else {}
		var v := _flyer(_hand_size_px().x if seat == 0 else _seat_size().x)
		if glove:
			now = await _at(now, float(step["grab"]), gen)
			if gen != _gen:
				return
			var to_x := _slot_center(slot).x if seat == 0 else _seat_center(seat - 1).x
			# The hand's own throw sends the card, so the fingers and the card never drift apart.
			hand3d.deal_step(v, float(step["send"]) - float(step["grab"]), plan["flick"], true, style, origin_x,
					clampf((to_x - _bank_c().x) / (size.x * 0.35), -1.0, 1.0), func(): _send(v, seat, slot, card))
			now = await _at(now, float(step["send"]), gen)
		else:
			now = await _at(now, float(step["send"]), gen)
			if gen != _gen:
				return
			_send(v, seat, slot, card)
		if gen != _gen:
			return
	# The starting card is turned over onto the stack.
	var start: Dictionary = deck.pop_back()
	var sv := _flyer(bank.size.x)
	var sg := float(plan["start"]["grab"])
	var ss := float(plan["start"]["send"])
	var dur := maxf(fly_time, CardFlip.min_duration())
	var launch_start := func():
		_lift_from_bank()
		Sfx.play("draw", 0.4)
		CardFlip.run(self, sv, start, dur, 1.0, _bank_c(), stack.position + stack.size / 2.0, reduce_on)
		_land_later(sv, dur, func():
			stack.set_card(start, true)
			stack.visible = true
			stack_caption.text = "Starting card"
			Sfx.play("deal", 0.45))
	if glove:
		now = await _at(now, sg, gen)
		if gen != _gen:
			return
		hand3d.deal_step(sv, ss - sg, plan["flick"], true, style, origin_x,
				clampf((stack.position.x + stack.size.x / 2.0 - _bank_c().x) / (size.x * 0.35), -1.0, 1.0), launch_start)
		now = await _at(now, ss, gen)
	else:
		now = await _at(now, ss, gen)
		if gen != _gen:
			return
		launch_start.call()
	if glove:
		now = await _at(now, float(plan["release"]), gen)
		if gen != _gen:
			return
		hand3d.deal_end()
	await _wait(dur)
	if gen != _gen:
		return
	_busy = false
	status.text = "Dealt %d cards in %.1f s" % [players * hand_size + 1, float(Time.get_ticks_msec() - _t0) / 1000.0 / maxf(Engine.time_scale, 0.01)]


## Waits until plan time `t` (the plan clock is `now`) and returns the new clock.
func _at(now: float, t: float, gen: int) -> float:
	if t > now:
		await _wait(t - now)
	return maxf(now, t)


# ---------------------------------------------------------------- screenshots

## `--dealshot=<file.png>` [--dealmode=N] [--players=N] [--cards=N]: <file>_00.. frames of one deal, 0.35 s apart.
func capture(path: String) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dealmode="):
			_set_mode(int(a.substr(11)))
		elif a.begins_with("--players="):
			players = int(a.substr(10))
		elif a.begins_with("--cards="):
			hand_size = int(a.substr(8))
	await get_tree().create_timer(0.4).timeout
	deal()
	var base := path.get_basename()
	for i in 14:
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%02d.png" % [base, i])
	get_tree().quit()
