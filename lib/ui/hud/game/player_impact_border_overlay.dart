import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../theme/ui_tokens.dart';

/// Full-screen red border pulse for direct player impact feedback.
class PlayerImpactBorderOverlay extends StatelessWidget {
  const PlayerImpactBorderOverlay({super.key, required this.triggerSignal});

  final ValueListenable<int> triggerSignal;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: ValueListenableBuilder<int>(
        valueListenable: triggerSignal,
        builder: (context, trigger, _) {
          if (trigger == 0) {
            return const SizedBox.expand();
          }
          return TweenAnimationBuilder<double>(
            key: ValueKey(trigger),
            tween: Tween<double>(begin: 1.0, end: 0.0),
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            builder: (context, intensity, _) {
              if (intensity <= 0.001) {
                return const SizedBox.expand();
              }
              return CustomPaint(
                painter: _PlayerImpactBorderPainter(intensity: intensity),
                child: const SizedBox.expand(),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlayerImpactBorderPainter extends CustomPainter {
  const _PlayerImpactBorderPainter({required this.intensity});

  final double intensity;
  static const Color _baseColor = UiBrandPalette.crimsonDanger;

  @override
  void paint(Canvas canvas, Size size) {
    final clamped = intensity.clamp(0.0, 1.0);
    if (clamped <= 0.0) return;

    final edgeDepth = lerpDouble(20.0, 68.0, clamped) ?? 20.0;
    final edgeAlpha = lerpDouble(0.06, 0.28, clamped) ?? 0.06;
    final strokeAlpha = lerpDouble(0.12, 0.45, clamped) ?? 0.12;
    final strokeWidth = lerpDouble(2.0, 8.0, clamped) ?? 2.0;

    _paintEdge(
      canvas,
      Rect.fromLTWH(0.0, 0.0, size.width, edgeDepth),
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      alpha: edgeAlpha,
    );
    _paintEdge(
      canvas,
      Rect.fromLTWH(0.0, size.height - edgeDepth, size.width, edgeDepth),
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      alpha: edgeAlpha,
    );
    _paintEdge(
      canvas,
      Rect.fromLTWH(0.0, 0.0, edgeDepth, size.height),
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      alpha: edgeAlpha,
    );
    _paintEdge(
      canvas,
      Rect.fromLTWH(size.width - edgeDepth, 0.0, edgeDepth, size.height),
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      alpha: edgeAlpha,
    );

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = _baseColor.withValues(alpha: strokeAlpha);
    canvas.drawRect(Offset.zero & size, strokePaint);
  }

  void _paintEdge(
    Canvas canvas,
    Rect rect, {
    required Alignment begin,
    required Alignment end,
    required double alpha,
  }) {
    final edgePaint = Paint()
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: <Color>[
          _baseColor.withValues(alpha: alpha),
          _baseColor.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, edgePaint);
  }

  @override
  bool shouldRepaint(_PlayerImpactBorderPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}
