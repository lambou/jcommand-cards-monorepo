extends RefCounted
## 3D suit icons: pre-rendered Blender turntables (tools/blender/make_suits.py).
## Each assets/suits/suit_X.png is a FRAMES-frame spritesheet of one full spin (cross-faded between frames), frame 0 = facing front.
## Falls back to the flat vector art if a sheet is missing, so the game never breaks without assets.

const CardArt := preload("res://scripts/ui/card_art.gd")

const FRAMES := 96
const COLS := 12
const FRAME_PX := 192
## The suit fills ~78% of a frame (ortho camera margin), so scale the quad up to match CardArt's radius.
const FILL := 2.0 / 0.78

static var _sheets: Dictionary = {}


static func sheet(suit: String) -> Texture2D:
	if not _sheets.has(suit):
		var path := "res://assets/suits/suit_%s.png" % suit
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		# A sheet packed with a different frame count / size would be sampled at the wrong
		# places (empty or garbled), so treat it as missing and use the flat art instead.
		if tex != null and tex.get_size() != Vector2(COLS * FRAME_PX, ceili(float(FRAMES) / COLS) * FRAME_PX):
			push_warning("suit sheet %s has an unexpected size %s; using flat suits" % [path, tex.get_size()])
			tex = null
		_sheets[suit] = tex
	return _sheets[suit]


static func available() -> bool:
	for s in ["H", "D", "C", "S"]:
		if sheet(s) == null:
			return false
	return true


## Draw `suit` centred on `c`, with the same size convention as CardArt.draw_suit (`s` = half-height).
## `angle` is the spin in degrees (0 = front-facing); wraps around.
static func draw(ci: CanvasItem, suit: String, c: Vector2, s: float, angle: float = 0.0, modulate: Color = Color.WHITE) -> void:
	var tex := sheet(suit)
	if tex == null:
		CardArt.draw_suit(ci, suit, c, s, CardArt.suit_color(suit))
		return
	# Cross-fade between the two nearest frames so slow spins glide instead of stepping.
	var pos := fposmod(angle / 360.0 * FRAMES, float(FRAMES))
	var f0 := int(pos) % FRAMES
	var f1 := (f0 + 1) % FRAMES
	var t := pos - floorf(pos)
	var side := s * FILL
	var dst := Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side))
	ci.draw_texture_rect_region(tex, dst, _frame_rect(f0), modulate)
	if t > 0.02:
		var m2 := modulate
		m2.a *= t
		ci.draw_texture_rect_region(tex, dst, _frame_rect(f1), m2)


static func _frame_rect(f: int) -> Rect2:
	return Rect2(Vector2((f % COLS) * FRAME_PX, (f / COLS) * FRAME_PX), Vector2(FRAME_PX, FRAME_PX))


## Endless idle turntable: a slow, constant spin (degrees, unbounded; draw() wraps it). `phase`
## offsets neighbouring suits so they do not turn in lockstep.
const IDLE_DEG_PER_SEC := 42.0

static func idle(time: float, phase: float = 0.0) -> float:
	return time * IDLE_DEG_PER_SEC + phase * 57.0
