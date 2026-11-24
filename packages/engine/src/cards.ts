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
  for (const color of spec.deck.jokers as Color[]) {
    cards.push({ id: id++, rank: 'JOKER', color });
  }
  return cards;
}

/** "7H", "10S", "AD", "JR" (red joker), "JB" (black joker). */
export function cardCode(card: Card): string {
  if (card.rank === 'JOKER') return card.color === 'red' ? 'JR' : 'JB';
  return `${card.rank}${card.suit}`;
}

export function parseCard(code: string, id: number): Card {
  if (code === 'JR') return { id, rank: 'JOKER', color: 'red' };
  if (code === 'JB') return { id, rank: 'JOKER', color: 'black' };
  const suit = code.slice(-1) as Suit;
  const rank = code.slice(0, -1) as Rank;
  if (!SUITS.includes(suit) || !(spec.deck.ranks as string[]).includes(rank)) {
    throw new Error(`Bad card code: ${code}`);
  }
  return { id, rank, suit, color: suitColor(suit) };
}
