import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/contracts/v0_render_contract.dart';
import '../../core/math/vec2.dart';
import '../../core/snapshots/game_state_snapshot.dart';

/// Helper for mapping local pointer positions into V0 world-space aim direction.
///
/// This follows the pixel-perfect viewport rules (integer physical-pixel scale
/// + letterbox) so aim lines up with what the player sees.
class V0ViewportMapper {
  V0ViewportMapper._({
    required this.viewW,
    required this.viewH,
    required this.offsetX,
    required this.offsetY,
  });

  factory V0ViewportMapper.fromConstraints(
    BoxConstraints constraints, {
    required double devicePixelRatio,
  }) {
    final screenPxW = constraints.maxWidth * devicePixelRatio;
    final screenPxH = constraints.maxHeight * devicePixelRatio;
    final scaleW = (screenPxW / v0VirtualWidth).floor();
    final scaleH = (screenPxH / v0VirtualHeight).floor();
    final scale = math.max(1, math.min(scaleW, scaleH));

    final viewW = (v0VirtualWidth * scale) / devicePixelRatio;
    final viewH = (v0VirtualHeight * scale) / devicePixelRatio;
    final offsetX = (constraints.maxWidth - viewW) / 2;
    final offsetY = (constraints.maxHeight - viewH) / 2;

    return V0ViewportMapper._(
      viewW: viewW,
      viewH: viewH,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  final double viewW;
  final double viewH;
  final double offsetX;
  final double offsetY;

  Vec2? aimDirFromLocal(Offset localPos, GameStateSnapshot snapshot) {
    final inViewportX = localPos.dx - offsetX;
    final inViewportY = localPos.dy - offsetY;
    if (inViewportX < 0 ||
        inViewportY < 0 ||
        inViewportX > viewW ||
        inViewportY > viewH) {
      return null;
    }

    if (snapshot.entities.isEmpty) return null;
    final player = snapshot.entities.first;

    final vx = (inViewportX / viewW) * v0VirtualWidth;
    final vy = (inViewportY / viewH) * v0VirtualHeight;

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

