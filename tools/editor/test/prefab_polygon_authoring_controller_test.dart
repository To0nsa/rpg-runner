import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_polygon_authoring_controller.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_polygon_scene_surface.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_polygon_scene_painter.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/collision_fitting/prefab_collision_fitting.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/prefabs/validation/prefab_validation.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_scene_projection.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test(
    'preview stays local and one accepted gesture creates one session edit',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      final session = harness.session;
      final loadedDocument = session.document;
      expect(controller.coordinateStepHalfPixels, 2);

      controller.select(TerrainPolygonSelection.vertex('collision_001', 1));
      controller.setTool(TerrainPolygonTool.moveVertex);
      expect(
        controller.beginGesture(
          pointer: 7,
          point: const TerrainPolygonScenePoint(8, -8),
        ),
        isTrue,
      );
      controller.updateGesture(
        pointer: 7,
        point: const TerrainPolygonScenePoint(9.6, -8),
      );
      await session.exportDirectWrite();

      expect(session.document, same(loadedDocument));
      expect(session.canUndo, isFalse);
      expect(controller.state.visibleShapes.single.vertices[1].xHalfPixels, 10);

      expect(controller.commitGesture(7), isTrue);

      expect(session.document, isNot(same(loadedDocument)));
      expect(session.canUndo, isTrue);
      expect(session.pendingChanges.changedItemIds, <String>['target']);
      expect(controller.prefab.revision, 5);
      expect(
        controller.prefab.collisionShapes.single.vertices[1].xHalfPixels,
        10,
      );
      expect(controller.hasActiveOperation, isFalse);
      expect(controller.issues, isEmpty);

      controller.select(TerrainPolygonSelection.shape('collision_001'));
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
      expect(controller.prefab.revision, 5);
      expect(session.canUndo, isTrue);

      expect(controller.undo(), isTrue);
      expect(controller.prefab.revision, 4);
      expect(controller.state.shapes.single.vertices[1].xHalfPixels, 8);
      expect(session.canRedo, isTrue);

      expect(controller.redo(), isTrue);
      expect(controller.prefab.revision, 5);
      expect(controller.state.shapes.single.vertices[1].xHalfPixels, 10);
    },
  );

  test(
    'owner rejection preserves preview diagnostics and never enters history',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      final session = harness.session;
      final loadedDocument = session.document;

      controller.select(TerrainPolygonSelection.shape('collision_001'));
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
        point: const TerrainPolygonScenePoint(40, 0),
      );

      expect(controller.commitGesture(3), isFalse);

      expect(session.document, same(loadedDocument));
      expect(session.canUndo, isFalse);
      expect(controller.hasActiveOperation, isTrue);
      expect(
        controller.state.visibleShapes.single.vertices.first.xHalfPixels,
        32,
      );
      expect(
        controller.issues.map((issue) => issue.code),
        contains('prefab_collision_shapes_outside_visual_source'),
      );
      expect(
        () => controller.issues.add(
          const PrefabValidationIssue(
            code: 'external_mutation',
            message: 'must not be accepted',
          ),
        ),
        throwsUnsupportedError,
      );

      controller.setTool(TerrainPolygonTool.select);
      expect(controller.hasActiveOperation, isFalse);
      expect(controller.state.tool, TerrainPolygonTool.select);
      expect(controller.state.visibleShapes, controller.state.shapes);
      expect(controller.issues, isEmpty);
    },
  );

  test('rejected collinear preview normalizes as one source commit', () async {
    final harness = await _buildHarness(shape: _pentagon());
    final controller = harness.authoring;
    final session = harness.session;

    controller.select(TerrainPolygonSelection.vertex('collision_001', 1));
    controller.setTool(TerrainPolygonTool.moveVertex);
    expect(
      controller.beginGesture(
        pointer: 17,
        point: const TerrainPolygonScenePoint(0, -6),
      ),
      isTrue,
    );
    controller.updateGesture(
      pointer: 17,
      point: const TerrainPolygonScenePoint(0, -8),
    );

    expect(controller.commitGesture(17), isFalse);
    expect(controller.hasActiveOperation, isTrue);
    expect(controller.prefab.revision, 4);
    expect(session.canUndo, isFalse);
    expect(
      controller.issues.map((issue) => issue.code),
      contains('collinear_middle_vertex'),
    );

    expect(controller.normalizeSelectedShape(), isTrue);
    expect(controller.hasActiveOperation, isFalse);
    expect(controller.prefab.revision, 5);
    expect(controller.prefab.collisionShapes.single.vertices, hasLength(4));
    expect(session.canUndo, isTrue);
    expect(session.pendingChanges.changedItemIds, <String>['target']);
    expect(
      controller.issues.map((issue) => issue.code),
      contains('normalized_collinear_vertex'),
    );
  });

  test(
    'creation derives collision semantics without terrain metadata',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      final session = harness.session;

      controller.setNewShapeNameInput('collision_002');
      expect(controller.beginCreatePolygon(), isTrue);
      expect(controller.state.draft!.shapeId, 'collision_002');
      expect(
        controller.state.draft!.collisionMode,
        TerrainSourceCollisionMode.solid,
      );
      expect(controller.state.draft!.surfaceKind, isNull);
      expect(controller.state.draft!.materialKey, isNull);
      expect(session.canUndo, isFalse);
      expect(controller.prefab.revision, 4);
      controller.cancelActiveOperation();

      controller.select(TerrainPolygonSelection.shape('collision_001'));
      expect(
        controller.editSelectedAxisAlignedRectangle(
          xHalfPixels: -6,
          yHalfPixels: -6,
          widthHalfPixels: 12,
          heightHalfPixels: 12,
          shapeId: 'collision_main',
        ),
        isTrue,
      );
      expect(controller.prefab.revision, 5);
      expect(session.canUndo, isTrue);
      expect(
        controller.state.selection,
        TerrainPolygonSelection.shape('collision_main'),
      );
      final edited = controller.prefab.collisionShapes.single;
      expect(edited.shapeId, 'collision_main');
      expect(edited.vertices, const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: -6, yHalfPixels: -6),
        TerrainSourceVertexDef(xHalfPixels: 6, yHalfPixels: -6),
        TerrainSourceVertexDef(xHalfPixels: 6, yHalfPixels: 6),
        TerrainSourceVertexDef(xHalfPixels: -6, yHalfPixels: 6),
      ]);
      expect(
        controller.validateShapeName('collision_main'),
        contains('already uses'),
      );
      expect(
        controller.validateShapeName(
          'collision_main',
          excludingShapeId: 'collision_main',
        ),
        isNull,
      );
    },
  );

  test('controller requires a current prefab-v3 session', () {
    final session = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: const <AuthoringDomainPlugin>[PrefabDomainPlugin()],
      ),
      initialPluginId: PrefabDomainPlugin.pluginId,
      initialWorkspacePath: Directory.current.path,
    );

    expect(
      () => PrefabPolygonAuthoringController(
        session: session,
        prefabKey: 'target',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('PrefabV3Document'),
        ),
      ),
    );
  });

  testWidgets('scene surface exposes its collision-editor semantics label', (
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

    expect(
      find.bySemanticsLabel('Prefab collision polygon editor'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('scene surface drags a rectangle into a local draft', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    final transform = TerrainPolygonViewportTransform(
      origin: const Offset(100, 100),
      zoom: 4,
    );
    controller.setTool(TerrainPolygonTool.createRectangle);
    await tester.pumpWidget(
      _surfaceApp(controller: controller, transform: transform),
    );
    final topLeft = tester.getTopLeft(
      find.byKey(const ValueKey<String>('prefab_polygon_scene_surface')),
    );
    final start = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
    );
    final end = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 40, yHalfPixels: 40),
    );

    final drag = await tester.startGesture(topLeft + start);
    await drag.moveTo(topLeft + end);
    await tester.pump();

    expect(controller.state.draft!.isClosed, isTrue);
    expect(
      controller.sceneProjection.draft!.vertices,
      const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 40, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 40, yHalfPixels: 40),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 40),
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

  testWidgets(
    'scene surface selects, previews, commits, and cancels with Escape',
    (tester) async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      final transform = TerrainPolygonViewportTransform(
        origin: const Offset(100, 100),
        zoom: 4,
      );
      controller.setTool(TerrainPolygonTool.moveVertex);

      await tester.pumpWidget(
        _surfaceApp(controller: controller, transform: transform),
      );
      final topLeft = tester.getTopLeft(
        find.byKey(const ValueKey<String>('prefab_polygon_scene_surface')),
      );
      final firstDrag = await tester.startGesture(
        topLeft + const Offset(116, 84),
      );
      await firstDrag.moveTo(topLeft + const Offset(120, 84));
      await tester.pump();

      expect(controller.hasActiveOperation, isTrue);
      expect(controller.prefab.revision, 4);
      expect(controller.state.visibleShapes.single.vertices[1].xHalfPixels, 10);

      await firstDrag.up();
      await tester.pump();
      expect(controller.prefab.revision, 5);
      expect(controller.hasActiveOperation, isFalse);
      expect(controller.state.tool, TerrainPolygonTool.moveVertex);

      final cancelledDrag = await tester.startGesture(
        topLeft + const Offset(116, 116),
      );
      await cancelledDrag.moveTo(topLeft + const Offset(120, 116));
      await tester.pump();
      expect(controller.hasActiveOperation, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await cancelledDrag.up();
      await tester.pump();

      expect(controller.hasActiveOperation, isFalse);
      expect(controller.prefab.revision, 5);
      expect(controller.state.shapes.single.vertices[1].xHalfPixels, 10);
      expect(
        controller.state.shapes.single.vertices[2],
        const TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
      );
    },
  );

  testWidgets('scene surface moves and inserts open-draft vertices locally', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    final transform = TerrainPolygonViewportTransform(
      origin: const Offset(100, 100),
      zoom: 4,
    );
    controller.beginCreatePolygon();
    for (final point in const <TerrainPolygonScenePoint>[
      TerrainPolygonScenePoint(0, 0),
      TerrainPolygonScenePoint(20, 0),
      TerrainPolygonScenePoint(20, 20),
    ]) {
      controller.addDraftVertex(point);
    }
    controller.setTool(TerrainPolygonTool.moveVertex);

    await tester.pumpWidget(
      _surfaceApp(controller: controller, transform: transform),
    );
    final topLeft = tester.getTopLeft(
      find.byKey(const ValueKey<String>('prefab_polygon_scene_surface')),
    );
    final vertexCanvas = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
    );
    final move = await tester.startGesture(topLeft + vertexCanvas);
    await move.moveTo(topLeft + vertexCanvas + const Offset(4, 0));
    await move.up();
    await tester.pump();

    expect(controller.state.draft!.vertices[1].xHalfPixels, 22);
    expect(controller.canUndo, isTrue);
    expect(controller.undo(), isTrue);
    expect(controller.state.draft!.vertices[1].xHalfPixels, 20);
    expect(controller.canRedo, isTrue);
    expect(controller.redo(), isTrue);
    expect(controller.state.draft!.vertices[1].xHalfPixels, 22);

    controller.setTool(TerrainPolygonTool.insertVertex);
    final edgeCanvas = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 10, yHalfPixels: 0),
    );
    final insert = await tester.startGesture(topLeft + edgeCanvas);
    await insert.moveTo(topLeft + edgeCanvas + const Offset(0, -4));
    await insert.up();
    await tester.pump();

    expect(controller.state.draft!.vertices, hasLength(4));
    expect(
      controller.state.draft!.vertices[1],
      const TerrainSourceVertexDef(xHalfPixels: 10, yHalfPixels: -2),
    );

    controller.setTool(TerrainPolygonTool.createPolygon);
    final appendedVertexCanvas = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
    );
    await tester.tapAt(topLeft + appendedVertexCanvas);
    await tester.pump();

    expect(controller.state.draft!.vertices, hasLength(5));
    expect(
      controller.state.draft!.vertices.last,
      const TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
    );
    expect(harness.session.canUndo, isFalse);
    expect(controller.prefab.revision, 4);
  });

  testWidgets('focused surface Delete and Ctrl shortcuts use session history', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    _registerShellUndoRedoShortcuts(
      undo: controller.undo,
      redo: controller.redo,
    );
    final transform = TerrainPolygonViewportTransform(
      origin: const Offset(100, 100),
      zoom: 4,
    );

    await tester.pumpWidget(
      _surfaceApp(controller: controller, transform: transform),
    );
    final surface = find.byKey(
      const ValueKey<String>('prefab_polygon_scene_surface'),
    );
    final topLeft = tester.getTopLeft(surface);
    await tester.tapAt(topLeft + const Offset(116, 84));
    await tester.pump();
    expect(
      controller.state.selection,
      TerrainPolygonSelection.vertex('collision_001', 1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(controller.prefab.revision, 5);
    expect(controller.state.shapes.single.vertices, hasLength(3));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.prefab.revision, 4);
    expect(controller.state.shapes.single.vertices, hasLength(4));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.prefab.revision, 5);
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
            origin: const Offset(100, 100),
            zoom: 4,
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
      origin: const Offset(100, 100),
      zoom: 4,
    );

    await tester.pumpWidget(
      _surfaceApp(
        controller: controller,
        transform: transform,
        onPanDelta: panDeltas.add,
      ),
    );
    final surface = find.byKey(
      const ValueKey<String>('prefab_polygon_scene_surface'),
    );
    final center = tester.getCenter(surface);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final pan = await tester.startGesture(center);
    await pan.moveBy(const Offset(12, -7));
    await pan.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(panDeltas, isNotEmpty);
    expect(harness.session.document, same(document));
    expect(harness.session.canUndo, isFalse);
    expect(controller.prefab.revision, 4);
  });

  test(
    'fit refit remains local and equivalent save is a history no-op',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      controller.select(TerrainPolygonSelection.shape('collision_001'));
      final mask = _alphaMask(<String>[
        '..........',
        '.########.',
        '.########.',
        '.########.',
        '.########.',
        '.########.',
        '.########.',
        '.########.',
        '.########.',
        '..........',
      ]);
      final result = PrefabCollisionFitter.generate(
        mask: mask,
        method: PrefabCollisionCreationMethod.fitVisibleBounds,
      );

      final token = controller.startFitGeneration(
        method: PrefabCollisionCreationMethod.fitVisibleBounds,
        settings: const PrefabCollisionFitSettings(),
        refitShapeId: 'collision_001',
      );
      expect(token, isNonZero);
      expect(controller.prefab.revision, 4);
      expect(harness.session.canUndo, isFalse);
      expect(
        controller.completeFitGeneration(
          token: token,
          sourceMask: mask,
          sourceIdentity: 'source-a',
          result: result,
          visualOriginXPx: -5,
          visualOriginYPx: -5,
        ),
        isTrue,
      );
      expect(controller.hasFitDraft, isTrue);
      expect(controller.canSaveFitDraft, isTrue);
      expect(controller.prefab.revision, 4);

      expect(
        controller.saveFitDraft(currentSourceIdentity: 'source-a'),
        isTrue,
      );
      expect(controller.hasFitDraft, isFalse);
      expect(controller.prefab.revision, 4);
      expect(harness.session.canUndo, isFalse);
    },
  );

  test(
    'platform fit saves disconnected one-way candidates atomically',
    () async {
      final harness = await _buildHarness(
        kind: PrefabKind.platform,
        collisionShapes: const <TerrainSourceShapeDef>[],
      );
      final controller = harness.authoring;
      final mask = _alphaMask(<String>[
        '##..##....',
        '##..##....',
        '..........',
        '..........',
        '..........',
        '..........',
        '..........',
        '..........',
        '..........',
        '..........',
      ]);
      final result = PrefabCollisionFitter.generate(
        mask: mask,
        method: PrefabCollisionCreationMethod.detectPlatformSurface,
      );
      final token = controller.startFitGeneration(
        method: PrefabCollisionCreationMethod.detectPlatformSurface,
        settings: const PrefabCollisionFitSettings(),
      );

      expect(
        controller.completeFitGeneration(
          token: token,
          sourceMask: mask,
          sourceIdentity: 'source-platform',
          result: result,
          visualOriginXPx: -5,
          visualOriginYPx: -5,
        ),
        isTrue,
      );
      expect(controller.fitCandidateShapeIds, hasLength(2));
      expect(controller.prefab.collisionShapes, isEmpty);
      expect(harness.session.canUndo, isFalse);
      expect(
        controller.saveFitDraft(currentSourceIdentity: 'source-platform'),
        isTrue,
        reason: controller.issues
            .map((issue) => '${issue.code}: ${issue.message}')
            .join('\n'),
      );
      expect(controller.prefab.revision, 5);
      expect(controller.prefab.collisionShapes, hasLength(2));
      expect(
        controller.prefab.collisionShapes.map((shape) => shape.collisionMode),
        everyElement(TerrainSourceCollisionMode.oneWay),
      );
      expect(
        controller.prefab.collisionShapes.map((shape) => shape.surfaceKind),
        everyElement(isNull),
      );
      expect(
        controller.prefab.collisionShapes.map((shape) => shape.materialKey),
        everyElement(isNull),
      );
      expect(harness.session.canUndo, isTrue);
      expect(controller.undo(), isTrue);
      expect(controller.prefab.collisionShapes, isEmpty);
    },
  );

  test('interlocking platform closures remain blocked for review', () async {
    final harness = await _buildHarness(
      kind: PrefabKind.platform,
      collisionShapes: const <TerrainSourceShapeDef>[],
    );
    final controller = harness.authoring;
    final mask = _alphaMask(<String>[
      '#####.....',
      '#...#.....',
      '#.#.#.....',
      '#...#.....',
      '#####.....',
      '..........',
      '..........',
      '..........',
      '..........',
      '..........',
    ]);
    final result = PrefabCollisionFitter.generate(
      mask: mask,
      method: PrefabCollisionCreationMethod.detectPlatformSurface,
    );
    final token = controller.startFitGeneration(
      method: PrefabCollisionCreationMethod.detectPlatformSurface,
      settings: const PrefabCollisionFitSettings(),
    );

    expect(result.shapes, hasLength(2));
    expect(
      controller.completeFitGeneration(
        token: token,
        sourceMask: mask,
        sourceIdentity: 'interlocking-platform',
        result: result,
        visualOriginXPx: -5,
        visualOriginYPx: -5,
      ),
      isFalse,
    );
    expect(controller.hasFitDraft, isTrue);
    expect(controller.canSaveFitDraft, isFalse);
    expect(controller.fitMessages.join(' '), contains('overlap'));
    expect(controller.prefab.collisionShapes, isEmpty);
  });

  test('fit cancel and stale source preserve the owner snapshot', () async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    final mask = _alphaMask(List<String>.filled(10, '##########'));
    final result = PrefabCollisionFitter.generate(
      mask: mask,
      method: PrefabCollisionCreationMethod.fitVisibleBounds,
    );
    final token = controller.startFitGeneration(
      method: PrefabCollisionCreationMethod.fitVisibleBounds,
      settings: const PrefabCollisionFitSettings(),
      refitShapeId: 'collision_001',
    );
    controller.completeFitGeneration(
      token: token,
      sourceMask: mask,
      sourceIdentity: 'before',
      result: result,
      visualOriginXPx: -5,
      visualOriginYPx: -5,
    );

    expect(controller.saveFitDraft(currentSourceIdentity: 'after'), isFalse);
    expect(controller.hasFitDraft, isTrue);
    expect(controller.prefab.revision, 4);
    expect(controller.cancelFitDraft(), isTrue);
    expect(controller.prefab.collisionShapes, <TerrainSourceShapeDef>[
      _rectangle(),
    ]);
    expect(harness.session.canUndo, isFalse);
  });

  test(
    'a stale async fit completion cannot replace a newer generation',
    () async {
      final harness = await _buildHarness();
      final controller = harness.authoring;
      final mask = _alphaMask(List<String>.filled(10, '##########'));
      final result = PrefabCollisionFitter.generate(
        mask: mask,
        method: PrefabCollisionCreationMethod.fitVisibleBounds,
      );
      final staleToken = controller.startFitGeneration(
        method: PrefabCollisionCreationMethod.fitVisibleBounds,
        settings: const PrefabCollisionFitSettings(),
      );
      final currentToken = controller.startFitGeneration(
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
        settings: const PrefabCollisionFitSettings(),
      );

      expect(
        controller.completeFitGeneration(
          token: staleToken,
          sourceMask: mask,
          sourceIdentity: 'stale',
          result: result,
          visualOriginXPx: -5,
          visualOriginYPx: -5,
        ),
        isFalse,
      );
      expect(controller.isFitLoading, isTrue);
      expect(
        controller.fitMethod,
        PrefabCollisionCreationMethod.traceVisibleOutline,
      );
      expect(
        controller.completeFitGeneration(
          token: currentToken,
          sourceMask: mask,
          sourceIdentity: 'current',
          result: result,
          visualOriginXPx: -5,
          visualOriginYPx: -5,
        ),
        isFalse,
        reason: 'the current generation rejects a result from another method',
      );
      expect(controller.fitMessages.join(' '), contains('does not match'));
      expect(controller.prefab.revision, 4);
    },
  );

  test('fit review disables Save for a transformed Chunk collision', () async {
    final chunk = ChunkV2FileData(
      chunkKey: 'forest_test',
      id: 'forest_test',
      revision: 1,
      status: chunkStatusActive,
      levelId: 'forest',
      tileSize: 16,
      width: 100,
      height: 100,
      difficulty: chunkDifficultyNormal,
      assemblyGroupId: defaultChunkAssemblyGroupId,
      tags: const <String>[],
      tileLayers: const <TileLayerDef>[],
      prefabs: const <PlacedPrefabDef>[
        PlacedPrefabDef(prefabId: 'target', prefabKey: 'target', x: 10, y: 10),
      ],
      markers: const <PlacedMarkerDef>[],
      groundBandZIndex: 0,
      collisionShapes: <TerrainSourceShapeDef>[
        _box('ground', left: 28, top: 12, right: 40, bottom: 28),
      ],
    );
    final harness = await _buildHarness(
      downstreamChunks: <PrefabV3DownstreamChunk>[
        PrefabV3DownstreamChunk(
          data: chunk,
          sourcePath: 'assets/authoring/level/chunks/forest_test.json',
          baselineContents: ChunkV2FileCodec.encode(chunk),
        ),
      ],
    );
    final controller = harness.authoring;
    final mask = _alphaMask(List<String>.filled(10, '##########'));
    final result = PrefabCollisionFitter.generate(
      mask: mask,
      method: PrefabCollisionCreationMethod.fitVisibleBounds,
    );
    final token = controller.startFitGeneration(
      method: PrefabCollisionCreationMethod.fitVisibleBounds,
      settings: const PrefabCollisionFitSettings(),
      refitShapeId: 'collision_001',
    );

    expect(
      controller.completeFitGeneration(
        token: token,
        sourceMask: mask,
        sourceIdentity: 'downstream-overlap',
        result: result,
        visualOriginXPx: -5,
        visualOriginYPx: -5,
      ),
      isFalse,
    );
    expect(controller.canSaveFitDraft, isFalse);
    expect(controller.fitMessages.join(' '), contains('overlap'));
    expect(controller.prefab.revision, 4);
    expect(harness.session.canUndo, isFalse);
  });

  test('refit scopes components, clears terrain metadata, and allocates IDs atomically', () async {
    final selected = _box(
      'collision_001',
      left: -4,
      top: -4,
      right: 4,
      bottom: 4,
      surfaceKind: 'stone',
      materialKey: 'granite',
    );
    final unrelated = _box(
      'collision_002',
      left: -10,
      top: 6,
      right: -8,
      bottom: 8,
      surfaceKind: 'obstacle',
      materialKey: 'legacy_material',
    );
    final harness = await _buildHarness(
      collisionShapes: <TerrainSourceShapeDef>[selected, unrelated],
    );
    final controller = harness.authoring;
    controller.select(TerrainPolygonSelection.shape(selected.shapeId));
    final mask = _alphaMask(<String>[
      '........##',
      '........##',
      '..........',
      '...####...',
      '...####...',
      '...####...',
      '...####...',
      '..........',
      '..........',
      '..........',
    ]);
    final result = PrefabCollisionFitter.generate(
      mask: mask,
      method: PrefabCollisionCreationMethod.traceVisibleOutline,
    );
    final token = controller.startFitGeneration(
      method: PrefabCollisionCreationMethod.traceVisibleOutline,
      settings: const PrefabCollisionFitSettings(),
      refitShapeId: selected.shapeId,
    );

    expect(
      controller.completeFitGeneration(
        token: token,
        sourceMask: mask,
        sourceIdentity: 'source-refit',
        result: result,
        visualOriginXPx: -5,
        visualOriginYPx: -5,
      ),
      isTrue,
    );
    final candidateIds = controller.fitCandidateShapeIds;
    expect(candidateIds, <String>['collision_001', 'collision_003']);
    expect(controller.isFitCandidateIncluded(candidateIds.first), isFalse);
    expect(controller.isFitCandidateIncluded(candidateIds.last), isTrue);
    expect(controller.fitEvidence!.coveredVisiblePixels, 16);

    controller.select(TerrainPolygonSelection.shape(candidateIds.last));
    expect(
      controller.editSelectedAxisAlignedRectangle(
        xHalfPixels: -4,
        yHalfPixels: -4,
        widthHalfPixels: 10,
        heightHalfPixels: 8,
        shapeId: candidateIds.last,
      ),
      isTrue,
    );
    expect(controller.fitEvidence!.coveredTransparentPixels, 4);
    expect(controller.undo(), isTrue);
    expect(controller.fitEvidence!.coveredTransparentPixels, 0);

    controller.setFitCandidateIncluded(candidateIds.first, true);
    expect(controller.fitEvidence!.coveredVisiblePixels, 20);
    expect(controller.canUndo, isTrue);
    expect(controller.undo(), isTrue);
    expect(controller.isFitCandidateIncluded(candidateIds.first), isFalse);
    expect(controller.redo(), isTrue);
    expect(controller.isFitCandidateIncluded(candidateIds.first), isTrue);

    expect(
      controller.saveFitDraft(currentSourceIdentity: 'source-refit'),
      isTrue,
      reason: controller.fitMessages.join('\n'),
    );
    final saved = controller.prefab.collisionShapes;
    expect(controller.prefab.revision, 5);
    expect(saved, hasLength(3));
    expect(
      saved.singleWhere((shape) => shape.shapeId == 'collision_002'),
      unrelated,
    );
    for (final id in <String>['collision_001', 'collision_003']) {
      final shape = saved.singleWhere((candidate) => candidate.shapeId == id);
      expect(shape.surfaceKind, isNull);
      expect(shape.materialKey, isNull);
      expect(shape.collisionMode, TerrainSourceCollisionMode.solid);
    }
    expect(controller.undo(), isTrue);
    expect(controller.prefab.collisionShapes, <TerrainSourceShapeDef>[
      selected,
      unrelated,
    ]);
    expect(controller.redo(), isTrue);
    expect(controller.prefab.collisionShapes, saved);
  });
}

Widget _surfaceApp({
  required PrefabPolygonAuthoringController controller,
  required TerrainPolygonViewportTransform transform,
  ValueChanged<Offset>? onPanDelta,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: PrefabPolygonSceneSurface(
          controller: controller,
          transform: transform,
          onPanDelta: onPanDelta,
          visualSource: const ColoredBox(color: Color(0xFF111A22)),
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
  PrefabKind kind = PrefabKind.obstacle,
  Iterable<PrefabV3DownstreamChunk> downstreamChunks =
      const <PrefabV3DownstreamChunk>[],
}) async {
  final root = Directory.systemTemp.createTempSync('prefab_polygon_route_');
  final data = PrefabV3FileData(
    slices: const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'slice_a',
        sourceImagePath: 'assets/images/level/test.png',
        x: 0,
        y: 0,
        width: 10,
        height: 10,
      ),
    ],
    prefabs: <PrefabV3Def>[
      PrefabV3Def(
        prefabKey: 'target',
        id: 'target',
        revision: 4,
        status: PrefabStatus.active,
        kind: kind,
        visualSource: kind == PrefabKind.platform
            ? const PrefabVisualSource.platformModule('module_a')
            : const PrefabVisualSource.atlasSlice('slice_a'),
        anchorXPx: 5,
        anchorYPx: 5,
        collisionShapes:
            collisionShapes ?? <TerrainSourceShapeDef>[shape ?? _rectangle()],
        tags: const <String>['test'],
      ),
    ],
  );
  final tileData = PrefabTileFileData(
    tileSlices: kind == PrefabKind.platform
        ? const <AtlasSliceDef>[
            AtlasSliceDef(
              id: 'tile_a',
              sourceImagePath: 'assets/images/level/test.png',
              x: 0,
              y: 0,
              width: 10,
              height: 10,
            ),
          ]
        : const <AtlasSliceDef>[],
    platformModules: kind == PrefabKind.platform
        ? const <TileModuleDef>[
            TileModuleDef(
              id: 'module_a',
              tileSize: 10,
              cells: <TileModuleCellDef>[
                TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
              ],
            ),
          ]
        : const <TileModuleDef>[],
  );
  final document = PrefabV3Document(
    data: data,
    tileData: tileData,
    visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
      'target': PrefabV3VisualBounds(widthPx: 10, heightPx: 10),
    },
    atlasImagePaths: const <String>[],
    atlasImageSizes: const <String, Size>{
      'assets/images/level/test.png': Size(10, 10),
    },
    prefabBaselineContents: PrefabV3FileCodec.encode(data),
    tileBaselineContents: PrefabTileFileCodec.encode(tileData),
    downstreamChunks: downstreamChunks,
  );
  final session = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[_PrefabPlugin(document)],
    ),
    initialPluginId: PrefabDomainPlugin.pluginId,
    initialWorkspacePath: root.path,
  );
  await session.loadWorkspace();
  final authoring = PrefabPolygonAuthoringController(
    session: session,
    prefabKey: 'target',
  );
  addTearDown(() {
    authoring.dispose();
    session.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return _Harness(session: session, authoring: authoring);
}

PrefabAlphaMask _alphaMask(List<String> rows) => PrefabAlphaMask(
  width: rows.first.length,
  height: rows.length,
  alpha: Uint8List.fromList(<int>[
    for (final row in rows)
      for (final value in row.codeUnits) value == 35 ? 255 : 0,
  ]),
);

TerrainSourceShapeDef _rectangle() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: 8),
  ],
);

TerrainSourceShapeDef _box(
  String shapeId, {
  required int left,
  required int top,
  required int right,
  required int bottom,
  String? surfaceKind,
  String? materialKey,
}) => TerrainSourceShapeDef(
  shapeId: shapeId,
  surfaceKind: surfaceKind,
  materialKey: materialKey,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: bottom),
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: bottom),
  ],
);

TerrainSourceShapeDef _pentagon() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: -6),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: 8),
  ],
);

final class _Harness {
  const _Harness({required this.session, required this.authoring});

  final EditorSessionController session;
  final PrefabPolygonAuthoringController authoring;
}

final class _PrefabPlugin implements AuthoringDomainPlugin {
  const _PrefabPlugin(this.document);

  final PrefabV3Document document;
  static const PrefabDomainPlugin _delegate = PrefabDomainPlugin();

  @override
  String get id => PrefabDomainPlugin.pluginId;

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
