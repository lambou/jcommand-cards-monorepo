extends Control
## Start-up sequence: a splash (logo fades in, holds, fades out; tap to skip), then a loading
## screen that pulls the avatar sheets and suit art into the resource cache with threaded loads
## so the menu and table never hitch on first use. Emits `finished` when the menu can show.

signal finished

const UI := preload("res://scripts/ui/ui_kit.gd")
const Avatar := preload("res://scripts/ui/avatar.gd")
const Settings := preload("res://scripts/game/settings.gd")

const LOGO := UI.LOGO
const SPLASH_LOGO := 360.0   # logo edge length on the 1080-wide canvas
const SPLASH_IN := 0.7
const SPLASH_HOLD := 0.9
const SPLASH_OUT := 0.5
const MIN_LOADING := 1.2   # keep the loading screen readable even when everything is cached
const TIPS := [
	"Aces skip the next player.",
	"Answer a 7 or a Joker with another to pass the penalty on.",
	"A J lets you choose the next suit.",
	"Finish without drawing from the bank for a CLEAN FINISH bonus.",
	"A 2 goes on anything.",
]

var _splash: Control
var _loading: Control
var _bar: ProgressBar
var _status: Label
var _paths: PackedStringArray = []
var _done := 0
var _elapsed := 0.0
var _phase := 0      # 0 splash, 1 loading, 2 done
var _splash_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background())
	_build_splash()
	_build_loading()
	_loading.modulate.a = 0.0
	_loading.visible = false
	_run_splash()


func _build_splash() -> void:
	_splash = Control.new()
	_splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_splash)
	var logo := TextureRect.new()
	logo.texture = load(LOGO) if ResourceLoader.exists(LOGO) else null
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sz := Vector2(SPLASH_LOGO, SPLASH_LOGO)
	logo.custom_minimum_size = sz
	logo.size = sz
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	logo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.grow_vertical = Control.GROW_DIRECTION_BOTH
	logo.offset_left = -sz.x / 2.0
	logo.offset_right = sz.x / 2.0
	logo.offset_top = -sz.y / 2.0
	logo.offset_bottom = sz.y / 2.0
	logo.pivot_offset = sz / 2.0
	logo.name = "Logo"
	_splash.add_child(logo)


func _build_loading() -> void:
	_loading = Control.new()
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loading)

	var box := UI.column(UI.SPACE_M)
	box.custom_minimum_size = Vector2(800, 0)
	_loading.add_child(box)
	box.add_child(UI.title("J-COMMAND", UI.FONT_DISPLAY))
	box.add_child(UI.tagline("Shed your cards. Stop the others."))
	box.add_child(UI.spacer(120))

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(800, 44)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = UI.SURFACE
	track.border_color = UI.SURFACE_BORDER
	track.set_border_width_all(3)
	track.set_corner_radius_all(22)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI.AMBER
	fill.set_corner_radius_all(22)
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)

	_status = UI.hint("Loading...", 800)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	var tip := UI.hint("Tip: " + TIPS[randi() % TIPS.size()], 800)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override("font_color", UI.TEXT_DIM)
	box.add_child(UI.spacer(60))
	box.add_child(tip)


func _run_splash() -> void:
	var logo: Control = _splash.get_node("Logo")
	var reduce := Settings.reduce()
	logo.modulate.a = 0.0
	logo.scale = Vector2.ONE * (1.0 if reduce else 0.8)
	_splash_tween = create_tween()
	_splash_tween.tween_property(logo, "modulate:a", 1.0, SPLASH_IN)
	if not reduce:
		_splash_tween.parallel().tween_property(logo, "scale", Vector2.ONE, SPLASH_IN) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_splash_tween.tween_interval(SPLASH_HOLD)
	_splash_tween.tween_property(_splash, "modulate:a", 0.0, SPLASH_OUT)
	_splash_tween.tween_callback(_start_loading)


func _input(event: InputEvent) -> void:
	if _phase == 0 and (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		if _splash_tween != null:
			_splash_tween.kill()
		_start_loading()


func _start_loading() -> void:
	if _phase != 0:
		return
	_phase = 1
	_splash.visible = false
	_loading.visible = true
	create_tween().tween_property(_loading, "modulate:a", 1.0, 0.35)
	_paths = _resource_list()
	for p in _paths:
		ResourceLoader.load_threaded_request(p)


func _resource_list() -> PackedStringArray:
	var out := PackedStringArray()
	for s in Avatar.STYLES:
		var n := str(s["name"]).to_lower()
		for anim in ["idle", "happy"]:
			_add_if_exists(out, "res://assets/avatars/%s_%s.png" % [n, anim])
	for su in ["H", "D", "C", "S"]:
		_add_if_exists(out, "res://assets/suits/suit_%s.png" % su)
	for col in ["red", "black"]:
		for anim in ["roar", "idle"]:
			_add_if_exists(out, "res://assets/joker/joker_%s_%s.png" % [col, anim])
	return out


func _add_if_exists(list: PackedStringArray, path: String) -> void:
	if ResourceLoader.exists(path):
		list.append(path)


func _process(delta: float) -> void:
	if _phase != 1:
		return
	_elapsed += delta
	var done := 0
	for p in _paths:
		var st := ResourceLoader.load_threaded_get_status(p)
		if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			done += 1  # loaded, or failed (the game falls back to vector art)
	_done = done
	var real := 1.0 if _paths.is_empty() else float(done) / float(_paths.size())
	# Never run ahead of the minimum display time, so the bar always fills smoothly.
	var shown := minf(real, _elapsed / MIN_LOADING)
	_bar.value = move_toward(_bar.value, shown, delta * 1.5)
	_status.text = "Loading..." if _bar.value < 1.0 else "Ready!"
	if real >= 1.0 and _elapsed >= MIN_LOADING and _bar.value >= 1.0:
		_phase = 2
		_finish()


func _finish() -> void:
	for p in _paths:
		if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(p) # keep the loaded resource in the cache
	var t := create_tween()
	t.tween_interval(0.25)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func(): finished.emit())
