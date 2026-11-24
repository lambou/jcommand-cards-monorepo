extends RefCounted
## Placeholder vector avatars drawn with circles and polygons. One style per player slot:
## 0 = you, 1..3 = the bots.

const STYLES := [
	{"name": "You", "bg": Color(0.96, 0.76, 0.22), "skin": Color(0.97, 0.80, 0.66), "hair": Color(0.28, 0.17, 0.08), "kind": "cap", "accent": Color(0.85, 0.15, 0.18)},
	{"name": "Rex", "bg": Color(0.27, 0.55, 0.86), "skin": Color(0.86, 0.63, 0.46), "hair": Color(0.10, 0.10, 0.12), "kind": "spiky", "accent": Color(0.1, 0.1, 0.12)},
	{"name": "Luna", "bg": Color(0.86, 0.36, 0.58), "skin": Color(0.99, 0.86, 0.73), "hair": Color(0.74, 0.34, 0.14), "kind": "bob", "accent": Color(0.74, 0.34, 0.14)},
	{"name": "Zed", "bg": Color(0.34, 0.70, 0.46), "skin": Color(0.63, 0.44, 0.31), "hair": Color(0.06, 0.06, 0.07), "kind": "afro", "accent": Color(0.06, 0.06, 0.07)},
]

const Settings := preload("res://scripts/game/settings.gd")
const DARK :=Color(0.12, 0.10, 0.12)


## Style index for a player id: you get the avatar picked in Settings, the bots the others in order.
static func index_for(id: String) -> int:
	Settings.load_settings()
	var mine := Settings.avatar % STYLES.size()
	if not id.begins_with("bot"):
		return mine
	var slot := clampi(int(id.substr(3)), 1, STYLES.size() - 1)
	var others := []
	for i in STYLES.size():
		if i != mine:
			others.append(i)
	return others[slot - 1]


static func display_name(idx: int) -> String:
	return STYLES[idx % STYLES.size()]["name"]


## Pre-rendered 3D avatars (tools/avatars -> assets/avatars/<name>_<anim>.png spritesheets + meta.json).
## Returns false when no sheet exists, so the vector drawing below stays as the fallback.
static var _sheets := {}
static var _meta := {}


static func _sheet(name: String, anim: String) -> Texture2D:
	var key := "%s_%s" % [name, anim]
	if not _sheets.has(key):
		var p := "res://assets/avatars/%s.png" % key
		_sheets[key] = load(p) if ResourceLoader.exists(p) else null
	return _sheets[key]


static func _draw_sprite(ci: CanvasItem, idx: int, c: Vector2, r: float, happy: bool) -> bool:
	if _meta.is_empty():
		var f := FileAccess.open("res://assets/avatars/meta.json", FileAccess.READ)
		_meta = JSON.parse_string(f.get_as_text()) if f != null else {"avatars": {}}
	var name := str(STYLES[idx % STYLES.size()]["name"]).to_lower()
	var info: Dictionary = _meta.get("avatars", {}).get(name, {})
	var anim := "happy" if (happy and info.has("happy")) else "idle"
	if not info.has(anim):
		return false
	var tex := _sheet(name, anim)
	if tex == null:
		return false
	var n := int(info[anim]["frames"])
	var cols := int(info[anim]["cols"])
	var fs := float(_meta["size"])
	var frame := 0
	if not Settings.reduce():
		frame = int(float(Time.get_ticks_msec()) / 1000.0 * float(_meta["fps"])) % n
	ci.draw_texture_rect_region(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0),
		Rect2(float(frame % cols) * fs, float(frame / cols) * fs, fs, fs))
	return true


## The ring around the portrait: a Blender-rendered bevelled metal band (tools/avatars/render_frame.py), tinted
## with `ring`. Thin or thick by how heavy the ring is relative to the avatar; a plain arc if the art is missing.
static var _frames := {}


static func _draw_frame(ci: CanvasItem, c: Vector2, r: float, ring: Color, ring_w: float) -> void:
	var kind := "thick" if ring_w / r >= 0.1 else "thin"
	if not _frames.has(kind):
		var p := "res://assets/avatars/frame_%s.png" % kind
		_frames[kind] = load(p) if ResourceLoader.exists(p) else null
	var tex: Texture2D = _frames[kind]
	if tex == null:
		ci.draw_arc(c, r, 0.0, TAU, 160, ring, ring_w, true)   # 160 segments: a true circle at any size
		return
	# The filter is per canvas item, not per draw call; sprite sheets have no mipmaps, so this costs them nothing.
	if ci.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		ci.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var half := r * 1.1   # the art spans +-1.1 avatar radii
	ci.draw_texture_rect(tex, Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0), false, ring)


static func _dir(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))


static func _half_disc(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 17:
		pts.append(c + _dir(PI + PI * float(k) / 16.0) * rad)
	ci.draw_colored_polygon(pts, col)


## The darker shoulders blob, clipped to the avatar disc (an unclipped disc pokes out below it).
static func _shoulders(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var sc := c + Vector2(0, r * 0.55)
	var sr := r * 0.62
	var pts := PackedVector2Array()
	var n := 64
	for k in n:
		var p := sc + _dir(TAU * float(k) / float(n)) * sr
		var off := p - c
		if off.length() > r:
			p = c + off.normalized() * r
		pts.append(p)
	ci.draw_colored_polygon(pts, col)


## Draws the avatar centred on `c` with radius `r`. `ring_w` > 0 adds a border ring.
## `talk` is for a speaking avatar (Rex in the tutorial): a lively head and a mouth that opens and closes.
static func draw_avatar(ci: CanvasItem, idx: int, c: Vector2, r: float, ring: Color = Color.WHITE, ring_w: float = 0.0, happy: bool = false, talk: bool = false) -> void:
	if _draw_sprite(ci, idx, c, r, happy or talk):
		if ring_w > 0.0:
			_draw_frame(ci, c, r, ring, ring_w)
		return
	var st: Dictionary = STYLES[idx % STYLES.size()]
	var skin: Color = st["skin"]
	var hair: Color = st["hair"]
	# Idle animation: breathing shoulders, a gentle head bob/sway, blinking and eyes that wander.
	# Each avatar has its own phase so they don't move in lockstep.
	var bob := 0.0
	var sway := 0.0
	var breathe := 0.0
	var blink := 1.0
	var look := Vector2.ZERO
	if not Settings.reduce():
		var t := float(Time.get_ticks_msec()) / 1000.0
		var ph := float(idx) * 1.9
		bob = sin(t * 2.2 + ph) * r * 0.025
		sway = sin(t * 1.1 + ph) * r * 0.025
		breathe = sin(t * 2.2 + ph - 0.6) * r * 0.02
		if happy:
			bob -= absf(sin(t * 6.0 + ph)) * r * 0.07
		if talk:
			bob -= absf(sin(t * 9.0 + ph)) * r * 0.035
			sway += sin(t * 5.0 + ph) * r * 0.03
		var cyc := fmod(t + ph, 3.4 + float(idx % 3) * 0.6)
		if cyc < 0.14:
			blink = absf(cyc - 0.07) / 0.07 # 1 -> 0 -> 1
		look = Vector2(sin(t * 0.7 + ph * 2.0), sin(t * 0.43 + ph) * 0.5)

	ci.draw_circle(c, r, st["bg"])
	_shoulders(ci, c + Vector2(0, breathe), r, (st["bg"] as Color).darkened(0.18))

	var hc := c + Vector2(sway, r * 0.1 + bob)
	var hr := r * 0.5

	# Hair behind the head.
	match st["kind"]:
		"afro":
			ci.draw_circle(hc + Vector2(0, -hr * 0.3), hr * 1.32, hair)
		"bob":
			ci.draw_circle(hc + Vector2(0, -hr * 0.1), hr * 1.18, hair)
			ci.draw_circle(hc + Vector2(-hr * 0.98, hr * 0.55), hr * 0.46, hair)
			ci.draw_circle(hc + Vector2(hr * 0.98, hr * 0.55), hr * 0.46, hair)

	# Ears + head.
	ci.draw_circle(hc + Vector2(-hr * 0.98, hr * 0.05), hr * 0.18, skin)
	ci.draw_circle(hc + Vector2(hr * 0.98, hr * 0.05), hr * 0.18, skin)
	ci.draw_circle(hc, hr, skin)

	# Hair / hat on top.
	match st["kind"]:
		"cap":
			_half_disc(ci, hc + Vector2(0, -hr * 0.08), hr * 1.04, st["accent"])
			ci.draw_colored_polygon(PackedVector2Array([
				hc + Vector2(-hr * 0.2, -hr * 0.22), hc + Vector2(hr * 1.35, -hr * 0.22),
				hc + Vector2(hr * 1.35, hr * 0.0), hc + Vector2(-hr * 0.2, hr * 0.0)]), (st["accent"] as Color).darkened(0.2))
			ci.draw_circle(hc + Vector2(0, -hr * 0.95), hr * 0.1, Color.WHITE)
		"spiky":
			for i in 5:
				var a := deg_to_rad(-90.0 + float(i - 2) * 30.0)
				ci.draw_colored_polygon(PackedVector2Array([
					hc + _dir(a - 0.24) * hr * 0.92, hc + _dir(a + 0.24) * hr * 0.92, hc + _dir(a) * hr * 1.6]), hair)
			_half_disc(ci, hc + Vector2(0, -hr * 0.05), hr * 1.0, hair)
		"bob", "afro":
			_half_disc(ci, hc + Vector2(0, -hr * 0.05), hr * 1.03, hair)

	# Face.
	var eye_y := hr * 0.14
	for sx in [-1.0, 1.0]:
		var ec: Vector2 = hc + Vector2(sx * hr * 0.4, eye_y)
		ec += look * hr * 0.05
		if blink < 0.999:
			ci.draw_line(ec - Vector2(hr * 0.13, 0), ec + Vector2(hr * 0.13, 0), DARK, maxf(2.0, hr * 0.06), true)
		else:
			ci.draw_circle(ec, hr * 0.13, DARK)
			ci.draw_circle(ec + Vector2(hr * 0.04, -hr * 0.05), hr * 0.045, Color.WHITE)
		ci.draw_circle(hc + Vector2(sx * hr * 0.62, hr * 0.3), hr * 0.14, Color(1.0, 0.45, 0.5, 0.35))
	if talk and not Settings.reduce():
		# Mouth opening and closing at a speaking rhythm (two beats added so it never looks mechanical).
		var tt := float(Time.get_ticks_msec()) / 1000.0
		var open := clampf(0.5 + 0.5 * sin(tt * 17.0) * (0.6 + 0.4 * sin(tt * 5.3)), 0.12, 1.0)
		var mc := hc + Vector2(0, hr * 0.5)
		var pts := PackedVector2Array()
		for k in 20:
			var a := TAU * float(k) / 20.0
			pts.append(mc + Vector2(cos(a) * hr * 0.3, sin(a) * hr * (0.07 + 0.2 * open)))
		ci.draw_colored_polygon(pts, DARK)
		ci.draw_circle(mc + Vector2(0, hr * (0.07 + 0.2 * open) * 0.45), hr * 0.1, Color(0.9, 0.35, 0.4))
	else:
		var smile := hr * (0.42 if happy else 0.3)
		ci.draw_arc(hc + Vector2(0, hr * (0.22 if happy else 0.3)), smile, 0.12 * PI, 0.88 * PI, 14, DARK, maxf(2.0, hr * 0.07), true)

	if ring_w > 0.0:
		ci.draw_arc(c, r, 0.0, TAU, 160, ring, ring_w, true)   # 160 segments: a true circle at any size
