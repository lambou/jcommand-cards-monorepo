extends RefCounted
## Emoji-style reaction stickers, drawn entirely in code (same approach as avatar.gd, no assets).
##
## `draw(ci, id, c, r, t)` paints one sticker centred on `c` inside radius `r` on the CanvasItem
## `ci` (call it from `_draw`). `t` is seconds since the sticker appeared, so every reaction is a
## pure function of time: the bubble, the picker and the preview all share this one drawing code.

const OUT := Color(0.33, 0.18, 0.04)
const YEL_TOP := Color(1.0, 0.9, 0.38)
const YEL_BOT := Color(0.99, 0.68, 0.13)
const TEAR := Color(0.4, 0.76, 1.0)
const WHITE := Color(1, 1, 1)
const DARK := Color(0.2, 0.1, 0.05)

## Sticker background colour behind each emoji, so the yellow faces pop.
const BACKING := {
	"gg": Color(0.22, 0.66, 0.42),
	"laugh": Color(0.27, 0.58, 0.92),
	"wow": Color(0.6, 0.42, 0.92),
	"clap": Color(0.96, 0.56, 0.22),
	"cool": Color(0.18, 0.7, 0.76),
	"think": Color(0.42, 0.47, 0.88),
	"oops": Color(0.92, 0.45, 0.62),
	"sad": Color(0.42, 0.56, 0.78),
	"angry": Color(1.0, 0.72, 0.26),
	"hurry": Color(0.3, 0.6, 0.92),
}


## Paints the sticker: a white die-cut disc with a soft shadow, a coloured backing and the emoji.
static func draw(ci: CanvasItem, id: String, c: Vector2, r: float, t: float, backing: bool = true) -> void:
	if backing:
		ci.draw_circle(c + Vector2(0, r * 0.07), r * 1.04, Color(0, 0, 0, 0.28))
		ci.draw_circle(c, r * 1.02, WHITE)
		var bg: Color = BACKING.get(id, Color(0.4, 0.6, 0.9))
		ci.draw_circle(c, r * 0.93, bg.darkened(0.12))
		ci.draw_circle(c + Vector2(0, -r * 0.05), r * 0.86, bg)
	var u := r * 0.78
	match id:
		"gg": _gg(ci, c, u, t)
		"laugh": _laugh(ci, c, u, t)
		"wow": _wow(ci, c, u, t)
		"clap": _clap(ci, c, u, t)
		"cool": _cool(ci, c, u, t)
		"think": _think(ci, c, u, t)
		"oops": _oops(ci, c, u, t)
		"sad": _sad(ci, c, u, t)
		"angry": _angry(ci, c, u, t)
		"hurry": _hurry(ci, c, u, t)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the ten reactions

static func _laugh(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	var s := sin(t * 24.0)
	_xf(ci, c, Vector2(s * 0.025 * u, -absf(s) * 0.03 * u), s * 0.07)
	_face(ci, u, YEL_TOP, YEL_BOT)
	# Eyes squeezed shut with laughter.
	for sx in [-1.0, 1.0]:
		ci.draw_arc(Vector2(sx * 0.36 * u, -0.1 * u), 0.15 * u, PI + 0.3, TAU - 0.3, 14, OUT, 0.085 * u, true)
	# Big open grin: dark mouth, teeth strip on top, tongue below.
	var my := 0.1 * u
	var rx := 0.52 * u
	var ry := u * (0.46 + 0.05 * sin(t * 24.0))
	var mouth := PackedVector2Array()
	for k in 25:
		var a := PI * float(k) / 24.0
		mouth.append(Vector2(cos(a) * rx, my + sin(a) * ry))
	ci.draw_colored_polygon(mouth, Color(0.5, 0.08, 0.1))
	_oval(ci, Vector2(0, my + ry * 0.8), 0.27 * u, 0.12 * u, Color(1.0, 0.45, 0.5))
	var a1 := asin(0.17 * u / ry)
	var teeth := PackedVector2Array()
	for k in 7:
		var a := a1 * float(k) / 6.0
		teeth.append(Vector2(cos(a) * rx, my + sin(a) * ry))
	for k in 7:
		var a := PI - a1 + a1 * float(k) / 6.0
		teeth.append(Vector2(cos(a) * rx, my + sin(a) * ry))
	ci.draw_colored_polygon(teeth, WHITE)
	var ring := mouth.duplicate()
	ring.append(ring[0])
	ci.draw_polyline(ring, OUT, 0.05 * u, true)
	# Tears of joy flying off both sides.
	for k in 2:
		for sx in [-1.0, 1.0]:
			var f := fposmod(t * 1.7 + float(k) * 0.5, 1.0)
			var p := Vector2(sx * (0.5 + 0.55 * f) * u, (-0.1 - 0.2 * f + 0.9 * f * f) * u)
			_drop(ci, p, 0.1 * u, 1.0 - f * f)


static func _wow(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 12.0)
	_xf(ci, c, Vector2.ZERO, 0.0, 1.0 + 0.03 * pulse)
	_face(ci, u, YEL_TOP, YEL_BOT)
	# Raised eyebrows.
	var lift := -0.05 * u * pulse
	for sx in [-1.0, 1.0]:
		ci.draw_arc(Vector2(sx * 0.32 * u, -0.38 * u + lift), 0.2 * u, PI + 0.5, TAU - 0.5, 12, OUT, 0.07 * u, true)
	# Wide eyes with tiny pupils.
	for sx in [-1.0, 1.0]:
		var e := Vector2(sx * 0.31 * u, -0.1 * u)
		_oval(ci, e, 0.17 * u, 0.22 * u, WHITE, 0.035 * u)
		ci.draw_circle(e + Vector2(0, 0.01 * u), (0.075 - 0.015 * pulse) * u, DARK)
		ci.draw_circle(e + Vector2(-0.025 * u, -0.03 * u), 0.025 * u, WHITE)
	# Mouth: a round "O".
	var mo := Vector2(0, 0.46 * u)
	_oval(ci, mo, (0.14 + 0.03 * pulse) * u, (0.19 + 0.04 * pulse) * u, Color(0.45, 0.07, 0.1), 0.04 * u)
	_oval(ci, mo + Vector2(0, 0.08 * u), 0.08 * u, 0.06 * u, Color(1.0, 0.45, 0.5))
	# Astonishment lines.
	for k in 3:
		var a := -PI * 0.5 + (float(k) - 1.0) * 0.5
		var on := 0.5 + 0.5 * sin(t * 14.0 + float(k) * 1.7)
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(d * u * 1.04, d * u * (1.04 + 0.2 * on), Color(1, 1, 1, 0.9), 0.07 * u, true)


static func _angry(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	_xf(ci, c, Vector2(sin(t * 42.0) * 0.03 * u, 0.0), sin(t * 31.0) * 0.03)
	_face(ci, u, Color(1.0, 0.52, 0.34), Color(0.86, 0.13, 0.1))
	# Steam puffing out of the head.
	for k in 3:
		for sx in [-1.0, 1.0]:
			var f := fposmod(t * 1.3 + float(k) / 3.0, 1.0)
			var p := Vector2(sx * (0.62 + 0.1 * sin(f * 9.0 + float(k))) * u, (-0.5 - 0.75 * f) * u)
			ci.draw_circle(p, (0.07 + 0.12 * f) * u, Color(1, 1, 1, 0.85 * (1.0 - f)))
	# Slanted brows, glaring eyes, gritted frown.
	for sx in [-1.0, 1.0]:
		_cap(ci, Vector2(sx * 0.56 * u, -0.4 * u), Vector2(sx * 0.1 * u, -0.2 * u), 0.065 * u, Color(0.25, 0.03, 0.03))
		_oval(ci, Vector2(sx * 0.3 * u, -0.02 * u), 0.085 * u, 0.1 * u, Color(0.2, 0.02, 0.02))
		ci.draw_circle(Vector2(sx * 0.3 * u - 0.025 * u, -0.05 * u), 0.025 * u, WHITE)
	var m := Rect2(-0.3 * u, 0.36 * u, 0.6 * u, 0.2 * u)
	_box(ci, m, 0.07 * u, WHITE, 0.045 * u)
	for kx in [-0.1, 0.1]:
		ci.draw_line(Vector2(kx * u, m.position.y), Vector2(kx * u, m.end.y), OUT, 0.03 * u, true)
	ci.draw_line(Vector2(m.position.x, m.position.y + m.size.y * 0.5), Vector2(m.end.x, m.position.y + m.size.y * 0.5), OUT, 0.03 * u, true)
	# A throbbing anger mark.
	var th := 1.0 + 0.15 * sin(t * 16.0)
	var vc := Vector2(0.56 * u, -0.58 * u)
	for q in 4:
		var d := Vector2(1.0 if q % 2 == 0 else -1.0, 1.0 if q < 2 else -1.0)
		var s0 := 0.0 if q == 0 else (PI * 0.5 if q == 1 else (PI * 1.5 if q == 2 else PI))
		ci.draw_arc(vc + d * 0.075 * u * th, 0.085 * u * th, s0 + PI * 0.5, s0 + PI, 8, Color(0.75, 0.05, 0.05), 0.045 * u, true)


static func _sad(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	_xf(ci, c, Vector2(0.0, 0.015 * u * sin(t * 4.0)), sin(t * 3.0) * 0.04)
	_face(ci, u, YEL_TOP, YEL_BOT)
	for sx in [-1.0, 1.0]:
		_cap(ci, Vector2(sx * 0.54 * u, -0.34 * u), Vector2(sx * 0.14 * u, -0.5 * u), 0.04 * u, OUT)
		var e := Vector2(sx * 0.3 * u, -0.1 * u)
		_oval(ci, e, 0.09 * u, 0.13 * u, DARK)
		ci.draw_circle(e + Vector2(-0.03 * u, -0.05 * u), 0.035 * u, WHITE)
	ci.draw_arc(Vector2(0, 0.62 * u), 0.26 * u, PI + 0.65, TAU - 0.65, 14, OUT, 0.07 * u, true)
	# A tear rolls down each cheek, one after the other.
	for k in 2:
		var f := fposmod(t * 0.95 + float(k) * 0.5, 1.0)
		var sx := -1.0 if k == 0 else 1.0
		var p := Vector2(sx * 0.32 * u, (0.04 + 0.7 * f) * u)
		_drop(ci, p, 0.1 * u, minf(1.0, (1.0 - f) * 3.0))


static func _cool(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	_xf(ci, c, Vector2.ZERO, sin(t * 3.0) * 0.03)
	_face(ci, u, YEL_TOP, YEL_BOT)
	# Sunglasses drop onto the nose at the start.
	var k := clampf(t / 0.32, 0.0, 1.0)
	var drop := (1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k)) # ease-out
	var gy := -0.2 * u - (1.0 - drop) * 0.9 * u
	var lens := Color(0.07, 0.08, 0.12)
	for sx in [-1.0, 1.0]:
		var rect := Rect2(Vector2(0.0 if sx > 0.0 else -0.62 * u, gy), Vector2(0.62 * u, 0.36 * u))
		rect.position.x += 0.03 * u * sx
		_lens(ci, rect, lens, 0.045 * u)
		# Glint across each lens.
		ci.draw_colored_polygon(PackedVector2Array([
			rect.position + Vector2(0.1 * u, 0.04 * u), rect.position + Vector2(0.2 * u, 0.04 * u),
			rect.position + Vector2(0.12 * u, 0.2 * u), rect.position + Vector2(0.02 * u, 0.2 * u)]), Color(1, 1, 1, 0.22))
	_cap(ci, Vector2(-0.04 * u, gy + 0.08 * u), Vector2(0.04 * u, gy + 0.08 * u), 0.04 * u, lens)
	ci.draw_line(Vector2(-0.62 * u, gy + 0.06 * u), Vector2(-0.88 * u, gy - 0.02 * u), OUT, 0.05 * u, true)
	ci.draw_line(Vector2(0.62 * u, gy + 0.06 * u), Vector2(0.88 * u, gy - 0.02 * u), OUT, 0.05 * u, true)
	# Smug smile with a smirk.
	ci.draw_arc(Vector2(0.02 * u, 0.12 * u), 0.4 * u, 0.35, PI - 0.5, 16, OUT, 0.075 * u, true)
	# A sparkle on the lens.
	if k >= 1.0:
		var sp := fposmod(t * 0.8, 1.0)
		_star(ci, Vector2(0.45 * u, gy + 0.06 * u), 0.2 * u * sin(sp * PI), WHITE, 0.0)


static func _think(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	_xf(ci, c, Vector2.ZERO, sin(t * 2.6) * 0.1)
	_face(ci, u, YEL_TOP, YEL_BOT)
	ci.draw_arc(Vector2(-0.32 * u, -0.34 * u), 0.2 * u, PI + 0.45, TAU - 0.45, 12, OUT, 0.07 * u, true)
	_cap(ci, Vector2(0.1 * u, -0.38 * u), Vector2(0.5 * u, -0.34 * u), 0.04 * u, OUT)
	for sx in [-1.0, 1.0]:
		var e := Vector2(sx * 0.3 * u, -0.1 * u)
		_oval(ci, e, 0.15 * u, 0.19 * u, WHITE, 0.035 * u)
		ci.draw_circle(e + Vector2(0.05 * u, -0.07 * u), 0.075 * u, DARK) # looking up and away
	# A flat, wobbly mouth pushed to one side.
	var pts := PackedVector2Array()
	for k in 12:
		var x := lerpf(-0.18, 0.36, float(k) / 11.0)
		pts.append(Vector2(x * u, (0.46 + 0.035 * sin(float(k) * 1.2 + t * 3.0)) * u))
	ci.draw_polyline(pts, OUT, 0.06 * u, true)
	# Thought dots pop in one by one.
	for k in 3:
		var phase := fposmod(t * 0.9, 1.6)
		if phase > 0.25 * float(k + 1):
			var s := (0.05 + 0.04 * float(k)) * u
			var p := Vector2((0.74 + 0.16 * float(k)) * u, (-0.62 - 0.2 * float(k)) * u)
			ci.draw_circle(p, s + 0.02 * u, OUT)
			ci.draw_circle(p, s, WHITE)


static func _oops(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	_xf(ci, c, Vector2(sin(t * 20.0) * 0.012 * u, 0.0), sin(t * 9.0) * 0.045)
	_face(ci, u, YEL_TOP, YEL_BOT)
	for sx in [-1.0, 1.0]:
		_oval(ci, Vector2(sx * 0.5 * u, 0.2 * u), 0.16 * u, 0.1 * u, Color(1.0, 0.4, 0.45, 0.55))
		_cap(ci, Vector2(sx * 0.5 * u, -0.34 * u), Vector2(sx * 0.14 * u, -0.46 * u), 0.04 * u, OUT)
		var e := Vector2(sx * 0.3 * u, -0.1 * u)
		_oval(ci, e, 0.15 * u, 0.19 * u, WHITE, 0.035 * u)
		var look := 0.07 * u * (1.0 if sin(t * 6.0) > 0.0 else -1.0) # shifty eyes
		ci.draw_circle(e + Vector2(look, 0.02 * u), 0.07 * u, DARK)
	# Gritted-teeth grimace.
	var m := Rect2(-0.36 * u, 0.3 * u, 0.72 * u, 0.26 * u)
	_box(ci, m, 0.09 * u, WHITE, 0.045 * u)
	for kx in [-0.18, 0.0, 0.18]:
		ci.draw_line(Vector2(kx * u, m.position.y), Vector2(kx * u, m.end.y), OUT, 0.03 * u, true)
	ci.draw_line(Vector2(m.position.x, m.position.y + m.size.y * 0.5), Vector2(m.end.x, m.position.y + m.size.y * 0.5), OUT, 0.03 * u, true)
	# Nervous sweat drop on the forehead.
	var f := fposmod(t * 0.8, 1.0)
	_drop(ci, Vector2(0.62 * u, (-0.5 + 0.35 * f) * u), 0.12 * u, minf(1.0, (1.0 - f) * 2.5))


static func _gg(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	var b := 0.5 + 0.5 * sin(t * 9.0)
	_xf(ci, c, Vector2(0.0, -0.04 * u * b), sin(t * 9.0) * 0.07, 1.0 + 0.06 * b)
	var skin_o := OUT
	# Sleeve cuff, then the curled fingers, the palm and the raised thumb.
	_box(ci, Rect2(-0.8 * u, -0.05 * u, 0.3 * u, 0.78 * u), 0.06 * u, Color(0.2, 0.42, 0.85), 0.05 * u, skin_o)
	_box(ci, Rect2(-0.5 * u, 0.0, 1.14 * u, 0.72 * u), 0.2 * u, YEL_BOT, 0.05 * u, skin_o)
	for k in 4:
		var y := (0.1 + 0.17 * float(k)) * u
		_cap_o(ci, Vector2(0.0, y), Vector2(0.4 * u, y), 0.095 * u, YEL_TOP, 0.04 * u)
	_cap_o(ci, Vector2(-0.18 * u, 0.12 * u), Vector2(-0.12 * u, -0.56 * u), 0.15 * u, YEL_TOP, 0.045 * u)
	ci.draw_circle(Vector2(-0.14 * u, -0.5 * u), 0.04 * u, Color(1, 1, 1, 0.55))
	# Twinkles.
	for k in 3:
		var p := [Vector2(0.62, -0.5), Vector2(0.78, -0.12), Vector2(-0.72, -0.62)][k] as Vector2
		var s := 0.5 + 0.5 * sin(t * 8.0 + float(k) * 2.1)
		_star(ci, p * u, (0.08 + 0.12 * s) * u, WHITE, float(k))


static func _clap(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	_xf(ci, c, Vector2.ZERO, 0.0)
	var k := 0.5 + 0.5 * sin(t * 15.0) # 0 = hands apart, 1 = hands together
	var gap := (0.06 + 0.34 * (1.0 - k)) * u
	var tilt := 0.1 + 0.3 * (1.0 - k)
	for sx in [-1.0, 1.0]:
		var base := Vector2(sx * (gap + 0.28 * u), 0.6 * u)
		var dir := Vector2(-sx * sin(tilt), -cos(tilt))
		var tip := base + dir * 1.05 * u
		_cap_o(ci, base, tip, 0.23 * u, YEL_BOT if sx < 0.0 else YEL_TOP, 0.045 * u)
		# Finger creases along the upper half of the hand.
		var side := Vector2(-dir.y, dir.x)
		for f in [-0.09, 0.0, 0.09]:
			ci.draw_line(base + dir * 0.6 * u + side * f * u, base + dir * 0.98 * u + side * f * u, Color(OUT, 0.55), 0.025 * u, true)
	# Impact rays when the palms meet.
	if k > 0.82:
		for q in 5:
			var a := -PI * 0.5 + (float(q) - 2.0) * 0.42
			var d := Vector2(cos(a), sin(a))
			ci.draw_line(Vector2(0, -0.46 * u) + d * 0.24 * u, Vector2(0, -0.46 * u) + d * 0.5 * u, WHITE, 0.07 * u, true)
		_star(ci, Vector2(0, -0.58 * u), 0.2 * u, Color(1.0, 0.95, 0.5), 0.0)


static func _hurry(ci: CanvasItem, c: Vector2, u: float, t: float) -> void:
	_xf(ci, c, Vector2(sin(t * 55.0) * 0.025 * u, 0.0), sin(t * 46.0) * 0.07)
	var cy := 0.08 * u
	var body := Color(0.86, 0.14, 0.18)
	# Bells, hammer and legs.
	for sx in [-1.0, 1.0]:
		var bp := Vector2(sx * 0.55 * u, -0.58 * u)
		ci.draw_circle(bp, 0.3 * u, OUT)
		ci.draw_circle(bp, 0.255 * u, Color(0.96, 0.78, 0.2))
		_cap(ci, Vector2(sx * 0.42 * u, 0.7 * u), Vector2(sx * 0.62 * u, 0.98 * u), 0.08 * u, OUT)
	ci.draw_line(Vector2(0, -0.78 * u), Vector2(0, -0.98 * u), OUT, 0.06 * u, true)
	# Body and face.
	ci.draw_circle(Vector2(0, cy), 0.8 * u, OUT)
	ci.draw_circle(Vector2(0, cy), 0.74 * u, body)
	ci.draw_circle(Vector2(0, cy), 0.58 * u, OUT)
	ci.draw_circle(Vector2(0, cy), 0.55 * u, Color(1.0, 0.97, 0.88))
	for q in 12:
		var a := TAU * float(q) / 12.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(Vector2(0, cy) + d * 0.43 * u, Vector2(0, cy) + d * 0.52 * u, OUT, 0.035 * u, true)
	var ha := t * 1.3 - PI * 0.5
	var ma := t * 13.0 - PI * 0.5
	ci.draw_line(Vector2(0, cy), Vector2(0, cy) + Vector2(cos(ha), sin(ha)) * 0.26 * u, OUT, 0.07 * u, true)
	ci.draw_line(Vector2(0, cy), Vector2(0, cy) + Vector2(cos(ma), sin(ma)) * 0.4 * u, Color(0.85, 0.1, 0.1), 0.05 * u, true)
	ci.draw_circle(Vector2(0, cy), 0.06 * u, OUT)
	# Ringing arcs on both sides.
	var ring := 0.5 + 0.5 * sin(t * 22.0)
	for sx in [-1.0, 1.0]:
		var base_a := 0.0 if sx > 0.0 else PI
		for j in 2:
			var rad := (0.98 + 0.13 * float(j)) * u
			ci.draw_arc(Vector2(0, cy), rad, base_a - 0.3, base_a + 0.3, 8, Color(1, 1, 1, (0.9 - 0.35 * float(j)) * (0.5 + 0.5 * ring)), 0.055 * u, true)


# ---------------------------------------------------------------- drawing helpers

static func _xf(ci: CanvasItem, c: Vector2, off: Vector2, rot: float, sc: float = 1.0) -> void:
	ci.draw_set_transform(c + off, rot, Vector2(sc, sc))


## The round emoji head: dark outline, a vertical yellow gradient built from stacked discs, a shine.
static func _face(ci: CanvasItem, u: float, top: Color, bottom: Color) -> void:
	ci.draw_circle(Vector2.ZERO, u, OUT)
	ci.draw_circle(Vector2.ZERO, u * 0.95, bottom)
	ci.draw_circle(Vector2(0, -u * 0.07), u * 0.87, bottom.lerp(top, 0.5))
	ci.draw_circle(Vector2(0, -u * 0.15), u * 0.72, top.lerp(bottom, 0.2))
	ci.draw_circle(Vector2(0, -u * 0.22), u * 0.55, top)
	_oval(ci, Vector2(-u * 0.4, -u * 0.58), u * 0.14, u * 0.07, Color(1, 1, 1, 0.4))


static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, line_w: float = 0.0, line: Color = OUT) -> void:
	if line_w > 0.0:
		_ell(ci, c, rx + line_w, ry + line_w, line)
	_ell(ci, c, rx, ry, fill)


static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var a := TAU * float(k) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


## A line segment with round ends.
static func _cap(ci: CanvasItem, a: Vector2, b: Vector2, hw: float, col: Color) -> void:
	var d := b - a
	var dist := d.length()
	ci.draw_circle(a, hw, col)
	ci.draw_circle(b, hw, col)
	if dist < 0.001:
		return
	var n := Vector2(-d.y, d.x) / dist * hw
	ci.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), col)


static func _cap_o(ci: CanvasItem, a: Vector2, b: Vector2, hw: float, fill: Color, line_w: float) -> void:
	_cap(ci, a, b, hw + line_w, OUT)
	_cap(ci, a, b, hw, fill)


static func _box(ci: CanvasItem, rect: Rect2, radius: float, fill: Color, border_w: float = 0.0, border: Color = OUT) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(maxi(1, int(radius)))
	sb.set_border_width_all(int(border_w))
	sb.border_color = border
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)


## A sunglasses lens: flat top, rounded bottom.
static func _lens(ci: CanvasItem, rect: Rect2, fill: Color, border_w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left = int(rect.size.y * 0.1)
	sb.corner_radius_top_right = int(rect.size.y * 0.1)
	sb.corner_radius_bottom_left = int(rect.size.y * 0.55)
	sb.corner_radius_bottom_right = int(rect.size.y * 0.55)
	sb.set_border_width_all(int(border_w))
	sb.border_color = OUT
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)


## A four-pointed sparkle.
static func _star(ci: CanvasItem, c: Vector2, rr: float, col: Color, rot: float) -> void:
	if rr <= 0.5:
		return
	var pts := PackedVector2Array()
	for k in 8:
		var a := rot + TAU * float(k) / 8.0
		var rad := rr if k % 2 == 0 else rr * 0.32
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(pts, col)


## A teardrop (tears, sweat). `s` is its rough size.
static func _drop(ci: CanvasItem, c: Vector2, s: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var col := Color(TEAR.r, TEAR.g, TEAR.b, alpha)
	var edge := Color(0.15, 0.4, 0.75, alpha)
	var body := c + Vector2(0, s * 0.35)
	ci.draw_circle(body, s * 0.62, edge)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.25), body + Vector2(s * 0.58, -s * 0.12), body + Vector2(-s * 0.58, -s * 0.12)]), edge)
	ci.draw_circle(body, s * 0.5, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.05), body + Vector2(s * 0.46, -s * 0.1), body + Vector2(-s * 0.46, -s * 0.1)]), col)
	ci.draw_circle(body + Vector2(-s * 0.18, -s * 0.05), s * 0.14, Color(1, 1, 1, alpha * 0.85))
