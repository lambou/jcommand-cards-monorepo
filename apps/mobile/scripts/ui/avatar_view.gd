extends Control
## A standalone avatar (used for your own portrait beside the hand).

const TextFx := preload("res://scripts/ui/text_fx.gd")
const Avatar := preload("res://scripts/ui/avatar.gd")
const Settings := preload("res://scripts/game/settings.gd")

## The CHECK! plate runs from size.y - 10 to size.y + 26. The points label under the avatar
## drops by CHECK_DROP while the plate is up, so the two stack instead of overlapping.
const CHECK_PLATE_H := 36.0
const CHECK_DROP := 30.0

var avatar_index := 0
var check := false:
	set(v):
		check = v
		queue_redraw()
var active := false:
	set(v):
		active = v
		queue_redraw()


func _init(p_index: int = 0) -> void:
	avatar_index = p_index
	size = Vector2(110, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true) # idle animation


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0 - 4.0
	var pulse := 0.5 if Settings.reduce() else 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * 0.5)
	var ring := Color(1.0, 0.82, 0.2) if active else Color(1, 1, 1, 0.6)
	if check:
		draw_circle(size / 2.0, r + 6.0 + 4.0 * pulse, Color(1.0, 0.75, 0.2, 0.18 + 0.1 * pulse))
		ring = Color(1.0, 0.82, 0.2)
	Avatar.draw_avatar(self, avatar_index, size / 2.0, r, ring, 7.0 if (active or check) else 3.0, false, false, active)
	if check:
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color(0.98, 0.78, 0.2)
		badge.set_corner_radius_all(12)
		badge.set_border_width_all(3)
		badge.border_color = Color.WHITE
		var br := Rect2(-8.0, size.y - 10.0, size.x + 16.0, CHECK_PLATE_H)
		draw_style_box(badge, br)
		TextFx.draw(self, preload("res://assets/fonts/LilitaOne-Regular.ttf"), Vector2(br.position.x, br.position.y + 27.0), "CHECK!", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 26, Color.WHITE)
