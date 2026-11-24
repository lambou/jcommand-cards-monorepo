extends Control
## Leaderboard overlay: personal stats and the top local scores.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Leaderboard := preload("res://scripts/game/leaderboard.gd")

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	add_child(UI.background())
	var page := UI.scroll_page("Leaderboard", "Close", func(): closed.emit())
	add_child(page["scroll"])
	add_child(page["header"])
	add_child(page["footer"])
	var col: VBoxContainer = page["content"]

	var st := Leaderboard.stats()
	col.add_child(UI.tagline("%d games  -  %d wins  -  %d clean finishes" % [st["games"], st["wins"], st["cleans"]]))

	var list: Array = Leaderboard.entries()
	if list.is_empty():
		col.add_child(UI.body("No games yet. Finish a game to set a score.

Finish without ever drawing from the bank for a CLEAN FINISH: 3000 bonus points.", 900))
	for i in list.size():
		col.add_child(_row(i + 1, list[i]))


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
