import 'dart:ui';

import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/terrain/water_region.dart';

import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_water_commit.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_polygon_scene_projection.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../../../terrain_authoring/terrain_vertex_snap.dart';

/// Route-local rectangle draft. Pointer release keeps a reviewable candidate;
/// only the workspace may publish its stale-checked commit through the plugin.
final class ChunkWaterDrawing {
  ChunkV2FileData? _source;
  int? _pointer;
  Offset? _start;
  Offset? _end;
  String? _materialKey;
  String? _regionId;
  List<TerrainSourceVertexDef> _neighbors = const [];
  TerrainPolygonSnapPolicy _snapPolicy =
      TerrainPolygonSnapPolicy.ownerGridPixels(1);
  bool _snapToNeighbors = true;
  WaterRegionData? _candidate;
  String? _error;
  Offset? _snappedNeighbor;

  bool get hasActiveOperation => _source != null;
  bool get isDragging => _pointer != null;
  Rect? get bounds => _start == null ? null : Rect.fromPoints(_start!, _end!);
  WaterRegionData? get candidate => _candidate;
  String? get error => _error;
  Offset? get snappedNeighbor => _snappedNeighbor;

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
    _source = chunk;
    _pointer = pointer;
    _materialKey = materialKey;
    _regionId = regionId ?? nextChunkWaterId(chunk.waterRegions);
    _snapPolicy = TerrainPolygonSnapPolicy.ownerGridPixels(
      snapToGrid ? chunk.tileSize : 1,
    );
    _snapToNeighbors = snapToNeighbors;
    // Water's source contract is whole pixels. Fractional collision vertices
    // must not silently move when used as exact snap targets.
    _neighbors =
        [
              ...chunk.collisionShapes.expand((shape) => shape.vertices),
              for (final shape in expansion?.expandedPrefabShapes ?? [])
                for (final vertex in shape.vertices)
                  if (vertex.xTicks % terrainPhysicsTicksPerWorldUnit == 0 &&
                      vertex.yTicks % terrainPhysicsTicksPerWorldUnit == 0)
                    TerrainSourceVertexDef(
                      xHalfPixels:
                          vertex.xTicks ~/ terrainPhysicsTicksPerWorldUnit * 2,
                      yHalfPixels:
                          vertex.yTicks ~/ terrainPhysicsTicksPerWorldUnit * 2,
                    ),
              for (final region in chunk.waterRegions)
                for (final x in [region.x, region.x + region.width])
                  for (final y in [region.y, region.y + region.height])
                    TerrainSourceVertexDef(
                      xHalfPixels: x * 2,
                      yHalfPixels: y * 2,
                    ),
            ]
            .where(
              (vertex) =>
                  vertex.xHalfPixels.isEven &&
                  vertex.yHalfPixels.isEven &&
                  vertex.xHalfPixels >= 0 &&
                  vertex.xHalfPixels <= chunk.width * 2 &&
                  vertex.yHalfPixels >= 0 &&
                  vertex.yHalfPixels <= chunk.height * 2,
            )
            .toList(growable: false);
    _start = _snap(worldPoint, zoom);
    _end = _start;
    _refreshCandidate();
    return true;
  }

  void update({
    required int pointer,
    required Offset worldPoint,
    required double zoom,
  }) {
    if (_pointer != pointer) return;
    _end = _snap(worldPoint, zoom);
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
    if (_source == null || isDragging) return false;
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
    if (isDragging || _candidate == null || _error != null) return null;
    return ChunkWaterCommit(
      expectedRevision: _source!.revision,
      regions: [..._source!.waterRegions, _candidate!],
    );
  }

  bool cancel() {
    if (!hasActiveOperation) return false;
    _source = null;
    _pointer = null;
    _start = null;
    _end = null;
    _candidate = null;
    _error = null;
    _snappedNeighbor = null;
    _neighbors = const [];
    return true;
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
    _error = chunkWaterValidationMessage(_source!, [
      ..._source!.waterRegions,
      _candidate!,
    ]);
  }
}
