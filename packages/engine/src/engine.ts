import type {
  Action, Card, GameEvent, GameState, Player, Required, Result, Settings, Suit,
} from './types';
import { createDeck, SUITS, suitColor } from './cards';
import { penaltyOf, ruleOf, spec } from './rules';
import { shuffleInPlace } from './rng';

const fail = (error: string): Result => ({ ok: false, error });

// ---------------------------------------------------------------- setup

export interface CreateGameOptions {
  playerIds: string[];
  settings?: Partial<Settings>;
  seed?: number;
  /** Pre-ordered deck (last element is dealt first). Skips shuffling. For tests. */
  deck?: Card[];
}

export function createGame(opts: CreateGameOptions): GameState {
  const settings: Settings = { ...spec.defaultSettings, ...opts.settings };
  const n = opts.playerIds.length;
  if (n < 2 || n > 10) throw new Error('2-10 players required');
  const deck = opts.deck ? [...opts.deck] : createDeck();
  if (n * settings.handSize + 2 > deck.length) throw new Error('Too many players for the deck');

  const rngState = (opts.seed ?? 1) >>> 0;
  const box = { s: rngState };
  if (!opts.deck) shuffleInPlace(deck, box);

  const players: Player[] = opts.playerIds.map((id) => ({
    id, hand: [], status: 'playing', place: null,
  }));
  for (let r = 0; r < settings.handSize; r++) {
    for (const p of players) p.hand.push(deck.pop()!);
  }

  // Flip the starting card. Redeal-type cards go to the bottom of the bank.
  let start = deck.pop()!;
  while (ruleOf(start.rank).onStart === 'redeal') {
    deck.unshift(start);
    start = deck.pop()!;
  }

  const startRule = ruleOf(start.rank);
  let required: Required;
  if (startRule.onStart === 'free') required = { kind: 'free' };
  else required = { kind: 'suit', suit: start.suit! };

  const state: GameState = {
    players,
    bank: deck,
    stack: [start],
    required,
    pending: 0,
    current: 0,
    settings,
    rngState: box.s,
    finishedOrder: [],
    provisionalOrder: [],
    over: false,
    loser: null,
  };
  if (startRule.onStart === 'skipFirst') {
    for (let k = 0; k < (startRule.skipNext ?? 1); k++) {
      state.current = nextUnfinished(state, state.current);
    }
  }
  return state;
}

// ---------------------------------------------------------------- queries

function matchesRequired(card: Card, req: Required): boolean {
  switch (req.kind) {
    case 'free': return true;
    case 'color': return card.color === req.color;
    case 'suit':
      return card.suit !== undefined
        ? card.suit === req.suit
        : card.color === suitColor(req.suit);
  }
}

function unfinishedCount(s: GameState): number {
  return s.players.filter((p) => p.status !== 'finished').length;
}

export function isPlayable(s: GameState, hand: Card[], card: Card): boolean {
  if (s.pending > 0) return penaltyOf(card.rank) > 0;
  const rule = ruleOf(card.rank);
  if (rule.cannotFinishWhenTwoPlayersLeft && hand.length === 1 && unfinishedCount(s) === 2) {
    return false;
  }
  const floor = s.stack[s.stack.length - 1]!;
  if (rule.playOnLion && floor.rank === 'LION') return true;
  if (rule.playOnSeven && floor.rank === '7') return true;
  switch (rule.playOn) {
    case 'any': return true;
    case 'required':
      return matchesRequired(card, s.required)
        || (s.settings.matchRank && rule.matchRank !== false && floor.rank === card.rank);
    case 'requiredOrSameRank':
      return matchesRequired(card, s.required) || floor.rank === card.rank;
  }
}

export function legalActions(s: GameState, playerId: string): Action[] {
  if (s.over) return [];
  const p = s.players[s.current]!;
  if (p.id !== playerId) return [];
  const out: Action[] = [];
  for (const card of p.hand) {
    if (!isPlayable(s, p.hand, card)) continue;
    if (ruleOf(card.rank).sets === 'chosen') {
      for (const chosenSuit of SUITS) out.push({ type: 'play', playerId, cardId: card.id, chosenSuit });
    } else {
      out.push({ type: 'play', playerId, cardId: card.id });
    }
  }
  out.push(s.pending > 0 ? { type: 'takePenalty', playerId } : { type: 'draw', playerId });
  return out;
}

// ---------------------------------------------------------------- helpers

function nextUnfinished(s: GameState, from: number): number {
  const n = s.players.length;
  for (let i = 1; i <= n; i++) {
    const idx = (from + i) % n;
    if (s.players[idx]!.status !== 'finished') return idx;
  }
  return from;
}

function drawOne(s: GameState, events: GameEvent[]): Card | null {
  if (s.bank.length === 0) {
    if (s.stack.length <= 1) return null;
    const floor = s.stack.pop()!;
    const rest = s.stack;
    s.stack = [floor];
    if (s.settings.reshuffleOnRefill) {
      const box = { s: s.rngState };
      shuffleInPlace(rest, box);
      s.rngState = box.s;
      s.bank = rest;
    } else {
      // Turn the pile over: the old bottom becomes the top of the bank.
      s.bank = rest.reverse();
    }
    events.push({ type: 'refill', reshuffled: s.settings.reshuffleOnRefill });
  }
  return s.bank.pop() ?? null;
}

function confirmFinish(s: GameState, p: Player, events: GameEvent[]): void {
  p.status = 'finished';
  p.place = s.finishedOrder.length + 1;
  s.finishedOrder.push(p.id);
  events.push({ type: 'finish', playerId: p.id, place: p.place });
}

/** Ends the game when at most one player is still in. Returns true if over. */
function checkOver(s: GameState, events: GameEvent[]): boolean {
  const left = s.players.filter((p) => p.status !== 'finished');
  if (left.length > 1) return false;
  s.over = true;
  s.provisionalOrder = [];
  if (left.length === 1) {
    const last = left[0]!;
    last.status = 'finished';
    last.place = s.finishedOrder.length + 1;
    s.finishedOrder.push(last.id);
    s.loser = last.id;
  }
  events.push({ type: 'gameOver', loser: s.loser });
  return true;
}

// ---------------------------------------------------------------- apply

export function applyAction(state: GameState, action: Action): Result {
  if (state.over) return fail('game_over');
  const s = structuredClone(state);
  const events: GameEvent[] = [];
  const cur = s.players[s.current]!;
  if (cur.id !== action.playerId) return fail('not_your_turn');

  switch (action.type) {
    case 'play': return doPlay(s, cur, action, events);
    case 'draw': return doDraw(s, cur, events);
    case 'takePenalty': return doTakePenalty(s, cur, events);
  }
}

function doPlay(
  s: GameState, cur: Player, action: Extract<Action, { type: 'play' }>, events: GameEvent[],
): Result {
  const idx = cur.hand.findIndex((c) => c.id === action.cardId);
  if (idx < 0) return fail('card_not_in_hand');
  const card = cur.hand[idx]!;
  if (!isPlayable(s, cur.hand, card)) return fail('illegal_play');
  const rule = ruleOf(card.rank);
  if (rule.sets === 'chosen' && (!action.chosenSuit || !SUITS.includes(action.chosenSuit))) {
    return fail('suit_required');
  }

  cur.hand.splice(idx, 1);
  if (rule.slideUnder) s.stack.unshift(card);
  else s.stack.push(card);

  switch (rule.sets) {
    case 'suit': s.required = { kind: 'suit', suit: card.suit! }; break;
    case 'color': s.required = { kind: 'color', color: card.color }; break;
    case 'chosen': s.required = { kind: 'suit', suit: action.chosenSuit as Suit }; break;
    case 'none': break;
  }
  const penalty = rule.penalty ?? 0;
  s.pending += penalty;
  events.push({ type: 'play', playerId: cur.id, card, chosenSuit: action.chosenSuit });

  if (cur.hand.length === 0) {
    if (penalty > 0) {
      cur.status = 'provisional';
      s.provisionalOrder.push(cur.id);
      events.push({ type: 'provisionalFinish', playerId: cur.id });
    } else {
      confirmFinish(s, cur, events);
    }
  }
  if (checkOver(s, events)) return { ok: true, state: s, events };

  let next = nextUnfinished(s, s.current);
  for (let k = 0; k < (rule.skipNext ?? 0); k++) {
    events.push({ type: 'skip', playerId: s.players[next]!.id });
    next = nextUnfinished(s, next);
  }
  s.current = next;
  return { ok: true, state: s, events };
}

function doDraw(s: GameState, cur: Player, events: GameEvent[]): Result {
  if (s.pending > 0) return fail('must_take_penalty');
  const card = drawOne(s, events);
  if (card) cur.hand.push(card);
  events.push({ type: 'draw', playerId: cur.id, count: card ? 1 : 0 });
  s.current = nextUnfinished(s, s.current);
  return { ok: true, state: s, events };
}

function doTakePenalty(s: GameState, cur: Player, events: GameEvent[]): Result {
  if (s.pending <= 0) return fail('no_penalty');
  let drawn = 0;
  for (let i = 0; i < s.pending; i++) {
    const card = drawOne(s, events);
    if (!card) break;
    cur.hand.push(card);
    drawn++;
  }
  s.pending = 0;
  events.push({ type: 'penaltyTaken', playerId: cur.id, count: drawn });

  // The taker (if they had provisionally finished) is back in the game; every
  // other provisional finisher is now confirmed, in the order they finished.
  if (cur.status === 'provisional') cur.status = 'playing';
  for (const id of s.provisionalOrder) {
    const p = s.players.find((q) => q.id === id)!;
    if (p !== cur) confirmFinish(s, p, events);
  }
  s.provisionalOrder = [];
  if (cur.hand.length === 0) confirmFinish(s, cur, events); // bank exhausted edge case

  if (checkOver(s, events)) return { ok: true, state: s, events };
  s.current = nextUnfinished(s, s.current);
  return { ok: true, state: s, events };
}
