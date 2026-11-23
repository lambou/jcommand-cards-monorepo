extends Control
## Free-turn inspector for the 3D suit models, shown on the real table colours and inside the real
## in-game widgets (suit picker buttons, the PLAY pill, a card face) so lighting can be judged in context.
##   drag / left-right keys : turn the big suits freely (with inertia)
##   space                  : toggle auto-spin
##   esc                    : quit
## Launch: godot --path apps/mobile -- --modelview      (see main.gd for --modelviewshot)

const TextFx := preload("res://scripts/ui/text_fx.gd")
const CardArt := preload("res://scripts/ui/card_art.gd")
const Suit3D := preload("res://scripts/ui/suit3d.gd")
const SuitButton := preload("res://scripts/ui/suit_button.gd")
const RequiredView := preload("res://scripts/ui/required_view.gd")

const SUITS := ["H", "D", "C", "S"]
const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")

var angle := 0.0          # degrees, shared by the big suits
var _vel := 0.0           # deg/s inertia after a drag
var _drag := false
var auto_spin := false

var _buttons: Array = []
var _pills: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for s in SUITS:
		var b := SuitButton.new(s)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		_buttons.append(b)
	for r in [{"kind": "suit", "suit": "H"}, {"kind": "suit", "suit": "S"}, {"kind": "color", "color": "red"}, {"kind": "color", "color": "black"}]:
		var p := RequiredView.new()
		p.set_required(r)
		add_child(p)
		_pills.append(p)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var gap := 24.0
	var bw := (_buttons[0] as Control).size.x
	var x := (w - (bw * 4 + gap * 3)) / 2.0
	for b in _buttons:
		b.position = Vector2(x, h * 0.62)
		x += bw + gap
	var pw := (_pills[0] as Control).size.x
	var cols := 2
	var px := (w - (pw * cols + gap)) / 2.0
	for i in _pills.size():
		var p: Control = _pills[i]
		p.position = Vector2(px + (i % cols) * (pw + gap), h * 0.62 + 210.0 + (i / cols) * 110.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		if _drag:
			_vel = 0.0
	elif event is InputEventMouseMotion and _drag:
		angle += event.relative.x * 0.9
		_vel = event.relative.x * 0.9 / maxf(get_process_delta_time(), 0.001)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed:
		return
	match event.keycode:
		KEY_LEFT:
			angle -= 7.5
		KEY_RIGHT:
			angle += 7.5
		KEY_SPACE:
			auto_spin = not auto_spin
		KEY_ESCAPE:
			get_tree().quit()


func _process(delta: float) -> void:
	if auto_spin:
		angle += 60.0 * delta
	elif not _drag and absf(_vel) > 1.0:
		angle += _vel * delta
		_vel = lerpf(_vel, 0.0, minf(delta * 4.0, 1.0))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.33, 0.21))   # same as the table bg
	var w := size.x
	var h := size.y
	TextFx.draw(self, FONT, Vector2(0, 62), "3D suit models - drag to turn", HORIZONTAL_ALIGNMENT_CENTER, w, 40, Color.WHITE)

	# Big suits on the table colour (top) and on a card face (below), same angle.
	var cell := minf(w / 4.4, h * 0.26)
	var x0 := (w - cell * 4) / 2.0
	for i in 4:
		var s: String = SUITS[i]
		var cx := x0 + cell * (i + 0.5)
		Suit3D.draw(self, s, Vector2(cx, h * 0.2), cell * 0.4, angle)
		var card := Rect2(cx - cell * 0.32, h * 0.33, cell * 0.64, cell * 0.64 * 1.43)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(14)
		box.bg_color = Color(0.99, 0.98, 0.95)
		box.set_border_width_all(3)
		box.border_color = CardArt.BLACK
		draw_style_box(box, card)
		Suit3D.draw(self, s, card.get_center(), cell * 0.2, angle)
	TextFx.draw(self, FONT, Vector2(0, h - 14), "angle %d  |  space: auto-spin  |  esc: quit" % int(posmod(angle, 360.0)), HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(1, 1, 1, 0.7))
