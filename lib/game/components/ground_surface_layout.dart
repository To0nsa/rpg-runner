import 'dart:ui' as ui;

import '../../core/snapshots/ground_surface_snapshot.dart';

/// Visible render span for one ground surface.
class GroundSurfaceRenderBand {
  const GroundSurfaceRenderBand({
    required this.minX,
    required this.maxX,
    required this.topY,
    required this.bottomY,
  }) : assert(maxX >= minX),
       assert(bottomY >= topY);

  final double minX;
  final double maxX;
  final double topY;
  final double bottomY;
}

/// Layout helpers for geometry-driven ground rendering.
class GroundSurfaceLayout {
  const GroundSurfaceLayout._();

  /// Builds clipped, finite world-space render bands from ground surfaces.
  ///
  /// - Surface X spans are clamped to [visibleWorldRect.left/right].
  /// - Infinite surfaces are converted into finite visible spans.
  /// - Surfaces outside vertical visibility are omitted.
  static List<GroundSurfaceRenderBand> buildVisibleBands({
    required List<GroundSurfaceSnapshot> surfaces,
    required ui.Rect visibleWorldRect,
    required double fillDepth,
  }) {
    if (surfaces.isEmpty || fillDepth <= 0.0) {
      return const <GroundSurfaceRenderBand>[];
    }

    final visibleLeft = visibleWorldRect.left;
    final visibleRight = visibleWorldRect.right;
    final visibleTop = visibleWorldRect.top;
    final visibleBottom = visibleWorldRect.bottom;
    final out = <GroundSurfaceRenderBand>[];

    for (final surface in surfaces) {
      var minX = surface.minX;
      var maxX = surface.maxX;

      if (!minX.isFinite) minX = visibleLeft;
      if (!maxX.isFinite) maxX = visibleRight;
      if (minX < visibleLeft) minX = visibleLeft;
      if (maxX > visibleRight) maxX = visibleRight;
      if (maxX <= minX) continue;

      final topY = surface.topY;
      final bottomY = topY + fillDepth;
      if (bottomY <= visibleTop || topY >= visibleBottom) continue;

      out.add(
        GroundSurfaceRenderBand(
          minX: minX,
          maxX: maxX,
          topY: topY,
          bottomY: bottomY,
        ),
      );
    }

    return out;
  }
}
