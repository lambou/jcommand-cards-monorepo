extends RefCounted
## Registry of UI themes for the design system (see DESIGN_SYSTEM.md). A theme is a palette (every colour token
## ui_kit.gd exposes) plus a style (the shape / finish options of the widgets). ui_kit.gd's `apply_theme(name)`
## copies one of these into the kit's tokens, so screens never know which theme is active and switching is one
## call:   UI.apply_theme("cloud")        (debug: godot --path apps/mobile -- --uitheme=cloud)
## To add a theme: "felt" is hand-written; every other theme is derived from two hues (see derive()), so adding
## one is a line in DERIVED plus its name in NAMES.

const DEFAULT := "lagoon"
const NAMES := ["felt", "lagoon", "sky", "dusk", "ember"]

## Derived themes: [base hue, accent hue, saturation scale, lift], all in 0..1. `lift` raises the lightness of the
## gradient (0 = deep like Felt; a brighter, more open world as it grows, text is still fitted to stay legible).
const DERIVED := {
	"lagoon": [0.50, 0.06, 1.0],        # deep teal, with aqua and sea-green neighbours; coral-orange accent
	"sky": [0.58, 0.10, 1.0, 0.10],     # open blue, with cyan and violet-blue neighbours; sun-yellow accent
	"dusk": [0.71, 0.13, 0.95],         # deep indigo, with violet and blue neighbours; golden accent
	"ember": [0.93, 0.12, 0.95],        # deep wine, with magenta and plum neighbours; golden accent
}

## Style options. btn_radius / pill_radius: corner radius in px (-1 = fully rounded: height/3 for buttons,
## height/2 for pills). gloss: 0 none, 1 strip, 2 swoosh, 3 dot, 4 slant, 5 mixed (a different one per button).
## shadow: 0 strong blurry drop shadow, 1 subtle (thin outline + tight shadow), 2 none. bold: thick dark label
## outline. panel_lip: thickness of a panel's bottom edge. popup_frame(_bottom): popup border widths.
## panel_shadow: soft shadow under panels (only with the strong shadow).
const STYLE_CLASSIC := {
	"btn_radius": -1, "pill_radius": -1, "gloss": 0, "shadow": 0, "bold": false,
	"panel_lip": 4, "popup_frame": 6, "popup_frame_bottom": 6, "panel_shadow": false,
}
const STYLE_MODERN := {
	"btn_radius": 16, "pill_radius": 16, "gloss": 4, "shadow": 1, "bold": true,
	"panel_lip": 10, "popup_frame": 10, "popup_frame_bottom": 16, "panel_shadow": true,
}

## The original green felt look: the reference for what a theme should feel like (a coloured, not white, world).
const FELT := {
	"BG_TOP": Color(0.03, 0.2, 0.13), "BG_MID": Color(0.07, 0.33, 0.21), "BG_BOTTOM": Color(0.12, 0.45, 0.28),
	"SURFACE": Color(0.02, 0.15, 0.09, 0.55), "SURFACE_SOLID": Color(0.05, 0.22, 0.15), "SURFACE_BORDER": Color(0.55, 1.0, 0.7, 0.35),
	"FRAME": Color(0.93, 0.76, 0.28), "BAR": Color(0.05, 0.22, 0.15), "BAR_BORDER": Color(0.55, 1.0, 0.7, 0.35),
	"SCRIM": Color(0, 0, 0, 0.65),
	"GOLD": Color(1.0, 0.85, 0.3), "PRIMARY": Color(1.0, 0.72, 0.15), "SECONDARY": Color(0.15, 0.62, 0.4),
	"TERTIARY": Color(0.1, 0.5, 0.55), "DANGER": Color(1.0, 0.32, 0.27), "OFF": Color(0.1, 0.3, 0.2),
	"TEXT": Color.WHITE, "TEXT_INK": Color.WHITE, "TEXT_DIM": Color(1, 1, 1, 0.7), "TEXT_HEADING": Color(1.0, 0.85, 0.3),
	"TEXT_OFF": Color(0.8, 0.96, 0.85), "TEXT_ON_GOLD": Color(0.25, 0.14, 0.02), "TEXT_ACCENT": Color(1.0, 0.85, 0.3),
	"TITLE": Color(1.0, 0.87, 0.35), "TAGLINE": Color(0.8, 0.96, 0.85), "OUTLINE_DARK": Color(0.04, 0.2, 0.12),
}


## The palette of a theme, plus the menu backdrop's colours (suit pattern, veil over the scattered cards, card tint).
static func palette(name: String) -> Dictionary:
	var p: Dictionary
	if DERIVED.has(name):
		var d: Array = DERIVED[name]
		p = derive(d[0], d[1], d[2], d[3] if d.size() > 3 else 0.0)
	else:
		p = FELT.duplicate()
	p["PATTERN"] = Color(0.6, 1.0, 0.75, 0.05)
	p["VEIL"] = Color(Color(p["BG_TOP"]), 0.7)
	p["CARD_TINT"] = Color(0.8, 0.86, 0.82, 0.92)
	return p


static func style(name: String) -> Dictionary:
	return STYLE_CLASSIC if name == "felt" else STYLE_MODERN


# ---------------------------------------------------------------- derived palettes
## A whole palette from two hues, so the colours are related by construction instead of picked one by one, and
## shaped like Felt's relationships (not its green): a coloured world, vivid neighbours, one warm accent.
##   base   (hb): the world. Gradient, cards, borders, bars and text tints are deep tints of this hue.
##   neighbour  : the secondary button (and the tertiary slot, which just aliases it) is a vivid mid-tone of a hue
##                right next to the base on the colour wheel (Felt: green world, emerald buttons), so it belongs to
##                the world without blending in.
##   accent (ha): the one warm colour. The primary button, the selection, titles, headings, highlighted numbers and
##                the popup frame. Every theme picks its own, so each has its own character.
##   danger: a muted red, used only for destructive things.
## `sat` scales every saturation (1 = as designed, lower = greyer). Every foreground colour is then fitted:
## brightened or darkened until it reaches its contrast minimum against the surface it sits on (WCAG ratios: 4.5
## for text, 3 for large text such as button labels), so any theme built this way is legible by construction.
static func derive(hb: float, ha: float, sat: float = 1.0, lift: float = 0.0) -> Dictionary:
	var p := {}
	p["BG_TOP"] = _hsv(hb, 0.80, 0.20 + lift, sat)
	p["BG_MID"] = _hsv(hb, 0.72, 0.30 + lift, sat)
	p["BG_BOTTOM"] = _hsv(hb, 0.68, 0.42 + lift, sat)
	p["SURFACE"] = _hsv(hb, 0.80, 0.12, sat, 0.62)
	p["SURFACE_SOLID"] = _hsv(hb, 0.75, 0.20, sat)
	p["SURFACE_BORDER"] = _hsv(hb, 0.40, 0.70, sat, 0.45)
	p["GOLD"] = _hsv(ha + 0.005, 0.62, 1.0, sat)
	p["FRAME"] = p["GOLD"]
	p["BAR"] = p["SURFACE_SOLID"]
	p["BAR_BORDER"] = p["SURFACE_BORDER"]
	p["SCRIM"] = Color(0, 0, 0, 0.65)
	var white := Color.WHITE
	var light_bg: Color = p["BG_BOTTOM"]
	p["TEXT"] = white
	p["TEXT_INK"] = fit_light(_hsv(hb, 0.08, 0.98, sat), light_bg, 4.5)
	p["TEXT_DIM"] = Color(p["TEXT_INK"], 0.75)
	p["TEXT_HEADING"] = fit_light(_hsv(ha, 0.55, 1.0, sat), light_bg, 4.5)
	p["TITLE"] = white   # the name and screen titles are white (outlined); only Felt keeps gold titles
	p["TAGLINE"] = fit_light(_hsv(hb, 0.15, 0.92, sat), light_bg, 4.5)
	p["TEXT_OFF"] = p["TAGLINE"]
	p["OUTLINE_DARK"] = _hsv(hb, 0.85, 0.10, sat)
	p["SECONDARY"] = fit(_hsv(hb + 0.02, 0.76, 0.66, sat), white, 3.0)
	p["TERTIARY"] = p["SECONDARY"]   # only two button colours: primary + secondary. A tertiary request just gets the secondary
	p["OFF"] = _hsv(hb, 0.55, 0.30, sat)
	p["PRIMARY"] = fit(_hsv(ha, 0.85, 0.97, sat), white, 2.2)   # bright; its label is bold and outlined
	p["DANGER"] = fit(_hsv(0.99, 0.65, 0.80, sat), white, 3.0)
	p["TEXT_ON_GOLD"] = fit(_hsv(ha, 0.90, 0.30, sat), p["GOLD"], 4.5)
	p["TEXT_ACCENT"] = fit_light(p["GOLD"], p["SURFACE_SOLID"], 4.5)
	return p


static func _hsv(h: float, s: float, v: float, sat: float, a: float = 1.0) -> Color:
	return Color.from_hsv(fposmod(h, 1.0), clampf(s * sat, 0.0, 1.0), v, a)


## WCAG relative luminance of a colour.
static func luminance(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	for i in 3:
		var v: float = ch[i]
		ch[i] = v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


## WCAG contrast ratio between two colours (1 = identical, 21 = black on white).
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Darken `c` (same hue and saturation) until it reaches `min_ratio` contrast against `against`.
static func fit(c: Color, against: Color, min_ratio: float) -> Color:
	var out := c
	var guard := 0
	while contrast(out, against) < min_ratio and out.v > 0.04 and guard < 80:
		out = Color.from_hsv(out.h, out.s, out.v - 0.01, out.a)
		guard += 1
	return out


## Brighten `c` (same hue and saturation) until it reaches `min_ratio` contrast against `against`.
static func fit_light(c: Color, against: Color, min_ratio: float) -> Color:
	var out := c
	var guard := 0
	while contrast(out, against) < min_ratio and out.v < 0.999 and guard < 100:
		out = Color.from_hsv(out.h, out.s, minf(out.v + 0.01, 1.0), out.a)
		guard += 1
	return out


## The foreground / background pairs a theme must keep legible: [label, fg, bg, minimum ratio].
static func contrast_pairs(name: String) -> Array:
	var p := palette(name)
	var out := []
	for bg in ["BG_TOP", "BG_MID", "BG_BOTTOM"]:
		out.append(["TEXT_INK on " + bg, p["TEXT_INK"], p[bg], 4.5])
		out.append(["TAGLINE on " + bg, p["TAGLINE"], p[bg], 3.0])
	for bg in ["SURFACE", "SURFACE_SOLID"]:
		out.append(["TEXT_INK on " + bg, p["TEXT_INK"], p[bg], 4.5])
		out.append(["TEXT_DIM on " + bg, p["TEXT_DIM"], p[bg], 4.5])
		out.append(["TEXT_HEADING on " + bg, p["TEXT_HEADING"], p[bg], 4.5])
		out.append(["TEXT_ACCENT on " + bg, p["TEXT_ACCENT"], p[bg], 4.5])
	for face in ["SECONDARY", "TERTIARY", "DANGER", "OFF", "BAR"]:
		out.append(["TEXT on " + face, p["TEXT"], p[face], 3.0])
	out.append(["TEXT on PRIMARY (outlined)", p["TEXT"], p["PRIMARY"], 2.2])
	out.append(["TEXT_ON_GOLD on GOLD", p["TEXT_ON_GOLD"], p["GOLD"], 4.5])
	return out
