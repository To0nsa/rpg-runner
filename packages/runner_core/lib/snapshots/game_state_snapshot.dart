/// Immutable snapshot of game state for rendering and UI.
///
/// Built by [GameCore] after each fixed simulation tick. This is the primary
/// contract between Core and the Flame/Flutter layer—treat as read-only.
library;

import '../levels/level_id.dart';
import 'camera_snapshot.dart';
import 'entity_render_snapshot.dart';
import 'enums.dart';
import 'player_hud_snapshot.dart';
import 'staged_terrain_render_snapshot.dart';
import 'static_prefab_sprite_snapshot.dart';

/// Complete game state snapshot at a specific simulation tick.
///
/// Contains everything the renderer and UI need: camera position, HUD data,
/// entity list, and static geometry.
class GameStateSnapshot {
  const GameStateSnapshot({
    required this.tick,
    required this.runId,
    required this.seed,
    required this.levelId,
    required this.visualThemeId,
    required this.distance,
    required this.paused,
    required this.gameOver,
    required this.camera,
    required this.hud,
    required this.entities,
    required this.staticPrefabSprites,
    this.stagedTerrainRenderSnapshot,
  });

  /// Current simulation tick.
  final int tick;

  /// Unique identifier for this run session.
  final int runId;

  /// Seed used for deterministic generation/RNG.
  final int seed;

  /// Level identifier for this run (stable across sessions).
  final LevelId levelId;

  /// Optional render theme identifier for this run.
  ///
  /// This is Core-owned metadata (pure data) that the renderer can map to
  /// asset paths and visuals without importing any Core gameplay logic.
  final String? visualThemeId;

  /// Distance progressed in the run.
  final double distance;

  /// Whether the simulation is currently paused.
  final bool paused;

  /// Whether the run has ended (simulation is frozen).
  final bool gameOver;

  /// Camera snapshot used for rendering this frame.
  final CameraSnapshot camera;

  /// HUD-only player stats.
  final PlayerHudSnapshot hud;

  /// Render-only entity list for the current tick.
  final List<EntityRenderSnapshot> entities;

  /// Render-only authored prefab visual sprites for static streamed chunks.
  final List<StaticPrefabSpriteSnapshot> staticPrefabSprites;

  /// Compiler-owned terrain fill data published with the active terrain bundle.
  ///
  /// Normal streaming publishes it from the complete staged candidate selected
  /// by the scheduler. A terrain harness sets it only when a complete staged
  /// collision/navigation/render publication has crossed a tick boundary.
  final StagedTerrainRenderSnapshot? stagedTerrainRenderSnapshot;

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
