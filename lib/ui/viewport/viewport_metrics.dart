import 'dart:math' as math;

import 'package:flutter/widgets.dart';
/// Viewport scaling modes for fitting a fixed virtual canvas to the screen.
enum ViewportScaleMode {
  /// Integer physical-pixel scale (pixel-perfect, no cropping).
  ///
  /// Fits the entire virtual canvas on-screen, letterboxing the remaining area.
  pixelPerfectContain,

  /// Integer physical-pixel scale (pixel-perfect, with cropping).
  ///
  /// Fully covers the screen by scaling up until both dimensions fit. Any
  /// overflow is cropped by the outer [ClipRect].
  pixelPerfectCover,
}

/// Shared viewport sizing results for rendering and input mapping.
@immutable
class ViewportMetrics {
  const ViewportMetrics({
    required this.viewW,
    required this.viewH,
    required this.offsetX,
    required this.offsetY,
  });

  /// Scaled viewport width in logical pixels.
  final double viewW;

  /// Scaled viewport height in logical pixels.
  final double viewH;

  /// Viewport top-left offset in logical pixels.
  final double offsetX;

  /// Viewport top-left offset in logical pixels.
  final double offsetY;
}

/// Computes shared viewport metrics from the current layout constraints.
ViewportMetrics computeViewportMetrics(
  BoxConstraints constraints,
  double devicePixelRatio,
  int virtualW,
  int virtualH,
  ViewportScaleMode mode, {
  Alignment alignment = Alignment.center,
}) {
  assert(devicePixelRatio > 0);
  assert(virtualW > 0);
  assert(virtualH > 0);

  final screenW = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
  final screenH = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
  final screenPxW = screenW * devicePixelRatio;
  final screenPxH = screenH * devicePixelRatio;

  final scaleW = screenPxW / virtualW;
  final scaleH = screenPxH / virtualH;

  final scalePx = switch (mode) {
    ViewportScaleMode.pixelPerfectContain =>
      math.max(1.0, math.min(scaleW, scaleH).floorToDouble()),
    ViewportScaleMode.pixelPerfectCover =>
      math.max(1.0, math.max(scaleW, scaleH).ceilToDouble()),
  };

  final viewPxW = virtualW * scalePx;
  final viewPxH = virtualH * scalePx;
  final viewW = viewPxW / devicePixelRatio;
  final viewH = viewPxH / devicePixelRatio;

  final alignX = (alignment.x + 1.0) * 0.5;
  final alignY = (alignment.y + 1.0) * 0.5;
  final offsetX = (screenW - viewW) * alignX;
  final offsetY = (screenH - viewH) * alignY;

  return ViewportMetrics(
    viewW: viewW,
    viewH: viewH,
    offsetX: offsetX,
    offsetY: offsetY,
  );
}
