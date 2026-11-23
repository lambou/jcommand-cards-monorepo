// Copies packages/rules-spec/rules.json into the Godot project (apps/mobile/data/rules.json).
// Use --check to verify without writing (exit 1 if out of sync).
import { copyFileSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const src = fileURLToPath(new URL('../../packages/rules-spec/rules.json', import.meta.url));
const dst = fileURLToPath(new URL('../../apps/mobile/data/rules.json', import.meta.url));

if (process.argv.includes('--check')) {
  if (readFileSync(src, 'utf8') !== readFileSync(dst, 'utf8')) {
    console.error('apps/mobile/data/rules.json is out of sync; run: pnpm sync-rules');
    process.exit(1);
  }
  console.log('rules.json in sync');
} else {
  copyFileSync(src, dst);
  console.log('synced rules.json -> apps/mobile/data/rules.json');
}
