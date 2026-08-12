import 'package:flutter/foundation.dart';

import '../../../../chunks/chunk_domain_plugin.dart';
import '../../../../chunks/chunk_v2_collision_commit.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../../../domain/authoring_types.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_polygon_scene_projection.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';

/// Chunk-route state for one direct chunk-local polygon owner.
///
/// Drafts, gestures, selection, tools, and rejection diagnostics remain local.
/// Only an accepted owner-reviewed semantic commit reaches session history.
/// Construction requires the explicit chunk-v2 current document, so normal
/// chunk-v1 sessions cannot activate this controller before source cutover.
final class ChunkPolygonAuthoringController extends ChangeNotifier {
  ChunkPolygonAuthoringController({
    required EditorSessionController session,
    required String chunkKey,
    TerrainPolygonSnapPolicy snapPolicy =
        const TerrainPolygonSnapPolicy.halfPixel(),
    ChunkV2CollisionCommitPolicy commitPolicy =
        const ChunkV2CollisionCommitPolicy(),
  }) : _session = session,
       _chunkKey = chunkKey,
       _snapPolicy = snapPolicy,
       _commitPolicy = commitPolicy,
       // `ground_` is reserved by the temporary legacy projection for migrated
       // bottom-band terrain; direct editor shapes must remain ordinary solids.
       _reducer = TerrainPolygonInteractionReducer(
         sourcePath: _requireSourcePath(session, chunkKey),
         ownerKey: chunkKey,
         shapeIdPrefix: 'solid',
       ),
       _state = TerrainPolygonInteractionState(
         shapes: _requireChunk(session, chunkKey).collisionShapes,
       ) {
    _observedDocument = session.document;
    _session.addListener(_handleSessionChanged);
  }

  final EditorSessionController _session;
  final String _chunkKey;
  TerrainPolygonSnapPolicy _snapPolicy;
  final ChunkV2CollisionCommitPolicy _commitPolicy;
  final TerrainPolygonInteractionReducer _reducer;

  TerrainPolygonInteractionState _state;
  List<ValidationIssue> _issues = const <ValidationIssue>[];
  AuthoringDocument? _observedDocument;
  bool _isDispatching = false;

  String get chunkKey => _chunkKey;
  TerrainPolygonInteractionState get state => _state;
  TerrainPolygonSceneProjection get sceneProjection =>
      TerrainPolygonSceneProjection.fromInteraction(_state);
  List<ValidationIssue> get issues => _issues;
  TerrainPolygonSnapPolicy get snapPolicy => _snapPolicy;
  bool get hasActiveOperation => _state.hasActiveOperation;
  bool get canUndo {
    if (_state.gesture != null) return true;
    if (_state.draft != null) return _state.canUndoDraftVertexEdit;
    return _session.canUndo;
  }

  bool get canRedo {
    if (_state.gesture != null) return false;
    if (_state.draft != null) return _state.canRedoDraftVertexEdit;
    return _session.canRedo;
  }

  ChunkV2FileData get chunk => _requireChunk(_session, _chunkKey);

  void setTool(TerrainPolygonTool tool) {
    _replaceLocalState(_reducer.setTool(_state, tool));
  }

  void setSnapPolicy(TerrainPolygonSnapPolicy snapPolicy) {
    if (snapPolicy.stepHalfPixels == _snapPolicy.stepHalfPixels) return;
    if (_state.hasActiveOperation) {
      _state = _reducer.cancelActiveOperation(_state);
    }
    _snapPolicy = snapPolicy;
    _issues = const <ValidationIssue>[];
    notifyListeners();
  }

  void select(TerrainPolygonSelection? selection) {
    _replaceLocalState(_reducer.select(_state, selection));
  }

  void selectAt({
    required TerrainPolygonScenePoint point,
    required double vertexRadiusHalfPixels,
    required double edgeRadiusHalfPixels,
    bool includeShapeFill = true,
  }) {
    select(
      TerrainPolygonSceneHitTest.hitTest(
        projection: sceneProjection,
        point: point,
        vertexRadiusHalfPixels: vertexRadiusHalfPixels,
        edgeRadiusHalfPixels: edgeRadiusHalfPixels,
        includeShapeFill: includeShapeFill,
      ),
    );
  }

  void beginCreatePolygon({
    TerrainSourceCollisionMode collisionMode = TerrainSourceCollisionMode.solid,
    String? surfaceKind,
    String? materialKey,
  }) {
    _replaceLocalState(
      _reducer.beginCreatePolygon(
        _state,
        collisionMode: collisionMode,
        surfaceKind: surfaceKind,
        materialKey: materialKey,
      ),
    );
  }

  bool beginCreateRectangle({
    required int pointer,
    required TerrainPolygonScenePoint point,
  }) {
    final next = _reducer.beginCreateRectangle(
      _state,
      pointer: pointer,
      startPointer: _snapPoint(point),
    );
    final started = !identical(next, _state);
    _replaceLocalState(next);
    return started;
  }

  void addDraftVertex(TerrainPolygonScenePoint point) {
    _replaceLocalState(
      _reducer.addDraftVertex(
        _state,
        rawVertex: _snapPoint(point),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      ),
    );
  }

  bool saveDraft() {
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.saveDraft(attemptedState),
      attemptedState: attemptedState,
    );
  }

  bool beginDraftGesture({
    required int pointer,
    required TerrainPolygonScenePoint point,
    required double vertexRadiusHalfPixels,
    required double edgeRadiusHalfPixels,
  }) {
    if (_state.draft == null || _state.gesture != null) return false;
    final sourcePoint = _snapPoint(point);
    var next = _state;
    switch (_state.tool) {
      case TerrainPolygonTool.moveVertex:
        final vertexIndex = TerrainPolygonSceneHitTest.hitTestDraftVertex(
          projection: sceneProjection,
          point: point,
          radiusHalfPixels: vertexRadiusHalfPixels,
        );
        if (vertexIndex != null) {
          next = _reducer.beginMoveDraftVertex(
            _state,
            pointer: pointer,
            vertexIndex: vertexIndex,
            startPointer: sourcePoint,
          );
        }
        break;
      case TerrainPolygonTool.insertVertex:
        final edgeIndex = TerrainPolygonSceneHitTest.hitTestDraftEdge(
          projection: sceneProjection,
          point: point,
          radiusHalfPixels: edgeRadiusHalfPixels,
        );
        if (edgeIndex != null) {
          next = _reducer.beginInsertDraftVertex(
            _state,
            pointer: pointer,
            edgeIndex: edgeIndex,
            rawVertex: sourcePoint,
            snap: const TerrainPolygonSnapPolicy.halfPixel(),
          );
        }
        break;
      case TerrainPolygonTool.select:
      case TerrainPolygonTool.createPolygon:
      case TerrainPolygonTool.createRectangle:
      case TerrainPolygonTool.translateShape:
        break;
    }
    final started = !identical(next, _state);
    _replaceLocalState(next);
    return started;
  }

  bool beginGesture({
    required int pointer,
    required TerrainPolygonScenePoint point,
  }) {
    final selection = _state.selection;
    if (selection == null || _state.hasActiveOperation) return false;
    final sourcePoint = _snapPoint(point);
    final next = switch (_state.tool) {
      TerrainPolygonTool.moveVertex
          when selection.kind == TerrainPolygonSelectionKind.vertex =>
        _reducer.beginMoveVertex(
          _state,
          pointer: pointer,
          shapeId: selection.shapeId,
          vertexIndex: selection.elementIndex!,
          startPointer: sourcePoint,
        ),
      TerrainPolygonTool.translateShape => _reducer.beginTranslateShape(
        _state,
        pointer: pointer,
        shapeId: selection.shapeId,
        startPointer: sourcePoint,
      ),
      TerrainPolygonTool.insertVertex
          when selection.kind == TerrainPolygonSelectionKind.edge =>
        _reducer.beginInsertVertex(
          _state,
          pointer: pointer,
          shapeId: selection.shapeId,
          edgeIndex: selection.elementIndex!,
          rawVertex: sourcePoint,
          snap: const TerrainPolygonSnapPolicy.halfPixel(),
        ),
      _ => _state,
    };
    final started = !identical(next, _state);
    _replaceLocalState(next);
    return started;
  }

  void updateGesture({
    required int pointer,
    required TerrainPolygonScenePoint point,
  }) {
    _replaceLocalState(
      _reducer.updateGesture(
        _state,
        pointer: pointer,
        currentPointer: _snapPoint(point),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      ),
    );
  }

  bool commitGesture(int pointer) {
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.commitGesture(attemptedState, pointer: pointer),
      attemptedState: attemptedState,
    );
  }

  void cancelActiveOperation() {
    _replaceLocalState(_reducer.cancelActiveOperation(_state));
  }

  bool deleteSelection() {
    final selection = _state.selection;
    if (selection == null || _state.hasActiveOperation) return false;
    final attemptedState = _state;
    final result = switch (selection.kind) {
      TerrainPolygonSelectionKind.vertex => _reducer.deleteSelectedVertex(
        attemptedState,
      ),
      TerrainPolygonSelectionKind.shape => _reducer.deleteSelectedShape(
        attemptedState,
      ),
      TerrainPolygonSelectionKind.edge => null,
    };
    if (result == null) return false;
    return _applyInteractionResult(result, attemptedState: attemptedState);
  }

  bool editSelectedVertex(TerrainSourceVertexDef vertex) {
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.editSelectedVertex(attemptedState, vertex: vertex),
      attemptedState: attemptedState,
    );
  }

  bool duplicateSelectedShape({
    required int deltaXHalfPixels,
    required int deltaYHalfPixels,
  }) {
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.duplicateSelectedShape(
        attemptedState,
        deltaXHalfPixels: deltaXHalfPixels,
        deltaYHalfPixels: deltaYHalfPixels,
      ),
      attemptedState: attemptedState,
    );
  }

  bool normalizeSelectedShape() {
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.normalizeSelectedShape(attemptedState),
      attemptedState: attemptedState,
    );
  }

  bool editSelectedShapeMetadata({
    required TerrainSourceCollisionMode collisionMode,
    String? surfaceKind,
    String? materialKey,
  }) {
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.editSelectedShapeMetadata(
        attemptedState,
        collisionMode: collisionMode,
        surfaceKind: surfaceKind,
        materialKey: materialKey,
      ),
      attemptedState: attemptedState,
    );
  }

  bool undo() {
    if (_state.gesture != null) {
      cancelActiveOperation();
      return true;
    }
    if (_state.draft != null) {
      final next = _reducer.undoDraftVertexEdit(_state);
      final changed = !identical(next, _state);
      _replaceLocalState(next);
      return changed;
    }
    if (!_session.canUndo) return false;
    _session.undo();
    return true;
  }

  bool redo() {
    if (_state.gesture != null) return false;
    if (_state.draft != null) {
      final next = _reducer.redoDraftVertexEdit(_state);
      final changed = !identical(next, _state);
      _replaceLocalState(next);
      return changed;
    }
    if (!_session.canRedo) return false;
    _session.redo();
    return true;
  }

  TerrainSourceVertexDef _snapPoint(TerrainPolygonScenePoint point) =>
      _snapPolicy.snapFractionalVertex(
        xHalfPixels: point.xHalfPixels,
        yHalfPixels: point.yHalfPixels,
      );

  bool _applyInteractionResult(
    TerrainPolygonInteractionResult result, {
    required TerrainPolygonInteractionState attemptedState,
  }) {
    if (!result.accepted) {
      _state = result.state;
      _issues = _interactionIssues(result, accepted: false);
      notifyListeners();
      return false;
    }
    final commit = result.commit;
    if (commit == null) {
      final stateChanged = !identical(result.state, attemptedState);
      _state = result.state;
      _issues = _interactionIssues(result, accepted: true);
      notifyListeners();
      return stateChanged;
    }

    final document = _session.document;
    if (document is! ChunkV2Document) {
      _rejectLocally(
        attemptedState,
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_polygon_document_unavailable',
          message:
              'The chunk-v2 current document is no longer loaded; reload '
              'before committing collision geometry.',
        ),
      );
      return false;
    }
    final currentChunk = _findChunk(document, _chunkKey);
    if (currentChunk == null) {
      _rejectLocally(
        attemptedState,
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_polygon_owner_missing',
          message: 'Chunk $_chunkKey no longer exists in the current document.',
          sourcePath: document.sourcePathByChunkKey[_chunkKey],
        ),
      );
      return false;
    }
    final sourcePath = document.sourcePathByChunkKey[_chunkKey] ?? _chunkKey;
    final ownerResult = _commitPolicy.apply(
      chunk: currentChunk,
      commit: commit,
      sourcePath: sourcePath,
      chunkIndex: document.chunks.indexOf(currentChunk),
    );
    if (!ownerResult.accepted || !ownerResult.changed) {
      _state = attemptedState;
      _issues = _sortedIssues(ownerResult.issues);
      notifyListeners();
      return false;
    }

    final beforeDocument = document;
    _isDispatching = true;
    try {
      _session.applyCommand(
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkPolygonCommandKind,
          payload: <String, Object?>{'chunkKey': _chunkKey, 'commit': commit},
        ),
      );
    } finally {
      _isDispatching = false;
    }
    _observedDocument = _session.document;
    if (identical(_session.document, beforeDocument)) {
      _rejectLocally(
        attemptedState,
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_polygon_plugin_command_rejected',
          message:
              'The chunk plugin rejected an owner-reviewed polygon commit; '
              'reload the current document before retrying.',
          sourcePath: sourcePath,
        ),
      );
      return false;
    }

    final updatedChunk = _requireChunk(_session, _chunkKey);
    _state = _stateFromShapes(
      updatedChunk.collisionShapes,
      preferredSelection: result.state.selection,
      preferredTool: result.state.tool,
    );
    _issues = _sortedIssues(<ValidationIssue>[
      ..._interactionIssues(result, accepted: true),
      ...ownerResult.issues,
    ]);
    notifyListeners();
    return true;
  }

  void _rejectLocally(
    TerrainPolygonInteractionState attemptedState,
    ValidationIssue issue,
  ) {
    _state = attemptedState;
    _issues = List<ValidationIssue>.unmodifiable(<ValidationIssue>[issue]);
    notifyListeners();
  }

  List<ValidationIssue> _interactionIssues(
    TerrainPolygonInteractionResult result, {
    required bool accepted,
  }) => _sortedIssues(
    result.diagnostics.map(
      (diagnostic) => ValidationIssue(
        severity: accepted
            ? ValidationSeverity.warning
            : ValidationSeverity.error,
        code: diagnostic.code,
        message: diagnostic.message,
        sourcePath: diagnostic.sourcePath,
        shapeId: diagnostic.shapeId,
        elementIndex: diagnostic.elementIndex,
      ),
    ),
  );

  void _replaceLocalState(TerrainPolygonInteractionState next) {
    final stateChanged = !identical(next, _state);
    final issuesChanged = _issues.isNotEmpty;
    if (!stateChanged && !issuesChanged) return;
    _state = next;
    _issues = const <ValidationIssue>[];
    notifyListeners();
  }

  void _handleSessionChanged() {
    if (_isDispatching) return;
    final document = _session.document;
    if (identical(document, _observedDocument)) return;
    _observedDocument = document;
    if (document is! ChunkV2Document) return;
    final owner = _findChunk(document, _chunkKey);
    if (owner == null) return;
    _state = _stateFromShapes(
      owner.collisionShapes,
      preferredSelection: _state.selection,
      preferredTool: _state.tool,
    );
    _issues = const <ValidationIssue>[];
    notifyListeners();
  }

  TerrainPolygonInteractionState _stateFromShapes(
    Iterable<TerrainSourceShapeDef> shapes, {
    required TerrainPolygonSelection? preferredSelection,
    required TerrainPolygonTool preferredTool,
  }) {
    try {
      return TerrainPolygonInteractionState(
        shapes: shapes,
        selection: preferredSelection,
        tool: preferredTool,
      );
    } on ArgumentError {
      return TerrainPolygonInteractionState(
        shapes: shapes,
        tool: preferredTool,
      );
    }
  }

  @override
  void dispose() {
    _session.removeListener(_handleSessionChanged);
    super.dispose();
  }
}

ChunkV2FileData _requireChunk(
  EditorSessionController session,
  String chunkKey,
) {
  final document = session.document;
  if (document is! ChunkV2Document) {
    throw StateError(
      'Chunk polygon authoring requires a loaded ChunkV2Document.',
    );
  }
  final chunk = _findChunk(document, chunkKey);
  if (chunk == null) {
    throw StateError('Chunk $chunkKey does not exist in the current document.');
  }
  return chunk;
}

String _requireSourcePath(EditorSessionController session, String chunkKey) {
  final document = session.document;
  if (document is! ChunkV2Document) {
    throw StateError(
      'Chunk polygon authoring requires a loaded ChunkV2Document.',
    );
  }
  final sourcePath = document.sourcePathByChunkKey[chunkKey];
  if (sourcePath == null || sourcePath.isEmpty) {
    throw StateError('Chunk $chunkKey has no current source path.');
  }
  return sourcePath;
}

ChunkV2FileData? _findChunk(ChunkV2Document document, String chunkKey) {
  for (final chunk in document.chunks) {
    if (chunk.chunkKey == chunkKey) return chunk;
  }
  return null;
}

List<ValidationIssue> _sortedIssues(Iterable<ValidationIssue> issues) {
  final sorted = List<ValidationIssue>.of(issues)
    ..sort((left, right) {
      var order = (left.sourcePath ?? '').compareTo(right.sourcePath ?? '');
      if (order != 0) return order;
      order = (left.shapeId ?? '').compareTo(right.shapeId ?? '');
      if (order != 0) return order;
      order = (left.elementIndex ?? -1).compareTo(right.elementIndex ?? -1);
      if (order != 0) return order;
      order = left.code.compareTo(right.code);
      return order != 0 ? order : left.message.compareTo(right.message);
    });
  return List<ValidationIssue>.unmodifiable(sorted);
}
