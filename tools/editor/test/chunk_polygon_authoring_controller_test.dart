import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_polygon_authoring_controller.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_polygon_scene_surface.dart';
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
    'owner rejection preserves preview and exact diagnostics outside history',
    () async {
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

      expect(controller.commitGesture(3), isFalse);
      expect(session.document, same(loadedDocument));
      expect(session.canUndo, isFalse);
      expect(controller.hasActiveOperation, isTrue);
      expect(
        controller.state.visibleShapes.single.vertices.first.xHalfPixels,
        220,
      );
      expect(
        controller.issues.map((issue) => issue.code),
        contains('chunk_collision_shape_out_of_bounds'),
      );
      expect(controller.issues.single.shapeId, 'ground_001');
      expect(
        () => controller.issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
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
      find.bySemanticsLabel('Chunk collision polygon editor'),
      findsOneWidget,
    );
    semantics.dispose();
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
        find.byKey(const ValueKey<String>('chunk_polygon_scene_surface')),
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

  testWidgets('focused Delete and Ctrl shortcuts use session history', (
    tester,
  ) async {
    final harness = await _buildHarness();
    final controller = harness.authoring;
    final transform = TerrainPolygonViewportTransform(
      origin: const Offset(10, 10),
      zoom: 2,
    );
    await tester.pumpWidget(
      _surfaceApp(controller: controller, transform: transform),
    );
    final topLeft = tester.getTopLeft(
      find.byKey(const ValueKey<String>('chunk_polygon_scene_surface')),
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
    final surface = find.byKey(
      const ValueKey<String>('chunk_polygon_scene_surface'),
    );
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
  ValueChanged<Offset>? onPanDelta,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 240,
        height: 160,
        child: ChunkPolygonSceneSurface(
          controller: controller,
          transform: transform,
          onPanDelta: onPanDelta,
          background: const ColoredBox(color: Color(0xFF111A22)),
        ),
      ),
    ),
  ),
);

Future<_Harness> _buildHarness({TerrainSourceShapeDef? shape}) async {
  final root = Directory.systemTemp.createTempSync('chunk_polygon_route_');
  final chunk = _chunk(shape: shape);
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
      prefabs: const <PrefabV3Def>[],
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
  );
  addTearDown(() {
    authoring.dispose();
    session.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return _Harness(session: session, authoring: authoring);
}

ChunkV2FileData _chunk({TerrainSourceShapeDef? shape}) => ChunkV2FileData(
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
  prefabs: const <PlacedPrefabDef>[],
  markers: const <PlacedMarkerDef>[],
  groundBandZIndex: 0,
  collisionShapes: <TerrainSourceShapeDef>[
    shape ??
        TerrainSourceShapeDef(
          shapeId: 'ground_001',
          vertices: const <TerrainSourceVertexDef>[
            TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
            TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 20),
            TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 80),
            TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 80),
          ],
        ),
  ],
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
