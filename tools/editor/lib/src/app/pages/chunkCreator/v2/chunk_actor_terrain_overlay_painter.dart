import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';

import '../../../../chunks/chunk_v2_actor_terrain_projection.dart';
import '../../shared/terrain_polygon_scene_painter.dart';

/// Read-only painter for Core-owned actor traversal and placement evidence.
class ChunkActorTerrainOverlayPainter extends CustomPainter {
  const ChunkActorTerrainOverlayPainter({
    required this.projection,
    required this.actor,
    required this.transform,
  });

  final ChunkV2ActorTerrainProjection projection;
  final ChunkV2TerrainActor actor;
  final TerrainPolygonViewportTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    switch (actor) {
      case ChunkV2TerrainActor.eloise:
      case ChunkV2TerrainActor.grojib:
      case ChunkV2TerrainActor.hashash:
        _paintGrounded(canvas, projection.groundedView(actor)!);
      case ChunkV2TerrainActor.unoco:
        _paintUnoco(canvas);
      case ChunkV2TerrainActor.derf:
        _paintDerf(canvas);
    }
  }

  void _paintGrounded(Canvas canvas, ChunkV2GroundedTerrainView view) {
    final graph = view.graph;
    if (graph != null) _paintGraph(canvas, graph);
    final color = switch (actor) {
      ChunkV2TerrainActor.eloise => const Color(0xFF67E8F9),
      ChunkV2TerrainActor.grojib => const Color(0xFFA7F3D0),
      ChunkV2TerrainActor.hashash => const Color(0xFFC4B5FD),
      ChunkV2TerrainActor.unoco || ChunkV2TerrainActor.derf => throw StateError(
        'Grounded painter received a non-grounded actor.',
      ),
    };
    for (final surface in view.eligibleSurfaces) {
      _drawSurface(canvas, surface, color: color, strokeWidth: 4);
    }
  }

  void _paintGraph(Canvas canvas, TerrainSurfaceGraph graph) {
    for (var from = 0; from < graph.surfaces.length; from += 1) {
      for (final edge in graph.edgesFor(from)) {
        final color = switch (edge.kind) {
          TerrainSurfaceEdgeKind.walk => const Color(0xFF60A5FA),
          TerrainSurfaceEdgeKind.jump => const Color(0xFFF472B6),
          TerrainSurfaceEdgeKind.drop => const Color(0xFFFBBF24),
        };
        final start = _toCanvas(edge.takeoffPoint);
        final end = _toCanvas(edge.landingPoint);
        canvas.drawLine(
          start,
          end,
          Paint()
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: 0.62),
        );
        _drawArrowHead(canvas, start: start, end: end, color: color);
      }
    }
  }

  void _paintUnoco(Canvas canvas) {
    for (final edge in projection.expansion.geometry.edges) {
      if (!projection.isUnocoSolidBlocker(edge.id)) continue;
      canvas.drawLine(
        _toCanvas(edge.start),
        _toCanvas(edge.end),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFF87171).withValues(alpha: 0.78),
      );
    }
    for (final surface in projection.surfaceSet.surfaces) {
      if (!projection.isUnocoLocalHoverCandidate(surface.id)) continue;
      _drawSurface(
        canvas,
        surface,
        color: const Color(0xFF22D3EE),
        strokeWidth: 4,
      );
    }
  }

  void _paintDerf(Canvas canvas) {
    for (final evidence in projection.derfPerches) {
      final color = evidence.perchEligible
          ? const Color(0xFF4ADE80)
          : evidence.slopeAndModeEligible
          ? const Color(0xFFFBBF24)
          : const Color(0xFFF87171);
      _drawSurface(
        canvas,
        evidence.surface,
        color: color,
        strokeWidth: evidence.perchEligible ? 4 : 2,
      );
      if (evidence.perchEligible) {
        _drawDerfMinimumSpan(canvas, evidence.surface);
      }
    }
  }

  void _drawDerfMinimumSpan(Canvas canvas, TerrainNavigationSurface surface) {
    final centerX = (surface.xMinTicks + surface.xMaxTicks) ~/ 2;
    final halfSpan = derfMinimumSupportSpanTicks ~/ 2;
    final startX = centerX - halfSpan;
    final endX = centerX + halfSpan;
    final start = _toCanvas(TerrainPoint(startX, surface.yAtXTicks(startX)));
    final end = _toCanvas(TerrainPoint(endX, surface.yAtXTicks(endX)));
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.92);
    canvas.drawLine(start, end, paint);
    final perpendicular = _unitPerpendicular(start, end) * 4;
    canvas.drawLine(start - perpendicular, start + perpendicular, paint);
    canvas.drawLine(end - perpendicular, end + perpendicular, paint);
  }

  void _drawSurface(
    Canvas canvas,
    TerrainNavigationSurface surface, {
    required Color color,
    required double strokeWidth,
  }) {
    canvas.drawLine(
      _toCanvas(surface.start),
      _toCanvas(surface.end),
      Paint()
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.9),
    );
  }

  void _drawArrowHead(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required Color color,
  }) {
    final delta = end - start;
    if (delta.distanceSquared < 1) return;
    final unit = delta / delta.distance;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final tip = end;
    final base = tip - unit * 6;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base + perpendicular * 3).dx, (base + perpendicular * 3).dy)
      ..lineTo((base - perpendicular * 3).dx, (base - perpendicular * 3).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.75));
  }

  Offset _unitPerpendicular(Offset start, Offset end) {
    final delta = end - start;
    if (delta.distanceSquared == 0) return const Offset(0, 1);
    return Offset(-delta.dy, delta.dx) / delta.distance;
  }

  Offset _toCanvas(TerrainPoint point) => Offset(
    transform.origin.dx +
        point.xTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
    transform.origin.dy +
        point.yTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
  );

  @override
  bool shouldRepaint(covariant ChunkActorTerrainOverlayPainter oldDelegate) =>
      !identical(projection, oldDelegate.projection) ||
      actor != oldDelegate.actor ||
      transform.origin != oldDelegate.transform.origin ||
      transform.zoom != oldDelegate.transform.zoom;
}
