extends Node
## Makes the UI feel physical: a soft tick when the mouse moves onto a button, a clack when one is
## pressed, and (on desktop) a custom drawn mouse pointer that turns gold over anything clickable.
## Added once by Main; it watches the whole tree, so every Button anywhere gets this automatically.
## A button can opt out with `b.set_meta("quiet", true)` before it enters the tree.

const Sfx := preload("res://scripts/audio/sfx.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")

const HOVER_GAP_MS := 45   # rapid sweeps across a row of pills don't machine-gun the tick

var _desktop := false
var _last_hover := 0


func _ready() -> void:
	_desktop = not (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"))
	if _desktop and DisplayServer.get_name() != "headless":
		_install_cursors()
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(n)


func _exit_tree() -> void:
	# Input holds the cursor textures; hand them back before the renderer shuts down (else they leak at exit).
	if _desktop:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)


func _on_node_added(n: Node) -> void:
	if not n is BaseButton or n.has_meta("quiet"):
		return
	var b := n as BaseButton
	if b.has_meta("_feel"):
		return
	b.set_meta("_feel", true)
	b.button_down.connect(_on_down.bind(b))
	if _desktop:
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.mouse_entered.connect(_on_hover.bind(b))


func _on_hover(b: BaseButton) -> void:
	if b.disabled:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hover < HOVER_GAP_MS:
		return
	_last_hover = now
	Sfx.play("ui_hover", 0.8)


func _on_down(b: BaseButton) -> void:
	if not b.disabled:
		Sfx.play("ui_click")


# ---------------------------------------------------------------- the pointer

## Classic arrow, tip at the origin, in 24-unit design space.
const ARROW := [Vector2(0, 0), Vector2(0, 17.5), Vector2(4.0, 13.8), Vector2(6.6, 20.4), Vector2(10.6, 18.8), Vector2(8.1, 12.6), Vector2(13.2, 12.6)]


func _install_cursors() -> void:
	var px := int(clampf(round(30.0 * DisplayServer.screen_get_scale()), 24.0, 96.0))
	var hot := Vector2(px * 2.0 / 24.0, px * 1.4 / 24.0) # the arrow's tip (see `pad` in _cursor)
	Input.set_custom_mouse_cursor(_cursor(px, Color(1.0, 0.97, 0.9), UI.OUTLINE_DARK), Input.CURSOR_ARROW, hot)
	Input.set_custom_mouse_cursor(_cursor(px, UI.GOLD, UI.TEXT_ON_GOLD), Input.CURSOR_POINTING_HAND, hot)


## Draws the arrow at 4x and scales down for smooth edges: a soft drop shadow, a dark rim, a light
## fill with a subtle top-to-bottom shade.
func _cursor(px: int, fill: Color, rim: Color) -> ImageTexture:
	const SS := 4
	var big := px * SS
	var img := Image.create(big, big, false, Image.FORMAT_RGBA8)
	var unit := float(big) / 24.0
	var pad := Vector2(2.0, 1.4) * unit # room for the rim around the tip
	var poly: Array[Vector2] = []
	for p in ARROW:
		poly.append(p * unit + pad)
	var rim_w := 1.05 * unit
	var shadow_off := Vector2(0.9, 1.3) * unit
	for y in big:
		for x in big:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			# Shadow: the rimmed shape, offset and feathered.
			var sd := _sdist(p - shadow_off, poly) - rim_w
			if sd < 1.0 * unit:
				col = Color(0, 0, 0, 0.3 * clampf(1.0 - sd / (1.0 * unit), 0.0, 1.0))
			var d := _sdist(p, poly)
			if d < -rim_w:
				var shade := clampf((p.y - pad.y) / (20.0 * unit), 0.0, 1.0)
				col = fill.lerp(fill.darkened(0.22), shade)
			elif d < rim_w:
				col = rim
			img.set_pixel(x, y, col)
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## Signed distance to a (possibly concave) polygon: negative inside.
static func _sdist(p: Vector2, poly: Array[Vector2]) -> float:
	var best := INF
	var inside := false
	var n := poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
		if (a.y > p.y) != (b.y > p.y) and p.x < a.x + (p.y - a.y) / (b.y - a.y) * ab.x:
			inside = not inside
	return -best if inside else best
