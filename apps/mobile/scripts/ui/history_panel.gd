extends Control
## Game history overlay: the recorded games kept on this device, each one replayable.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Recorder := preload("res://scripts/game/recorder.gd")

signal closed
signal replay_requested(path: String)

var _col: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	add_child(UI.background())
	var page := UI.scroll_page("History", "Close", func(): closed.emit())
	add_child(page["scroll"])
	add_child(page["header"])
	add_child(page["footer"])
	_col = page["content"]
	_fill()


func _fill() -> void:
	for c in _col.get_children():
		c.queue_free()
	var list: Array = Recorder.list().filter(func(r): return r["finished"])
	if list.is_empty():
		_col.add_child(UI.body("No recorded games yet. Finished games are kept here so you can watch them again.", 900))
	for rec in list:
		_col.add_child(_row(rec))


func _row(rec: Dictionary) -> Control:
	var h: Dictionary = rec["header"]
	var f: Dictionary = rec["footer"]
	var card := UI.panel(UI.SPACE_S)
	card[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var place := int(f.get("human_place", 0))
	var result := "Lost"
	if bool(f.get("human_out", false)):
		result = ["", "1st", "2nd", "3rd", "4th"][clampi(place, 0, 4)]
	var title := UI.heading("%s of %d  -  %s" % [result, (h["player_ids"] as Array).size(), str(h["difficulty"]).capitalize()])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card[1].add_child(title)
	var when := Time.get_datetime_string_from_unix_time(int(h["started_at"]), true)
	var detail := UI.hint("%s  -  %d moves" % [when, int(f.get("actions", 0))], 0.0)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card[1].add_child(detail)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UI.SPACE_M)
	var path: String = rec["path"]
	var replay := UI.pill("Replay", true, Vector2(UI.PILL_W + 30, 90), 44)
	replay.pressed.connect(func(): replay_requested.emit(path))
	var del := UI.pill("Delete", false, Vector2(UI.PILL_W + 30, 90), 44)
	del.pressed.connect(func():
		Recorder.delete(path)
		_fill())
	buttons.add_child(replay)
	buttons.add_child(del)
	card[1].add_child(buttons)
	return card[0]
