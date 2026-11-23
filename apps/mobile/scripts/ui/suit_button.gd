extends Control
## Big tappable suit icon used by the "pick a suit" prompt after playing a J.

const TextFx := preload("res://scripts/ui/text_fx.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")

signal chosen(suit: String)

var suit := "H"


func _init(p_suit: String = "H") -> void:
	suit = p_suit
	custom_minimum_size = Vector2(190, 190)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(suit)
		accept_event()


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(26)
	box.bg_color = Color(0.98, 0.97, 0.94)
	box.set_border_width_all(4)
	box.border_color = Color(0.25, 0.25, 0.3)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	CardArt.draw_suit(self, suit, size / 2.0 + Vector2(0, -6), 52, CardArt.suit_color(suit))
	TextFx.draw(self, preload("res://assets/fonts/LilitaOne-Regular.ttf"), Vector2(0, size.y - 14), CardArt.SUIT_NAMES[suit], HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color.WHITE)
