extends Control
## Pill showing what must be played next: a suit, a color, or any card.

const TextFx := preload("res://scripts/ui/text_fx.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")
const Suit3D := preload("res://scripts/ui/suit3d.gd")
const Settings := preload("res://scripts/game/settings.gd")

var required: Dictionary = {"kind": "free"}
var _angle := 0.0     # extra spin (360 -> 0) added to the idle turn when the requirement changes
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(400, 92)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_required(r: Dictionary) -> void:
	var changed := r != required
	required = r
	if changed and r.get("kind", "") != "free" and not Settings.reduce():
		# One full turn that eases out to face front. It is added on top of the idle turn (not
		# swapped for it), so the hand-off at the end is seamless.
		_angle = 360.0
		var tw := create_tween()
		tw.tween_property(self, "_angle", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _process(delta: float) -> void:
	# Redraw while turning so the 3D suit stays alive.
	if Settings.reduce() or required.get("kind", "free") == "free" or not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _suit_angle(phase: float) -> float:
	if Settings.reduce():
		return 0.0
	return _angle + Suit3D.idle(_time, phase)


func _draw() -> void:
	var font := preload("res://assets/fonts/LilitaOne-Regular.ttf")
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(int(size.y / 2))
	box.bg_color = Color(0.07, 0.17, 0.30)
	box.set_border_width_all(5)
	box.border_color = Color(1.0, 0.82, 0.2)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var mid := Vector2(size.x * 0.62, size.y / 2.0)
	# Flat fallback suits need a light plate to be readable; the 3D suits never get one (a light
	# disc would show as a white spot whenever the suit turns edge-on).
	var flat := not Suit3D.available()
	var plate := Color(0.98, 0.97, 0.94) if flat else Color(0.11, 0.25, 0.42)
	var rim := Color(0.1, 0.05, 0.0) if flat else Color(1.0, 0.82, 0.2, 0.55)
	match required["kind"]:
		"suit":
			draw_circle(mid, 34, rim)
			draw_circle(mid, 31 if not flat else 30, plate)
		"color":
			for dx in [-34, 34]:
				draw_circle(mid + Vector2(dx, 0), 31, rim)
				draw_circle(mid + Vector2(dx, 0), 28 if not flat else 27, plate)
	TextFx.draw(self, font, Vector2(28, size.y / 2.0 + 14), "PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	match required["kind"]:
		"suit":
			Suit3D.draw(self, required["suit"], mid, 28, _suit_angle(0.0))
		"color":
			var red: bool = required["color"] == "red"
			Suit3D.draw(self, "H" if red else "S", mid + Vector2(-34, 0), 24, _suit_angle(0.0))
			Suit3D.draw(self, "D" if red else "C", mid + Vector2(34, 0), 24, _suit_angle(1.7))
		_:
			TextFx.draw(self, font, Vector2(size.x * 0.46, size.y / 2.0 + 14), "ANY CARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
