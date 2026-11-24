export type Suit = 'H' | 'D' | 'C' | 'S';
export type Color = 'red' | 'black';
export type Rank =
  | 'A' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | '10' | 'J' | 'Q' | 'K'
  | 'LION';

export interface Card {
  id: number;
  rank: Rank;
  /** Absent for Lions. */
  suit?: Suit;
  color: Color;
}

export type Required =
  | { kind: 'free' }
  | { kind: 'suit'; suit: Suit }
  | { kind: 'color'; color: Color };

/**
 * playing     - still in the game
 * provisional - emptied their hand with a penalty card; confirmed out only once
 *               the penalty lands on someone else
 * finished    - confirmed out (has a place)
 */
export type PlayerStatus = 'playing' | 'provisional' | 'finished';

export interface Player {
  id: string;
  hand: Card[];
  status: PlayerStatus;
  place: number | null;
}

export interface Settings {
  handSize: number;
  reshuffleOnRefill: boolean;
  /** A card may also be played on a card of the same rank (new suit = the played card's suit). */
  matchRank: boolean;
}

export interface GameState {
  players: Player[];
  /** Last element is the top (next card drawn). */
  bank: Card[];
  /** Last element is the top / floor card. Slid-under 2s sit at index 0. */
  stack: Card[];
  required: Required;
  pending: number;
  /** Index into players. */
  current: number;
  settings: Settings;
  rngState: number;
  finishedOrder: string[];
  provisionalOrder: string[];
  over: boolean;
  loser: string | null;
}

export type Action =
  | { type: 'play'; playerId: string; cardId: number; chosenSuit?: Suit }
  | { type: 'draw'; playerId: string }
  | { type: 'takePenalty'; playerId: string };

export type GameEvent =
  | { type: 'play'; playerId: string; card: Card; chosenSuit?: Suit }
  | { type: 'draw'; playerId: string; count: number }
  | { type: 'penaltyTaken'; playerId: string; count: number }
  | { type: 'skip'; playerId: string }
  | { type: 'refill'; reshuffled: boolean }
  | { type: 'provisionalFinish'; playerId: string }
  | { type: 'finish'; playerId: string; place: number }
  | { type: 'gameOver'; loser: string | null };

export type Result =
  | { ok: true; state: GameState; events: GameEvent[] }
  | { ok: false; error: string };

export type PlayOn = 'required' | 'any' | 'requiredOrSameRank';
export type Sets = 'suit' | 'color' | 'chosen' | 'none';

export interface RuleDef {
  playOn: PlayOn;
  sets: Sets;
  penalty?: number;
  /** Playable on any Lion regardless of the required colour. */
  playOnLion?: boolean;
  /** Playable on any 7 regardless of the required colour. */
  playOnSeven?: boolean;
  slideUnder?: boolean;
  /** Default true. Lions have no number, so they never rank-match. */
  matchRank?: boolean;
  skipNext?: number;
  cannotFinishWhenTwoPlayersLeft?: boolean;
  onStart?: 'redeal' | 'free' | 'skipFirst';
}
