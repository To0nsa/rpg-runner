import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/snapshots/entity_render_snapshot.dart';
import '../../core/snapshots/enums.dart';
import '../game_controller.dart';
import '../input/aim_preview.dart';

/// Renders a directional ray from the player to indicate aiming direction.
///
/// This component listens to [AimPreviewModel] (exposed as a ValueListenable)
/// and draws a line when aiming is active. It correctly handles:
/// - **Interpolation**: Smooths the ray origin between simulation ticks to match sprite movement.
/// - **Default Direction**: Optionally defaults to the player's facing direction if no aim is active.
/// - **Performance**: Caches the player entity ID to minimize search overhead.
class AimRayComponent extends Component {
  AimRayComponent({
    required this.controller,
    required this.preview,
    required this.length,
    Paint? paint,
    this.drawWhenNoAim = true,
  }) : _paint =
           paint ??
           (Paint()
             ..color = const Color.fromARGB(255, 120, 165, 236)
             ..strokeWidth = 2
             ..strokeCap = StrokeCap.round);

  /// Controller source for game state (snapshots) and interpolation alpha.
  final GameController controller;

  /// Reactive source of aim state (active, direction, etc.).
  final ValueListenable<AimPreviewState> preview;

  /// Length of the ray in world units (pixels).
  final double length;

  /// Whether to draw the ray (using facing direction) even when the user hasn't
  /// dragged far enough to establish a specific aim vector.
  final bool drawWhenNoAim;

  final Paint _paint;

  /// Cached ID of the player entity to avoid O(N) lookup every frame.
  int? _cachedPlayerId;

  @override
  void render(Canvas canvas) {
    final state = preview.value;
    if (!state.active) return;
    if (!state.hasAim && !drawWhenNoAim) return;

    // Use current snapshot to find/validate player exists.
    final currentEntities = controller.snapshot.entities;
    var player = _findPlayer(currentEntities);
    if (player == null) {
      // Invalidate cache if player not found (e.g. died/despawned).
      _cachedPlayerId = null;
      return;
    }

    // Attempt to interpolate position for smooth rendering.
    double startX = player.pos.x;
    double startY = player.pos.y;

    // If we have a previous snapshot and the player existed there too, interpolate.
    if (_cachedPlayerId != null) {
      final prevPlayer = _findEntityById(
        controller.prevSnapshot.entities,
        _cachedPlayerId!,
      );
      if (prevPlayer != null) {
        final alpha = controller.alpha;
        startX = prevPlayer.pos.x * (1 - alpha) + player.pos.x * alpha;
        startY = prevPlayer.pos.y * (1 - alpha) + player.pos.y * alpha;
      }
    }

    final (dirX, dirY) = _resolveDir(state, player);
    final endX = startX + dirX * length;
    final endY = startY + dirY * length;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), _paint);
  }

  /// returns the aim direction vector (normalized).
  ///
  /// If aim is set, returns that. Otherwise, falls back to player facing.
  (double, double) _resolveDir(
    AimPreviewState state,
    EntityRenderSnapshot player,
  ) {
    if (state.hasAim) {
      return (state.dirX, state.dirY);
    }
    final facing = player.facing;
    return (facing == Facing.right ? 1.0 : -1.0, 0.0);
  }

  EntityRenderSnapshot? _findEntityById(
    List<EntityRenderSnapshot> entities,
    int id,
  ) {
    for (final e in entities) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Locates the player entity, using the cached ID for O(1) expected time.
  EntityRenderSnapshot? _findPlayer(List<EntityRenderSnapshot> entities) {
    // Fast path: check cached ID first.
    if (_cachedPlayerId != null) {
      final cached = _findEntityById(entities, _cachedPlayerId!);
      // Ensure it's still the player (ids shouldn't be reused immediately, but safe check).
      if (cached != null && cached.kind == EntityKind.player) {
        return cached;
      }
    }

    // Slow path: linear search.
    for (final e in entities) {
      if (e.kind == EntityKind.player) {
        _cachedPlayerId = e.id;
        return e;
      }
    }
    return null;
  }
}
