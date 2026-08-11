import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_polygon_overlap.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';

import 'terrain_source_core_adapter.dart';
import 'terrain_source_models.dart';

/// Kind of owner-local polygon element selected by an editor route.
enum TerrainPolygonSelectionKind { shape, edge, vertex }

/// Shared pointer tool identity used by both polygon-authoring routes.
enum TerrainPolygonTool {
  select,
  createPolygon,
  moveVertex,
  translateShape,
  insertVertex,
}

/// Stable selection expressed by shape ID and optional geometry index.
///
/// Shape selections have no element index. Edge and vertex selections require
/// a non-negative index and are checked against the current shape on use.
final class TerrainPolygonSelection {
  factory TerrainPolygonSelection.shape(String shapeId) =>
      TerrainPolygonSelection._(
        shapeId: _requireSelectionShapeId(shapeId),
        kind: TerrainPolygonSelectionKind.shape,
        elementIndex: null,
      );

  factory TerrainPolygonSelection.edge(String shapeId, int edgeIndex) =>
      TerrainPolygonSelection._(
        shapeId: _requireSelectionShapeId(shapeId),
        kind: TerrainPolygonSelectionKind.edge,
        elementIndex: _requireElementIndex(edgeIndex),
      );

  factory TerrainPolygonSelection.vertex(String shapeId, int vertexIndex) =>
      TerrainPolygonSelection._(
        shapeId: _requireSelectionShapeId(shapeId),
        kind: TerrainPolygonSelectionKind.vertex,
        elementIndex: _requireElementIndex(vertexIndex),
      );

  const TerrainPolygonSelection._({
    required this.shapeId,
    required this.kind,
    required this.elementIndex,
  });

  final String shapeId;
  final TerrainPolygonSelectionKind kind;
  final int? elementIndex;

  @override
  bool operator ==(Object other) =>
      other is TerrainPolygonSelection &&
      shapeId == other.shapeId &&
      kind == other.kind &&
      elementIndex == other.elementIndex;

  @override
  int get hashCode => Object.hash(shapeId, kind, elementIndex);
}

/// Snap policy applied to exact half-pixel authoring coordinates.
///
/// The half-pixel policy preserves every integer tick. Owner-grid snapping uses
/// an integer pixel grid and resolves exact ties away from zero without
/// floating-point arithmetic.
final class TerrainPolygonSnapPolicy {
  const TerrainPolygonSnapPolicy.halfPixel() : stepHalfPixels = 1;

  factory TerrainPolygonSnapPolicy.ownerGridPixels(int gridSizePixels) {
    if (gridSizePixels <= 0) {
      throw ArgumentError.value(
        gridSizePixels,
        'gridSizePixels',
        'Owner grid size must be positive.',
      );
    }
    return TerrainPolygonSnapPolicy._(gridSizePixels * 2);
  }

  const TerrainPolygonSnapPolicy._(this.stepHalfPixels);

  /// Exact snap interval in half-pixel ticks.
  final int stepHalfPixels;

  int snapCoordinate(int halfPixels) =>
      _roundToStep(halfPixels, stepHalfPixels);

  /// Snaps a display-derived fractional source coordinate directly to this
  /// policy's exact integer grid.
  ///
  /// Pointer projection is intentionally fractional. Rounding only after
  /// division by [stepHalfPixels] avoids first rounding to a half-pixel and
  /// then choosing the wrong owner-grid cell near a midpoint.
  int snapFractionalCoordinate(double halfPixels) {
    if (!halfPixels.isFinite) {
      throw ArgumentError.value(
        halfPixels,
        'halfPixels',
        'Pointer source coordinate must be finite.',
      );
    }
    return _roundFractionalHalfAwayFromZero(halfPixels / stepHalfPixels) *
        stepHalfPixels;
  }

  /// Converts one fractional source-space pointer into an authored vertex.
  TerrainSourceVertexDef snapFractionalVertex({
    required double xHalfPixels,
    required double yHalfPixels,
  }) => TerrainSourceVertexDef(
    xHalfPixels: snapFractionalCoordinate(xHalfPixels),
    yHalfPixels: snapFractionalCoordinate(yHalfPixels),
  );

  TerrainSourceVertexDef snapVertex(TerrainSourceVertexDef vertex) =>
      TerrainSourceVertexDef(
        xHalfPixels: snapCoordinate(vertex.xHalfPixels),
        yHalfPixels: snapCoordinate(vertex.yHalfPixels),
      );
}

/// In-progress polygon creation kept outside committed owner shapes.
final class TerrainPolygonDraft {
  TerrainPolygonDraft({
    required this.shapeId,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
    required Iterable<TerrainSourceVertexDef> vertices,
    Iterable<Iterable<TerrainSourceVertexDef>> undoVertexSnapshots =
        const <List<TerrainSourceVertexDef>>[],
    Iterable<Iterable<TerrainSourceVertexDef>> redoVertexSnapshots =
        const <List<TerrainSourceVertexDef>>[],
  }) : vertices = List<TerrainSourceVertexDef>.unmodifiable(vertices),
       undoVertexSnapshots = _freezeVertexSnapshots(undoVertexSnapshots),
       redoVertexSnapshots = _freezeVertexSnapshots(redoVertexSnapshots);

  final String shapeId;
  final TerrainSourceCollisionMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;
  final List<TerrainSourceVertexDef> vertices;
  final List<List<TerrainSourceVertexDef>> undoVertexSnapshots;
  final List<List<TerrainSourceVertexDef>> redoVertexSnapshots;

  bool get canUndoVertexEdit => undoVertexSnapshots.isNotEmpty;
  bool get canRedoVertexEdit => redoVertexSnapshots.isNotEmpty;
}

/// Active pointer gesture whose preview has not entered undo history yet.
enum TerrainPolygonGestureKind { moveVertex, translateShape, insertVertex }

/// Immutable gesture preview derived from one committed source shape.
final class TerrainPolygonGesture {
  const TerrainPolygonGesture({
    required this.pointer,
    required this.kind,
    required this.originalShape,
    required this.previewShape,
    required this.startPointer,
    required this.activeVertexIndex,
  });

  final int pointer;
  final TerrainPolygonGestureKind kind;
  final TerrainSourceShapeDef originalShape;
  final TerrainSourceShapeDef previewShape;
  final TerrainSourceVertexDef startPointer;
  final int? activeVertexIndex;
}

/// Shared immutable interaction snapshot for prefab- and chunk-owned polygons.
///
/// [shapes] is always the committed owner snapshot. [visibleShapes] substitutes
/// an active gesture preview without mutating that snapshot, which lets Escape
/// cancel a gesture and lets history record exactly one entry on commit.
final class TerrainPolygonInteractionState {
  factory TerrainPolygonInteractionState({
    required Iterable<TerrainSourceShapeDef> shapes,
    TerrainPolygonSelection? selection,
    TerrainPolygonTool tool = TerrainPolygonTool.select,
  }) {
    final canonicalShapes = canonicalTerrainSourceShapes(shapes);
    if (selection != null && !_selectionExists(canonicalShapes, selection)) {
      throw ArgumentError.value(
        selection,
        'selection',
        'Selection does not exist in the committed shape snapshot.',
      );
    }
    return TerrainPolygonInteractionState._(
      shapes: canonicalShapes,
      selection: selection,
      tool: tool,
      draft: null,
      gesture: null,
    );
  }

  const TerrainPolygonInteractionState._({
    required this.shapes,
    required this.selection,
    required this.tool,
    required this.draft,
    required this.gesture,
  });

  final List<TerrainSourceShapeDef> shapes;
  final TerrainPolygonSelection? selection;
  final TerrainPolygonTool tool;
  final TerrainPolygonDraft? draft;
  final TerrainPolygonGesture? gesture;

  bool get hasActiveOperation => draft != null || gesture != null;
  bool get canUndoDraftVertexEdit => draft?.canUndoVertexEdit ?? false;
  bool get canRedoDraftVertexEdit => draft?.canRedoVertexEdit ?? false;

  List<TerrainSourceShapeDef> get visibleShapes {
    final activeGesture = gesture;
    if (activeGesture == null) return shapes;
    return canonicalTerrainSourceShapes(<TerrainSourceShapeDef>[
      for (final shape in shapes)
        if (shape.shapeId == activeGesture.originalShape.shapeId)
          activeGesture.previewShape
        else
          shape,
    ]);
  }
}

/// One accepted semantic edit suitable for a single undo/redo history entry.
final class TerrainPolygonInteractionCommit {
  TerrainPolygonInteractionCommit({
    required Iterable<TerrainSourceShapeDef> beforeShapes,
    required Iterable<TerrainSourceShapeDef> afterShapes,
    required this.beforeSelection,
    required this.afterSelection,
  }) : beforeShapes = List<TerrainSourceShapeDef>.unmodifiable(beforeShapes),
       afterShapes = List<TerrainSourceShapeDef>.unmodifiable(afterShapes);

  final List<TerrainSourceShapeDef> beforeShapes;
  final List<TerrainSourceShapeDef> afterShapes;
  final TerrainPolygonSelection? beforeSelection;
  final TerrainPolygonSelection? afterSelection;
}

/// Outcome of an attempted polygon commit.
///
/// Rejected results retain the active draft/gesture so the caller can show
/// diagnostics and continue editing or cancel. Accepted no-ops have no
/// [commit], preventing empty undo entries. Non-blocking Core findings may be
/// present on an accepted result.
final class TerrainPolygonInteractionResult {
  TerrainPolygonInteractionResult({
    required this.state,
    required this.accepted,
    required this.commit,
    required Iterable<TerrainDiagnostic> diagnostics,
  }) : diagnostics = List<TerrainDiagnostic>.unmodifiable(
         List<TerrainDiagnostic>.of(diagnostics)..sort(),
       );

  final TerrainPolygonInteractionState state;
  final bool accepted;
  final TerrainPolygonInteractionCommit? commit;
  final List<TerrainDiagnostic> diagnostics;
}

/// Pure reducer shared by prefab-local and chunk-local polygon workflows.
///
/// It owns common selection, draft, snap, gesture, shape-ID, and Core geometry
/// rules. Owner-specific bounds, visual intersection, capacity, expanded
/// placement, and seam validation remain plugin responsibilities.
final class TerrainPolygonInteractionReducer {
  TerrainPolygonInteractionReducer({
    required this.sourcePath,
    required this.ownerKey,
    required this.shapeIdPrefix,
  }) {
    if (sourcePath.trim().isEmpty || sourcePath.trim() != sourcePath) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'Source path must be non-empty and trimmed.',
      );
    }
    if (ownerKey.trim().isEmpty || ownerKey.trim() != ownerKey) {
      throw ArgumentError.value(
        ownerKey,
        'ownerKey',
        'Owner key must be non-empty and trimmed.',
      );
    }
    TerrainSourceShapeDef(
      shapeId: '${shapeIdPrefix}_001',
      vertices: const <TerrainSourceVertexDef>[],
    );
  }

  final String sourcePath;
  final String ownerKey;
  final String shapeIdPrefix;

  /// Changes selection without creating an undoable semantic edit.
  TerrainPolygonInteractionState select(
    TerrainPolygonInteractionState state,
    TerrainPolygonSelection? selection,
  ) {
    if (state.hasActiveOperation) return state;
    if (selection != null && !_selectionExists(state.shapes, selection)) {
      throw ArgumentError.value(
        selection,
        'selection',
        'Selection does not exist in the committed shape snapshot.',
      );
    }
    return _state(state, selection: selection, replaceSelection: true);
  }

  /// Changes the active pointer tool without touching source or history.
  ///
  /// An open creation draft permits only vertex-level editing tools. Switching
  /// between them preserves the draft and cancels only an active pointer
  /// preview. Other creation-context tools remain unavailable until Save or
  /// Cancel ends the draft.
  TerrainPolygonInteractionState setTool(
    TerrainPolygonInteractionState state,
    TerrainPolygonTool tool,
  ) {
    if (state.tool == tool) return state;
    if (state.draft != null) {
      if (tool != TerrainPolygonTool.moveVertex &&
          tool != TerrainPolygonTool.insertVertex) {
        return state;
      }
      return _state(
        state,
        tool: tool,
        gesture: null,
        replaceGesture: state.gesture != null,
      );
    }
    return _state(
      state,
      tool: tool,
      gesture: null,
      replaceGesture: state.gesture != null,
    );
  }

  /// Starts an ordered vertex-click draft with a deterministic shape ID.
  TerrainPolygonInteractionState beginCreatePolygon(
    TerrainPolygonInteractionState state, {
    TerrainSourceCollisionMode collisionMode = TerrainSourceCollisionMode.solid,
    String? surfaceKind,
    String? materialKey,
  }) {
    if (state.hasActiveOperation) return state;
    final draft = TerrainPolygonDraft(
      shapeId: _allocateShapeId(state.shapes),
      collisionMode: collisionMode,
      surfaceKind: surfaceKind,
      materialKey: materialKey,
      vertices: const <TerrainSourceVertexDef>[],
    );
    return _state(
      state,
      tool: TerrainPolygonTool.createPolygon,
      selection: null,
      replaceSelection: true,
      draft: draft,
      replaceDraft: true,
    );
  }

  /// Appends one snapped point while preserving authored click order.
  TerrainPolygonInteractionState addDraftVertex(
    TerrainPolygonInteractionState state, {
    required TerrainSourceVertexDef rawVertex,
    required TerrainPolygonSnapPolicy snap,
  }) {
    final draft = state.draft;
    if (draft == null || state.gesture != null) return state;
    final nextVertices = <TerrainSourceVertexDef>[
      ...draft.vertices,
      snap.snapVertex(rawVertex),
    ];
    return _state(
      state,
      draft: _recordDraftVertices(draft, nextVertices),
      replaceDraft: true,
    );
  }

  /// Restores the draft snapshot before its last vertex-level edit.
  TerrainPolygonInteractionState undoDraftVertexEdit(
    TerrainPolygonInteractionState state,
  ) {
    final draft = state.draft;
    if (draft == null || state.gesture != null || !draft.canUndoVertexEdit) {
      return state;
    }
    final undo = draft.undoVertexSnapshots;
    return _state(
      state,
      draft: _draftWithHistory(
        draft,
        vertices: undo.last,
        undoVertexSnapshots: undo.take(undo.length - 1),
        redoVertexSnapshots: <List<TerrainSourceVertexDef>>[
          ...draft.redoVertexSnapshots,
          draft.vertices,
        ],
      ),
      replaceDraft: true,
      selection: null,
      replaceSelection: true,
    );
  }

  /// Reapplies the next locally undone draft vertex edit.
  TerrainPolygonInteractionState redoDraftVertexEdit(
    TerrainPolygonInteractionState state,
  ) {
    final draft = state.draft;
    if (draft == null || state.gesture != null || !draft.canRedoVertexEdit) {
      return state;
    }
    final redo = draft.redoVertexSnapshots;
    return _state(
      state,
      draft: _draftWithHistory(
        draft,
        vertices: redo.last,
        undoVertexSnapshots: <List<TerrainSourceVertexDef>>[
          ...draft.undoVertexSnapshots,
          draft.vertices,
        ],
        redoVertexSnapshots: redo.take(redo.length - 1),
      ),
      replaceDraft: true,
      selection: null,
      replaceSelection: true,
    );
  }

  /// Saves one draft as a normalized Core-reviewed source commit.
  ///
  /// Save is the explicit permission to remove redundant collinear middle
  /// vertices. Every other blocking diagnostic retains the editable draft.
  TerrainPolygonInteractionResult saveDraft(
    TerrainPolygonInteractionState state,
  ) {
    if (state.draft == null || state.gesture != null) {
      return _acceptedNoOp(state);
    }
    return normalizeSelectedShape(state);
  }

  /// Starts a local vertex drag against the open creation draft.
  TerrainPolygonInteractionState beginMoveDraftVertex(
    TerrainPolygonInteractionState state, {
    required int pointer,
    required int vertexIndex,
    required TerrainSourceVertexDef startPointer,
  }) {
    final draft = state.draft;
    if (draft == null || state.gesture != null) return state;
    final shape = _draftAsShape(draft);
    _requireVertexIndex(shape, vertexIndex);
    return _state(
      state,
      tool: TerrainPolygonTool.moveVertex,
      gesture: TerrainPolygonGesture(
        pointer: pointer,
        kind: TerrainPolygonGestureKind.moveVertex,
        originalShape: shape,
        previewShape: shape,
        startPointer: startPointer,
        activeVertexIndex: vertexIndex,
      ),
      replaceGesture: true,
    );
  }

  /// Inserts and optionally drags one local vertex on an open draft edge.
  TerrainPolygonInteractionState beginInsertDraftVertex(
    TerrainPolygonInteractionState state, {
    required int pointer,
    required int edgeIndex,
    required TerrainSourceVertexDef rawVertex,
    required TerrainPolygonSnapPolicy snap,
  }) {
    final draft = state.draft;
    if (draft == null || state.gesture != null) return state;
    if (edgeIndex < 0 || edgeIndex >= draft.vertices.length - 1) {
      return state;
    }
    final shape = _draftAsShape(draft);
    final vertex = snap.snapVertex(rawVertex);
    final vertexIndex = edgeIndex + 1;
    final vertices = shape.vertices.toList()..insert(vertexIndex, vertex);
    return _state(
      state,
      tool: TerrainPolygonTool.insertVertex,
      gesture: TerrainPolygonGesture(
        pointer: pointer,
        kind: TerrainPolygonGestureKind.insertVertex,
        originalShape: shape,
        previewShape: _shapeWithVertices(shape, vertices),
        startPointer: vertex,
        activeVertexIndex: vertexIndex,
      ),
      replaceGesture: true,
    );
  }

  /// Starts a vertex drag without changing the committed owner snapshot.
  TerrainPolygonInteractionState beginMoveVertex(
    TerrainPolygonInteractionState state, {
    required int pointer,
    required String shapeId,
    required int vertexIndex,
    required TerrainSourceVertexDef startPointer,
  }) {
    if (state.hasActiveOperation) return state;
    final shape = _requireShape(state.shapes, shapeId);
    _requireVertexIndex(shape, vertexIndex);
    return _state(
      state,
      tool: TerrainPolygonTool.moveVertex,
      selection: TerrainPolygonSelection.vertex(shapeId, vertexIndex),
      replaceSelection: true,
      gesture: TerrainPolygonGesture(
        pointer: pointer,
        kind: TerrainPolygonGestureKind.moveVertex,
        originalShape: shape,
        previewShape: shape,
        startPointer: startPointer,
        activeVertexIndex: vertexIndex,
      ),
      replaceGesture: true,
    );
  }

  /// Starts a whole-shape translation preview.
  TerrainPolygonInteractionState beginTranslateShape(
    TerrainPolygonInteractionState state, {
    required int pointer,
    required String shapeId,
    required TerrainSourceVertexDef startPointer,
  }) {
    if (state.hasActiveOperation) return state;
    final shape = _requireShape(state.shapes, shapeId);
    return _state(
      state,
      tool: TerrainPolygonTool.translateShape,
      selection: TerrainPolygonSelection.shape(shapeId),
      replaceSelection: true,
      gesture: TerrainPolygonGesture(
        pointer: pointer,
        kind: TerrainPolygonGestureKind.translateShape,
        originalShape: shape,
        previewShape: shape,
        startPointer: startPointer,
        activeVertexIndex: null,
      ),
      replaceGesture: true,
    );
  }

  /// Inserts a provisional edge vertex and enters the same drag lifecycle.
  ///
  /// The initial point may be collinear with its edge and therefore remains a
  /// preview until the user moves it to a Core-valid position and commits.
  TerrainPolygonInteractionState beginInsertVertex(
    TerrainPolygonInteractionState state, {
    required int pointer,
    required String shapeId,
    required int edgeIndex,
    required TerrainSourceVertexDef rawVertex,
    required TerrainPolygonSnapPolicy snap,
  }) {
    if (state.hasActiveOperation) return state;
    final shape = _requireShape(state.shapes, shapeId);
    _requireEdgeIndex(shape, edgeIndex);
    final vertex = snap.snapVertex(rawVertex);
    final vertexIndex = edgeIndex + 1;
    final vertices = shape.vertices.toList()..insert(vertexIndex, vertex);
    return _state(
      state,
      tool: TerrainPolygonTool.insertVertex,
      selection: TerrainPolygonSelection.vertex(shapeId, vertexIndex),
      replaceSelection: true,
      gesture: TerrainPolygonGesture(
        pointer: pointer,
        kind: TerrainPolygonGestureKind.insertVertex,
        originalShape: shape,
        previewShape: _shapeWithVertices(shape, vertices),
        startPointer: vertex,
        activeVertexIndex: vertexIndex,
      ),
      replaceGesture: true,
    );
  }

  /// Recomputes an active preview from its original shape and current pointer.
  TerrainPolygonInteractionState updateGesture(
    TerrainPolygonInteractionState state, {
    required int pointer,
    required TerrainSourceVertexDef currentPointer,
    required TerrainPolygonSnapPolicy snap,
  }) {
    final gesture = state.gesture;
    if (gesture == null || gesture.pointer != pointer) {
      return state;
    }
    final TerrainSourceShapeDef preview;
    switch (gesture.kind) {
      case TerrainPolygonGestureKind.moveVertex:
      case TerrainPolygonGestureKind.insertVertex:
        final vertexIndex = gesture.activeVertexIndex!;
        final vertices = gesture.previewShape.vertices.toList(growable: false);
        vertices[vertexIndex] = snap.snapVertex(currentPointer);
        preview = _shapeWithVertices(gesture.previewShape, vertices);
      case TerrainPolygonGestureKind.translateShape:
        final rawDeltaX =
            currentPointer.xHalfPixels - gesture.startPointer.xHalfPixels;
        final rawDeltaY =
            currentPointer.yHalfPixels - gesture.startPointer.yHalfPixels;
        final deltaX = snap.snapCoordinate(rawDeltaX);
        final deltaY = snap.snapCoordinate(rawDeltaY);
        preview = _shapeWithVertices(
          gesture.originalShape,
          gesture.originalShape.vertices.map(
            (vertex) => TerrainSourceVertexDef(
              xHalfPixels: vertex.xHalfPixels + deltaX,
              yHalfPixels: vertex.yHalfPixels + deltaY,
            ),
          ),
        );
    }
    return _state(
      state,
      gesture: TerrainPolygonGesture(
        pointer: gesture.pointer,
        kind: gesture.kind,
        originalShape: gesture.originalShape,
        previewShape: preview,
        startPointer: gesture.startPointer,
        activeVertexIndex: gesture.activeVertexIndex,
      ),
      replaceGesture: true,
    );
  }

  /// Validates one gesture preview and emits at most one history commit.
  TerrainPolygonInteractionResult commitGesture(
    TerrainPolygonInteractionState state, {
    required int pointer,
  }) {
    final gesture = state.gesture;
    if (gesture == null || gesture.pointer != pointer) {
      return _acceptedNoOp(state);
    }
    final draft = state.draft;
    if (draft != null) {
      if (gesture.originalShape.shapeId != draft.shapeId) {
        return _acceptedNoOp(state);
      }
      if (gesture.previewShape == gesture.originalShape) {
        return TerrainPolygonInteractionResult(
          state: _state(state, gesture: null, replaceGesture: true),
          accepted: true,
          commit: null,
          diagnostics: const <TerrainDiagnostic>[],
        );
      }
      return TerrainPolygonInteractionResult(
        state: _state(
          state,
          draft: _recordDraftVertices(draft, gesture.previewShape.vertices),
          replaceDraft: true,
          gesture: null,
          replaceGesture: true,
        ),
        accepted: true,
        commit: null,
        diagnostics: const <TerrainDiagnostic>[],
      );
    }
    if (gesture.previewShape == gesture.originalShape) {
      return _commitShapes(
        state,
        state.shapes,
        state.selection,
        clearGesture: true,
      );
    }
    final validation = _validateAndCanonicalize(
      gesture.previewShape,
      otherShapes: state.shapes.where(
        (shape) => shape.shapeId != gesture.originalShape.shapeId,
      ),
    );
    if (validation.shape == null) {
      return _rejected(state, validation.diagnostics);
    }
    final canonical = validation.shape!;
    final afterShapes = _replaceShape(state.shapes, canonical);
    final selection = gesture.activeVertexIndex == null
        ? TerrainPolygonSelection.shape(canonical.shapeId)
        : _selectionForCanonicalVertex(
            canonical,
            gesture.previewShape.vertices[gesture.activeVertexIndex!],
          );
    return _commitShapes(
      state,
      afterShapes,
      selection,
      diagnostics: validation.diagnostics,
      clearGesture: true,
    );
  }

  /// Cancels a draft or gesture and restores the committed visible snapshot.
  TerrainPolygonInteractionState cancelActiveOperation(
    TerrainPolygonInteractionState state,
  ) {
    if (!state.hasActiveOperation) return state;
    if (state.gesture != null) {
      return _state(
        state,
        tool: state.draft == null ? TerrainPolygonTool.select : state.tool,
        gesture: null,
        replaceGesture: true,
      );
    }
    return _state(
      state,
      tool: TerrainPolygonTool.select,
      selection: null,
      replaceSelection: true,
      draft: null,
      replaceDraft: true,
    );
  }

  /// Replaces one selected vertex with an exact numeric half-pixel value.
  ///
  /// Numeric inspector values are already exact authored ticks and therefore
  /// do not pass through the pointer snap policy. The complete candidate shape
  /// still runs through canonicalization, overlap, and owner commit validation.
  TerrainPolygonInteractionResult editSelectedVertex(
    TerrainPolygonInteractionState state, {
    required TerrainSourceVertexDef vertex,
  }) {
    final selection = state.selection;
    if (state.hasActiveOperation ||
        selection == null ||
        selection.kind != TerrainPolygonSelectionKind.vertex) {
      return _acceptedNoOp(state);
    }
    final shape = _requireShape(state.shapes, selection.shapeId);
    final vertexIndex = selection.elementIndex!;
    _requireVertexIndex(shape, vertexIndex);
    final vertices = shape.vertices.toList();
    if (vertices[vertexIndex] == vertex) return _acceptedNoOp(state);
    vertices[vertexIndex] = vertex;
    final candidate = _shapeWithVertices(shape, vertices);
    final validation = _validateAndCanonicalize(
      candidate,
      otherShapes: state.shapes.where(
        (other) => other.shapeId != candidate.shapeId,
      ),
    );
    final canonical = validation.shape;
    if (canonical == null) {
      return _rejected(state, validation.diagnostics);
    }
    final canonicalVertexIndex = canonical.vertices.indexOf(vertex);
    return _commitShapes(
      state,
      _replaceShape(state.shapes, canonical),
      canonicalVertexIndex < 0
          ? TerrainPolygonSelection.shape(canonical.shapeId)
          : TerrainPolygonSelection.vertex(
              canonical.shapeId,
              canonicalVertexIndex,
            ),
      diagnostics: validation.diagnostics,
    );
  }

  /// Deletes the selected vertex when the result can still be a polygon.
  TerrainPolygonInteractionResult deleteSelectedVertex(
    TerrainPolygonInteractionState state,
  ) {
    final selection = state.selection;
    if (state.hasActiveOperation ||
        selection == null ||
        selection.kind != TerrainPolygonSelectionKind.vertex) {
      return _acceptedNoOp(state);
    }
    final shape = _requireShape(state.shapes, selection.shapeId);
    final vertexIndex = selection.elementIndex!;
    _requireVertexIndex(shape, vertexIndex);
    if (shape.vertices.length <= 3) {
      return _rejected(state, <TerrainDiagnostic>[
        _diagnostic(
          shape,
          vertexIndex,
          'minimum_vertex_count',
          'Deleting this vertex would leave fewer than three vertices.',
        ),
      ]);
    }
    final vertices = shape.vertices.toList()..removeAt(vertexIndex);
    return _commitValidatedReplacement(
      state,
      _shapeWithVertices(shape, vertices),
    );
  }

  /// Deletes the selected shape without changing any remaining shape IDs.
  TerrainPolygonInteractionResult deleteSelectedShape(
    TerrainPolygonInteractionState state,
  ) {
    final selection = state.selection;
    if (state.hasActiveOperation || selection == null) {
      return _acceptedNoOp(state);
    }
    _requireShape(state.shapes, selection.shapeId);
    return _commitShapes(
      state,
      state.shapes
          .where((shape) => shape.shapeId != selection.shapeId)
          .toList(growable: false),
      null,
    );
  }

  /// Duplicates the selected shape with the lowest free deterministic ID.
  ///
  /// The caller supplies an exact initial translation appropriate to its owner
  /// grid. Positive-area overlap remains blocking; exact edge contact is valid.
  TerrainPolygonInteractionResult duplicateSelectedShape(
    TerrainPolygonInteractionState state, {
    required int deltaXHalfPixels,
    required int deltaYHalfPixels,
  }) {
    final selection = state.selection;
    if (state.hasActiveOperation || selection == null) {
      return _acceptedNoOp(state);
    }
    final source = _requireShape(state.shapes, selection.shapeId);
    final duplicate = TerrainSourceShapeDef(
      shapeId: _allocateShapeId(state.shapes),
      vertices: source.vertices.map(
        (vertex) => TerrainSourceVertexDef(
          xHalfPixels: vertex.xHalfPixels + deltaXHalfPixels,
          yHalfPixels: vertex.yHalfPixels + deltaYHalfPixels,
        ),
      ),
      collisionMode: source.collisionMode,
      surfaceKind: source.surfaceKind,
      materialKey: source.materialKey,
    );
    final validation = _validateAndCanonicalize(
      duplicate,
      otherShapes: state.shapes,
    );
    if (validation.shape == null) {
      return _rejected(state, validation.diagnostics);
    }
    return _commitShapes(
      state,
      <TerrainSourceShapeDef>[...state.shapes, validation.shape!],
      TerrainPolygonSelection.shape(validation.shape!.shapeId),
      diagnostics: validation.diagnostics,
    );
  }

  /// Applies explicit collision-mode and optional metadata values.
  TerrainPolygonInteractionResult editSelectedShapeMetadata(
    TerrainPolygonInteractionState state, {
    required TerrainSourceCollisionMode collisionMode,
    required String? surfaceKind,
    required String? materialKey,
  }) {
    final selection = state.selection;
    if (state.hasActiveOperation || selection == null) {
      return _acceptedNoOp(state);
    }
    final shape = _requireShape(state.shapes, selection.shapeId);
    final updated = TerrainSourceShapeDef(
      shapeId: shape.shapeId,
      vertices: shape.vertices,
      collisionMode: collisionMode,
      surfaceKind: surfaceKind,
      materialKey: materialKey,
    );
    return _commitShapes(
      state,
      _replaceShape(state.shapes, updated),
      selection,
    );
  }

  /// Explicitly applies Core winding/start and collinear normalization.
  ///
  /// A rejected draft or gesture remains preview-only, but Normalize may
  /// explicitly accept its visible geometry after Core removes collinear
  /// middle vertices.
  TerrainPolygonInteractionResult normalizeSelectedShape(
    TerrainPolygonInteractionState state,
  ) {
    final draft = state.draft;
    final selection = state.selection;
    if (draft == null && selection == null) {
      return _acceptedNoOp(state);
    }
    final gesture = state.gesture;
    final shape = draft != null
        ? TerrainSourceShapeDef(
            shapeId: draft.shapeId,
            vertices: draft.vertices,
            collisionMode: draft.collisionMode,
            surfaceKind: draft.surfaceKind,
            materialKey: draft.materialKey,
          )
        : gesture?.previewShape ??
              _requireShape(state.shapes, selection!.shapeId);
    final review = TerrainSourceCoreAdapter.review(
      shape: shape,
      sourcePath: _shapeSourcePath(shape.shapeId),
      chunkIndex: -1,
      chunkKey: ownerKey,
      normalizeCollinear: true,
    );
    if (review.hasBlockingDiagnostics || review.canonicalVertices == null) {
      return _rejected(state, review.diagnostics);
    }
    final normalized = TerrainSourceCoreAdapter.applyCanonicalVertices(
      shape,
      review,
    );
    final overlapDiagnostics = _overlapDiagnostics(
      normalized,
      state.shapes.where(
        (candidate) => candidate.shapeId != normalized.shapeId,
      ),
    );
    if (overlapDiagnostics.isNotEmpty) {
      return _rejected(state, <TerrainDiagnostic>[
        ...review.diagnostics,
        ...overlapDiagnostics,
      ]);
    }
    return _commitShapes(
      state,
      draft != null
          ? <TerrainSourceShapeDef>[...state.shapes, normalized]
          : _replaceShape(state.shapes, normalized),
      TerrainPolygonSelection.shape(normalized.shapeId),
      diagnostics: review.diagnostics,
      clearDraft: draft != null,
      clearGesture: gesture != null,
      resetTool: draft != null,
    );
  }

  TerrainPolygonInteractionResult _commitValidatedReplacement(
    TerrainPolygonInteractionState state,
    TerrainSourceShapeDef candidate,
  ) {
    final validation = _validateAndCanonicalize(
      candidate,
      otherShapes: state.shapes.where(
        (shape) => shape.shapeId != candidate.shapeId,
      ),
    );
    if (validation.shape == null) {
      return _rejected(state, validation.diagnostics);
    }
    return _commitShapes(
      state,
      _replaceShape(state.shapes, validation.shape!),
      TerrainPolygonSelection.shape(validation.shape!.shapeId),
      diagnostics: validation.diagnostics,
    );
  }

  ({TerrainSourceShapeDef? shape, List<TerrainDiagnostic> diagnostics})
  _validateAndCanonicalize(
    TerrainSourceShapeDef shape, {
    required Iterable<TerrainSourceShapeDef> otherShapes,
  }) {
    final review = TerrainSourceCoreAdapter.review(
      shape: shape,
      sourcePath: _shapeSourcePath(shape.shapeId),
      chunkIndex: -1,
      chunkKey: ownerKey,
    );
    if (review.hasBlockingDiagnostics || review.canonicalVertices == null) {
      return (shape: null, diagnostics: review.diagnostics);
    }
    final canonical = TerrainSourceCoreAdapter.applyCanonicalVertices(
      shape,
      review,
    );
    final diagnostics = <TerrainDiagnostic>[
      ...review.diagnostics,
      ..._overlapDiagnostics(canonical, otherShapes),
    ]..sort();
    if (diagnostics.any(terrainDiagnosticIsBlocking)) {
      return (shape: null, diagnostics: diagnostics);
    }
    return (shape: canonical, diagnostics: diagnostics);
  }

  List<TerrainDiagnostic> _overlapDiagnostics(
    TerrainSourceShapeDef shape,
    Iterable<TerrainSourceShapeDef> otherShapes,
  ) {
    final source = _sourcePoints(shape);
    final diagnostics = <TerrainDiagnostic>[];
    for (final other in otherShapes) {
      if (TerrainPolygonOverlap.sourceLoops(source, _sourcePoints(other))) {
        diagnostics.add(
          _diagnostic(
            shape,
            0,
            'positive_area_shape_overlap',
            'Shape ${shape.shapeId} overlaps ${other.shapeId} in positive area.',
          ),
        );
      }
    }
    diagnostics.sort();
    return diagnostics;
  }

  TerrainPolygonInteractionResult _commitShapes(
    TerrainPolygonInteractionState state,
    Iterable<TerrainSourceShapeDef> afterShapes,
    TerrainPolygonSelection? afterSelection, {
    Iterable<TerrainDiagnostic> diagnostics = const <TerrainDiagnostic>[],
    bool clearDraft = false,
    bool clearGesture = false,
    bool resetTool = false,
  }) {
    final canonicalAfter = canonicalTerrainSourceShapes(afterShapes);
    final next = _state(
      state,
      shapes: canonicalAfter,
      tool: resetTool ? TerrainPolygonTool.select : state.tool,
      selection: afterSelection,
      replaceSelection: true,
      draft: clearDraft ? null : state.draft,
      replaceDraft: clearDraft,
      gesture: clearGesture ? null : state.gesture,
      replaceGesture: clearGesture,
    );
    if (_shapeListsEqual(state.shapes, canonicalAfter)) {
      return TerrainPolygonInteractionResult(
        state: next,
        accepted: true,
        commit: null,
        diagnostics: diagnostics,
      );
    }
    return TerrainPolygonInteractionResult(
      state: next,
      accepted: true,
      commit: TerrainPolygonInteractionCommit(
        beforeShapes: state.shapes,
        afterShapes: canonicalAfter,
        beforeSelection: state.selection,
        afterSelection: afterSelection,
      ),
      diagnostics: diagnostics,
    );
  }

  TerrainPolygonInteractionResult _acceptedNoOp(
    TerrainPolygonInteractionState state,
  ) => TerrainPolygonInteractionResult(
    state: state,
    accepted: true,
    commit: null,
    diagnostics: const <TerrainDiagnostic>[],
  );

  TerrainPolygonInteractionResult _rejected(
    TerrainPolygonInteractionState state,
    Iterable<TerrainDiagnostic> diagnostics,
  ) => TerrainPolygonInteractionResult(
    state: state,
    accepted: false,
    commit: null,
    diagnostics: diagnostics,
  );

  String _allocateShapeId(Iterable<TerrainSourceShapeDef> shapes) {
    final used = shapes.map((shape) => shape.shapeId.toLowerCase()).toSet();
    for (var ordinal = 1; ; ordinal++) {
      final candidate =
          '${shapeIdPrefix}_${ordinal.toString().padLeft(3, '0')}';
      if (!used.contains(candidate.toLowerCase())) return candidate;
    }
  }

  String _shapeSourcePath(String shapeId) => '$sourcePath:$ownerKey:$shapeId';

  TerrainDiagnostic _diagnostic(
    TerrainSourceShapeDef shape,
    int elementIndex,
    String code,
    String message,
  ) => TerrainDiagnostic(
    sourcePath: _shapeSourcePath(shape.shapeId),
    shapeId: shape.shapeId,
    elementIndex: elementIndex,
    code: code,
    message: message,
  );
}

TerrainPolygonInteractionState _state(
  TerrainPolygonInteractionState source, {
  List<TerrainSourceShapeDef>? shapes,
  TerrainPolygonTool? tool,
  TerrainPolygonSelection? selection,
  bool replaceSelection = false,
  TerrainPolygonDraft? draft,
  bool replaceDraft = false,
  TerrainPolygonGesture? gesture,
  bool replaceGesture = false,
}) => TerrainPolygonInteractionState._(
  shapes: shapes ?? source.shapes,
  selection: replaceSelection ? selection : source.selection,
  tool: tool ?? source.tool,
  draft: replaceDraft ? draft : source.draft,
  gesture: replaceGesture ? gesture : source.gesture,
);

List<List<TerrainSourceVertexDef>> _freezeVertexSnapshots(
  Iterable<Iterable<TerrainSourceVertexDef>> snapshots,
) => List<List<TerrainSourceVertexDef>>.unmodifiable(
  snapshots.map(List<TerrainSourceVertexDef>.unmodifiable),
);

TerrainPolygonDraft _recordDraftVertices(
  TerrainPolygonDraft draft,
  Iterable<TerrainSourceVertexDef> vertices,
) => _draftWithHistory(
  draft,
  vertices: vertices,
  undoVertexSnapshots: <List<TerrainSourceVertexDef>>[
    ...draft.undoVertexSnapshots,
    draft.vertices,
  ],
  redoVertexSnapshots: const <List<TerrainSourceVertexDef>>[],
);

TerrainPolygonDraft _draftWithHistory(
  TerrainPolygonDraft source, {
  required Iterable<TerrainSourceVertexDef> vertices,
  required Iterable<Iterable<TerrainSourceVertexDef>> undoVertexSnapshots,
  required Iterable<Iterable<TerrainSourceVertexDef>> redoVertexSnapshots,
}) => TerrainPolygonDraft(
  shapeId: source.shapeId,
  collisionMode: source.collisionMode,
  surfaceKind: source.surfaceKind,
  materialKey: source.materialKey,
  vertices: vertices,
  undoVertexSnapshots: undoVertexSnapshots,
  redoVertexSnapshots: redoVertexSnapshots,
);

TerrainSourceShapeDef _draftAsShape(TerrainPolygonDraft draft) =>
    TerrainSourceShapeDef(
      shapeId: draft.shapeId,
      vertices: draft.vertices,
      collisionMode: draft.collisionMode,
      surfaceKind: draft.surfaceKind,
      materialKey: draft.materialKey,
    );

TerrainSourceShapeDef _requireShape(
  Iterable<TerrainSourceShapeDef> shapes,
  String shapeId,
) {
  for (final shape in shapes) {
    if (shape.shapeId == shapeId) return shape;
  }
  throw ArgumentError.value(shapeId, 'shapeId', 'Shape does not exist.');
}

void _requireVertexIndex(TerrainSourceShapeDef shape, int vertexIndex) {
  if (vertexIndex < 0 || vertexIndex >= shape.vertices.length) {
    throw RangeError.index(vertexIndex, shape.vertices, 'vertexIndex');
  }
}

void _requireEdgeIndex(TerrainSourceShapeDef shape, int edgeIndex) {
  if (edgeIndex < 0 || edgeIndex >= shape.vertices.length) {
    throw RangeError.index(edgeIndex, shape.vertices, 'edgeIndex');
  }
}

bool _selectionExists(
  Iterable<TerrainSourceShapeDef> shapes,
  TerrainPolygonSelection selection,
) {
  TerrainSourceShapeDef? selectedShape;
  for (final shape in shapes) {
    if (shape.shapeId == selection.shapeId) {
      selectedShape = shape;
      break;
    }
  }
  if (selectedShape == null) return false;
  return switch (selection.kind) {
    TerrainPolygonSelectionKind.shape => true,
    TerrainPolygonSelectionKind.edge || TerrainPolygonSelectionKind.vertex =>
      selection.elementIndex! < selectedShape.vertices.length,
  };
}

TerrainSourceShapeDef _shapeWithVertices(
  TerrainSourceShapeDef source,
  Iterable<TerrainSourceVertexDef> vertices,
) => TerrainSourceShapeDef(
  shapeId: source.shapeId,
  vertices: vertices,
  collisionMode: source.collisionMode,
  surfaceKind: source.surfaceKind,
  materialKey: source.materialKey,
);

List<TerrainSourceShapeDef> _replaceShape(
  Iterable<TerrainSourceShapeDef> shapes,
  TerrainSourceShapeDef replacement,
) => canonicalTerrainSourceShapes(<TerrainSourceShapeDef>[
  for (final shape in shapes)
    if (shape.shapeId == replacement.shapeId) replacement else shape,
]);

TerrainPolygonSelection _selectionForCanonicalVertex(
  TerrainSourceShapeDef canonical,
  TerrainSourceVertexDef selectedVertex,
) {
  final index = canonical.vertices.indexOf(selectedVertex);
  return index < 0
      ? TerrainPolygonSelection.shape(canonical.shapeId)
      : TerrainPolygonSelection.vertex(canonical.shapeId, index);
}

List<SourceTerrainPoint> _sourcePoints(TerrainSourceShapeDef shape) => shape
    .vertices
    .map((vertex) => SourceTerrainPoint(vertex.xHalfPixels, vertex.yHalfPixels))
    .toList(growable: false);

bool _shapeListsEqual(
  List<TerrainSourceShapeDef> left,
  List<TerrainSourceShapeDef> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _requireSelectionShapeId(String shapeId) {
  if (shapeId.isEmpty) {
    throw ArgumentError.value(shapeId, 'shapeId', 'Must not be empty.');
  }
  return shapeId;
}

int _requireElementIndex(int elementIndex) {
  if (elementIndex < 0) {
    throw RangeError.value(
      elementIndex,
      'elementIndex',
      'Must be non-negative.',
    );
  }
  return elementIndex;
}

int _roundToStep(int value, int step) {
  if (step == 1 || value == 0) return value;
  final magnitude = value.abs();
  var quotient = magnitude ~/ step;
  final remainder = magnitude.remainder(step);
  if (remainder * 2 >= step) quotient++;
  final snapped = quotient * step;
  return value.isNegative ? -snapped : snapped;
}

int _roundFractionalHalfAwayFromZero(double value) =>
    value >= 0 ? (value + 0.5).floor() : (value - 0.5).ceil();
