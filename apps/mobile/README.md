# Godot client

Open this folder in Godot 4.7 and press Play, or run:

    godot --path apps/mobile

You play against 1-3 bots, fully offline.

## Layout
- `scripts/engine/` - GDScript port of `packages/engine` (`engine.gd` = rules; must stay identical to the TypeScript engine)
- `scripts/ai/bot.gd` - bot players (`easy` = mostly random, `normal` = heuristic)
- `scripts/game/offline_game.gd` - offline session: runs the engine, drives the bots
- `scripts/audio/sfx.gd` - synthesised sound effects (`Sfx.play("name")`); `scripts/game/settings.gd` - saved settings (sound, volume, reduce motion)
- `DESIGN_SYSTEM.md` / `scripts/ui/ui_kit.gd` - UI tokens + widgets; all new UI must use them
- `scripts/ui/` - menu, table, placeholder vector cards (`card_art.gd`, `card_view.gd`, ...)
- `scripts/main.gd` - root; also hosts debug flags (below)
- `data/rules.json` - synced copy of `packages/rules-spec/rules.json` (`pnpm sync-rules`)

## Game records
Every game is logged to `user://games/<id>.jsonl` (header with seed/players/difficulty/rules hash, one line per action
with the bot RNG state, optional stickers, a footer once finished; see `scripts/game/recorder.gd`). The engine is
deterministic, so the log is enough to **resume** an unfinished game (menu: Resume game) or **replay** a finished one
(menu: History). One unfinished game and the last 20 finished ones are kept. Debug runs (any `--` flag) never record.

## Tests and tools (all headless-friendly)
    godot --headless --path apps/mobile -s res://scripts/tests/run_conformance.gd   # shared scenarios vs TS engine
    godot --headless --path apps/mobile -s res://scripts/tests/test_record_replay.gd   # record / resume / replay determinism
    godot --path apps/mobile -- --replayshot=out.png                                # replay UI of the newest record the test left behind
    godot --headless --path apps/mobile -- --selftest                               # plays full games through the real UI handlers
    godot --headless --path apps/mobile -s res://scripts/tests/sim_bots.gd -- 100   # bot-vs-bot win rates / game length
    godot --path apps/mobile -- --shot=out.png --bots=2                             # out_a/_b/_c.png: mid-deal, a card mid-flight, settled
    godot --path apps/mobile -- --menushot=out.png                                  # screenshot of the menu
    godot --path apps/mobile -- --exportsounds=out_dir                              # write every sound as a .wav so you can listen
    godot --path apps/mobile -- --reduce --selftest                                 # run with Reduce motion on (not saved)
    godot --path apps/mobile -- --settingsshot=out.png                              # screenshot of the settings screen
    godot --headless --path apps/mobile -s res://scripts/tests/sim_learn.gd -- train 30 24 200   # retrain the 'hard' bot's knowledge (data/hard_knowledge.json) by self-play vs 'normal'
    godot --headless --path apps/mobile -s res://scripts/tests/sim_choices.gd -- 100   # how often a turn offers a real choice

## 3D suits
The suit icons (J picker, PLAY pill) are Blender renders, shown by `scripts/ui/suit3d.gd`. Regenerate with:

    blender -b -P tools/blender/make_suits.py -- --out <tmp_frames_dir>     # 96-frame turntable per suit (EEVEE, ~30 min)
    python tools/blender/pack_suits.py <tmp_frames_dir> apps/mobile/assets/suits

Tweak look/shape in `make_suits.py` (`MAX_R`/`MAX_T` = plumpness, colours at the top). Missing sheets fall back to the flat vector art.
    godot --path apps/mobile -- --suitshot=out.png    # picker + PLAY-pill spin screenshots
