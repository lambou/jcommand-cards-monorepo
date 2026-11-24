extends Control
## One placeholder vector card (face or back). Emits `pressed(card_id)` on tap.

const TextFx := preload("res://scripts/ui/text_fx.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")

signal pressed(card_id: int)
signal dragged(dx: float)

const DRAG_THRESHOLD := 14.0
var _down := false
var _dragging := false
var _last_x := 0.0
var _down_x := 0.0

const BASE := Vector2(150, 215)

var card: Dictionary = {}
var face_up := true
var dimmed := false
var lifted := false
var badge_text := ""
## Number of cards to show peeking out from underneath (pile thickness).
var peek := 0


func _init() -> void:
	size = BASE
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_card(c: Dictionary, up: bool = true) -> void:
	card = c
	face_up = up
	queue_redraw()


func set_flags(p_dimmed: bool, p_lifted: bool, p_badge: String = "") -> void:
	dimmed = p_dimmed
	lifted = p_lifted
	badge_text = p_badge
	queue_redraw()


## A press only counts as a tap if the finger is released without dragging; a drag
## is reported as horizontal movement (used to scroll the hand).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_dragging = false
			_last_x = get_global_mouse_position().x
			_down_x = _last_x
		elif _down:
			_down = false
			if not _dragging:
				pressed.emit(int(card.get("id", -1)))
		accept_event()
	elif event is InputEventMouseMotion and _down:
		var x := get_global_mouse_position().x
		if not _dragging and absf(x - _down_x) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			dragged.emit(x - _last_x)
		_last_x = x
		accept_event()


const INK := Color(0.10, 0.10, 0.18)
const SPECIAL := {
	"7": Color(0.95, 0.50, 0.10),
	"2": Color(0.58, 0.32, 0.88),
	"J": Color(0.15, 0.52, 0.92),
	"A": Color(0.08, 0.66, 0.56),
	"LION": Color(0.96, 0.74, 0.12),
}
const CAPTIONS := {"7": "+2", "2": "ANY", "J": "PICK SUIT", "A": "STOP", "LION": "LION +4"}


## Face-down card, usable for any rect (also the opponents' fans).
static func draw_back(ci: CanvasItem, r: Rect2) -> void:
	var u := r.size.x / BASE.x
	var rad := int(16 * u)
	var theme := TableBg.current_theme() # the back changes colour with the table so it never blends in
	var back_col: Color = theme["back"]
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.35)
	shadow.set_corner_radius_all(rad)
	ci.draw_style_box(shadow, Rect2(r.position + Vector2(0, 5 * u), r.size))
	var body := StyleBoxFlat.new()
	body.set_corner_radius_all(rad)
	body.bg_color = back_col
	body.set_border_width_all(maxi(2, int(4 * u)))
	body.border_color = Color(0.97, 0.97, 1.0)
	ci.draw_style_box(body, r)
	var inner := Rect2(r.position + Vector2(11, 11) * u, r.size - Vector2(22, 22) * u)
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_corner_radius_all(int(9 * u))
	frame.set_border_width_all(maxi(1, int(3 * u)))
	frame.border_color = Color(1.0, 0.80, 0.25)
	ci.draw_style_box(frame, inner)
	# Diamond lattice.
	var step := 24.0 * u
	var half := 8.0 * u
	var lat: Color = theme["lattice"]
	var cy := inner.position.y + step * 0.5
	var row := 0
	while cy < inner.end.y - half:
		var cx := inner.position.x + step * (0.5 if row % 2 == 0 else 1.0)
		while cx < inner.end.x - half:
			if cx > inner.position.x + half and absf(cy - (r.position.y + r.size.y / 2.0)) > 42.0 * u:
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(cx, cy - half), Vector2(cx + half * 0.7, cy),
					Vector2(cx, cy + half), Vector2(cx - half * 0.7, cy)]), lat)
			cx += step
		cy += step * 0.5
		row += 1
	# Centre emblem.
	var c := r.position + r.size / 2.0
	ci.draw_circle(c, 36 * u, INK)
	ci.draw_circle(c, 32 * u, Color(1.0, 0.80, 0.25))
	ci.draw_circle(c, 25 * u, back_col)
	CardArt.draw_suit(ci, "D", c, 17 * u, Color(0.97, 0.97, 1.0))
	# Bevel highlight.
	ci.draw_line(r.position + Vector2(18 * u, 5 * u), r.position + Vector2(r.size.x - 18 * u, 5 * u), Color(1, 1, 1, 0.55), maxf(1.0, 2.0 * u))


func _draw() -> void:
	var u := size.x / BASE.x
	var font := preload("res://assets/fonts/LilitaOne-Regular.ttf")
	var rad := int(18 * u)
	var rank: String = str(card.get("rank", ""))

	# Pile thickness: cards peeking out from underneath, each slightly rotated.
	if peek > 0 and face_up:
		for k in range(peek, 0, -1):
			var ang := sin(float(k) * 12.9898 + float(card.get("id", 0))) * deg_to_rad(6.0)
			draw_set_transform(size / 2.0 + Vector2(-6.0, 6.0) * float(k) * u, ang, Vector2.ONE)
			var sh := StyleBoxFlat.new()
			sh.bg_color = Color(0, 0, 0, 0.3)
			sh.set_corner_radius_all(rad)
			draw_style_box(sh, Rect2(-size / 2.0 + Vector2(0, 4 * u), size))
			var under := StyleBoxFlat.new()
			under.set_corner_radius_all(rad)
			under.bg_color = Color(0.86, 0.84, 0.78)
			under.set_border_width_all(maxi(2, int(4 * u)))
			under.border_color = INK
			draw_style_box(under, Rect2(-size / 2.0, size))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if not face_up:
		draw_back(self, Rect2(Vector2.ZERO, size))
		_draw_badge(font, u)
		return

	# Hard offset shadow (+ gold glow when playable).
	var sh2 := StyleBoxFlat.new()
	sh2.bg_color = Color(0, 0, 0, 0.35)
	sh2.set_corner_radius_all(rad)
	if lifted:
		sh2.shadow_color = Color(1.0, 0.8, 0.2, 0.6)
		sh2.shadow_size = int(14 * u)
	draw_style_box(sh2, Rect2(Vector2(0, 6 * u), size))

	var body := StyleBoxFlat.new()
	body.set_corner_radius_all(rad)
	body.bg_color = Color(0.93, 0.90, 0.82)
	body.set_border_width_all(maxi(2, int((6 if lifted else 4) * u)))
	body.border_color = Color(1.0, 0.78, 0.15) if lifted else INK
	draw_style_box(body, Rect2(Vector2.ZERO, size))

	# Cream inner panel = bevel.
	var panel := StyleBoxFlat.new()
	panel.set_corner_radius_all(int(13 * u))
	panel.bg_color = Color(0.995, 0.985, 0.95)
	var inset := 7.0 * u
	draw_style_box(panel, Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0))
	draw_line(Vector2(20 * u, 9 * u), Vector2(size.x - 20 * u, 9 * u), Color(1, 1, 1, 0.9), maxf(1.0, 3.0 * u))

	var is_special := SPECIAL.has(rank)
	var sc: Color = SPECIAL.get(rank, Color.WHITE)
	if is_special:
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(sc.r, sc.g, sc.b, 0.16)
		plate.set_corner_radius_all(int(10 * u))
		draw_style_box(plate, Rect2(Vector2(14, 14) * u, size - Vector2(28, 28) * u))
		var fr := StyleBoxFlat.new()
		fr.draw_center = false
		fr.set_corner_radius_all(int(13 * u))
		fr.set_border_width_all(maxi(2, int(5 * u)))
		fr.border_color = sc
		draw_style_box(fr, Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0))

	var col := INK
	var corner_text := rank
	var pip_suit := ""
	if rank == "LION":
		col = CardArt.RED if card["color"] == "red" else CardArt.BLACK
		corner_text = "L"
		CardArt.draw_lion(self, card["color"], Vector2(size.x / 2.0, size.y * 0.37), 34 * u)
	elif rank != "":
		pip_suit = card["suit"]
		col = CardArt.suit_color(pip_suit)
		var pip_c := Vector2(size.x / 2.0, size.y * (0.36 if is_special else 0.5))
		CardArt.draw_suit(self, pip_suit, pip_c, (32.0 if is_special else 44.0) * u, col)

	if is_special:
		var rw := 86.0 * u
		var rr := Rect2(Vector2((size.x - rw) / 2.0, size.y * 0.60 - 14 * u), Vector2(rw, 28 * u))
		var rib := StyleBoxFlat.new()
		rib.bg_color = sc
		rib.set_corner_radius_all(int(9 * u))
		rib.set_border_width_all(maxi(2, int(3 * u)))
		rib.border_color = INK
		draw_style_box(rib, rr)
		TextFx.draw(self, font, Vector2(rr.position.x, rr.position.y + 22 * u), CAPTIONS[rank],
			HORIZONTAL_ALIGNMENT_CENTER, rw, int(18 * u), Color.WHITE)

	# Corners: top-left, then the same thing rotated 180 degrees for the bottom-right.
	if rank != "":
		_corner(font, u, corner_text, pip_suit, col, Vector2.ZERO, 0.0)
		_corner(font, u, corner_text, pip_suit, col, size / 2.0, PI)

	if dimmed:
		var shade := StyleBoxFlat.new()
		shade.bg_color = Color(0.30, 0.42, 0.85, 0.20)
		shade.set_corner_radius_all(rad)
		draw_style_box(shade, Rect2(Vector2.ZERO, size))
	_draw_badge(font, u)


func _corner(_font: Font, u: float, text: String, suit: String, col: Color, pivot: Vector2, ang: float) -> void:
	var off := Vector2.ZERO
	if ang != 0.0:
		draw_set_transform(pivot, ang, Vector2.ONE)
		off = -pivot
	# Condensed, high-contrast face for the index; no outline so counters stay open.
	var rf := preload("res://assets/fonts/FjallaOne-Regular.ttf")
	var fs := int(58 * u)
	var tw := rf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cx := maxf(10 * u + tw / 2.0, 24 * u)
	draw_string(rf, off + Vector2(cx - tw / 2.0, 54 * u), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if suit != "":
		CardArt.draw_suit(self, suit, off + Vector2(cx, 84 * u), 15 * u, col)
	if ang != 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_badge(font: Font, u: float) -> void:
	if badge_text == "":
		return
	var c := Vector2(size.x - 14 * u, 14 * u)
	draw_circle(c, 30 * u, Color(0.85, 0.12, 0.12))
	draw_arc(c, 30 * u, 0, TAU, 32, Color.WHITE, 3.0 * u)
	TextFx.draw(self, font, c + Vector2(-30 * u, 12 * u), badge_text, HORIZONTAL_ALIGNMENT_CENTER, 60 * u, int(32 * u), Color.WHITE)
