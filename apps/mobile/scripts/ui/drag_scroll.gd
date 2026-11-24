extends ScrollContainer
## ScrollContainer that scrolls by click/touch-dragging anywhere inside it, including
## when the press starts on a button. Once the pointer moves past the deadzone the
## press becomes a scroll: buttons stop reacting until release, so nothing gets
## toggled by accident. Touch works through Godot's emulated mouse events.

const DEADZONE := 14.0

## Controls that sit on top of this one (pinned header/footer): presses there never scroll.
var blockers: Array = []

var _pressing := false
var _dragging := false
var _press_y := 0.0
var _press_scroll := 0


func _ready() -> void:
	scroll_deadzone = 1000000   # turn off the built-in touch drag; this script replaces it


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = false
			_pressing = get_global_rect().has_point(event.position)
			for b in blockers:
				if is_instance_valid(b) and (b as Control).get_global_rect().has_point(event.position):
					_pressing = false
			_press_y = event.position.y
			_press_scroll = scroll_vertical
		else:
			var was := _dragging
			_pressing = false
			_dragging = false
			if was:
				get_viewport().set_input_as_handled()
				_set_buttons_ignore(false)
	elif event is InputEventMouseMotion and _pressing:
		var dy: float = event.position.y - _press_y
		if not _dragging and absf(dy) > DEADZONE:
			_dragging = true
			_set_buttons_ignore(true)   # cancels the press so the release won't click
		if _dragging:
			scroll_vertical = int(_press_scroll - dy)
			get_viewport().set_input_as_handled()


func _set_buttons_ignore(on: bool) -> void:
	for n in find_children("*", "BaseButton", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
