import 'dart:math' as math;

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

final TerrainPolygonSnapPolicy _prefabCollisionSnapPolicy =
    TerrainPolygonSnapPolicy.ownerGridPixels(1);

/// Prefab-route state for one polygon collision owner.
///
/// Selection, tools, drafts, gesture previews, and rejected diagnostics remain
/// local. Only an accepted owner-reviewed semantic commit is dispatched to the
/// plugin/session boundary, producing one undo entry and one revision bump.
/// All pointer-authored collision coordinates snap to whole source pixels.
/// The controller requires the current Prefab-v3 document; fail-closed legacy
/// or missing-source sessions cannot activate polygon authoring.
final class PrefabPolygonAuthoringController extends ChangeNotifier {
  PrefabPolygonAuthoringController({
    required EditorSessionController session,
    required String prefabKey,
    String? newShapeSurfaceKind,
    String? newShapeMaterialKey,
    TerrainSourceCollisionMode newShapeCollisionMode =
        TerrainSourceCollisionMode.solid,
    PrefabV3CollisionCommitPolicy commitPolicy =
        const PrefabV3CollisionCommitPolicy(),
  }) : _session = session,
       _prefabKey = prefabKey,
       _newShapeSurfaceKind = _normalizeOptionalKey(newShapeSurfaceKind),
       _newShapeMaterialKey = _normalizeOptionalKey(newShapeMaterialKey),
       _newShapeCollisionMode = newShapeCollisionMode,
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
  String? _newShapeSurfaceKind;
  String? _newShapeMaterialKey;
  TerrainSourceCollisionMode _newShapeCollisionMode;
  String _newShapeNameInput = '';
  int _newShapeNameGeneration = 0;
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

  /// Fixed Prefab collision step in half-pixel ticks; `2` is one source pixel.
  int get coordinateStepHalfPixels => _prefabCollisionSnapPolicy.stepHalfPixels;
  String? get newShapeMaterialKey => _newShapeMaterialKey;
  String? get newShapeSurfaceKind => _newShapeSurfaceKind;
  TerrainSourceCollisionMode get newShapeCollisionMode =>
      _newShapeCollisionMode;
  String get newShapeNameInput => _newShapeNameInput;
  int get newShapeNameGeneration => _newShapeNameGeneration;
  String get resolvedNewShapeName => _newShapeNameInput.trim().isEmpty
      ? _reducer.allocateShapeId(_state)
      : _newShapeNameInput.trim();
  String? get newShapeNameError => _newShapeNameInput.trim().isEmpty
      ? null
      : validateShapeName(_newShapeNameInput);
  bool get canBeginNewShape => newShapeNameError == null;
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

  void setNewShapeCollisionMode(TerrainSourceCollisionMode collisionMode) {
    if (_state.hasActiveOperation || collisionMode == _newShapeCollisionMode) {
      return;
    }
    _newShapeCollisionMode = collisionMode;
    notifyListeners();
  }

  void setNewShapeMaterialKey(String? materialKey) {
    if (_state.hasActiveOperation) return;
    final normalized = _normalizeOptionalKey(materialKey);
    if (normalized == _newShapeMaterialKey) return;
    _newShapeMaterialKey = normalized;
    notifyListeners();
  }

  void setNewShapeSurfaceKind(String? surfaceKind) {
    if (_state.hasActiveOperation) return;
    final normalized = _normalizeOptionalKey(surfaceKind);
    if (normalized == _newShapeSurfaceKind) return;
    _newShapeSurfaceKind = normalized;
    notifyListeners();
  }

  void setNewShapeNameInput(String value) {
    if (_state.hasActiveOperation || value == _newShapeNameInput) return;
    _newShapeNameInput = value;
    _issues = const <PrefabValidationIssue>[];
    notifyListeners();
  }

  String? validateShapeName(String value, {String? excludingShapeId}) {
    final shapeId = value.trim();
    final syntaxError = terrainSourceShapeIdValidationError(shapeId);
    if (syntaxError != null) return syntaxError;
    final duplicate = _state.shapes.any(
      (shape) =>
          shape.shapeId != excludingShapeId &&
          shape.shapeId.toLowerCase() == shapeId.toLowerCase(),
    );
    return duplicate ? 'Another collision shape already uses this name.' : null;
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

  bool beginCreatePolygon({
    TerrainSourceCollisionMode? collisionMode,
    String? surfaceKind,
    String? materialKey,
  }) {
    if (!canBeginNewShape) return false;
    final before = _state;
    _replaceLocalState(
      _reducer.beginCreatePolygon(
        _state,
        shapeId: resolvedNewShapeName,
        collisionMode: collisionMode ?? _newShapeCollisionMode,
        surfaceKind: surfaceKind ?? newShapeSurfaceKind,
        materialKey: materialKey ?? _newShapeMaterialKey,
      ),
    );
    return !identical(before, _state);
  }

  bool beginCreateRectangle({
    required int pointer,
    required TerrainPolygonScenePoint point,
  }) {
    if (!canBeginNewShape) return false;
    final next = _reducer.beginCreateRectangle(
      _state,
      pointer: pointer,
      startPointer: _snapPoint(point),
      shapeId: resolvedNewShapeName,
      collisionMode: _newShapeCollisionMode,
      surfaceKind: newShapeSurfaceKind,
      materialKey: _newShapeMaterialKey,
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
        snap: _prefabCollisionSnapPolicy,
      ),
    );
  }

  bool saveDraft() {
    final attemptedState = _state;
    final saved = _applyInteractionResult(
      _reducer.saveDraft(attemptedState),
      attemptedState: attemptedState,
    );
    if (saved) {
      _newShapeNameInput = '';
      _newShapeNameGeneration += 1;
      notifyListeners();
    }
    return saved;
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
            snap: _prefabCollisionSnapPolicy,
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
          snap: _prefabCollisionSnapPolicy,
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
        snap: _prefabCollisionSnapPolicy,
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

  bool editSelectedVertex(TerrainSourceVertexDef vertex, {String? shapeId}) {
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.editSelectedVertex(
        attemptedState,
        vertex: vertex,
        shapeId: shapeId,
      ),
      attemptedState: attemptedState,
    );
  }

  bool editSelectedAxisAlignedRectangle({
    required int xHalfPixels,
    required int yHalfPixels,
    required int widthHalfPixels,
    required int heightHalfPixels,
    String? shapeId,
  }) {
    final attemptedState = _state;
    final left = _prefabCollisionSnapPolicy.snapCoordinate(xHalfPixels);
    final top = _prefabCollisionSnapPolicy.snapCoordinate(yHalfPixels);
    final right = _prefabCollisionSnapPolicy.snapCoordinate(
      xHalfPixels + widthHalfPixels,
    );
    final bottom = _prefabCollisionSnapPolicy.snapCoordinate(
      yHalfPixels + heightHalfPixels,
    );
    final minimumSize = _prefabCollisionSnapPolicy.stepHalfPixels;
    return _applyInteractionResult(
      _reducer.editSelectedAxisAlignedRectangle(
        attemptedState,
        xHalfPixels: left,
        yHalfPixels: top,
        widthHalfPixels: math.max(minimumSize, right - left),
        heightHalfPixels: math.max(minimumSize, bottom - top),
        shapeId: shapeId,
      ),
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

  bool renameSelectedShape(String shapeId) {
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.renameSelectedShape(attemptedState, shapeId: shapeId.trim()),
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
      _prefabCollisionSnapPolicy.snapFractionalVertex(
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

String? _normalizeOptionalKey(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
