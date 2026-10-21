import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../game/spatial/offscreen_indicators.dart';
import '../../controls/controls_tuning.dart';
import '../../controls/layout/controls_radial_layout.dart';
import '../../controls/movement_control_mode.dart';
import '../../theme/ui_hud_theme.dart';
import '../../viewport/viewport_metrics.dart';
import 'offscreen_indicator_layout.dart';

/// Paint-only live actor bearings. HUD keys identify tight panel bounds, not
/// full-screen Align/Stack wrappers; they are read after layout during paint.
class OffscreenIndicatorOverlay extends StatefulWidget {
  const OffscreenIndicatorOverlay({
    super.key,
    required this.frames,
    required this.metrics,
    required this.movementControlMode,
    this.hudObstacles = const [],
  });

  final ValueListenable<OffscreenIndicatorFrame?> frames;
  final ViewportMetrics metrics;
  final MovementControlMode movementControlMode;
  final List<GlobalKey> hudObstacles;

  @override
  State<OffscreenIndicatorOverlay> createState() =>
      _OffscreenIndicatorOverlayState();
}

class _OffscreenIndicatorOverlayState extends State<OffscreenIndicatorOverlay> {
  final _paintKey = GlobalKey();
  var _projector = OffscreenIndicatorProjector();

  @override
  void didUpdateWidget(covariant OffscreenIndicatorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      _projector = OffscreenIndicatorProjector();
    }
  }

  List<Rect> _hudBounds() {
    final paintBox = _paintKey.currentContext?.findRenderObject();
    if (paintBox is! RenderBox || !paintBox.hasSize) return const [];
    return [
      for (final key in widget.hudObstacles)
        if (key.currentContext?.findRenderObject() case final RenderBox box)
          if (box.hasSize && !box.size.isEmpty)
            Rect.fromPoints(
              paintBox.globalToLocal(box.localToGlobal(Offset.zero)),
              paintBox.globalToLocal(
                box.localToGlobal(box.size.bottomRight(Offset.zero)),
              ),
            ),
    ];
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: _paintKey,
        painter: _IndicatorPainter(
          frames: widget.frames,
          projector: _projector,
          metrics: widget.metrics,
          safePadding: MediaQuery.paddingOf(context),
          textScaler: MediaQuery.textScalerOf(context),
          theme: context.hudTheme,
          hudBounds: _hudBounds,
          movementMode: widget.movementControlMode,
        ),
      ),
    ),
  );
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter({
    required this.frames,
    required this.projector,
    required this.metrics,
    required this.safePadding,
    required this.textScaler,
    required this.theme,
    required this.hudBounds,
    required this.movementMode,
  }) : super(repaint: frames);

  final ValueListenable<OffscreenIndicatorFrame?> frames;
  final OffscreenIndicatorProjector projector;
  final ViewportMetrics metrics;
  final EdgeInsets safePadding;
  final TextScaler textScaler;
  final UiHudTheme theme;
  final List<Rect> Function() hudBounds;
  final MovementControlMode movementMode;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frames.value;
    if (frame == null ||
        size.isEmpty ||
        metrics.viewW <= 0 ||
        metrics.viewH <= 0) {
      return;
    }
    final viewport = IndicatorViewport(
      metrics: metrics,
      camera: frame.camera,
      hostSize: size,
    );
    if (viewport.visible.isEmpty) return;
    final indicators = projector.project(frame, viewport.visibleWorld);
    final text = <String, TextPainter>{};
    TextPainter label(String value) => text.putIfAbsent(
      value,
      () => TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.foreground,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(),
    );
    final markers = layoutOffscreenIndicators(
      indicators: indicators,
      viewport: viewport,
      safeBounds: safePadding.deflateRect(Offset.zero & size),
      exclusions: [...hudBounds(), ..._controlBounds(size, movementMode)],
      measure: (value) {
        final painter = label(value);
        return Size(painter.width + 34, math.max(22, painter.height + 6));
      },
    );
    for (final marker in markers) {
      final rect = marker.bounds;
      final color = marker.indicator.isPlayer
          ? theme.highlight
          : theme.enemyIndicator;
      final outline = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(outline, Paint()..color = theme.background);
      canvas.drawRRect(
        outline,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final icon = Offset(rect.left + 9, rect.center.dy);
      canvas.save();
      canvas.translate(icon.dx, icon.dy);
      canvas.rotate(switch (marker.indicator.edge) {
        OffscreenIndicatorEdge.left => -math.pi / 2,
        OffscreenIndicatorEdge.top => 0,
        OffscreenIndicatorEdge.topLeft => -math.pi / 4,
      });
      canvas.drawPath(
        Path()
          ..moveTo(-3, 2)
          ..lineTo(0, -3)
          ..lineTo(3, 2),
        Paint()
          ..color = theme.foreground
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
      final symbol = Offset(rect.left + 22, rect.center.dy);
      if (marker.indicator.isPlayer) {
        canvas.drawPath(
          Path()
            ..moveTo(symbol.dx, symbol.dy - 4)
            ..lineTo(symbol.dx + 4, symbol.dy)
            ..lineTo(symbol.dx, symbol.dy + 4)
            ..lineTo(symbol.dx - 4, symbol.dy)
            ..close(),
          Paint()..color = color,
        );
      } else {
        canvas.drawCircle(symbol, 3, Paint()..color = color);
      }
      final painter = label(marker.label);
      painter.paint(
        canvas,
        Offset(rect.left + 30, rect.center.dy - painter.height / 2),
      );
    }
    for (final painter in text.values) {
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _IndicatorPainter oldDelegate) => true;
}

List<Rect> _controlBounds(Size size, MovementControlMode movementMode) {
  const tuning = ControlsTuning.defaults;
  final layout = ControlsRadialLayoutSolver.solve(
    layout: tuning.layout,
    action: tuning.style.actionButton,
    directional: tuning.style.directionalActionButton,
  );
  Rect control(ControlsAnchor anchor, double extent) => Rect.fromLTWH(
    size.width - anchor.right - extent,
    size.height - anchor.bottom - extent,
    extent,
    extent,
  );
  return [
    if (movementMode == MovementControlMode.joystick)
      // The floating base can move throughout its activation region.
      Rect.fromLTWH(
        0,
        size.height / 2,
        size.width * .33,
        size.height / 2,
      ).inflate(tuning.moveJoystick.size / 2)
    else if (movementMode == MovementControlMode.fixedJoystick)
      Rect.fromLTWH(
        tuning.layout.edgePadding,
        size.height -
            tuning.layout.bottomEdgePadding -
            tuning.moveJoystick.size,
        tuning.moveJoystick.size,
        tuning.moveJoystick.size,
      )
    else
      Rect.fromLTWH(
        tuning.layout.edgePadding,
        size.height -
            tuning.layout.bottomEdgePadding -
            tuning.moveButtons.buttonHeight,
        tuning.moveButtons.buttonWidth * 2 + tuning.moveButtons.gap,
        tuning.moveButtons.buttonHeight,
      ),
    control(layout.jump, layout.jumpSize),
    control(layout.dash, layout.actionSize),
    control(layout.melee, layout.directionalSize),
    control(layout.secondary, layout.actionSize),
    control(layout.projectile, layout.directionalSize),
    control(layout.spell, layout.actionSize),
    Rect.fromLTWH(
      size.width - layout.projectileCharge.right - tuning.style.chargeBar.width,
      size.height -
          layout.projectileCharge.bottom -
          tuning.style.chargeBar.height,
      tuning.style.chargeBar.width,
      tuning.style.chargeBar.height,
    ),
  ];
}
