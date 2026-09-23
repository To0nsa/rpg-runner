import 'dart:ui';

import 'package:runner_core/terrain/water_region.dart';

import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_water_commit.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import 'chunk_scene_snap_vertices.dart';
import '../../shared/scene_rectangle_gesture.dart';

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

/// Route-local creation/resize/move preview over a captured source revision. The
/// workspace retains new drafts and publishes completed edits through the
/// same plugin commit; pointer motion never changes the session document.
final class ChunkWaterDrawing {
  ChunkV2FileData? _source;
  SceneRectangleGesture? _gesture;
  String? _materialKey;
  String? _regionId;
  WaterRegionData? _editedRegion;
  bool _moving = false;
  WaterRegionData? _candidate;
  String? _error;

  bool get hasActiveOperation => _source != null;
  bool get isDragging => _gesture?.isDragging ?? false;
  bool get isEditing => _editedRegion != null;
  bool get isResizing => isEditing && !_moving;
  bool get isMoving => isEditing && _moving;
  String? get editingRegionId => _editedRegion?.id;
  Rect? get bounds => _gesture?.bounds;
  WaterRegionData? get candidate => _candidate;
  String? get error => _error;
  Offset? get snappedNeighbor => _gesture?.snappedNeighbor;

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
      worldPoint: worldPoint,
      zoom: zoom,
      materialKey: materialKey,
      regionId: regionId ?? nextChunkWaterId(chunk.waterRegions),
      snapToGrid: snapToGrid,
      snapToNeighbors: snapToNeighbors,
      expansion: expansion,
    );
    _refreshCandidate();
    return true;
  }

  /// Anchors the opposite corner without snapping it. Capturing the grab offset
  /// avoids a jump when the pointer lands near, rather than exactly on, a handle.
  bool beginResize({
    required ChunkV2FileData chunk,
    required WaterRegionData region,
    required SceneRectangleCorner corner,
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
      worldPoint: worldPoint,
      zoom: 1,
      original: waterRegionBounds(region),
      corner: corner,
      materialKey: region.materialKey,
      regionId: region.id,
      snapToGrid: snapToGrid,
      snapToNeighbors: snapToNeighbors,
      expansion: expansion,
    );
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
    _capture(
      chunk: chunk,
      pointer: pointer,
      worldPoint: worldPoint,
      zoom: 1,
      original: waterRegionBounds(region),
      materialKey: region.materialKey,
      regionId: region.id,
      snapToGrid: snapToGrid,
      snapToNeighbors: snapToNeighbors,
      expansion: expansion,
    );
    _refreshCandidate();
    return true;
  }

  void _capture({
    required ChunkV2FileData chunk,
    required int pointer,
    required Offset worldPoint,
    required double zoom,
    Rect? original,
    SceneRectangleCorner? corner,
    required String materialKey,
    required String regionId,
    required bool snapToGrid,
    required bool snapToNeighbors,
    required ChunkV2CollisionExpansion? expansion,
  }) {
    _source = chunk;
    _materialKey = materialKey;
    _regionId = regionId;
    _gesture = SceneRectangleGesture(
      pointer: pointer,
      worldPoint: worldPoint,
      limit: Size(chunk.width.toDouble(), chunk.height.toDouble()),
      snapPolicy: TerrainPolygonSnapPolicy.ownerGridPixels(
        snapToGrid ? chunk.tileSize : 1,
      ),
      neighbors: chunkWholePixelSnapVertices(
        chunk: chunk,
        expansion: expansion,
        excludingWaterId: editingRegionId,
      ),
      snapToNeighbors: snapToNeighbors,
      zoom: zoom,
      original: original,
      corner: corner,
      moving: _moving,
    );
  }

  void update({
    required int pointer,
    required Offset worldPoint,
    required double zoom,
  }) {
    if (_gesture == null) return;
    _gesture!.update(pointer: pointer, worldPoint: worldPoint, zoom: zoom);
    _refreshCandidate();
  }

  void finish({
    required int pointer,
    required Offset worldPoint,
    required double zoom,
  }) {
    if (_gesture == null) return;
    _gesture!.finish(pointer: pointer, worldPoint: worldPoint, zoom: zoom);
    _refreshCandidate();
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
    _gesture!.setBounds(
      Rect.fromLTWH(
        xHalfPixels * .5,
        yHalfPixels * .5,
        widthHalfPixels * .5,
        heightHalfPixels * .5,
      ),
    );
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
    _gesture = null;
    _editedRegion = null;
    _moving = false;
    _candidate = null;
    _error = null;
    return true;
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
