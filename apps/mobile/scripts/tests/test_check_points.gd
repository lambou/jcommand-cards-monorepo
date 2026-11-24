extends SceneTree
## The CHECK! plate and the points label under your avatar must stack, never overlap:
##   godot --headless --path apps/mobile -s res://scripts/tests/test_check_points.gd

const Table := preload("res://scripts/ui/table.gd")
const AvatarView := preload("res://scripts/ui/avatar_view.gd")

var failures: Array = []


func _init() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame # the tree must be live before Table's children get their _ready
	for sz in [Vector2i(1080, 1920), Vector2i(720, 1280), Vector2i(1080, 2400)]:
		await _run(sz)
	if failures.is_empty():
		print("PASS: check plate and points stack")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)


func _plate_bottom(t) -> float:
	return t.you_avatar.position.y + t.you_avatar.size.y - 10.0 + AvatarView.CHECK_PLATE_H


func _run(sz: Vector2i) -> void:
	var t := Table.new()
	root.add_child(t)
	root.size = sz
	await process_frame
	t.start(1, "easy")
	await process_frame
	t._relayout()
	var tag := str(sz)
	var y_idle: float = t.you_points.position.y
	if t.you_points.position.y < t.you_avatar.position.y + t.you_avatar.size.y:
		failures.append("%s: idle points are above the avatar's bottom" % tag)

	var st: Dictionary = t.game.state.duplicate(true)
	for p in st["players"]:
		if p["id"] == t.ME:
			p["status"] = "playing"
			p["hand"] = [p["hand"][0]]
	st["over"] = false
	t._update_check_state(st)
	if not t.you_avatar.check:
		failures.append("%s: avatar did not enter check" % tag)
	await create_timer(0.4).timeout
	var y_check: float = t.you_points.position.y
	if absf(y_check - (y_idle + AvatarView.CHECK_DROP)) > 0.5:
		failures.append("%s: points did not drop (%.1f -> %.1f)" % [tag, y_idle, y_check])
	if y_check < _plate_bottom(t):
		failures.append("%s: points overlap the plate (%.1f < %.1f)" % [tag, y_check, _plate_bottom(t)])

	for p in st["players"]:
		if p["id"] == t.ME:
			p["hand"] = [p["hand"][0], p["hand"][0]]
	t._update_check_state(st)
	await create_timer(0.4).timeout
	if t.you_avatar.check or absf(t.you_points.position.y - y_idle) > 0.5:
		failures.append("%s: points did not return (%.1f vs %.1f)" % [tag, t.you_points.position.y, y_idle])

	# a relayout while in check keeps the stack
	for p in st["players"]:
		if p["id"] == t.ME:
			p["hand"] = [p["hand"][0]]
	t._update_check_state(st)
	t._relayout()
	if absf(t.you_points.position.y - (y_idle + AvatarView.CHECK_DROP)) > 0.5:
		failures.append("%s: relayout in check lost the stack" % tag)
	t.queue_free()
