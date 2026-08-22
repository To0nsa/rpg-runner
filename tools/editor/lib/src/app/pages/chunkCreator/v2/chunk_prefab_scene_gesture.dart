import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_prefab_surface_snap.dart';
import '../../../../chunks/chunk_scene_coordinate_policy.dart';
import '../../../../chunks/chunk_v2_composition_commit.dart';
import '../../../../chunks/chunk_v2_composition_operation.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../prefabs/models/models.dart';

enum ChunkPrefabSceneTool { select, place, move }

@immutable
final class ChunkPrefabGestureResult {
  const ChunkPrefabGestureResult({required this.candidate, this.commit});

  final PlacedPrefabDef candidate;
  final ChunkV2CompositionCommit? commit;
}

/// Route-local prefab placement preview and operation-token owner.
///
/// Pointer updates never touch the editor session. Finishing returns at most
/// one existing composition commit for the route to dispatch.
final class ChunkPrefabSceneGesture {
  ChunkPrefabSceneTool _tool = ChunkPrefabSceneTool.select;
  int? _pointer;
  ChunkV2CompositionOperation? _operation;
  PlacedPrefabDef? _candidate;
  Offset _anchorOffset = Offset.zero;
  int? _hiddenSourceIndex;
  String? _hiddenPlacementKey;
  int? _tileSize;
  int? _chunkWidth;
  int? _chunkHeight;
  PrefabV3Def? _prefab;
  ChunkPrefabSurfaceSnapContext? _surfaceSnapContext;
  double _surfaceSnapRadiusWorld = 0;
  bool _surfaceSnapEnabled = false;
  ChunkPrefabSurfaceSnapResult? _surfaceSnapResult;

  ChunkPrefabSceneTool get tool => _tool;
  bool get hasActiveOperation => _pointer != null;
  PlacedPrefabDef? get candidate => _candidate;
  int? get hiddenSourceIndex => _hiddenSourceIndex;
  String? get hiddenPlacementKey => _hiddenPlacementKey;
  ChunkPrefabSurfaceSnapResult? get surfaceSnapResult => _surfaceSnapResult;
  bool get isSurfaceSnapped => _surfaceSnapResult?.snapped ?? false;
  String? get surfaceSnapMessage => _surfaceSnapResult?.message;
  List<List<TerrainPoint>> get previewCollisionLoops =>
      _surfaceSnapResult?.collisionLoops ?? const <List<TerrainPoint>>[];

  void setTool(ChunkPrefabSceneTool tool) {
    if (hasActiveOperation) return;
    _tool = tool;
  }

  bool beginPlace({
    required int pointer,
    required Offset worldPoint,
    required ChunkV2FileData chunk,
    required PrefabV3Def prefab,
    ChunkPrefabSurfaceSnapContext? surfaceSnapContext,
    double surfaceSnapRadiusWorld = 0,
    bool surfaceSnapEnabled = false,
  }) {
    if (hasActiveOperation) return false;
    _pointer = pointer;
    _operation = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
    );
    _tileSize = chunk.tileSize;
    _chunkWidth = chunk.width;
    _chunkHeight = chunk.height;
    _prefab = prefab;
    _surfaceSnapContext = surfaceSnapContext;
    _surfaceSnapRadiusWorld = surfaceSnapRadiusWorld;
    _surfaceSnapEnabled = surfaceSnapEnabled;
    _anchorOffset = Offset.zero;
    _hiddenSourceIndex = null;
    _hiddenPlacementKey = null;
    _candidate = _positioned(
      PlacedPrefabDef(
        prefabId: prefab.id,
        prefabKey: prefab.prefabKey,
        x: 0,
        y: 0,
        scale: surfaceSnapEnabled
            ? ChunkPrefabSurfaceSnap.preferredCompatibleScale(prefab)
            : defaultPrefabPlacementScale,
      ),
      worldPoint,
    );
    return true;
  }

  bool beginMove({
    required int pointer,
    required Offset worldPoint,
    required ChunkV2FileData chunk,
    required ChunkPlacedPrefabSelection selection,
    PrefabV3Def? prefab,
    ChunkPrefabSurfaceSnapContext? surfaceSnapContext,
    double surfaceSnapRadiusWorld = 0,
    bool surfaceSnapEnabled = false,
  }) {
    if (hasActiveOperation) return false;
    _pointer = pointer;
    _operation = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
      sourceIndex: selection.sourceIndex,
      presentationKey: selection.selectionKey,
    );
    _tileSize = chunk.tileSize;
    _chunkWidth = chunk.width;
    _chunkHeight = chunk.height;
    _prefab = prefab;
    _surfaceSnapContext = surfaceSnapContext;
    _surfaceSnapRadiusWorld = surfaceSnapRadiusWorld;
    _surfaceSnapEnabled = surfaceSnapEnabled;
    _anchorOffset = Offset(
      selection.prefab.x - worldPoint.dx,
      selection.prefab.y - worldPoint.dy,
    );
    _hiddenSourceIndex = selection.sourceIndex;
    _hiddenPlacementKey = selection.selectionKey;
    _candidate = selection.prefab;
    if (surfaceSnapEnabled && prefab != null) {
      _candidate = _resolveSurface(selection.prefab);
    }
    return true;
  }

  void update({required int pointer, required Offset worldPoint}) {
    if (_pointer != pointer || _candidate == null) return;
    _candidate = _positioned(_candidate!, worldPoint + _anchorOffset);
  }

  ChunkPrefabGestureResult? finish({
    required int pointer,
    required Offset worldPoint,
  }) {
    if (_pointer != pointer || _candidate == null || _operation == null) {
      return null;
    }
    update(pointer: pointer, worldPoint: worldPoint);
    final candidate = _candidate!;
    final commit = _operation!.buildPrefab(candidate: candidate);
    _clear();
    return ChunkPrefabGestureResult(candidate: candidate, commit: commit);
  }

  bool cancel() {
    if (!hasActiveOperation) return false;
    _clear();
    return true;
  }

  PlacedPrefabDef _positioned(PlacedPrefabDef prefab, Offset point) {
    final tileSize = _tileSize;
    if (tileSize == null) return prefab;
    final positioned = prefab.copyWith(
      x: quantizeChunkPrefabGestureCoordinate(
        point.dx,
        tileSize: tileSize,
        snapToGrid: prefab.snapToGrid,
      ),
      y: quantizeChunkPrefabGestureCoordinate(
        point.dy,
        tileSize: tileSize,
        snapToGrid: prefab.snapToGrid,
      ),
    );
    return _resolveSurface(positioned);
  }

  PlacedPrefabDef _resolveSurface(PlacedPrefabDef positioned) {
    final surfacePrefab = _prefab;
    final chunkWidth = _chunkWidth;
    final chunkHeight = _chunkHeight;
    if (!_surfaceSnapEnabled ||
        surfacePrefab == null ||
        chunkWidth == null ||
        chunkHeight == null) {
      _surfaceSnapResult = null;
      return positioned;
    }
    final result = ChunkPrefabSurfaceSnap.resolve(
      placement: positioned,
      prefab: surfacePrefab,
      context: _surfaceSnapContext,
      snapRadiusWorld: _surfaceSnapRadiusWorld,
      chunkWidth: chunkWidth,
      chunkHeight: chunkHeight,
    );
    _surfaceSnapResult = result;
    return result.placement;
  }

  void _clear() {
    _pointer = null;
    _operation = null;
    _candidate = null;
    _anchorOffset = Offset.zero;
    _hiddenSourceIndex = null;
    _hiddenPlacementKey = null;
    _tileSize = null;
    _chunkWidth = null;
    _chunkHeight = null;
    _prefab = null;
    _surfaceSnapContext = null;
    _surfaceSnapRadiusWorld = 0;
    _surfaceSnapEnabled = false;
    _surfaceSnapResult = null;
  }
}
