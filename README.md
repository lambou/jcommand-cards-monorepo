# J-Command Cards

See [GDD.md](GDD.md) for the game design.

## Layout
- `packages/rules-spec` - declarative card rules (`rules.json`) + golden scenarios shared by all engines
- `packages/engine` - TypeScript rules engine (source of truth)
- `apps/server` - game server (placeholder)
- `apps/mobile` - Godot client; `scripts/engine` is the GDScript port of the engine
- `tools/conformance` - sync + run-godot helpers

## Commands
    pnpm install
    pnpm test        # engine unit + golden scenario tests
    pnpm typecheck
    pnpm sync-rules          # copy rules.json into the Godot project
    GODOT=<godot console exe> pnpm conformance:godot   # GDScript engine vs shared scenarios
