import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon_overlap.dart';

import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/collision_fitting/prefab_collision_fitting.dart';
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
    PrefabV3CollisionCommitPolicy commitPolicy =
        const PrefabV3CollisionCommitPolicy(),
  }) : _session = session,
       _prefabKey = prefabKey,
       _newShapeSurfaceKind = _normalizeOptionalKey(newShapeSurfaceKind),
       _newShapeMaterialKey = _normalizeOptionalKey(newShapeMaterialKey),
       _newShapeCollisionMode = _collisionModeForKind(
         _requirePrefab(session, prefabKey).kind,
       ),
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
  _PrefabCollisionFitDraft? _fitDraft;
  int _fitGenerationToken = 0;
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
  bool get hasActiveOperation => _state.hasActiveOperation || _fitDraft != null;
  bool get hasFitDraft => _fitDraft != null;
  bool get isFitLoading => _fitDraft?.loading ?? false;
  bool get fitHasLocalEdits => _fitDraft?.undoSnapshots.isNotEmpty ?? false;
  PrefabCollisionCreationMethod? get fitMethod => _fitDraft?.method;
  PrefabCollisionFitSettings? get fitSettings => _fitDraft?.settings;
  PrefabAlphaMask? get fitMask => _fitDraft?.acceptedMask;
  PrefabCollisionFitEvidence? get fitEvidence => _fitDraft?.evidence;
  String? get fitRefitShapeId => _fitDraft?.refitShapeId;
  List<String> get fitMessages =>
      List<String>.unmodifiable(_fitDraft?.messages ?? const <String>[]);
  List<String> get fitCandidateShapeIds => List<String>.unmodifiable(
    _fitDraft?.candidateShapeIds ?? const <String>[],
  );
  Set<String> get includedFitCandidateShapeIds =>
      Set<String>.unmodifiable(_fitDraft?.includedShapeIds ?? const <String>{});
  bool get canSaveFitDraft {
    final draft = _fitDraft;
    return draft != null &&
        !draft.loading &&
        draft.candidateShapeIds.isNotEmpty &&
        draft.includedShapeIds.isNotEmpty &&
        !draft.blocked;
  }

  bool isFitCandidate(String shapeId) =>
      _fitDraft?.candidateShapeIds.contains(shapeId) ?? false;

  bool isFitCandidateIncluded(String shapeId) =>
      _fitDraft?.includedShapeIds.contains(shapeId) ?? false;

  bool canEditShape(String shapeId) => _fitDraft == null
      ? !_state.hasActiveOperation
      : !_fitDraft!.loading && isFitCandidate(shapeId);
  bool get canUndo {
    if (_state.gesture != null) return true;
    if (_state.draft != null) return _state.canUndoDraftVertexEdit;
    if (_fitDraft != null) return _fitDraft!.undoSnapshots.isNotEmpty;
    return _session.canUndo;
  }

  bool get canRedo {
    if (_state.gesture != null) return false;
    if (_state.draft != null) return _state.canRedoDraftVertexEdit;
    if (_fitDraft != null) return _fitDraft!.redoSnapshots.isNotEmpty;
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
    if (_fitDraft?.loading ?? false) return;
    _replaceLocalState(_reducer.setTool(_state, tool));
  }

  void setNewShapeCollisionMode(TerrainSourceCollisionMode collisionMode) {
    final requiredMode = _collisionModeForKind(prefab.kind);
    if (_state.hasActiveOperation ||
        _fitDraft != null ||
        collisionMode != requiredMode ||
        collisionMode == _newShapeCollisionMode) {
      return;
    }
    _newShapeCollisionMode = collisionMode;
    notifyListeners();
  }

  void setNewShapeMaterialKey(String? materialKey) {
    if (hasActiveOperation) return;
    final normalized = _normalizeOptionalKey(materialKey);
    if (normalized == _newShapeMaterialKey) return;
    _newShapeMaterialKey = normalized;
    notifyListeners();
  }

  void setNewShapeSurfaceKind(String? surfaceKind) {
    if (hasActiveOperation) return;
    final normalized = _normalizeOptionalKey(surfaceKind);
    if (normalized == _newShapeSurfaceKind) return;
    _newShapeSurfaceKind = normalized;
    notifyListeners();
  }

  void setNewShapeNameInput(String value) {
    if (hasActiveOperation || value == _newShapeNameInput) return;
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
    if (_fitDraft?.loading ?? false) return;
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
    if (!canBeginNewShape || _fitDraft != null) return false;
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
    if (!canBeginNewShape || _fitDraft != null) return false;
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
    if (_fitDraft != null && !isFitCandidate(selection.shapeId)) return false;
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
    if (_fitDraft != null && !_state.hasActiveOperation) {
      cancelFitDraft();
      return;
    }
    _replaceLocalState(_reducer.cancelActiveOperation(_state));
  }

  bool deleteSelection() {
    if (_fitDraft != null) return false;
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
    if (!_fitEditTargetsCandidate(shapeId)) return false;
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
    if (!_fitEditTargetsCandidate(shapeId)) return false;
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
    if (_fitDraft != null) return false;
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
    if (!_fitEditTargetsCandidate(null)) return false;
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.normalizeSelectedShape(attemptedState),
      attemptedState: attemptedState,
    );
  }

  bool renameSelectedShape(String shapeId) {
    if (_fitDraft != null) return false;
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
    final selection = _state.selection;
    if (_fitDraft != null &&
        (selection == null || !isFitCandidate(selection.shapeId))) {
      return false;
    }
    final requiredMode = _collisionModeForKind(prefab.kind);
    if (collisionMode != requiredMode) return false;
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

  /// Starts or regenerates one digest-bound multi-shape fitting draft.
  ///
  /// The returned token must accompany the async result; older completions are
  /// ignored after another generation, owner change, or cancellation.
  int startFitGeneration({
    required PrefabCollisionCreationMethod method,
    required PrefabCollisionFitSettings settings,
    String? refitShapeId,
  }) {
    if (!method.isPixelDerived ||
        prefab.kind == PrefabKind.decoration ||
        _state.hasActiveOperation) {
      return 0;
    }
    if (method == PrefabCollisionCreationMethod.detectPlatformSurface &&
        prefab.kind != PrefabKind.platform) {
      return 0;
    }
    if (_newShapeNameInput.isNotEmpty && newShapeNameError != null) return 0;
    final existing = _fitDraft;
    if (existing != null && existing.refitShapeId != refitShapeId) return 0;
    if (refitShapeId != null &&
        _findShape(_state.shapes, refitShapeId) == null &&
        existing == null) {
      return 0;
    }
    final beforeShapes = existing?.beforeShapes ?? _state.shapes;
    final beforeSelection = existing?.beforeSelection ?? _state.selection;
    if (existing != null) {
      _state = _stateFromShapes(
        beforeShapes,
        preferredSelection: beforeSelection,
        preferredTool: TerrainPolygonTool.select,
      );
    }
    final token = ++_fitGenerationToken;
    _fitDraft = _PrefabCollisionFitDraft(
      method: method,
      settings: settings,
      beforeShapes: beforeShapes,
      beforeSelection: beforeSelection,
      refitShapeId: refitShapeId,
      expectedOwnerRevision: prefab.revision,
      generationToken: token,
      loading: true,
      preferredPrimaryId:
          existing?.preferredPrimaryId ??
          refitShapeId ??
          (_newShapeNameInput.trim().isEmpty
              ? null
              : _newShapeNameInput.trim()),
    );
    _issues = const <PrefabValidationIssue>[];
    notifyListeners();
    return token;
  }

  /// Installs a generated result as a local prospective owner snapshot.
  bool completeFitGeneration({
    required int token,
    required PrefabAlphaMask sourceMask,
    required String sourceIdentity,
    required PrefabCollisionFitResult result,
    required int visualOriginXPx,
    required int visualOriginYPx,
  }) {
    final draft = _fitDraft;
    if (draft == null || draft.generationToken != token) return false;
    if (result.method != draft.method || result.settings != draft.settings) {
      rejectFitGeneration(
        token: token,
        message: 'The generated result does not match the current fit method and settings.',
      );
      return false;
    }
    final bounds = visualBounds;
    if (bounds == null ||
        sourceMask.width != bounds.widthPx ||
        sourceMask.height != bounds.heightPx ||
        visualOriginXPx != -prefab.anchorXPx ||
        visualOriginYPx != -prefab.anchorYPx) {
      rejectFitGeneration(
        token: token,
        message:
            'The generated mask no longer matches this Prefab visual layout.',
      );
      return false;
    }
    final messages = <String>[
      for (final diagnostic in result.diagnostics) diagnostic.message,
    ];
    if (!result.accepted) {
      draft
        ..loading = false
        ..blocked = true
        ..sourceIdentity = sourceIdentity
        ..sourceMask = sourceMask
        ..acceptedMask = _acceptedMask(sourceMask, result.acceptedPixels)
        ..baseEvidence = result.evidence
        ..evidence = result.evidence
        ..generationBlocked = true
        ..generationMessages = messages
        ..messages = messages;
      notifyListeners();
      return false;
    }

    final retained = <TerrainSourceShapeDef>[
      for (final shape in draft.beforeShapes)
        if (shape.shapeId != draft.refitShapeId) shape,
    ];
    final refitShape = draft.refitShapeId == null
        ? null
        : _findShape(draft.beforeShapes, draft.refitShapeId!);
    final collisionMode = _collisionModeForKind(prefab.kind);
    final generated = <TerrainSourceShapeDef>[];
    final componentByShapeId = <String, int>{};
    for (var index = 0; index < result.shapes.length; index += 1) {
      final fitShape = result.shapes[index];
      final shapeId = _allocateFitShapeId(
        <TerrainSourceShapeDef>[...retained, ...generated],
        preferred: index == 0
            ? (refitShape?.shapeId ??
                  (_newShapeNameInput.trim().isEmpty
                      ? null
                      : _newShapeNameInput.trim()))
            : null,
        prefix: refitShape == null
            ? 'collision'
            : _shapeIdPrefix(refitShape.shapeId),
      );
      final shape = TerrainSourceShapeDef(
        shapeId: shapeId,
        collisionMode: collisionMode,
        surfaceKind: refitShape?.surfaceKind ?? _newShapeSurfaceKind,
        materialKey: refitShape?.materialKey ?? _newShapeMaterialKey,
        vertices: <TerrainSourceVertexDef>[
          for (final point in fitShape.vertices)
            TerrainSourceVertexDef(
              xHalfPixels: (visualOriginXPx + point.x) * 2,
              yHalfPixels: (visualOriginYPx + point.y) * 2,
            ),
        ],
      );
      generated.add(shape);
      componentByShapeId[shapeId] = fitShape.componentIndex;
    }
    final prospective = canonicalTerrainSourceShapes(<TerrainSourceShapeDef>[
      ...retained,
      ...generated,
    ]);
    final included = <String>{};
    if (refitShape == null) {
      included.addAll(generated.map((shape) => shape.shapeId));
    } else {
      for (final shape in generated) {
        if (_sourceShapesOverlap(refitShape, shape)) {
          included.add(shape.shapeId);
        }
      }
      if (included.isEmpty) {
        messages.add(
          'No generated component intersects ${refitShape.shapeId}; include a component explicitly to replace it.',
        );
      }
    }
    _state = TerrainPolygonInteractionState(
      shapes: prospective,
      selection: generated.isEmpty
          ? null
          : TerrainPolygonSelection.shape(generated.first.shapeId),
      tool: TerrainPolygonTool.select,
    );
    draft
      ..loading = false
      ..blocked = false
      ..sourceIdentity = sourceIdentity
      ..sourceMask = sourceMask
      ..acceptedMask = _acceptedMask(sourceMask, result.acceptedPixels)
      ..baseEvidence = result.evidence
      ..evidence = result.evidence
      ..visualOriginXPx = visualOriginXPx
      ..visualOriginYPx = visualOriginYPx
      ..generationBlocked = false
      ..generationMessages = messages
      ..messages = messages
      ..candidateShapeIds = generated.map((shape) => shape.shapeId).toList()
      ..componentByShapeId = componentByShapeId
      ..includedShapeIds = included
      ..undoSnapshots.clear()
      ..redoSnapshots.clear();
    _reviewFitDraft();
    notifyListeners();
    return !draft.blocked;
  }

  /// Completes a failed source load without allowing stale async work to win.
  void rejectFitGeneration({required int token, required String message}) {
    final draft = _fitDraft;
    if (draft == null || draft.generationToken != token) return;
    draft
      ..loading = false
      ..blocked = true
      ..generationBlocked = true
      ..generationMessages = <String>[message]
      ..messages = <String>[message];
    notifyListeners();
  }

  void setFitCandidateIncluded(String shapeId, bool included) {
    final draft = _fitDraft;
    if (draft == null ||
        draft.loading ||
        !draft.candidateShapeIds.contains(shapeId) ||
        draft.includedShapeIds.contains(shapeId) == included) {
      return;
    }
    _recordFitUndo();
    if (included) {
      draft.includedShapeIds.add(shapeId);
    } else {
      draft.includedShapeIds.remove(shapeId);
    }
    _reviewFitDraft();
    notifyListeners();
  }

  /// Cancels a fitting draft and restores its exact pre-fit owner snapshot.
  bool cancelFitDraft() {
    final draft = _fitDraft;
    if (draft == null) return false;
    _fitGenerationToken += 1;
    _fitDraft = null;
    _state = _stateFromShapes(
      draft.beforeShapes,
      preferredSelection: draft.beforeSelection,
      preferredTool: TerrainPolygonTool.select,
    );
    _issues = const <PrefabValidationIssue>[];
    notifyListeners();
    return true;
  }

  /// Saves every included fit candidate as one semantic owner commit.
  bool saveFitDraft({required String currentSourceIdentity}) {
    final draft = _fitDraft;
    if (draft == null || !canSaveFitDraft) return false;
    if (draft.sourceIdentity != currentSourceIdentity) {
      draft
        ..blocked = true
        ..messages = <String>[
          'The visual source changed after generation. Regenerate before saving.',
        ];
      notifyListeners();
      return false;
    }
    final currentOwner = prefab;
    if (currentOwner.revision != draft.expectedOwnerRevision ||
        !_shapeListsEqual(currentOwner.collisionShapes, draft.beforeShapes)) {
      draft
        ..blocked = true
        ..messages = <String>[
          'The Prefab collision source changed after generation. Regenerate before saving.',
        ];
      notifyListeners();
      return false;
    }

    final candidates = <TerrainSourceShapeDef>[
      for (final id in draft.candidateShapeIds)
        if (draft.includedShapeIds.contains(id)) _findShape(_state.shapes, id)!,
    ];
    final retained = <TerrainSourceShapeDef>[
      for (final shape in draft.beforeShapes)
        if (shape.shapeId != draft.refitShapeId) shape,
    ];
    final finalCandidates = _reallocateIncludedCandidates(
      candidates,
      retained: retained,
      refitShapeId: draft.refitShapeId,
    );
    final after = canonicalTerrainSourceShapes(<TerrainSourceShapeDef>[
      ...retained,
      ...finalCandidates,
    ]);
    final selection = finalCandidates.isEmpty
        ? draft.beforeSelection
        : TerrainPolygonSelection.shape(finalCandidates.first.shapeId);
    final commit = TerrainPolygonInteractionCommit(
      beforeShapes: draft.beforeShapes,
      afterShapes: after,
      beforeSelection: draft.beforeSelection,
      afterSelection: selection,
    );
    final attemptedState = _state;
    _fitDraft = null;
    final saved = _commitOwner(
      commit,
      attemptedState: attemptedState,
      acceptedSelection: selection,
      acceptNoOp: true,
    );
    if (saved) {
      _newShapeNameInput = '';
      _newShapeNameGeneration += 1;
    } else if (_fitDraft == null &&
        !_shapeListsEqual(commit.beforeShapes, commit.afterShapes)) {
      _fitDraft = draft;
      _state = attemptedState;
    }
    notifyListeners();
    return saved;
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
    final fitDraft = _fitDraft;
    if (fitDraft != null) {
      if (fitDraft.undoSnapshots.isEmpty) return false;
      fitDraft.redoSnapshots.add(_currentFitSnapshot());
      final snapshot = fitDraft.undoSnapshots.removeLast();
      _restoreFitSnapshot(snapshot);
      notifyListeners();
      return true;
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
    final fitDraft = _fitDraft;
    if (fitDraft != null) {
      if (fitDraft.redoSnapshots.isEmpty) return false;
      fitDraft.undoSnapshots.add(_currentFitSnapshot());
      final snapshot = fitDraft.redoSnapshots.removeLast();
      _restoreFitSnapshot(snapshot);
      notifyListeners();
      return true;
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

    if (_fitDraft != null) {
      if (!_fitCommitTouchesCandidatesOnly(commit)) {
        _state = attemptedState;
        _issues = const <PrefabValidationIssue>[
          PrefabValidationIssue(
            code: 'prefab_fit_retained_shape_edit_forbidden',
            message: 'A fitting draft can edit only its generated candidates.',
            sourcePath: PrefabStore.prefabDefsPath,
          ),
        ];
        notifyListeners();
        return false;
      }
      _recordFitUndo();
      _state = result.state;
      _issues = _interactionIssues(result, accepted: true);
      _reviewFitDraft();
      notifyListeners();
      return true;
    }

    return _commitOwner(
      commit,
      attemptedState: attemptedState,
      acceptedSelection: result.state.selection,
      acceptedTool: result.state.tool,
      supplementalIssues: _interactionIssues(result, accepted: true),
    );
  }

  bool _commitOwner(
    TerrainPolygonInteractionCommit commit, {
    required TerrainPolygonInteractionState attemptedState,
    required TerrainPolygonSelection? acceptedSelection,
    TerrainPolygonTool acceptedTool = TerrainPolygonTool.select,
    Iterable<PrefabValidationIssue> supplementalIssues =
        const <PrefabValidationIssue>[],
    bool acceptNoOp = false,
  }) {
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
    if (!ownerResult.accepted || (!ownerResult.changed && !acceptNoOp)) {
      _state = attemptedState;
      _issues = ownerResult.issues;
      notifyListeners();
      return false;
    }
    if (!ownerResult.changed) {
      _state = _stateFromShapes(
        commit.beforeShapes,
        preferredSelection: acceptedSelection,
        preferredTool: acceptedTool,
      );
      _issues = _sortedIssues(<PrefabValidationIssue>[
        ...supplementalIssues,
        ...ownerResult.issues,
      ]);
      notifyListeners();
      return true;
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
              'The prefab plugin rejected the validated polygon commit; '
              'reload the current document before retrying.',
          sourcePath: PrefabStore.prefabDefsPath,
        ),
      );
      return false;
    }

    final updatedPrefab = _requirePrefab(_session, _prefabKey);
    _state = _stateFromShapes(
      updatedPrefab.collisionShapes,
      preferredSelection: acceptedSelection,
      preferredTool: acceptedTool,
    );
    _issues = _sortedIssues(<PrefabValidationIssue>[
      ...supplementalIssues,
      ...ownerResult.issues,
    ]);
    notifyListeners();
    return true;
  }

  bool _fitEditTargetsCandidate(String? explicitShapeId) {
    final draft = _fitDraft;
    if (draft == null) return true;
    if (draft.loading) return false;
    final target = explicitShapeId ?? _state.selection?.shapeId;
    return target != null && draft.candidateShapeIds.contains(target);
  }

  bool _fitCommitTouchesCandidatesOnly(TerrainPolygonInteractionCommit commit) {
    final draft = _fitDraft!;
    final retained = <String, TerrainSourceShapeDef>{
      for (final shape in draft.beforeShapes)
        if (shape.shapeId != draft.refitShapeId) shape.shapeId: shape,
    };
    final afterById = <String, TerrainSourceShapeDef>{
      for (final shape in commit.afterShapes) shape.shapeId: shape,
    };
    for (final entry in retained.entries) {
      if (afterById[entry.key] != entry.value) return false;
    }
    for (final shape in commit.afterShapes) {
      if (!retained.containsKey(shape.shapeId) &&
          !draft.candidateShapeIds.contains(shape.shapeId)) {
        return false;
      }
    }
    return true;
  }

  void _recordFitUndo() {
    final draft = _fitDraft;
    if (draft == null) return;
    draft.undoSnapshots.add(_currentFitSnapshot());
    draft.redoSnapshots.clear();
  }

  _PrefabCollisionFitSnapshot _currentFitSnapshot() =>
      _PrefabCollisionFitSnapshot(
        state: _state,
        includedShapeIds: _fitDraft!.includedShapeIds,
      );

  void _restoreFitSnapshot(_PrefabCollisionFitSnapshot snapshot) {
    _state = snapshot.state;
    _fitDraft!.includedShapeIds = Set<String>.of(snapshot.includedShapeIds);
    _reviewFitDraft();
  }

  void _reviewFitDraft() {
    final draft = _fitDraft;
    if (draft == null || draft.loading) return;
    final candidates = <TerrainSourceShapeDef>[
      for (final id in draft.candidateShapeIds)
        if (draft.includedShapeIds.contains(id)) _findShape(_state.shapes, id)!,
    ];
    if (candidates.isEmpty) {
      draft
        ..blocked = true
        ..messages = <String>[
          ...draft.generationMessages,
          'Include at least one generated component before saving.',
        ];
      return;
    }
    final retained = <TerrainSourceShapeDef>[
      for (final shape in draft.beforeShapes)
        if (shape.shapeId != draft.refitShapeId) shape,
    ];
    final prospective = canonicalTerrainSourceShapes(<TerrainSourceShapeDef>[
      ...retained,
      ...candidates,
    ]);
    final sourceMask = draft.sourceMask;
    final acceptedMask = draft.acceptedMask;
    final baseEvidence = draft.baseEvidence;
    if (sourceMask != null && acceptedMask != null && baseEvidence != null) {
      draft.evidence = PrefabCollisionFitter.evaluateEvidence(
        mask: sourceMask,
        acceptedPixels: acceptedMask.alpha,
        shapes: <PrefabCollisionFitShape>[
          for (final shape in candidates)
            PrefabCollisionFitShape(
              componentIndex: draft.componentByShapeId[shape.shapeId] ?? 0,
              partitionIndex: 0,
              vertices: <PrefabCollisionFitPoint>[
                for (final vertex in shape.vertices)
                  PrefabCollisionFitPoint(
                    vertex.xHalfPixels ~/ 2 - draft.visualOriginXPx,
                    vertex.yHalfPixels ~/ 2 - draft.visualOriginYPx,
                  ),
              ],
            ),
        ],
        method: draft.method,
        baseline: baseEvidence,
      );
    }
    final bounds = visualBounds;
    final review = validatePrefabCollisionShapes(
      prefabId: prefab.id,
      prefabKey: prefab.prefabKey,
      kind: prefab.kind,
      anchorXPx: prefab.anchorXPx,
      anchorYPx: prefab.anchorYPx,
      collisionShapes: prospective,
      sourceWidthPx: bounds?.widthPx,
      sourceHeightPx: bounds?.heightPx,
      sourcePath: '${PrefabStore.prefabDefsPath}:${prefab.prefabKey}',
    );
    final document = _session.document;
    final downstream = document is PrefabV3Document
        ? introducedPrefabV3DownstreamCollisionErrors(
            original: document,
            candidateData: document.data.copyWith(
              prefabs: <PrefabV3Def>[
                for (final owner in document.data.prefabs)
                  if (owner.prefabKey == prefab.prefabKey)
                    owner.copyWith(
                      revision: owner.revision + 1,
                      collisionShapes: prospective,
                    )
                  else
                    owner,
              ],
            ),
          )
        : const <ValidationIssue>[];
    final blocking = review.where(
      (issue) => issue.severity == PrefabValidationSeverity.error,
    );
    draft
      ..blocked =
          draft.generationBlocked ||
          blocking.isNotEmpty ||
          downstream.isNotEmpty
      ..messages = <String>[
        ...draft.generationMessages,
        ...review.map((issue) => issue.message),
        ...downstream.map((issue) => issue.message),
      ];
    _issues = review;
  }

  List<TerrainSourceShapeDef> _reallocateIncludedCandidates(
    List<TerrainSourceShapeDef> candidates, {
    required List<TerrainSourceShapeDef> retained,
    required String? refitShapeId,
  }) {
    final result = <TerrainSourceShapeDef>[];
    final draft = _fitDraft!;
    for (var index = 0; index < candidates.length; index += 1) {
      final source = candidates[index];
      final preferred = index == 0
          ? (refitShapeId ?? draft.preferredPrimaryId)
          : null;
      final id = _allocateFitShapeId(
        <TerrainSourceShapeDef>[...retained, ...result],
        preferred: preferred,
        prefix: refitShapeId == null
            ? 'collision'
            : _shapeIdPrefix(refitShapeId),
      );
      result.add(
        TerrainSourceShapeDef(
          shapeId: id,
          vertices: source.vertices,
          collisionMode: _collisionModeForKind(prefab.kind),
          surfaceKind: source.surfaceKind,
          materialKey: source.materialKey,
        ),
      );
    }
    return result;
  }

  String _allocateFitShapeId(
    Iterable<TerrainSourceShapeDef> usedShapes, {
    String? preferred,
    required String prefix,
  }) {
    final used = usedShapes.map((shape) => shape.shapeId.toLowerCase()).toSet();
    if (preferred != null &&
        terrainSourceShapeIdValidationError(preferred) == null &&
        !used.contains(preferred.toLowerCase())) {
      return preferred;
    }
    for (var ordinal = 1; ; ordinal += 1) {
      final candidate = '${prefix}_${ordinal.toString().padLeft(3, '0')}';
      if (!used.contains(candidate.toLowerCase())) return candidate;
    }
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
    final fitDraft = _fitDraft;
    if (fitDraft != null) {
      fitDraft
        ..blocked = true
        ..messages = <String>[
          ...fitDraft.generationMessages,
          'The Prefab document changed while fitting. Cancel and regenerate from the current source.',
        ];
      notifyListeners();
      return;
    }
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

final class _PrefabCollisionFitDraft {
  _PrefabCollisionFitDraft({
    required this.method,
    required this.settings,
    required Iterable<TerrainSourceShapeDef> beforeShapes,
    required this.beforeSelection,
    required this.refitShapeId,
    required this.expectedOwnerRevision,
    required this.generationToken,
    required this.loading,
    required this.preferredPrimaryId,
  }) : beforeShapes = List<TerrainSourceShapeDef>.unmodifiable(beforeShapes);

  PrefabCollisionCreationMethod method;
  PrefabCollisionFitSettings settings;
  final List<TerrainSourceShapeDef> beforeShapes;
  final TerrainPolygonSelection? beforeSelection;
  final String? refitShapeId;
  final int expectedOwnerRevision;
  int generationToken;
  bool loading;
  bool blocked = false;
  bool generationBlocked = false;
  final String? preferredPrimaryId;
  String? sourceIdentity;
  PrefabAlphaMask? sourceMask;
  PrefabAlphaMask? acceptedMask;
  PrefabCollisionFitEvidence? baseEvidence;
  PrefabCollisionFitEvidence? evidence;
  int visualOriginXPx = 0;
  int visualOriginYPx = 0;
  List<String> generationMessages = <String>[];
  List<String> messages = <String>[];
  List<String> candidateShapeIds = <String>[];
  Map<String, int> componentByShapeId = <String, int>{};
  Set<String> includedShapeIds = <String>{};
  final List<_PrefabCollisionFitSnapshot> undoSnapshots =
      <_PrefabCollisionFitSnapshot>[];
  final List<_PrefabCollisionFitSnapshot> redoSnapshots =
      <_PrefabCollisionFitSnapshot>[];
}

final class _PrefabCollisionFitSnapshot {
  _PrefabCollisionFitSnapshot({
    required this.state,
    required Iterable<String> includedShapeIds,
  }) : includedShapeIds = Set<String>.unmodifiable(includedShapeIds);

  final TerrainPolygonInteractionState state;
  final Set<String> includedShapeIds;
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

TerrainSourceShapeDef? _findShape(
  Iterable<TerrainSourceShapeDef> shapes,
  String shapeId,
) {
  for (final shape in shapes) {
    if (shape.shapeId == shapeId) return shape;
  }
  return null;
}

TerrainSourceCollisionMode _collisionModeForKind(PrefabKind kind) =>
    switch (kind) {
      PrefabKind.platform => TerrainSourceCollisionMode.oneWay,
      PrefabKind.obstacle ||
      PrefabKind.unknown => TerrainSourceCollisionMode.solid,
      PrefabKind.decoration => TerrainSourceCollisionMode.none,
    };

PrefabAlphaMask _acceptedMask(
  PrefabAlphaMask source,
  Uint8List acceptedPixels,
) => PrefabAlphaMask(
  width: source.width,
  height: source.height,
  alpha: Uint8List.fromList(<int>[
    for (final accepted in acceptedPixels) accepted == 0 ? 0 : 255,
  ]),
);

bool _sourceShapesOverlap(
  TerrainSourceShapeDef left,
  TerrainSourceShapeDef right,
) => TerrainPolygonOverlap.sourceLoops(
  <SourceTerrainPoint>[
    for (final vertex in left.vertices)
      SourceTerrainPoint(vertex.xHalfPixels, vertex.yHalfPixels),
  ],
  <SourceTerrainPoint>[
    for (final vertex in right.vertices)
      SourceTerrainPoint(vertex.xHalfPixels, vertex.yHalfPixels),
  ],
);

String _shapeIdPrefix(String shapeId) {
  final separator = shapeId.lastIndexOf('_');
  if (separator <= 0 || separator == shapeId.length - 1) return 'collision';
  return int.tryParse(shapeId.substring(separator + 1)) == null
      ? 'collision'
      : shapeId.substring(0, separator);
}

bool _shapeListsEqual(
  List<TerrainSourceShapeDef> left,
  List<TerrainSourceShapeDef> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
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
