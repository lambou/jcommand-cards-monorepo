extends CanvasLayer
## Screen-to-screen transition: a felt-green diamond iris closes over the old screen, the logo
## pops in the middle while the new screen is built underneath, then the iris opens on it.
## Input is swallowed for the whole run, so a double tap can't start two screens.
## With Reduce motion on it is a plain quick fade instead.
## Main owns one of these; call `go(swap)` where `swap` builds the next screen.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Settings := preload("res://scripts/game/settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

const CLOSE_TIME := 0.36
const HOLD_TIME := 0.06
const OPEN_TIME := 0.44
const LOGO_SIZE := 260.0

const SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0; // 0 = open, 1 = fully covered
uniform bool fade_mode = false;
uniform vec2 rect_size = vec2(1080.0, 1920.0);
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform vec4 rim_color : source_color;

void fragment() {
	vec3 felt = mix(top_color.rgb, bottom_color.rgb, UV.y);
	// Faint diamond lattice on the felt, like the card backs.
	vec2 px = UV * rect_size;
	vec2 cell = abs(fract(px / 120.0) - 0.5);
	float lattice = smoothstep(0.03, 0.0, abs(cell.x + cell.y - 0.5));
	felt += lattice * 0.035;
	if (fade_mode) {
		COLOR = vec4(felt, progress);
	} else {
		vec2 p = px - rect_size * 0.5;
		float d = abs(p.x) + abs(p.y);                     // diamond distance from the centre
		float reach = (rect_size.x + rect_size.y) * 0.5 + 40.0; // corners fully covered at progress 1
		float r = (1.0 - progress) * reach;
		float cover = smoothstep(r - 2.0, r + 2.0, d);
		float rim = smoothstep(r - 2.0, r + 2.0, d) * (1.0 - smoothstep(r + 12.0, r + 16.0, d));
		vec3 col = mix(felt, rim_color.rgb, rim * step(0.001, progress) * step(progress, 0.999));
		COLOR = vec4(col, cover);
	}
}
"""

var _cover: ColorRect
var _mat: ShaderMaterial
var _logo: TextureRect
var _busy := false


func _ready() -> void:
	layer = 100
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("top_color", UI.BG_TOP)
	_mat.set_shader_parameter("bottom_color", UI.BG_BOTTOM)
	_mat.set_shader_parameter("rim_color", Color(1.0, 0.82, 0.2))
	_cover = ColorRect.new()
	_cover.material = _mat
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.resized.connect(func(): _mat.set_shader_parameter("rect_size", _cover.size))
	add_child(_cover)

	_logo = TextureRect.new()
	if ResourceLoader.exists(UI.LOGO):
		_logo.texture = load(UI.LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(LOGO_SIZE, LOGO_SIZE)
	_logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_logo.offset_left = -LOGO_SIZE / 2.0
	_logo.offset_top = -LOGO_SIZE / 2.0
	_logo.offset_right = LOGO_SIZE / 2.0
	_logo.offset_bottom = LOGO_SIZE / 2.0
	_logo.pivot_offset = Vector2(LOGO_SIZE, LOGO_SIZE) / 2.0
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(_logo)
	_set_progress(0.0)


func is_busy() -> bool:
	return _busy


## Covers the screen, calls `swap` (which replaces the current screen), then reveals the new one.
## Ignored while a transition is already running.
func go(swap: Callable) -> void:
	if _busy:
		return
	_busy = true
	var fade := Settings.reduce_motion
	_mat.set_shader_parameter("fade_mode", fade)
	_cover.visible = true
	_logo.scale = Vector2.ZERO
	_logo.modulate.a = 0.0 if fade else 1.0
	if not fade:
		Sfx.play("whoosh", 0.8)

	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, 0.2 if fade else CLOSE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if not fade:
		t.tween_property(_logo, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished

	swap.call()
	# Let the new screen lay out and build its first frame (3D hands, fonts) while still hidden.
	await get_tree().process_frame
	await get_tree().process_frame
	if not fade:
		await get_tree().create_timer(HOLD_TIME).timeout
		Sfx.play("whoosh", 0.55)

	t = create_tween().set_parallel()
	if not fade:
		t.tween_property(_logo, "scale", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_method(_set_progress, 1.0, 0.0, 0.22 if fade else OPEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.0 if fade else 0.08)
	await t.finished
	_busy = false


func _set_progress(p: float) -> void:
	_mat.set_shader_parameter("progress", p)
	_cover.visible = p > 0.0
