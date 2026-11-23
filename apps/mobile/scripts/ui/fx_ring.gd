extends Control
## An expanding, fading ring (shockwave). Animate `t` from 0 to 1.

var color := Color.WHITE
var max_radius := 150.0
var line_width := 10.0
var t := 0.0:
	set(v):
		t = v
		queue_redraw()


func _draw() -> void:
	var a := clampf(1.0 - t, 0.0, 1.0)
	draw_arc(Vector2.ZERO, max_radius * t, 0.0, TAU, 56, Color(color.r, color.g, color.b, a * color.a), maxf(line_width * (1.0 - t * 0.7), 1.0), true)
