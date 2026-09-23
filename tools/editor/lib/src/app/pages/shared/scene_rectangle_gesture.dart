import 'dart:ui';

import '../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../terrain_authoring/terrain_polygon_scene_projection.dart';
import '../../../terrain_authoring/terrain_source_models.dart';
import '../../../terrain_authoring/terrain_vertex_snap.dart';

/// Clockwise handle order gives deterministic nearest-corner selection.
enum SceneRectangleCorner {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft;

  Offset position(Rect bounds) => switch (this) {
    topLeft => bounds.topLeft,
    topRight => bounds.topRight,
    bottomRight => bounds.bottomRight,
    bottomLeft => bounds.bottomLeft,
  };

  SceneRectangleCorner get opposite => values[(index + 2) % values.length];
}

/// Uses Terrain's ten-canvas-pixel vertex hit radius, independent of zoom.
SceneRectangleCorner? hitTestSceneRectangleCorner({
  required Rect bounds,
  required Offset worldPoint,
  required double zoom,
}) {
  var distanceSquared = (10 / zoom) * (10 / zoom);
  SceneRectangleCorner? nearest;
  for (final corner in SceneRectangleCorner.values) {
    final distance = (corner.position(bounds) - worldPoint).distanceSquared;
    if (distance <= distanceSquared &&
        (nearest == null || distance < distanceSquared)) {
      nearest = corner;
      distanceSquared = distance;
    }
  }
  return nearest;
}

/// Shared rectangle draw/resize/translation math. Domains capture source revision
/// and validate candidates; this helper owns only pointer geometry and snapping.
final class SceneRectangleGesture {
  SceneRectangleGesture({
    required int pointer,
    required Offset worldPoint,
    required this.limit,
    required TerrainPolygonSnapPolicy snapPolicy,
    required List<TerrainSourceVertexDef> neighbors,
    required bool snapToNeighbors,
    required double zoom,
    Rect? original,
    SceneRectangleCorner? corner,
    bool moving = false,
  }) : _pointer = pointer,
       _pointerStart = worldPoint,
       _snapPolicy = snapPolicy,
       _neighbors = neighbors,
       _snapToNeighbors = snapToNeighbors,
       _original = original,
       _moving = moving {
    if (original == null) {
      _start = _snap(worldPoint, zoom);
      _end = _start;
    } else if (moving) {
      _start = original.topLeft;
      _end = original.bottomRight;
    } else {
      _start = corner!.opposite.position(original);
      _originalCorner = corner.position(original);
      _end = _originalCorner;
      _grabOffset = worldPoint - _originalCorner!;
    }
  }
  final Size limit;
  final TerrainPolygonSnapPolicy _snapPolicy;
  final List<TerrainSourceVertexDef> _neighbors;
  final bool _snapToNeighbors;
  final Rect? _original;
  final bool _moving;
  final Offset _pointerStart;
  int? _pointer;
  Offset? _start, _end, _originalCorner, _snappedNeighbor;
  Offset _grabOffset = Offset.zero;
  bool get isDragging => _pointer != null;
  Rect get bounds => Rect.fromPoints(_start!, _end!);
  Offset? get snappedNeighbor => _snappedNeighbor;
  void setBounds(Rect bounds) {
    assert(!isDragging);
    _start = bounds.topLeft;
    _end = bounds.bottomRight;
    _snappedNeighbor = null;
  }

  void update({
    required int pointer,
    required Offset worldPoint,
    required double zoom,
  }) {
    if (_pointer != pointer) return;
    if (_moving) {
      _updateMove(worldPoint, zoom);
    } else if (_original != null &&
        (worldPoint - _pointerStart).distanceSquared < 1e-8) {
      _end = _originalCorner;
      _snappedNeighbor = null;
    } else {
      _end = _snap(worldPoint - _grabOffset, zoom);
    }
  }

  void finish({
    required int pointer,
    required Offset worldPoint,
    required double zoom,
  }) {
    if (_pointer != pointer) return;
    update(pointer: pointer, worldPoint: worldPoint, zoom: zoom);
    _pointer = null;
  }

  void _updateMove(Offset point, double zoom) {
    final original = _original!;
    final delta = point - _pointerStart;
    _snappedNeighbor = null;
    if (delta.distanceSquared < 1e-8) {
      _start = original.topLeft;
      _end = original.bottomRight;
      return;
    }
    final maximumX = limit.width - original.width;
    final maximumY = limit.height - original.height;
    Offset? snappedOrigin;
    var nearestDistanceSquared = (8 / zoom) * (8 / zoom);
    if (_snapToNeighbors) {
      for (final corner in SceneRectangleCorner.values) {
        final movingCorner = corner.position(original) + delta;
        for (final target in _neighbors) {
          final neighbor = Offset(
            target.xHalfPixels * .5,
            target.yHalfPixels * .5,
          );
          final distance = (neighbor - movingCorner).distanceSquared;
          final origin =
              neighbor - (corner.position(original) - original.topLeft);
          if (origin.dx < 0 ||
              origin.dx > maximumX ||
              origin.dy < 0 ||
              origin.dy > maximumY) {
            continue;
          }
          if (distance <= nearestDistanceSquared &&
              (snappedOrigin == null || distance < nearestDistanceSquared)) {
            nearestDistanceSquared = distance;
            snappedOrigin = origin;
            _snappedNeighbor = neighbor;
          }
        }
      }
    }
    _start =
        snappedOrigin ??
        Offset(
          (original.left +
                  _snapPolicy.snapFractionalCoordinate(delta.dx * 2) * .5)
              .clamp(0, maximumX),
          (original.top +
                  _snapPolicy.snapFractionalCoordinate(delta.dy * 2) * .5)
              .clamp(0, maximumY),
        );
    _end = _start! + Offset(original.width, original.height);
  }

  Offset _snap(Offset point, double zoom) {
    final sourcePoint = TerrainPolygonScenePoint(point.dx * 2, point.dy * 2);
    final neighbor = _snapToNeighbors
        ? nearestTerrainVertex(
            _neighbors,
            sourcePoint,
            radiusHalfPixels: 16 / zoom,
          )
        : null;
    _snappedNeighbor = neighbor == null
        ? null
        : Offset(neighbor.xHalfPixels * .5, neighbor.yHalfPixels * .5);
    if (_snappedNeighbor != null) return _snappedNeighbor!;
    final vertex = _snapPolicy.snapFractionalVertex(
      xHalfPixels: sourcePoint.xHalfPixels,
      yHalfPixels: sourcePoint.yHalfPixels,
    );
    final step = _snapPolicy.stepHalfPixels;
    return Offset(
      vertex.xHalfPixels.clamp(0, limit.width * 2 ~/ step * step) * .5,
      vertex.yHalfPixels.clamp(0, limit.height * 2 ~/ step * step) * .5,
    );
  }
}
