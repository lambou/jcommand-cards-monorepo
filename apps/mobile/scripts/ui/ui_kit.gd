extends RefCounted
## J-Command design system: tokens + widget factories. See DESIGN_SYSTEM.md.
## Every menu / overlay / HUD control must be built from here (no ad-hoc Color()/font sizes).
##   const UI := preload("res://scripts/ui/ui_kit.gd")

# ---- Color tokens ---------------------------------------------------------
const BG_TOP := Color(0.03, 0.2, 0.13)
const BG_MID := Color(0.07, 0.33, 0.21)      # the felt green; also the table colour
const BG_BOTTOM := Color(0.12, 0.45, 0.28)
const SURFACE := Color(0.02, 0.15, 0.09, 0.55)   # translucent panel fill
const SURFACE_SOLID := Color(0.05, 0.22, 0.15)   # popups on top of the table
const SURFACE_BORDER := Color(0.55, 1.0, 0.7, 0.35)
const SCRIM := Color(0, 0, 0, 0.65)               # dim behind modal popups

const GOLD := Color(1.0, 0.85, 0.3)          # titles, headings, selection, accents
const GOLD_LIGHT := Color(1.0, 0.87, 0.35)
const AMBER := Color(1.0, 0.72, 0.15)        # primary button face
const EMERALD := Color(0.15, 0.62, 0.4)      # secondary button face
const TEAL := Color(0.1, 0.5, 0.55)          # tertiary button face
const RED := Color(1.0, 0.32, 0.27)          # danger / penalties / destructive
const OFF := Color(0.1, 0.3, 0.2)            # unselected pill / toggle off

const TEXT := Color.WHITE
const TEXT_MINT := Color(0.8, 0.96, 0.85)    # taglines, unselected pill text
const TEXT_DIM := Color(1, 1, 1, 0.7)        # hints, captions
const TEXT_ON_GOLD := Color(0.25, 0.14, 0.02)  # text on a gold/amber face
const OUTLINE_DARK := Color(0.04, 0.2, 0.12)   # title outline

# ---- Type scale (viewport is 1080x1920; Lilita One is the project font) ----
const FONT_DISPLAY := 128   # game logo only
const FONT_H1 := 96         # screen titles ("Settings")
const FONT_BUTTON_L := 80   # the one primary call to action per screen
const FONT_PILL := 52       # pill / toggle / stepper labels
const FONT_BUTTON := 46     # normal buttons
const FONT_HEADING := 40    # section headings inside a panel
const FONT_BODY := 38       # paragraphs
const FONT_HINT := 34       # helper text under controls
const FONT_CAPTION := 30    # table captions

# ---- Spacing / geometry ----------------------------------------------------
const SPACE_S := 16
const SPACE_M := 30         # default VBox separation between blocks
const SPACE_L := 60
const PANEL_PAD := 36
const PANEL_RADIUS := 48
const BTN_W := 700          # standard button width (fits 1080 with margins)
const BTN_H_L := 170
const BTN_H := 120
const PILL_W := 190
const PILL_H := 110
const ICON_BTN := 110       # icon-only HUD button (touch target)
const MARGIN_SCREEN := 50  # edge margin for full-screen content
const MAX_CONTENT_W := 980  # widest a page's content gets (1080 minus margins); wider screens just get more side margin

enum Variant { PRIMARY, SECONDARY, TERTIARY, DANGER }


# ---- Style primitives ------------------------------------------------------
static func face_color(v: Variant) -> Color:
	match v:
		Variant.PRIMARY: return AMBER
		Variant.SECONDARY: return EMERALD
		Variant.TERTIARY: return TEAL
		_: return RED


## Chunky "candy" surface: flat face + darker lip underneath + soft shadow.
static func candy(face: Color, radius: int, lip: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.border_width_bottom = lip
	sb.border_width_top = 4
	sb.border_color = face.darkened(0.35)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 8)
	return sb


static func _apply_states(b: Button, face: Color, radius: int, lip: int) -> void:
	b.add_theme_stylebox_override("normal", candy(face, radius, lip))
	b.add_theme_stylebox_override("hover", candy(face.lightened(0.08), radius, lip))
	var down := candy(face.darkened(0.08), radius, 4)
	down.content_margin_top = 8
	down.shadow_size = 4
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# ---- Containers -------------------------------------------------------------
static func background() -> TextureRect:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([BG_TOP, BG_MID, BG_BOTTOM])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP   # a screen blocks input behind it
	return bg


## Vertical scroll area with an invisible scroll bar (drag or wheel to scroll).
static func scroll_area() -> ScrollContainer:
	var s := preload("res://scripts/ui/drag_scroll.gd").new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The bar is invisible: touch-dragging is the interaction, a bar is just noise.
	var bar := s.get_v_scroll_bar()
	bar.modulate.a = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.x = 0
	for style in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	return s


## Full-screen scrolling page: a pinned header (title) and footer (Close) with the
## content running full width underneath them. Header and footer are solid bars with
## a border on the edge facing the content and a soft shadow, so content slides under
## them with depth. Returns {scroll, content, header, footer}; add blocks to content.
static func scroll_page(title_text: String, close_text: String, on_close: Callable) -> Dictionary:
	var scroll := scroll_area()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var content := VBoxContainer.new()
	# Fixed-width column centred in the page: wider screens just get more empty side space. (Side margins
	# can't do this: their size feeds the minimum size, so the page could no longer shrink when resized.)
	content.custom_minimum_size.x = MAX_CONTENT_W
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", SPACE_M)
	pad.add_child(content)

	var header := _bar(true)
	var t := title(title_text)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.get_child(0).add_child(t)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.grow_vertical = Control.GROW_DIRECTION_END

	var footer := _bar(false)
	var footer_box: VBoxContainer = footer.get_child(0)
	footer_box.add_theme_constant_override("separation", SPACE_S)
	if close_text != "":   # "" = caller fills footer_box with its own buttons
		var center := CenterContainer.new()
		center.add_child(button(close_text, Variant.SECONDARY, on_close))
		footer_box.add_child(center)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN

	scroll.blockers = [header, footer]

	# Keep the first/last block clear of the bars at rest; they only overlap while scrolling.
	var sync := func():
		pad.add_theme_constant_override("margin_top", int(header.size.y) + SPACE_M)
		pad.add_theme_constant_override("margin_bottom", int(footer.size.y) + SPACE_M)
	header.resized.connect(sync)
	footer.resized.connect(sync)
	return {"scroll": scroll, "content": content, "header": header, "footer": footer, "footer_box": footer_box}


static func _bar(is_header: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE_SOLID
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4 if is_header else -4)
	sb.border_color = SURFACE_BORDER
	sb.set_content_margin_all(0)
	if is_header:
		sb.border_width_bottom = 4
		sb.content_margin_top = MARGIN_SCREEN
		sb.content_margin_bottom = SPACE_M
	else:
		sb.border_width_top = 4
		sb.content_margin_top = SPACE_M
		sb.content_margin_bottom = MARGIN_SCREEN
	p.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	p.add_child(inner)
	return p


## Centered vertical column; add your blocks to it.
static func column(separation: int = SPACE_M) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", separation)
	return box


## Rounded translucent card. Returns [panel, inner_vbox]; add content to inner_vbox.
static func panel(separation: int = SPACE_S) -> Array:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE
	sb.set_corner_radius_all(PANEL_RADIUS)
	sb.set_border_width_all(4)
	sb.border_color = SURFACE_BORDER
	sb.set_content_margin_all(PANEL_PAD)
	p.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", separation)
	p.add_child(inner)
	return [p, inner]


## Solid bordered popup (J picker style) for modals over the table.
static func popup_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE_SOLID
	sb.set_corner_radius_all(PANEL_RADIUS)
	sb.set_border_width_all(6)
	sb.border_color = Color(0.93, 0.76, 0.28)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 30
	sb.set_content_margin_all(PANEL_PAD)
	return sb


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# ---- Text ---------------------------------------------------------------------
## Outlined display text. size: FONT_DISPLAY (logo) or FONT_H1 (screen title).
static func title(text: String, font_size: int = FONT_H1) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", GOLD_LIGHT)
	l.add_theme_constant_override("outline_size", int(font_size * 0.22))
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.1, 0.05, 0.6))
	l.add_theme_constant_override("shadow_offset_y", int(font_size * 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func tagline(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_HEADING)
	l.add_theme_color_override("font_color", TEXT_MINT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Gold section heading inside a panel.
static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_HEADING)
	l.add_theme_color_override("font_color", GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Paragraph text. wrap_width > 0 enables word wrap at that minimum width.
static func body(text: String, wrap_width: float = 0.0, font_size: int = FONT_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", TEXT)
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Dim helper text under a control.
static func hint(text: String, wrap_width: float = 820.0) -> Label:
	var l := body(text, wrap_width, FONT_HINT)
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ---- Controls -----------------------------------------------------------------
## Standard button. large=true is the single primary CTA of a screen (PLAY).
static func button(text: String, variant: Variant, on_press: Callable, large: bool = false) -> Button:
	var face := face_color(variant)
	var h := BTN_H_L if large else BTN_H
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(BTN_W, h)
	b.add_theme_font_size_override("font_size", FONT_BUTTON_L if large else FONT_BUTTON)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, TEXT)
	b.add_theme_constant_override("outline_size", 10)
	b.add_theme_color_override("font_outline_color", face.darkened(0.45))
	_apply_states(b, face, h / 3, 12)
	b.pressed.connect(on_press)
	return b


## Gold-when-selected toggle pill. Used for choices and on/off switches.
static func pill(text: String, selected: bool, size: Vector2 = Vector2(PILL_W, PILL_H), font_size: int = FONT_PILL) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = selected
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = size
	b.add_theme_color_override("font_color", TEXT_MINT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT_ON_GOLD)
	b.add_theme_color_override("font_hover_pressed_color", TEXT_ON_GOLD)
	var r := int(size.y / 2)
	b.add_theme_stylebox_override("normal", candy(OFF, r, 8))
	b.add_theme_stylebox_override("hover", candy(OFF.lightened(0.1), r, 8))
	b.add_theme_stylebox_override("pressed", candy(GOLD, r, 8))
	b.add_theme_stylebox_override("hover_pressed", candy(GOLD, r, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Row of mutually exclusive pills. on_pick(index) fires on selection.
static func choice_row(labels: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := pill(labels[i], i == selected)
		b.button_group = group
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
	return row


## Full-width on/off switch (gold when on). Caller updates .text in the handler.
static func toggle(text: String, on: bool, handler: Callable) -> Button:
	var b := pill(text, on, Vector2(BTN_W, BTN_H))
	b.toggled.connect(handler)
	return b


## Round icon-only button (HUD). kind: "home" or "gear". Touch-sized (ICON_BTN).
static func icon_button(kind: String, on_press: Callable, variant: Variant = Variant.SECONDARY, face_override := Color(0, 0, 0, 0)) -> Button:
	var face := face_color(variant) if face_override.a == 0.0 else face_override
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ICON_BTN, ICON_BTN)
	b.size = Vector2(ICON_BTN, ICON_BTN)
	_apply_states(b, face, ICON_BTN / 2, 8)
	for state in ["normal", "hover", "pressed"]:   # softer shadow than full-size buttons
		var sb: StyleBoxFlat = b.get_theme_stylebox(state)
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = 5 if state != "pressed" else 2
		sb.shadow_offset = Vector2(0, 3)
	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_icon.bind(art, kind, face.darkened(0.2)))
	b.add_child(art)
	b.pressed.connect(on_press)
	return b


static func _draw_icon(c: Control, kind: String, hole: Color) -> void:
	var ctr := c.size / 2.0 - Vector2(0, 3)
	var u := ICON_BTN / 100.0
	if kind == "home":
		var roof := PackedVector2Array([ctr + Vector2(0, -34) * u, ctr + Vector2(-38, -2) * u, ctr + Vector2(38, -2) * u])
		c.draw_colored_polygon(roof, TEXT)
		c.draw_rect(Rect2(ctr + Vector2(-26, -4) * u, Vector2(52, 38) * u), TEXT)
		c.draw_rect(Rect2(ctr + Vector2(-8, 12) * u, Vector2(16, 22) * u), hole)
	else:
		for i in 8:
			var a := TAU * i / 8.0
			var d := Vector2.from_angle(a)
			c.draw_line(ctr + d * 22.0 * u, ctr + d * 34.0 * u, TEXT, 13.0 * u)
		c.draw_circle(ctr, 27.0 * u, TEXT)
		c.draw_circle(ctr, 12.0 * u, hole)


## Small round-ish +/- button.
static func stepper(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(PILL_H + 10, PILL_H)
	b.add_theme_font_size_override("font_size", 64)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	_apply_states(b, EMERALD, PILL_H / 2, 8)
	b.pressed.connect(on_press)
	return b
