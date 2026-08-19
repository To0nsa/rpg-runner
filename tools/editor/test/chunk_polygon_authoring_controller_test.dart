import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_polygon_authoring_controller.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_coordinator.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_surface.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_polygon_scene_painter.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_scene_projection.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('new direct chunk shapes use the solid ID family', () async {
    final harness = await _buildHarness();
    final controller = harness.authoring;

    controller.beginCreatePolygon();
    expect(controller.state.draft!.shapeId, 'solid_001');
    for (final point in const <TerrainPolygonScenePoint>[
      TerrainPolygonScenePoint(120, 20),
      TerrainPolygonScenePoint(140, 20),
      TerrainPolygonScenePoint(140, 40),
    ]) {
      controller.addDraftVertex(point);
    }

    expect(controller.saveDraft(), isTrue);
    expect(
      controller.chunk.collisionShapes.map((shape) => shape.shapeId),
      containsAll(<String>['ground_001', 'solid_001']),
    );
  });

  test('direct chunk pointers always snap to whole pixels', () async {
    final harness = await _buildHarness();
    final controller = harness.authoring;

    expect(controller.creationSnapPolicy.stepHalfPixels, 2);
    expect(controller.editSnapPolicy.stepHalfPixels, 2);
    expect(controller.beginCreatePolygon(), isTrue);
    expect(
      controller.addDraftVertex(const TerrainPolygonScenePoint(121, 21)),
      isTrue,
    );
    expect(
      controller.state.draft!.vertices.single,
      const TerrainSourceVertexDef(xHalfPixels: 122, yHalfPixels: 22),
    );
  });

  test(
    'terrain tile grid keeps creation and edit snapping independent',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;

      expect(controller.creationSnapToGrid, isFalse);
      expect(controller.editSnapToGrid, isFalse);
      expect(controller.creationSnapPolicy.stepHalfPixels, 2);
      expect(controller.editSnapPolicy.stepHalfPixels, 2);
      controller.setCreationSnapToGrid(true);
      expect(controller.creationSnapToGrid, isTrue);
      expect(controller.editSnapToGrid, isFalse);
      expect(controller.creationSnapPolicy.stepHalfPixels, 32);
      expect(controller.editSnapPolicy.stepHalfPixels, 2);

      expect(controller.beginCreatePolygon(), isTrue);
      expect(
        controller.addDraftVertex(const TerrainPolygonScenePoint(121, 21)),
        isTrue,
      );
      expect(
        controller.state.draft!.vertices.single,
        const TerrainSourceVertexDef(xHalfPixels: 128, yHalfPixels: 32),
      );
      controller.setCreationSnapToGrid(false);
      expect(controller.creationSnapToGrid, isTrue);
      controller.cancelActiveOperation();

      controller.select(TerrainPolygonSelection.vertex('ground_001', 1));
      expect(
        controller.editSelectedVertex(
          const TerrainSourceVertexDef(xHalfPixels: 124, yHalfPixels: 30),
        ),
        isTrue,
      );
      expect(
        controller.chunk.collisionShapes.single.vertices[1],
        const TerrainSourceVertexDef(xHalfPixels: 124, yHalfPixels: 30),
      );

      controller.setEditSnapToGrid(true);
      expect(controller.creationSnapToGrid, isTrue);
      expect(controller.editSnapToGrid, isTrue);
      expect(
        controller.editSelectedVertex(
          const TerrainSourceVertexDef(xHalfPixels: 123, yHalfPixels: 29),
        ),
        isTrue,
      );
      expect(
        controller.chunk.collisionShapes.single.vertices[1],
        const TerrainSourceVertexDef(xHalfPixels: 128, yHalfPixels: 32),
      );

      controller.setTool(TerrainPolygonTool.createRectangle);
      expect(
        controller.beginCreateRectangle(
          pointer: 3,
          point: const TerrainPolygonScenePoint(139, 5),
        ),
        isTrue,
      );
      controller.updateGesture(
        pointer: 3,
        point: const TerrainPolygonScenePoint(181, 27),
      );
      expect(
        controller.state.gesture!.previewShape.vertices.expand(
          (vertex) => <int>[vertex.xHalfPixels, vertex.yHalfPixels],
        ),
        everyElement(
          isA<int>().having((coordinate) => coordinate % 32, 'remainder', 0),
        ),
      );
      controller.cancelActiveOperation();

      controller.setCreationSnapToGrid(false);
      expect(controller.creationSnapToGrid, isFalse);
      expect(controller.editSnapToGrid, isTrue);
      expect(controller.creationSnapPolicy.stepHalfPixels, 2);
      expect(controller.editSnapPolicy.stepHalfPixels, 32);
    },
  );

  test('selected creation settings apply to polygons and rectangles', () async {
    final harness = await _buildHarness(newShapeMaterialKey: 'grass_dirt');
    final controller = harness.authoring;

    expect(controller.newShapeCollisionMode, TerrainSourceCollisionMode.solid);
    controller.setNewShapeCollisionMode(TerrainSourceCollisionMode.oneWay);
    controller.setNewShapeMaterialKey('stone');

    controller.beginCreatePolygon();
    expect(
      controller.state.draft!.collisionMode,
      TerrainSourceCollisionMode.oneWay,
    );
    expect(controller.state.draft!.materialKey, 'stone');
    controller.cancelActiveOperation();

    controller.setTool(TerrainPolygonTool.createRectangle);
    expect(
      controller.beginCreateRectangle(
        pointer: 1,
        point: const TerrainPolygonScenePoint(120, 20),
      ),
      isTrue,
    );
    controller.updateGesture(
      pointer: 1,
      point: const TerrainPolygonScenePoint(160, 60),
    );
    expect(
      controller.state.gesture!.previewShape.collisionMode,
      TerrainSourceCollisionMode.oneWay,
    );
    expect(controller.state.gesture!.previewShape.materialKey, 'stone');
    expect(controller.commitGesture(1), isTrue);
    expect(
      controller.state.draft!.collisionMode,
      TerrainSourceCollisionMode.oneWay,
    );
    expect(controller.newShapeCollisionMode, TerrainSourceCollisionMode.oneWay);
    expect(controller.newShapeMaterialKey, 'stone');
  });

  test(
    'custom shape names validate, commit, and reset after creation',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;

      controller.setNewShapeNameInput('secret_ledge');
      expect(controller.newShapeNameError, isNull);
      expect(controller.resolvedNewShapeName, 'secret_ledge');
      expect(controller.beginCreatePolygon(), isTrue);
      for (final point in const <TerrainPolygonScenePoint>[
        TerrainPolygonScenePoint(120, 20),
        TerrainPolygonScenePoint(140, 20),
        TerrainPolygonScenePoint(140, 40),
      ]) {
        controller.addDraftVertex(point);
      }
      expect(controller.saveDraft(), isTrue);
      expect(controller.newShapeNameInput, isEmpty);
      expect(controller.newShapeNameGeneration, 1);
      expect(
        controller.chunk.collisionShapes.map((shape) => shape.shapeId),
        contains('secret_ledge'),
      );

      controller.setNewShapeNameInput('Bad name');
      expect(controller.canBeginNewShape, isFalse);
      expect(controller.beginCreatePolygon(), isFalse);
      expect(controller.state.draft, isNull);

      controller.setNewShapeNameInput('ground_001');
      expect(controller.newShapeNameError, contains('already uses'));
      expect(controller.beginCreatePolygon(), isFalse);
      expect(controller.state.draft, isNull);
    },
  );

  test('exact geometry and a custom name commit as one edit', () async {
    final harness = await _buildHarness();
    final controller = harness.authoring;

    controller.select(TerrainPolygonSelection.vertex('ground_001', 1));
    expect(
      controller.editSelectedVertex(
        const TerrainSourceVertexDef(xHalfPixels: 104, yHalfPixels: 20),
        shapeId: 'main_floor',
      ),
      isTrue,
    );

    expect(controller.chunk.revision, 5);
    final renamed = controller.chunk.collisionShapes.single;
    expect(renamed.shapeId, 'main_floor');
    expect(
      renamed.vertices,
      contains(const TerrainSourceVertexDef(xHalfPixels: 104, yHalfPixels: 20)),
    );
    expect(controller.state.selection?.shapeId, 'main_floor');

    expect(controller.undo(), isTrue);
    expect(controller.chunk.revision, 4);
    expect(controller.chunk.collisionShapes.single.shapeId, 'ground_001');
  });

  test(
    'terrain creation defaults and local gestures feed the material preview',
    () async {
      final harness = await _buildHarness(
        newShapeSurfaceKind: 'ground',
        newShapeMaterialKey: 'grass_dirt',
      );
      final controller = harness.authoring;
      final document = harness.session.document;

      controller.beginCreatePolygon();
      expect(controller.state.draft!.surfaceKind, 'ground');
      expect(controller.state.draft!.materialKey, 'grass_dirt');
      controller.addDraftVertex(const TerrainPolygonScenePoint(120, 20));
      controller.addDraftVertex(const TerrainPolygonScenePoint(140, 20));
      expect(controller.terrainPreviewShapes, hasLength(1));

      controller.addDraftVertex(const TerrainPolygonScenePoint(140, 40));
      var preview = controller.terrainPreviewShapes.last;
      expect(controller.terrainPreviewShapes, hasLength(2));
      expect(preview.shapeId, 'solid_001');
      expect(preview.surfaceKind, 'ground');
      expect(preview.materialKey, 'grass_dirt');

      controller.setTool(TerrainPolygonTool.moveVertex);
      expect(
        controller.beginDraftGesture(
          pointer: 7,
          point: const TerrainPolygonScenePoint(120, 20),
          vertexRadiusHalfPixels: 2,
          edgeRadiusHalfPixels: 2,
        ),
        isTrue,
      );
      controller.updateGesture(
        pointer: 7,
        point: const TerrainPolygonScenePoint(124, 24),
      );
      preview = controller.terrainPreviewShapes.last;
      expect(
        preview.vertices.first,
        const TerrainSourceVertexDef(xHalfPixels: 124, yHalfPixels: 24),
      );
      expect(harness.session.document, same(document));
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      controller.cancelActiveOperation();
      controller.cancelActiveOperation();
      controller.setTool(TerrainPolygonTool.createRectangle);
      expect(
        controller.beginCreateRectangle(
          pointer: 8,
          point: const TerrainPolygonScenePoint(120, 20),
        ),
        isTrue,
      );
      controller.updateGesture(
        pointer: 8,
        point: const TerrainPolygonScenePoint(180, 60),
      );
      preview = controller.terrainPreviewShapes.last;
      expect(preview.vertices, hasLength(4));
      expect(preview.surfaceKind, 'ground');
      expect(preview.materialKey, 'grass_dirt');
      expect(harness.session.document, same(document));

      expect(controller.commitGesture(8), isTrue);
      expect(harness.session.document, same(document));
      expect(controller.saveDraft(), isTrue);
      final committed = controller.chunk.collisionShapes.singleWhere(
        (shape) => shape.shapeId == 'solid_001',
      );
      expect(committed.surfaceKind, 'ground');
      expect(committed.materialKey, 'grass_dirt');
    },
  );

  test(
    'preview stays local and one accepted gesture creates one session edit',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      final session = harness.session;
      final loadedDocument = session.document;

      controller.select(TerrainPolygonSelection.vertex('ground_001', 1));
      controller.setTool(TerrainPolygonTool.moveVertex);
      expect(
        controller.beginGesture(
          pointer: 7,
          point: const TerrainPolygonScenePoint(100, 20),
        ),
        isTrue,
      );
      controller.updateGesture(
        pointer: 7,
        point: const TerrainPolygonScenePoint(103.6, 20),
      );
      await session.exportDirectWrite();

      expect(session.document, same(loadedDocument));
      expect(session.canUndo, isFalse);
      expect(
        controller.state.visibleShapes.single.vertices[1].xHalfPixels,
        104,
      );
      expect(
        controller.terrainPreviewShapes.single.vertices[1].xHalfPixels,
        104,
      );

      expect(controller.commitGesture(7), isTrue);
      expect(session.document, isNot(same(loadedDocument)));
      expect(session.canUndo, isTrue);
      expect(session.pendingChanges.changedItemIds, <String>['forest_target']);
      expect(controller.chunk.revision, 5);
      expect(
        controller.chunk.collisionShapes.single.vertices[1].xHalfPixels,
        104,
      );
      expect(controller.hasActiveOperation, isFalse);
      expect(controller.issues, isEmpty);

      controller.select(TerrainPolygonSelection.shape('ground_001'));
      controller.setTool(TerrainPolygonTool.translateShape);
      controller.beginGesture(
        pointer: 8,
        point: const TerrainPolygonScenePoint(0, 0),
      );
      controller.updateGesture(
        pointer: 8,
        point: const TerrainPolygonScenePoint(2, 0),
      );
      expect(controller.undo(), isTrue);
      expect(controller.hasActiveOperation, isFalse);
      expect(controller.chunk.revision, 5);

      expect(controller.undo(), isTrue);
      expect(controller.chunk.revision, 4);
      expect(controller.state.shapes.single.vertices[1].xHalfPixels, 100);
      expect(session.canRedo, isTrue);

      expect(controller.redo(), isTrue);
      expect(controller.chunk.revision, 5);
      expect(controller.state.shapes.single.vertices[1].xHalfPixels, 104);
    },
  );

  test(
    'chunk authoring clamps all direct geometry input to owner bounds',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      final session = harness.session;

      controller.beginCreatePolygon();
      controller.addDraftVertex(const TerrainPolygonScenePoint(-20, 120));
      controller.addDraftVertex(const TerrainPolygonScenePoint(240, 120));
      controller.addDraftVertex(const TerrainPolygonScenePoint(240, 90));
      expect(controller.state.draft!.vertices, const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 100),
        TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 100),
        TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 90),
      ]);
      controller.cancelActiveOperation();

      controller.setTool(TerrainPolygonTool.createRectangle);
      expect(
        controller.beginCreateRectangle(
          pointer: 1,
          point: const TerrainPolygonScenePoint(120, -10),
        ),
        isTrue,
      );
      controller.updateGesture(
        pointer: 1,
        point: const TerrainPolygonScenePoint(240, 120),
      );
      expect(controller.commitGesture(1), isTrue);
      expect(controller.state.draft!.vertices, const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 100),
        TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 100),
      ]);
      controller.cancelActiveOperation();

      controller.select(TerrainPolygonSelection.vertex('ground_001', 1));
      controller.setTool(TerrainPolygonTool.moveVertex);
      expect(
        controller.beginGesture(
          pointer: 2,
          point: const TerrainPolygonScenePoint(100, 20),
        ),
        isTrue,
      );
      controller.updateGesture(
        pointer: 2,
        point: const TerrainPolygonScenePoint(240, 20),
      );
      expect(
        controller.state.visibleShapes.single.vertices[1],
        const TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 20),
      );
      controller.cancelActiveOperation();
      expect(session.pendingChanges.hasChanges, isFalse);

      controller.select(TerrainPolygonSelection.edge('ground_001', 0));
      controller.setTool(TerrainPolygonTool.insertVertex);
      expect(
        controller.beginGesture(
          pointer: 3,
          point: const TerrainPolygonScenePoint(60, 20),
        ),
        isTrue,
      );
      controller.updateGesture(
        pointer: 3,
        point: const TerrainPolygonScenePoint(240, -10),
      );
      expect(
        controller.state.visibleShapes.single.vertices[1],
        const TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 0),
      );
      controller.cancelActiveOperation();
    },
  );

  test('whole-shape movement stops at the chunk boundary', () async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    final session = harness.session;
    final loadedDocument = session.document;

    controller.select(TerrainPolygonSelection.shape('ground_001'));
    controller.setTool(TerrainPolygonTool.translateShape);
    expect(
      controller.beginGesture(
        pointer: 3,
        point: const TerrainPolygonScenePoint(0, 0),
      ),
      isTrue,
    );
    controller.updateGesture(
      pointer: 3,
      point: const TerrainPolygonScenePoint(200, 0),
    );

    expect(controller.hasActiveOperation, isTrue);
    expect(
      controller.state.visibleShapes.single.vertices.first.xHalfPixels,
      120,
    );
    expect(
      controller.state.visibleShapes.single.vertices.map(
        (vertex) => vertex.xHalfPixels,
      ),
      everyElement(inInclusiveRange(0, 200)),
    );
    controller.cancelActiveOperation();
    expect(session.document, same(loadedDocument));
    expect(controller.hasActiveOperation, isFalse);
    expect(controller.issues, isEmpty);
  });

  test(
    'rectangle drag stops at direct solid contact without an internal edge',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;

      controller.setTool(TerrainPolygonTool.createRectangle);
      expect(
        controller.beginCreateRectangle(
          pointer: 31,
          point: const TerrainPolygonScenePoint(120, 20),
        ),
        isTrue,
      );
      controller.updateGesture(
        pointer: 31,
        point: const TerrainPolygonScenePoint(80, 60),
        snapRadiusHalfPixels: 12,
      );
      expect(
        controller.state.gesture!.previewShape.vertices,
        const <TerrainSourceVertexDef>[
          TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 20),
          TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 20),
          TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 60),
          TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 60),
        ],
      );

      expect(controller.commitGesture(31), isTrue);
      expect(controller.saveDraft(), isTrue);
      final scene = harness.session.scene as ChunkV2Scene;
      final expansion =
          scene.collisionExpansionByChunkKey['forest_target']!.expansion!;
      const factor =
          terrainPhysicsTicksPerWorldUnit ~/ terrainSourceTicksPerWorldUnit;
      final sharedStart = TerrainPoint(100 * factor, 20 * factor);
      final sharedEnd = TerrainPoint(100 * factor, 60 * factor);
      expect(
        expansion.geometry.edges.where(
          (edge) =>
              (edge.start == sharedStart && edge.end == sharedEnd) ||
              (edge.start == sharedEnd && edge.end == sharedStart),
        ),
        isEmpty,
      );
    },
  );

  test('vertex movement cannot cross another direct solid', () async {
    final harness = await _buildHarness(
      collisionShapes: <TerrainSourceShapeDef>[
        _chunkGround(),
        TerrainSourceShapeDef(
          shapeId: 'solid_002',
          vertices: const <TerrainSourceVertexDef>[
            TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 20),
            TerrainSourceVertexDef(xHalfPixels: 160, yHalfPixels: 20),
            TerrainSourceVertexDef(xHalfPixels: 160, yHalfPixels: 80),
            TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 80),
          ],
        ),
      ],
    );
    final controller = harness.authoring;

    controller.select(TerrainPolygonSelection.vertex('ground_001', 1));
    controller.setTool(TerrainPolygonTool.moveVertex);
    expect(
      controller.beginGesture(
        pointer: 32,
        point: const TerrainPolygonScenePoint(100, 20),
      ),
      isTrue,
    );
    controller.updateGesture(
      pointer: 32,
      point: const TerrainPolygonScenePoint(180, 20),
    );

    expect(
      controller.state.gesture!.previewShape.vertices[1],
      const TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 20),
    );
    expect(controller.commitGesture(32), isTrue);
    expect(controller.issues, isEmpty);
  });

  test(
    'expanded prefab collision blocks and attracts draft vertices',
    () async {
      final prefab = _solidPrefab();
      final harness = await _buildHarness(
        prefabs: <PrefabV3Def>[prefab],
        placements: const <PlacedPrefabDef>[
          PlacedPrefabDef(
            prefabId: 'rock',
            prefabKey: 'prefab_rock',
            x: 70,
            y: 10,
          ),
        ],
      );
      final controller = harness.authoring;
      controller.beginCreatePolygon();

      expect(
        controller.addDraftVertex(const TerrainPolygonScenePoint(150, 30)),
        isFalse,
      );
      expect(controller.state.draft!.vertices, isEmpty);
      expect(
        controller.issues.map((issue) => issue.code),
        contains('chunk_polygon_point_inside_collision'),
      );

      expect(
        controller.addDraftVertex(
          const TerrainPolygonScenePoint(132, 30),
          snapRadiusHalfPixels: 10,
        ),
        isTrue,
      );
      expect(
        controller.state.draft!.vertices.single,
        const TerrainSourceVertexDef(xHalfPixels: 140, yHalfPixels: 30),
      );

      controller.cancelActiveOperation();
      controller.beginCreatePolygon();
      expect(
        controller.addDraftVertex(const TerrainPolygonScenePoint(130, 10)),
        isTrue,
      );
      expect(
        controller.addDraftVertex(const TerrainPolygonScenePoint(170, 10)),
        isTrue,
      );
      expect(
        controller.addDraftVertex(const TerrainPolygonScenePoint(170, 50)),
        isFalse,
      );
      expect(controller.state.draft!.vertices, hasLength(2));
    },
  );

  test('rejected collinear preview normalizes as one source commit', () async {
    final harness = await _buildHarness(shape: _pentagon());
    final controller = harness.authoring;
    final session = harness.session;

    controller.select(TerrainPolygonSelection.vertex('ground_001', 1));
    controller.setTool(TerrainPolygonTool.moveVertex);
    expect(
      controller.beginGesture(
        pointer: 17,
        point: const TerrainPolygonScenePoint(60, 16),
      ),
      isTrue,
    );
    controller.updateGesture(
      pointer: 17,
      point: const TerrainPolygonScenePoint(60, 20),
    );

    expect(controller.commitGesture(17), isFalse);
    expect(controller.hasActiveOperation, isTrue);
    expect(controller.chunk.revision, 4);
    expect(session.canUndo, isFalse);
    expect(
      controller.issues.map((issue) => issue.code),
      contains('collinear_middle_vertex'),
    );

    expect(controller.normalizeSelectedShape(), isTrue);
    expect(controller.hasActiveOperation, isFalse);
    expect(controller.chunk.revision, 5);
    expect(controller.chunk.collisionShapes.single.vertices, hasLength(4));
    expect(session.canUndo, isTrue);
    expect(session.pendingChanges.changedItemIds, <String>['forest_target']);
    expect(
      controller.issues.map((issue) => issue.code),
      contains('normalized_collinear_vertex'),
    );
  });

  test('controller requires a current chunk-v2 session', () {
    final session = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[ChunkDomainPlugin()],
      ),
      initialPluginId: ChunkDomainPlugin.pluginId,
      initialWorkspacePath: Directory.current.path,
    );
    addTearDown(session.dispose);

    expect(
      () => ChunkPolygonAuthoringController(
        session: session,
        chunkKey: 'forest_target',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ChunkV2Document'),
        ),
      ),
    );
  });

  testWidgets('scene surface exposes its chunk-authoring semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = await _buildHarness();
    await tester.pumpWidget(
      _surfaceApp(
        controller: harness.authoring,
        transform: TerrainPolygonViewportTransform(
          origin: Offset.zero,
          zoom: 1,
        ),
      ),
    );

    expect(find.bySemanticsLabel('Chunk authoring scene'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('non-terrain scene input routes through domain callbacks', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final selectedPoints = <Offset>[];
    var clears = 0;
    var deletes = 0;
    var completes = 0;
    await tester.pumpWidget(
      _surfaceApp(
        controller: harness.authoring,
        transform: TerrainPolygonViewportTransform(
          origin: const Offset(10, 20),
          zoom: 2,
        ),
        activeDomain: ChunkSceneDomain.prefabs,
        onSelectWorldPoint: selectedPoints.add,
        onClearSelection: () => clears += 1,
        onDeleteSelection: () => deletes += 1,
        onCompleteOperation: () => completes += 1,
      ),
    );

    final surface = find.byKey(const ValueKey<String>('chunk_scene_surface'));
    await tester.tapAt(tester.getTopLeft(surface) + const Offset(50, 80));
    await tester.pump();
    expect(selectedPoints.single, const Offset(20, 30));
    expect(harness.session.canUndo, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(clears, 1);
    expect(deletes, 1);
    expect(completes, 1);
    expect(harness.session.canUndo, isFalse);
  });

  testWidgets('layers tab keeps primary scene authoring passive', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final selectedPoints = <Offset>[];
    harness.authoring.setTool(TerrainPolygonTool.createPolygon);
    await tester.pumpWidget(
      _surfaceApp(
        controller: harness.authoring,
        transform: TerrainPolygonViewportTransform(
          origin: Offset.zero,
          zoom: 1,
        ),
        activeDomain: ChunkSceneDomain.layers,
        onSelectWorldPoint: selectedPoints.add,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('chunk_scene_surface')));
    await tester.pump();

    expect(selectedPoints, isEmpty);
    expect(harness.authoring.state.draft, isNull);
    expect(harness.session.canUndo, isFalse);
  });

  testWidgets('scene surface drags a rectangle into a local draft', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    final transform = TerrainPolygonViewportTransform(
      origin: const Offset(10, 10),
      zoom: 2,
    );
    controller.setTool(TerrainPolygonTool.createRectangle);
    await tester.pumpWidget(
      _surfaceApp(controller: controller, transform: transform),
    );
    final topLeft = tester.getTopLeft(
      find.byKey(const ValueKey<String>('chunk_scene_surface')),
    );
    final start = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 20),
    );
    final end = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 160, yHalfPixels: 60),
    );

    final drag = await tester.startGesture(topLeft + start);
    await drag.moveTo(topLeft + end);
    await tester.pump();

    expect(controller.state.draft!.isClosed, isTrue);
    expect(
      controller.sceneProjection.draft!.vertices,
      const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 160, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 160, yHalfPixels: 60),
        TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 60),
      ],
    );
    expect(harness.session.canUndo, isFalse);

    await drag.up();
    await tester.pump();
    expect(controller.state.gesture, isNull);
    expect(controller.state.draft, isNotNull);
    expect(controller.state.tool, TerrainPolygonTool.moveVertex);
    expect(harness.session.canUndo, isFalse);
  });

  testWidgets('scene surface snaps rectangle starts in canvas space', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    final transform = TerrainPolygonViewportTransform(
      origin: const Offset(10, 10),
      zoom: 2,
    );
    controller.setTool(TerrainPolygonTool.createRectangle);
    await tester.pumpWidget(
      _surfaceApp(controller: controller, transform: transform),
    );
    final topLeft = tester.getTopLeft(
      find.byKey(const ValueKey<String>('chunk_scene_surface')),
    );
    final start = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 106, yHalfPixels: 40),
    );
    final end = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 140, yHalfPixels: 60),
    );

    final drag = await tester.startGesture(topLeft + start);
    await drag.moveTo(topLeft + end);
    await tester.pump();

    expect(
      controller.sceneProjection.draft!.vertices,
      const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 40),
        TerrainSourceVertexDef(xHalfPixels: 140, yHalfPixels: 40),
        TerrainSourceVertexDef(xHalfPixels: 140, yHalfPixels: 60),
        TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 60),
      ],
    );

    await drag.up();
    await tester.pump();
  });

  testWidgets(
    'scene surface selects previews commits and cancels with Escape',
    (tester) async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      final transform = TerrainPolygonViewportTransform(
        origin: const Offset(10, 10),
        zoom: 2,
      );
      controller.setTool(TerrainPolygonTool.moveVertex);

      await tester.pumpWidget(
        _surfaceApp(controller: controller, transform: transform),
      );
      final topLeft = tester.getTopLeft(
        find.byKey(const ValueKey<String>('chunk_scene_surface')),
      );
      final vertexCanvas = transform.sourceVertexToCanvas(
        const TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 20),
      );
      final firstDrag = await tester.startGesture(topLeft + vertexCanvas);
      await firstDrag.moveTo(topLeft + vertexCanvas + const Offset(4, 0));
      await tester.pump();

      expect(controller.hasActiveOperation, isTrue);
      expect(controller.chunk.revision, 4);
      expect(
        controller.state.visibleShapes.single.vertices[1].xHalfPixels,
        104,
      );

      await firstDrag.up();
      await tester.pump();
      expect(controller.chunk.revision, 5);
      expect(controller.hasActiveOperation, isFalse);
      expect(controller.state.tool, TerrainPolygonTool.moveVertex);

      final otherVertexCanvas = transform.sourceVertexToCanvas(
        const TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 80),
      );
      final cancelledDrag = await tester.startGesture(
        topLeft + otherVertexCanvas,
      );
      await cancelledDrag.moveTo(
        topLeft + otherVertexCanvas + const Offset(4, 0),
      );
      await tester.pump();
      expect(controller.hasActiveOperation, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await cancelledDrag.up();
      await tester.pump();
      expect(controller.hasActiveOperation, isFalse);
      expect(controller.chunk.revision, 5);
      expect(controller.state.shapes.single.vertices[1].xHalfPixels, 104);
      expect(
        controller.state.shapes.single.vertices[2],
        const TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 80),
      );
    },
  );

  testWidgets('scene surface moves and inserts open-draft vertices locally', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    final transform = TerrainPolygonViewportTransform(
      origin: const Offset(10, 10),
      zoom: 2,
    );
    controller.beginCreatePolygon();
    for (final point in const <TerrainPolygonScenePoint>[
      TerrainPolygonScenePoint(120, 20),
      TerrainPolygonScenePoint(160, 20),
      TerrainPolygonScenePoint(160, 60),
    ]) {
      controller.addDraftVertex(point);
    }
    controller.setTool(TerrainPolygonTool.moveVertex);

    await tester.pumpWidget(
      _surfaceApp(controller: controller, transform: transform),
    );
    final topLeft = tester.getTopLeft(
      find.byKey(const ValueKey<String>('chunk_scene_surface')),
    );
    final vertexCanvas = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 160, yHalfPixels: 20),
    );
    final move = await tester.startGesture(topLeft + vertexCanvas);
    await move.moveTo(topLeft + vertexCanvas + const Offset(4, 0));
    await move.up();
    await tester.pump();

    expect(controller.state.draft!.vertices[1].xHalfPixels, 164);
    expect(controller.undo(), isTrue);
    expect(controller.state.draft!.vertices[1].xHalfPixels, 160);
    expect(controller.redo(), isTrue);
    expect(controller.state.draft!.vertices[1].xHalfPixels, 164);

    controller.setTool(TerrainPolygonTool.insertVertex);
    final edgeCanvas = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 140, yHalfPixels: 20),
    );
    final insert = await tester.startGesture(topLeft + edgeCanvas);
    await insert.moveTo(topLeft + edgeCanvas + const Offset(0, -4));
    await insert.up();
    await tester.pump();

    expect(controller.state.draft!.vertices, hasLength(4));
    expect(
      controller.state.draft!.vertices[1],
      const TerrainSourceVertexDef(xHalfPixels: 140, yHalfPixels: 16),
    );

    controller.setTool(TerrainPolygonTool.createPolygon);
    final appendedVertexCanvas = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 60),
    );
    await tester.tapAt(topLeft + appendedVertexCanvas);
    await tester.pump();

    expect(controller.state.draft!.vertices, hasLength(5));
    expect(
      controller.state.draft!.vertices.last,
      const TerrainSourceVertexDef(xHalfPixels: 120, yHalfPixels: 60),
    );
    expect(harness.session.canUndo, isFalse);
    expect(controller.chunk.revision, 4);
  });

  testWidgets('focused Delete and Ctrl shortcuts use session history', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    _registerShellUndoRedoShortcuts(
      undo: controller.undo,
      redo: controller.redo,
    );
    final transform = TerrainPolygonViewportTransform(
      origin: const Offset(10, 10),
      zoom: 2,
    );
    await tester.pumpWidget(
      _surfaceApp(controller: controller, transform: transform),
    );
    final topLeft = tester.getTopLeft(
      find.byKey(const ValueKey<String>('chunk_scene_surface')),
    );
    await tester.tapAt(
      topLeft +
          transform.sourceVertexToCanvas(
            const TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 20),
          ),
    );
    await tester.pump();
    expect(
      controller.state.selection,
      TerrainPolygonSelection.vertex('ground_001', 1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(controller.chunk.revision, 5);
    expect(controller.state.shapes.single.vertices, hasLength(3));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.chunk.revision, 4);
    expect(controller.state.shapes.single.vertices, hasLength(4));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.chunk.revision, 5);
    expect(controller.state.shapes.single.vertices, hasLength(3));
  });

  testWidgets(
    'shell Ctrl shortcuts undo and redo one open-draft vertex edit at a time',
    (tester) async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      _registerShellUndoRedoShortcuts(
        undo: controller.undo,
        redo: controller.redo,
      );
      controller.beginCreatePolygon();
      for (final point in const <TerrainPolygonScenePoint>[
        TerrainPolygonScenePoint(0, 0),
        TerrainPolygonScenePoint(20, 0),
        TerrainPolygonScenePoint(20, 20),
        TerrainPolygonScenePoint(0, 20),
      ]) {
        controller.addDraftVertex(point);
      }
      controller.setTool(TerrainPolygonTool.moveVertex);

      await tester.pumpWidget(
        _surfaceApp(
          controller: controller,
          transform: TerrainPolygonViewportTransform(
            origin: const Offset(10, 10),
            zoom: 2,
          ),
        ),
      );

      await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(controller.state.draft!.vertices, hasLength(3));
      expect(
        controller.state.draft!.vertices.last,
        const TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
      );

      await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyY);
      expect(controller.state.draft!.vertices, hasLength(4));

      await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
      await _pressCtrlShiftShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(controller.state.draft!.vertices, hasLength(4));
    },
  );

  testWidgets('Ctrl drag pans without changing polygon document state', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    final document = harness.session.document;
    final panDeltas = <Offset>[];
    final transform = TerrainPolygonViewportTransform(
      origin: const Offset(10, 10),
      zoom: 2,
    );
    await tester.pumpWidget(
      _surfaceApp(
        controller: controller,
        transform: transform,
        onPanDelta: panDeltas.add,
      ),
    );
    final surface = find.byKey(const ValueKey<String>('chunk_scene_surface'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final pan = await tester.startGesture(tester.getCenter(surface));
    await pan.moveBy(const Offset(12, -7));
    await pan.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(panDeltas, isNotEmpty);
    expect(harness.session.document, same(document));
    expect(harness.session.canUndo, isFalse);
    expect(controller.chunk.revision, 4);
  });
}

Widget _surfaceApp({
  required ChunkPolygonAuthoringController controller,
  required TerrainPolygonViewportTransform transform,
  ChunkSceneDomain activeDomain = ChunkSceneDomain.terrain,
  ValueChanged<Offset>? onPanDelta,
  ValueChanged<Offset>? onSelectWorldPoint,
  VoidCallback? onClearSelection,
  VoidCallback? onDeleteSelection,
  VoidCallback? onCompleteOperation,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 240,
        height: 160,
        child: ChunkSceneSurface(
          controller: controller,
          transform: transform,
          activeDomain: activeDomain,
          onPanDelta: onPanDelta,
          onSelectWorldPoint: onSelectWorldPoint,
          onClearSelection: onClearSelection,
          onDeleteSelection: onDeleteSelection,
          onCompleteOperation: onCompleteOperation,
          background: const ColoredBox(color: Color(0xFF111A22)),
        ),
      ),
    ),
  ),
);

void _registerShellUndoRedoShortcuts({
  required bool Function() undo,
  required bool Function() redo,
}) {
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !HardwareKeyboard.instance.isControlPressed) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      return HardwareKeyboard.instance.isShiftPressed ? redo() : undo();
    }
    if (event.logicalKey == LogicalKeyboardKey.keyY) return redo();
    return false;
  }

  HardwareKeyboard.instance.addHandler(handleKeyEvent);
  addTearDown(() => HardwareKeyboard.instance.removeHandler(handleKeyEvent));
}

Future<void> _pressCtrlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _pressCtrlShiftShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<_Harness> _buildHarness({
  TerrainSourceShapeDef? shape,
  Iterable<TerrainSourceShapeDef>? collisionShapes,
  Iterable<PrefabV3Def> prefabs = const <PrefabV3Def>[],
  Iterable<PlacedPrefabDef> placements = const <PlacedPrefabDef>[],
  String? newShapeSurfaceKind,
  String? newShapeMaterialKey,
}) async {
  final root = Directory.systemTemp.createTempSync('chunk_polygon_route_');
  final chunk = _chunk(
    shape: shape,
    collisionShapes: collisionShapes,
    placements: placements,
  );
  final document = ChunkV2Document(
    chunks: <ChunkV2FileData>[chunk],
    sourcePathByChunkKey: const <String, String>{
      'forest_target': 'chunks/forest_target.json',
    },
    baselineContentsByChunkKey: <String, String>{
      'forest_target': ChunkV2FileCodec.encode(chunk),
    },
    prefabData: PrefabV3FileData(
      slices: const <AtlasSliceDef>[],
      prefabs: prefabs,
    ),
    tileData: PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[],
      platformModules: const <TileModuleDef>[],
    ),
    visualBoundsByPrefabKey: const {},
    levels: const <LevelDef>[_forestLevel],
    availableLevelIds: const <String>['forest'],
    activeLevelId: 'forest',
  );
  final session = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[_ChunkPlugin(document)],
    ),
    initialPluginId: ChunkDomainPlugin.pluginId,
    initialWorkspacePath: root.path,
  );
  await session.loadWorkspace();
  final authoring = ChunkPolygonAuthoringController(
    session: session,
    chunkKey: 'forest_target',
    newShapeSurfaceKind: newShapeSurfaceKind,
    newShapeMaterialKey: newShapeMaterialKey,
  );
  addTearDown(() {
    authoring.dispose();
    session.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return _Harness(session: session, authoring: authoring);
}

ChunkV2FileData _chunk({
  TerrainSourceShapeDef? shape,
  Iterable<TerrainSourceShapeDef>? collisionShapes,
  Iterable<PlacedPrefabDef> placements = const <PlacedPrefabDef>[],
}) => ChunkV2FileData(
  chunkKey: 'forest_target',
  id: 'forest_target',
  revision: 4,
  status: chunkStatusActive,
  levelId: 'forest',
  tileSize: 16,
  width: 100,
  height: 50,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: const <String>['forest'],
  tileLayers: const <TileLayerDef>[],
  prefabs: placements,
  markers: const <PlacedMarkerDef>[],
  groundBandZIndex: 0,
  collisionShapes:
      collisionShapes ?? <TerrainSourceShapeDef>[shape ?? _chunkGround()],
);

TerrainSourceShapeDef _chunkGround() => TerrainSourceShapeDef(
  shapeId: 'ground_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
    TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 20),
    TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 80),
    TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 80),
  ],
);

PrefabV3Def _solidPrefab() => PrefabV3Def(
  prefabKey: 'prefab_rock',
  id: 'rock',
  revision: 1,
  status: PrefabStatus.active,
  kind: PrefabKind.obstacle,
  visualSource: const PrefabVisualSource.atlasSlice('rock_slice'),
  anchorXPx: 0,
  anchorYPx: 0,
  collisionShapes: <TerrainSourceShapeDef>[
    TerrainSourceShapeDef(
      shapeId: 'collision_001',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
      ],
    ),
  ],
  tags: const <String>[],
);

TerrainSourceShapeDef _pentagon() => TerrainSourceShapeDef(
  shapeId: 'ground_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
    TerrainSourceVertexDef(xHalfPixels: 60, yHalfPixels: 16),
    TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 20),
    TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 80),
    TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 80),
  ],
);

const LevelDef _forestLevel = LevelDef(
  levelId: 'forest',
  revision: 1,
  displayName: 'Forest',
  visualThemeId: 'forest',
  cameraCenterY: 25,
  groundTopY: 10,
  earlyPatternChunks: 0,
  easyPatternChunks: 0,
  normalPatternChunks: 0,
  noEnemyChunks: 0,
  enumOrdinal: 1,
  status: levelStatusActive,
);

final class _Harness {
  const _Harness({required this.session, required this.authoring});

  final EditorSessionController session;
  final ChunkPolygonAuthoringController authoring;
}

final class _ChunkPlugin implements AuthoringDomainPlugin {
  _ChunkPlugin(this.document);

  final ChunkV2Document document;
  final ChunkDomainPlugin _delegate = ChunkDomainPlugin();

  @override
  String get id => ChunkDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async =>
      document;

  @override
  List<ValidationIssue> validate(AuthoringDocument document) =>
      _delegate.validate(document);

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      _delegate.buildEditableScene(document);

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) => _delegate.applyEdit(document, command);

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => _delegate.exportToRepo(workspace, document: document);

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => _delegate.describePendingChanges(workspace, document: document);
}
