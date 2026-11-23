extends SceneTree
## Headless conformance runner:
##   godot --headless --path apps/mobile -s res://scripts/tests/run_conformance.gd [-- <rules-spec dir>]
## Exits non-zero on any failure.

const Testing := preload("res://scripts/engine/testing.gd")
const CardEngine := preload("res://scripts/engine/engine.gd")


func _init() -> void:
	var spec_dir := _spec_dir()
	var failures: Array = []
	var total := 0

	# 1. The synced rules copy must match the source of truth.
	var src := FileAccess.get_file_as_string(spec_dir.path_join("rules.json"))
	var copy := FileAccess.get_file_as_string("res://data/rules.json")
	if src.is_empty():
		failures.append("cannot read %s" % spec_dir.path_join("rules.json"))
	elif src != copy:
		failures.append("apps/mobile/data/rules.json is out of sync with packages/rules-spec/rules.json (run tools/conformance/sync-rules.mjs)")

	# 2. Golden scenarios.
	var sdir := spec_dir.path_join("scenarios")
	var files := Array(DirAccess.get_files_at(sdir))
	files.sort()
	for f in files:
		if not str(f).ends_with(".json"):
			continue
		var scenarios = JSON.parse_string(FileAccess.get_file_as_string(sdir.path_join(f)))
		for sc in scenarios:
			total += 1
			var errs := Testing.run_scenario(sc)
			if errs.is_empty():
				print("ok   %s / %s" % [f, sc["name"]])
			else:
				for e in errs:
					failures.append("%s: %s" % [f, e])

	# 3. Deal / start-card cases (also checks RNG parity).
	var ddir := spec_dir.path_join("deals")
	var dfiles := Array(DirAccess.get_files_at(ddir))
	dfiles.sort()
	for f in dfiles:
		if not str(f).ends_with(".json"):
			continue
		var deals = JSON.parse_string(FileAccess.get_file_as_string(ddir.path_join(f)))
		for d in deals:
			total += 1
			var errs := Testing.run_playout(d) if str(f) == "playouts.json" else Testing.run_deal(d)
			if errs.is_empty():
				print("ok   %s / %s" % [f, d["name"]])
			else:
				for e in errs:
					failures.append("%s: %s" % [f, e])

	print("")
	if failures.is_empty():
		print("PASS: %d cases" % total)
		quit(0)
	else:
		for e in failures:
			printerr("FAIL " + e)
		printerr("FAILED: %d failure(s) in %d cases" % [failures.size(), total])
		quit(1)


func _spec_dir() -> String:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		return args[0]
	return ProjectSettings.globalize_path("res://").path_join("../../packages/rules-spec").simplify_path()
