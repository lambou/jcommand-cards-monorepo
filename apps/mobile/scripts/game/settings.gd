extends RefCounted
## Player settings, saved in user://settings.cfg. Read them through the static vars;
## call save() after changing one.

const PATH := "user://settings.cfg"

static var sound_enabled := true
static var volume := 0.8 # 0..1
static var reduce_motion := false

static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sound_enabled = bool(cfg.get_value("audio", "enabled", true))
	volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)
	reduce_motion = bool(cfg.get_value("accessibility", "reduce_motion", false))


## True when motion effects (shake, flashes, sparks, confetti, pulses, bounces) must be skipped.
static func reduce() -> bool:
	load_settings()
	return reduce_motion


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "enabled", sound_enabled)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("accessibility", "reduce_motion", reduce_motion)
	cfg.save(PATH)
