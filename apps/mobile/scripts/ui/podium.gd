extends Control
## Results podium: 1st in the middle, 2nd on the left, 3rd on the right. The blocks rise one after
## another (3rd, 2nd, 1st) with the players' avatars riding on top; 4th place gets a small row below.

const TextFx := preload("res://scripts/ui/text_fx.gd")
const Avatar := preload("res://scripts/ui/avatar.gd")

signal first_landed

const GOLD := Color(0.98, 0.78, 0.2)
const SILVER := Color(0.78, 0.80, 0.86)
const BRONZE := Color(0.80, 0.50, 0.26)
const DESIGN_H := 760.0

var order: Array = [] # player ids, 1st first
var names: Dictionary = {}
var me := "you"

var r0 := 0.0:
	set(v):
		r0 = v
		queue_redraw()
var r1 := 0.0:
	set(v):
		r1 = v
		queue_redraw()
var r2 := 0.0:
	set(v):
		r2 = v
		queue_redraw()
var r3 := 0.0:
	set(v):
		r3 = v
		queue_redraw()


func setup(p_order: Array, p_names: Dictionary, p_me: String) -> void:
	order = p_order
	names = p_names
	me = p_me
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## Raises the podium: 3rd, then 2nd, then 1st.
func play() -> void:
	var tw := create_tween()
	var rise := 0.55
	if order.size() >= 4:
		tw.tween_property(self, "r3", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if order.size() >= 3:
		tw.tween_property(self, "r2", 1.0, rise).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if order.size() >= 2:
		tw.tween_property(self, "r1", 1.0, rise).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	tw.tween_property(self, "r0", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	tw.tween_callback(func(): first_landed.emit())


func _draw() -> void:
	if order.is_empty():
		return
	var font := preload("res://assets/fonts/LilitaOne-Regular.ttf")
	var u := size.y / DESIGN_H
	var step_w := minf(size.x * 0.29, 320.0)
	var gap := 12.0
	var cx := size.x / 2.0
	var base_y := size.y - (130.0 * u if order.size() >= 4 else 24.0 * u)
	var centers := [cx, cx - (step_w + gap), cx + (step_w + gap)]
	var heights := [340.0 * u, 250.0 * u, 175.0 * u]
	var colors := [GOLD, SILVER, BRONZE]
	var rises := [r0, r1, r2]

	for place in mini(order.size(), 3):
		var id: String = order[place]
		var rise: float = rises[place]
		var bh: float = heights[place] * rise
		var x: float = centers[place] - step_w / 2.0
		var top := base_y - bh
		var col: Color = colors[place]

		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.corner_radius_top_left = int(16 * u)
		sb.corner_radius_top_right = int(16 * u)
		draw_style_box(sb, Rect2(x, top, step_w, bh))
		draw_rect(Rect2(x, top, step_w, 10.0 * u), col.lightened(0.35)) # lit top edge
		draw_rect(Rect2(x + step_w * 0.5, top, step_w * 0.5, bh), Color(0, 0, 0, 0.1)) # shaded right half

		if rise > 0.3:
			var a := clampf((rise - 0.3) / 0.5, 0.0, 1.0)
			var dark := Color(1, 1, 1, a)
			TextFx.draw(self, font, Vector2(x, top + 112.0 * u), str(place + 1), HORIZONTAL_ALIGNMENT_CENTER, step_w, int(120.0 * u), dark)
			var is_me := id == me
			var name_col := Color(1, 1, 1, a)
			TextFx.draw(self, font, Vector2(x, top + 112.0 * u + 52.0 * u), str(names.get(id, id)), HORIZONTAL_ALIGNMENT_CENTER, step_w, int(42.0 * u), name_col)

		# The avatar rides on top of its block.
		var ar := (68.0 if place == 0 else 56.0) * u
		var ac := Vector2(centers[place], top - ar - 8.0 * u)
		var ring := col.lightened(0.2)
		Avatar.draw_avatar(self, Avatar.index_for(id), ac, ar, ring, 7.0 * u, place == 0)
		if place == 0 and rise > 0.9:
			_crown(ac + Vector2(0, -ar - 4.0 * u), 46.0 * u)
		if id == me and rise > 0.5:
			var tag_y := ac.y - ar - (62.0 * u if place == 0 else 14.0 * u)
			TextFx.draw(self, font, Vector2(centers[place] - 80.0, tag_y), "YOU", HORIZONTAL_ALIGNMENT_CENTER, 160.0, int(38.0 * u), Color(1.0, 0.9, 0.35))

	# 4th place: a small row under the podium.
	if order.size() >= 4 and r3 > 0.0:
		var id4: String = order[3]
		var ar4 := 34.0 * u
		var y4 := size.y - 52.0 * u
		var label := "4th   %s" % str(names.get(id4, id4))
		var col4 := Color(1, 1, 1, r3)
		TextFx.draw(self, font, Vector2(cx - 100.0 * u, y4 + 12.0 * u), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(40.0 * u), col4)
		Avatar.draw_avatar(self, Avatar.index_for(id4), Vector2(cx - 150.0 * u, y4), ar4, Color(1, 1, 1, 0.5 * r3), 3.0)


func _crown(c: Vector2, w: float) -> void:
	var h := w * 0.7
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-w, 0), c + Vector2(-w, -h * 0.9), c + Vector2(-w * 0.5, -h * 0.4), c + Vector2(0, -h),
		c + Vector2(w * 0.5, -h * 0.4), c + Vector2(w, -h * 0.9), c + Vector2(w, 0)]), GOLD)
	draw_rect(Rect2(c.x - w, c.y - h * 0.18, w * 2.0, h * 0.22), GOLD.darkened(0.15))
	for k in [-1.0, 0.0, 1.0]:
		draw_circle(c + Vector2(k * w * 0.62, -h * (0.95 if k == 0.0 else 0.8)), h * 0.1, Color(0.9, 0.2, 0.25))
