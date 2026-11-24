extends Control
## Your side of reactions: a round button by your avatar that opens a grid of the ten stickers.
## Tap one and `picked(id)` fires; the popup closes. The table decides what happens next
## (show it, play the sound, tell the other players), so this stays UI-only.

const Art := preload("res://scripts/ui/reaction_art.gd")
const Reactions := preload("res://scripts/game/reactions.gd")
const Settings := preload("res://scripts/game/settings.gd")

signal picked(id: String)

const BTN := 104.0
const COLS := 5
const CELL := Vector2(148, 176)
const GAP := 8.0
const PAD := 24.0
const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")

var _button: Control
var _overlay: Control
var _panel: Panel
var _cells: Array = []
var _cool_until := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 800

	_button = Control.new()
	_button.size = Vector2(BTN, BTN)
	_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_button.draw.connect(_draw_button)
	_button.gui_input.connect(_on_button_input)
	add_child(_button)

	# A transparent full-screen layer: tapping outside the grid closes it.
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(_overlay)

	_panel = Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(TableBg.current_theme()["panel"], 0.97)
	ps.set_corner_radius_all(40)
	ps.set_border_width_all(6)
	ps.border_color = Color(0.93, 0.76, 0.28)
	ps.shadow_color = Color(0, 0, 0, 0.5)
	ps.shadow_size = 30
	ps.shadow_offset = Vector2(0, 10)
	ps.anti_aliasing = true
	_panel.add_theme_stylebox_override("panel", ps)
	_overlay.add_child(_panel)

	var rows := int(ceil(float(Reactions.LIST.size()) / float(COLS)))
	_panel.size = Vector2(COLS * CELL.x + (COLS - 1) * GAP + PAD * 2.0, rows * CELL.y + (rows - 1) * GAP + PAD * 2.0)
	for i in Reactions.LIST.size():
		var cell := Cell.new(Reactions.LIST[i]["id"])
		cell.position = Vector2(PAD + (i % COLS) * (CELL.x + GAP), PAD + (i / COLS) * (CELL.y + GAP))
		cell.size = CELL
		cell.tapped.connect(_on_tapped)
		_panel.add_child(cell)
		_cells.append(cell)


## Puts the button at `pos` (top-left) and tucks the popup above it, inside `view` bounds.
func place(pos: Vector2, view: Vector2) -> void:
	if _button == null:
		return
	_button.position = pos
	var x := clampf(pos.x + BTN - _panel.size.x, 12.0, maxf(view.x - _panel.size.x - 12.0, 12.0))
	var y := maxf(pos.y - _panel.size.y - 18.0, 12.0)
	_panel.position = Vector2(x, y)


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func open() -> void:
	if _overlay == null or not visible or _cooling():
		return
	_overlay.visible = true
	if Settings.reduce():
		_panel.modulate.a = 1.0
		return
	_panel.pivot_offset = Vector2(_panel.size.x, _panel.size.y)
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.12)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _overlay != null:
		_overlay.visible = false


## Greys the sticker button out for `seconds` after you send one (anti-spam).
func start_cooldown(seconds: float) -> void:
	_cool_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	for c in _cells:
		c.enabled = false
	_button.queue_redraw()
	get_tree().create_timer(seconds).timeout.connect(func():
		for c in _cells:
			c.enabled = true
		if _button != null:
			_button.queue_redraw())


func _cooling() -> bool:
	return Time.get_ticks_msec() < _cool_until


func _on_button_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_button.accept_event()
		if is_open():
			close()
		else:
			open()


func _on_tapped(id: String) -> void:
	if _cooling():
		return
	close()
	picked.emit(id)


func _draw_button() -> void:
	var c := Vector2(BTN, BTN) / 2.0
	var dim := 0.45 if _cooling() else 1.0
	_button.draw_circle(c + Vector2(0, 5), BTN / 2.0, Color(0, 0, 0, 0.35 * dim))
	_button.draw_circle(c, BTN / 2.0, Color(0.93, 0.76, 0.28, dim))
	_button.draw_circle(c, BTN / 2.0 - 7.0, Color(TableBg.current_theme()["panel"], dim))
	Art.draw(_button, "laugh", c, BTN / 2.0 - 12.0, 0.9, false)
	if _cooling():
		_button.draw_circle(c, BTN / 2.0, Color(0, 0, 0, 0.3))


## One sticker in the grid: it keeps animating while the popup is open.
class Cell extends Control:
	signal tapped(id: String)

	var id := ""
	var enabled := true:
		set(v):
			enabled = v
			queue_redraw()
	var _t := 0.0

	func _init(p_id: String) -> void:
		id = p_id
		mouse_filter = Control.MOUSE_FILTER_STOP
		_t = randf() * 1.5

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if enabled:
				tapped.emit(id)

	func _draw() -> void:
		var r := size.x * 0.4
		var c := Vector2(size.x / 2.0, r + 6.0)
		var dim := 1.0 if enabled else 0.45
		var t := fposmod(_t, 2.4) if not Settings.reduce() else 0.9
		Art.draw(self, id, c, r, t)
		if dim < 1.0:
			draw_circle(c, r * 1.02, Color(TableBg.current_theme()["panel"], 0.55))
		var label: String = Reactions.info(id).get("name", id)
		draw_string(FONT, Vector2(0, size.y - 12.0), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1, 1, 1, 0.9 * dim))
