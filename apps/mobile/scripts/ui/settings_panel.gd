extends Control
## Settings overlay: sound on/off, volume, reduce motion. Saves on every change.

const Settings := preload("res://scripts/game/settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

signal closed

var _sound_btn: Button
var _motion_btn: Button
var _volume_label: Label


func _ready() -> void:
	Settings.load_settings()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.13, 0.09, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 30)
	add_child(box)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_sound_btn = _toggle("", Settings.sound_enabled, _on_sound)
	box.add_child(_sound_btn)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	row.add_child(_step_button("-", -0.1))
	_volume_label = Label.new()
	_volume_label.add_theme_font_size_override("font_size", 52)
	_volume_label.custom_minimum_size = Vector2(380, 0)
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_volume_label)
	row.add_child(_step_button("+", 0.1))

	_motion_btn = _toggle("", Settings.reduce_motion, _on_motion)
	box.add_child(_motion_btn)

	var hint := Label.new()
	hint.text = "Reduce motion turns off shaking, flashes, sparks, confetti, pulsing and bounces. Cards still move, and messages still show."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(820, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 34)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(hint)

	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 56)
	close.custom_minimum_size = Vector2(520, 120)
	close.pressed.connect(func(): closed.emit())
	box.add_child(close)
	_refresh()


func _toggle(text: String, on: bool, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.add_theme_font_size_override("font_size", 56)
	b.custom_minimum_size = Vector2(760, 120)
	b.toggled.connect(handler)
	return b


func _step_button(text: String, delta: float) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 64)
	b.custom_minimum_size = Vector2(120, 110)
	b.pressed.connect(func():
		Settings.volume = clampf(snappedf(Settings.volume + delta, 0.1), 0.0, 1.0)
		Settings.save()
		_refresh()
		Sfx.play("turn"))
	return b


func _on_sound(on: bool) -> void:
	Settings.sound_enabled = on
	Settings.save()
	_refresh()
	Sfx.play("check")


func _on_motion(on: bool) -> void:
	Settings.reduce_motion = on
	Settings.save()
	_refresh()


func _refresh() -> void:
	_sound_btn.text = "Sound: %s" % ("On" if Settings.sound_enabled else "Off")
	_motion_btn.text = "Reduce motion: %s" % ("On" if Settings.reduce_motion else "Off")
	_volume_label.text = "Volume %d%%" % int(round(Settings.volume * 100.0))
