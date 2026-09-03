import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_polygon_scene_painter.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_scene_projection.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_core_adapter.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  group('TerrainPolygonViewportTransform', () {
    test('maps exact half-pixel ticks to canvas and back', () {
      final transform = TerrainPolygonViewportTransform(
        origin: const Offset(100, 50),
        zoom: 2,
      );

      expect(
        transform.sourceVertexToCanvas(
          const TerrainSourceVertexDef(xHalfPixels: 3, yHalfPixels: -1),
        ),
        const Offset(103, 49),
      );
      expect(
        transform.canvasToSource(const Offset(103, 49)),
        const TerrainPolygonScenePoint(3, -1),
      );
      expect(transform.canvasRadiusToSourceHalfPixels(4), 4);
    });

    test('preserves fractional pointer positions for the snap policy', () {
      final transform = TerrainPolygonViewportTransform(
        origin: const Offset(10, 20),
        zoom: 4,
      );

      expect(
        transform.canvasToSource(const Offset(15, 17)),
        const TerrainPolygonScenePoint(2.5, -1.5),
      );
    });

    test('rejects invalid viewport and pointer inputs', () {
      expect(
        () => TerrainPolygonViewportTransform(
          origin: const Offset(double.nan, 0),
          zoom: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => TerrainPolygonViewportTransform(origin: Offset.zero, zoom: 0),
        throwsArgumentError,
      );
      final transform = TerrainPolygonViewportTransform(
        origin: Offset.zero,
        zoom: 1,
      );
      expect(
        () => transform.canvasToSource(const Offset(double.infinity, 0)),
        throwsArgumentError,
      );
      expect(
        () => transform.canvasRadiusToSourceHalfPixels(-1),
        throwsArgumentError,
      );
    });
  });

  group('TerrainPolygonScenePainter', () {
    test('repaints only when semantic scene inputs change', () {
      final state = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('shape_a')],
      );
      final equivalentState = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[_rectangle('shape_a')],
      );
      final transform = TerrainPolygonViewportTransform(
        origin: Offset.zero,
        zoom: 2,
      );
      final painter = TerrainPolygonScenePainter(
        projection: TerrainPolygonSceneProjection.fromInteraction(state),
        transform: transform,
      );

      expect(
        TerrainPolygonScenePainter(
          projection: TerrainPolygonSceneProjection.fromInteraction(
            equivalentState,
          ),
          transform: TerrainPolygonViewportTransform(
            origin: Offset.zero,
            zoom: 2,
          ),
        ).shouldRepaint(painter),
        isFalse,
      );
      expect(
        TerrainPolygonScenePainter(
          projection: TerrainPolygonSceneProjection.fromInteraction(
            TerrainPolygonInteractionState(
              shapes: state.shapes,
              selection: TerrainPolygonSelection.shape('shape_a'),
            ),
          ),
          transform: transform,
        ).shouldRepaint(painter),
        isTrue,
      );
      expect(
        TerrainPolygonScenePainter(
          projection: painter.projection,
          transform: TerrainPolygonViewportTransform(
            origin: const Offset(1, 0),
            zoom: 2,
          ),
        ).shouldRepaint(painter),
        isTrue,
      );
      expect(
        TerrainPolygonScenePainter(
          projection: painter.projection,
          transform: transform,
          style: const TerrainPolygonSceneStyle(outlineWidth: 2),
        ).shouldRepaint(painter),
        isTrue,
      );
      expect(
        TerrainPolygonScenePainter(
          projection: painter.projection,
          transform: transform,
          showActiveOneWayEdges: true,
        ).shouldRepaint(painter),
        isTrue,
      );
    });

    test('one-way preview edge classification matches Core exposure', () {
      final shape = TerrainSourceShapeDef(
        shapeId: 'platform_surface',
        collisionMode: TerrainSourceCollisionMode.oneWay,
        vertices: const <TerrainSourceVertexDef>[
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 4),
          TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 4),
          TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 16, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 16, yHalfPixels: 12),
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 12),
        ],
      );
      final previewIndices = <int>{
        for (var index = 0; index < shape.vertices.length; index += 1)
          if (terrainSourceEdgeIsActiveOneWay(
            shape.vertices[index],
            shape.vertices[(index + 1) % shape.vertices.length],
          ))
            index,
      };
      final geometry = const TerrainCompiler().compile([
        TerrainSourceCoreAdapter.toPolygonInput(
          shape: shape,
          sourcePath: 'test/platform.json',
          chunkIndex: 0,
          chunkKey: 'test',
        ),
      ], geometryVersion: 1);

      expect(
        geometry.edges.map((edge) => edge.id.localEdgeIndex).toSet(),
        previewIndices,
      );
      expect(previewIndices, <int>{0, 2});
    });

    testWidgets('renders solids, one-way shapes, previews, and open drafts', (
      tester,
    ) async {
      final reducer = TerrainPolygonInteractionReducer(
        sourcePath: 'test/source.json',
        ownerKey: 'owner',
        shapeIdPrefix: 'shape',
      );
      var state = TerrainPolygonInteractionState(
        shapes: <TerrainSourceShapeDef>[
          _rectangle('solid'),
          TerrainSourceShapeDef(
            shapeId: 'one_way',
            collisionMode: TerrainSourceCollisionMode.oneWay,
            vertices: const <TerrainSourceVertexDef>[
              TerrainSourceVertexDef(xHalfPixels: 24, yHalfPixels: 0),
              TerrainSourceVertexDef(xHalfPixels: 44, yHalfPixels: 0),
              TerrainSourceVertexDef(xHalfPixels: 44, yHalfPixels: 20),
              TerrainSourceVertexDef(xHalfPixels: 24, yHalfPixels: 20),
            ],
          ),
        ],
      );
      state = reducer.beginMoveVertex(
        state,
        pointer: 1,
        shapeId: 'solid',
        vertexIndex: 1,
        startPointer: state.shapes.first.vertices[1],
      );
      state = reducer.updateGesture(
        state,
        pointer: 1,
        currentPointer: const TerrainSourceVertexDef(
          xHalfPixels: 22,
          yHalfPixels: 2,
        ),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      );
      final previewProjection = TerrainPolygonSceneProjection.fromInteraction(
        state,
      );
      state = reducer.cancelActiveOperation(state);
      state = reducer.beginCreatePolygon(
        state,
        collisionMode: TerrainSourceCollisionMode.solid,
      );
      state = reducer.addDraftVertex(
        state,
        rawVertex: const TerrainSourceVertexDef(
          xHalfPixels: 0,
          yHalfPixels: 24,
        ),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      );
      state = reducer.addDraftVertex(
        state,
        rawVertex: const TerrainSourceVertexDef(
          xHalfPixels: 20,
          yHalfPixels: 24,
        ),
        snap: const TerrainPolygonSnapPolicy.halfPixel(),
      );

      Future<void> pumpProjection(TerrainPolygonSceneProjection projection) =>
          tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: CustomPaint(
                  size: const Size(160, 100),
                  painter: TerrainPolygonScenePainter(
                    projection: projection,
                    transform: TerrainPolygonViewportTransform(
                      origin: const Offset(20, 20),
                      zoom: 2,
                    ),
                  ),
                ),
              ),
            ),
          );

      await pumpProjection(previewProjection);
      expect(tester.takeException(), isNull);
      await pumpProjection(
        TerrainPolygonSceneProjection.fromInteraction(state),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

TerrainSourceShapeDef _rectangle(String shapeId) => TerrainSourceShapeDef(
  shapeId: shapeId,
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
    TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
    TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
    TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
  ],
);
