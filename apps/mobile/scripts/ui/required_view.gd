extends Control
## Pill showing what must be played next: a suit, a color, or any card.

const TextFx := preload("res://scripts/ui/text_fx.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")

var required: Dictionary = {"kind": "free"}


func _init() -> void:
	custom_minimum_size = Vector2(400, 92)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_required(r: Dictionary) -> void:
	required = r
	queue_redraw()


func _draw() -> void:
	var font := preload("res://assets/fonts/LilitaOne-Regular.ttf")
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(int(size.y / 2))
	box.bg_color = Color(0.07, 0.17, 0.30)
	box.set_border_width_all(5)
	box.border_color = Color(1.0, 0.82, 0.2)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var mid := Vector2(size.x * 0.62, size.y / 2.0)
	var plate := Color(0.98, 0.97, 0.94)
	match required["kind"]:
		"suit":
			draw_circle(mid, 34, Color(0.1, 0.05, 0.0))
			draw_circle(mid, 30, plate)
		"color":
			for dx in [-34, 34]:
				draw_circle(mid + Vector2(dx, 0), 31, Color(0.1, 0.05, 0.0))
				draw_circle(mid + Vector2(dx, 0), 27, plate)
	TextFx.draw(self, font, Vector2(28, size.y / 2.0 + 14), "PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	match required["kind"]:
		"suit":
			CardArt.draw_suit(self, required["suit"], mid, 28, CardArt.suit_color(required["suit"]))
		"color":
			var col: Color = CardArt.RED if required["color"] == "red" else CardArt.BLACK
			CardArt.draw_suit(self, "H" if required["color"] == "red" else "S", mid + Vector2(-34, 0), 24, col)
			CardArt.draw_suit(self, "D" if required["color"] == "red" else "C", mid + Vector2(34, 0), 24, col)
		_:
			TextFx.draw(self, font, Vector2(size.x * 0.46, size.y / 2.0 + 14), "ANY CARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
