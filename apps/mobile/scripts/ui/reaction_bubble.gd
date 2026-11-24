extends Control
## One reaction sticker popping out of a seat: it bounces in, plays its animation, floats up a
## little and fades out, then frees itself. Spawn it with `ReactionBubble.spawn(...)`.

const Art := preload("res://scripts/ui/reaction_art.gd")
const TextFx := preload("res://scripts/ui/text_fx.gd")
const Reactions := preload("res://scripts/game/reactions.gd")
const Settings := preload("res://scripts/game/settings.gd")

const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const CAPTION_H := 54.0

var id := ""
var radius := 62.0
var caption := ""
var _t := 0.0


## Creates a sticker whose disc is centred on `center` (in `parent`'s coordinates).
static func spawn(parent: Control, p_id: String, center: Vector2, p_radius: float = 62.0) -> Control:
	var b = new()
	b.id = p_id
	b.radius = p_radius
	b.caption = str(Reactions.info(p_id).get("caption", ""))
	var w := maxf(p_radius * 2.6, 260.0 if b.caption != "" else 0.0)
	b.size = Vector2(w, p_radius * 2.4 + CAPTION_H)
	b.pivot_offset = Vector2(w / 2.0, p_radius * 1.2)
	# Keep the whole sticker on screen even next to the edges.
	var margin := w / 2.0 + 6.0
	var cx := clampf(center.x, margin, maxf(parent.size.x - margin, margin))
	var cy := maxf(center.y, p_radius * 1.2 + 4.0)
	b.position = Vector2(cx, cy) - b.pivot_offset
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	b.play()
	return b


func play() -> void:
	var reduce := Settings.reduce()
	var hold := Reactions.SEAT_SHOW
	if reduce:
		_t = 0.9 # a calm still frame of the animation
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.15)
		tw.tween_interval(hold - 0.5)
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)
		return
	scale = Vector2(0.15, 0.15)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.1)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold - 0.34 - 0.35)
	tw.tween_property(self, "position:y", position.y - 26.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if Settings.reduce():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x / 2.0, radius * 1.2)
	Art.draw(self, id, c, radius, _t)
	if caption == "":
		return
	var fs := 40
	var tw := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pill := Rect2(Vector2(size.x / 2.0 - tw / 2.0 - 22.0, c.y + radius * 1.05), Vector2(tw + 44.0, 48.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.05, 0.0, 0.85)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(3)
	sb.border_color = Art.BACKING.get(id, Color.WHITE).lightened(0.2)
	sb.anti_aliasing = true
	draw_style_box(sb, pill)
	draw_string(FONT, Vector2(pill.position.x, pill.position.y + 37.0), caption, HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, fs, Color(1.0, 0.92, 0.55))
