import { createGame, legalActions } from '@jcommand/engine';

// Placeholder: WebSocket rooms + matchmaking come in milestone M3.
const game = createGame({ playerIds: ['A', 'B'], seed: 1 });
console.log('engine wired; first player legal actions:', legalActions(game, game.players[game.current]!.id).length);
