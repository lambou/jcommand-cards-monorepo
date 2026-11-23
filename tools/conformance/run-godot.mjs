// Runs the GDScript engine against the shared scenarios (headless).
// Godot binary: $GODOT, else "godot" on PATH.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const project = fileURLToPath(new URL('../../apps/mobile', import.meta.url));
const godot = process.env.GODOT || 'godot';
const r = spawnSync(godot, ['--headless', '--path', project, '-s', 'res://scripts/tests/run_conformance.gd'], { stdio: 'inherit' });
if (r.error) {
  console.error(`Could not run "${godot}". Set the GODOT env var to your Godot 4 console executable.`);
  process.exit(2);
}
process.exit(r.status ?? 1);
