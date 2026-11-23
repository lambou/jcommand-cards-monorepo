extends RefCounted
## Placeholder vector art: suit symbols and the lion, drawn with polygons/circles.

const RED := Color(0.80, 0.09, 0.12)
const BLACK := Color(0.10, 0.10, 0.14)

const SUIT_NAMES := {"H": "Hearts", "D": "Diamonds", "C": "Clubs", "S": "Spades"}


static func suit_color(suit: String) -> Color:
	return RED if (suit == "H" or suit == "D") else BLACK


static func draw_suit(ci: CanvasItem, suit: String, c: Vector2, s: float, col: Color) -> void:
	match suit:
		"D":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(0.68 * s, 0), c + Vector2(0, s), c + Vector2(-0.68 * s, 0)]), col)
		"H":
			ci.draw_circle(c + Vector2(-0.3 * s, -0.3 * s), 0.4 * s, col)
			ci.draw_circle(c + Vector2(0.3 * s, -0.3 * s), 0.4 * s, col)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.68 * s, -0.12 * s), c + Vector2(0.68 * s, -0.12 * s), c + Vector2(0, 0.9 * s)]), col)
		"S":
			ci.draw_circle(c + Vector2(-0.3 * s, 0.14 * s), 0.4 * s, col)
			ci.draw_circle(c + Vector2(0.3 * s, 0.14 * s), 0.4 * s, col)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.68 * s, 0.1 * s), c + Vector2(0.68 * s, 0.1 * s), c + Vector2(0, -0.95 * s)]), col)
			_stem(ci, c, s, col)
		"C":
			ci.draw_circle(c + Vector2(0, -0.42 * s), 0.34 * s, col)
			ci.draw_circle(c + Vector2(-0.4 * s, 0.1 * s), 0.34 * s, col)
			ci.draw_circle(c + Vector2(0.4 * s, 0.1 * s), 0.34 * s, col)
			ci.draw_circle(c + Vector2(0, -0.05 * s), 0.3 * s, col)
			_stem(ci, c, s, col)


static func _stem(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-0.1 * s, 0.25 * s), c + Vector2(0.1 * s, 0.25 * s),
		c + Vector2(0.24 * s, 0.92 * s), c + Vector2(-0.24 * s, 0.92 * s)]), col)


## A simple lion face; mane color = the lion's color.
static func draw_lion(ci: CanvasItem, color_name: String, c: Vector2, s: float) -> void:
	var mane := RED if color_name == "red" else BLACK
	var n := 12
	for i in n:
		var a := TAU * float(i) / float(n)
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * 0.78 * s, 0.34 * s, mane)
	ci.draw_circle(c, 0.82 * s, mane)
	ci.draw_circle(c, 0.6 * s, Color(0.96, 0.80, 0.42))
	ci.draw_circle(c + Vector2(-0.22 * s, -0.12 * s), 0.08 * s, Color(0.1, 0.1, 0.1))
	ci.draw_circle(c + Vector2(0.22 * s, -0.12 * s), 0.08 * s, Color(0.1, 0.1, 0.1))
	var nose := Color(0.35, 0.15, 0.15)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-0.1 * s, 0.05 * s), c + Vector2(0.1 * s, 0.05 * s), c + Vector2(0, 0.18 * s)]), nose)
	ci.draw_line(c + Vector2(0, 0.18 * s), c + Vector2(0, 0.3 * s), nose, 0.04 * s + 1.0)
	ci.draw_arc(c + Vector2(-0.1 * s, 0.3 * s), 0.1 * s, 0.0, PI * 0.9, 8, nose, 0.04 * s + 1.0)
	ci.draw_arc(c + Vector2(0.1 * s, 0.3 * s), 0.1 * s, PI * 0.1, PI, 8, nose, 0.04 * s + 1.0)
