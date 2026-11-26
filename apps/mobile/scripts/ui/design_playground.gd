extends Control
## Design-system playground: every ui_kit.gd component on one scrolling page, built by the real kit, so a theme
## or a widget change is tried and validated here before it reaches a screen. Run it with
##   godot --path apps/mobile -- --dsplay      (or open scenes/design_playground.tscn and press F6)
## Screenshots: --dsshot=<file.png>.
##
## The footer switches the active theme (ui_themes.gd) and overrides its style options (corners, gloss, shadow,
## bold text) live, by writing to UI.style. Whatever looks right here is what the game gets: set the same values
## in ui_themes.gd.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Themes := preload("res://scripts/ui/ui_themes.gd")
const Settings := preload("res://scripts/game/settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

const GLOSS := ["Off", "Strip", "Swoosh", "Dot", "Slant", "Mixed"]
const SHADOWS := ["Strong", "Subtle", "None"]
const CORNERS := ["Round", "Soft", "Boxy"]
const CORNER_PX := [-1, 34, 16]   # button / pill corner radius per CORNERS entry (-1 = fully rounded)

var _root: Control
var _page: Dictionary
var _gloss_anchor: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.load_settings()
	if Sfx.instance == null: # run on its own (F6) there is no Main to provide the sounds
		add_child(Sfx.new())
	_apply(UI.theme_name)
	_build()


## Activate a theme (resetting the style switches to its own unless keep_style).
func _apply(name: String, keep_style: bool = false) -> void:
	var kept := UI.style.duplicate()
	UI.apply_theme(name)
	if keep_style:
		UI.style = kept


func _set_theme(i: int) -> void:
	_apply(Themes.NAMES[i])
	_build()


func _set_corner(i: int) -> void:
	UI.style["btn_radius"] = CORNER_PX[i]
	UI.style["pill_radius"] = CORNER_PX[i]
	_build()


func _set_gloss(i: int) -> void:
	UI.style["gloss"] = i
	_build()


func _set_shadow(i: int) -> void:
	UI.style["shadow"] = i
	_build()


func _set_bold(on: bool) -> void:
	UI.style["bold"] = on
	_build()


func _corner_index() -> int:
	var px := int(UI.style.get("btn_radius", -1))
	if px < 0:
		return 0
	return 1 if px >= 24 else 2


# ---------------------------------------------------------------- page

func _build() -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(UI.background())

	_page = UI.scroll_page("Design system", "", Callable())
	_root.add_child(_page["scroll"])
	_root.add_child(_page["header"])
	_root.add_child(_page["footer"])
	_footer(_page["footer_box"])

	var c: VBoxContainer = _page["content"]
	_menu_preview(c)
	_section(c, "Colour tokens", "Theme: %s. The palette every widget is built from." % UI.theme_name)
	c.add_child(_swatches())

	_section(c, "Contrast check", "Every foreground / background pair of the theme. 4.5 for text, 3 for button labels (WCAG).")
	c.add_child(_contrast_table())

	_section(c, "Type scale", "Lilita One. FONT_* sizes on the 1080x1920 viewport.")
	c.add_child(UI.title("DISPLAY 128", UI.FONT_DISPLAY))
	c.add_child(UI.title("H1 96", UI.FONT_H1))
	for spec in [["BUTTON_L 80", UI.FONT_BUTTON_L], ["PILL 52", UI.FONT_PILL], ["BUTTON 46", UI.FONT_BUTTON],
			["HEADING 40", UI.FONT_HEADING], ["BODY 38", UI.FONT_BODY], ["HINT 34", UI.FONT_HINT], ["CAPTION 30", UI.FONT_CAPTION]]:
		var l := UI.body(spec[0], 0.0, spec[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(l)

	_section(c, "Text", "brand_header / title / tagline / heading / body / hint")
	c.add_child(UI.brand_header("ZAPKO"))
	c.add_child(UI.title("Screen title"))
	c.add_child(UI.tagline("Shed your cards. Stop the others."))
	c.add_child(UI.heading("Section heading"))
	var body := UI.body("Body text is for paragraphs: rules, explanations and anything that needs to be read.", 900)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(body)
	c.add_child(UI.hint("A hint sits under a control and explains it."))

	_section(c, "Buttons", "button(text, Variant, on_press, large)")
	for spec in [["PLAY", UI.Variant.PRIMARY, true], ["Primary", UI.Variant.PRIMARY, false],
			["Secondary", UI.Variant.SECONDARY, false], ["Tertiary", UI.Variant.TERTIARY, false], ["Danger", UI.Variant.DANGER, false]]:
		var b := UI.button(spec[0], spec[1], func(): pass, spec[2])
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add_child(b)

	_section(c, "Gloss variants", "Every shape side by side. Pick one in the footer (Gloss row) to apply it everywhere.")
	_gloss_anchor = c.get_child(c.get_child_count() - 2)
	var kept := int(UI.style.get("gloss", 0))
	for m in range(1, GLOSS.size()):
		c.add_child(UI.heading(GLOSS[m]))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		UI.style["gloss"] = m
		for spec in [["Primary", UI.Variant.PRIMARY], ["Secondary", UI.Variant.SECONDARY], ["Tertiary", UI.Variant.TERTIARY]]:
			var gb := UI.button(spec[0], spec[1], func(): pass)
			gb.custom_minimum_size.x = 300
			row.add_child(gb)
		UI.style["gloss"] = kept
		c.add_child(row)

	_section(c, "Icon buttons", "icon_button(\"home\" | \"gear\", on_press, Variant)")
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", UI.SPACE_M)
	for spec in [["home", UI.Variant.SECONDARY], ["gear", UI.Variant.SECONDARY], ["home", UI.Variant.PRIMARY],
			["gear", UI.Variant.TERTIARY], ["gear", UI.Variant.DANGER]]:
		icons.add_child(UI.icon_button(spec[0], func(): pass, spec[1]))
	c.add_child(icons)

	_section(c, "Choices", "choice_row / toggle / stepper (gold = selected, OFF = not)")
	c.add_child(UI.choice_row(["1", "2", "3"], 1, func(_i): pass))
	c.add_child(UI.choice_row(["Easy", "Normal", "Hard"], 1, func(_i): pass, true))
	var tog_on := UI.toggle("Sound: On", true, func(_on): pass)
	tog_on.toggled.connect(func(on: bool): tog_on.text = "Sound: %s" % ("On" if on else "Off"))
	c.add_child(tog_on)
	var tog_off := UI.toggle("Reduce motion: Off", false, func(_on): pass)
	tog_off.toggled.connect(func(on: bool): tog_off.text = "Reduce motion: %s" % ("On" if on else "Off"))
	c.add_child(tog_off)
	var steps := HBoxContainer.new()
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	steps.add_theme_constant_override("separation", 20)
	var value := UI.body("50%", 0.0, UI.FONT_PILL)
	value.custom_minimum_size.x = 380
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vol := [50]
	steps.add_child(UI.stepper("-", func():
		vol[0] = maxi(vol[0] - 10, 0)
		value.text = "%d%%" % vol[0]))
	steps.add_child(value)
	steps.add_child(UI.stepper("+", func():
		vol[0] = mini(vol[0] + 10, 100)
		value.text = "%d%%" % vol[0]))
	c.add_child(steps)

	_section(c, "Panel", "panel() groups related controls, with headings inside")
	var card := UI.panel()
	card[0].custom_minimum_size.x = UI.MENU_W
	card[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card[1].add_child(UI.heading("Opponents"))
	card[1].add_child(UI.choice_row(["1", "2", "3"], 1, func(_i): pass, true))
	card[1].add_child(UI.heading("Difficulty"))
	card[1].add_child(UI.choice_row(["Easy", "Normal", "Hard"], 1, func(_i): pass, true))
	card[1].add_child(UI.hint("Cards hold body text and hints too.", 0.0))
	c.add_child(card[0])
	var score := UI.panel()
	score[0].custom_minimum_size.x = UI.MENU_W
	score[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var line := HBoxContainer.new()
	var place := UI.body("1st place", 0.0, UI.FONT_HINT)
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(place)
	var pts := UI.body("+1200 pts", 0.0, UI.FONT_HINT)
	pts.add_theme_color_override("font_color", UI.TEXT_ACCENT)
	line.add_child(pts)
	score[1].add_child(line)
	score[1].add_child(UI.title("4200 pts"))
	c.add_child(score[0])

	_section(c, "Popup over the table", "SCRIM + popup_style() on the live table")
	c.add_child(_table_popup())

	_section(c, "Scroll page", "scroll_page(): pinned header and footer, content slides under them")
	var open := UI.button("Open a scroll page", UI.Variant.SECONDARY, _open_scroll_demo)
	open.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(open)

	_section(c, "Spacing", "SPACE_S 16 / SPACE_M 30 / SPACE_L 60 / PANEL_PAD 36 / MARGIN_SCREEN 50")
	var gaps := HBoxContainer.new()
	gaps.alignment = BoxContainer.ALIGNMENT_CENTER
	gaps.add_theme_constant_override("separation", UI.SPACE_L)
	for spec in [["S", UI.SPACE_S], ["M", UI.SPACE_M], ["L", UI.SPACE_L], ["PAD", UI.PANEL_PAD], ["SCREEN", UI.MARGIN_SCREEN]]:
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_END
		var bar := ColorRect.new()
		bar.color = UI.SECONDARY
		bar.custom_minimum_size = Vector2(spec[1], spec[1])
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(bar)
		v.add_child(_caption(spec[0]))
		gaps.add_child(v)
	c.add_child(gaps)
	c.add_child(UI.spacer(UI.SPACE_L))


## The start menu's composition (logo, options card, PLAY, the secondary stack, Settings), to judge a theme on a real screen.
func _menu_preview(c: VBoxContainer) -> void:
	_section(c, "Start menu preview", "The real menu layout in this theme: one accent (PLAY), one structural colour, one tone of it.")
	c.add_child(UI.brand_header("ZAPKO"))
	c.add_child(UI.tagline("Shed your cards. Stop the others."))
	var card := UI.panel()
	card[0].custom_minimum_size.x = UI.MENU_W
	card[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card[1].add_child(UI.heading("Opponents"))
	card[1].add_child(UI.choice_row(["1", "2", "3"], 1, func(_i): pass, true))
	card[1].add_child(UI.heading("Difficulty"))
	card[1].add_child(UI.choice_row(["Easy", "Normal", "Hard"], 1, func(_i): pass, true))
	c.add_child(card[0])
	var play := UI.button("PLAY", UI.Variant.PRIMARY, func(): pass, true)
	play.custom_minimum_size.x = UI.MENU_W
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(play)
	for spec in [["Leaderboard", UI.Variant.SECONDARY], ["History", UI.Variant.SECONDARY],
			["How to play", UI.Variant.SECONDARY], ["Settings", UI.Variant.TERTIARY]]:
		var b := UI.button(spec[0], spec[1], func(): pass)
		b.custom_minimum_size.x = UI.MENU_W
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add_child(b)


## Footer: theme, then the live style overrides (corners, gloss, shadow + bold text).
func _footer(box: VBoxContainer) -> void:
	box.add_child(_switch_row(_names(Themes.NAMES), Themes.NAMES.find(UI.theme_name), _set_theme, 36))
	box.add_child(_switch_row(CORNERS, _corner_index(), _set_corner, 36))
	box.add_child(_switch_row(GLOSS, int(UI.style.get("gloss", 0)), _set_gloss, 36))
	var look := HBoxContainer.new()
	look.add_theme_constant_override("separation", 20)
	var shadows := UI.choice_row(SHADOWS, int(UI.style.get("shadow", 0)), _set_shadow, true)
	shadows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_small(shadows, 36)
	look.add_child(shadows)
	_small(shadows, 32)
	var bold := UI.pill("Bold", bool(UI.style.get("bold", false)), Vector2(170, 80), 32)
	bold.toggled.connect(_set_bold)
	look.add_child(bold)
	look.custom_minimum_size.x = UI.MAX_CONTENT_W - 100
	var center := CenterContainer.new()
	center.add_child(look)
	box.add_child(center)


func _names(ids: Array) -> Array:
	var out := []
	for id in ids:
		out.append(str(id).capitalize())
	return out


func _switch_row(labels: Array, selected: int, on_pick: Callable, font: int) -> Control:
	var row := UI.choice_row(labels, selected, on_pick, true)
	row.custom_minimum_size.x = UI.MAX_CONTENT_W - 100
	_small(row, font)
	var center := CenterContainer.new()
	center.add_child(row)
	return center


func _small(row: HBoxContainer, font: int) -> void:
	for b in row.get_children():
		b.custom_minimum_size = Vector2(0, 80)
		b.add_theme_font_size_override("font_size", font)


func _section(c: VBoxContainer, name: String, note: String) -> void:
	c.add_child(UI.spacer(UI.SPACE_M))
	c.add_child(UI.title(name, UI.FONT_PILL + 12))
	c.add_child(UI.hint(note))


func _caption(text: String) -> Label:
	var l := UI.hint(text, 0.0)
	l.add_theme_font_size_override("font_size", UI.FONT_CAPTION)
	return l


func _contrast_table() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var fails := 0
	for row in Themes.contrast_pairs(UI.theme_name):
		var ratio := Themes.contrast(row[1], row[2])
		var ok := ratio >= float(row[3])
		fails += 0 if ok else 1
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 16)
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(row[2], 1.0)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		chip.add_theme_stylebox_override("panel", sb)
		chip.custom_minimum_size.x = 130
		var aa := Label.new()
		aa.text = "Aa"
		aa.add_theme_font_size_override("font_size", UI.FONT_BODY)
		aa.add_theme_color_override("font_color", Color(row[1], 1.0))
		aa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(aa)
		line.add_child(chip)
		var t := UI.body("%s   %.1f (min %.1f)  %s" % [row[0], ratio, row[3], "ok" if ok else "FAIL"], 0.0, UI.FONT_CAPTION)
		t.add_theme_color_override("font_color", UI.TEXT_INK if ok else Color("#C0392B"))
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(t)
		box.add_child(line)
	if fails > 0:
		print("contrast: theme %s has %d failing pairs" % [UI.theme_name, fails])
	return box


func _swatches() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", UI.SPACE_S)
	g.add_theme_constant_override("v_separation", UI.SPACE_S)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pal := Themes.palette(UI.theme_name)
	for key in pal:
		var col: Color = pal[key]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(310, 80)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(20)
		sb.set_border_width_all(3)
		sb.border_color = Color(0, 0, 0, 0.25)
		chip.add_theme_stylebox_override("panel", sb)
		v.add_child(chip)
		var alpha := "" if col.a >= 0.999 else "  a%d%%" % roundi(col.a * 100.0)
		var cap := _caption("%s\n#%s%s" % [key, col.to_html(false).to_upper(), alpha])
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.custom_minimum_size.x = 310
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(cap)
		g.add_child(v)
	return g


## A modal as the game shows it: the real table, dimmed by the scrim, with a popup on top.
func _table_popup() -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(UI.MAX_CONTENT_W, 780)
	stage.clip_contents = true
	var table := TableBg.new()
	table.style = 0
	stage.add_child(table)
	var scrim := ColorRect.new()
	scrim.color = UI.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(center)
	var pop := PanelContainer.new()
	pop.add_theme_stylebox_override("panel", UI.popup_style())
	center.add_child(pop)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UI.SPACE_M)
	pop.add_child(box)
	box.add_child(UI.title("New here?", 80))
	var text := UI.body("I'm Rex. Learn Zapko by playing a few quick hands with me.", 640)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	box.add_child(UI.button("Let's play", UI.Variant.PRIMARY, func(): pass))
	box.add_child(UI.button("Not now", UI.Variant.SECONDARY, func(): pass))
	return stage


func _open_scroll_demo() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)
	overlay.add_child(UI.background())
	var pg := UI.scroll_page("Scroll page", "Close", func(): UI.slide_out(overlay))
	overlay.add_child(pg["scroll"])
	overlay.add_child(pg["header"])
	overlay.add_child(pg["footer"])
	for i in 6:
		var p := UI.panel()
		p[1].add_child(UI.heading("Block %d" % (i + 1)))
		p[1].add_child(UI.body("Content runs full width and slides under the pinned header and footer while you scroll.", 820))
		(pg["content"] as VBoxContainer).add_child(p[0])
	UI.slide_in(overlay)


# ---------------------------------------------------------------- screenshots

func _shot(path: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


## `--dsshot=<file.png>`: for every theme <file>_<theme>_<n>.png (colours, buttons, choices/panels), plus the
## default theme's full page and scroll page, and each shadow of the default theme.
func capture(path: String) -> void:
	var base := path.get_basename()
	for t in Themes.NAMES.size():
		_set_theme(t)
		await get_tree().create_timer(0.8).timeout
		var scroll: ScrollContainer = _page["scroll"]
		var bar := scroll.get_v_scroll_bar()
		var end := int(bar.max_value - bar.page)
		var step := int(get_viewport_rect().size.y * 0.7)
		var y := 0
		var n := 0
		while true:
			scroll.scroll_vertical = y
			if Themes.NAMES[t] == Themes.DEFAULT or n in [0, 1, 2]:
				await _shot("%s_%s_%02d.png" % [base, Themes.NAMES[t], n])
			n += 1
			if y >= end:
				break
			y = mini(y + step, end)
		if Themes.NAMES[t] == Themes.DEFAULT:
			_open_scroll_demo()
			await get_tree().create_timer(0.8).timeout
			await _shot("%s_%s_scrollpage.png" % [base, Themes.NAMES[t]])
	_set_theme(Themes.NAMES.find(Themes.DEFAULT))
	for m in range(0, SHADOWS.size()):
		_set_shadow(m)
		await get_tree().create_timer(0.6).timeout
		(_page["scroll"] as ScrollContainer).scroll_vertical = int(get_viewport_rect().size.y * 0.7) * 3
		await _shot("%s_shadow_%s.png" % [base, SHADOWS[m].to_lower()])
	get_tree().quit()
