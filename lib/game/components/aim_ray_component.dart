import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/snapshots/entity_render_snapshot.dart';
import '../../core/snapshots/enums.dart';
import '../game_controller.dart';
import '../input/aim_preview.dart';

/// Renders a visual "aim ray" or laser sight extending from the player.
///
/// Reacts to [AimPreviewState] to show the player where their projectile
/// or ability will land.
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

  /// Provides access to the game state (player position).
  final GameController controller;

  /// Reactive state for the current aim direction/status.
  final ValueListenable<AimPreviewState> preview;

  /// Length of the ray in world units (pixels).
  final double length;

  /// Whether to draw a "straight ahead" ray even when the player hasn't
  /// explicitly dragged to aim (fallback to player facing).
  final bool drawWhenNoAim;

  final Paint _paint;

  @override
  void render(Canvas canvas) {
    final state = preview.value;
    if (!state.active) return;
    if (!state.hasAim && !drawWhenNoAim) return;

    final player = _findPlayer(controller.snapshot.entities);
    if (player == null) return;

    final (dirX, dirY) = _resolveDir(state, player);
    final startX = player.pos.x;
    final startY = player.pos.y;
    final endX = startX + dirX * length;
    final endY = startY + dirY * length;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), _paint);
  }

  /// Determines the ray direction.
  ///
  /// Uses the explicit aim if available; otherwise falls back to the player's
  /// current facing direction.
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

  EntityRenderSnapshot? _findPlayer(List<EntityRenderSnapshot> entities) {
    for (final e in entities) {
      if (e.kind == EntityKind.player) return e;
    }
    return null;
  }
}
