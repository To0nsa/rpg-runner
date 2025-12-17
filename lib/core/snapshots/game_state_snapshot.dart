// Immutable snapshot of the full game state needed by Render/UI.
//
// Built by the Core after each fixed simulation tick and treated as read-only
// by Flame/Flutter. This is the primary contract between Core and the rest of
// the app.
import 'entity_render_snapshot.dart';
import 'player_hud_snapshot.dart';

/// Snapshot of the current game state at a specific simulation tick.
class GameStateSnapshot {
  const GameStateSnapshot({
    required this.tick,
    required this.seed,
    required this.distance,
    required this.paused,
    required this.hud,
    required this.entities,
  });

  /// Current simulation tick.
  final int tick;

  /// Seed used for deterministic generation/RNG.
  final int seed;

  /// Distance progressed in the run (placeholder for V0).
  final double distance;

  /// Whether the simulation is currently paused.
  final bool paused;

  /// HUD-only player stats.
  final PlayerHudSnapshot hud;

  /// Render-only entity list for the current tick.
  final List<EntityRenderSnapshot> entities;
}
