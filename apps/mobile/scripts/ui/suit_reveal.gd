extends Control
## "Collectible" reveal for a suit change: the new 3D suit appears huge in the middle of the screen,
## spinning to a stop under rotating light rays, so nobody can miss that the suit has changed.
## Call start(parent, suit) on a new instance; it frees itself when it is over and never blocks input.

const Suit3D := preload("res://scripts/ui/suit3d.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")

const DUR := 2.1          ## total seconds on screen
const POP := 0.38         ## seconds for the suit to pop in
const SPIN := 1.45        ## seconds of spinning before it settles facing the front
const TURNS := 2.0        ## full turns during the spin (slowing down to a stop)
const SUIT_HALF := 150.0  ## half-height of the suit, in viewport pixels (CardArt convention)

var suit := "S"
var t := 0.0:
	set(v):
		t = v
		queue_redraw()
		if _rays != null:
			_rays.queue_redraw()

var _rays: Control
var _card: Control ## the pile's top card (the one that changed the suit)
var _dim: ColorRect
var _glow: Color


## Fade in over the first 0.18s and out over the last 0.45s.
func _envelope() -> float:
	return clampf(t / 0.18, 0.0, 1.0) * clampf((DUR - t) / 0.45, 0.0, 1.0)


func _centre() -> Vector2:
	return Vector2(size.x / 2.0, size.y * 0.64)


## `SuitReveal.new().start(parent, "S")`
## `delay` waits first, so the card that caused the change can be seen landing.
## `card` is the control showing the card that caused it; it stays undimmed in the backdrop.
## `started` is called once the reveal actually begins (after the delay).
func start(parent: Control, suit_id: String, delay: float = 0.0, card: Control = null, started: Callable = Callable()) -> void:
	suit = suit_id
	_card = card
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if delay > 0.0:
		await parent.get_tree().create_timer(delay).timeout
		if not parent.is_inside_tree():
			free()
			return
	parent.add_child(self)
	if started.is_valid():
		started.call()
	var tw := create_tween()
	tw.tween_property(self, "t", DUR, DUR)
	tw.tween_callback(queue_free)


func _ready() -> void:
	# Red suits glow red-gold; the black suits are dark, so they glow cold white-blue instead.
	_glow = Color(1.0, 0.62, 0.38) if CardArt.suit_color(suit) == CardArt.RED else Color(0.62, 0.8, 1.0)
	var dim := ColorRect.new()
	dim.color = Color.WHITE
	var sh := Shader.new()
	sh.code = DIM_SHADER
	var dm := ShaderMaterial.new()
	dm.shader = sh
	dim.material = dm
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.show_behind_parent = true
	dim.modulate.a = 0.0
	add_child(dim)
	_rays = Rays.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.show_behind_parent = true
	var rsh := Shader.new()
	rsh.code = RAYS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = rsh
	_rays.material = mat
	_rays.reveal = self
	add_child(_rays)
	_dim = dim
	preload("res://scripts/audio/sfx.gd").play("bonus_out", 0.7)


## The table dimmer: dark everywhere except a rounded hole around the card (it "escapes" the backdrop).
const DIM_SHADER := """
shader_type canvas_item;
uniform vec4 hole = vec4(0.0);
uniform float radius = 20.0;
varying vec2 pos;
void vertex() { pos = VERTEX; }
void fragment() {
	vec2 half_size = hole.zw * 0.5;
	vec2 q = abs(pos - hole.xy - half_size) - half_size + radius;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = vec4(0.02, 0.02, 0.08, COLOR.a * smoothstep(-1.0, 3.0, d)); // COLOR.a arrives as the node modulate
}
"""


## Same hole for the additive rays, so they do not tint the card.
const RAYS_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 hole = vec4(0.0);
uniform float radius = 20.0;
varying vec2 pos;
void vertex() { pos = VERTEX; }
void fragment() {
	vec2 half_size = hole.zw * 0.5;
	vec2 q = abs(pos - hole.xy - half_size) - half_size + radius;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR.a *= smoothstep(-1.0, 3.0, d);
}
"""


func _draw() -> void:
	var env := _envelope()
	if _dim != null:
		_dim.modulate.a = 0.62 * env
		if _card != null and is_instance_valid(_card):
			var hole := Rect2(_card.position, _card.size).grow(14.0) # leaves room for the card's lights and halo
			var hv := Vector4(hole.position.x, hole.position.y, hole.size.x, hole.size.y)
			(_dim.material as ShaderMaterial).set_shader_parameter("hole", hv)
			(_rays.material as ShaderMaterial).set_shader_parameter("hole", hv)
	var c := _centre()
	var pop := clampf(t / POP, 0.0, 1.0)
	# Ease-out-back: overshoots a little on the way in, then a gentle hover.
	var back := 1.0 + 2.70158 * pow(pop - 1.0, 3.0) + 1.70158 * pow(pop - 1.0, 2.0)
	var scale_k := maxf(back, 0.05)
	var bob := sin(t * 3.2) * 8.0
	var spin_p := clampf(t / SPIN, 0.0, 1.0)
	var angle := pow(1.0 - spin_p, 3.0) * 360.0 * TURNS # slows to a stop facing front (0)
	var mod := Color(1, 1, 1, env)
	# Backing disc so the suit stays readable against the table.
	draw_circle(c + Vector2(0, bob), SUIT_HALF * 1.18 * scale_k, Color(_glow.r * 0.25, _glow.g * 0.25, _glow.b * 0.3, 0.55 * env))
	Suit3D.draw(self, suit, c + Vector2(0, bob), SUIT_HALF * scale_k, angle, mod)
	# Sparkles drifting up around the suit.
	for i in 14:
		var seed_a := float(i) * 2.399 # golden angle: an even scatter
		var life := fposmod(t * 0.55 + float(i) * 0.137, 1.0)
		var r := SUIT_HALF * (0.75 + 0.9 * fposmod(seed_a * 0.37, 1.0)) * scale_k
		var p := c + Vector2(cos(seed_a), sin(seed_a)) * r + Vector2(0, -life * 90.0 + bob)
		var tw := sin(life * PI)
		_star(p, 7.0 + 12.0 * fposmod(seed_a, 0.7), Color(1.0, 0.96, 0.8, tw * env))
	# Name of the suit, like an item pick-up banner.
	var font := ThemeDB.fallback_font
	var text := ("%s" % CardArt.SUIT_NAMES[suit]).to_upper()
	var fs := 92
	var label_p := clampf((t - 0.25) / 0.3, 0.0, 1.0)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(c.x - w / 2.0, c.y + SUIT_HALF * 1.6 + (1.0 - label_p) * 30.0)
	var a := env * label_p
	draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 22, Color(0.1, 0.05, 0.0, a))
	draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.88, 0.3, a))
	var sub := "NEW SUIT"
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var sp := Vector2(c.x - sw / 2.0, tp.y - fs - 14.0)
	draw_string_outline(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 10, Color(0.1, 0.05, 0.0, a))
	draw_string(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 1.0, 1.0, a * 0.9))


## A four-pointed twinkle.
func _star(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r * 0.22, -r * 0.22), p + Vector2(r, 0), p + Vector2(r * 0.22, r * 0.22),
		p + Vector2(0, r), p + Vector2(-r * 0.22, r * 0.22), p + Vector2(-r, 0), p + Vector2(-r * 0.22, -r * 0.22)])
	draw_colored_polygon(pts, col)


## Additive layer behind the suit: a soft glow and two counter-rotating fans of light rays.
class Rays extends Control:
	var reveal: Node

	func _draw() -> void:
		if reveal == null:
			return
		var env: float = reveal._envelope()
		var c: Vector2 = reveal._centre()
		var col: Color = reveal._glow
		var t: float = reveal.t
		var grow := clampf(t / 0.5, 0.0, 1.0)
		var reach := 640.0 * (0.6 + 0.4 * grow) # stops well short of the corners
		# Soft glow: stacked translucent discs.
		for i in 10:
			var f := float(i) / 10.0
			draw_circle(c, lerpf(340.0, 70.0, f) * (0.7 + 0.3 * grow), Color(col.r, col.g, col.b, 0.05 * env))
		_fan(c, 12, t * 0.55, 0.075, reach, Color(col.r, col.g, col.b, 0.5 * env))
		_fan(c, 18, -t * 0.8 + 0.2, 0.035, reach * 0.8, Color(1.0, 0.95, 0.75, 0.38 * env))

	## `n` thin wedges around `c`, bright at the centre and fading out along their length.
	func _fan(c: Vector2, n: int, rot: float, half: float, length: float, col: Color) -> void:
		var clear := Color(col.r, col.g, col.b, 0.0)
		for i in n:
			var a := rot + TAU * float(i) / float(n)
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a - half) * length, c + Vector2.from_angle(a + half) * length])
			draw_polygon(pts, PackedColorArray([col, clear, clear]))
