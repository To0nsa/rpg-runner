import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'controls_tuning.dart';

/// Paint-only cooldown indicator rendered around circular controls.
///
/// `cooldownTicksLeft` and `cooldownTicksTotal` are simulation ticks. Nothing
/// is painted when either value is non-positive.
class CooldownRing extends StatelessWidget {
  const CooldownRing({
    super.key,
    required this.cooldownTicksLeft,
    required this.cooldownTicksTotal,
    required this.tuning,
  });

  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final CooldownRingTuning tuning;

  @override
  Widget build(BuildContext context) {
    if (cooldownTicksLeft <= 0 || cooldownTicksTotal <= 0) {
      return const SizedBox.shrink();
    }

    final clampedLeft = cooldownTicksLeft.clamp(0, cooldownTicksTotal);
    final elapsed = 1.0 - (clampedLeft / cooldownTicksTotal);

    return CustomPaint(
      painter: _CooldownRingPainter(
        elapsedFraction: elapsed.clamp(0.0, 1.0),
        thickness: tuning.thickness,
        trackColor: tuning.trackColor,
        progressColor: tuning.progressColor,
      ),
    );
  }
}

class _CooldownRingPainter extends CustomPainter {
  _CooldownRingPainter({
    required this.elapsedFraction,
    required this.thickness,
    required this.trackColor,
    required this.progressColor,
  });

  final double elapsedFraction;
  final double thickness;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = thickness / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - thickness,
      size.height - thickness,
    );

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    canvas.drawArc(rect, startAngle, math.pi * 2, false, trackPaint);
    if (elapsedFraction > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        math.pi * 2 * elapsedFraction,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CooldownRingPainter oldDelegate) {
    return oldDelegate.elapsedFraction != elapsedFraction ||
        oldDelegate.thickness != thickness ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
