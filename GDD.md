# J-Command Cards — Game Design Document

Status: Draft v0.2 (rules confirmed with the designer; items in section 14 still need confirmation)

## 1. Overview

| | |
|---|---|
| Genre | Card shedding game (Crazy Eights / Uno / Jacaré family) |
| Players | 2–4 in the UI (the engine supports up to 10) |
| Platforms | Mobile and tablet first (Godot), web later |
| Modes | Offline vs AI bots, online private room (join code), online random matchmaking |
| Art | Placeholder vector cards for now |
| Goal | Be the first to play every card in your hand |

**Pillars**
1. **Fast, readable turns.** The player always knows what is legal and what is pending.
2. **Penalty chains are the drama.** 7s and Lions build tension.
3. **Hidden hands.** Each player's cards are private, so there is no shared-device play.

## 2. Components

- **Deck:** 54 cards = 52 standard cards (♥ ♦ ♣ ♠, A 2–10 J Q K) + 2 Lions (1 red, 1 black).
- **Colors:** ♥ and ♦ are red; ♣ and ♠ are black.
- **Bank:** the face-down draw pile.
- **Stack:** the face-up discard pile. Its top card is the "floor card".

## 3. Setup

1. Shuffle the 54 cards.
2. Deal 5 cards to each player.
3. Flip one card to start the stack. The rest is the bank.
4. Apply the **starting card rule**:

| Flipped card | Result |
|---|---|
| 7 or Lion | Goes to the bottom of the bank. Flip another card (repeat if needed). |
| J | The first player chooses the required suit. |
| Ace (Stop) | The first player is skipped. The second player plays first. |
| 2 | Treated as free. The first player may play any suit. |
| Other | Normal. The first player must match its suit. |

Play order is clockwise.

## 4. Core State

The engine tracks these values:

- `required`: one of `{ suit: S }`, `{ color: C }`, or `free`
  - Normally this is the suit of the floor card.
  - A J sets it to the chosen suit.
  - A Lion sets it to the Lion's color.
  - The starting 2 sets it to `free`.
- `pendingPenalty`: an integer (0, 2, 4, 6, …), the accumulated draw penalty.
- `floorCard`: the top card of the stack. Slid 2s do not change it.

## 5. Turn

On your turn you do exactly one of these:

1. **Play** a legal card (section 6).
2. **Draw 1** card from the bank, voluntarily. This is your whole turn. You cannot play the drawn card until your next turn. Not allowed while a penalty is pending.
3. **Take the penalty**, if `pendingPenalty > 0` and you have no 7 or Lion to play, or you choose not to play one. You draw the whole penalty, and that is your whole turn. Play then continues with the next player.

You may draw voluntarily even if you hold a playable card.

## 6. Card Rules

### 6.1 Normal card (3–6, 8–10, Q, K)
Legal if its suit matches `required`. If `required` is a color, any suit of that color is legal. If `required` is `free`, any card is legal. Afterwards `required` becomes the played card's suit.

**Rank match ("passive J"):** a card can also be played on a card of the **same rank**, whatever the suit. The played card's suit becomes the new `required` suit. Example: 5♥ on 5♦, and the required suit is now ♥. This applies to every numbered or lettered card, including 7 (7♦ on 7♥ still adds its +2 penalty) and Ace. Lions count as a rank of their own, so a Lion can be played on a Lion floor card whatever its color (see 6.3). Rank matching is not allowed while a penalty is pending. Setting `matchRank` (default `true`) turns it off.

### 6.2 Seven (7)
- **Normal situation:** it must match `required`. It adds +2 to `pendingPenalty`.
- **Penalty pending:** it can be played on top of a pending penalty regardless of suit.
- After a penalty is taken, the next player must match the suit of the last 7.

### 6.3 Lion (red or black)
- **Normal situation:** a red Lion is legal when the required suit or color is red. A black Lion is legal when it is black. It adds +4 to `pendingPenalty`.
- **Penalty pending:** it can be played on top of a pending penalty regardless of color.
- After a penalty is taken, the next player must play a card of the Lion's color (either suit).
- With `required = free`, any Lion is legal.
- **Lion on 7:** a Lion can be played on a 7 that is the floor card, whatever its color (mirror of 7 on Lion).
- **Lion on Lion:** a Lion can be played on a Lion that is the floor card, whatever its color. Example: A plays the red Lion, B cannot block and draws 4, and C may now play the black Lion on it. The played Lion's color becomes the required color, and its +4 applies.

### 6.4 Penalty chain
- Penalties stack: 7 → +2, Lion → +4. 7 + 7 = 4, 7 + Lion = 6, and so on.
- The target must play a 7 or a Lion, which passes the total to the next player. Otherwise they draw the total from the bank.
- **A 2 cannot block a penalty.**
- The player who draws the penalty loses their turn, and the next player plays normally. That player must follow the `required` rule set by the last penalty card.

### 6.5 Two (2) — "Goes everywhere"
- Legal on any floor card, any `required`. It cannot be played while a penalty is pending.
- It is slid under the stack. `floorCard` and `required` do not change.

### 6.6 Jack (J)
- The first J must match `required`. A J is always legal on top of another J of any suit.
- The player chooses the new `required` suit, which can be the same one.
- It cannot be played while a penalty is pending.

### 6.7 Ace — "Stop"
- The first Ace must match `required`. An Ace is legal on top of another Ace of any suit.
- The next player is skipped.
- **Ace on Ace:** A plays an Ace, B is skipped, C plays an Ace, D is skipped.
- **2 players:** the opponent is skipped, so you play again.
- It cannot be played while a penalty is pending.

### 6.8 Penalty-pending legal moves

| Pending penalty | Legal plays | Otherwise |
|---|---|---|
| Yes | 7, Lion | Draw the whole penalty |
| No | Per card rules above, or draw 1 | n/a |

## 7. Bank Exhaustion

When the bank cannot supply a draw:
1. Keep the floor card on the stack.
2. Turn the rest of the stack over to become the bank in LIFO order (no shuffle).
3. Continue. If the bank is still insufficient, the player draws what is available.

Slid 2s sit at the bottom of the stack, so they come out first.

**Setting** `reshuffleOnRefill` (default `false`): when `true`, the recycled pile is shuffled.

## 8. Winning

**Finishing:** you win a place when you play your last card, subject to the rules below.

### 8.1 Two players (1v1)
- **Last card is an Ace:** it cannot finish the game. You must draw 1 card from the bank and keep playing. (A Stop would skip the opponent and make you play again with an empty hand.)
- **Last card is a 7 or Lion:** the game ends only if the opponent cannot block with a 7 or Lion. If they block, the chain comes back, and you must draw the total and continue.
- **Any other last card** (including 2 and J): you win immediately.

### 8.2 Three or four players
- A player who finishes leaves the rotation. First finisher is 1st place, and so on.
- **Last card is an Ace:** allowed. The skip still applies.
- **Last card is a 7 or Lion:** the penalty passes on as normal.
  - If the next player blocks, the chain continues.
  - Whoever ends up unable to block draws the total.
  - **Edge case:** if every other player's last cards are all penalty cards and the chain ends on the last remaining player, that player draws and loses. The game ends.
- The game continues until one player remains. That player is last place.

### 8.3 Scoring and leaderboard (offline)
- **Base points:** 1st = 1000, then evenly down to 0 for last (3 players: 1000/500/0).
- **Clean Finish:** finishing (any place but last) without ever drawing from the bank = **+3000**. Forced penalty draws do not break it; a draw on an empty bank does not count.
- **Otherwise:** up to +200 for few voluntary draws (-50 per draw).
- **Multiplier:** x1.0 / 1.5 / 2.0 for 1 / 2 / 3 bots, x0.6 on Easy.
- Scores are stored on the device (`user://leaderboard.cfg`, top 20, last place scores 0 and is not listed). Menu > Leaderboard shows them. Code: `scripts/game/scoring.gd`, `leaderboard.gd`.

## 9. Settings (per-room / per-game)

| Setting | Default | Notes |
|---|---|---|
| `playerCount` | 4 | 2–4 in the UI, engine allows up to 10 |
| `handSize` | 5 | |
| `reshuffleOnRefill` | `false` | |
| `matchRank` | `true` | Same-rank cards can be played on each other (section 6.1). Bot simulation: with it, a 1v1 game averages about 43 turns instead of about 270. |
| `botDifficulty` | `normal` | Offline mode only |
| `turnTimer` | 30 s | Online only; on timeout, auto-draw 1 (or take the penalty) |

## 10. Platforms and Modes

- **Offline vs AI bots (Godot, no network):** 1 human, 1–3 bots, 3 difficulties (random-legal, heuristic, lookahead).
- **Online private room:** the host creates a room and shares a join code. Friends join with the code.
- **Online random matchmaking:** queue by player count (2, 3 or 4).
- **Identity:** anonymous guest identity with a nickname (device-bound token). Accounts are out of scope for v1.
- **No same-device multiplayer:** hands are secret.
- **Web:** later, as a Godot web export or a separate client reusing the same server and engine.

## 11. UX

- Portrait phone and landscape tablet layouts.
- The player's hand is a fanned row at the bottom. Illegal cards are dimmed. Tap to select, tap again or drag to play.
- The bank and stack are in the middle.
- **Indicators:**
  - the required suit or color (a large icon),
  - the pending penalty counter (for example "+6"),
  - whose turn it is, with a timer online,
  - opponent card counts.
- **Prompts:** a suit picker after playing a J.
- **Card movement:** every card visibly travels. The deal flies from the bank to each seat, the starting card flips onto the stack, played cards fly from the hand (or the opponent's seat, turning face-up mid-flight) to the stack, and draws and penalty cards fly from the bank to the drawer. A 2 slides under the stack.
- **Last-played preview:** each seat shows the last card that player played. A gold border and "ON TOP" mark the one currently on top of the stack. A caption under the stack says who played it, and your own last play is shown beside the bank.
- **Avatars:** every player has a placeholder vector portrait (you plus the bots Rex, Luna and Zed). Bots show theirs on their seat, and yours sits beside your hand. A gold ring marks whose turn it is.
- **Results podium:** when the game ends, a podium rises with 1st in the middle (crowned), 2nd on the left and 3rd on the right, each with the player's avatar and name. 4th place gets a small row below. If you finished 1st, confetti falls.
- **Check:** when a player plays down to exactly one card, everyone must notice, but calmly (no shake, no full-screen flash, no blinking). A short "CHECK!" with "<Name> has ONE card left!" shows in the band between the table and your hand for about 1.4 s, with one ring from that player's seat and a soft red vignette at the screen edges. While the player keeps one card, their seat has a steady red border and a CHECK! badge, with only a slow glow. If it is you, your avatar gets a gold glow and badge and the banner reads "CHECK! Play your last card to win". There is deliberately no banner listing who is in check, because with three of four players in check it would overwhelm the screen. A re-fire within 10 s gets only the ring. It clears as soon as the hand is no longer exactly one card.
- **Sound:** all effects are synthesised in code (no audio assets yet): a soft slap when a card lands, ticks for dealing and drawing, a swish for a 2 sliding under, a thump for a 7, a growl for a Lion, two sinking notes for a penalty, two beeps for Stop, a gentle two-note chime for Check (it still plays on a quick re-fire), a small ping when it becomes your turn, a short blip for an illegal tap, and a rising arpeggio (win) or falling notes (lose) on the podium.
- **Settings (menu and in-game):** sound on/off, volume (10% steps), and **Reduce motion**. Settings are saved on the device. Reduce motion turns off the shake, vignette and flash, rings, sparks, confetti, seat and avatar pulsing, card trails, pops and bounces, and the pile lift when a 2 slides under. Cards still move, and every message and badge still shows.
- **Feedback:** drawn cards animate from the bank to the hand. A skipped player shows a "Stop" banner.
- **Art:** placeholder vector cards. Suit and rank are drawn procedurally in Godot. Lions are a red or black paw/crown icon.

## 12. Technical Architecture

### 12.1 Monorepo layout

```
jcommand-cards-game/
  packages/
    rules-spec/    # card + effect definitions (JSON), settings schema, scenario test vectors
    engine/        # TypeScript rules engine (source of truth)
  apps/
    server/        # TypeScript: WebSocket game server, rooms, matchmaking
    mobile/        # Godot project: UI, bots, GDScript engine port
    web/           # later
  tools/
    conformance/   # runs the same scenarios against TS and GDScript engines
  GDD.md
```

### 12.2 Rules engine
- Pure, deterministic and serialisable: `applyAction(state, action) -> state | error`, with a seeded RNG for reproducibility.
- `legalActions(state, playerId)` drives both UI dimming and bot choices.
- **Actions:** `play(card, chosenSuit?)`, `draw`, `takePenalty`.

### 12.3 Shared rules between TypeScript and GDScript
The engine is written twice (TypeScript and a GDScript port) because offline play needs the rules in Godot. They are kept in sync with two shared artefacts in `packages/rules-spec`:
1. **Declarative rule data (the "middle language"):** a JSON file describing card definitions and effects. Examples of effect types: `drawPenalty(n)`, `skipNext`, `universalPlay`, `chooseSuit`, `chainOnAny`. Both engines read the same file for card behaviour.
2. **Golden scenarios:** JSON files of `{initialState, actions[], expectedStates/errors}`. A conformance tool runs every scenario against both engines in CI. A mismatch fails the build.

A full rule DSL with two interpreters was considered. It is overkill for this ruleset, but the effect vocabulary in (1) can later be used to generate parts of the GDScript.

### 12.4 Server
- Authoritative: clients send intents, the server validates them with the engine and broadcasts state.
- **Hidden information:** each client receives only its own hand plus opponent card counts.
- WebSocket protocol. Reconnection by token. Bots can fill in for disconnected players.
- Matchmaking queue keyed by player count. Private rooms use short join codes.

### 12.5 Client (Godot)
- The client renders state and sends intents.
- In offline mode the client runs the GDScript engine locally and the bots act as local players.

## 13. Milestones

1. **M1: Engine and spec.** Rules JSON, TS engine, scenario suite covering every rule in this document.
2. **M2: Godot offline.** GDScript port, passes the conformance suite, placeholder UI, bots.
3. **M3: Server.** Rooms, join codes, matchmaking, reconnection.
4. **M4: Online client.** Godot network layer, lobby screens.
5. **M5: Polish.** Animations, sound, tuning, store builds. Web later.

## 14. Decisions and Open Items

**Confirmed by the designer**
1. **Provisional finish on a penalty card with 3+ players.** A player who finishes on a 7 or Lion is only confirmed finished once the penalty lands on someone else. If the chain comes all the way back to them, they draw it and are back in the game, as in 1v1.
2. **No voluntary draw in a penalty chain.** You can only play a 7 or Lion, or take the whole penalty.
3. **Ranking by finish order.** First finisher is 1st place, and so on.
4. **Online turn timer** is 30 s. On timeout the player auto-draws 1, or takes the penalty if one is pending.

**Design finding: information, not card choice, is the skill lever.** Simulations (`apps/mobile/scripts/tests/`) show that with the current rules a player has no playable card on about 35% of turns, exactly one on about 33%, and a real choice (2+ cards) on only about 32%. A "hard" bot that counts every card already played, remembers suits players could not match, models the next player and plans its last cards won only 47-51% against the normal bot in 400-game 1v1 matches, whatever its weights, so it is not offered. The same bot given the opponent's real hand won 62-63% (251/400, noise about 2.5 points), so exact knowledge of the opponent's hand is worth about 12-13 points, but remembering played cards cannot supply it (the opponent's 5 cards are a small sample of about 35 unseen cards). After a bank refill the bank order is fully known (no reshuffle), but that happens in only 11% of 1v1 games, 32% of 3-player and 62% of 4-player games, and late. The normal bot beats the random-ish easy bot only about 58-65% of the time. To raise skill without cheating, the rules need more decisions (for example, being allowed to play the card you just drew, or drawing until you can play); a bot that peeks at hands would be an openly labelled option.

**Still open (defaults in effect)**
- A slid 2 leaves no trace, so nothing special applies to it.
- Bot names and avatars are placeholders.
