import 'package:flutter/widgets.dart';

import '../../../game/spatial/offscreen_indicators.dart';
import '../../../game/spatial/world_view_transform.dart';
import '../../viewport/viewport_metrics.dart';

/// Maps the clipped game area to world space. Safe areas and HUD exclusions
/// affect label placement only, never whether an actor is considered visible.
class IndicatorViewport {
  IndicatorViewport({
    required this.metrics,
    required this.camera,
    required Size hostSize,
  }) : visible = Rect.fromLTWH(
         metrics.offsetX,
         metrics.offsetY,
         metrics.viewW,
         metrics.viewH,
       ).intersect(Offset.zero & hostSize);

  final ViewportMetrics metrics;
  final WorldViewTransform camera;
  final Rect visible;

  Rect get visibleWorld =>
      Rect.fromPoints(_toWorld(visible.topLeft), _toWorld(visible.bottomRight));

  Offset _toWorld(Offset point) => Offset(
    camera.viewToWorldX(
      (point.dx - metrics.offsetX) * camera.viewWidth / metrics.viewW,
    ),
    camera.viewToWorldY(
      (point.dy - metrics.offsetY) * camera.viewHeight / metrics.viewH,
    ),
  );

  Offset toScreen(Offset world) => Offset(
    metrics.offsetX +
        camera.worldToViewX(world.dx) * metrics.viewW / camera.viewWidth,
    metrics.offsetY +
        camera.worldToViewY(world.dy) * metrics.viewH / camera.viewHeight,
  );
}

/// Final paint geometry, with the nearest body-to-view distance for a group.
class OffscreenMarker {
  const OffscreenMarker({
    required this.indicator,
    required this.bounds,
    required this.bearingBounds,
    this.count = 1,
  });

  final OffscreenIndicator indicator;
  final Rect bounds;

  /// Placement before other markers displace it; grouping follows the bearing,
  /// so the player's reserved slot cannot split a nearby enemy group.
  final Rect bearingBounds;
  final int count;

  String get label => offscreenDistanceLabel(indicator.distanceMeters, count);
}

/// Whole metres avoid busy decimals; positive sub-metre gaps never read as zero.
String offscreenDistanceLabel(double meters, int count) {
  final distance = meters < 1 ? '<1 m' : '${meters.floor()} m';
  return count > 1 ? '×$count · $distance' : distance;
}

/// Keeps labels inside [safeBounds] and clear of measured HUD/control bounds.
/// Player placement has priority. Enemies whose desired labels overlap group
/// on the same edge; stable distance/id ordering prevents frame-order jitter.
/// If no slot remains, additional enemies join an existing same-edge group.
List<OffscreenMarker> layoutOffscreenIndicators({
  required List<OffscreenIndicator> indicators,
  required IndicatorViewport viewport,
  required Rect safeBounds,
  required List<Rect> exclusions,
  required Size Function(String label) measure,
}) {
  final area = safeBounds.intersect(viewport.visible).deflate(4);
  if (area.isEmpty) return const [];
  final sorted = [...indicators]
    ..sort((a, b) {
      if (a.isPlayer != b.isPlayer) return a.isPlayer ? -1 : 1;
      final distance = a.distanceMeters.compareTo(b.distanceMeters);
      return distance != 0 ? distance : a.id.compareTo(b.id);
    });
  final placed = <OffscreenMarker>[];
  for (final indicator in sorted) {
    final point = viewport.toScreen(indicator.anchor);
    final size = measure(offscreenDistanceLabel(indicator.distanceMeters, 1));
    final ideal = _idealRect(indicator.edge, point, size, area);
    final desired = _findSlot(ideal, area, exclusions);
    var groupIndex = -1;
    if (!indicator.isPlayer) {
      groupIndex = placed.indexWhere(
        (marker) =>
            !marker.indicator.isPlayer &&
            marker.indicator.edge == indicator.edge &&
            desired != null &&
            marker.bearingBounds.inflate(4).overlaps(desired),
      );
    }
    final occupied = [
      ...exclusions,
      for (final marker in placed) marker.bounds,
    ];
    final slot = _findSlot(ideal, area, occupied);
    if (groupIndex < 0 && slot == null && !indicator.isPlayer) {
      groupIndex = placed.indexWhere(
        (marker) =>
            !marker.indicator.isPlayer &&
            marker.indicator.edge == indicator.edge,
      );
    }
    if (groupIndex >= 0) {
      final group = placed[groupIndex];
      final count = group.count + 1;
      final expanded = Rect.fromLTWH(
        group.bounds.left,
        group.bounds.top,
        measure(offscreenDistanceLabel(group.indicator.distanceMeters, count))
            .width,
        group.bounds.height,
      );
      final groupSlot = _findSlot(expanded, area, [
        ...exclusions,
        for (var i = 0; i < placed.length; i++)
          if (i != groupIndex) placed[i].bounds,
      ]);
      if (groupSlot != null) {
        placed[groupIndex] = OffscreenMarker(
          indicator: group.indicator,
          bounds: groupSlot,
          bearingBounds: group.bearingBounds,
          count: count,
        );
        continue;
      }
    }
    if (slot != null) {
      placed.add(
        OffscreenMarker(
          indicator: indicator,
          bounds: slot,
          bearingBounds: desired ?? ideal,
        ),
      );
    }
  }
  return placed;
}

Rect _idealRect(
  OffscreenIndicatorEdge edge,
  Offset point,
  Size size,
  Rect area,
) {
  final leftEdge = edge != OffscreenIndicatorEdge.top;
  return Rect.fromLTWH(
    leftEdge ? area.left : point.dx - size.width / 2,
    edge == OffscreenIndicatorEdge.left ? point.dy - size.height / 2 : area.top,
    size.width,
    size.height,
  );
}

Rect? _findSlot(Rect ideal, Rect area, List<Rect> exclusions) {
  if (ideal.width > area.width || ideal.height > area.height) return null;
  final x = ideal.left.clamp(area.left, area.right - ideal.width);
  final y = ideal.top.clamp(area.top, area.bottom - ideal.height);
  // Vertical displacement preserves the top marker's horizontal bearing and
  // keeps left markers on their edge even around vitals and movement controls.
  final candidates =
      <double>{
        y,
        area.top,
        area.bottom - ideal.height,
        for (final rect in exclusions) ...[
          rect.top - ideal.height - 4,
          rect.bottom + 4,
        ],
      }.toList()..sort((a, b) {
        final distance = (a - y).abs().compareTo((b - y).abs());
        return distance != 0 ? distance : a.compareTo(b);
      });
  for (final candidate in candidates) {
    if (candidate < area.top || candidate + ideal.height > area.bottom) {
      continue;
    }
    final rect = Rect.fromLTWH(x, candidate, ideal.width, ideal.height);
    if (exclusions.every((other) => !other.inflate(4).overlaps(rect))) {
      return rect;
    }
  }
  return null;
}
