extends Control
## Leaderboard overlay: personal stats and the top local scores.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Leaderboard := preload("res://scripts/game/leaderboard.gd")

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	add_child(UI.background())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UI.MARGIN_SCREEN)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UI.SPACE_M)
	margin.add_child(col)
	var t := UI.title("Leaderboard")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)

	var st := Leaderboard.stats()
	col.add_child(UI.tagline("%d games  -  %d wins  -  %d clean finishes" % [st["games"], st["wins"], st["cleans"]]))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var card := UI.panel()
	card[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card[0])
	var list: Array = Leaderboard.entries()
	if list.is_empty():
		card[1].add_child(UI.body("No games yet. Finish a game to set a score.

Finish without ever drawing from the bank for a CLEAN FINISH: 3000 bonus points.", 900))
	for i in list.size():
		card[1].add_child(_row(i + 1, list[i]))

	var close := UI.button("Close", UI.Variant.SECONDARY, func(): closed.emit())
	close.custom_minimum_size.x = 0
	col.add_child(close)


func _row(rank: int, e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.SPACE_M)
	var r := UI.heading("#%d" % rank) if rank > 3 else UI.heading(["1st", "2nd", "3rd"][rank - 1])
	r.custom_minimum_size.x = 110
	row.add_child(r)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pts := UI.body("%d pts%s" % [int(e["score"]), "  CLEAN" if e.get("clean", false) else ""], 0.0, UI.FONT_BODY)
	if e.get("clean", false):
		pts.add_theme_color_override("font_color", UI.GOLD)
	mid.add_child(pts)
	var place := int(e["place"])
	var detail := UI.hint("%s of %d  -  %s  -  %s" % [["", "1st", "2nd", "3rd", "4th"][clampi(place, 0, 4)], int(e["players"]), str(e["difficulty"]).capitalize(), str(e["date"])], 0.0)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(detail)
	row.add_child(mid)
	return row
