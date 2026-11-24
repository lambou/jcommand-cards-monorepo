extends Control
## Lights walking around the card on top of the pile (the one that changed the suit), over a soft halo.
## Stays on until hide_lights() (a new card landed on the pile) or its duration runs out, whichever
## comes first. Never blocks input.

var target: Control
var alpha := 0.0
var _t := 0.0
var _tw: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func show_on(card: Control, duration: float = 0.0) -> void:
	target = card
	visible = true
	set_process(true)
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "alpha", 1.0, 0.25)
	if duration > 0.0:
		_tw.tween_interval(maxf(duration - 0.25, 0.0))
		_tw.tween_callback(hide_lights)


## Fades out quickly and stops drawing.
func hide_lights() -> void:
	if not visible:
		return
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "alpha", 0.0, 0.15)
	_tw.tween_callback(func():
		visible = false
		set_process(false))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Lights walking around the card's edge: three bright comets with fading tails, over a soft halo.
func _draw() -> void:
	if target == null or not is_instance_valid(target) or alpha <= 0.0:
		return
	var env := alpha
	var t := _t
	var rect := Rect2(target.position, target.size).grow(7.0)
	var r := 22.0
	var w := rect.size.x - 2.0 * r
	var h := rect.size.y - 2.0 * r
	var arc := PI * 0.5 * r
	var total := 2.0 * (w + h) + 4.0 * arc
	# Soft halo: rings fading outwards, drawn outside the card only so its face stays pure white.
	var pulse := 0.8 + 0.2 * sin(t * 7.0)
	for ring in 7:
		var g := rect.grow(float(ring) * 5.0)
		var rw := g.size.x - 2.0 * (r + ring * 5.0)
		var rh := g.size.y - 2.0 * (r + ring * 5.0)
		var rr := r + float(ring) * 5.0
		var ra := PI * 0.5 * rr
		var rt := 2.0 * (rw + rh) + 4.0 * ra
		var pts := PackedVector2Array()
		for j in 49:
			pts.append(_perimeter(g, rr, rw, rh, ra, rt, float(j % 48) / 48.0 * rt))
		draw_polyline(pts, Color(1.0, 0.85, 0.4, 0.2 * pulse * env * (1.0 - float(ring) / 7.0)), 6.0, true)
	var n := 40
	for i in n:
		var u := float(i) / float(n)
		var light := 0.18
		for k in 3:
			var d := fposmod(t * 0.45 + float(k) / 3.0 - u, 1.0) # distance behind a comet's head
			light = maxf(light, exp(-d * 8.0))
		var p := _perimeter(rect, r, w, h, arc, total, u * total)
		draw_circle(p, 13.0 * light, Color(1.0, 0.85, 0.4, 0.25 * light * env))
		draw_circle(p, 3.0 + 4.0 * light, Color(1.0, 0.97, 0.8, (0.35 + 0.65 * light) * env))


## Point at distance `s` along the rounded rectangle's edge, clockwise from the top-left corner's end.
func _perimeter(rect: Rect2, r: float, w: float, h: float, arc: float, _total: float, s: float) -> Vector2:
	var tl := rect.position
	if s < w:
		return tl + Vector2(r + s, 0)
	s -= w
	if s < arc:
		return _corner(tl + Vector2(r + w, r), r, -PI * 0.5 + s / r)
	s -= arc
	if s < h:
		return tl + Vector2(rect.size.x, r + s)
	s -= h
	if s < arc:
		return _corner(tl + Vector2(r + w, r + h), r, s / r)
	s -= arc
	if s < w:
		return tl + Vector2(r + w - s, rect.size.y)
	s -= w
	if s < arc:
		return _corner(tl + Vector2(r, r + h), r, PI * 0.5 + s / r)
	s -= arc
	if s < h:
		return tl + Vector2(0, r + h - s)
	s -= h
	return _corner(tl + Vector2(r, r), r, PI + s / r)


func _corner(c: Vector2, r: float, a: float) -> Vector2:
	return c + Vector2.from_angle(a) * r
