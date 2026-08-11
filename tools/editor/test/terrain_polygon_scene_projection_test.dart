import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_scene_projection.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  group('scene projection', () {
    test('projects selection and gesture preview without changing source', () {
      final reducer = _reducer();
      final initial = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('shape_a')],
      );
      var state = reducer.beginMoveVertex(
        initial,
        pointer: 1,
        shapeId: 'shape_a',
        vertexIndex: 1,
        startPointer: initial.shapes.single.vertices[1],
      );
      state = reducer.updateGesture(
        state,
        pointer: 1,
        currentPointer: const TerrainSourceVertexDef(
          xHalfPixels: 24,
          yHalfPixels: 0,
        ),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      );

      final projection = TerrainPolygonSceneProjection.fromInteraction(state);

      expect(initial.shapes.single.vertices[1].xHalfPixels, 20);
      expect(projection.shapes.single.shape.vertices[1].xHalfPixels, 24);
      expect(projection.shapes.single.isGesturePreview, isTrue);
      expect(projection.shapes.single.isSelected, isTrue);
      expect(projection.shapes.single.selectedVertexIndex, 1);
      expect(projection.shapes.single.selectedEdgeIndex, isNull);
    });

    test('projects an open draft separately from committed shapes', () {
      final reducer = _reducer();
      var state = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('shape_a')],
      );
      state = reducer.beginCreatePolygon(
        state,
        collisionMode: TerrainSourceCollisionMode.oneWay,
        surfaceKind: 'wood',
      );
      state = reducer.addDraftVertex(
        state,
        rawVertex: const TerrainSourceVertexDef(
          xHalfPixels: 41,
          yHalfPixels: 2,
        ),
        snap: TerrainPolygonSnapPolicy.ownerGridPixels(2),
      );

      final projection = TerrainPolygonSceneProjection.fromInteraction(state);

      expect(projection.shapes, hasLength(1));
      expect(projection.draft!.shapeId, 'shape_001');
      expect(
        projection.draft!.collisionMode,
        TerrainSourceCollisionMode.oneWay,
      );
      expect(projection.draft!.surfaceKind, 'wood');
      expect(
        projection.draft!.vertices.single,
        const TerrainSourceVertexDef(xHalfPixels: 40, yHalfPixels: 4),
      );
      expect(projection.draft!.isGesturePreview, isFalse);
      expect(projection.draft!.selectedVertexIndex, isNull);
    });

    test('projects a draft vertex gesture without changing draft source', () {
      final reducer = _reducer();
      var state = TerrainPolygonInteractionState(
        shapes: const <TerrainSourceShapeDef>[],
      );
      state = reducer.beginCreatePolygon(state);
      state = reducer.addDraftVertex(
        state,
        rawVertex: const TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      );
      state = reducer.beginMoveDraftVertex(
        state,
        pointer: 4,
        vertexIndex: 0,
        startPointer: state.draft!.vertices.single,
      );
      state = reducer.updateGesture(
        state,
        pointer: 4,
        currentPointer: const TerrainSourceVertexDef(
          xHalfPixels: 8,
          yHalfPixels: 4,
        ),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      );

      final projection = TerrainPolygonSceneProjection.fromInteraction(state);

      expect(state.draft!.vertices.single.xHalfPixels, 0);
      expect(projection.draft!.vertices.single.xHalfPixels, 8);
      expect(projection.draft!.isGesturePreview, isTrue);
      expect(projection.draft!.selectedVertexIndex, 0);
    });
  });

  group('source-space hit testing', () {
    test('draft hit testing uses vertices and open edges only', () {
      final reducer = _reducer();
      var state = TerrainPolygonInteractionState(
        shapes: const <TerrainSourceShapeDef>[],
      );
      state = reducer.beginCreatePolygon(state);
      for (final vertex in const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
      ]) {
        state = reducer.addDraftVertex(
          state,
          rawVertex: vertex,
          snap: const TerrainPolygonSnapPolicy.halfPixel(),
        );
      }
      final projection = TerrainPolygonSceneProjection.fromInteraction(state);

      expect(
        TerrainPolygonSceneHitTest.hitTestDraftVertex(
          projection: projection,
          point: const TerrainPolygonScenePoint(1, 0),
          radiusHalfPixels: 2,
        ),
        0,
      );
      expect(
        TerrainPolygonSceneHitTest.hitTestDraftEdge(
          projection: projection,
          point: const TerrainPolygonScenePoint(10, 1),
          radiusHalfPixels: 2,
        ),
        0,
      );
      expect(
        TerrainPolygonSceneHitTest.hitTestDraftEdge(
          projection: projection,
          point: const TerrainPolygonScenePoint(10, 10),
          radiusHalfPixels: 0.5,
        ),
        isNull,
      );
    });

    test('uses vertex then edge then fill priority', () {
      final projection = _projection(<TerrainSourceShapeDef>[
        _rectangle('shape_a'),
      ]);

      final vertex = TerrainPolygonSceneHitTest.hitTest(
        projection: projection,
        point: const TerrainPolygonScenePoint(1, 1),
        vertexRadiusHalfPixels: 3,
        edgeRadiusHalfPixels: 3,
      );
      final edge = TerrainPolygonSceneHitTest.hitTest(
        projection: projection,
        point: const TerrainPolygonScenePoint(10, 1),
        vertexRadiusHalfPixels: 2,
        edgeRadiusHalfPixels: 2,
      );
      final fill = TerrainPolygonSceneHitTest.hitTest(
        projection: projection,
        point: const TerrainPolygonScenePoint(10, 10),
        vertexRadiusHalfPixels: 2,
        edgeRadiusHalfPixels: 2,
      );

      expect(vertex, TerrainPolygonSelection.vertex('shape_a', 0));
      expect(edge, TerrainPolygonSelection.edge('shape_a', 0));
      expect(fill, TerrainPolygonSelection.shape('shape_a'));
    });

    test('fill can be disabled independently from handles', () {
      final projection = _projection(<TerrainSourceShapeDef>[
        _rectangle('shape_a'),
      ]);

      final selection = TerrainPolygonSceneHitTest.hitTest(
        projection: projection,
        point: const TerrainPolygonScenePoint(10, 10),
        vertexRadiusHalfPixels: 1,
        edgeRadiusHalfPixels: 1,
        includeShapeFill: false,
      );

      expect(selection, isNull);
    });

    test('closest feature wins before deterministic shape tie-breaks', () {
      final shapes = <TerrainSourceShapeDef>[
        _rectangle('shape_a'),
        _rectangle('shape_b', offsetX: 2),
      ];
      final selectedA = _projection(
        shapes,
        selection: TerrainPolygonSelection.shape('shape_a'),
      );

      final closest = TerrainPolygonSceneHitTest.hitTest(
        projection: selectedA,
        point: const TerrainPolygonScenePoint(2, 0),
        vertexRadiusHalfPixels: 3,
        edgeRadiusHalfPixels: 0,
      );
      final equalDistance = TerrainPolygonSceneHitTest.hitTest(
        projection: selectedA,
        point: const TerrainPolygonScenePoint(1, 0),
        vertexRadiusHalfPixels: 2,
        edgeRadiusHalfPixels: 0,
      );

      expect(closest, TerrainPolygonSelection.vertex('shape_b', 0));
      expect(equalDistance, TerrainPolygonSelection.vertex('shape_a', 0));
    });

    test('fill prefers selected shape then topmost canonical shape', () {
      final shapes = <TerrainSourceShapeDef>[
        _rectangle('shape_a'),
        _rectangle('shape_b'),
      ];
      final unselected = _projection(shapes);
      final selectedA = _projection(
        shapes,
        selection: TerrainPolygonSelection.shape('shape_a'),
      );

      TerrainPolygonSelection? hit(TerrainPolygonSceneProjection projection) =>
          TerrainPolygonSceneHitTest.hitTest(
            projection: projection,
            point: const TerrainPolygonScenePoint(10, 10),
            vertexRadiusHalfPixels: 0,
            edgeRadiusHalfPixels: 0,
          );

      expect(hit(unselected), TerrainPolygonSelection.shape('shape_b'));
      expect(hit(selectedA), TerrainPolygonSelection.shape('shape_a'));
    });

    test('concave fill and boundary hits remain deterministic', () {
      final concave = _shape('shape_a', const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
      ]);
      final projection = _projection(<TerrainSourceShapeDef>[concave]);

      final arm = TerrainPolygonSceneHitTest.hitTest(
        projection: projection,
        point: const TerrainPolygonScenePoint(4, 16),
        vertexRadiusHalfPixels: 0,
        edgeRadiusHalfPixels: 0,
      );
      final notch = TerrainPolygonSceneHitTest.hitTest(
        projection: projection,
        point: const TerrainPolygonScenePoint(16, 16),
        vertexRadiusHalfPixels: 0,
        edgeRadiusHalfPixels: 0,
      );
      final boundary = TerrainPolygonSceneHitTest.hitTest(
        projection: projection,
        point: const TerrainPolygonScenePoint(8, 14),
        vertexRadiusHalfPixels: 0,
        edgeRadiusHalfPixels: 0,
      );

      expect(arm, TerrainPolygonSelection.shape('shape_a'));
      expect(notch, isNull);
      expect(boundary, TerrainPolygonSelection.edge('shape_a', 3));
    });

    test('rejects non-finite coordinates and invalid radii', () {
      final projection = _projection(<TerrainSourceShapeDef>[
        _rectangle('shape_a'),
      ]);

      expect(
        () => TerrainPolygonSceneHitTest.hitTest(
          projection: projection,
          point: const TerrainPolygonScenePoint(double.nan, 0),
          vertexRadiusHalfPixels: 1,
          edgeRadiusHalfPixels: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => TerrainPolygonSceneHitTest.hitTest(
          projection: projection,
          point: const TerrainPolygonScenePoint(0, 0),
          vertexRadiusHalfPixels: -1,
          edgeRadiusHalfPixels: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}

TerrainPolygonInteractionReducer _reducer() => TerrainPolygonInteractionReducer(
  sourcePath: 'test/source.json',
  ownerKey: 'owner',
  shapeIdPrefix: 'shape',
);

TerrainPolygonSceneProjection _projection(
  Iterable<TerrainSourceShapeDef> shapes, {
  TerrainPolygonSelection? selection,
}) => TerrainPolygonSceneProjection.fromInteraction(
  TerrainPolygonInteractionState(shapes: shapes, selection: selection),
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
