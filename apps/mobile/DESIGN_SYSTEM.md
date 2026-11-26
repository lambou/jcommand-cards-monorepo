# Zapko design system

All menus, overlays and HUD controls are built from `scripts/ui/ui_kit.gd`:

    const UI := preload("res://scripts/ui/ui_kit.gd")

**Rule: no ad-hoc `Color(...)`, font sizes, or `StyleBoxFlat` in screen code.** If you need something the kit lacks, add a token/factory to the kit first, then use it. Reference screens: `menu.gd`, `settings_panel.gd`.

## Themes (the design system is switchable)
The look is not hard-coded in the kit. `scripts/ui/ui_themes.gd` is a registry of named themes; each is a **palette** (every colour token below) plus a **style** (shape and finish of the widgets). `UI.apply_theme(name)` copies one into the kit's tokens, and every screen built afterwards uses it. Screens never name a colour or know which theme is active, so a whole new look is one entry in `ui_themes.gd`, not a code change.

| Theme | What it is |
|---|---|
| `lagoon` (default) | deep teal world, coral-orange accent |
| `sky` | open blue world (a lifted gradient, still a colour, never white), sun-yellow accent |
| `dusk` | deep indigo world, golden accent |
| `ember` | deep wine world, golden accent |
| `felt` | the original hand-written green felt look; the reference for how a theme should feel |

Every theme except `felt` is **derived** (`ui_themes.gd`, `derive()`) from the relationships that make Felt work, not from its green: a coloured world (deep tints of the base hue, never white), a vivid **neighbour** of that hue for the secondary button (Felt: green world, emerald buttons; the tertiary slot just aliases it, so screens only ever show primary + secondary), and one warm **accent** (primary button, selection, titles, headings, popup frame) that each theme picks for itself. Danger is a muted red used only for destructive things. Saturation has one scale knob, and every foreground colour is fitted (brightened or darkened) to meet WCAG contrast against its surface, so a derived theme is legible by construction (PRIMARY is bright and its bold outlined label is held to 2.2, not 3). Saturation has one scale knob, and every foreground colour is fitted (brightened or darkened) to meet WCAG contrast against its surface, so a derived theme is legible by construction. The playground's "Contrast check" lists every pair.

Switch in code with `UI.apply_theme("cloud")` (then rebuild any open screen), or for a debug run with `godot --path apps/mobile -- --uitheme=cloud`. The default is `Themes.DEFAULT`.

**Style options** (per theme, `UI.style`): `btn_radius` / `pill_radius` corner radius in px (-1 = fully rounded: height/3 for buttons, height/2 for pills) · `gloss` 0 none, 1 strip, 2 swoosh, 3 dot, 4 slant, 5 mixed (a different shape per button) · `shadow` 0 strong blurry drop shadow, 1 subtle (thin outline + tight shadow), 2 none · `bold` thick dark label outline · `panel_lip` panel bottom edge · `popup_frame(_bottom)` popup border widths · `panel_shadow`. The modern themes use boxy 16 px corners, slant gloss, subtle shadow and bold labels.

**Rules for theme-safe code**
- Read tokens when you build a widget (`UI.GOLD`), never in a `const` or at class load: they change with the theme.
- Never hard-code a colour that sits on a themed surface (cards, bars, popups, the gradient); use a token. The felt table and its HUD are the exception: they are themed per table style by `TableBg.THEMES`, a separate system.
- With gloss on, a button's label is drawn by an overlay Label so it stays above the shine; keep changing `button.text` as usual, it follows.

## Look (default theme)
A coloured, not white, world: deep teal gradient screens, translucent dark cards with a thick lower lip, pale text, accent-coloured titles and selection, chunky candy buttons (flat face + darker lip, thin outline, tight shadow, a slanted gloss highlight, boxy corners) in a world colour with one neighbour for buttons plus one warm accent, Lilita One font. The felt table is themed separately. Inspiration (style only, never another game's art or characters): casual mobile-game menus with chunky glossy buttons and pill chips.

## Colour tokens
Names are fixed; each theme gives them values (see `ui_themes.gd`).

| Token | Use |
|---|---|
| `BG_TOP/MID/BG_BOTTOM` | screen gradient (`UI.background()`) |
| `SURFACE`, `SURFACE_BORDER` | card fill / border (`UI.panel()`) |
| `SURFACE_SOLID` + `FRAME` | popup body + frame (`UI.popup_style()`) |
| `BAR`, `BAR_BORDER` | pinned header/footer of `UI.scroll_page` |
| `SCRIM` | dim behind modal popups |
| `GOLD` | selection, "on", rewards |
| `PRIMARY` | primary button |
| `SECONDARY` | secondary button, steppers, Close |
| `TERTIARY` | tertiary button |
| `DANGER` | danger/penalty/destructive only |
| `OFF` | unselected pill / toggle off |
| `TEXT` | white: on buttons, bars and titles |
| `TEXT_INK`, `TEXT_DIM` | body text / hints on cards and the gradient |
| `TEXT_HEADING`, `TAGLINE` | section headings / taglines |
| `TEXT_OFF`, `TEXT_ON_GOLD`, `TEXT_ACCENT` | unselected pill text / text on a gold face / highlighted numbers on a card |
| `TITLE`, `OUTLINE_DARK` | title text / title and button-text outline |
| `PATTERN`, `VEIL`, `CARD_TINT` | menu backdrop: suit pattern, veil over the scattered cards, card tint |

## Type scale (1080x1920 viewport)
`FONT_DISPLAY` 128 logo only · `FONT_H1` 96 screen title · `FONT_BUTTON_L` 80 primary CTA · `FONT_PILL` 52 · `FONT_BUTTON` 46 · `FONT_HEADING` 40 · `FONT_BODY` 38 · `FONT_HINT` 34 · `FONT_CAPTION` 30 (table captions). Don't invent sizes.

## Spacing and geometry
`SPACE_S` 16 (inside panels) · `SPACE_M` 30 (between blocks) · `SPACE_L` 60 · `PANEL_PAD` 36 · `PANEL_RADIUS` 48 · `MARGIN_SCREEN` 50. Standard button `BTN_W` 700 x `BTN_H` 120 (primary CTA `BTN_H_L` 170). Pills `PILL_W` 190 x `PILL_H` 110. Touch targets never below 110 px tall. Corner radii come from the theme style (`UI.btn_radius(h)`, `UI.pill_radius(h)`).

## Components
- `UI.background()` full-screen gradient; blocks input behind it. Every full screen/overlay starts with it.
- `UI.column()` centered vertical stack; `UI.panel()` returns `[panel, inner_vbox]`.
- Text: `UI.title(text, size)`, `UI.tagline`, `UI.heading`, `UI.body(text, wrap_w)`, `UI.hint`.
- `UI.button(text, Variant, on_press, large)`: PRIMARY / SECONDARY / TERTIARY / DANGER.
- `UI.icon_button("home"|"gear", on_press)`: round icon-only HUD button, `ICON_BTN` 110 px (finger-sized). Use for table HUD instead of text buttons.
- `UI.choice_row(labels, selected, on_pick)` mutually exclusive pills; `UI.toggle(text, on, handler)` on/off switch (gold = on); `UI.stepper("-"/"+", cb)`.
- `UI.spacer(h)`.

## Rules
1. **One primary button per screen**, large, at the bottom of the main action stack. Secondary actions below it in SECONDARY/TERTIARY. Close/Back is SECONDARY.
2. Group related controls in one `UI.panel()` with `UI.heading`s; don't scatter controls on the bare background.
3. Selection is always `GOLD`; "off" is always `OFF`. State is also written in text ("Sound: On"), never colour alone.
4. Screens are portrait, one centered column, nothing closer than 50 px to the edge. Long content uses `UI.scroll_page(title, close_text, on_close)`: a pinned header (border on its bottom edge) and footer (border on its top edge), both solid with a soft shadow, and borderless full-width content that slides under them. The scroll bar is invisible; never the default grey bar.
5. Full-screen overlays use `UI.background()` (opaque). Modals over the live table use `SCRIM` + `UI.popup_style()`.
6. Text over art gets an outline/shadow (`UI.title` does this). Body text is `TEXT_INK`; white text only on buttons, bars and outlined titles.
7. Respect Reduce motion (`Settings.reduce_motion`) for any new animation; UI feedback sounds go through `Sfx.play`.
8. Create controls in code via the kit; do not set per-node theme overrides in `.tscn` files.

## Adding to the system
**Try it in the playground first** (`godot --path apps/mobile -- --dsplay`, `scripts/ui/design_playground.gd`). It is built by the real kit and shows every component, with a footer to switch theme and override corners, gloss, shadow and bold text live. Only after a look is validated there does it go into `ui_themes.gd` / `ui_kit.gd`, and never straight into screens.

- New theme: add a palette + style to `ui_themes.gd`, list it in `NAMES`.
- New colour token: add it to every palette in `ui_themes.gd`, a `static var` + assignment in `ui_kit.gd`, a row above.
- New size/component: add to `ui_kit.gd` (and the playground page), a row above, then use it.

Verify with `godot --path apps/mobile -- --dsshot=out.png`, `--menushot=out.png`, `--settingsshot=out.png`, and `--uitheme=<name>` to try another theme on any screen.

## Migration status
Done: menu, rules, settings, leaderboard, history, game-over screen, boot, welcome/coach popups. Table screens (the table itself, its HUD and the J suit picker popup in `table.gd`) are themed per table style by `TableBg.THEMES`, not by this system yet.
