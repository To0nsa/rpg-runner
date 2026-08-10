import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';

import '../../../../chunks/chunk_v2_marker_placement_projection.dart';
import '../../shared/terrain_polygon_scene_painter.dart';

/// Read-only marker anchors and exact Core placement evidence.
class ChunkMarkerPlacementOverlayPainter extends CustomPainter {
  const ChunkMarkerPlacementOverlayPainter({
    required this.projection,
    required this.transform,
    this.selectedMarkerKey,
  });

  final ChunkV2MarkerPlacementProjection projection;
  final TerrainPolygonViewportTransform transform;
  final String? selectedMarkerKey;

  @override
  void paint(Canvas canvas, Size size) {
    for (final outcome in projection.outcomes) {
      _paintOutcome(
        canvas,
        outcome,
        selected: outcome.selectionKey == selectedMarkerKey,
      );
    }
  }

  void _paintOutcome(
    Canvas canvas,
    ChunkV2MarkerPlacementOutcome outcome, {
    required bool selected,
  }) {
    final color = _dispositionColor(outcome.disposition);
    final anchor = _worldToCanvas(
      outcome.marker.x.toDouble(),
      outcome.marker.y.toDouble(),
    );
    final intendedSurface = outcome.intendedSurface;
    if (intendedSurface != null) {
      canvas.drawLine(
        _toCanvas(intendedSurface.start),
        _toCanvas(intendedSurface.end),
        Paint()
          ..strokeWidth = selected ? 6 : 4
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: selected ? 0.95 : 0.66),
      );
    }

    final result = outcome.result;
    final profile = outcome.profile;
    final body = result?.bodyCenter ?? result?.requestedBodyCenter;
    if (body != null && profile != null) {
      final bodyCanvas = _toCanvas(body);
      canvas.drawLine(
        anchor,
        bodyCanvas,
        Paint()
          ..strokeWidth = selected ? 2.5 : 1.5
          ..color = color.withValues(alpha: 0.75),
      );
      final capsuleCenter = body.translated(
        profile.capsule.resolvedOffsetXTicks,
        profile.capsule.offsetYTicks,
      );
      _drawCapsule(
        canvas,
        center: capsuleCenter,
        radiusTicks: profile.capsule.radiusTicks,
        verticalHalfSegmentTicks: profile.capsule.verticalHalfSegmentTicks,
        color: color,
        selected: selected,
        rejected: result?.accepted == false,
      );
    }

    final anchorPaint = Paint()
      ..color = color
      ..style = outcome.deferred ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = selected ? 3 : 2;
    final radius = selected ? 7.0 : 5.0;
    if (outcome.disposition == ChunkV2MarkerPlacementDisposition.malformed) {
      canvas.drawLine(
        anchor - Offset(radius, radius),
        anchor + Offset(radius, radius),
        anchorPaint,
      );
      canvas.drawLine(
        anchor + Offset(radius, -radius),
        anchor + Offset(-radius, radius),
        anchorPaint,
      );
    } else if (outcome.deferred) {
      final path = Path()
        ..moveTo(anchor.dx, anchor.dy - radius)
        ..lineTo(anchor.dx + radius, anchor.dy)
        ..lineTo(anchor.dx, anchor.dy + radius)
        ..lineTo(anchor.dx - radius, anchor.dy)
        ..close();
      canvas.drawPath(path, anchorPaint);
    } else {
      canvas.drawCircle(anchor, radius, anchorPaint);
    }
  }

  void _drawCapsule(
    Canvas canvas, {
    required TerrainPoint center,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required Color color,
    required bool selected,
    required bool rejected,
  }) {
    final centerCanvas = _toCanvas(center);
    final radius =
        radiusTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom;
    final halfHeight =
        (radiusTicks + verticalHalfSegmentTicks) /
        terrainPhysicsTicksPerWorldUnit *
        transform.zoom;
    final bounds = Rect.fromLTRB(
      centerCanvas.dx - radius,
      centerCanvas.dy - halfHeight,
      centerCanvas.dx + radius,
      centerCanvas.dy + halfHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 2
        ..color = color.withValues(alpha: rejected ? 0.78 : 1),
    );
    if (rejected) {
      canvas.drawLine(
        bounds.topLeft,
        bounds.bottomRight,
        Paint()
          ..strokeWidth = selected ? 3 : 2
          ..color = color.withValues(alpha: 0.9),
      );
      canvas.drawLine(
        bounds.topRight,
        bounds.bottomLeft,
        Paint()
          ..strokeWidth = selected ? 3 : 2
          ..color = color.withValues(alpha: 0.9),
      );
    }
  }

  Color _dispositionColor(ChunkV2MarkerPlacementDisposition disposition) =>
      switch (disposition) {
        ChunkV2MarkerPlacementDisposition.guaranteedAccepted => const Color(
          0xFF4ADE80,
        ),
        ChunkV2MarkerPlacementDisposition.conditionalAccepted => const Color(
          0xFF67E8F9,
        ),
        ChunkV2MarkerPlacementDisposition.guaranteedRejected => const Color(
          0xFFF87171,
        ),
        ChunkV2MarkerPlacementDisposition.conditionalRejected => const Color(
          0xFFFBBF24,
        ),
        ChunkV2MarkerPlacementDisposition.disabled => const Color(0xFF94A3B8),
        ChunkV2MarkerPlacementDisposition.deferredGuaranteed ||
        ChunkV2MarkerPlacementDisposition.deferredConditional => const Color(
          0xFFC4B5FD,
        ),
        ChunkV2MarkerPlacementDisposition.malformed => const Color(0xFFFF4D8D),
      };

  Offset _toCanvas(TerrainPoint point) => Offset(
    transform.origin.dx +
        point.xTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
    transform.origin.dy +
        point.yTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
  );

  Offset _worldToCanvas(double x, double y) => Offset(
    transform.origin.dx + x * transform.zoom,
    transform.origin.dy + y * transform.zoom,
  );

  @override
  bool shouldRepaint(
    covariant ChunkMarkerPlacementOverlayPainter oldDelegate,
  ) =>
      !identical(projection, oldDelegate.projection) ||
      selectedMarkerKey != oldDelegate.selectedMarkerKey ||
      transform != oldDelegate.transform;
}
