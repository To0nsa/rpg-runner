import 'dart:ui';

import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/traps/trap_definition.dart';

/// Read-only authored-frame collision preview; the editable trigger is separate.
void paintTrapDamagePose(
  Canvas canvas, {
  required TrapDefinition definition,
  required int frameIndex,
  required double x,
  required double y,
  required Facing facing,
}) {
  final hit = definition.frames[frameIndex].hitbox;
  if (hit == null) return;
  final sign = facing == Facing.left ? -1.0 : 1.0;
  final a = Offset(x + hit.ax * sign, y + hit.ay);
  final b = Offset(x + hit.bx * sign, y + hit.by);
  final paint = Paint()
    ..color = const Color(0x99FF5148)
    ..strokeWidth = hit.radius * 2
    ..strokeCap = StrokeCap.round;
  if (a == b) {
    canvas.drawCircle(a, hit.radius, paint);
  } else {
    canvas.drawLine(a, b, paint);
  }
}
