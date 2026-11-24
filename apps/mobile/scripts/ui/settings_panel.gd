extends Control
## Settings overlay: sound on/off, volume, reduce motion. Saves on every change.

const UI := preload("res://scripts/ui/ui_kit.gd")
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
	add_child(UI.background())

	var box := UI.column()
	add_child(box)
	box.add_child(UI.title("Settings"))
	box.add_child(UI.spacer(10))

	var card := UI.panel(UI.SPACE_M)
	box.add_child(card[0])
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

	_motion_btn = UI.toggle("", Settings.reduce_motion, _on_motion)
	inner.add_child(_motion_btn)
	inner.add_child(UI.hint("Reduce motion turns off shaking, flashes, sparks, confetti, pulsing and bounces. Cards still move, and messages still show."))

	box.add_child(UI.spacer(10))
	box.add_child(UI.button("Close", UI.Variant.SECONDARY, func(): closed.emit()))
	_refresh()


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


func _refresh() -> void:
	_sound_btn.text = "Sound: %s" % ("On" if Settings.sound_enabled else "Off")
	_motion_btn.text = "Reduce motion: %s" % ("On" if Settings.reduce_motion else "Off")
	_volume_label.text = "%d%%" % int(round(Settings.volume * 100.0))
