import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

/// Read-only assembled overview. Detailed geometry input stays in the shared
/// Chunk Creator viewport, including its established pan/zoom/grid controls.
class CampaignOverview extends CustomPainter {
  CampaignOverview(this.mission, this.chunks);
  final CampaignMissionSource mission;
  final Map<String, PolygonTerrainRuntimeChunk> chunks;
  @override
  void paint(Canvas canvas, Size size) {
    if (mission.route.isEmpty) return;
    final scale = (size.width / (mission.route.length * 600)).clamp(
      0.01,
      size.height / 270,
    );
    canvas.save();
    canvas.scale(scale);
    for (var i = 0; i < mission.route.length; i++) {
      final chunk = chunks[mission.route[i].chunkKey];
      for (final polygon in chunk?.compiled.geometry.polygons ?? []) {
        final path = Path();
        for (var j = 0; j < polygon.vertices.length; j++) {
          final v = polygon.vertices[j];
          final x = v.xTicks / 1024 + i * 600;
          final y = v.yTicks / 1024;
          if (j == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path..close(), Paint()..color = Colors.blueGrey);
      }
      canvas.drawLine(
        Offset(i * 600.0, 0),
        Offset(i * 600.0, 270),
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 1 / scale,
      );
    }
    for (final region in [
      if (mission.exit != null) mission.exit!,
      ...mission.requiredRegions,
    ]) {
      final i = mission.route.indexWhere(
        (o) => o.id == region.origin.occurrenceId,
      );
      if (i >= 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            i * 600 + region.origin.x,
            region.origin.y,
            region.width,
            region.height,
          ),
          Paint()..color = Colors.green.withValues(alpha: .3),
        );
      }
    }
    for (final point in [
      if (mission.start != null) mission.start!,
      ...mission.collectibles,
    ]) {
      final i = mission.route.indexWhere((o) => o.id == point.occurrenceId);
      if (i >= 0) {
        canvas.drawCircle(
          Offset(i * 600 + point.x, point.y),
          5 / scale,
          Paint()..color = Colors.amber,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CampaignOverview oldDelegate) =>
      !identical(mission, oldDelegate.mission) || chunks != oldDelegate.chunks;
}
