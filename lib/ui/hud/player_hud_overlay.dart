import 'package:flutter/widgets.dart';

import '../../game/game_controller.dart';

class PlayerHudOverlay extends StatelessWidget {
  const PlayerHudOverlay({required this.controller, super.key});

  final GameController controller;

  static const double _barWidth = 140;
  static const double _barHeight = 6;
  static const double _barGap = 4;

  @override
  Widget build(BuildContext context) {
    final totalHeight = _barHeight * 3 + _barGap * 2;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hud = controller.snapshot.hud;
        return IgnorePointer(
          child: RepaintBoundary(
            child: SizedBox(
              width: _barWidth,
              height: totalHeight,
              
              child: CustomPaint(
                painter: _HudBarsPainter(
                  hp: hud.hp,
                  hpMax: hud.hpMax,
                  mana: hud.mana,
                  manaMax: hud.manaMax,
                  stamina: hud.stamina,
                  staminaMax: hud.staminaMax,
                  barWidth: _barWidth,
                  barHeight: _barHeight,
                  barGap: _barGap,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HudBarsPainter extends CustomPainter {
  _HudBarsPainter({
    required this.hp,
    required this.hpMax,
    required this.mana,
    required this.manaMax,
    required this.stamina,
    required this.staminaMax,
    required this.barWidth,
    required this.barHeight,
    required this.barGap,
  });

  final double hp;
  final double hpMax;
  final double mana;
  final double manaMax;
  final double stamina;
  final double staminaMax;
  final double barWidth;
  final double barHeight;
  final double barGap;

  static final Paint _back = Paint()..color = const Color(0xAA000000);
  static final Paint _outline = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final Paint _hp = Paint()..color = const Color(0xFFDC4440);
  static final Paint _mana = Paint()..color = const Color(0xFF2D98DA);
  static final Paint _stamina = Paint()..color = const Color(0xFF4CD137);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBar(
      canvas,
      y: 0,
      value: hp,
      max: hpMax,
      fill: _hp,
    );
    _drawBar(
      canvas,
      y: barHeight + barGap,
      value: mana,
      max: manaMax,
      fill: _mana,
    );
    _drawBar(
      canvas,
      y: (barHeight + barGap) * 2,
      value: stamina,
      max: staminaMax,
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
    final backRect = Rect.fromLTWH(0, y, barWidth, barHeight);
    canvas.drawRect(backRect, _back);
    canvas.drawRect(backRect, _outline);

    if (max <= 0) return;
    final t = (value / max).clamp(0.0, 1.0);
    if (t <= 0) return;
    canvas.drawRect(Rect.fromLTWH(0, y, barWidth * t, barHeight), fill);
  }

  @override
  bool shouldRepaint(covariant _HudBarsPainter oldDelegate) {
    return hp != oldDelegate.hp ||
        hpMax != oldDelegate.hpMax ||
        mana != oldDelegate.mana ||
        manaMax != oldDelegate.manaMax ||
        stamina != oldDelegate.stamina ||
        staminaMax != oldDelegate.staminaMax ||
        barWidth != oldDelegate.barWidth ||
        barHeight != oldDelegate.barHeight ||
        barGap != oldDelegate.barGap;
  }
}
