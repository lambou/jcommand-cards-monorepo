extends Control
## Rex's coaching overlay for the tutorial: dims the table except for one spotlighted spot (with a pulsing
## ring and a bobbing arrow), and shows Rex talking in a speech bubble. It never blocks the table: all the
## input rules live in Table (it only lets the lesson's expected action through). Only the bubble, its
## Next button and the chapter-end panel take taps.

signal next_pressed
signal outro_next
signal outro_replay
signal outro_menu

const UI := preload("res://scripts/ui/ui_kit.gd")
const Avatar := preload("res://scripts/ui/avatar.gd")
const Settings := preload("res://scripts/game/settings.gd")
const Fx := preload("res://scripts/ui/fx.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

const REX_STYLE := 1 # Rex's avatar (see Avatar.STYLES)
const DIM := Color(0, 0, 0, 0.58)
const GOLD := Color(1.0, 0.82, 0.2)
const CHARS_PER_SEC := 55.0

## Where the spotlight goes (this control's coordinates). Empty = no spotlight, the whole table is dimmed.
var target := Rect2()
## The lowest the bubble may reach when it has to move out of the way of the spotlight (the top of the hand area).
var bottom_limit := 1200.0
var active := false # a step is showing

var _bubble: PanelContainer
var _portrait: Portrait
var _say: Label
var _hint: Label
var _next: Button
var _say_text := ""
var _typing: Tween
var _hint_serial := 0
var _outro: Control


## Rex's face: the avatar, animated while he talks.
class Portrait extends Control:
	var talking := false

	func _init(px: float) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0 - 4.0
		Avatar.draw_avatar(self, REX_STYLE, size / 2.0, r, GOLD, 6.0, false, talking)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2100 # above the J picker (2000), so a suit button can be spotlighted
	_build_bubble()
	set_process(true)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UI.popup_style())
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.visible = false
	_bubble.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_finish_typing())
	add_child(_bubble)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.SPACE_M)
	_bubble.add_child(row)
	_portrait = Portrait.new(140.0)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", UI.SPACE_S)
	row.add_child(col)
	_say = UI.body("", 300.0)
	_say.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_say)
	_hint = UI.body("", 300.0, UI.FONT_HINT)
	_hint.add_theme_color_override("font_color", UI.RED.lightened(0.25))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	col.add_child(_hint)
	_next = UI.button("Next", UI.Variant.PRIMARY, func():
		if _typing != null and _typing.is_valid() and _typing.is_running():
			_finish_typing() # the first tap only finishes the sentence
		else:
			next_pressed.emit())
	_next.custom_minimum_size = Vector2(320, 96)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.visible = false
	col.add_child(_next)


# ---------------------------------------------------------------- steps

## Shows what Rex says now. `read` steps get a Next button; the others wait for the player to act.
func show_step(text: String, read: bool) -> void:
	active = true
	_bubble.visible = true
	_next.visible = read
	_hint.visible = false
	_hint_serial += 1
	_set_say(text)
	Sfx.play("turn", 0.5)
	if not Settings.reduce():
		_bubble.pivot_offset = _bubble.size / 2.0
		_bubble.scale = Vector2(0.92, 0.92)
		_bubble.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_bubble, "modulate:a", 1.0, 0.16)
		tw.tween_property(_bubble, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


## Swaps the line while a step is showing (e.g. once the J's suit picker opens). No-op for the same text.
func set_say(text: String) -> void:
	if active and text != _say_text:
		_hint.visible = false
		_set_say(text)


func hide_step() -> void:
	active = false
	_bubble.visible = false
	_hint.visible = false
	_stop_typing()
	target = Rect2()
	queue_redraw()


## The player did something else than the lesson asks: Rex says so, and the bubble gives a little shake.
func nudge(text: String) -> void:
	if not active or text == "":
		return
	_hint.text = text
	_hint.visible = true
	_hint_serial += 1
	var mine := _hint_serial
	get_tree().create_timer(2.6).timeout.connect(func():
		if mine == _hint_serial and is_instance_valid(_hint):
			_hint.visible = false)
	if not Settings.reduce():
		var x0 := _bubble.position.x
		var tw := create_tween()
		for dx in [-14.0, 12.0, -8.0, 5.0, 0.0]:
			tw.tween_property(_bubble, "position:x", x0 + dx, 0.05)


func _set_say(text: String) -> void:
	_say_text = text
	_say.text = text
	_stop_typing()
	if Settings.reduce():
		_say.visible_ratio = 1.0
		return
	_say.visible_ratio = 0.0
	_portrait.talking = true
	_typing = create_tween()
	_typing.tween_property(_say, "visible_ratio", 1.0, maxf(text.length() / CHARS_PER_SEC, 0.4))
	_typing.tween_callback(func(): _portrait.talking = false)


func _finish_typing() -> void:
	if _typing != null and _typing.is_valid():
		_typing.kill()
		_typing = null
		_say.visible_ratio = 1.0
		_portrait.talking = false


func _stop_typing() -> void:
	if _typing != null:
		_typing.kill()
		_typing = null
	_portrait.talking = false


# ---------------------------------------------------------------- frame

func _process(_delta: float) -> void:
	if active:
		_place_bubble()
		queue_redraw()


## The bubble sits at the top; when the spotlight is up there it drops to just above the hand instead.
func _place_bubble() -> void:
	var bw := minf(size.x - 40.0, 1000.0)
	_say.custom_minimum_size.x = maxf(bw - 140.0 - 3.0 * UI.SPACE_M - 2.0 * UI.PANEL_PAD, 260.0)
	_hint.custom_minimum_size.x = _say.custom_minimum_size.x
	_bubble.size = Vector2(bw, 0.0)
	var bh := _bubble.get_combined_minimum_size().y
	_bubble.size = Vector2(bw, bh)
	var x := (size.x - bw) / 2.0
	var pos := Vector2(x, 130.0)
	if target.has_area() and Rect2(pos, Vector2(bw, bh)).grow(16.0).intersects(target):
		pos.y = maxf(bottom_limit - bh, 130.0)
	if _hint.visible and _bubble.position.x != x:
		pos.x = _bubble.position.x # keep a running shake
	_bubble.position = pos


func _draw() -> void:
	if not active:
		return
	var w := size.x
	var h := size.y
	if not target.has_area():
		draw_rect(Rect2(0, 0, w, h), DIM)
		return
	var r := target.grow(10.0).intersection(Rect2(0, 0, w, h))
	draw_rect(Rect2(0, 0, w, r.position.y), DIM)
	draw_rect(Rect2(0, r.end.y, w, h - r.end.y), DIM)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), DIM)
	draw_rect(Rect2(r.end.x, r.position.y, w - r.end.x, r.size.y), DIM)
	var t := float(Time.get_ticks_msec()) / 1000.0
	var pulse := 0.5 if Settings.reduce() else 0.5 + 0.5 * sin(t * TAU * 0.8)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_corner_radius_all(26)
	ring.set_border_width_all(6)
	ring.border_color = Color(GOLD, 0.65 + 0.35 * pulse)
	ring.shadow_color = Color(GOLD, 0.25 + 0.25 * pulse)
	ring.shadow_size = int(8 + 10 * pulse)
	draw_style_box(ring, r.grow(4.0 + 4.0 * pulse))
	# Bobbing arrow on the side facing the middle of the screen.
	var bob := 0.0 if Settings.reduce() else absf(sin(t * 4.0)) * 18.0
	var below := target.get_center().y < size.y * 0.3
	var tip_y := r.end.y + 12.0 + bob if below else r.position.y - 12.0 - bob
	var s := 1.0 if below else -1.0
	var cx := clampf(r.get_center().x, 50.0, w - 50.0)
	var tri := PackedVector2Array([Vector2(cx, tip_y), Vector2(cx - 34.0, tip_y + 52.0 * s), Vector2(cx + 34.0, tip_y + 52.0 * s)])
	draw_colored_polygon(tri, GOLD)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.42, 0.24, 0.02), 4.0, true)


# ---------------------------------------------------------------- chapter end

## Replaces the lesson with Rex's wrap-up and the buttons for what to do next.
func show_outro(title: String, text: String, next_label: String) -> void:
	hide_step()
	if _outro != null:
		_outro.queue_free()
	_outro = Control.new()
	_outro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_outro.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = UI.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outro.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outro.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.popup_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UI.SPACE_S)
	panel.add_child(box)

	var face := Portrait.new(190.0)
	face.talking = false
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(face)
	box.add_child(UI.title(title, 72))
	var body := UI.body(text, minf(size.x - 200.0, 780.0))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	box.add_child(UI.spacer(UI.SPACE_S))
	for spec in [[next_label, UI.Variant.PRIMARY, func(): outro_next.emit()],
			["Replay chapter", UI.Variant.SECONDARY, func(): outro_replay.emit()],
			["Menu", UI.Variant.TERTIARY, func(): outro_menu.emit()]]:
		var c := CenterContainer.new()
		c.add_child(UI.button(spec[0], spec[1], spec[2]))
		box.add_child(c)
	add_child(_outro)
	if not Settings.reduce():
		Fx.confetti(self, size.x)
		panel.pivot_offset = panel.get_combined_minimum_size() / 2.0
		panel.scale = Vector2(0.88, 0.88)
		create_tween().tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("win", 0.6)


func outro_visible() -> bool:
	return _outro != null and is_instance_valid(_outro)
