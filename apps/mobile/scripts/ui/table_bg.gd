class_name TableBg
extends Control
## Table background, drawn in code. Set `style` (index into STYLES) before adding to the tree.

const STYLES := ["Classic Felt", "Royal Velvet", "Burgundy Lounge", "Dark Wood"]
const GOLD := Color(0.91, 0.75, 0.31)

var style := 0

var _glow: GradientTexture2D
var _weave: ImageTexture


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _ready() -> void:
	match style:
		1:
			_glow = _radial([Color(0.17, 0.27, 0.58), Color(0.04, 0.07, 0.20)], Vector2(0.5, 0.4), Vector2(1.0, 1.0))
		2:
			_glow = _radial([Color(0.56, 0.12, 0.20), Color(0.16, 0.03, 0.07)], Vector2(0.5, 0.45), Vector2(1.0, 1.0))
		3:
			_glow = _radial([Color(0.12, 0.50, 0.31), Color(0.03, 0.22, 0.14)], Vector2(0.5, 0.45), Vector2(0.9, 0.9))
		_:
			_glow = _radial([Color(0.16, 0.62, 0.38), Color(0.01, 0.12, 0.07)], Vector2(0.5, 0.45), Vector2(1.0, 1.0), 0.6, Color(0.07, 0.38, 0.23))
			_weave = _make_weave()
	queue_redraw()


func _draw() -> void:
	match style:
		1: _draw_velvet()
		2: _draw_burgundy()
		3: _draw_wood()
		_: _draw_classic()


func _draw_classic() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_glow, r, false)
	draw_texture_rect(_weave, r, true) # tiled fabric weave
	var m := minf(size.x, size.y) * 0.045
	_rim(Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0), m * 2.2, Color(GOLD, 0.6), maxf(2.0, m * 0.2))
	var m2 := m * 1.6
	_rim(Rect2(Vector2(m2, m2), size - Vector2(m2, m2) * 2.0), m * 1.8, Color(GOLD, 0.25), maxf(1.0, m * 0.1))


func _draw_velvet() -> void:
	draw_texture_rect(_glow, Rect2(Vector2.ZERO, size), false)
	# Damask: gold diamonds with a dot in the middle, on a 72px grid.
	var s := 72.0
	var line := Color(GOLD, 0.26)
	var dot := Color(GOLD, 0.30)
	var y := 0.0
	while y < size.y + s:
		var x := 0.0
		while x < size.x + s:
			var c := Vector2(x + s * 0.5, y + s * 0.5)
			var h := s * 0.42
			draw_polyline(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0), c + Vector2(0, -h)]), line, 1.5, true)
			draw_circle(c, 5.0, dot)
			draw_circle(Vector2(x, y), 3.0, Color(GOLD, 0.2))
			x += s
		y += s
	var w := maxf(6.0, minf(size.x, size.y) * 0.012)
	draw_rect(Rect2(Vector2(w, w) * 0.5, size - Vector2(w, w)), Color(GOLD, 0.55), false, w)


func _draw_burgundy() -> void:
	draw_texture_rect(_glow, Rect2(Vector2.ZERO, size), false)
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.055), 2.0)
		x += 24.0
	var c := size * Vector2(0.5, 0.5)
	var rad := minf(size.x, size.y) * 0.41
	draw_arc(c, rad, 0.0, TAU, 128, Color(GOLD, 0.5), 4.0, true)
	# dashed inner ring
	var dr := rad * 0.9
	var n := 72
	for i in n:
		var a0 := TAU * i / n
		draw_arc(c, dr, a0, a0 + TAU / n * 0.45, 4, Color(GOLD, 0.25), 3.0, true)
	var m := minf(size.x, size.y) * 0.03
	_rim(Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0), m * 1.5, Color(GOLD, 0.3), 2.0)


func _draw_wood() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var planks := 5
	var pw := size.x / planks
	for i in planks:
		var shade := rng.randf_range(-0.04, 0.05)
		var base := Color(0.34 + shade, 0.19 + shade * 0.7, 0.09 + shade * 0.4)
		draw_rect(Rect2(i * pw, 0, pw + 1.0, size.y), base)
		# sheen down the middle of each plank
		draw_rect(Rect2(i * pw + pw * 0.3, 0, pw * 0.4, size.y), Color(1, 0.8, 0.5, 0.05))
		# grain: wobbly dark lines running along the plank
		for g in 9:
			var gx := i * pw + rng.randf_range(0.05, 0.95) * pw
			var ph := rng.randf() * TAU
			var amp := rng.randf_range(2.0, 7.0)
			var pts := PackedVector2Array()
			var yy := 0.0
			while yy <= size.y + 40.0:
				pts.append(Vector2(gx + sin(yy * 0.012 + ph) * amp, yy))
				yy += 40.0
			draw_polyline(pts, Color(0, 0, 0, rng.randf_range(0.10, 0.22)), rng.randf_range(1.0, 2.5), true)
		draw_line(Vector2(i * pw, 0), Vector2(i * pw, size.y), Color(0, 0, 0, 0.55), 4.0)
	# inset felt panel
	var m := minf(size.x, size.y) * 0.08
	var panel := Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0)
	var rad := m * 1.3
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.02, 0.15, 0.09)
	shadow.set_corner_radius_all(int(rad))
	shadow.shadow_color = Color(0, 0, 0, 0.5)
	shadow.shadow_size = int(m * 0.8)
	shadow.anti_aliasing = true
	draw_style_box(shadow, panel)
	var inset := rad * 0.3
	draw_texture_rect(_glow, panel.grow(-inset), false)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0)
	frame.set_border_width_all(int(maxf(5.0, m * 0.14)))
	frame.border_color = Color(0.16, 0.08, 0.03)
	frame.set_corner_radius_all(int(rad))
	frame.anti_aliasing = true
	draw_style_box(frame, panel)


func _rim(rect: Rect2, radius: float, col: Color, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(int(ceil(width)))
	sb.border_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


## Radial gradient from colors[0] (centre) to colors[1] (edge), optionally with a middle stop.
func _radial(colors: Array, center: Vector2, edge: Vector2, mid_at := -1.0, mid := Color.BLACK) -> GradientTexture2D:
	var g := Gradient.new()
	if mid_at > 0.0:
		g.offsets = PackedFloat32Array([0.0, mid_at, 1.0])
		g.colors = PackedColorArray([colors[0], mid, colors[1]])
	else:
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([colors[0], colors[1]])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = center
	t.fill_to = edge
	t.width = 256
	t.height = 256
	return t


func _make_weave() -> ImageTexture:
	# 96px tile: a visible crosshatch weave plus random felt speckle (seeded so it never shimmers)
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in n:
		for x in n:
			var a := 0.0
			var c := Color.WHITE
			if (x + y) % 6 == 0 or (x - y + n * 2) % 6 == 0:
				a = 0.07
			var r := rng.randf()
			if r < 0.18:
				a = maxf(a, rng.randf_range(0.03, 0.10))
			elif r < 0.30:
				c = Color.BLACK
				a = rng.randf_range(0.05, 0.14)
			img.set_pixel(x, y, Color(c, a))
	return ImageTexture.create_from_image(img)
