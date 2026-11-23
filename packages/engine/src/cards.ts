import type { Card, Color, Rank, Suit } from './types';
import { spec } from './rules';

export const SUITS: Suit[] = ['H', 'D', 'C', 'S'];

export function suitColor(suit: Suit): Color {
  return suit === 'H' || suit === 'D' ? 'red' : 'black';
}

export function createDeck(): Card[] {
  const cards: Card[] = [];
  let id = 0;
  for (const suit of spec.deck.suits as Suit[]) {
    for (const rank of spec.deck.ranks as Rank[]) {
      cards.push({ id: id++, rank, suit, color: suitColor(suit) });
    }
  }
  for (const color of spec.deck.lions as Color[]) {
    cards.push({ id: id++, rank: 'LION', color });
  }
  return cards;
}

/** "7H", "10S", "AD", "LR" (red lion), "LB" (black lion). */
export function cardCode(card: Card): string {
  if (card.rank === 'LION') return card.color === 'red' ? 'LR' : 'LB';
  return `${card.rank}${card.suit}`;
}

export function parseCard(code: string, id: number): Card {
  if (code === 'LR') return { id, rank: 'LION', color: 'red' };
  if (code === 'LB') return { id, rank: 'LION', color: 'black' };
  const suit = code.slice(-1) as Suit;
  const rank = code.slice(0, -1) as Rank;
  if (!SUITS.includes(suit) || !(spec.deck.ranks as string[]).includes(rank)) {
    throw new Error(`Bad card code: ${code}`);
  }
  return { id, rank, suit, color: suitColor(suit) };
}
