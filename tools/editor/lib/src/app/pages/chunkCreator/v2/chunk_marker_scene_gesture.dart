import 'package:flutter/material.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_scene_coordinate_policy.dart';
import '../../../../chunks/chunk_v2_composition_commit.dart';
import '../../../../chunks/chunk_v2_composition_operation.dart';
import '../../../../chunks/chunk_v2_file_data.dart';

enum ChunkMarkerSceneTool { select, place, move }

@immutable
final class ChunkMarkerGestureResult {
  const ChunkMarkerGestureResult({required this.candidate, this.commit});

  final PlacedMarkerDef candidate;
  final ChunkV2CompositionCommit? commit;
}

/// Route-local authored-marker anchor preview and operation-token owner.
final class ChunkMarkerSceneGesture {
  ChunkMarkerSceneTool _tool = ChunkMarkerSceneTool.select;
  int? _pointer;
  ChunkV2CompositionOperation? _operation;
  PlacedMarkerDef? _candidate;
  Offset _anchorOffset = Offset.zero;
  int? _hiddenSourceIndex;

  ChunkMarkerSceneTool get tool => _tool;
  bool get hasActiveOperation => _pointer != null;
  PlacedMarkerDef? get candidate => _candidate;
  int? get hiddenSourceIndex => _hiddenSourceIndex;

  void setTool(ChunkMarkerSceneTool tool) {
    if (hasActiveOperation) return;
    _tool = tool;
  }

  bool beginPlace({
    required int pointer,
    required Offset worldPoint,
    required ChunkV2FileData chunk,
    required String markerId,
  }) {
    if (hasActiveOperation) return false;
    _pointer = pointer;
    _operation = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.markers,
    );
    _anchorOffset = Offset.zero;
    _hiddenSourceIndex = null;
    _candidate = _positioned(
      PlacedMarkerDef(markerId: markerId, x: 0, y: 0),
      worldPoint,
    );
    return true;
  }

  bool beginMove({
    required int pointer,
    required Offset worldPoint,
    required ChunkV2FileData chunk,
    required ChunkPlacedMarkerSelection selection,
  }) {
    if (hasActiveOperation) return false;
    _pointer = pointer;
    _operation = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.markers,
      sourceIndex: selection.sourceIndex,
      presentationKey: selection.selectionKey,
    );
    _anchorOffset = Offset(
      selection.marker.x - worldPoint.dx,
      selection.marker.y - worldPoint.dy,
    );
    _hiddenSourceIndex = selection.sourceIndex;
    _candidate = selection.marker;
    return true;
  }

  void update({required int pointer, required Offset worldPoint}) {
    if (_pointer != pointer || _candidate == null) return;
    _candidate = _positioned(_candidate!, worldPoint + _anchorOffset);
  }

  ChunkMarkerGestureResult? finish({
    required int pointer,
    required Offset worldPoint,
  }) {
    if (_pointer != pointer || _candidate == null || _operation == null) {
      return null;
    }
    update(pointer: pointer, worldPoint: worldPoint);
    final candidate = _candidate!;
    final commit = _operation!.buildMarker(candidate: candidate);
    _clear();
    return ChunkMarkerGestureResult(candidate: candidate, commit: commit);
  }

  bool cancel() {
    if (!hasActiveOperation) return false;
    _clear();
    return true;
  }

  PlacedMarkerDef _positioned(PlacedMarkerDef marker, Offset point) =>
      marker.copyWith(
        x: quantizeChunkSceneCoordinate(point.dx, step: 1),
        y: quantizeChunkSceneCoordinate(point.dy, step: 1),
      );

  void _clear() {
    _pointer = null;
    _operation = null;
    _candidate = null;
    _anchorOffset = Offset.zero;
    _hiddenSourceIndex = null;
  }
}
