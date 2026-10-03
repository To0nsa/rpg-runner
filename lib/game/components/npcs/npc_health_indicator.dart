import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';

/// Live allied health. Cleared guards retain a health bar and gain a check.
class NpcHealthIndicator extends PositionComponent {
  NpcHealthSnapshot? health;
  final _background = Paint()..color = const Color(0xE61B2638);
  final _fill = Paint()..color = const Color(0xFF65E3AE);
  final _safe = Paint()
    ..color = const Color(0xFFB9FFDA)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void render(Canvas canvas) {
    final value = health;
    if (value == null || value.hp100 <= 0 || value.maxHp100 <= 0) return;
    if (value.protected || value.guarding) {
      if (value.guarding) canvas.save();
      if (value.guarding) canvas.translate(0, -11);
      canvas.drawPath(
        Path()
          ..moveTo(-4, 1)
          ..lineTo(-1, 4)
          ..lineTo(5, -3),
        _safe,
      );
      if (value.guarding) canvas.restore();
      if (value.protected) return;
    }
    canvas.drawRect(const Rect.fromLTWH(-15, -1, 30, 6), _background);
    final ratio = (value.hp100 / value.maxHp100).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(-14, 0, 28 * ratio, 4), _fill);
    // The allied cross remains visible even when health is nearly empty.
    canvas.drawLine(const Offset(-20, 0), const Offset(-20, 4), _safe);
    canvas.drawLine(const Offset(-22, 2), const Offset(-18, 2), _safe);
  }
}
