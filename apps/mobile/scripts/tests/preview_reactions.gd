extends SceneTree
## Dev tool: renders every reaction sticker at a few moments in time to PNG contact sheets.
## Needs a real renderer (not --headless):
##   godot --path apps/mobile --resolution 1100x480 -s res://scripts/tests/preview_reactions.gd -- <out_dir>

const Art := preload("res://scripts/ui/reaction_art.gd")
const Reactions := preload("res://scripts/game/reactions.gd")

const TIMES := [0.15, 0.5, 0.9, 1.3]


class Sheet extends Control:
	var t := 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.33, 0.21))
		var i := 0
		for r in Reactions.LIST:
			var c := Vector2(110.0 + (i % 5) * 220.0, 120.0 + (i / 5) * 230.0)
			Art.draw(self, r["id"], c, 90.0, t)
			i += 1


func _init() -> void:
	var out := "user://reaction_preview"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	# Render in our own viewport so the project's 1080x1920 stretch does not rescale the sheet.
	var vp := SubViewport.new()
	vp.size = Vector2i(1100, 480)
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var sheet := Sheet.new()
	sheet.size = Vector2(1100, 480)
	vp.add_child(sheet)
	await process_frame
	for t in TIMES:
		sheet.t = t
		sheet.queue_redraw()
		await process_frame
		await process_frame
		var img := vp.get_texture().get_image()
		img.save_png("%s/sheet_t%03d.png" % [out, int(t * 100.0)])
	print("saved previews to ", out)
	quit()
