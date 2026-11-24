extends RefCounted
## Player settings, saved in user://settings.cfg. Read them through the static vars;
## call save() after changing one.

const PATH := "user://settings.cfg"

static var sound_enabled := true
static var volume := 0.8 # 0..1
static var reduce_motion := false
static var show_reactions := true # emoji reactions: the button, and bots reacting
static var hand_you := true # 3D hand that plays your cards
static var hand_bots := true # 3D hands that play the opponents' cards
static var hand_color := 0 # index into Hand3D.STYLES; opponents get the following ones
static var table_style := 0 # index into TableBg.STYLES
static var avatar := 0 # index into Avatar.STYLES; the bots get the other three

static var tutorial_seen := false # the one-time "learn with Rex" prompt has been shown
static var tutorial_done: Array = [] # ids of the finished tutorial chapters

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
	show_reactions = bool(cfg.get_value("game", "show_reactions", true))
	hand_you = bool(cfg.get_value("game", "hand_you", true))
	hand_bots = bool(cfg.get_value("game", "hand_bots", true))
	hand_color = maxi(int(cfg.get_value("game", "hand_color", 0)), 0)
	table_style = maxi(int(cfg.get_value("game", "table_style", 0)), 0)
	avatar = maxi(int(cfg.get_value("game", "avatar", 0)), 0)
	tutorial_seen = bool(cfg.get_value("tutorial", "seen", false))
	tutorial_done = Array(cfg.get_value("tutorial", "done", []))


## Whether a 3D hand should play the cards of you (`bots` false) or of the opponents; off with reduce motion.
static func hands(bots: bool) -> bool:
	load_settings()
	return not reduce_motion and (hand_bots if bots else hand_you)


## True when motion effects (shake, flashes, sparks, confetti, pulses, bounces) must be skipped.
static func reduce() -> bool:
	load_settings()
	return reduce_motion


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "enabled", sound_enabled)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("accessibility", "reduce_motion", reduce_motion)
	cfg.set_value("game", "show_reactions", show_reactions)
	cfg.set_value("game", "hand_you", hand_you)
	cfg.set_value("game", "hand_bots", hand_bots)
	cfg.set_value("game", "hand_color", hand_color)
	cfg.set_value("game", "table_style", table_style)
	cfg.set_value("game", "avatar", avatar)
	cfg.set_value("tutorial", "seen", tutorial_seen)
	cfg.set_value("tutorial", "done", tutorial_done)
	cfg.save(PATH)


static func tutorial_chapter_done(id: String) -> bool:
	load_settings()
	return tutorial_done.has(id)


## Remembers a finished chapter. Debug runs (screenshots, tests) never write the player's settings.
static func mark_tutorial_done(id: String) -> void:
	load_settings()
	if not tutorial_done.has(id):
		tutorial_done.append(id)
		if OS.get_cmdline_user_args().is_empty():
			save()
