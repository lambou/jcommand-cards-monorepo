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
const TABLE_RADIUS := 22

var _table_frames: Array = []
var _table_names: Array = []
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
	inner.add_child(UI.heading("Table"))
	var tables := HBoxContainer.new()
	tables.alignment = BoxContainer.ALIGNMENT_CENTER
	tables.add_theme_constant_override("separation", 16)
	inner.add_child(tables)
	for i in TableBg.STYLES.size():
		tables.add_child(_table_choice(i))
	inner.add_child(UI.hint("Tap a table to use it. Takes effect when the next game starts."))
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


## One tappable preview: the real table background scaled down, with its name underneath.
func _table_choice(i: int) -> Control:
	var thumb := Vector2(233, 414)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var btn := Button.new()
	btn.custom_minimum_size = thumb
	# Soft drop shadow behind the card (the button's own style; the preview covers its fill).
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.02, 0.1, 0.07)
	back.set_corner_radius_all(TABLE_RADIUS)
	back.shadow_color = Color(0, 0, 0, 0.45)
	back.shadow_size = 10
	back.shadow_offset = Vector2(0, 5)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, back if state != "focus" else StyleBoxEmpty.new())
	btn.pressed.connect(func():
		Settings.table_style = i
		Settings.save()
		_refresh()
		Sfx.play("check"))
	box.add_child(btn)
	# The table is drawn at real game size in a SubViewport (at 2x the thumbnail for crisp lines),
	# then shown through a rounded-corner mask so the card edges are clean.
	var full := Vector2(1080, 1920)
	var vp := SubViewport.new()
	vp.size = Vector2i(thumb * 2.0)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	btn.add_child(vp)
	var bg := TableBg.new()
	bg.style = i
	vp.add_child(bg)
	bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bg.size = full
	bg.scale = Vector2(vp.size) / full
	var shot := TextureRect.new()
	shot.texture = vp.get_texture()
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_SCALE
	shot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _rounded_shader()
	mat.set_shader_parameter("radius_px", float(TABLE_RADIUS))
	mat.set_shader_parameter("size_px", thumb)
	shot.material = mat
	btn.add_child(shot)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(frame)
	_table_frames.append(frame)
	var name_label := Label.new()
	name_label.text = TableBg.STYLES[i]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", UI.FONT_CAPTION)
	box.add_child(name_label)
	_table_names.append(name_label)
	return box


static func _rounded_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform float radius_px = 18.0;
uniform vec2 size_px = vec2(233.0, 414.0);
void fragment() {
	vec2 p = (UV - 0.5) * size_px;
	vec2 q = abs(p) - (size_px * 0.5 - vec2(radius_px));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius_px;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(-1.0, 0.5, d);
}
"""
	return s


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
	for i in _table_frames.size():
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		var on: bool = i == Settings.table_style % TableBg.STYLES.size()
		sb.border_color = Color(1.0, 0.85, 0.3) if on else Color(1, 1, 1, 0.22)
		sb.set_border_width_all(6 if on else 2)
		sb.set_corner_radius_all(TABLE_RADIUS)
		sb.anti_aliasing = true
		(_table_names[i] as Label).add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if on else Color(1, 1, 1, 0.7))
		(_table_frames[i] as Panel).add_theme_stylebox_override("panel", sb)
	_hand_you_btn.text = "Your 3D hand: %s" % ("On" if Settings.hand_you else "Off")
	_hand_bots_btn.text = "Opponents' 3D hands: %s" % ("On" if Settings.hand_bots else "Off")
	_sound_btn.text = "Sound: %s" % ("On" if Settings.sound_enabled else "Off")
	_motion_btn.text = "Reduce motion: %s" % ("On" if Settings.reduce_motion else "Off")
	_volume_label.text = "%d%%" % int(round(Settings.volume * 100.0))
