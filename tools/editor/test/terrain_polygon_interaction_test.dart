import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  group('snap and selection', () {
    test('owner-grid snapping is exact and resolves ties away from zero', () {
      final snap = TerrainPolygonSnapPolicy.ownerGridPixels(4);

      expect(snap.stepHalfPixels, 8);
      expect(snap.snapCoordinate(3), 0);
      expect(snap.snapCoordinate(4), 8);
      expect(snap.snapCoordinate(-3), 0);
      expect(snap.snapCoordinate(-4), -8);
      expect(const TerrainPolygonSnapPolicy.halfPixel().snapCoordinate(-7), -7);
    });

    test('fractional pointer snapping chooses the nearest exact grid cell', () {
      final grid = TerrainPolygonSnapPolicy.ownerGridPixels(4);
      const halfPixel = TerrainPolygonSnapPolicy.halfPixel();

      expect(grid.snapFractionalCoordinate(3.9), 0);
      expect(grid.snapFractionalCoordinate(4), 8);
      expect(grid.snapFractionalCoordinate(-3.9), 0);
      expect(grid.snapFractionalCoordinate(-4), -8);
      expect(
        halfPixel.snapFractionalVertex(xHalfPixels: 2.5, yHalfPixels: -2.5),
        const TerrainSourceVertexDef(xHalfPixels: 3, yHalfPixels: -3),
      );
      expect(
        () => grid.snapFractionalCoordinate(double.nan),
        throwsArgumentError,
      );
    });

    test('shape, edge, and vertex selections validate committed indices', () {
      final reducer = _reducer();
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
      );

      final shape = reducer.select(
        initial,
        TerrainPolygonSelection.shape('collision_001'),
      );
      final edge = reducer.select(
        shape,
        TerrainPolygonSelection.edge('collision_001', 3),
      );
      final vertex = reducer.select(
        edge,
        TerrainPolygonSelection.vertex('collision_001', 2),
      );

      expect(shape.selection!.kind, TerrainPolygonSelectionKind.shape);
      expect(edge.selection!.kind, TerrainPolygonSelectionKind.edge);
      expect(vertex.selection!.kind, TerrainPolygonSelectionKind.vertex);
      expect(
        () => reducer.select(
          initial,
          TerrainPolygonSelection.edge('collision_001', 4),
        ),
        throwsArgumentError,
      );
      expect(
        () => TerrainPolygonInteractionState(
          shapes: initial.shapes,
          selection: TerrainPolygonSelection.vertex('collision_001', 9),
        ),
        throwsArgumentError,
      );
    });

    test(
      'tool changes are local state and active operations own their tool',
      () {
        final reducer = _reducer();
        final initial = TerrainPolygonInteractionState(
          shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
        );
        final insertTool = reducer.setTool(
          initial,
          TerrainPolygonTool.insertVertex,
        );
        final gesture = reducer.beginMoveVertex(
          insertTool,
          pointer: 1,
          shapeId: 'collision_001',
          vertexIndex: 0,
          startPointer: initial.shapes.single.vertices.first,
        );
        final ignoredSwitch = reducer.setTool(
          gesture,
          TerrainPolygonTool.createPolygon,
        );
        final cancelled = reducer.cancelActiveOperation(ignoredSwitch);

        expect(initial.tool, TerrainPolygonTool.select);
        expect(insertTool.tool, TerrainPolygonTool.insertVertex);
        expect(gesture.tool, TerrainPolygonTool.moveVertex);
        expect(ignoredSwitch, same(gesture));
        expect(cancelled.tool, TerrainPolygonTool.select);
      },
    );
  });

  group('polygon creation', () {
    test('ordered clicks close as one canonical Core-reviewed commit', () {
      final reducer = _reducer();
      var state = TerrainPolygonInteractionState(
        shapes: const <TerrainSourceShapeDef>[],
      );
      state = reducer.beginCreatePolygon(state);
      for (final vertex in const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
      ]) {
        state = reducer.addDraftVertex(
          state,
          rawVertex: vertex,
          snap: const TerrainPolygonSnapPolicy.halfPixel(),
        );
      }

      final result = reducer.closePolygon(state);

      expect(result.accepted, isTrue);
      expect(result.diagnostics, isEmpty);
      expect(result.commit, isNotNull);
      expect(result.commit!.beforeShapes, isEmpty);
      expect(result.commit!.afterShapes, hasLength(1));
      expect(result.state.draft, isNull);
      expect(
        result.state.selection,
        TerrainPolygonSelection.shape('collision_001'),
      );
      expect(
        result.state.shapes.single.collisionMode,
        TerrainSourceCollisionMode.solid,
      );
      expect(result.state.shapes.single.surfaceKind, isNull);
      expect(
        result.state.shapes.single.vertices,
        const <TerrainSourceVertexDef>[
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
        ],
      );
    });

    test('invalid close retains the draft and Escape cancels it', () {
      final reducer = _reducer();
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
        selection: TerrainPolygonSelection.shape('collision_001'),
      );
      var state = reducer.beginCreatePolygon(initial);
      state = reducer.addDraftVertex(
        state,
        rawVertex: const TerrainSourceVertexDef(
          xHalfPixels: 40,
          yHalfPixels: 0,
        ),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      );

      final rejected = reducer.closePolygon(state);
      final cancelled = reducer.cancelActiveOperation(rejected.state);

      expect(rejected.accepted, isFalse);
      expect(
        rejected.diagnostics.map((diagnostic) => diagnostic.code),
        contains('too_few_vertices'),
      );
      expect(rejected.state.draft, isNotNull);
      expect(cancelled.draft, isNull);
      expect(cancelled.shapes, initial.shapes);
      expect(cancelled.selection, initial.selection);
    });
  });

  group('gesture lifecycle', () {
    test('vertex drag previews freely and commits one history snapshot', () {
      final reducer = _reducer();
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
      );
      var state = reducer.beginMoveVertex(
        initial,
        pointer: 7,
        shapeId: 'collision_001',
        vertexIndex: 1,
        startPointer: initial.shapes.single.vertices[1],
      );
      state = reducer.updateGesture(
        state,
        pointer: 7,
        currentPointer: const TerrainSourceVertexDef(
          xHalfPixels: 24,
          yHalfPixels: 0,
        ),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      );

      expect(initial.shapes.single.vertices[1].xHalfPixels, 20);
      expect(state.shapes.single.vertices[1].xHalfPixels, 20);
      expect(state.visibleShapes.single.vertices[1].xHalfPixels, 24);

      final result = reducer.commitGesture(state, pointer: 7);

      expect(result.accepted, isTrue);
      expect(result.commit, isNotNull);
      expect(result.commit!.beforeShapes, initial.shapes);
      expect(result.commit!.afterShapes.single.vertices[1].xHalfPixels, 24);
      expect(result.state.gesture, isNull);
      expect(result.state.selection!.kind, TerrainPolygonSelectionKind.vertex);
    });

    test('invalid drag stays preview-only until Escape restores source', () {
      final reducer = _reducer();
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
      );
      var state = reducer.beginMoveVertex(
        initial,
        pointer: 3,
        shapeId: 'collision_001',
        vertexIndex: 1,
        startPointer: initial.shapes.single.vertices[1],
      );
      state = reducer.updateGesture(
        state,
        pointer: 3,
        currentPointer: initial.shapes.single.vertices[3],
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      );

      final rejected = reducer.commitGesture(state, pointer: 3);
      final cancelled = reducer.cancelActiveOperation(rejected.state);

      expect(rejected.accepted, isFalse);
      expect(rejected.commit, isNull);
      expect(rejected.state.gesture, isNotNull);
      expect(rejected.diagnostics, isNotEmpty);
      expect(cancelled.visibleShapes, initial.shapes);
      expect(cancelled.gesture, isNull);
    });

    test('whole-shape translation uses one exact snapped delta', () {
      final reducer = _reducer();
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
      );
      var state = reducer.beginTranslateShape(
        initial,
        pointer: 1,
        shapeId: 'collision_001',
        startPointer: const TerrainSourceVertexDef(
          xHalfPixels: 0,
          yHalfPixels: 0,
        ),
      );
      state = reducer.updateGesture(
        state,
        pointer: 1,
        currentPointer: const TerrainSourceVertexDef(
          xHalfPixels: 5,
          yHalfPixels: -5,
        ),
        snap: TerrainPolygonSnapPolicy.ownerGridPixels(4),
      );

      final result = reducer.commitGesture(state, pointer: 1);

      expect(result.accepted, isTrue);
      expect(
        result.state.shapes.single.vertices.first,
        const TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
      );
      expect(result.state.selection!.kind, TerrainPolygonSelectionKind.shape);
    });

    test('no-op gesture does not silently normalize loaded geometry', () {
      final reducer = _reducer();
      final rotated = _shape('collision_001', const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
      ]);
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[rotated],
      );
      final state = reducer.beginTranslateShape(
        initial,
        pointer: 5,
        shapeId: 'collision_001',
        startPointer: const TerrainSourceVertexDef(
          xHalfPixels: 0,
          yHalfPixels: 0,
        ),
      );

      final result = reducer.commitGesture(state, pointer: 5);

      expect(result.accepted, isTrue);
      expect(result.commit, isNull);
      expect(result.state.gesture, isNull);
      expect(result.state.shapes.single.vertices, rotated.vertices);
    });

    test(
      'edge insertion remains provisional until moved to valid geometry',
      () {
        final reducer = _reducer();
        final initial = TerrainPolygonInteractionState(
          shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
        );
        var state = reducer.beginInsertVertex(
          initial,
          pointer: 9,
          shapeId: 'collision_001',
          edgeIndex: 0,
          rawVertex: const TerrainSourceVertexDef(
            xHalfPixels: 10,
            yHalfPixels: 0,
          ),
          snap: const TerrainPolygonSnapPolicy.halfPixel(),
        );

        expect(state.shapes.single.vertices, hasLength(4));
        expect(state.visibleShapes.single.vertices, hasLength(5));
        expect(reducer.commitGesture(state, pointer: 9).accepted, isFalse);

        state = reducer.updateGesture(
          state,
          pointer: 9,
          currentPointer: const TerrainSourceVertexDef(
            xHalfPixels: 10,
            yHalfPixels: -10,
          ),
          snap: const TerrainPolygonSnapPolicy.halfPixel(),
        );
        final result = reducer.commitGesture(state, pointer: 9);

        expect(result.accepted, isTrue);
        expect(result.state.shapes.single.vertices, hasLength(5));
        expect(result.commit, isNotNull);
      },
    );
  });

  group('immediate semantic edits', () {
    test('vertex deletion enforces three vertices and remains undoable', () {
      final reducer = _reducer();
      final triangle = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[
          _shape('collision_001', const <TerrainSourceVertexDef>[
            TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
            TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
            TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
          ]),
        ],
        selection: TerrainPolygonSelection.vertex('collision_001', 1),
      );
      final rejected = reducer.deleteSelectedVertex(triangle);

      expect(rejected.accepted, isFalse);
      expect(rejected.diagnostics.single.code, 'minimum_vertex_count');

      final rectangle = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
        selection: TerrainPolygonSelection.vertex('collision_001', 1),
      );
      final accepted = reducer.deleteSelectedVertex(rectangle);

      expect(accepted.accepted, isTrue);
      expect(accepted.commit, isNotNull);
      expect(accepted.state.shapes.single.vertices, hasLength(3));
    });

    test('duplicate uses the lowest free ID and permits shared edges', () {
      final reducer = _reducer();
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[
          _rectangle('collision_001'),
          _rectangle('collision_003', offsetX: 60),
        ],
        selection: TerrainPolygonSelection.shape('collision_001'),
      );

      final result = reducer.duplicateSelectedShape(
        initial,
        deltaXHalfPixels: 20,
        deltaYHalfPixels: 0,
      );

      expect(result.accepted, isTrue);
      expect(result.state.shapes.map((shape) => shape.shapeId), <String>[
        'collision_001',
        'collision_002',
        'collision_003',
      ]);
      expect(
        result.state.selection,
        TerrainPolygonSelection.shape('collision_002'),
      );
    });

    test('duplicate rejects positive-area overlap', () {
      final reducer = _reducer();
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
        selection: TerrainPolygonSelection.shape('collision_001'),
      );

      final result = reducer.duplicateSelectedShape(
        initial,
        deltaXHalfPixels: 10,
        deltaYHalfPixels: 0,
      );

      expect(result.accepted, isFalse);
      expect(result.commit, isNull);
      expect(
        result.diagnostics.map((diagnostic) => diagnostic.code),
        contains('positive_area_shape_overlap'),
      );
    });

    test('metadata edits and shape deletion each produce one commit', () {
      final reducer = _reducer();
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
        selection: TerrainPolygonSelection.shape('collision_001'),
      );

      final metadata = reducer.editSelectedShapeMetadata(
        initial,
        collisionMode: TerrainSourceCollisionMode.oneWay,
        surfaceKind: 'wood',
        materialKey: null,
      );
      final deleted = reducer.deleteSelectedShape(metadata.state);

      expect(metadata.commit, isNotNull);
      expect(
        metadata.state.shapes.single.collisionMode,
        TerrainSourceCollisionMode.oneWay,
      );
      expect(metadata.state.shapes.single.surfaceKind, 'wood');
      expect(deleted.commit, isNotNull);
      expect(deleted.state.shapes, isEmpty);
      expect(deleted.state.selection, isNull);
    });

    test('Normalize is explicit and reports removed collinear vertices', () {
      final reducer = _reducer();
      final shape = _shape('collision_001', const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 10, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
      ]);
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[shape],
        selection: TerrainPolygonSelection.shape('collision_001'),
      );

      expect(initial.shapes.single.vertices, hasLength(5));
      final result = reducer.normalizeSelectedShape(initial);

      expect(result.accepted, isTrue);
      expect(result.commit, isNotNull);
      expect(result.state.shapes.single.vertices, hasLength(4));
      expect(
        result.diagnostics.map((diagnostic) => diagnostic.code),
        contains('normalized_collinear_vertex'),
      );
    });
  });
}

TerrainPolygonInteractionReducer _reducer() => TerrainPolygonInteractionReducer(
  sourcePath: 'test/prefab_defs.json',
  ownerKey: 'test_prefab',
  shapeIdPrefix: 'collision',
);

TerrainSourceShapeDef _rectangle(String shapeId, {int offsetX = 0}) =>
    _shape(shapeId, <TerrainSourceVertexDef>[
      TerrainSourceVertexDef(xHalfPixels: offsetX, yHalfPixels: 0),
      TerrainSourceVertexDef(xHalfPixels: offsetX + 20, yHalfPixels: 0),
      TerrainSourceVertexDef(xHalfPixels: offsetX + 20, yHalfPixels: 20),
      TerrainSourceVertexDef(xHalfPixels: offsetX, yHalfPixels: 20),
    ]);

TerrainSourceShapeDef _shape(
  String shapeId,
  Iterable<TerrainSourceVertexDef> vertices,
) => TerrainSourceShapeDef(shapeId: shapeId, vertices: vertices);
