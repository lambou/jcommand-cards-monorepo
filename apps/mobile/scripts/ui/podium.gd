extends Control
## Results podium: 1st in the middle, 2nd on the left, 3rd on the right. The blocks rise one after
## another (3rd, 2nd, 1st) with the players' avatars riding on top; 4th place gets a small row below.

const TextFx := preload("res://scripts/ui/text_fx.gd")
const Avatar := preload("res://scripts/ui/avatar.gd")
const Settings := preload("res://scripts/game/settings.gd")

signal first_landed

const GOLD := Color(0.98, 0.78, 0.2)
const SILVER := Color(0.78, 0.80, 0.86)
const BRONZE := Color(0.80, 0.50, 0.26)
const DESIGN_H := 760.0

var order: Array = [] # player ids, 1st first
var names: Dictionary = {}
var me := "you"
var scores: Dictionary = {} # player id -> final points (optional)

var r0 := 0.0:
	set(v):
		r0 = v
		queue_redraw()
var r1 := 0.0:
	set(v):
		r1 = v
		queue_redraw()
var r2 := 0.0:
	set(v):
		r2 = v
		queue_redraw()
var r3 := 0.0:
	set(v):
		r3 = v
		queue_redraw()


func setup(p_order: Array, p_names: Dictionary, p_me: String, p_scores: Dictionary = {}) -> void:
	order = p_order
	names = p_names
	me = p_me
	scores = p_scores
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw() # avatar idle animation


## Raises the podium: 3rd, then 2nd, then 1st.
func play() -> void:
	var tw := create_tween()
	var rise := 0.55
	if order.size() >= 4:
		tw.tween_property(self, "r3", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if order.size() >= 3:
		tw.tween_property(self, "r2", 1.0, rise).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if order.size() >= 2:
		tw.tween_property(self, "r1", 1.0, rise).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	tw.tween_property(self, "r0", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	tw.tween_callback(func(): first_landed.emit())


func _draw() -> void:
	if order.is_empty():
		return
	var font := preload("res://assets/fonts/LilitaOne-Regular.ttf")
	var u := size.y / DESIGN_H
	var step_w := minf(size.x * 0.29, 320.0)
	var gap := 12.0
	var cx := size.x / 2.0
	var base_y := size.y - (130.0 * u if order.size() >= 4 else 24.0 * u)
	var centers := [cx, cx - (step_w + gap), cx + (step_w + gap)]
	var heights := [390.0 * u, 310.0 * u, 235.0 * u]
	var colors := [GOLD, SILVER, BRONZE]
	var rises := [r0, r1, r2]

	for place in mini(order.size(), 3):
		var id: String = order[place]
		var rise: float = rises[place]
		var bh: float = heights[place] * rise
		var x: float = centers[place] - step_w / 2.0
		var top := base_y - bh
		var col: Color = colors[place]

		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.corner_radius_top_left = int(16 * u)
		sb.corner_radius_top_right = int(16 * u)
		draw_style_box(sb, Rect2(x, top, step_w, bh))
		draw_rect(Rect2(x, top, step_w, 10.0 * u), col.lightened(0.35)) # lit top edge
		draw_rect(Rect2(x + step_w * 0.5, top, step_w * 0.5, bh), Color(0, 0, 0, 0.1)) # shaded right half

		if rise > 0.3:
			var a := clampf((rise - 0.3) / 0.5, 0.0, 1.0)
			var dark := Color(1, 1, 1, a)
			TextFx.draw(self, font, Vector2(x, top + 112.0 * u), str(place + 1), HORIZONTAL_ALIGNMENT_CENTER, step_w, int(120.0 * u), dark)
			var is_me := id == me
			var name_col := Color(1, 1, 1, a)
			TextFx.draw(self, font, Vector2(x, top + 112.0 * u + 52.0 * u), str(names.get(id, id)), HORIZONTAL_ALIGNMENT_CENTER, step_w, int(42.0 * u), name_col)
			if scores.has(id):
				TextFx.draw(self, font, Vector2(x, top + 112.0 * u + 104.0 * u), "%d pts" % int(scores[id]), HORIZONTAL_ALIGNMENT_CENTER, step_w, int(36.0 * u), Color(1.0, 0.92, 0.45, a))

		# The avatar rides on top of its block.
		var ar := (68.0 if place == 0 else 56.0) * u
		var crown_clear := 62.0 * u   # how far above the avatar the YOU tag must sit
		ar = roundf(ar)
		var ac := Vector2(centers[place], top - ar - 8.0 * u).round()   # whole pixels: crisp avatar disc + ring
		if place == 0 and rise > 0.5:
			var k := 0.0 if Settings.reduce() else sin(float(Time.get_ticks_msec()) / 1000.0 * 2.0)
			var hr := ar * (2.5 + 0.12 * k)
			var ha := clampf((rise - 0.5) / 0.5, 0.0, 1.0) * (0.85 + 0.15 * k)
			draw_texture_rect(_halo(), Rect2(ac - Vector2(hr, hr), Vector2(hr, hr) * 2.0), false, Color(1, 1, 1, ha))
		var ring := col.lightened(0.2)
		Avatar.draw_avatar(self, Avatar.index_for(id), ac, ar, ring, 7.0 * u, place == 0)
		if place == 0 and rise > 0.9:
			var cc := ac + Vector2(0, -ar + 2.0 * u)
			if _crown_sprite(cc, 64.0 * u):
				crown_clear = 140.0 * u
			else:
				_crown(cc, 64.0 * u)
		if id == me and rise > 0.5:
			var tag_y := ac.y - ar - (crown_clear if place == 0 else 14.0 * u)
			TextFx.draw(self, font, Vector2(centers[place] - 80.0, tag_y), "YOU", HORIZONTAL_ALIGNMENT_CENTER, 160.0, int(38.0 * u), Color(1.0, 0.9, 0.35))

	# 4th place: a small row under the podium.
	if order.size() >= 4 and r3 > 0.0:
		var id4: String = order[3]
		var ar4 := 34.0 * u
		var y4 := size.y - 52.0 * u
		var label := "4th   %s" % str(names.get(id4, id4))
		if scores.has(id4):
			label += "   %d pts" % int(scores[id4])
		var col4 := Color(1, 1, 1, r3)
		TextFx.draw(self, font, Vector2(cx - 100.0 * u, y4 + 12.0 * u), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(40.0 * u), col4)
		Avatar.draw_avatar(self, Avatar.index_for(id4), Vector2(cx - 150.0 * u, y4), ar4, Color(1, 1, 1, 0.5 * r3), 3.0)


# Soft gold halo behind the winner: one radial gradient, drawn pulsing slowly.
static var _halo_tex: GradientTexture2D


static func _halo() -> GradientTexture2D:
	if _halo_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.86, 0.35, 0.75), Color(1.0, 0.8, 0.25, 0.28), Color(1.0, 0.75, 0.2, 0.0)])
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(1.0, 0.5)
		_halo_tex.width = 256
		_halo_tex.height = 256
	return _halo_tex


# Animated 3D crown (tools/blender/make_crown.py + pack_crown.py): a looping sway on a spritesheet.
static var _crown_tex: Texture2D
static var _crown_meta: Dictionary = {}
static var _crown_tried := false


## Draws the animated 3D crown sitting on `c` (bottom-centre) at half width `w`; false if the sheet is missing.
func _crown_sprite(c: Vector2, w: float) -> bool:
	if not _crown_tried:
		_crown_tried = true
		if ResourceLoader.exists("res://assets/crown/crown.png") and FileAccess.file_exists("res://assets/crown/crown.json"):
			var f := FileAccess.open("res://assets/crown/crown.json", FileAccess.READ)
			_crown_meta = JSON.parse_string(f.get_as_text())
			_crown_tex = load("res://assets/crown/crown.png")
	if _crown_tex == null or _crown_meta.is_empty():
		return false
	var n: int = _crown_meta["frames"]
	var cols: int = _crown_meta["cols"]
	var px: float = _crown_meta["frame_px"]
	var i := int(float(Time.get_ticks_msec()) / 1000.0 * float(_crown_meta["fps"]) * 0.6) % n   # relaxed 60% speed
	var src := Rect2(float(i % cols) * px, float(i / cols) * px, px, px)
	var s := w * 2.7                                    # frame size: the crown fills ~72% of it
	draw_texture_rect_region(_crown_tex, Rect2(c.x - s * 0.5, c.y - s * 0.9, s, s), src)
	return true


## Gold crown: soft rounded peaks with ball tips, gradient body, outline, gemmed band.
## c = bottom-centre of the crown, w = half width.
func _crown(c: Vector2, w: float) -> void:
	var h := w * 0.9
	var lw := maxf(2.0, w * 0.07)
	var outline := Color(0.42, 0.24, 0.02)
	var light := Color(1.0, 0.93, 0.5)
	var deep := Color(0.9, 0.58, 0.08)
	# Top profile through peaks/valleys, eased so every tip and dip is round.
	var ctrl := [Vector2(-w, -h * 0.78), Vector2(-w * 0.5, -h * 0.42), Vector2(0, -h * 0.98),
			Vector2(w * 0.5, -h * 0.42), Vector2(w, -h * 0.78)]
	var top := PackedVector2Array()
	for i in range(ctrl.size() - 1):
		var p0: Vector2 = ctrl[i]
		var p1: Vector2 = ctrl[i + 1]
		for k in 14:
			var t := float(k) / 14.0
			var e := t * t * (3.0 - 2.0 * t)
			top.append(Vector2(lerpf(p0.x, p1.x, t), lerpf(p0.y, p1.y, e)))
	top.append(ctrl[ctrl.size() - 1])
	var poly := PackedVector2Array()
	var cols := PackedColorArray()
	for v in top:
		poly.append(c + v)
		cols.append(light.lerp(deep, clampf((v.y + h) / h, 0.0, 1.0)))
	poly.append(c + Vector2(w * 0.94, 0))
	cols.append(deep)
	poly.append(c + Vector2(-w * 0.94, 0))
	cols.append(deep)
	draw_polygon(poly, cols)
	var line := PackedVector2Array(poly)
	line.append(poly[0])
	draw_polyline(line, outline, lw, true)
	# Ball tips on the three peaks.
	var br := w * 0.13
	for pk in [ctrl[0], ctrl[2], ctrl[4]]:
		var bc: Vector2 = c + pk + Vector2(0, -br * 0.35)
		draw_circle(bc, br + lw * 0.5, outline)
		draw_circle(bc, br, light.lerp(deep, 0.25))
		draw_circle(bc + Vector2(-br * 0.3, -br * 0.3), br * 0.3, Color(1, 1, 1, 0.85))
	# Band with rounded ends.
	var band := Rect2(c.x - w * 1.0, c.y - h * 0.3, w * 2.0, h * 0.3)
	var sb := StyleBoxFlat.new()
	sb.bg_color = deep.lerp(light, 0.25)
	sb.set_corner_radius_all(int(band.size.y * 0.5))
	sb.set_border_width_all(int(ceilf(lw)))
	sb.border_color = outline
	draw_style_box(sb, band)
	draw_rect(Rect2(band.position.x + band.size.y * 0.5, band.position.y + lw * 1.2, band.size.x - band.size.y, lw * 0.8), Color(1, 1, 1, 0.35))
	# Gems on the band: big red centre, small blue sides.
	var gy := band.position.y + band.size.y * 0.5
	for g in [[-0.6, Color(0.25, 0.55, 1.0), 0.6], [0.0, Color(0.95, 0.2, 0.28), 0.9], [0.6, Color(0.25, 0.55, 1.0), 0.6]]:
		var gr := band.size.y * 0.5 * float(g[2]) * 0.85
		var gc := Vector2(c.x + w * float(g[0]), gy)
		draw_circle(gc, gr + lw * 0.4, outline)
		draw_circle(gc, gr, g[1])
		draw_circle(gc + Vector2(-gr * 0.3, -gr * 0.3), gr * 0.32, Color(1, 1, 1, 0.8))
