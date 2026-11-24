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


func _ready() -> void:
	Settings.load_settings()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	add_child(UI.background())

	# Pinned header/footer with the content scrolling full width underneath.
	var page := UI.scroll_page("Settings", "Close", func(): closed.emit())
	add_child(page["scroll"])
	add_child(page["header"])
	add_child(page["footer"])
	var inner: VBoxContainer = page["content"]

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
