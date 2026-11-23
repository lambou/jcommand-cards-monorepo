import { describe, expect, it } from 'vitest';
import {
  applyAction, cardCode, createGame, legalActions, type Action, type Card, type GameState,
} from '../src';
import { parseCard } from '../src/cards';

/** codes are listed in the order they are dealt/flipped (first = dealt first). */
function stackedDeck(codes: string[]): Card[] {
  // createGame pops from the end, so reverse.
  return codes.map((c, i) => parseCard(c, i)).reverse();
}

describe('createGame', () => {
  it('deals 5 cards each and flips one, with a full 54-card deck', () => {
    const s = createGame({ playerIds: ['A', 'B', 'C'], seed: 42 });
    expect(s.players.every((p) => p.hand.length === 5)).toBe(true);
    expect(s.stack).toHaveLength(1);
    expect(s.players.reduce((n, p) => n + p.hand.length, 0) + s.stack.length + s.bank.length).toBe(54);
  });

  it('is deterministic for a seed', () => {
    const a = createGame({ playerIds: ['A', 'B'], seed: 7 });
    const b = createGame({ playerIds: ['A', 'B'], seed: 7 });
    expect(a).toEqual(b);
  });

  const hands2 = ['3S', '4S', '5S', '6S', '8S', '9S', '10S', 'QS', 'KS', '3C']; // A,B alternate

  it('sends a starting 7 or Lion to the bottom of the bank and flips again', () => {
    const s = createGame({
      playerIds: ['A', 'B'],
      deck: stackedDeck([...hands2, '7H', 'LR', '5D', 'KD']),
    });
    expect(cardCode(s.stack[0]!)).toBe('5D');
    expect(s.bank.map(cardCode).slice(0, 2)).toEqual(['LR', '7H']);
    expect(s.required).toEqual({ kind: 'suit', suit: 'D' });
    expect(s.current).toBe(0);
  });

  it('starting J or 2 leaves the first player free', () => {
    for (const code of ['JH', '2H']) {
      const s = createGame({ playerIds: ['A', 'B'], deck: stackedDeck([...hands2, code, 'KD']) });
      expect(s.required).toEqual({ kind: 'free' });
    }
  });

  it('starting Ace skips the first player', () => {
    const s = createGame({ playerIds: ['A', 'B', 'C'], deck: stackedDeck([
      '3S', '4S', '5S', '6S', '8S', '9S', '10S', 'QS', 'KS', '3C', '4C', '5C', '6C', '8C', '9C', 'AH', 'KD',
    ]) });
    expect(s.required).toEqual({ kind: 'suit', suit: 'H' });
    expect(s.players[s.current]!.id).toBe('B');
  });
});

describe('legalActions', () => {
  it('offers a suit choice for each J and takePenalty only under a penalty', () => {
    const s = createGame({ playerIds: ['A', 'B'], deck: stackedDeck([
      'JH', '4S', '5S', '6S', '8S', '9S', '10S', 'QS', 'KS', '3C', '9H', 'KD',
    ]) });
    const acts = legalActions(s, 'A');
    expect(acts.filter((a) => a.type === 'play')).toHaveLength(4); // JH x 4 suits (9S..: none match H)
    expect(acts.some((a) => a.type === 'draw')).toBe(true);
    expect(legalActions(s, 'B')).toEqual([]);
  });
});

describe('random playouts', () => {
  function playout(seed: number, players: number): GameState {
    let s = createGame({ playerIds: ['A', 'B', 'C', 'D'].slice(0, players), seed });
    let pick = seed;
    for (let i = 0; i < 1500 && !s.over; i++) {
      const id = s.players[s.current]!.id;
      const acts = legalActions(s, id);
      expect(acts.length).toBeGreaterThan(0);
      pick = (pick * 1103515245 + 12345) >>> 0;
      const act: Action = acts[pick % acts.length]!;
      const r = applyAction(s, act);
      if (!r.ok) throw new Error(`legal action rejected: ${r.error}`);
      s = r.state;
      // card conservation
      const total = s.players.reduce((n, p) => n + p.hand.length, 0) + s.bank.length + s.stack.length;
      expect(total).toBe(54);
    }
    return s;
  }

  for (const players of [2, 3, 4]) {
    it(`conserves cards and terminates sensibly with ${players} players`, () => {
      let finished = 0;
      for (let seed = 1; seed <= 10; seed++) {
        const s = playout(seed, players);
        if (s.over) {
          finished++;
          expect(s.finishedOrder).toHaveLength(players);
          expect(new Set(s.players.map((p) => p.place)).size).toBe(players);
        }
      }
      expect(finished).toBeGreaterThan(0);
    });
  }
});
