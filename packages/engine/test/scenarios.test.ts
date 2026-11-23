import { describe, expect, it } from 'vitest';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { runDeal, runPlayout, runScenario, type Deal, type Playout, type Scenario } from '../src/testing';

const dealsDir = fileURLToPath(new URL('../../rules-spec/deals/', import.meta.url));
for (const file of readdirSync(dealsDir).filter((f) => f.endsWith('.json'))) {
  const items = JSON.parse(readFileSync(join(dealsDir, file), 'utf8')) as (Deal | Playout)[];
  describe(`deals/${file}`, () => {
    for (const d of items) {
      it(d.name, () => {
        const errs = file === 'playouts.json' ? runPlayout(d as Playout) : runDeal(d as Deal);
        expect(errs).toEqual([]);
      });
    }
  });
}

const dir = fileURLToPath(new URL('../../rules-spec/scenarios/', import.meta.url));

for (const file of readdirSync(dir).filter((f) => f.endsWith('.json'))) {
  const scenarios = JSON.parse(readFileSync(join(dir, file), 'utf8')) as Scenario[];
  describe(file, () => {
    for (const sc of scenarios) {
      it(sc.name, () => {
        expect(runScenario(sc)).toEqual([]);
      });
    }
  });
}
