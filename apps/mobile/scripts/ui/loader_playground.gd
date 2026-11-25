extends Control
## Playground for the logo loader (ui/logo_loader.gd). Nothing here touches the game:
## run it with   godot --path apps/mobile -- --loaderplay   (or open scenes/loader_playground.tscn and press F6)
## Switch between Spinning and Progress, scrub the progress, run a fake load, finish it, try it small and
## without the tile, slow it down, and check Reduce motion.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Loader := preload("res://scripts/ui/logo_loader.gd")
const Settings := preload("res://scripts/game/settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

const BIG := 460.0
const SMALL := 96.0

var big: Loader
var small: Loader
var status: Label
var small_label: Label
var slider: HSlider
var _mode := 0   # 0 spinning, 1 progress
var _sim: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.load_settings()
	if Sfx.instance == null: # run on its own (F6) there is no Main to provide the sounds
		add_child(Sfx.new())
	add_child(UI.background())

	var col := UI.column(UI.SPACE_M)
	add_child(col)
	col.add_child(UI.title("Loader", UI.FONT_H1))

	big = Loader.new()
	big.custom_minimum_size = Vector2(BIG, BIG)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	big.completed.connect(func(): status.text = "Completed!")
	col.add_child(big)

	status = UI.hint("Spinning", 820)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(status)

	# The small one inline, as it would sit in a "finding players" row.
	var p := UI.panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.SPACE_M)
	small = Loader.new()
	small.show_tile = false
	small.custom_minimum_size = Vector2(SMALL, SMALL)
	row.add_child(small)
	small_label = UI.body("Finding players...")
	small_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(small_label)
	p[1].add_child(row)
	col.add_child(p[0])

	var controls := UI.panel()
	var box: VBoxContainer = controls[1]
	box.add_child(UI.heading("Mode"))
	box.add_child(UI.choice_row(["Spinning", "Progress"], 0, _set_mode, true))
	box.add_child(UI.heading("Progress"))
	slider = _slider(0.0, 1.0, 0.0, func(x: float):
		_stop_sim()
		_set_progress(x))
	box.add_child(slider)
	box.add_child(UI.heading("Slow motion"))
	box.add_child(_slider(0.1, 1.0, 1.0, func(x: float): Engine.time_scale = x))
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", UI.SPACE_S)
	var tile := UI.pill("Tile: On", true, Vector2(UI.PILL_W * 2, UI.PILL_H))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.toggled.connect(func(on: bool):
		big.show_tile = on
		tile.text = "Tile: On" if on else "Tile: Off")
	toggles.add_child(tile)
	var reduce := UI.pill("Reduce motion: Off", false, Vector2(UI.PILL_W * 2, UI.PILL_H))
	reduce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reduce.toggled.connect(func(on: bool):
		big.reduce_override = 1 if on else 0
		small.reduce_override = big.reduce_override
		reduce.text = "Reduce motion: On" if on else "Reduce motion: Off")
	toggles.add_child(reduce)
	box.add_child(toggles)
	col.add_child(controls[0])

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", UI.SPACE_S)
	for spec in [["Assemble", UI.Variant.SECONDARY, _assemble], ["Finish", UI.Variant.TERTIARY, _finish]]:
		var b := UI.button(spec[0], spec[1], spec[2])
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)
	col.add_child(actions)
	col.add_child(UI.button("Simulate load", UI.Variant.PRIMARY, _simulate, true))


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _slider(lo: float, hi: float, v: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = v
	s.custom_minimum_size = Vector2(0, 60)
	s.value_changed.connect(cb)
	return s


func _set_mode(i: int) -> void:
	_mode = i
	_stop_sim()
	big.reset()
	if i == 0:
		big.progress = -1.0
		status.text = "Spinning"
	else:
		_set_progress(slider.value)


func _set_progress(x: float) -> void:
	if _mode == 0:
		return
	big.progress = x
	status.text = "Loading... %d%%" % roundi(x * 100.0)


func _assemble() -> void:
	big.assemble()
	small.assemble()


func _finish() -> void:
	_stop_sim()
	status.text = "Finishing..."
	big.complete()


## A fake load: progress arrives in uneven chunks, like real resources would, then the loader finishes.
func _simulate() -> void:
	_stop_sim()
	_mode = 1
	big.reset()
	big.progress = 0.0
	slider.set_value_no_signal(0.0)
	_sim = create_tween()
	var v := 0.0
	while v < 1.0:
		v = minf(v + randf_range(0.04, 0.16), 1.0)
		var target := v
		_sim.tween_interval(randf_range(0.08, 0.35))
		_sim.tween_callback(func():
			slider.set_value_no_signal(target)
			_set_progress(target))
	_sim.tween_interval(0.5)
	_sim.tween_callback(_finish)


func _stop_sim() -> void:
	if _sim != null and _sim.is_valid():
		_sim.kill()
	_sim = null


# ---------------------------------------------------------------- screenshots

## `--loadershot=<file.png>`: <file>_spin0..3 (spinner through one lap), _p25/_p60/_p100, _bare.
func capture(path: String) -> void:
	var base := path.get_basename()
	await get_tree().create_timer(1.0).timeout
	for i in 4:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_spin%d.png" % [base, i])
		await get_tree().create_timer(big.period / 4.0).timeout
	_set_mode(1)
	for p in [0.3, 0.6, 1.0]:
		_set_progress(p)
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_p%d.png" % [base, roundi(p * 100.0)])
	_set_mode(0)
	big.show_tile = false
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_bare.png" % base)
	get_tree().quit()
