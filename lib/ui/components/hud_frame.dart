import 'package:flutter/material.dart';

import '../theme/ui_hud_theme.dart';

/// Restrained iron framing inside the existing footprint. The decoration never
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

/// A quiet metal rim over a control's resource-tinted surface.
class HudMedallion extends StatelessWidget {
  const HudMedallion({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _MedallionPainter(context.hudTheme),
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

class _PanelPainter extends CustomPainter {
  const _PanelPainter(this.theme);
  final UiHudTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 12) return;
    final rect = (Offset.zero & size).deflate(.5);
    final path = _panelPath(rect, 3);
    canvas.drawPath(path, Paint()..color = theme.background);
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.border.withValues(alpha: .4)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool hitTest(Offset position) => false;
  @override
  bool shouldRepaint(covariant _PanelPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class _MedallionPainter extends CustomPainter {
  const _MedallionPainter(this.theme);
  final UiHudTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (radius < 8) return;
    final outer = Rect.fromCircle(center: center, radius: radius - 1);
    canvas.drawOval(
      outer,
      Paint()
        ..color = theme.border.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool hitTest(Offset position) => false;
  @override
  bool shouldRepaint(covariant _MedallionPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
