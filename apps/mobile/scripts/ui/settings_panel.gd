extends Control
## Settings overlay: sound on/off, volume, reduce motion. Saves on every change.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Settings := preload("res://scripts/game/settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const Hand3D := preload("res://scripts/ui/hand3d.gd")

signal closed

var _sound_btn: Button
var _motion_btn: Button
var _react_btn: Button
var _hand_you_btn: Button
var _hand_bots_btn: Button
var _hand_color_btn: Button
var _volume_label: Label
var _scroll: ScrollContainer
var _pressing := false
var _dragging := false
var _press_y := 0.0
var _press_scroll := 0
const DRAG_DEADZONE := 14.0


func _ready() -> void:
	Settings.load_settings()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	add_child(UI.background())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UI.MARGIN_SCREEN)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UI.SPACE_M)
	margin.add_child(box)
	var t := UI.title("Settings")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	# Content scrolls only when it overflows. Dragging is handled in _input so a
	# finger that starts on a button still scrolls without toggling it.
	_scroll = UI.scroll_area()
	_scroll.scroll_deadzone = 1000000   # disable built-in drag; we do it ourselves
	box.add_child(_scroll)

	var card := UI.panel(UI.SPACE_M)
	card[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(card[0])
	var inner: VBoxContainer = card[1]

	_sound_btn = UI.toggle("", Settings.sound_enabled, _on_sound)
	inner.add_child(_sound_btn)

	inner.add_child(UI.heading("Volume"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	inner.add_child(row)
	row.add_child(UI.stepper("-", func(): _step(-0.1)))
	_volume_label = UI.body("", 0.0, UI.FONT_PILL)
	_volume_label.custom_minimum_size = Vector2(380, 0)
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_volume_label)
	row.add_child(UI.stepper("+", func(): _step(0.1)))

	_react_btn = UI.toggle("", Settings.show_reactions, _on_reactions)
	inner.add_child(_react_btn)
	inner.add_child(UI.hint("Reactions are the emoji stickers players send during a game. Turn them off to hide the button and stop other players' stickers."))
	_hand_you_btn = UI.toggle("", Settings.hand_you, _on_hand_you)
	inner.add_child(_hand_you_btn)
	_hand_bots_btn = UI.toggle("", Settings.hand_bots, _on_hand_bots)
	inner.add_child(_hand_bots_btn)
	_hand_color_btn = UI.button("", UI.Variant.SECONDARY, _on_hand_color)
	inner.add_child(_hand_color_btn)
	inner.add_child(UI.hint("3D hands pick up and play the cards: yours from the bottom, the opponents' from the top. They are also off while Reduce motion is on."))
	_motion_btn = UI.toggle("", Settings.reduce_motion, _on_motion)
	inner.add_child(_motion_btn)
	inner.add_child(UI.hint("Reduce motion turns off shaking, flashes, sparks, confetti, pulsing and bounces. Cards still move, and messages still show."))

	box.add_child(UI.button("Close", UI.Variant.SECONDARY, func(): closed.emit()))
	_refresh()


func _input(event: InputEvent) -> void:
	if _scroll == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_y = event.position.y
			_press_scroll = _scroll.scroll_vertical
			_pressing = _scroll.get_global_rect().has_point(event.position)
			_dragging = false
		else:
			var was := _dragging
			_pressing = false
			_dragging = false
			if was:
				get_viewport().set_input_as_handled()
				_set_buttons_ignore(false)
	elif event is InputEventMouseMotion and _pressing:
		var dy: float = event.position.y - _press_y
		if not _dragging and absf(dy) > DRAG_DEADZONE:
			_dragging = true
			_set_buttons_ignore(true)   # cancels the press so the release won't click
		if _dragging:
			_scroll.scroll_vertical = int(_press_scroll - dy)
			get_viewport().set_input_as_handled()


func _set_buttons_ignore(on: bool) -> void:
	for n in _scroll.find_children("*", "BaseButton", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP


func _step(delta: float) -> void:
	Settings.volume = clampf(snappedf(Settings.volume + delta, 0.1), 0.0, 1.0)
	Settings.save()
	_refresh()
	Sfx.play("turn")


func _on_sound(on: bool) -> void:
	Settings.sound_enabled = on
	Settings.save()
	_refresh()
	Sfx.play("check")


func _on_motion(on: bool) -> void:
	Settings.reduce_motion = on
	Settings.save()
	_refresh()


func _on_hand_color() -> void:
	Settings.hand_color = (Settings.hand_color + 1) % Hand3D.STYLES.size()
	Settings.save()
	_refresh()


func _on_hand_you(on: bool) -> void:
	Settings.hand_you = on
	Settings.save()
	_refresh()


func _on_hand_bots(on: bool) -> void:
	Settings.hand_bots = on
	Settings.save()
	_refresh()


func _on_reactions(on: bool) -> void:
	Settings.show_reactions = on
	Settings.save()
	_refresh()


func _refresh() -> void:
	_react_btn.text = "Reactions: %s" % ("On" if Settings.show_reactions else "Off")
	_hand_color_btn.text = "Hand colour: %s" % Hand3D.STYLES[Settings.hand_color % Hand3D.STYLES.size()][0]
	_hand_you_btn.text = "Your 3D hand: %s" % ("On" if Settings.hand_you else "Off")
	_hand_bots_btn.text = "Opponents' 3D hands: %s" % ("On" if Settings.hand_bots else "Off")
	_sound_btn.text = "Sound: %s" % ("On" if Settings.sound_enabled else "Off")
	_motion_btn.text = "Reduce motion: %s" % ("On" if Settings.reduce_motion else "Off")
	_volume_label.text = "%d%%" % int(round(Settings.volume * 100.0))
