import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/contracts/v0_render_contract.dart';
import '../../core/math/vec2.dart';
import '../../core/snapshots/game_state_snapshot.dart';
import '../viewport/viewport_metrics.dart';

/// Helper for mapping local pointer positions into V0 world-space aim direction.
///
/// Uses the shared viewport metrics so input matches the rendered view.
class V0ViewportMapper {
  V0ViewportMapper({required this.metrics});

  final ViewportMetrics metrics;

  Vec2? aimDirFromLocal(Offset localPos, GameStateSnapshot snapshot) {
    if (metrics.viewW <= 0 || metrics.viewH <= 0) return null;

    final inViewportX = localPos.dx - metrics.offsetX;
    final inViewportY = localPos.dy - metrics.offsetY;
    if (inViewportX < 0 ||
        inViewportY < 0 ||
        inViewportX > metrics.viewW ||
        inViewportY > metrics.viewH) {
      return null;
    }

    if (snapshot.entities.isEmpty) return null;
    final player = snapshot.entities.first;

    final vx = (inViewportX / metrics.viewW) * v0VirtualWidth;
    final vy = (inViewportY / metrics.viewH) * v0VirtualHeight;

    final camCenterX = player.pos.x.roundToDouble();
    final camCenterY = v0CameraFixedY.roundToDouble();

    final worldX = camCenterX - (v0VirtualWidth / 2) + vx;
    final worldY = camCenterY - (v0VirtualHeight / 2) + vy;

    final dx = worldX - player.pos.x;
    final dy = worldY - player.pos.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len <= 1e-9) return const Vec2(0, 0);
    return Vec2(dx / len, dy / len);
  }
}
