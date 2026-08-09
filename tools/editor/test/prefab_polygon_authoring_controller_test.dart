import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_polygon_authoring_controller.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_polygon_scene_surface.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_polygon_scene_painter.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
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

      controller.cancelActiveOperation();
      expect(controller.hasActiveOperation, isFalse);
      expect(controller.state.visibleShapes, controller.state.shapes);
      expect(controller.issues, isEmpty);
    },
  );

  test('controller requires an explicit staged prefab-v3 session', () {
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
          contains('PrefabV3StagingDocument'),
        ),
      ),
    );
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

      controller.setTool(TerrainPolygonTool.moveVertex);
      final cancelledDrag = await tester.startGesture(
        topLeft + const Offset(120, 84),
      );
      await cancelledDrag.moveTo(topLeft + const Offset(124, 84));
      await tester.pump();
      expect(controller.hasActiveOperation, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await cancelledDrag.up();
      await tester.pump();

      expect(controller.hasActiveOperation, isFalse);
      expect(controller.prefab.revision, 5);
      expect(controller.state.shapes.single.vertices[1].xHalfPixels, 10);
    },
  );

  testWidgets('focused surface Delete and Ctrl shortcuts use session history', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
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

Future<_Harness> _buildHarness() async {
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
        kind: PrefabKind.obstacle,
        visualSource: const PrefabVisualSource.atlasSlice('slice_a'),
        anchorXPx: 5,
        anchorYPx: 5,
        collisionShapes: <TerrainSourceShapeDef>[_rectangle()],
        tags: const <String>['test'],
      ),
    ],
  );
  final tileData = PrefabTileFileData(
    tileSlices: const <AtlasSliceDef>[],
    platformModules: const <TileModuleDef>[],
  );
  final document = PrefabV3StagingDocument(
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
  );
  final session = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[_StagingPrefabPlugin(document)],
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

TerrainSourceShapeDef _rectangle() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
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

final class _StagingPrefabPlugin implements AuthoringDomainPlugin {
  const _StagingPrefabPlugin(this.document);

  final PrefabV3StagingDocument document;
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
