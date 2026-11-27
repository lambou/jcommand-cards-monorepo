extends RefCounted
## The version shown in the app ("v1.4.2 (87)" on the start menu, like Subway Surfers).
##
## Never edited by hand. The release pipeline (.github/workflows/release-android.yml) derives the
## semver from the Conventional Commits since the last v* git tag, then writes
## res://build_info.json before exporting:  {"version": "1.4.2", "build": 87, "commit": "ab12cd3"}
## `build` is also the Android versionCode. The file is gitignored, so a local / editor run has
## no build info and shows "dev".

const BUILD_INFO := "res://build_info.json"
const UI := preload("res://scripts/ui/ui_kit.gd")

static var _cache: Dictionary = {}


static func info() -> Dictionary:
	if _cache.is_empty():
		_cache = {"version": "dev", "build": 0, "commit": ""}
		if FileAccess.file_exists(BUILD_INFO):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO))
			if parsed is Dictionary:
				_cache["version"] = str(parsed.get("version", "dev"))
				_cache["build"] = int(parsed.get("build", 0))
				_cache["commit"] = str(parsed.get("commit", ""))
	return _cache


## "1.4.2"
static func version_name() -> String:
	return str(info()["version"])


## "v1.4.2 (87)", or "dev" when there is no build info.
static func label_text() -> String:
	var i := info()
	if i["version"] == "dev":
		return "dev"
	var s := "v%s" % i["version"]
	if int(i["build"]) > 0:
		s += " (%d)" % int(i["build"])
	return s


## Small dim caption pinned to the bottom of its parent; ignores input.
static func make_label() -> Label:
	var l := UI.hint(label_text())
	l.name = "VersionLabel"
	l.add_theme_font_size_override("font_size", UI.FONT_CAPTION)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -64
	l.offset_bottom = -24
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return l
