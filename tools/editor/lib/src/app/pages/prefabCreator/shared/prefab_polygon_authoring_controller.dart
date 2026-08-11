import 'package:flutter/foundation.dart';

import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../../prefabs/domain/prefab_v3_collision_commit.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_store.dart';
import '../../../../prefabs/validation/prefab_validation.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_polygon_scene_projection.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';

/// Prefab-route state for one polygon collision owner.
///
/// Selection, tools, drafts, gesture previews, and rejected diagnostics remain
/// local. Only an accepted owner-reviewed semantic commit is dispatched to the
/// plugin/session boundary, producing one undo entry and one revision bump.
/// The controller requires the current Prefab-v3 document; fail-closed legacy
/// or missing-source sessions cannot activate polygon authoring.
final class PrefabPolygonAuthoringController extends ChangeNotifier {
  PrefabPolygonAuthoringController({
    required EditorSessionController session,
    required String prefabKey,
    TerrainPolygonSnapPolicy snapPolicy =
        const TerrainPolygonSnapPolicy.halfPixel(),
    PrefabV3CollisionCommitPolicy commitPolicy =
        const PrefabV3CollisionCommitPolicy(),
  }) : _session = session,
       _prefabKey = prefabKey,
       _snapPolicy = snapPolicy,
       _commitPolicy = commitPolicy,
       _reducer = TerrainPolygonInteractionReducer(
         sourcePath: PrefabStore.prefabDefsPath,
         ownerKey: prefabKey,
         shapeIdPrefix: 'collision',
       ),
       _state = TerrainPolygonInteractionState(
         shapes: _requirePrefab(session, prefabKey).collisionShapes,
       ) {
    _observedDocument = session.document;
    _session.addListener(_handleSessionChanged);
  }

  final EditorSessionController _session;
  final String _prefabKey;
  TerrainPolygonSnapPolicy _snapPolicy;
  final PrefabV3CollisionCommitPolicy _commitPolicy;
  final TerrainPolygonInteractionReducer _reducer;

  TerrainPolygonInteractionState _state;
  List<PrefabValidationIssue> _issues = const <PrefabValidationIssue>[];
  AuthoringDocument? _observedDocument;
  bool _isDispatching = false;

  String get prefabKey => _prefabKey;
  TerrainPolygonInteractionState get state => _state;
  TerrainPolygonSceneProjection get sceneProjection =>
      TerrainPolygonSceneProjection.fromInteraction(_state);
  List<PrefabValidationIssue> get issues => _issues;
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

  PrefabV3Def get prefab => _requirePrefab(_session, _prefabKey);

  PrefabV3VisualBounds? get visualBounds {
    final document = _session.document;
    return document is PrefabV3Document
        ? document.visualBoundsByPrefabKey[_prefabKey]
        : null;
  }

  void setTool(TerrainPolygonTool tool) {
    _replaceLocalState(_reducer.setTool(_state, tool));
  }

  /// Changes the page-local authoring grid without creating session history.
  ///
  /// An active preview is cancelled first so a gesture cannot start under one
  /// grid and commit under another.
  void setSnapPolicy(TerrainPolygonSnapPolicy snapPolicy) {
    if (snapPolicy.stepHalfPixels == _snapPolicy.stepHalfPixels) return;
    if (_state.hasActiveOperation) {
      _state = _reducer.cancelActiveOperation(_state);
    }
    _snapPolicy = snapPolicy;
    _issues = const <PrefabValidationIssue>[];
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

  /// Gives an active draft/gesture first refusal; otherwise undoes one session
  /// document commit and synchronizes the local projection.
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
    if (document is! PrefabV3Document) {
      _rejectLocally(
        attemptedState,
        const PrefabValidationIssue(
          code: 'prefab_polygon_document_unavailable',
          message:
              'The prefab-v3 current document is no longer loaded; reload '
              'before committing collision geometry.',
          sourcePath: PrefabStore.prefabDefsPath,
        ),
      );
      return false;
    }
    final bounds = document.visualBoundsByPrefabKey[_prefabKey];
    final ownerResult = _commitPolicy.apply(
      data: document.data,
      prefabKey: _prefabKey,
      commit: commit,
      sourceWidthPx: bounds?.widthPx,
      sourceHeightPx: bounds?.heightPx,
      sourcePath: PrefabStore.prefabDefsPath,
    );
    if (!ownerResult.accepted || !ownerResult.changed) {
      _state = attemptedState;
      _issues = ownerResult.issues;
      notifyListeners();
      return false;
    }

    final beforeDocument = document;
    _isDispatching = true;
    try {
      _session.applyCommand(
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{'prefabKey': _prefabKey, 'commit': commit},
        ),
      );
    } finally {
      _isDispatching = false;
    }
    _observedDocument = _session.document;
    if (identical(_session.document, beforeDocument)) {
      _rejectLocally(
        attemptedState,
        const PrefabValidationIssue(
          code: 'prefab_polygon_plugin_command_rejected',
          message:
              'The prefab plugin rejected an owner-reviewed polygon commit; '
              'reload the current document before retrying.',
          sourcePath: PrefabStore.prefabDefsPath,
        ),
      );
      return false;
    }

    final updatedPrefab = _requirePrefab(_session, _prefabKey);
    _state = _stateFromShapes(
      updatedPrefab.collisionShapes,
      preferredSelection: result.state.selection,
      preferredTool: result.state.tool,
    );
    _issues = _sortedIssues(<PrefabValidationIssue>[
      ..._interactionIssues(result, accepted: true),
      ...ownerResult.issues,
    ]);
    notifyListeners();
    return true;
  }

  void _rejectLocally(
    TerrainPolygonInteractionState attemptedState,
    PrefabValidationIssue issue,
  ) {
    _state = attemptedState;
    _issues = List<PrefabValidationIssue>.unmodifiable(<PrefabValidationIssue>[
      issue,
    ]);
    notifyListeners();
  }

  List<PrefabValidationIssue> _interactionIssues(
    TerrainPolygonInteractionResult result, {
    required bool accepted,
  }) => _sortedIssues(
    result.diagnostics.map(
      (diagnostic) => PrefabValidationIssue(
        code: diagnostic.code,
        message: diagnostic.message,
        severity: accepted
            ? PrefabValidationSeverity.warning
            : PrefabValidationSeverity.error,
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
    _issues = const <PrefabValidationIssue>[];
    notifyListeners();
  }

  void _handleSessionChanged() {
    if (_isDispatching) return;
    final document = _session.document;
    if (identical(document, _observedDocument)) return;
    _observedDocument = document;
    if (document is! PrefabV3Document) return;
    final owner = _findPrefab(document.data, _prefabKey);
    if (owner == null) return;
    _state = _stateFromShapes(
      owner.collisionShapes,
      preferredSelection: _state.selection,
      preferredTool: _state.tool,
    );
    _issues = const <PrefabValidationIssue>[];
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

PrefabV3Def _requirePrefab(EditorSessionController session, String prefabKey) {
  final document = session.document;
  if (document is! PrefabV3Document) {
    throw StateError(
      'Prefab polygon authoring requires a loaded PrefabV3Document.',
    );
  }
  final prefab = _findPrefab(document.data, prefabKey);
  if (prefab == null) {
    throw StateError(
      'Prefab $prefabKey does not exist in the current document.',
    );
  }
  return prefab;
}

PrefabV3Def? _findPrefab(PrefabV3FileData data, String prefabKey) {
  for (final prefab in data.prefabs) {
    if (prefab.prefabKey == prefabKey) return prefab;
  }
  return null;
}

List<PrefabValidationIssue> _sortedIssues(
  Iterable<PrefabValidationIssue> issues,
) {
  final sorted = List<PrefabValidationIssue>.of(issues)
    ..sort((left, right) {
      var order = left.sourcePath.compareTo(right.sourcePath);
      if (order != 0) return order;
      order = left.shapeId.compareTo(right.shapeId);
      if (order != 0) return order;
      order = left.elementIndex.compareTo(right.elementIndex);
      if (order != 0) return order;
      order = left.code.compareTo(right.code);
      return order != 0 ? order : left.message.compareTo(right.message);
    });
  return List<PrefabValidationIssue>.unmodifiable(sorted);
}
