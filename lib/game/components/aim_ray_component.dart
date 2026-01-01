import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/snapshots/entity_render_snapshot.dart';
import '../../core/snapshots/enums.dart';
import '../game_controller.dart';
import '../input/aim_preview.dart';

class AimRayComponent extends Component {
  AimRayComponent({
    required this.controller,
    required this.preview,
    required this.length,
  }) {
    _paint = Paint()
      ..color = const Color.fromARGB(255, 120, 165, 236)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
  }

  final GameController controller;
  final ValueListenable<AimPreviewState> preview;
  final double length;

  late final Paint _paint;

  @override
  void render(Canvas canvas) {
    final state = preview.value;
    if (!state.active) return;

    final player = _findPlayer(controller.snapshot.entities);
    if (player == null) return;

    final (dirX, dirY) = _resolveDir(state, player);
    final startX = player.pos.x;
    final startY = player.pos.y;
    final endX = startX + dirX * length;
    final endY = startY + dirY * length;

    canvas.drawLine(
      Offset(startX, startY),
      Offset(endX, endY),
      _paint,
    );
  }

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
