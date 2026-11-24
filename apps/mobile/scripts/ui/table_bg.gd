class_name TableBg
extends Control
## Table background, drawn in code. Set `style` (index into STYLES) before adding to the tree.

const STYLES := ["Classic Felt", "Royal Velvet", "Burgundy Lounge", "Dark Wood", "Black Marble"]
const GOLD := Color(0.91, 0.75, 0.31)
const Settings := preload("res://scripts/game/settings.gd")

## Per-table palette for the game UI drawn on top of the table: dark plate colour (opponent panels, emoji
## button), button face, text outline, and the card-back colours (body, lattice).
const THEMES := [
	{"panel": Color(0.05, 0.22, 0.14), "button": Color(0.15, 0.62, 0.40), "ink": Color(0.06, 0.10, 0.08),
		"back": Color(0.12, 0.21, 0.52), "lattice": Color(0.30, 0.46, 0.85, 0.55)},
	{"panel": Color(0.04, 0.07, 0.22), "button": Color(0.24, 0.36, 0.76), "ink": Color(0.02, 0.04, 0.15),
		"back": Color(0.50, 0.08, 0.18), "lattice": Color(0.80, 0.32, 0.44, 0.55)}, # burgundy back stands out on navy
	{"panel": Color(0.22, 0.05, 0.09), "button": Color(0.66, 0.18, 0.28), "ink": Color(0.13, 0.02, 0.05),
		"back": Color(0.12, 0.21, 0.52), "lattice": Color(0.30, 0.46, 0.85, 0.55)},
	{"panel": Color(0.05, 0.22, 0.14), "button": Color(0.15, 0.62, 0.40), "ink": Color(0.06, 0.10, 0.08),
		"back": Color(0.12, 0.21, 0.52), "lattice": Color(0.30, 0.46, 0.85, 0.55)},
	{"panel": Color(0.05, 0.05, 0.07), "button": Color(0.62, 0.47, 0.14), "ink": Color(0.02, 0.02, 0.03),
		"back": Color(0.04, 0.36, 0.34), "lattice": Color(0.22, 0.72, 0.66, 0.55)}, # teal back reads on black stone
]


## The palette of the table style chosen in settings.
static func current_theme() -> Dictionary:
	Settings.load_settings()
	return THEMES[Settings.table_style % THEMES.size()]

var style := 0

var _glow: GradientTexture2D
var _weave: ImageTexture
var _fade: GradientTexture2D
static var _marble: ImageTexture # generated once, shared by every Black Marble table


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _ready() -> void:
	match style:
		1:
			_glow = _radial([Color(0.17, 0.27, 0.58), Color(0.04, 0.07, 0.20)], Vector2(0.5, 0.4), Vector2(1.0, 1.0))
			# same centre colour, opaque in the middle and clear toward the edges
			_fade = _radial([Color(0.17, 0.27, 0.58, 0.96), Color(0.10, 0.17, 0.40, 0.0)], Vector2(0.5, 0.4), Vector2(1.0, 0.75))
			_weave = _make_weave(false)
		2:
			_glow = _radial([Color(0.56, 0.12, 0.20), Color(0.16, 0.03, 0.07)], Vector2(0.5, 0.45), Vector2(1.0, 1.0))
		3:
			_glow = _radial([Color(0.12, 0.50, 0.31), Color(0.03, 0.22, 0.14)], Vector2(0.5, 0.45), Vector2(0.9, 0.9))
		4:
			_glow = _radial([Color(0.19, 0.19, 0.21), Color(0.02, 0.02, 0.03)], Vector2(0.5, 0.4), Vector2(1.0, 1.0))
			_fade = _radial([Color(0.15, 0.15, 0.17, 0.62), Color(0.05, 0.05, 0.06, 0.0)], Vector2(0.5, 0.45), Vector2(1.0, 0.8))
			if _marble == null:
				_marble = _make_marble()
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_:
			_glow = _radial([Color(0.16, 0.62, 0.38), Color(0.01, 0.12, 0.07)], Vector2(0.5, 0.45), Vector2(1.0, 1.0), 0.6, Color(0.07, 0.38, 0.23))
			_weave = _make_weave(true)
	queue_redraw()


func _draw() -> void:
	match style:
		1: _draw_velvet()
		2: _draw_burgundy()
		3: _draw_wood()
		4: _draw_marble()
		_: _draw_classic()


func _draw_marble() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_glow, r, false)
	# soft diagonal sheen, like light on polished stone
	var w := size.x
	var h := size.y
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.05, 0), Vector2(w * 0.55, 0), Vector2(w * 0.05 + w * 0.2, h), Vector2(-w * 0.3, h)]), Color(1, 1, 1, 0.035))
	draw_texture_rect(_marble, r, false) # gold and grey veins
	draw_texture_rect(_fade, r, false) # keep the middle calm for the cards
	var m := minf(w, h) * 0.04
	_rim(Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0), m * 0.5, Color(GOLD, 0.7), maxf(2.0, m * 0.12))
	var m2 := m * 1.45
	_rim(Rect2(Vector2(m2, m2), size - Vector2(m2, m2) * 2.0), m * 0.3, Color(GOLD, 0.28), maxf(1.0, m * 0.06))
	# little gold diamonds on the four inner corners
	var c := m * 0.72
	for p in [Vector2(m, m), Vector2(w - m, m), Vector2(m, h - m), Vector2(w - m, h - m)]:
		var q: Vector2 = p
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -c * 0.55), q + Vector2(c * 0.55, 0), q + Vector2(0, c * 0.55), q + Vector2(-c * 0.55, 0)]), Color(GOLD, 0.9))


func _draw_classic() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_glow, r, false)
	draw_texture_rect(_weave, r, true) # tiled fabric weave
	var m := minf(size.x, size.y) * 0.045
	_rim(Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0), m * 2.2, Color(GOLD, 0.6), maxf(2.0, m * 0.2))
	var m2 := m * 1.6
	_rim(Rect2(Vector2(m2, m2), size - Vector2(m2, m2) * 2.0), m * 1.8, Color(GOLD, 0.25), maxf(1.0, m * 0.1))


func _draw_velvet() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_glow, r, false)
	# Gold lattice of touching diamonds (two sets of diagonal lines), with a small ornament in each cell.
	var d := 110.0
	var line := Color(GOLD, 0.4)
	var k := -int(size.y / d) - 1
	while k * d < size.x + size.y:
		draw_line(Vector2(k * d, 0), Vector2(k * d + size.y, size.y), line, 2.0, true)
		draw_line(Vector2(k * d, 0), Vector2(k * d - size.y, size.y), line, 2.0, true)
		k += 1
	var orn := Color(GOLD, 0.45)
	for b in int(size.y / (d * 0.5)) + 2:
		for a in int(size.x / (d * 0.5)) + 2:
			if (a + b) % 2 == 1: # cell centres sit where the grid index sum is odd
				var c := Vector2(a, b) * d * 0.5
				var h := d * 0.17
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.6, 0), c + Vector2(0, h), c + Vector2(-h * 0.6, 0)]), orn)
	# Calm the middle, where the piles and hands are: paint the glow back over it, fading out toward the edges.
	draw_texture_rect(_fade, r, false)
	draw_texture_rect(_weave, r, true) # fine velvet pile
	var m := minf(size.x, size.y) * 0.045
	# A quieter rim than Classic Felt: it runs behind the corner buttons and the hand, so it shouldn't shout.
	_rim(Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0), m * 2.2, Color(GOLD, 0.5), maxf(2.0, m * 0.15))
	var m2 := m * 1.6
	_rim(Rect2(Vector2(m2, m2), size - Vector2(m2, m2) * 2.0), m * 1.8, Color(GOLD, 0.2), maxf(1.0, m * 0.08))


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
	# Felt gradient, clipped to the rounded panel shape: a polygon whose UVs sample the gradient.
	var pts := _rounded_points(panel, rad, 12)
	var uvs := PackedVector2Array()
	for pt in pts:
		uvs.append((pt - panel.position) / panel.size)
	draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, _glow)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0)
	frame.set_border_width_all(int(maxf(5.0, m * 0.14)))
	frame.border_color = Color(0.16, 0.08, 0.03)
	frame.set_corner_radius_all(int(rad))
	frame.anti_aliasing = true
	draw_style_box(frame, panel)


## Outline of a rounded rectangle (convex), `seg` points per corner.
func _rounded_points(r: Rect2, radius: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[r.position + Vector2(r.size.x - radius, radius), -PI * 0.5],
		[r.position + Vector2(r.size.x - radius, r.size.y - radius), 0.0],
		[r.position + Vector2(radius, r.size.y - radius), PI * 0.5],
		[r.position + Vector2(radius, radius), PI],
	]
	for c in corners:
		for i in seg + 1:
			var a: float = c[1] + (PI * 0.5) * float(i) / seg
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * radius)
	return pts


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


## Veins from ridged noise, at a quarter of the game resolution and smoothed when stretched.
func _make_marble() -> ImageTexture:
	var wn := 270
	var hn := 480
	var img := Image.create(wn, hn, false, Image.FORMAT_RGBA8)
	var gold := FastNoiseLite.new()
	gold.seed = 21
	gold.frequency = 0.0075
	gold.fractal_octaves = 4
	var grey := FastNoiseLite.new()
	grey.seed = 5
	grey.frequency = 0.012
	grey.fractal_octaves = 3
	for y in hn:
		for x in wn:
			var g := 1.0 - clampf(absf(gold.get_noise_2d(x, y)) / 0.028, 0.0, 1.0)
			var s := 1.0 - clampf(absf(grey.get_noise_2d(x * 1.0, y * 1.0)) / 0.04, 0.0, 1.0)
			var col := Color(0.93, 0.78, 0.36, g * g * 0.8)
			if s * s * 0.28 > col.a:
				col = Color(0.85, 0.87, 0.92, s * s * 0.28)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _make_weave(crosshatch: bool) -> ImageTexture:
	# 96px tile: a visible crosshatch weave plus random felt speckle (seeded so it never shimmers)
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in n:
		for x in n:
			var a := 0.0
			var c := Color.WHITE
			if crosshatch and ((x + y) % 6 == 0 or (x - y + n * 2) % 6 == 0):
				a = 0.07
			var r := rng.randf()
			if r < 0.18:
				a = maxf(a, rng.randf_range(0.03, 0.10))
			elif r < 0.30:
				c = Color.BLACK
				a = rng.randf_range(0.05, 0.14)
			img.set_pixel(x, y, Color(c, a))
	return ImageTexture.create_from_image(img)
