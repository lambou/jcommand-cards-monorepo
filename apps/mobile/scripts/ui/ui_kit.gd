extends RefCounted
## J-Command design system: tokens + widget factories. See DESIGN_SYSTEM.md.
## Every menu / overlay / HUD control must be built from here (no ad-hoc Color()/font sizes).
##   const UI := preload("res://scripts/ui/ui_kit.gd")

const Themes := preload("res://scripts/ui/ui_themes.gd")

# ---- Color tokens ---------------------------------------------------------
## These are set by apply_theme() from ui_themes.gd (static vars, so screens still just write UI.GOLD).
## Never cache one in a const or at class load: read it when you build the widget.
static var BG_TOP := Color.WHITE   # screen gradient (UI.background()), top
static var BG_MID := Color.WHITE   # screen gradient, middle
static var BG_BOTTOM := Color.WHITE   # screen gradient, bottom
static var SURFACE := Color.WHITE   # card fill (UI.panel)
static var SURFACE_SOLID := Color.WHITE   # popup body (UI.popup_style)
static var SURFACE_BORDER := Color.WHITE   # card border
static var FRAME := Color.WHITE   # popup frame
static var BAR := Color.WHITE   # pinned header / footer bars
static var BAR_BORDER := Color.WHITE   # edge of a bar facing the content
static var SCRIM := Color.WHITE   # dim behind modal popups
static var GOLD := Color.WHITE   # selection, 'on', rewards
static var PRIMARY := Color.WHITE   # primary button face
static var SECONDARY := Color.WHITE   # secondary button face, steppers
static var TERTIARY := Color.WHITE   # tertiary button face
static var DANGER := Color.WHITE   # danger / penalties / destructive
static var OFF := Color.WHITE   # unselected pill / toggle off
static var TEXT := Color.WHITE   # on buttons, bars and titles
static var TEXT_INK := Color.WHITE   # body text on cards and the background
static var TEXT_DIM := Color.WHITE   # hints, captions
static var TEXT_HEADING := Color.WHITE   # section headings
static var TEXT_OFF := Color.WHITE   # unselected pill text
static var TEXT_ON_GOLD := Color.WHITE   # text on a gold face
static var TEXT_ACCENT := Color.WHITE   # highlighted numbers on a card
static var TITLE := Color.WHITE   # screen titles / logo text
static var TAGLINE := Color.WHITE   # taglines
static var OUTLINE_DARK := Color.WHITE   # title and button-text outline
static var PATTERN := Color.WHITE   # menu backdrop: suit pattern
static var VEIL := Color.WHITE   # menu backdrop: veil over the scattered cards
static var CARD_TINT := Color.WHITE   # menu backdrop: tint on the scattered cards

static var theme_name := ""
## Shape / finish options of the active theme (see ui_themes.gd). Writable, e.g. by the design playground.
static var style := {}
static var _gloss_seed := 0   # counts glossy buttons so the "mixed" gloss varies from one to the next


static func _static_init() -> void:
	apply_theme(Themes.DEFAULT)


## Switch the whole design system to a theme from ui_themes.gd. Screens built afterwards use it; rebuild open screens.
static func apply_theme(name: String) -> void:
	if not Themes.NAMES.has(name):
		name = Themes.DEFAULT
	theme_name = name
	var p: Dictionary = Themes.palette(name)
	BG_TOP = p["BG_TOP"]
	BG_MID = p["BG_MID"]
	BG_BOTTOM = p["BG_BOTTOM"]
	SURFACE = p["SURFACE"]
	SURFACE_SOLID = p["SURFACE_SOLID"]
	SURFACE_BORDER = p["SURFACE_BORDER"]
	FRAME = p["FRAME"]
	BAR = p["BAR"]
	BAR_BORDER = p["BAR_BORDER"]
	SCRIM = p["SCRIM"]
	GOLD = p["GOLD"]
	PRIMARY = p["PRIMARY"]
	SECONDARY = p["SECONDARY"]
	TERTIARY = p["TERTIARY"]
	DANGER = p["DANGER"]
	OFF = p["OFF"]
	TEXT = p["TEXT"]
	TEXT_INK = p["TEXT_INK"]
	TEXT_DIM = p["TEXT_DIM"]
	TEXT_HEADING = p["TEXT_HEADING"]
	TEXT_OFF = p["TEXT_OFF"]
	TEXT_ON_GOLD = p["TEXT_ON_GOLD"]
	TEXT_ACCENT = p["TEXT_ACCENT"]
	TITLE = p["TITLE"]
	TAGLINE = p["TAGLINE"]
	OUTLINE_DARK = p["OUTLINE_DARK"]
	PATTERN = p["PATTERN"]
	VEIL = p["VEIL"]
	CARD_TINT = p["CARD_TINT"]
	style = Themes.style(name).duplicate()
	_gloss_seed = 0


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
const MENU_W := 800         # start menu: options panel and every button share this width
const LOGO := "res://assets/branding/logo.png"
const LOGO_TITLE := 150     # logo edge next to the FONT_DISPLAY title

enum Variant { PRIMARY, SECONDARY, TERTIARY, DANGER }


# ---- Style primitives ------------------------------------------------------
static func face_color(v: Variant) -> Color:
	match v:
		Variant.PRIMARY: return PRIMARY
		Variant.SECONDARY: return SECONDARY
		Variant.TERTIARY: return TERTIARY
		_: return DANGER


## Chunky "candy" surface: flat face + darker lip underneath, plus the active theme's shadow
## (strong blurry drop shadow, or a thin outline with a tight shadow, or none).
static func candy(face: Color, radius: int, lip: int = 12, pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.border_width_bottom = lip
	sb.border_width_top = 4
	sb.border_color = face.darkened(0.35)
	match int(style.get("shadow", 0)):
		1:
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.shadow_color = Color(OUTLINE_DARK, 0.35)
			sb.shadow_size = 0 if pressed else 2
			sb.shadow_offset = Vector2(0, 3)
		2:
			sb.shadow_size = 0
		_:
			sb.shadow_color = Color(0, 0, 0, 0.35)
			sb.shadow_size = 4 if pressed else 14
			sb.shadow_offset = Vector2(0, 8)
	return sb


## Corner radius of a button / pill of height h in the active theme (-1 in the style = fully rounded).
static func btn_radius(h: float) -> int:
	var px := int(style.get("btn_radius", -1))
	return int(h / 3) if px < 0 else mini(px, int(h / 2))


static func pill_radius(h: float) -> int:
	var px := int(style.get("pill_radius", -1))
	return int(h / 2) if px < 0 else mini(px, int(h / 2))


static func _apply_states(b: Button, face: Color, radius: int, lip: int) -> void:
	b.add_theme_stylebox_override("normal", candy(face, radius, lip))
	b.add_theme_stylebox_override("hover", candy(face.lightened(0.08), radius, lip))
	var down := candy(face.darkened(0.08), radius, 4, true)
	down.content_margin_top = 8
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Final touches on a candy button, after its styles and font settings are in place: the bold label outline and
## the gloss. A button draws its own text before its children, so with gloss on the label is handed to an overlay
## Label added after the gloss (same font size, outline and colours), keeping the text on top of the shine.
static func _finish(b: Button, face: Color, radius: int, lip: int, outline: bool = true) -> void:
	if outline and bool(style.get("bold", false)):
		b.add_theme_constant_override("outline_size", 18)
		b.add_theme_color_override("font_outline_color", face.darkened(0.62))
	var mode := int(style.get("gloss", 0))
	if mode == 0:
		return
	if mode == 5:
		mode = 1 + (_gloss_seed * 7 + 2) % 4   # strip / swoosh / dot / slant, scattered
	_gloss_seed += 1
	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_gloss.bind(art, mode, radius, lip))
	b.add_child(art)
	var lbl := Label.new()
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_constant_override("outline_size", b.get_theme_constant("outline_size"))
	lbl.add_theme_color_override("font_outline_color", b.get_theme_color("font_outline_color"))
	var normal := b.get_theme_color("font_color")
	var pressed := b.get_theme_color("font_pressed_color")
	var update := func():
		lbl.text = b.text
		lbl.add_theme_font_size_override("font_size", b.get_theme_font_size("font_size"))
		lbl.add_theme_color_override("font_color", pressed if b.button_pressed else normal)
		lbl.offset_top = 4.0 if b.button_pressed else 0.0
	b.draw.connect(update)
	update.call()
	b.add_child(lbl)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color(0, 0, 0, 0))
	b.add_theme_constant_override("outline_size", 0)


## Gloss shapes: 1 strip across the top half, 2 swoosh (thick at the left, tapering right), 3 shorter strip plus a
## small shine dot, 4 two slanted shine bands.
static func _draw_gloss(art: Control, mode: int, radius: int, lip: int) -> void:
	var white := Color(1, 1, 1, 0.26)
	var x0 := 8.0
	var y0 := 8.0
	var w := art.size.x - 16.0
	var face := art.size.y - lip - 16.0       # height of the flat face
	var r := float(radius)
	match mode:
		1:
			var sb := StyleBoxFlat.new()
			sb.bg_color = white
			sb.corner_radius_top_left = maxi(radius - 6, 4)
			sb.corner_radius_top_right = maxi(radius - 6, 4)
			sb.corner_radius_bottom_left = maxi(radius / 3, 4)
			sb.corner_radius_bottom_right = maxi(radius / 3, 4)
			sb.anti_aliasing = true
			art.draw_style_box(sb, Rect2(x0, y0, w, face * 0.46))
		2:
			var pts := PackedVector2Array()
			var xs := x0 + r * 0.5
			var xe := x0 + w - r * 0.4
			for i in 21:
				var t := i / 20.0
				pts.append(Vector2(lerpf(xs, xe, t), y0 + (1.0 - sin(t * PI * 0.5)) * face * 0.05))
			for i in 21:
				var t := 1.0 - i / 20.0
				pts.append(Vector2(lerpf(xs, xe, t), y0 + face * 0.08 + face * 0.42 * pow(1.0 - t, 0.55) * (1.0 - pow(t, 1.6))))
			art.draw_colored_polygon(pts, white)
		3:
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = white
			sb2.set_corner_radius_all(maxi(int(face * 0.12), 4))
			sb2.anti_aliasing = true
			art.draw_style_box(sb2, Rect2(x0 + r * 1.5, y0 + 2.0, w - r * 2.4, face * 0.26))
			art.draw_circle(Vector2(x0 + r * 0.75, y0 + face * 0.2), maxf(face * 0.07, 4.0), white)
		4:
			for band in [[0.52, 0.12], [0.70, 0.05]]:
				var xa: float = x0 + w * band[0]
				var bw: float = w * band[1]
				var sl := face * 0.45
				art.draw_colored_polygon(PackedVector2Array([Vector2(xa + sl, y0 + 2.0), Vector2(xa + sl + bw, y0 + 2.0),
					Vector2(xa + bw, y0 + face - 2.0), Vector2(xa, y0 + face - 2.0)]), white)


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


## A full-screen page arriving: it slides in from the right edge (a quick fade with Reduce motion).
## Call right after adding the page to the tree.
static func slide_in(page: Control) -> void:
	if preload("res://scripts/game/settings.gd").reduce_motion:
		page.modulate.a = 0.0
		page.create_tween().tween_property(page, "modulate:a", 1.0, 0.15)
		return
	page.position.x = page.get_viewport_rect().size.x
	page.create_tween().tween_property(page, "position:x", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The page leaving: it slides back out to the right, then frees itself. Safe to call twice.
static func slide_out(page: Control) -> void:
	if page.has_meta("closing"):
		return
	page.set_meta("closing", true)
	var t := page.create_tween()
	if preload("res://scripts/game/settings.gd").reduce_motion:
		t.tween_property(page, "modulate:a", 0.0, 0.12)
	else:
		t.tween_property(page, "position:x", page.get_viewport_rect().size.x, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(page.queue_free)


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
	sb.bg_color = BAR
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4 if is_header else -4)
	sb.border_color = BAR_BORDER
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
	sb.border_width_bottom = int(style.get("panel_lip", 4))   # a chunky lip, like the candy buttons
	sb.border_color = SURFACE_BORDER
	if bool(style.get("panel_shadow", false)) and int(style.get("shadow", 0)) == 0:
		sb.shadow_color = Color(OUTLINE_DARK, 0.18)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 6)
	sb.set_content_margin_all(PANEL_PAD)
	p.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", separation)
	p.add_child(inner)
	return [p, inner]


## Solid framed popup for modals over the table.
static func popup_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE_SOLID
	sb.set_corner_radius_all(PANEL_RADIUS)
	sb.set_border_width_all(int(style.get("popup_frame", 6)))
	sb.border_width_bottom = int(style.get("popup_frame_bottom", 6))
	sb.border_color = FRAME
	sb.shadow_color = Color(0, 0, 0, 0.5)
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
	l.add_theme_color_override("font_color", TITLE)
	l.add_theme_constant_override("outline_size", int(font_size * 0.22))
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_color_override("font_shadow_color", Color(OUTLINE_DARK, 0.55))
	l.add_theme_constant_override("shadow_offset_y", int(font_size * 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## The game's name with the app logo on its left, centred as one unit (logo hidden if the file is missing).
static func brand_header(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	if ResourceLoader.exists(LOGO):
		var logo := TextureRect.new()
		logo.texture = load(LOGO)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(LOGO_TITLE, LOGO_TITLE)
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(logo)
	row.add_child(title(text, FONT_DISPLAY))
	return row


static func tagline(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_HEADING)
	l.add_theme_color_override("font_color", TAGLINE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Section heading inside a panel.
static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_HEADING)
	l.add_theme_color_override("font_color", TEXT_HEADING)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Paragraph text. wrap_width > 0 enables word wrap at that minimum width.
static func body(text: String, wrap_width: float = 0.0, font_size: int = FONT_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", TEXT_INK)
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
	var r := btn_radius(h)
	_apply_states(b, face, r, 12)
	_finish(b, face, r, 12)
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
	b.add_theme_color_override("font_color", TEXT_OFF)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT_ON_GOLD)
	b.add_theme_color_override("font_hover_pressed_color", TEXT_ON_GOLD)
	var r := pill_radius(size.y)
	b.add_theme_stylebox_override("normal", candy(OFF, r, 8))
	b.add_theme_stylebox_override("hover", candy(OFF.lightened(0.1), r, 8))
	b.add_theme_stylebox_override("pressed", candy(GOLD, r, 8))
	b.add_theme_stylebox_override("hover_pressed", candy(GOLD, r, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_finish(b, OFF, r, 8, false)
	return b


## Row of mutually exclusive pills. on_pick(index) fires on selection. stretch=true shares the row's full width.
static func choice_row(labels: Array, selected: int, on_pick: Callable, stretch: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := pill(labels[i], i == selected)
		if stretch:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	for state in ["normal", "hover", "pressed"]:   # softer shadow than full-size buttons (strong-shadow themes only)
		if int(style.get("shadow", 0)) != 0:
			break
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
	var r := pill_radius(PILL_H)
	_apply_states(b, SECONDARY, r, 8)
	_finish(b, SECONDARY, r, 8, false)
	b.pressed.connect(on_press)
	return b
