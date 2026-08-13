import 'package:flutter/material.dart';

import '../../../../chunks/chunk_domain_models.dart';
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
  int? _tileSize;

  ChunkPrefabSceneTool get tool => _tool;
  bool get hasActiveOperation => _pointer != null;
  PlacedPrefabDef? get candidate => _candidate;
  int? get hiddenSourceIndex => _hiddenSourceIndex;

  void setTool(ChunkPrefabSceneTool tool) {
    if (hasActiveOperation) return;
    _tool = tool;
  }

  bool beginPlace({
    required int pointer,
    required Offset worldPoint,
    required ChunkV2FileData chunk,
    required PrefabV3Def prefab,
  }) {
    if (hasActiveOperation) return false;
    _pointer = pointer;
    _operation = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
    );
    _tileSize = chunk.tileSize;
    _anchorOffset = Offset.zero;
    _hiddenSourceIndex = null;
    _candidate = _positioned(
      PlacedPrefabDef(
        prefabId: prefab.id,
        prefabKey: prefab.prefabKey,
        x: 0,
        y: 0,
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
    _anchorOffset = Offset(
      selection.prefab.x - worldPoint.dx,
      selection.prefab.y - worldPoint.dy,
    );
    _hiddenSourceIndex = selection.sourceIndex;
    _candidate = selection.prefab;
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
    return prefab.copyWith(
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
  }

  void _clear() {
    _pointer = null;
    _operation = null;
    _candidate = null;
    _anchorOffset = Offset.zero;
    _hiddenSourceIndex = null;
    _tileSize = null;
  }
}
