import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_staging_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets(
    'explicit chunk-v2 route edits active-level owners without reloading source',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness();
      addTearDown(harness.dispose);
      expect(harness.plugin.loadCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_staging_workspace')),
        findsOneWidget,
      );
      expect(harness.plugin.loadCount, 1);
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_owner_forest_chunk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_owner_meadow_chunk')),
        findsNothing,
      );
      final lockedApply = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('chunk_polygon_apply_locked')),
      );
      expect(lockedApply.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_shape_ground_001')),
      );
      await tester.pump();
      final deleteShape = find.byKey(
        const ValueKey<String>('chunk_polygon_delete_shape'),
      );
      await tester.ensureVisible(deleteShape);
      await tester.tap(deleteShape);
      await tester.pump();

      var forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 5);
      expect(forestChunk.collisionShapes, isEmpty);
      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'forest_chunk',
      ]);

      final routeState = tester.state(find.byType(ChunkCreatorPage));
      final localDraftState = routeState as EditorPageLocalDraftState;
      final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
      final reloadHandler = routeState as EditorPageReloadHandler;
      expect(localDraftState.hasLocalDraftChanges, isTrue);
      expect(shortcutHandler.canHandleUndoSessionShortcut, isTrue);
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();

      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(forestChunk.collisionShapes, hasLength(1));
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      expect(reloadHandler.canReloadEditorPage, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_shape_ground_001')),
      );
      await tester.pump();
      final firstVertex = find.byKey(
        const ValueKey<String>('chunk_polygon_vertex_ground_001_0'),
      );
      await tester.ensureVisible(firstVertex);
      await tester.tap(firstVertex);
      await tester.pump();
      final xField = find.byKey(
        const ValueKey<String>('chunk_polygon_vertex_x_field'),
      );
      final yField = find.byKey(
        const ValueKey<String>('chunk_polygon_vertex_y_field'),
      );
      final applyVertex = find.byKey(
        const ValueKey<String>('chunk_polygon_apply_vertex'),
      );
      await tester.ensureVisible(xField);
      await tester.enterText(xField, '12.25');
      await tester.enterText(yField, '10.5');
      await tester.tap(applyVertex);
      await tester.pump();

      expect(find.text('Use an integer or .5 value.'), findsOneWidget);
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.enterText(xField, '12.5');
      await tester.tap(applyVertex);
      await tester.pump();

      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 5);
      expect(
        forestChunk.collisionShapes.single.vertices,
        contains(
          const TerrainSourceVertexDef(xHalfPixels: 25, yHalfPixels: 21),
        ),
      );
      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'forest_chunk',
      ]);
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.enterText(xField, '101');
      await tester.tap(applyVertex);
      await tester.pump();
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      expect(find.text('chunk_collision_shape_out_of_bounds'), findsOneWidget);
      expect(tester.widget<TextField>(xField).controller!.text, '101');

      final editMetadata = find.byKey(
        const ValueKey<String>('chunk_polygon_edit_metadata'),
      );
      await tester.ensureVisible(editMetadata);
      await tester.tap(editMetadata);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_metadata_dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_metadata_mode')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('oneWay').last);
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('chunk_polygon_metadata_surface_field'),
        ),
        ' moss ',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('chunk_polygon_metadata_material_field'),
        ),
        ' ground_01 ',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_metadata_apply')),
      );
      await tester.pumpAndSettle();

      forestChunk = _chunk(harness.session, 'forest_chunk');
      final editedShape = forestChunk.collisionShapes.single;
      expect(forestChunk.revision, 5);
      expect(editedShape.collisionMode, TerrainSourceCollisionMode.oneWay);
      expect(editedShape.surfaceKind, 'moss');
      expect(editedShape.materialKey, 'ground_01');
      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'forest_chunk',
      ]);
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(
        forestChunk.collisionShapes.single.collisionMode,
        TerrainSourceCollisionMode.solid,
      );
      expect(forestChunk.collisionShapes.single.surfaceKind, isNull);
      expect(forestChunk.collisionShapes.single.materialKey, isNull);
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      final duplicateShape = find.byKey(
        const ValueKey<String>('chunk_polygon_duplicate_shape'),
      );
      await tester.ensureVisible(duplicateShape);
      await tester.tap(duplicateShape);
      await tester.pump();
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 5);
      expect(forestChunk.collisionShapes, hasLength(2));
      final duplicatedShape = forestChunk.collisionShapes.singleWhere(
        (shape) => shape.shapeId == 'ground_002',
      );
      expect(
        duplicatedShape.vertices,
        contains(
          const TerrainSourceVertexDef(xHalfPixels: 102, yHalfPixels: 20),
        ),
      );
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(forestChunk.collisionShapes, hasLength(1));
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_level_selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('meadow').last);
      await tester.pumpAndSettle();

      expect(
        (harness.session.document! as ChunkV2StagingDocument).activeLevelId,
        'meadow',
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_owner_meadow_chunk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_owner_forest_chunk')),
        findsNothing,
      );
      expect(harness.plugin.loadCount, 1);
    },
  );
}

Future<_Harness> _buildHarness() async {
  final root = Directory.systemTemp.createTempSync('chunk_stage_page_');
  final forestChunk = _chunkData(
    chunkKey: 'forest_chunk',
    levelId: 'forest',
    shapeId: 'ground_001',
  );
  final meadowChunk = _chunkData(
    chunkKey: 'meadow_chunk',
    levelId: 'meadow',
    shapeId: 'ground_002',
  );
  final document = ChunkV2StagingDocument(
    chunks: <ChunkV2FileData>[forestChunk, meadowChunk],
    sourcePathByChunkKey: const <String, String>{
      'forest_chunk': 'chunks/forest_chunk.json',
      'meadow_chunk': 'chunks/meadow_chunk.json',
    },
    baselineContentsByChunkKey: <String, String>{
      'forest_chunk': ChunkV2FileCodec.encode(forestChunk),
      'meadow_chunk': ChunkV2FileCodec.encode(meadowChunk),
    },
    prefabData: PrefabV3FileData(
      slices: const <AtlasSliceDef>[],
      prefabs: const <PrefabV3Def>[],
    ),
    tileData: PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[],
      platformModules: const <TileModuleDef>[],
    ),
    visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{},
    availableLevelIds: const <String>['forest', 'meadow'],
    activeLevelId: 'forest',
  );
  final plugin = _StagingChunkPlugin(document);
  final session = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[plugin],
    ),
    initialPluginId: ChunkDomainPlugin.pluginId,
    initialWorkspacePath: root.path,
  );
  await session.loadWorkspace();
  return _Harness(root: root, session: session, plugin: plugin);
}

ChunkV2FileData _chunkData({
  required String chunkKey,
  required String levelId,
  required String shapeId,
}) => ChunkV2FileData(
  chunkKey: chunkKey,
  id: chunkKey,
  revision: 4,
  status: chunkStatusActive,
  levelId: levelId,
  tileSize: 16,
  width: 100,
  height: 50,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: <String>[levelId],
  tileLayers: const <TileLayerDef>[],
  prefabs: const <PlacedPrefabDef>[],
  markers: const <PlacedMarkerDef>[],
  groundBandZIndex: 0,
  collisionShapes: <TerrainSourceShapeDef>[
    TerrainSourceShapeDef(
      shapeId: shapeId,
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 80),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 80),
      ],
    ),
  ],
);

ChunkV2FileData _chunk(EditorSessionController session, String chunkKey) {
  final document = session.document! as ChunkV2StagingDocument;
  return document.chunks.singleWhere((chunk) => chunk.chunkKey == chunkKey);
}

final class _Harness {
  const _Harness({
    required this.root,
    required this.session,
    required this.plugin,
  });

  final Directory root;
  final EditorSessionController session;
  final _StagingChunkPlugin plugin;

  void dispose() {
    session.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

final class _StagingChunkPlugin implements AuthoringDomainPlugin {
  _StagingChunkPlugin(this.document);

  final ChunkV2StagingDocument document;
  final ChunkDomainPlugin _delegate = ChunkDomainPlugin();
  int loadCount = 0;

  @override
  String get id => ChunkDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    loadCount += 1;
    return document;
  }

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
