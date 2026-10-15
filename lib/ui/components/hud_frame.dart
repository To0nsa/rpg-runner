import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ui_hud_theme.dart';

/// Weathered metal framing inside the existing footprint. The decoration never
/// captures input or changes the child's semantics.
class HudPanel extends StatelessWidget {
  const HudPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.width,
  });
  final Widget child;
  final EdgeInsets padding;
  final double? width;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PanelPainter(context.hudTheme),
    child: SizedBox(
      width: width,
      child: Padding(padding: padding + const EdgeInsets.all(1), child: child),
    ),
  );
}

/// Stamped edging over a control's resource-tinted surface. Directional scoring
/// is reserved for the floating joystick base through [compass].
class HudMedallion extends StatelessWidget {
  const HudMedallion({super.key, required this.child, this.compass = false});
  final Widget child;
  final bool compass;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _MedallionPainter(context.hudTheme, compass: compass),
    child: child,
  );
}

Path _panelPath(Rect r, double cut) => Path()
  ..moveTo(r.left + cut, r.top)
  ..lineTo(r.right - cut, r.top)
  ..lineTo(r.right, r.top + cut)
  ..lineTo(r.right, r.bottom - cut)
  ..lineTo(r.right - cut, r.bottom)
  ..lineTo(r.left + cut, r.bottom)
  ..lineTo(r.left, r.bottom - cut)
  ..lineTo(r.left, r.top + cut)
  ..close();

// Fixed marks never shimmer with frame time and stay quieter than the content.
void _wear(Canvas canvas, Rect bounds, UiHudTheme theme) {
  final paint = Paint()
    ..color = theme.wear.withValues(alpha: .08)
    ..strokeWidth = .6;
  for (var row = 0; row < bounds.height ~/ 9; row++) {
    for (var column = 0; column < bounds.width ~/ 13; column++) {
      final seed = (row * 37 + column * 19) % 17;
      if (seed > 8) continue;
      final p = Offset(
        bounds.left + column * 13 + seed,
        bounds.top + row * 9 + seed % 5,
      );
      canvas.drawLine(p, p + Offset(1 + seed % 4, -.4), paint);
    }
  }
}

class _PanelPainter extends CustomPainter {
  const _PanelPainter(this.theme);
  final UiHudTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 12) return;
    final rect = (Offset.zero & size).deflate(.5);
    final path = _panelPath(rect, 5);
    canvas.drawPath(path, Paint()..color = theme.background);
    canvas.save();
    canvas.clipPath(path);
    _wear(canvas, rect, theme);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.border.withValues(alpha: .65)
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      _panelPath(rect.deflate(3), 3),
      Paint()
        ..color = theme.wear.withValues(alpha: .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    final edge = Paint()
      ..color = theme.highlight.withValues(alpha: .42)
      ..strokeWidth = .8;
    canvas.drawLine(const Offset(9, 1.5), Offset(size.width * .38, 1.5), edge);
    canvas.drawLine(
      Offset(size.width * .64, size.height - 1.5),
      Offset(size.width - 9, size.height - 1.5),
      edge,
    );
    // Small pins suggest practical construction rather than ornamental gems.
    for (final p in [
      const Offset(4, 4),
      Offset(size.width - 4, size.height - 4),
    ]) {
      canvas.drawCircle(
        p,
        1,
        Paint()..color = theme.border.withValues(alpha: .8),
      );
    }
  }

  @override
  bool hitTest(Offset position) => false;
  @override
  bool shouldRepaint(covariant _PanelPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class _MedallionPainter extends CustomPainter {
  const _MedallionPainter(this.theme, {required this.compass});
  final UiHudTheme theme;
  final bool compass;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (radius < 8) return;
    final outer = Rect.fromCircle(center: center, radius: radius - 1);
    final inner = Rect.fromCircle(center: center, radius: radius - 4);
    canvas.save();
    canvas.clipPath(Path()..addOval(outer));
    _wear(canvas, outer, theme);
    canvas.restore();
    canvas.drawOval(
      outer,
      Paint()
        ..color = theme.track.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final rim = Paint()
      ..color = theme.border.withValues(alpha: .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Gaps and an incomplete highlight give the rim a worn, stamped edge.
    canvas.drawArc(outer, -.42, math.pi * 1.14, false, rim);
    canvas.drawArc(outer, math.pi * .91, math.pi * .85, false, rim);
    canvas.drawArc(
      outer.deflate(1),
      math.pi * 1.1,
      math.pi * .45,
      false,
      Paint()
        ..color = theme.highlight.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    canvas.drawOval(
      inner,
      Paint()
        ..color = theme.wear.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    final count = compass ? 12 : 4;
    for (var i = 0; i < count; i++) {
      final angle = i * math.pi * 2 / count;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (radius - (compass ? 9 : 4)),
        center + direction * (radius - (compass ? 5 : 1.5)),
        rim,
      );
    }
    if (compass) {
      final scoring = Paint()
        ..color = theme.wear.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7;
      canvas.drawOval(
        Rect.fromCircle(center: center, radius: radius * .57),
        scoring,
      );
      canvas.drawLine(
        center - Offset(radius * .55, 0),
        center + Offset(radius * .55, 0),
        scoring,
      );
    }
  }

  @override
  bool hitTest(Offset position) => false;
  @override
  bool shouldRepaint(covariant _MedallionPainter oldDelegate) =>
      oldDelegate.theme != theme || oldDelegate.compass != compass;
}
