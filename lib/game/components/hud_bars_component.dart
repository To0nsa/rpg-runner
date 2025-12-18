import 'dart:ui';

import 'package:flame/components.dart';

import '../game_controller.dart';

class HudBarsComponent extends PositionComponent {
  HudBarsComponent({
    required GameController controller,
    this.barWidth = 140,
    this.barHeight = 6,
    this.barGap = 4,
    super.position,
    super.anchor,
  }) : _controller = controller;

  final GameController _controller;

  final double barWidth;
  final double barHeight;
  final double barGap;

  final Paint _back = Paint()..color = const Color(0xAA000000);
  final Paint _outline = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  final Paint _hp = Paint()..color = const Color(0xFFDC4440);
  final Paint _mana = Paint()..color = const Color(0xFF2D98DA);
  final Paint _stamina = Paint()..color = const Color(0xFF4CD137);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final hud = _controller.snapshot.hud;

    _drawBar(
      canvas,
      y: 0,
      value: hud.hp,
      max: hud.hpMax,
      fill: _hp,
    );
    _drawBar(
      canvas,
      y: barHeight + barGap,
      value: hud.mana,
      max: hud.manaMax,
      fill: _mana,
    );
    _drawBar(
      canvas,
      y: (barHeight + barGap) * 2,
      value: hud.stamina,
      max: hud.staminaMax,
      fill: _stamina,
    );
  }

  void _drawBar(
    Canvas canvas, {
    required double y,
    required double value,
    required double max,
    required Paint fill,
  }) {
    final x = 0.0;
    final w = barWidth;
    final h = barHeight;

    final backRect = Rect.fromLTWH(x, y, w, h);
    canvas.drawRect(backRect, _back);
    canvas.drawRect(backRect, _outline);

    if (max <= 0) return;
    final t = (value / max).clamp(0.0, 1.0);
    if (t <= 0) return;
    canvas.drawRect(Rect.fromLTWH(x, y, w * t, h), fill);
  }
}
