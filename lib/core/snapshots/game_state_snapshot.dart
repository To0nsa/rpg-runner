/// Immutable snapshot of game state for rendering and UI.
///
/// Built by [GameCore] after each fixed simulation tick. This is the primary
/// contract between Core and the Flame/Flutter layer—treat as read-only.
library;

import '../levels/level_id.dart';
import 'entity_render_snapshot.dart';
import 'enums.dart';
import 'player_hud_snapshot.dart';
import 'static_ground_gap_snapshot.dart';
import 'static_solid_snapshot.dart';

/// Complete game state snapshot at a specific simulation tick.
///
/// Contains everything the renderer and UI need: camera position, HUD data,
/// entity list, and static geometry.
class GameStateSnapshot {
  const GameStateSnapshot({
    required this.tick,
    required this.seed,
    required this.levelId,
    required this.themeId,
    required this.distance,
    required this.paused,
    required this.gameOver,
    required this.cameraCenterX,
    required this.cameraCenterY,
    required this.hud,
    required this.entities,
    required this.staticSolids,
    required this.groundGaps,
  });

  /// Current simulation tick.
  final int tick;

  /// Seed used for deterministic generation/RNG.
  final int seed;

  /// Level identifier for this run (stable across sessions).
  final LevelId levelId;

  /// Optional render theme identifier for this run.
  ///
  /// This is Core-owned metadata (pure data) that the renderer can map to
  /// asset paths and visuals without importing any Core gameplay logic.
  final String? themeId;

  /// Distance progressed in the run (placeholder for V0).
  final double distance;

  /// Whether the simulation is currently paused.
  final bool paused;

  /// Whether the run has ended (simulation is frozen).
  final bool gameOver;

  /// Camera center used for rendering this snapshot.
  final double cameraCenterX;
  final double cameraCenterY;

  /// HUD-only player stats.
  final PlayerHudSnapshot hud;

  /// Render-only entity list for the current tick.
  final List<EntityRenderSnapshot> entities;

  /// Render-only static collision geometry (platforms/obstacles) for this run.
  final List<StaticSolidSnapshot> staticSolids;

  /// Render-only ground gaps (holes in the ground band).
  final List<StaticGroundGapSnapshot> groundGaps;

  /// Returns the player entity snapshot, or `null` if not found.
  ///
  /// Convenience getter to avoid duplicating player-lookup logic across
  /// rendering components.
  EntityRenderSnapshot? get playerEntity {
    for (final e in entities) {
      if (e.kind == EntityKind.player) return e;
    }
    return null;
  }
}
