import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../chunks/chunk_domain_plugin.dart';
import '../../../../chunks/chunk_v2_collision_commit.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../../../domain/authoring_types.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../terrain_authoring/terrain_polygon_contact_constraint.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_polygon_scene_projection.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';

// Direct Chunk terrain must remain on whole pixels even when collision contact
// refines an optional tile-grid gesture. Two half-pixel ticks equal one pixel.
const int _chunkTerrainContactStepHalfPixels = 2;

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
    this.newShapeSurfaceKind,
    String? newShapeMaterialKey,
    TerrainSourceCollisionMode newShapeCollisionMode =
        TerrainSourceCollisionMode.solid,
    bool creationSnapToGrid = false,
    bool editSnapToGrid = false,
    ChunkV2CollisionCommitPolicy commitPolicy =
        const ChunkV2CollisionCommitPolicy(),
  }) : _session = session,
       _chunkKey = chunkKey,
       _newShapeMaterialKey = _normalizeOptionalKey(newShapeMaterialKey),
       _newShapeCollisionMode = newShapeCollisionMode,
       _creationSnapToGrid = creationSnapToGrid,
       _editSnapToGrid = editSnapToGrid,
       _creationSnapPolicy = TerrainPolygonSnapPolicy.ownerGridPixels(
         creationSnapToGrid ? _requireChunk(session, chunkKey).tileSize : 1,
       ),
       _editSnapPolicy = TerrainPolygonSnapPolicy.ownerGridPixels(
         editSnapToGrid ? _requireChunk(session, chunkKey).tileSize : 1,
       ),
       _commitPolicy = commitPolicy,
       // Keep newly drawn general-purpose solids distinct from the explicit
       // `ground_` identities used by authored terrain bands.
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
  final String? newShapeSurfaceKind;
  String? _newShapeMaterialKey;
  TerrainSourceCollisionMode _newShapeCollisionMode;
  bool _creationSnapToGrid;
  bool _editSnapToGrid;
  String _newShapeNameInput = '';
  int _newShapeNameGeneration = 0;
  TerrainPolygonSnapPolicy _creationSnapPolicy;
  TerrainPolygonSnapPolicy _editSnapPolicy;
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

  /// Material-renderable committed, gesture-preview, and creation-draft loops.
  ///
  /// Drafts remain outside the session document. Once they have three points,
  /// this projection closes them visually so the scene can preview the same
  /// material result that Save would produce.
  List<TerrainSourceShapeDef> get terrainPreviewShapes {
    final projection = sceneProjection;
    final draft = projection.draft;
    return List<TerrainSourceShapeDef>.unmodifiable(<TerrainSourceShapeDef>[
      for (final shape in projection.shapes) shape.shape,
      if (draft != null && draft.vertices.length >= 3)
        TerrainSourceShapeDef(
          shapeId: draft.shapeId,
          vertices: draft.vertices,
          collisionMode: draft.collisionMode,
          surfaceKind: draft.surfaceKind,
          materialKey: draft.materialKey,
        ),
    ]);
  }

  List<ValidationIssue> get issues => _issues;
  String? get newShapeMaterialKey => _newShapeMaterialKey;
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
  bool get creationSnapToGrid => _creationSnapToGrid;
  bool get editSnapToGrid => _editSnapToGrid;
  TerrainPolygonSnapPolicy get creationSnapPolicy => _creationSnapPolicy;
  TerrainPolygonSnapPolicy get editSnapPolicy => _editSnapPolicy;
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

  /// Selects whole-pixel or owner tile-grid snapping for new terrain drafts.
  ///
  /// An active draft or gesture keeps the policy it started with so one local
  /// operation cannot mix grid intervals.
  void setCreationSnapToGrid(bool value) {
    if (_state.hasActiveOperation || value == _creationSnapToGrid) return;
    _creationSnapToGrid = value;
    _creationSnapPolicy = TerrainPolygonSnapPolicy.ownerGridPixels(
      value ? chunk.tileSize : 1,
    );
    notifyListeners();
  }

  /// Selects whole-pixel or owner tile-grid snapping for saved-shape edits.
  void setEditSnapToGrid(bool value) {
    if (_state.hasActiveOperation || value == _editSnapToGrid) return;
    _editSnapToGrid = value;
    _editSnapPolicy = TerrainPolygonSnapPolicy.ownerGridPixels(
      value ? chunk.tileSize : 1,
    );
    notifyListeners();
  }

  /// Selects the collision mode assigned to subsequently created shapes.
  ///
  /// An active draft or rectangle gesture retains the mode it started with.
  void setNewShapeCollisionMode(TerrainSourceCollisionMode collisionMode) {
    if (collisionMode == _newShapeCollisionMode) return;
    _newShapeCollisionMode = collisionMode;
    notifyListeners();
  }

  /// Selects the material key assigned to subsequently created shapes.
  ///
  /// An active draft or rectangle gesture retains the material it started
  /// with.
  void setNewShapeMaterialKey(String? materialKey) {
    final normalized = _normalizeOptionalKey(materialKey);
    if (normalized == _newShapeMaterialKey) return;
    _newShapeMaterialKey = normalized;
    notifyListeners();
  }

  /// Sets the optional custom ID used by the next polygon or rectangle.
  ///
  /// Blank input keeps deterministic automatic allocation. Invalid text stays
  /// route-local so the UI can explain it without starting an invalid draft.
  void setNewShapeNameInput(String value) {
    if (value == _newShapeNameInput) return;
    _newShapeNameInput = value;
    _issues = const <ValidationIssue>[];
    notifyListeners();
  }

  /// Validates one owner-local shape name, optionally excluding its source ID.
  String? validateShapeName(String value, {String? excludingShapeId}) {
    final shapeId = value.trim();
    final syntaxError = terrainSourceShapeIdValidationError(shapeId);
    if (syntaxError != null) return syntaxError;
    final duplicate = _state.shapes.any(
      (shape) =>
          shape.shapeId != excludingShapeId &&
          shape.shapeId.toLowerCase() == shapeId.toLowerCase(),
    );
    return duplicate ? 'Another terrain shape already uses this name.' : null;
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
    if (!canBeginNewShape) {
      _reportInvalidShapeName(newShapeNameError!);
      return false;
    }
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

  /// Starts a rectangle outside occupied collision, snapping near solid edges.
  bool beginCreateRectangle({
    required int pointer,
    required TerrainPolygonScenePoint point,
    double snapRadiusHalfPixels = 0,
  }) {
    if (!canBeginNewShape) {
      _reportInvalidShapeName(newShapeNameError!);
      return false;
    }
    final startPointer = TerrainPolygonContactConstraint.resolvePoint(
      desired: _snapPoint(point, _creationSnapPolicy),
      targets: _collisionTargets(),
      snapStepHalfPixels: _creationSnapPolicy.stepHalfPixels,
      snapRadiusHalfPixels: snapRadiusHalfPixels,
      isCandidateAllowed: _pointIsInBounds,
    );
    if (startPointer == null) {
      _reportBlockedPoint(
        'Start the rectangle outside existing collision or near an edge to '
        'snap onto it.',
      );
      return false;
    }
    final next = _reducer.beginCreateRectangle(
      _state,
      pointer: pointer,
      startPointer: startPointer,
      shapeId: resolvedNewShapeName,
      collisionMode: _newShapeCollisionMode,
      surfaceKind: newShapeSurfaceKind,
      materialKey: _newShapeMaterialKey,
    );
    final started = !identical(next, _state);
    _replaceLocalState(next);
    return started;
  }

  /// Appends one legal draft vertex and reports whether the draft changed.
  ///
  /// A point inside collision, or a point that would make the provisional
  /// closed draft occupy existing collision, is rejected without changing the
  /// draft. Nearby solid boundaries may provide a legal snapped point.
  bool addDraftVertex(
    TerrainPolygonScenePoint point, {
    double snapRadiusHalfPixels = 0,
  }) {
    final draft = _state.draft;
    if (draft == null || _state.gesture != null) return false;
    final targets = _collisionTargets();
    final vertex = TerrainPolygonContactConstraint.resolvePoint(
      desired: _snapPoint(point, _creationSnapPolicy),
      targets: targets,
      snapStepHalfPixels: _creationSnapPolicy.stepHalfPixels,
      snapRadiusHalfPixels: snapRadiusHalfPixels,
      isCandidateAllowed: (candidate) {
        if (!_pointIsInBounds(candidate)) return false;
        final shape = TerrainSourceShapeDef(
          shapeId: draft.shapeId,
          vertices: <TerrainSourceVertexDef>[...draft.vertices, candidate],
          collisionMode: draft.collisionMode,
          surfaceKind: draft.surfaceKind,
          materialKey: draft.materialKey,
        );
        return !TerrainPolygonContactConstraint.hasOccupiedAreaOverlap(
          shape: shape,
          targets: targets,
        );
      },
    );
    if (vertex == null) {
      _reportBlockedPoint(
        'Place the vertex outside existing collision or near an edge to snap '
        'onto it.',
      );
      return false;
    }
    final before = _state;
    _replaceLocalState(
      _reducer.addDraftVertex(
        _state,
        rawVertex: vertex,
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      ),
    );
    return !identical(_state, before);
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
    final sourcePoint = _snapPoint(point, _creationSnapPolicy);
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
    final sourcePoint = _snapPoint(point, _editSnapPolicy);
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

  /// Updates the active preview without allowing occupied-area overlap.
  ///
  /// When the requested pointer is invalid, the preview stops at the last
  /// legal authoring-grid point and may slide along the contacted boundary.
  void updateGesture({
    required int pointer,
    required TerrainPolygonScenePoint point,
    double snapRadiusHalfPixels = 0,
  }) {
    final gesture = _state.gesture;
    if (gesture == null || gesture.pointer != pointer) return;
    final snapPolicy = _gestureSnapPolicy;
    final desired = _boundedGesturePoint(point, snapPolicy);
    TerrainSourceShapeDef previewFor(TerrainSourceVertexDef candidatePointer) =>
        _reducer
            .updateGesture(
              _state,
              pointer: pointer,
              currentPointer: candidatePointer,
              snap: const TerrainPolygonSnapPolicy.halfPixel(),
            )
            .gesture!
            .previewShape;
    final constrained = TerrainPolygonContactConstraint.resolveGesturePointer(
      gesture: gesture,
      desired: desired,
      targets: _collisionTargets(
        excludedDirectShapeId: _state.draft == null
            ? gesture.originalShape.shapeId
            : null,
      ),
      snapStepHalfPixels: snapPolicy.stepHalfPixels,
      pointContactStepHalfPixels: _chunkTerrainContactStepHalfPixels,
      snapRadiusHalfPixels: snapRadiusHalfPixels,
      buildPreview: previewFor,
      isCandidateInBounds: _shapeIsInBounds,
    );
    _replaceLocalState(
      _reducer.updateGesture(
        _state,
        pointer: pointer,
        currentPointer: constrained,
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

  bool editSelectedVertex(TerrainSourceVertexDef vertex, {String? shapeId}) {
    final attemptedState = _state;
    return _applyInteractionResult(
      _reducer.editSelectedVertex(
        attemptedState,
        vertex: _boundVertex(
          _editSnapPolicy.snapVertex(vertex),
          _editSnapPolicy,
        ),
        shapeId: shapeId,
      ),
      attemptedState: attemptedState,
    );
  }

  /// Replaces all corners of the selected axis-aligned rectangle in one
  /// owner-reviewed source commit. Values use exact half-pixel ticks.
  bool editSelectedAxisAlignedRectangle({
    required int xHalfPixels,
    required int yHalfPixels,
    required int widthHalfPixels,
    required int heightHalfPixels,
    String? shapeId,
  }) {
    final attemptedState = _state;
    final left = _editSnapPolicy.snapCoordinate(xHalfPixels);
    final top = _editSnapPolicy.snapCoordinate(yHalfPixels);
    final right = _editSnapPolicy.snapCoordinate(xHalfPixels + widthHalfPixels);
    final bottom = _editSnapPolicy.snapCoordinate(
      yHalfPixels + heightHalfPixels,
    );
    final minimumSize = _editSnapPolicy.stepHalfPixels;
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

  TerrainPolygonSnapPolicy get _gestureSnapPolicy {
    final gesture = _state.gesture;
    return gesture?.kind == TerrainPolygonGestureKind.createRectangle ||
            _state.draft != null
        ? _creationSnapPolicy
        : _editSnapPolicy;
  }

  TerrainSourceVertexDef _snapPoint(
    TerrainPolygonScenePoint point,
    TerrainPolygonSnapPolicy snapPolicy,
  ) => _boundVertex(
    snapPolicy.snapFractionalVertex(
      xHalfPixels: point.xHalfPixels,
      yHalfPixels: point.yHalfPixels,
    ),
    snapPolicy,
  );

  /// Keeps all chunk-local authoring input within the closed owner rectangle.
  ///
  /// Shared polygon interaction deliberately has no owner bounds because it
  /// also serves Prefabs. Chunk input clamps before entering that reducer, so
  /// drafts stay editable at the edge instead of producing a later rejected
  /// commit. A tile-grid policy uses the final complete grid intersection when
  /// the raw right or bottom edge is off-grid. Whole-shape translation
  /// additionally constrains its delta because a pointer inside the chunk can
  /// still shift an entire polygon outside it.
  TerrainSourceVertexDef _boundedGesturePoint(
    TerrainPolygonScenePoint point,
    TerrainPolygonSnapPolicy snapPolicy,
  ) {
    final bounded = _snapPoint(point, snapPolicy);
    final gesture = _state.gesture;
    if (gesture?.kind != TerrainPolygonGestureKind.translateShape) {
      return bounded;
    }
    final original = gesture!.originalShape;
    final xBounds = _translationBounds(
      original.vertices.map((vertex) => vertex.xHalfPixels),
      maximum: chunk.width * 2,
    );
    final yBounds = _translationBounds(
      original.vertices.map((vertex) => vertex.yHalfPixels),
      maximum: chunk.height * 2,
    );
    final desiredDeltaX =
        bounded.xHalfPixels - gesture.startPointer.xHalfPixels;
    final desiredDeltaY =
        bounded.yHalfPixels - gesture.startPointer.yHalfPixels;
    return TerrainSourceVertexDef(
      xHalfPixels:
          gesture.startPointer.xHalfPixels +
          _clampInt(desiredDeltaX, xBounds.$1, xBounds.$2),
      yHalfPixels:
          gesture.startPointer.yHalfPixels +
          _clampInt(desiredDeltaY, yBounds.$1, yBounds.$2),
    );
  }

  TerrainSourceVertexDef _boundVertex(
    TerrainSourceVertexDef vertex,
    TerrainPolygonSnapPolicy snapPolicy,
  ) => TerrainSourceVertexDef(
    xHalfPixels: _clampInt(
      vertex.xHalfPixels,
      0,
      _lastGridCoordinateWithin(chunk.width * 2, snapPolicy.stepHalfPixels),
    ),
    yHalfPixels: _clampInt(
      vertex.yHalfPixels,
      0,
      _lastGridCoordinateWithin(chunk.height * 2, snapPolicy.stepHalfPixels),
    ),
  );

  bool _pointIsInBounds(TerrainSourceVertexDef point) =>
      point.xHalfPixels >= 0 &&
      point.xHalfPixels <= chunk.width * 2 &&
      point.yHalfPixels >= 0 &&
      point.yHalfPixels <= chunk.height * 2;

  bool _shapeIsInBounds(TerrainSourceShapeDef shape) =>
      shape.vertices.every(_pointIsInBounds);

  List<TerrainAuthoringCollisionLoop> _collisionTargets({
    String? excludedDirectShapeId,
  }) {
    final targets = <TerrainAuthoringCollisionLoop>[
      for (final shape in _state.shapes)
        if (shape.shapeId != excludedDirectShapeId)
          TerrainAuthoringCollisionLoop.fromSourceShape(
            stableKey: 'direct:${shape.shapeId}',
            shape: shape,
          ),
    ];
    final scene = _session.scene;
    if (scene is ChunkV2Scene) {
      final expansion =
          scene.collisionExpansionByChunkKey[_chunkKey]?.expansion;
      if (expansion != null) {
        for (final shape in expansion.expandedPrefabShapes) {
          targets.add(
            TerrainAuthoringCollisionLoop(
              stableKey: 'expanded:${shape.placementKey}:${shape.shapeId}',
              vertices: shape.vertices,
              collisionMode: shape.collisionMode,
            ),
          );
        }
      }
    }
    return targets;
  }

  void _reportBlockedPoint(String message) {
    final document = _session.document;
    _issues = List<ValidationIssue>.unmodifiable(<ValidationIssue>[
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'chunk_polygon_point_inside_collision',
        message: message,
        sourcePath: document is ChunkV2Document
            ? document.sourcePathByChunkKey[_chunkKey]
            : null,
      ),
    ]);
    notifyListeners();
  }

  void _reportInvalidShapeName(String message) {
    final document = _session.document;
    _issues = List<ValidationIssue>.unmodifiable(<ValidationIssue>[
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'chunk_polygon_shape_name_invalid',
        message: message,
        sourcePath: document is ChunkV2Document
            ? document.sourcePathByChunkKey[_chunkKey]
            : null,
      ),
    ]);
    notifyListeners();
  }

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

/// Inclusive delta range that keeps every [coordinates] value within
/// `0..maximum` after translation.
(int, int) _translationBounds(
  Iterable<int> coordinates, {
  required int maximum,
}) {
  final values = coordinates.toList(growable: false);
  if (values.isEmpty) {
    throw ArgumentError.value(coordinates, 'coordinates', 'Must not be empty.');
  }
  var minimumCoordinate = values.first;
  var maximumCoordinate = values.first;
  for (final coordinate in values.skip(1)) {
    if (coordinate < minimumCoordinate) minimumCoordinate = coordinate;
    if (coordinate > maximumCoordinate) maximumCoordinate = coordinate;
  }
  return (-minimumCoordinate, maximum - maximumCoordinate);
}

int _clampInt(int value, int minimum, int maximum) {
  if (minimum > maximum) {
    throw ArgumentError.value(
      maximum,
      'maximum',
      'Must be greater than or equal to minimum.',
    );
  }
  return value.clamp(minimum, maximum).toInt();
}

int _lastGridCoordinateWithin(int maximum, int step) =>
    (maximum ~/ step) * step;

String? _normalizeOptionalKey(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
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
