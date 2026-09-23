import 'dart:ui';

import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/trap_snapshot.dart';
import 'package:runner_core/traps/trap_definition.dart';

/// Shared game/editor warning appearance in world pixels, independent of Flame.
void paintTrapCue(
  Canvas canvas, {
  required TrapDefinition definition,
  required double x,
  required double y,
  required Facing facing,
  required TrapPhase phase,
}) {
  if (phase != TrapPhase.warning && phase != TrapPhase.active) return;
  final cue = facing == Facing.left
      ? definition.warningCue.mirrored()
      : definition.warningCue;
  final rect = Rect.fromLTWH(
    x + cue.offsetX,
    y + cue.offsetY,
    cue.width.toDouble(),
    cue.height.toDouble(),
  );
  final color = phase == TrapPhase.warning
      ? const Color(0xFFFFD447)
      : const Color(0xFFFF5148);
  canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.16));
  canvas.drawRect(
    rect.deflate(0.5),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  final center = Offset(rect.center.dx, rect.top + 8);
  canvas.drawCircle(center, 6, Paint()..color = const Color(0xFF25191A));
  final stroke = Paint()
    ..color = color
    ..strokeWidth = 2;
  canvas.drawLine(
    center + const Offset(0, -3),
    center + const Offset(0, 1),
    stroke,
  );
  canvas.drawCircle(center + const Offset(0, 3), 1, stroke);
}

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
