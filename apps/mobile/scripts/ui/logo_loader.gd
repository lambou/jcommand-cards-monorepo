extends Control
## Loading indicator drawn from the app logo: the heart split into four suit pieces (red heart lobe,
## yellow diamond lobe, cream spade and green club halves), optionally on the gold-framed felt tile.
##
##   Spinning (progress < 0): the pieces hop outward one after another, clockwise, while a gold glint
##   runs round the frame.
##   Progress (0..1): each piece fills bottom-up in turn (heart, diamond, spade, club) and pops when full;
##   a gold trace grows round the frame from the top.
##   complete(): the heart beats twice and `completed` fires.
##
## Drawn procedurally, so it is sharp at any size (from a 64 px inline badge to the splash). Honours
## Reduce motion: no hops, pops or beats, only the pieces brightening in turn.
## Try it:   godot --path apps/mobile -- --loaderplay

signal completed

const UI := preload("res://scripts/ui/ui_kit.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")
const Settings := preload("res://scripts/game/settings.gd")

## Order the pieces light up in: clockwise from the top-left lobe.
const ORDER := ["H", "D", "S", "C"]
const PIECE_COLOR := {
	"H": Color(1.0, 0.42, 0.45),
	"D": Color(1.0, 0.85, 0.36),
	"S": Color(0.94, 0.92, 0.83),
	"C": Color(0.47, 0.86, 0.6),
}
const PIP_COLOR := Color(0.2, 0.27, 0.23, 0.85)
const FELT := Color(0.18, 0.47, 0.32)
const FRAME := Color(0.86, 0.66, 0.26)

## Logo geometry, in the 1024 px logo's pixels relative to the heart's centre.
const LOGO_PX := 1024.0
const GAP := 5.0           # half the width of the grooves between pieces
const SPLIT_Y := -30.0     # the cut between the lobes and the lower halves
const LOBE_R := 212.0      # lobe circle radius
const LOBE_D := 170.0      # lobe circle centres sit at x = +-LOBE_D (they overlap, giving the dip)
const LOBE_CY := -125.0    # lobe circle centre height
const TIP_Y := 336.0
const PIP := {"H": Vector2(-180, -125), "D": Vector2(180, -125), "S": Vector2(118, 78), "C": Vector2(-118, 78)}
const PIP_SIZE := 78.0

## Seconds for one lap of the spinner.
@export var period := 1.4
## Negative = spinning (unknown duration), 0..1 = how far loading has got.
@export var progress := -1.0:
	set(v):
		progress = clampf(v, -1.0, 1.0) if v >= 0.0 else -1.0
## Draw the gold-framed felt tile behind the heart (off for a bare heart on any background).
@export var show_tile := true
## Run the assemble-in animation when the loader enters the tree.
@export var assemble_on_ready := true
## Seconds the assemble-in takes (the screen transition uses a quicker one).
@export var assemble_time := 0.75
## Override Settings.reduce_motion (-1 = follow the setting, 0 = off, 1 = on).
var reduce_override := -1

var _t := 0.0
var _shown := 0.0           # displayed progress, eased toward `progress`
var _pop := [0.0, 0.0, 0.0, 0.0]   # per piece: 1 when it just filled, decays to 0
var _assemble := 1.0        # 0 = pieces scattered, 1 = in place
var _beat := -1.0           # seconds into the completion heartbeat, -1 = none
var _pieces := {}           # suit -> PackedVector2Array (logo px, relative to heart centre)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heart := _heart_outline()
	var far := 1000.0
	_pieces = {
		"H": _cut(heart, -far, -GAP, -far, SPLIT_Y - GAP),
		"D": _cut(heart, GAP, far, -far, SPLIT_Y - GAP),
		"C": _cut(heart, -far, -GAP, SPLIT_Y + GAP, far),
		"S": _cut(heart, GAP, far, SPLIT_Y + GAP, far),
	}


func _ready() -> void:
	if assemble_on_ready:
		assemble()


func _reduce() -> bool:
	return Settings.reduce() if reduce_override < 0 else reduce_override == 1


## Pieces fly in from around the heart and click into place.
func assemble() -> void:
	_assemble = 1.0 if _reduce() else 0.0
	queue_redraw()


## Finish: fills whatever is left, beats twice, then emits `completed` (at once with Reduce motion).
func complete() -> void:
	if progress >= 0.0:
		progress = 1.0
		_shown = 1.0
	if _reduce():
		_beat = -1.0
		completed.emit.call_deferred()
		return
	_beat = 0.0


## Shows the finished heart at once: progress 1, all pieces filled, no pops (a static logo).
func show_full() -> void:
	progress = 1.0
	_shown = 1.0
	_pop = [0.0, 0.0, 0.0, 0.0]
	_beat = -1.0
	queue_redraw()


## The progress the pieces currently show (it eases toward `progress`), so a caller can wait for it.
func shown_progress() -> float:
	return _shown


## True once the assemble-in has finished.
func is_assembled() -> bool:
	return _assemble >= 1.0


func reset() -> void:
	_shown = 0.0
	_beat = -1.0
	_pop = [0.0, 0.0, 0.0, 0.0]
	queue_redraw()


# ---------------------------------------------------------------- shapes

## The whole heart outline: two overlapping circles, and from each a straight line tangent to it down to
## the tip, so the sides flow out of the lobes without a kink. Clockwise from the tip.
func _heart_outline() -> PackedVector2Array:
	var cl := Vector2(-LOBE_D, LOBE_CY)
	var tip := Vector2(0.0, TIP_Y)
	var v := tip - cl
	var a_tan := atan2(v.y, v.x) + acos(LOBE_R / v.length())   # outer tangent point, lower left of the circle
	var a_dip := atan2(-sqrt(LOBE_R * LOBE_R - LOBE_D * LOBE_D), LOBE_D) + TAU  # where the circles cross at x = 0
	var left := PackedVector2Array()
	for i in 49:
		var a := lerpf(a_tan, a_dip, float(i) / 48.0)
		left.append(cl + Vector2(cos(a), sin(a)) * LOBE_R)
	var pts := PackedVector2Array([tip])
	pts.append_array(left)
	for i in range(left.size() - 2, -1, -1):   # the right lobe mirrors the left (skip the shared dip point)
		pts.append(Vector2(-left[i].x, left[i].y))
	return pts


## Cuts the heart into its four pieces along a cross, leaving a GAP-wide groove on each side of the cuts.
func _cut(heart: PackedVector2Array, x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	var rect := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	var best := PackedVector2Array()
	for poly in Geometry2D.intersect_polygons(heart, rect):
		if poly.size() > best.size():
			best = poly
	return best


func _centroid(p: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for v in p:
		c += v
	return c / float(p.size())


# ---------------------------------------------------------------- animation

func _process(frame_delta: float) -> void:
	if not is_visible_in_tree():
		return
	# A hitch (a heavy screen being built) slows the animation for a frame instead of making it jump.
	var delta := minf(frame_delta, 1.0 / 30.0)
	_t += delta
	if _assemble < 1.0:
		_assemble = minf(_assemble + delta / maxf(assemble_time, 0.01), 1.0)
	if progress >= 0.0:
		var before := _shown
		_shown = move_toward(_shown, progress, delta * maxf(0.6, absf(progress - _shown) * 4.0))
		for i in 4:
			var edge := float(i + 1) / 4.0
			if before < edge - 0.0001 and _shown >= edge - 0.0001 and not _reduce():
				_pop[i] = 1.0
	for i in 4:
		_pop[i] = maxf(_pop[i] - delta / 0.45, 0.0)
	if _beat >= 0.0:
		_beat += delta
		if _beat >= 0.9:
			_beat = -1.0
			completed.emit()
	queue_redraw()


## Smooth single bump: 0 at u = 0 and u = w, 1 at the middle, 0 elsewhere.
static func _bump(u: float, w: float) -> float:
	return sin(PI * u / w) if u >= 0.0 and u <= w else 0.0


func _heartbeat() -> float:
	if _beat < 0.0 or _reduce():
		return 1.0
	return 1.0 + 0.11 * _bump(_beat, 0.28) + 0.07 * _bump(_beat - 0.34, 0.3)


static func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 1.0:
		return
	var k := side / LOGO_PX * _heartbeat()
	var o := size / 2.0 + Vector2(0.0, 8.0 * side / LOGO_PX)   # the heart sits a touch low in the tile
	if show_tile:
		_draw_tile(side * _heartbeat())
	var reduce := _reduce()
	var spinning := progress < 0.0
	for i in 4:
		var suit: String = ORDER[i]
		var base: PackedVector2Array = _pieces[suit]
		var c := _centroid(base)
		var out_dir := c.normalized()
		var hop := 0.0
		var glow := 0.0
		if spinning and _beat < 0.0:
			var u := fposmod(_t / period - float(i) * 0.25, 1.0)
			var b := _bump(u, 0.4)
			glow = b
			hop = 0.0 if reduce else b
		else:
			hop = _pop[i]
			glow = _pop[i]
		# Assemble: each piece flies in from further out along its own diagonal, staggered.
		var a := clampf(_assemble * 1.6 - float(i) * 0.2, 0.0, 1.0)
		var settle := _ease_out_back(a)
		var offset := out_dir * (hop * 26.0 + (1.0 - settle) * 420.0)
		var sc := (1.0 + 0.07 * hop) * lerpf(0.4, 1.0, settle)
		var xf := func(p: Vector2) -> Vector2: return o + k * (c + (p - c) * sc + offset)
		var pts := _map(base, xf)
		var alpha := clampf(a * 3.0, 0.0, 1.0)
		var col: Color = PIECE_COLOR[suit]
		var fill := 1.0
		if not spinning:
			fill = clampf(_shown * 4.0 - float(i), 0.0, 1.0)
		elif reduce:
			col = col.darkened(0.18 * (1.0 - glow))
		_draw_piece(pts, base, xf, col, glow, fill, alpha, k * sc)
		var pip_col := PIP_COLOR
		pip_col.a *= alpha * (lerpf(0.35, 1.0, fill) if not spinning else 1.0)
		CardArt.draw_suit(self, suit, xf.call(PIP[suit]), PIP_SIZE * k * sc, pip_col)


func _map(p: PackedVector2Array, xf: Callable) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for j in p.size():
		out[j] = xf.call(p[j])
	return out


func _shifted(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for j in p.size():
		out[j] = p[j] + d
	return out


## One piece: soft shadow, darker lip below (the logo's chunky depth), the face, and a gloss band.
## `fill` < 1 draws an empty socket with the colour risen from the bottom that far.
func _draw_piece(pts: PackedVector2Array, base: PackedVector2Array, xf: Callable, col: Color, glow: float, fill: float, alpha: float, k: float) -> void:
	var depth := 14.0 * k
	if alpha <= 0.0:
		return
	var face := col.lerp(Color.WHITE, 0.25 * glow)
	if fill < 1.0:
		# The empty socket: a dark recess in the piece's outline.
		draw_colored_polygon(pts, Color(0.02, 0.12, 0.07, 0.45 * alpha))
		draw_polyline(_closed(pts), Color(col, 0.35 * alpha), maxf(2.0, 5.0 * k), true)
		if fill <= 0.0:
			return
		# Rising colour: clip the piece (in logo space) to a band from the bottom up.
		var lo := 1e9
		var hi := -1e9
		for v in base:
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
		var level := lerpf(hi, lo, fill)
		var band := PackedVector2Array([Vector2(-600, level), Vector2(600, level), Vector2(600, hi + 10), Vector2(-600, hi + 10)])
		for poly in Geometry2D.intersect_polygons(base, band):
			draw_colored_polygon(_map(poly, xf), Color(face, alpha))
		return
	draw_colored_polygon(_shifted(pts, Vector2(0, depth * 2.2)), Color(0, 0, 0, 0.22 * alpha))
	draw_colored_polygon(_shifted(pts, Vector2(0, depth)), Color(col.darkened(0.32), alpha))
	draw_colored_polygon(pts, Color(face, alpha))
	# Gloss on the upper part of the face.
	var top := 1e9
	for v in base:
		top = minf(top, v.y)
	var gloss := PackedVector2Array([Vector2(-600, top - 10), Vector2(600, top - 10), Vector2(600, top + 70), Vector2(-600, top + 70)])
	for poly in Geometry2D.intersect_polygons(base, gloss):
		draw_colored_polygon(_map(poly, xf), Color(1, 1, 1, (0.16 + 0.2 * glow) * alpha))


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	out.append(p[0])
	return out


## The rounded gold frame and felt, with the glint (spinning) or progress trace (progress) on the frame.
func _draw_tile(side: float) -> void:
	var r := Rect2(size / 2.0 - Vector2(side, side) / 2.0, Vector2(side, side))
	var radius := side * 0.2
	var border := side * 0.055
	var sb := StyleBoxFlat.new()
	sb.bg_color = FELT
	sb.border_color = FRAME
	sb.set_border_width_all(int(maxf(border, 1.0)))
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 16
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = int(side * 0.03)
	sb.shadow_offset = Vector2(0, side * 0.02)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	# Inner bevel: a lighter line just inside the gold, a darker one inside that.
	var path := _rounded_path(r.grow(-border * 0.5), radius - border * 0.5)
	draw_polyline(path, Color(1.0, 0.9, 0.6, 0.55), maxf(border * 0.22, 1.0), true)
	var inner := _rounded_path(r.grow(-border * 1.05), radius - border)
	draw_polyline(inner, Color(0, 0, 0, 0.18), maxf(border * 0.35, 1.0), true)

	if _beat >= 0.0:
		draw_polyline(path, Color(1.0, 0.95, 0.75, 0.9 * _bump(_beat, 0.6)), maxf(border * 0.55, 1.5), true)
	elif progress < 0.0:
		if not _reduce():
			var head := fposmod(_t / period, 1.0)
			_draw_trace(path, head - 0.22, head, Color(1.0, 0.97, 0.8), border * 0.55, true)
	else:
		_draw_trace(path, 0.0, _shown, Color(1.0, 0.95, 0.72), border * 0.55, false)


## Part of a closed path between fractions `a` and `b` of its length (wrapping), optionally fading in from `a`.
func _draw_trace(path: PackedVector2Array, a: float, b: float, col: Color, width: float, fade: bool) -> void:
	if b - a <= 0.0005:
		return
	var n := path.size() - 1
	var steps := maxi(int((b - a) * float(n)), 2)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for s in steps + 1:
		var f := lerpf(a, b, float(s) / float(steps))
		pts.append(_along(path, fposmod(f, 1.0)))
		var c := col
		if fade:
			c.a *= float(s) / float(steps)
		cols.append(c)
	draw_polyline_colors(pts, cols, maxf(width, 1.5), true)


## The point at fraction `f` of the path (its points are evenly spaced, see _rounded_path).
func _along(path: PackedVector2Array, f: float) -> Vector2:
	var x := f * float(path.size() - 1)
	var i := mini(int(x), path.size() - 2)
	return path[i].lerp(path[i + 1], x - float(i))


## Closed, evenly spaced path round a rounded rect, starting at the top centre and going clockwise.
func _rounded_path(r: Rect2, radius: float) -> PackedVector2Array:
	radius = clampf(radius, 0.0, minf(r.size.x, r.size.y) / 2.0)
	var raw := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI / 2.0],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI / 2.0],
		[Vector2(r.position.x + radius, r.position.y + radius), PI],
	]
	raw.append(Vector2(r.get_center().x, r.position.y))
	for cr in corners:
		for j in 13:
			var ang: float = cr[1] + PI / 2.0 * float(j) / 12.0
			raw.append(cr[0] + Vector2(cos(ang), sin(ang)) * radius)
	raw.append(raw[0])
	# Resample to even spacing so a fraction of the points is a fraction of the length.
	var total := 0.0
	for j in raw.size() - 1:
		total += raw[j].distance_to(raw[j + 1])
	var count := 240
	var out := PackedVector2Array([raw[0]])
	var seg := 0
	var seg_start := 0.0
	for s in range(1, count + 1):
		var want := total * float(s) / float(count)
		while seg < raw.size() - 2 and seg_start + raw[seg].distance_to(raw[seg + 1]) < want:
			seg_start += raw[seg].distance_to(raw[seg + 1])
			seg += 1
		var seg_len := raw[seg].distance_to(raw[seg + 1])
		out.append(raw[seg].lerp(raw[seg + 1], clampf((want - seg_start) / maxf(seg_len, 0.0001), 0.0, 1.0)))
	return out
