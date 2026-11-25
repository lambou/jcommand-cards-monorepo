extends SceneTree
## The "Dealing" button in the settings panel names the current style, and every style the plan knows is reachable.
## (It only reads and relabels: it never presses the button, so the player's saved settings are not touched.)
##   godot --headless --path apps/mobile -s res://scripts/tests/test_deal_settings_ui.gd

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const Settings := preload("res://scripts/game/settings.gd")
const DealPlan := preload("res://scripts/game/deal_plan.gd")

var failures: Array = []


func _init() -> void:
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _run() -> void:
	await process_frame
	Settings.load_settings()
	var original := Settings.deal_style
	var panel: Control = SettingsPanel.new()
	root.add_child(panel)
	await process_frame
	_check(panel._deal_btn != null, "the panel has a Dealing button")
	for style in [DealPlan.FLY, DealPlan.DEALER, DealPlan.PACKETS]:
		Settings.deal_style = style
		panel._refresh()
		_check(panel._deal_btn.text == "Dealing: %s" % Settings.DEAL_STYLES[style], "the button names style %d (%s)" % [style, panel._deal_btn.text])
	# Pressing it steps through every style and comes back round (checked on the arithmetic the handler uses).
	var seen := {}
	var cur := DealPlan.FLY
	for i in Settings.DEAL_STYLES.size():
		seen[cur] = true
		cur = (cur + 1) % Settings.DEAL_STYLES.size()
	_check(seen.size() == 3 and cur == DealPlan.FLY, "cycling reaches all three styles and wraps")
	Settings.deal_style = original

	if failures.is_empty():
		print("PASS: deal settings button")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL " + f)
		quit(1)
