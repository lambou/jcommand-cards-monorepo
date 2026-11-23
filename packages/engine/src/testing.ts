import type { Action, Card, GameState, Required, Settings, Suit } from './types';
import { cardCode, parseCard } from './cards';
import { spec } from './rules';
import { applyAction, createGame, legalActions } from './engine';
import { suitColor } from './cards';

export interface ScenarioSetup {
  players: string[];
  hands: Record<string, string[]>;
  /** Top-first. */
  bank?: string[];
  /** Bottom -> top. */
  stack: string[];
  /** "H" | "D" | "C" | "S" | "red" | "black" | "free". Defaults to the stack top's suit. */
  required?: string;
  current?: string;
  pending?: number;
  settings?: Partial<Settings>;
}

export interface Expect {
  current?: string;
  pending?: number;
  required?: string;
  over?: boolean;
  loser?: string | null;
  stackTop?: string;
  stackBottom?: string;
  stackSize?: number;
  bankSize?: number;
  /** Top-first. */
  bank?: string[];
  handSizes?: Record<string, number>;
  /** Compared as multisets. */
  hands?: Record<string, string[]>;
  places?: Record<string, number | null>;
  statuses?: Record<string, string>;
  finishedOrder?: string[];
}

export interface Step {
  player: string;
  action: 'play' | 'draw' | 'takePenalty';
  card?: string;
  suit?: Suit;
  expectError?: boolean;
  expect?: Expect;
}

export interface Scenario {
  name: string;
  description?: string;
  setup: ScenarioSetup;
  steps: Step[];
}

export function requiredToString(r: Required): string {
  if (r.kind === 'free') return 'free';
  return r.kind === 'suit' ? r.suit : r.color;
}

function parseRequired(str: string): Required {
  if (str === 'free') return { kind: 'free' };
  if (str === 'red' || str === 'black') return { kind: 'color', color: str };
  return { kind: 'suit', suit: str as Suit };
}

export function buildState(setup: ScenarioSetup): GameState {
  let nextId = 0;
  const mk = (code: string): Card => parseCard(code, nextId++);
  const stack = setup.stack.map(mk);
  const top = stack[stack.length - 1]!;
  const required = setup.required
    ? parseRequired(setup.required)
    : top.suit
      ? ({ kind: 'suit', suit: top.suit } as Required)
      : ({ kind: 'color', color: top.color } as Required);
  const players = setup.players.map((id) => ({
    id,
    hand: (setup.hands[id] ?? []).map(mk),
    status: 'playing' as const,
    place: null,
  }));
  // setup.bank is top-first; state.bank keeps the top at the end.
  const bank = (setup.bank ?? []).map(mk).reverse();
  return {
    players,
    bank,
    stack,
    required,
    pending: setup.pending ?? 0,
    current: Math.max(0, setup.players.indexOf(setup.current ?? setup.players[0]!)),
    settings: { ...spec.defaultSettings, ...setup.settings },
    rngState: 1,
    finishedOrder: [],
    provisionalOrder: [],
    over: false,
    loser: null,
  };
}

const sorted = (xs: string[]) => [...xs].sort();

function check(state: GameState, e: Expect, label: string, out: string[]): void {
  const eq = (what: string, got: unknown, want: unknown) => {
    if (JSON.stringify(got) !== JSON.stringify(want)) {
      out.push(`${label}: ${what}: expected ${JSON.stringify(want)}, got ${JSON.stringify(got)}`);
    }
  };
  const byId = (id: string) => state.players.find((p) => p.id === id)!;
  if (e.current !== undefined) eq('current', state.players[state.current]!.id, e.current);
  if (e.pending !== undefined) eq('pending', state.pending, e.pending);
  if (e.required !== undefined) eq('required', requiredToString(state.required), e.required);
  if (e.over !== undefined) eq('over', state.over, e.over);
  if (e.loser !== undefined) eq('loser', state.loser, e.loser);
  if (e.stackTop !== undefined) eq('stackTop', cardCode(state.stack[state.stack.length - 1]!), e.stackTop);
  if (e.stackBottom !== undefined) eq('stackBottom', cardCode(state.stack[0]!), e.stackBottom);
  if (e.stackSize !== undefined) eq('stackSize', state.stack.length, e.stackSize);
  if (e.bankSize !== undefined) eq('bankSize', state.bank.length, e.bankSize);
  if (e.bank !== undefined) eq('bank', state.bank.map(cardCode).reverse(), e.bank);
  for (const [id, n] of Object.entries(e.handSizes ?? {})) eq(`handSize(${id})`, byId(id).hand.length, n);
  for (const [id, h] of Object.entries(e.hands ?? {})) eq(`hand(${id})`, sorted(byId(id).hand.map(cardCode)), sorted(h));
  for (const [id, pl] of Object.entries(e.places ?? {})) eq(`place(${id})`, byId(id).place, pl);
  for (const [id, st] of Object.entries(e.statuses ?? {})) eq(`status(${id})`, byId(id).status, st);
  if (e.finishedOrder !== undefined) eq('finishedOrder', state.finishedOrder, e.finishedOrder);
}

/** Runs a scenario; returns a list of failure messages (empty = pass). */
export function runScenario(sc: Scenario): string[] {
  const failures: string[] = [];
  let state = buildState(sc.setup);
  sc.steps.forEach((step, i) => {
    const label = `${sc.name} step ${i + 1} (${step.player} ${step.action}${step.card ? ' ' + step.card : ''})`;
    let action: Action;
    if (step.action === 'play') {
      const p = state.players.find((q) => q.id === step.player)!;
      const card = p.hand.find((c) => cardCode(c) === step.card);
      if (!card) {
        failures.push(`${label}: card not in hand (scenario bug)`);
        return;
      }
      action = { type: 'play', playerId: step.player, cardId: card.id, chosenSuit: step.suit };
    } else {
      action = { type: step.action, playerId: step.player };
    }
    const res = applyAction(state, action);
    if (step.expectError) {
      if (res.ok) failures.push(`${label}: expected an error but action succeeded`);
      return;
    }
    if (!res.ok) {
      failures.push(`${label}: unexpected error ${res.error}`);
      return;
    }
    state = res.state;
    if (step.expect) check(state, step.expect, label, failures);
  });
  return failures;
}

export interface Deal {
  name: string;
  playerIds: string[];
  seed?: number;
  /** Card codes, first-dealt first. Skips shuffling. */
  deck?: string[];
  settings?: Partial<Settings>;
  expect: Expect & { hands?: Record<string, string[]>; bankTop?: string[]; bankBottom?: string[] };
}

/** Runs a deal / start-card case; hands are compared in exact order here. */
export function runDeal(d: Deal): string[] {
  const failures: string[] = [];
  const state = createGame({
    playerIds: d.playerIds,
    seed: d.seed,
    settings: d.settings,
    deck: d.deck?.map((c, i) => parseCard(c, i)).reverse(), // engine deals from the end
  });
  const label = `deal ${d.name}`;
  const eq = (what: string, got: unknown, want: unknown) => {
    if (JSON.stringify(got) !== JSON.stringify(want)) {
      failures.push(`${label}: ${what}: expected ${JSON.stringify(want)}, got ${JSON.stringify(got)}`);
    }
  };
  const { hands, bankTop, bankBottom, ...rest } = d.expect;
  for (const [id, h] of Object.entries(hands ?? {})) {
    eq(`hand(${id})`, state.players.find((p) => p.id === id)!.hand.map(cardCode), h);
  }
  check(state, rest, label, failures);
  const topFirst = state.bank.map(cardCode).reverse();
  if (bankTop) eq('bankTop', topFirst.slice(0, bankTop.length), bankTop);
  if (bankBottom) eq('bankBottom', state.bank.map(cardCode).slice(0, bankBottom.length), bankBottom);
  return failures;
}

export interface Playout {
  name: string;
  playerIds: string[];
  seed: number;
  settings?: Partial<Settings>;
  maxSteps: number;
  expect: Expect & { steps: number };
}

/** Deterministic pseudo-random playout; both engines must end in the same state. */
export function playoutSummary(p: Pick<Playout, 'playerIds' | 'seed' | 'settings' | 'maxSteps'>) {
  let state = createGame({ playerIds: p.playerIds, seed: p.seed, settings: p.settings });
  let pick = p.seed;
  let steps = 0;
  while (!state.over && steps < p.maxSteps) {
    const acts = legalActions(state, state.players[state.current]!.id);
    pick = (Math.imul(pick, 1103515245) + 12345) >>> 0;
    // Prefer plays so games actually finish; occasionally take the draw/penalty instead.
    const plays = acts.filter((a) => a.type === 'play');
    const others = acts.filter((a) => a.type !== 'play');
    const pool = plays.length > 0 && (pick >>> 8) % 8 !== 0 ? plays : others.length > 0 ? others : plays;
    const res = applyAction(state, pool[pick % pool.length]!);
    if (!res.ok) throw new Error(`legal action rejected: ${res.error}`);
    state = res.state;
    steps++;
  }
  return { state, steps };
}

export function runPlayout(p: Playout): string[] {
  const failures: string[] = [];
  const { state, steps } = playoutSummary(p);
  check(state, p.expect, `playout ${p.name}`, failures);
  if (steps !== p.expect.steps) failures.push(`playout ${p.name}: steps: expected ${p.expect.steps}, got ${steps}`);
  return failures;
}

export { suitColor };
