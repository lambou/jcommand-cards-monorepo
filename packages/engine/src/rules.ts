import rulesJson from '@jcommand/rules-spec/rules.json';
import type { Rank, RuleDef, Settings } from './types';

interface RulesSpec {
  version: number;
  deck: { suits: string[]; ranks: string[]; jokers: string[] };
  defaultSettings: Settings;
  ranks: Record<string, RuleDef>;
}

export const spec = rulesJson as unknown as RulesSpec;

export function ruleOf(rank: Rank): RuleDef {
  return { ...spec.ranks['default'], ...(spec.ranks[rank] ?? {}) };
}

export function penaltyOf(rank: Rank): number {
  return ruleOf(rank).penalty ?? 0;
}
