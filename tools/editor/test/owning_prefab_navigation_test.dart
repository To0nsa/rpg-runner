import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_coordinator.dart';
import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_location.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/prefab_creator_page.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/prefab_creator_navigation.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_navigation_state.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  for (final destination in PrefabCreatorDestination.values) {
    testWidgets('history restores the Chunk after opening $destination', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final root = Directory.systemTemp.createTempSync('editor_history_');
      addTearDown(() => root.deleteSync(recursive: true));
      final fixture = _navigationFixture();
      final chunkPlugin = _NavigationChunkPlugin(fixture.chunkDocument);
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: [
            _NavigationEntitiesPlugin(),
            _NavigationPrefabPlugin(fixture.prefabDocument),
            chunkPlugin,
          ],
        ),
        initialPluginId: ChunkDomainPlugin.pluginId,
        initialWorkspacePath: root.path,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: EditorHomePage(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('editor_navigation_back')),
            )
            .onPressed,
        isNull,
      );
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('chunk_polygon_owner_selector')),
          )
          .onChanged!('forest_chunk');
      await tester.pumpAndSettle();
      tester
          .widget<SegmentedButton<ChunkSceneDomain>>(
            find.byKey(const ValueKey('chunk_scene_domain_selector')),
          )
          .onSelectionChanged!({ChunkSceneDomain.prefabs});
      await tester.pumpAndSettle();
      final origin =
          (tester.state(
                find.byType(ChunkCreatorPage),
              ) as EditorPageNavigationState).navigationLocation!
              as ChunkCreatorLocation;
      tester
          .widget<ChunkCreatorPage>(find.byType(ChunkCreatorPage))
          .onOpenPrefabTarget!(
        PrefabCreatorTarget(
          prefabKey: 'prefab_target',
          destination: destination,
        ),
      );
      await tester.pumpAndSettle();
      final prefabLocation =
          (tester.state(
                find.byType(PrefabCreatorPage),
              ) as EditorPageNavigationState).navigationLocation!
              as PrefabCreatorLocation;
      expect(prefabLocation.prefabKey, 'prefab_target');
      expect(
        prefabLocation.view,
        PrefabCreatorLocation.forTarget(
          PrefabCreatorTarget(
            prefabKey: 'prefab_target',
            destination: destination,
          ),
        ).view,
      );

      await tester.tap(find.byKey(const ValueKey('editor_navigation_back')));
      await tester.pumpAndSettle();
      final restored =
          (tester.state(
                find.byType(ChunkCreatorPage),
              ) as EditorPageNavigationState).navigationLocation!
              as ChunkCreatorLocation;
      expect(restored.chunkKey, origin.chunkKey);
      expect(restored.domain, origin.domain);
      expect(restored.zoom, origin.zoom);
      expect(restored.pan, origin.pan);
      expect(controller.pendingChanges.hasChanges, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      final forward =
          (tester.state(
                find.byType(PrefabCreatorPage),
              ) as EditorPageNavigationState).navigationLocation!
              as PrefabCreatorLocation;
      expect(forward.prefabKey, prefabLocation.prefabKey);
      expect(forward.view, prefabLocation.view);

      await _selectRoute(tester, 'CHUNK CREATOR');
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('chunk_polygon_owner_selector')),
            )
            .value,
        'forest_chunk',
      );
      await _selectRoute(tester, 'PREFAB CREATOR');
      final normal =
          (tester.state(
                find.byType(PrefabCreatorPage),
              ) as EditorPageNavigationState).navigationLocation!
              as PrefabCreatorLocation;
      expect(normal.prefabKey, prefabLocation.prefabKey);
      expect(normal.view, prefabLocation.view);
      if (destination == PrefabCreatorDestination.collision) {
        // A dependency journey can outlive a source owner. Re-entry must
        // reconcile the remembered key with fresh sources, without drafts.
        chunkPlugin.document = fixture.chunkDocument.copyWith(
          chunks: [fixture.chunkDocument.chunks.first],
          sourcePathByChunkKey: {
            'aaa_chunk':
                fixture.chunkDocument.sourcePathByChunkKey['aaa_chunk']!,
          },
          baselineContentsByChunkKey: {
            'aaa_chunk':
                fixture.chunkDocument.baselineContentsByChunkKey['aaa_chunk']!,
          },
        );
        await _selectRoute(tester, 'CHUNK CREATOR');
        expect(
          tester
              .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('chunk_polygon_owner_selector')),
              )
              .value,
          'aaa_chunk',
        );
        expect(controller.pendingChanges.hasChanges, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'placed prefab opens its exact atlas slice without using the legacy loader',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final root = Directory.systemTemp.createTempSync(
        'owning_prefab_navigation_',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final fixture = _navigationFixture();
      final prefabPlugin = _NavigationPrefabPlugin(fixture.prefabDocument);
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: <AuthoringDomainPlugin>[
            _NavigationEntitiesPlugin(),
            prefabPlugin,
            _NavigationChunkPlugin(fixture.chunkDocument),
          ],
        ),
        initialPluginId: EntityDomainPlugin.pluginId,
        initialWorkspacePath: root.path,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: EditorHomePage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await _selectRoute(tester, 'CHUNK CREATOR');
      await tester.pumpAndSettle();
      tester
          .widget<SegmentedButton<ChunkSceneDomain>>(
            find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
          )
          .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.prefabs});
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_prefab_placements_section_toggle'),
        ),
      );
      await tester.pumpAndSettle();
      final placementCard = find.byKey(
        const ValueKey<String>('chunk_v2_placement_prefab_target|20|10|0'),
      );
      await tester.tap(placementCard);
      await tester.pumpAndSettle();
      final openAtlas = find.byKey(
        const ValueKey<String>(
          'chunk_v2_placement_open_atlas_prefab_target|20|10|0',
        ),
      );
      await tester.ensureVisible(openAtlas);
      await tester.pumpAndSettle();
      await tester.tap(openAtlas);
      await tester.pumpAndSettle();

      expect(controller.selectedPluginId, PrefabDomainPlugin.pluginId);
      expect(controller.document, same(fixture.prefabDocument));
      expect(prefabPlugin.loadCount, 1);
      expect(prefabPlugin.normalLoadCount, 0);
      expect(
        find.byKey(const ValueKey<String>('prefab_polygon_workspace')),
        findsOneWidget,
      );
      final atlasView = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey<String>('prefab_v3_view_atlas_slices')),
      );
      expect(atlasView.selected, isTrue);
      expect(
        find.byKey(
          const ValueKey<String>('atlas_slice_selected_editor_target_slice'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('atlas_slice_selected_editor_other_slice'),
        ),
        findsNothing,
      );
      expect(fixture.chunk.revision, 1);

      final reloadButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('reload_editor_page_button')),
      );
      expect(reloadButton.onPressed, isNotNull);
      await tester.tap(
        find.byKey(const ValueKey<String>('reload_editor_page_button')),
      );
      await tester.pumpAndSettle();
      expect(prefabPlugin.loadCount, 1);
      expect(prefabPlugin.normalLoadCount, 1);
      expect(
        find.byKey(const ValueKey<String>('prefab_polygon_workspace')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'returning from collision authoring reloads prefab collision without applying the placement',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final root = Directory.systemTemp.createTempSync(
        'owning_prefab_collision_return_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final fixture = _navigationFixture();
      final chunkPlugin = _NavigationChunkPlugin(fixture.chunkDocument);
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: <AuthoringDomainPlugin>[
            _NavigationEntitiesPlugin(),
            _NavigationPrefabPlugin(fixture.prefabDocument),
            chunkPlugin,
          ],
        ),
        initialPluginId: ChunkDomainPlugin.pluginId,
        initialWorkspacePath: root.path,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: EditorHomePage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('chunk_polygon_owner_selector')),
          )
          .onChanged!('forest_chunk');
      await tester.pumpAndSettle();
      tester
          .widget<SegmentedButton<ChunkSceneDomain>>(
            find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
          )
          .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.prefabs});
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_prefab_placements_section_toggle'),
        ),
      );
      await tester.pumpAndSettle();
      const placementKey = 'prefab_target|20|10|0';
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_placement_$placementKey')),
      );
      await tester.pumpAndSettle();
      final openCollision = find.byKey(
        const ValueKey<String>(
          'chunk_v2_placement_open_collision_$placementKey',
        ),
      );
      await tester.ensureVisible(openCollision);
      await tester.tap(openCollision);
      await tester.pumpAndSettle();

      final previousPrefab = fixture.prefabDocument.data.prefabs.singleWhere(
        (prefab) => prefab.prefabKey == 'prefab_target',
      );
      final changedPrefab = previousPrefab.copyWith(
        revision: previousPrefab.revision + 1,
        collisionShapes: <TerrainSourceShapeDef>[
          _collisionShape(rightHalfPixels: 18),
        ],
      );
      final changedPrefabData = fixture.prefabDocument.data.copyWith(
        prefabs: <PrefabV3Def>[
          for (final prefab in fixture.prefabDocument.data.prefabs)
            if (prefab.prefabKey == changedPrefab.prefabKey)
              changedPrefab
            else
              prefab,
        ],
      );
      chunkPlugin.document = fixture.chunkDocument.copyWith(
        prefabData: changedPrefabData,
      );

      await tester.tap(find.byKey(const ValueKey('editor_navigation_back')));
      await tester.pumpAndSettle();

      final scene = controller.scene! as ChunkV2Scene;
      final expanded = scene
          .collisionExpansionByChunkKey['forest_chunk']!
          .expansion!
          .expandedPrefabShapes
          .single;
      expect(expanded.prefabRevision, changedPrefab.revision);
      expect(
        expanded.vertices.any((vertex) => vertex.xTicks == 29 * 1024),
        isTrue,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'chunk_v2_placement_inline_apply_$placementKey',
          ),
        ),
        findsNothing,
      );
      expect(fixture.chunk.revision, 1);
      expect(controller.pendingChanges.hasChanges, isFalse);
    },
  );
}

Future<void> _selectRoute(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

_NavigationFixture _navigationFixture() {
  final target = PrefabV3Def(
    prefabKey: 'prefab_target',
    id: 'target',
    revision: 3,
    status: PrefabStatus.active,
    kind: PrefabKind.obstacle,
    visualSource: const PrefabVisualSource.atlasSlice('target_slice'),
    anchorXPx: 0,
    anchorYPx: 0,
    collisionShapes: <TerrainSourceShapeDef>[_collisionShape()],
    tags: const <String>[],
  );
  final other = PrefabV3Def(
    prefabKey: 'prefab_other',
    id: 'aaa_other',
    revision: 1,
    status: PrefabStatus.active,
    kind: PrefabKind.obstacle,
    visualSource: const PrefabVisualSource.atlasSlice('other_slice'),
    anchorXPx: 0,
    anchorYPx: 0,
    collisionShapes: <TerrainSourceShapeDef>[_collisionShape()],
    tags: const <String>[],
  );
  final prefabData = PrefabV3FileData(
    slices: const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'other_slice',
        sourceImagePath: 'assets/test.png',
        x: 0,
        y: 0,
        width: 10,
        height: 10,
      ),
      AtlasSliceDef(
        id: 'target_slice',
        sourceImagePath: 'assets/test.png',
        x: 10,
        y: 0,
        width: 10,
        height: 10,
      ),
    ],
    prefabs: <PrefabV3Def>[other, target],
  );
  final tileData = PrefabTileFileData(
    tileSlices: const <AtlasSliceDef>[],
    platformModules: const <TileModuleDef>[],
  );
  final prefabDocument = PrefabV3Document(
    data: prefabData,
    tileData: tileData,
    visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
      'prefab_other': PrefabV3VisualBounds(widthPx: 10, heightPx: 10),
      'prefab_target': PrefabV3VisualBounds(widthPx: 10, heightPx: 10),
    },
    atlasImagePaths: const <String>['assets/test.png'],
    atlasImageSizes: const <String, Size>{'assets/test.png': Size(20, 10)},
    prefabBaselineContents: PrefabV3FileCodec.encode(prefabData),
    tileBaselineContents: PrefabTileFileCodec.encode(tileData),
  );
  final chunk = ChunkV2FileData(
    chunkKey: 'forest_chunk',
    id: 'forest_chunk',
    revision: 1,
    status: chunkStatusActive,
    levelId: 'forest',
    tileSize: 16,
    width: 100,
    height: 50,
    difficulty: chunkDifficultyNormal,
    assemblyGroupId: defaultChunkAssemblyGroupId,
    tags: const <String>[],
    tileLayers: const <TileLayerDef>[],
    prefabs: const <PlacedPrefabDef>[
      PlacedPrefabDef(
        prefabId: 'target',
        prefabKey: 'prefab_target',
        x: 20,
        y: 10,
      ),
    ],
    markers: const <PlacedMarkerDef>[],
    groundBandZIndex: 0,
    collisionShapes: const <TerrainSourceShapeDef>[],
  );
  final chunkDocument = ChunkV2Document(
    chunks: <ChunkV2FileData>[
      chunk.copyWith(chunkKey: 'aaa_chunk', id: 'aaa_chunk'),
      chunk,
    ],
    sourcePathByChunkKey: const <String, String>{
      'forest_chunk': 'chunks/forest_chunk.json',
      'aaa_chunk': 'chunks/aaa_chunk.json',
    },
    baselineContentsByChunkKey: <String, String>{
      'forest_chunk': ChunkV2FileCodec.encode(chunk),
      'aaa_chunk': ChunkV2FileCodec.encode(
        chunk.copyWith(chunkKey: 'aaa_chunk', id: 'aaa_chunk'),
      ),
    },
    prefabData: prefabData,
    tileData: tileData,
    visualBoundsByPrefabKey: prefabDocument.visualBoundsByPrefabKey,
    groundTopYByLevelId: const <String, double>{'forest': 40},
    levels: const <LevelDef>[_forestLevel],
    availableLevelIds: const <String>['forest'],
    activeLevelId: 'forest',
  );
  return _NavigationFixture(
    prefabDocument: prefabDocument,
    chunkDocument: chunkDocument,
    chunk: chunk,
  );
}

TerrainSourceShapeDef _collisionShape({int rightHalfPixels = 10}) =>
    TerrainSourceShapeDef(
      shapeId: 'collision_001',
      vertices: <TerrainSourceVertexDef>[
        const TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: rightHalfPixels, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: rightHalfPixels, yHalfPixels: 10),
        const TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 10),
      ],
    );

const LevelDef _forestLevel = LevelDef(
  levelId: 'forest',
  revision: 1,
  displayName: 'Forest',
  visualThemeId: 'forest',
  cameraCenterY: 25,
  groundTopY: 40,
  earlyPatternChunks: 0,
  easyPatternChunks: 0,
  normalPatternChunks: 0,
  noEnemyChunks: 0,
  enumOrdinal: 1,
  status: levelStatusActive,
);

final class _NavigationFixture {
  const _NavigationFixture({
    required this.prefabDocument,
    required this.chunkDocument,
    required this.chunk,
  });

  final PrefabV3Document prefabDocument;
  final ChunkV2Document chunkDocument;
  final ChunkV2FileData chunk;
}

final class _NavigationPrefabPlugin extends PrefabDomainPlugin {
  _NavigationPrefabPlugin(this.document);

  final PrefabV3Document document;
  int loadCount = 0;
  int normalLoadCount = 0;

  @override
  Future<PrefabV3Document> loadV3FromRepo(EditorWorkspace workspace) async {
    loadCount += 1;
    return document;
  }

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    normalLoadCount += 1;
    return document;
  }
}

final class _NavigationChunkPlugin implements AuthoringDomainPlugin {
  _NavigationChunkPlugin(this.document);

  ChunkV2Document document;
  static final ChunkDomainPlugin _delegate = ChunkDomainPlugin();

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

final class _NavigationEntitiesPlugin implements AuthoringDomainPlugin {
  @override
  String get id => EntityDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async =>
      const _NavigationDocument();

  @override
  List<ValidationIssue> validate(AuthoringDocument document) =>
      const <ValidationIssue>[];

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      const _NavigationScene();

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) => document;

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async => ExportResult(applied: false);

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => PendingChanges.empty;
}

final class _NavigationDocument extends AuthoringDocument {
  const _NavigationDocument();
}

final class _NavigationScene extends EditableScene {
  const _NavigationScene();
}
