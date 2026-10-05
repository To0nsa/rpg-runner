import 'dart:ui';

import 'package:flame/components.dart';
import 'package:runner_core/combat/combat_geometry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';

import '../util/math_util.dart' as math;

/// Draws the exact Core capsules, including their rounded ends and orientation.
final class CombatCapsuleOverlay extends PositionComponent {
  CombatCapsuleOverlay({required this.paint});
  final Paint paint;
  List<CombatCapsule> capsules = const [];

  @override
  void render(Canvas canvas) {
    for (final c in capsules) {
      canvas.save();
      canvas.translate(c.ax, c.ay);
      final delta = Offset(c.bx - c.ax, c.by - c.ay);
      canvas.rotate(delta.direction);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            -c.radius,
            -c.radius,
            delta.distance + c.radius,
            c.radius,
          ),
          Radius.circular(c.radius),
        ),
        paint,
      );
      canvas.restore();
    }
  }
}

void syncCombatCapsuleOverlays({
  required Iterable<EntityRenderSnapshot> entities,
  required bool enabled,
  required Component parent,
  required Map<int, CombatCapsuleOverlay> pool,
  required int priority,
  required Paint paint,
  required Map<int, EntityRenderSnapshot> prevById,
  required double alpha,
  required Vector2 cameraCenter,
  bool Function(EntityRenderSnapshot)? include,
}) {
  final seen = <int>{};
  if (enabled) {
    for (final e in entities) {
      if ((include != null && !include(e)) || e.combatCapsules.isEmpty) {
        continue;
      }
      seen.add(e.id);
      final view = pool.putIfAbsent(e.id, () {
        final value = CombatCapsuleOverlay(paint: paint)..priority = priority;
        parent.add(value);
        return value;
      });
      view.capsules = e.combatCapsules;
      final prev = prevById[e.id] ?? e;
      view.position.setValues(
        math.snapWorldToPixelsInCameraSpace1d(
          math.lerpDouble(prev.pos.x, e.pos.x, alpha),
          cameraCenter.x,
        ),
        math.snapWorldToPixelsInCameraSpace1d(
          math.lerpDouble(prev.pos.y, e.pos.y, alpha),
          cameraCenter.y,
        ),
      );
    }
  }
  for (final id in pool.keys.where((id) => !seen.contains(id)).toList()) {
    pool.remove(id)?.removeFromParent();
  }
}
