---
name: create-avatar
description: Use when adding, restyling or re-rendering a player avatar in the J-Command cards game (new bot character, new hair/hat kind, new animation, "make the avatars look better"). Covers the Blender pipeline in tools/avatars (procedural 3D chibi rig -> PNG frames -> circular spritesheets + preview GIFs) and how Godot plays them.
---

# Creating avatars

Avatars are **pre-rendered 3D sprites**: Blender builds a procedural chibi (head, face, hair, shoulders) and renders looping animations; Python packs the frames into spritesheets; Godot just plays the sheet in a circle. `scripts/ui/avatar.gd` keeps the old vector drawing as a fallback when no sheet exists.

## Files
- `tools/avatars/styles.json` — one entry per avatar: `name, bg, skin, hair, accent` (sRGB 0-1) and `kind` (hair style).
- `tools/avatars/render_avatars.py` — Blender script (rig, hair kinds, lighting, animations).
- `tools/avatars/pack_avatars.py` — masks frames to a circle, writes sheets + `meta.json` + GIFs.
- `apps/mobile/assets/avatars/` — output used by the game (`<name>_idle.png`, `<name>_happy.png`, `meta.json`). Commit these.
- `tools/avatars/previews/*.gif` — review GIFs (`all.gif` = every avatar side by side). Git-ignored: they are only for reviewing a render, the game never loads them.
- `tools/avatars/frames/` — raw renders, git-ignored.

## Add a new avatar
1. Append an entry to `styles.json` **and** to `STYLES` in `apps/mobile/scripts/ui/avatar.gd` (same order = player slot; same name, colours and kind — the vector fallback uses the GDScript copy). `Avatar.index_for` maps `botN` -> slot N, so more bots than avatars need more entries.
2. New hair/hat? Add a branch to `build_hair()` in `render_avatars.py`. Everything must be parented to the `head` pivot so it moves with the head. Hairline rule: a cap's lower edge must stay above local z 0.15 or it covers the eyes (`above(th)` filters a sphere to its cap). Hair that sits *behind* the head must be moved back in +y (front of the face is -y) or it hides the face.
3. Quick look at one still (~20 s): 
   `"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b -P tools/avatars/render_avatars.py -- --still --only <Name> --size 256 --out <scratch dir>` and view the PNG. Iterate here; don't render animations until the still is good.
4. Render frames: `blender -b -P tools/avatars/render_avatars.py -- --only <Name> --size 192 --out tools/avatars/frames` (Cycles on CPU: ~4-8 s/frame, 64 idle + 24 happy frames per avatar; run in the background). Omit `--only` for all avatars; `--anim idle` / `--anim happy` for one animation.
5. Pack: `python tools/avatars/pack_avatars.py` (needs Pillow). This rewrites sheets for every avatar that has frames, plus `meta.json` and the GIFs.
6. Review `tools/avatars/previews/<name>.gif` and `all.gif`. Check: reads at ~100 px, blink is visible, loop has no pop, face not covered, hair/hat does not clip.
7. In Godot run `--headless --import` once (sheets need `.import` files, which are git-ignored), then launch the game and check the table, your own portrait, opponents and the podium.

## Conventions that matter
- Coordinates: character faces **-y**, camera at -y looking +y, z up, orthographic, ortho scale 2.0 = the unit circle the avatar is masked to. Head radius 0.5, head centre z -0.10, shoulders low and wide so the disc stays filled.
- Colours go through `lin()` (sRGB -> linear); the view transform is `Standard`, so `bg` renders as exactly the colour in `styles.json` and matches the vector fallback and the ring.
- Animation loops are 24 fps and must be periodic in the loop length (`idle` 64 frames, `happy` 24) — only use `sin(k*ph)` with integer `k`, and keep a blink inside one loop. Per-avatar phase offset (`off = idx*0.9`, blink start `14 + idx*11`) keeps avatars out of sync.
- `happy` is used for the winner on the podium (`draw_avatar(..., happy=true)`). New animations: add to `ANIMS` in the Blender script, `COLS` in `pack_avatars.py`, and a branch in `pose()`; then read it in `avatar.gd::_draw_sprite`.
- Sheet size matters on mobile: 192 px frames, idle 8x8 sheet. Don't raise frame size/count casually (4 avatars x 2 sheets are loaded uncompressed).
- Reduce-motion setting: the game shows frame 0 only (handled in `_draw_sprite`).
- Windows quirk: heredocs with quotes in the Bash tool can fail; write files with the Write tool.
