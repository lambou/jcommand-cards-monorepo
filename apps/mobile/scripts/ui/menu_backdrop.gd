extends Control
## Menu background: the felt gradient, a faint suit pattern woven into it, and a few of the game's own cards
## scattered round the edges (tilted, partly off-screen, a little shaded). Purely decorative: ignores input,
## and the same layout every launch. Cards are real CardViews so they always match the table art.

const UI := preload("res://scripts/ui/ui_kit.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")
const CardView := preload("res://scripts/ui/card_view.gd")

const PATTERN_STEP := 132.0          # grid spacing of the suit pattern
const PATTERN_SIZE := 30.0           # suit glyph size in the pattern
const PATTERN_COL := Color(0.6, 1.0, 0.75, 0.05)
const CARD_SCALE := 1.15
const CARD_TINT := Color(0.8, 0.86, 0.82, 0.92)   # shaded so the cards sit back behind the menu

## [x, y] as fractions of the screen (card centre), rotation in degrees, card ("" = back, else rank+suit).
## Kept to the margins and corners: the menu column covers roughly x 0.14..0.86.
const SCATTER := [
	[0.36, -0.015, -9.0, ""],
	[0.52, -0.02, 11.0, "10C"],
	[0.80, 0.0, -22.0, "9S"],
	[0.98, 0.16, 28.0, ""],
	[0.95, 0.29, 14.0, "4S"],
	[-0.01, 0.24, 32.0, ""],
	[0.05, 0.36, -12.0, "5D"],
	[0.97, 0.56, -16.0, "3C"],
	[0.02, 0.78, -24.0, ""],
	[0.0, 0.88, 14.0, "6S"],
	[0.98, 0.84, -20.0, "4D"],
	[0.33, 1.02, 16.0, ""],
]

var _cards: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # a screen blocks input behind it
	clip_contents = true
	var grad := UI.background()
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)
	var pattern := Control.new()
	pattern.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pattern.draw.connect(_draw_pattern.bind(pattern))
	pattern.resized.connect(pattern.queue_redraw)
	add_child(pattern)
	for i in SCATTER.size():
		var spec: Array = SCATTER[i]
		var v := CardView.new()
		var id: String = spec[3]
		if id == "":
			v.set_card({"id": 900 + i}, false)
		else:
			var suit := id.right(1)
			v.set_card({"id": 900 + i, "rank": id.left(id.length() - 1), "suit": suit, "color": "red" if suit in ["H", "D"] else "black"})
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.pivot_offset = v.size / 2.0
		v.rotation = deg_to_rad(spec[2])
		v.scale = Vector2.ONE * CARD_SCALE
		v.modulate = CARD_TINT
		add_child(v)
		_cards.append(v)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	for i in _cards.size():
		var spec: Array = SCATTER[i]
		var v := _cards[i]
		v.position = Vector2(spec[0] * size.x, spec[1] * size.y) - v.size / 2.0


## Staggered grid of all four suits, barely lighter than the felt.
func _draw_pattern(c: Control) -> void:
	var suits := ["S", "H", "D", "C"]
	var row := 0
	var y := PATTERN_STEP * 0.5
	while y < c.size.y + PATTERN_STEP:
		var x := PATTERN_STEP * (0.25 if row % 2 == 0 else 0.75)
		var col_i := 0
		while x < c.size.x + PATTERN_STEP:
			CardArt.draw_suit(c, suits[(row + col_i) % 4], Vector2(x, y), PATTERN_SIZE, PATTERN_COL)
			x += PATTERN_STEP
			col_i += 1
		y += PATTERN_STEP * 0.87
		row += 1
