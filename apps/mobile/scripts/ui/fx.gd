extends RefCounted
## Small, self-cleaning visual effects (all drawn in code, no assets).
## Every helper adds its node to `parent` and frees it when the effect is over.

const Ring := preload("res://scripts/ui/fx_ring.gd")
const Settings := preload("res://scripts/game/settings.gd")


static func ring(parent: Control, center: Vector2, color: Color, radius: float, dur: float = 0.5, width: float = 10.0) -> void:
	if Settings.reduce():
		return
	var r := Ring.new()
	r.color = color
	r.max_radius = radius
	r.line_width = width
	r.position = center
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	var tw := parent.create_tween()
	tw.tween_property(r, "t", 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(r.queue_free)


## A one-shot burst of square sparks.
static func burst(parent: Control, center: Vector2, color: Color, amount: int = 16, speed: float = 420.0, life: float = 0.6) -> void:
	if Settings.reduce():
		return
	var p := CPUParticles2D.new()
	p.position = center
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.scale_amount_min = 5.0
	p.scale_amount_max = 12.0
	p.color = color
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


## Text that pops in, floats up and fades out.
static func popup_text(parent: Control, text: String, center: Vector2, color: Color, font_size: int = 64, rise: float = 90.0, dur: float = 1.1) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(10, int(font_size * 0.2)))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(maxf(620.0, float(text.length()) * float(font_size) * 0.62), font_size * 1.5)
	l.position = center - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE if Settings.reduce() else Vector2(0.3, 0.3)
	if Settings.reduce():
		rise = 0.0
	parent.add_child(l)
	var tw := parent.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE if Settings.reduce() else Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.08)
	tw.tween_property(l, "position:y", l.position.y - rise, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, dur * 0.35).set_delay(dur * 0.65)
	tw.tween_callback(l.queue_free)
	return l


## A red STOP sign that slams in.
static func stop_sign(parent: Control, center: Vector2) -> void:
	var l := Label.new()
	l.text = "STOP"
	l.add_theme_font_size_override("font_size", 58)
	l.add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.82, 0.08, 0.1)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(7)
	sb.border_color = Color.WHITE
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	l.add_theme_stylebox_override("normal", sb)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(230, 100)
	l.position = center - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE if Settings.reduce() else Vector2(2.6, 2.6)
	l.rotation_degrees = 0.0 if Settings.reduce() else -10.0
	l.modulate.a = 0.0
	parent.add_child(l)
	var tw := parent.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.1)
	tw.tween_interval(0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## Full-screen colour flash (e.g. red when you take a penalty).
static func flash(parent: Control, color: Color, peak_alpha: float = 0.3, dur: float = 0.5) -> void:
	if Settings.reduce():
		return
	var r := ColorRect.new()
	r.color = Color(color.r, color.g, color.b, 1.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.modulate.a = 0.0
	parent.add_child(r)
	var tw := parent.create_tween()
	tw.tween_property(r, "modulate:a", peak_alpha, dur * 0.2)
	tw.tween_property(r, "modulate:a", 0.0, dur * 0.8)
	tw.tween_callback(r.queue_free)


## Falling coloured confetti across `width` pixels.
static func confetti(parent: Control, width: float) -> void:
	if Settings.reduce():
		return
	var p := CPUParticles2D.new()
	p.position = Vector2(width / 2.0, -30)
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.3
	p.amount = 160
	p.lifetime = 3.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width / 2.0, 10)
	p.direction = Vector2(0, 1)
	p.spread = 22.0
	p.gravity = Vector2(0, 380)
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 620.0
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = 9.0
	p.scale_amount_max = 17.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.85, 0.2), Color(0.95, 0.25, 0.3), Color(0.3, 0.8, 1.0), Color(0.5, 1.0, 0.45), Color(1.0, 0.6, 0.9)])
	p.color_initial_ramp = g
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.6).timeout.connect(p.queue_free)


## Quick screen shake: jiggles `node.position` and returns it to where it started.
static func shake(node: Control, strength: float = 14.0, dur: float = 0.4) -> void:
	if Settings.reduce():
		return
	var home := node.position
	var tw := node.create_tween()
	var steps := 8
	for i in steps:
		var falloff := 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		tw.tween_property(node, "position", home + off, dur / float(steps))
	tw.tween_property(node, "position", home, 0.04)


## Soft colour glow at the screen edges (centre stays clear), one gentle pulse.
static func vignette(parent: Control, color: Color, peak_alpha: float = 0.25, dur: float = 0.6) -> void:
	if Settings.reduce():
		return
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 1.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.modulate.a = 0.0
	parent.add_child(r)
	var tw := parent.create_tween()
	tw.tween_property(r, "modulate:a", peak_alpha, dur * 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(r, "modulate:a", 0.0, dur * 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(r.queue_free)
