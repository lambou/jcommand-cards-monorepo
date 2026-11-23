extends Control
## Big tappable suit icon used by the "pick a suit" prompt after playing a J.
## The suit is a 3D Blender render that turns endlessly while idle and spins up when pressed.

const TextFx := preload("res://scripts/ui/text_fx.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")
const Suit3D := preload("res://scripts/ui/suit3d.gd")
const Settings := preload("res://scripts/game/settings.gd")

signal chosen(suit: String)

var suit := "H"
var _time := 0.0
var _spin := 0.0          # extra spin in degrees while pressed (tweened)
var _hover := 0.0         # 0..1 highlight


func _init(p_suit: String = "H") -> void:
	suit = p_suit
	custom_minimum_size = Vector2(185, 215)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2.0
	mouse_entered.connect(func(): _set_hover(1.0))
	mouse_exited.connect(func(): _set_hover(0.0))


func _set_hover(v: float) -> void:
	if Settings.reduce():
		return
	create_tween().tween_property(self, "_hover", v, 0.15)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or Settings.reduce():
		return
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if Settings.reduce():
			chosen.emit(suit)
			return
		# Quick spin + pop, then confirm.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween()
		tw.tween_property(self, "_spin", 360.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(self, "scale", Vector2(1.12, 1.12), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			chosen.emit(suit)
			_spin = 0.0
			scale = Vector2.ONE
			mouse_filter = Control.MOUSE_FILTER_STOP)


func _draw() -> void:
	var red := suit == "H" or suit == "D"
	var accent: Color = CardArt.RED if red else CardArt.BLACK
	var font := preload("res://assets/fonts/LilitaOne-Regular.ttf")
	var r := Rect2(Vector2.ZERO, size)

	# Card-like tile with a soft shadow; lifts and glows gold on hover/press.
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(26)
	box.bg_color = Color(0.99, 0.98, 0.95).lerp(Color(1.0, 0.95, 0.75), _hover * 0.7)
	box.set_border_width_all(5)
	box.border_color = Color(0.82, 0.68, 0.3).lerp(Color(1.0, 0.82, 0.2), _hover)
	box.shadow_color = Color(1.0, 0.82, 0.2, 0.55 * _hover) if _hover > 0.01 else Color(0, 0, 0, 0.35)
	box.shadow_size = int(10 + 14.0 * _hover)
	box.shadow_offset = Vector2(0, 6)
	draw_style_box(box, r)

	# Soft suit-coloured halo behind the 3D suit.
	var c := Vector2(size.x / 2.0, size.y * 0.42)
	for i in 5:
		var k := float(i) / 4.0
		draw_circle(c, 72.0 - k * 38.0, Color(accent.r, accent.g, accent.b, 0.05 + 0.03 * (1.0 - k) + 0.04 * _hover))

	var angle := _spin + Suit3D.idle(_time, float(suit.unicode_at(0)))
	if Settings.reduce():
		angle = 0.0
	Suit3D.draw(self, suit, c, 58, angle)

	# Name on a colour-coded ribbon along the bottom of the tile.
	var ribbon := Rect2(14, size.y - 50, size.x - 28, 36)
	var rb := StyleBoxFlat.new()
	rb.set_corner_radius_all(18)
	rb.bg_color = accent
	draw_style_box(rb, ribbon)
	TextFx.draw(self, font, Vector2(ribbon.position.x, ribbon.position.y + 27), CardArt.SUIT_NAMES[suit], HORIZONTAL_ALIGNMENT_CENTER, ribbon.size.x, 24, Color.WHITE)
