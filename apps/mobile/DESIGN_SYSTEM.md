# J-Command design system

All menus, overlays and HUD controls are built from `scripts/ui/ui_kit.gd`:

    const UI := preload("res://scripts/ui/ui_kit.gd")

**Rule: no ad-hoc `Color(...)`, font sizes, or `StyleBoxFlat` in screen code.** If you need something the kit lacks, add a token/factory to the kit first, then use it. Reference screens: `menu.gd`, `settings_panel.gd`.

## Look
Playful "felt table" casino: deep-green gradient, gold accents, chunky candy buttons (flat face + darker lip + soft shadow, they sink when pressed), rounded translucent panels, Lilita One font. Never purple/blue backgrounds. Inspiration (not to copy): Dribbble "game mobile menu" shots with chunky glossy buttons and pill chips.

## Colour tokens
| Token | Use |
|---|---|
| `BG_TOP/MID/BG_BOTTOM` | screen gradient (`UI.background()`); `BG_MID` = table felt |
| `SURFACE`, `SURFACE_BORDER` | translucent panel fill / border (`UI.panel()`) |
| `SURFACE_SOLID` + gold border | popups over the table (`UI.popup_style()`) |
| `SCRIM` | dim behind modal popups on the table |
| `GOLD` | titles, section headings, selection |
| `AMBER` | primary button |
| `EMERALD` | secondary button, steppers |
| `TEAL` | tertiary button |
| `RED` | danger/penalty/destructive only |
| `OFF` | unselected pill / toggle off |
| `TEXT`, `TEXT_MINT`, `TEXT_DIM`, `TEXT_ON_GOLD` | white / taglines + unselected pills / hints / text on gold faces |

## Type scale (1080x1920 viewport)
`FONT_DISPLAY` 128 logo only · `FONT_H1` 96 screen title · `FONT_BUTTON_L` 80 primary CTA · `FONT_PILL` 52 · `FONT_BUTTON` 46 · `FONT_HEADING` 40 · `FONT_BODY` 38 · `FONT_HINT` 34 · `FONT_CAPTION` 30 (table captions). Don't invent sizes.

## Spacing and geometry
`SPACE_S` 16 (inside panels) · `SPACE_M` 30 (between blocks) · `SPACE_L` 60 · `PANEL_PAD` 36 · `PANEL_RADIUS` 48 · `MARGIN_SCREEN` 50. Standard button `BTN_W` 700 x `BTN_H` 120 (primary CTA `BTN_H_L` 170). Pills `PILL_W` 190 x `PILL_H` 110. Touch targets never below 110 px tall. Corner radius = height/3 for buttons, height/2 for pills.

## Components
- `UI.background()` full-screen gradient; blocks input behind it. Every full screen/overlay starts with it.
- `UI.column()` centered vertical stack; `UI.panel()` returns `[panel, inner_vbox]`.
- Text: `UI.title(text, size)`, `UI.tagline`, `UI.heading`, `UI.body(text, wrap_w)`, `UI.hint`.
- `UI.button(text, Variant, on_press, large)`: PRIMARY (amber) / SECONDARY (emerald) / TERTIARY (teal) / DANGER (red).
- `UI.icon_button("home"|"gear", on_press)`: round icon-only HUD button, `ICON_BTN` 110 px (finger-sized). Use for table HUD instead of text buttons.
- `UI.choice_row(labels, selected, on_pick)` mutually exclusive pills; `UI.toggle(text, on, handler)` on/off switch (gold = on); `UI.stepper("-"/"+", cb)`.
- `UI.spacer(h)`.

## Rules
1. **One primary button per screen**, amber and large, at the bottom of the main action stack. Secondary actions below it in emerald/teal. Close/Back is SECONDARY.
2. Group related controls in one `UI.panel()` with gold `UI.heading`s; don't scatter controls on the bare background.
3. Selection is always gold; "off" is always `OFF` dark green. State is also written in text ("Sound: On"), never colour alone.
4. Screens are portrait, one centered column, nothing closer than 50 px to the edge. Long content uses `UI.scroll_page(title, close_text, on_close)`: a pinned header (border on its bottom edge) and footer (border on its top edge), both solid with a soft shadow, and borderless full-width content that slides under them. The scroll bar is invisible; never the default grey bar.
5. Full-screen overlays use `UI.background()` (opaque). Modals over the live table use `SCRIM` + `UI.popup_style()`.
6. Text over art gets an outline/shadow (`UI.title` does this); body text sits on a panel, not directly on the gradient.
7. Respect Reduce motion (`Settings.reduce_motion`) for any new animation; UI feedback sounds go through `Sfx.play`.
8. Create controls in code via the kit; do not set per-node theme overrides in `.tscn` files.

## Adding to the system
New colour/size/component: add to `ui_kit.gd`, add a row here, then use it. Verify with `godot --path apps/mobile -- --menushot=out.png` / `--settingsshot=out.png`.

## Migration status
Done: menu, rules, settings. Done also: game-over screen. Still ad-hoc (migrate when touched): J suit picker popup in `table.gd`.
