extends RefCounted
## Clash-style text: a thick dark outline drawn under the fill.

const OUTLINE := Color(0.1, 0.05, 0.0)


static func draw(ci: CanvasItem, font: Font, pos: Vector2, text: String, align: HorizontalAlignment,
		width: float, font_size: int, fill: Color, outline: Color = OUTLINE) -> void:
	outline.a = fill.a
	ci.draw_string_outline(font, pos, text, align, width, font_size, maxi(3, int(font_size * 0.25)), outline)
	ci.draw_string(font, pos, text, align, width, font_size, fill)
