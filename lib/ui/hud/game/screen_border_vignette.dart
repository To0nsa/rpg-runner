import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../theme/ui_tokens.dart';

/// Semantic screen feedback styles sharing the same edge geometry and fade.
enum ScreenBorderVignetteStyle { playerImpact, bossEntrance }

/// Read-only edge rendering; callers own their event or entrance timeline.
class ScreenBorderVignette extends StatelessWidget {
  const ScreenBorderVignette({
    super.key,
    required this.style,
    required this.intensity,
  });
  final ScreenBorderVignetteStyle style;
  final double intensity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: intensity <= .001
        ? const SizedBox.expand()
        : CustomPaint(
            painter: _ScreenBorderVignettePainter(
              intensity: intensity,
              baseColor: switch (style) {
                ScreenBorderVignetteStyle.playerImpact =>
                  UiBrandPalette.crimsonDanger,
                ScreenBorderVignetteStyle.bossEntrance => const Color(
                  0xFF000000,
                ),
              },
            ),
            child: const SizedBox.expand(),
          ),
  );
}

class _ScreenBorderVignettePainter extends CustomPainter {
  const _ScreenBorderVignettePainter({
    required this.intensity,
    required this.baseColor,
  });

  final double intensity;
  final Color baseColor;

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
      ..color = baseColor.withValues(alpha: strokeAlpha);
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
          baseColor.withValues(alpha: alpha),
          baseColor.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, edgePaint);
  }

  @override
  bool shouldRepaint(_ScreenBorderVignettePainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.baseColor != baseColor;
  }
}
