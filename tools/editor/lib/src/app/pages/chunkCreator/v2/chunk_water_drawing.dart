import 'dart:ui';

import 'package:runner_core/terrain/water_region.dart';

import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_water_commit.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_polygon_scene_projection.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../../../terrain_authoring/terrain_vertex_snap.dart';
import 'chunk_scene_snap_vertices.dart';

/// Clockwise handle order gives deterministic nearest-corner selection.
enum ChunkWaterCorner {
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

  ChunkWaterCorner get opposite => values[(index + 2) % values.length];
}

/// Source bounds in world pixels for scene hit-testing and painting.
Rect waterRegionBounds(WaterRegionData region) => Rect.fromLTWH(
  region.x.toDouble(),
  region.y.toDouble(),
  region.width.toDouble(),
  region.height.toDouble(),
);

/// Inclusive bounds preserve edge selection; authored order breaks shared-edge ties.
WaterRegionData? hitTestChunkWaterRegion(
  List<WaterRegionData> regions,
  Offset point,
) => regions.reversed
    .where(
      (region) =>
          point.dx >= region.x &&
          point.dx <= region.x + region.width &&
          point.dy >= region.y &&
          point.dy <= region.y + region.height,
    )
    .firstOrNull;

/// Uses Terrain's ten-canvas-pixel vertex hit radius, independent of zoom.
ChunkWaterCorner? hitTestChunkWaterCorner({
  required WaterRegionData region,
  required Offset worldPoint,
  required double zoom,
}) {
  final bounds = waterRegionBounds(region);
  var distanceSquared = (10 / zoom) * (10 / zoom);
  ChunkWaterCorner? nearest;
  for (final corner in ChunkWaterCorner.values) {
    final distance = (corner.position(bounds) - worldPoint).distanceSquared;
    if (distance <= distanceSquared &&
        (nearest == null || distance < distanceSquared)) {
      nearest = corner;
      distanceSquared = distance;
    }
  }
  return nearest;
}

/// Route-local creation/resize/move preview over a captured source revision. The
/// workspace retains new drafts and publishes completed edits through the
/// same plugin commit; pointer motion never changes the session document.
final class ChunkWaterDrawing {
  ChunkV2FileData? _source;
  int? _pointer;
  Offset? _start;
  Offset? _end;
  String? _materialKey;
  String? _regionId;
  WaterRegionData? _editedRegion;
  bool _moving = false;
  Offset? _pointerStart;
  Offset? _originalCorner;
  Offset _grabOffset = Offset.zero;
  List<TerrainSourceVertexDef> _neighbors = const [];
  TerrainPolygonSnapPolicy _snapPolicy =
      TerrainPolygonSnapPolicy.ownerGridPixels(1);
  bool _snapToNeighbors = true;
  WaterRegionData? _candidate;
  String? _error;
  Offset? _snappedNeighbor;

  bool get hasActiveOperation => _source != null;
  bool get isDragging => _pointer != null;
  bool get isEditing => _editedRegion != null;
  bool get isResizing => isEditing && !_moving;
  bool get isMoving => isEditing && _moving;
  String? get editingRegionId => _editedRegion?.id;
  Rect? get bounds => _start == null ? null : Rect.fromPoints(_start!, _end!);
  WaterRegionData? get candidate => _candidate;
  String? get error => _error;
  Offset? get snappedNeighbor => _snappedNeighbor;

  /// Material projection replaces an edited region without duplicating it.
  List<WaterRegionData>? get previewRegions =>
      _candidate != null && _error == null ? _regionsWithCandidate : null;

  List<WaterRegionData> get _regionsWithCandidate => [
    for (final region in _source!.waterRegions)
      region.id == editingRegionId ? _candidate! : region,
    if (!isEditing) _candidate!,
  ];

  /// Captures one owner-local draft in world pixels. [zoom] is canvas pixels
  /// per world pixel; the workspace supplies its current value on every update.
  bool begin({
    required ChunkV2FileData chunk,
    required int pointer,
    required Offset worldPoint,
    required String materialKey,
    required bool snapToGrid,
    required bool snapToNeighbors,
    required double zoom,
    ChunkV2CollisionExpansion? expansion,
    String? regionId,
  }) {
    if (hasActiveOperation) return false;
    _capture(
      chunk: chunk,
      pointer: pointer,
      materialKey: materialKey,
      regionId: regionId ?? nextChunkWaterId(chunk.waterRegions),
      snapToGrid: snapToGrid,
      snapToNeighbors: snapToNeighbors,
      expansion: expansion,
    );
    _start = _snap(worldPoint, zoom);
    _end = _start;
    _refreshCandidate();
    return true;
  }

  /// Anchors the opposite corner without snapping it. Capturing the grab offset
  /// avoids a jump when the pointer lands near, rather than exactly on, a handle.
  bool beginResize({
    required ChunkV2FileData chunk,
    required WaterRegionData region,
    required ChunkWaterCorner corner,
    required int pointer,
    required Offset worldPoint,
    required bool snapToGrid,
    required bool snapToNeighbors,
    ChunkV2CollisionExpansion? expansion,
  }) {
    if (hasActiveOperation || !chunk.waterRegions.contains(region)) {
      return false;
    }
    _editedRegion = region;
    _capture(
      chunk: chunk,
      pointer: pointer,
      materialKey: region.materialKey,
      regionId: region.id,
      snapToGrid: snapToGrid,
      snapToNeighbors: snapToNeighbors,
      expansion: expansion,
    );
    final rect = waterRegionBounds(region);
    _start = corner.opposite.position(rect);
    _originalCorner = corner.position(rect);
    _end = _originalCorner;
    _pointerStart = worldPoint;
    _grabOffset = worldPoint - _originalCorner!;
    _refreshCandidate();
    return true;
  }

  /// Captures a translation without changing the region's dimensions. The grid
  /// snaps displacement, preserving an off-grid origin until owner bounds clamp it.
  bool beginMove({
    required ChunkV2FileData chunk,
    required WaterRegionData region,
    required int pointer,
    required Offset worldPoint,
    required bool snapToGrid,
    required bool snapToNeighbors,
    ChunkV2CollisionExpansion? expansion,
  }) {
    if (hasActiveOperation || !chunk.waterRegions.contains(region)) {
      return false;
    }
    _editedRegion = region;
    _moving = true;
    _pointerStart = worldPoint;
    _capture(
      chunk: chunk,
      pointer: pointer,
      materialKey: region.materialKey,
      regionId: region.id,
      snapToGrid: snapToGrid,
      snapToNeighbors: snapToNeighbors,
      expansion: expansion,
    );
    _start = waterRegionBounds(region).topLeft;
    _end = waterRegionBounds(region).bottomRight;
    _refreshCandidate();
    return true;
  }

  void _capture({
    required ChunkV2FileData chunk,
    required int pointer,
    required String materialKey,
    required String regionId,
    required bool snapToGrid,
    required bool snapToNeighbors,
    required ChunkV2CollisionExpansion? expansion,
  }) {
    _source = chunk;
    _pointer = pointer;
    _materialKey = materialKey;
    _regionId = regionId;
    _snapPolicy = TerrainPolygonSnapPolicy.ownerGridPixels(
      snapToGrid ? chunk.tileSize : 1,
    );
    _snapToNeighbors = snapToNeighbors;
    _neighbors = chunkWholePixelSnapVertices(
      chunk: chunk,
      expansion: expansion,
      excludingWaterId: editingRegionId,
    );
  }

  void update({
    required int pointer,
    required Offset worldPoint,
    required double zoom,
  }) {
    if (_pointer != pointer) return;
    if (isMoving) {
      _updateMove(worldPoint, zoom);
    } else if (isResizing &&
        (worldPoint - _pointerStart!).distanceSquared < 1e-8) {
      // A click or a return to the grab position must not quantize saved bounds.
      _end = _originalCorner;
      _snappedNeighbor = null;
    } else {
      _end = _snap(worldPoint - _grabOffset, zoom);
    }
    _refreshCandidate();
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

  /// Applies the shared exact rectangle inspector to the local draft only.
  bool editDimensions({
    required int xHalfPixels,
    required int bottomYHalfPixels,
    required int widthHalfPixels,
    required int heightHalfPixels,
  }) {
    if (_source == null || isDragging || isEditing) return false;
    final yHalfPixels = bottomYHalfPixels - heightHalfPixels;
    if ([
          xHalfPixels,
          yHalfPixels,
          widthHalfPixels,
          heightHalfPixels,
        ].any((value) => value.isOdd) ||
        xHalfPixels < 0 ||
        yHalfPixels < 0 ||
        widthHalfPixels <= 0 ||
        heightHalfPixels <= 0 ||
        xHalfPixels + widthHalfPixels > _source!.width * 2 ||
        bottomYHalfPixels > _source!.height * 2) {
      _error = 'Keep a positive whole-pixel rectangle inside the chunk.';
      return false;
    }
    _start = Offset(xHalfPixels * .5, yHalfPixels * .5);
    _end = _start! + Offset(widthHalfPixels * .5, heightHalfPixels * .5);
    _snappedNeighbor = null;
    _refreshCandidate();
    return _error == null;
  }

  /// Returns a commit only after pointer release and successful source checks.
  /// The captured revision lets the plugin reject intervening document edits.
  ChunkWaterCommit? buildCommit() {
    if (isDragging ||
        _candidate == null ||
        _candidate == _editedRegion ||
        _error != null) {
      return null;
    }
    return ChunkWaterCommit(
      expectedRevision: _source!.revision,
      regions: _regionsWithCandidate,
    );
  }

  bool cancel() {
    if (!hasActiveOperation) return false;
    _source = null;
    _pointer = null;
    _start = null;
    _end = null;
    _editedRegion = null;
    _moving = false;
    _pointerStart = null;
    _originalCorner = null;
    _grabOffset = Offset.zero;
    _candidate = null;
    _error = null;
    _snappedNeighbor = null;
    _neighbors = const [];
    return true;
  }

  void _updateMove(Offset point, double zoom) {
    final original = waterRegionBounds(_editedRegion!);
    final delta = point - _pointerStart!;
    _snappedNeighbor = null;
    if (delta.distanceSquared < 1e-8) {
      _start = original.topLeft;
      _end = original.bottomRight;
      return;
    }
    final maximumX = _source!.width - original.width;
    final maximumY = _source!.height - original.height;
    Offset? snappedOrigin;
    var nearestDistanceSquared = (8 / zoom) * (8 / zoom);
    if (_snapToNeighbors) {
      for (final corner in ChunkWaterCorner.values) {
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
      vertex.xHalfPixels.clamp(0, _source!.width * 2 ~/ step * step) * .5,
      vertex.yHalfPixels.clamp(0, _source!.height * 2 ~/ step * step) * .5,
    );
  }

  void _refreshCandidate() {
    final rect = bounds!;
    _candidate = null;
    if (rect.isEmpty) {
      _error = 'Drag opposite corners to give the water width and depth.';
      return;
    }
    _candidate = WaterRegionData(
      id: _regionId!,
      x: rect.left.toInt(),
      y: rect.top.toInt(),
      width: rect.width.toInt(),
      height: rect.height.toInt(),
      materialKey: _materialKey!,
    );
    _error = chunkWaterValidationMessage(_source!, _regionsWithCandidate);
  }
}
