import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/prefab_creator_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets(
    'explicit staging route isolates owners and commits half-pixel polygons',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: PrefabCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('prefab_polygon_staging_workspace')),
        findsOneWidget,
      );
      expect(find.text('Save Definitions'), findsNothing);
      final lockedApply = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('prefab_polygon_apply_locked')),
      );
      expect(lockedApply.onPressed, isNull);

      final closeDraftFinder = find.byKey(
        const ValueKey<String>('prefab_polygon_close_draft'),
      );
      expect(tester.widget<OutlinedButton>(closeDraftFinder).onPressed, isNull);
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
      );
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(closeDraftFinder).onPressed,
        isNotNull,
      );
      final routeState = tester.state(find.byType(PrefabCreatorPage));
      final localDraftState = routeState as EditorPageLocalDraftState;
      final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
      expect(localDraftState.hasLocalDraftChanges, isTrue);
      expect(shortcutHandler.canHandleUndoSessionShortcut, isTrue);
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
      expect(tester.widget<OutlinedButton>(closeDraftFinder).onPressed, isNull);
      expect(harness.session.canUndo, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_owner_platform')),
      );
      await tester.pump();
      expect(tester.widget<OutlinedButton>(closeDraftFinder).onPressed, isNull);
      expect(find.textContaining('platform_module:module_a'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_owner_obstacle')),
      );
      await tester.pump();
      await tester.tap(find.text('0.5 px'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
      );
      await tester.pump();

      final surface = find.byKey(
        const ValueKey<String>('prefab_polygon_scene_surface'),
      );
      final center = tester.getCenter(surface);
      await tester.tapAt(center + const Offset(22, 22));
      await tester.tapAt(center + const Offset(34, 22));
      await tester.tapAt(center + const Offset(22, 34));
      await tester.pump();
      await tester.tap(closeDraftFinder);
      await tester.pump();

      var obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 2);
      expect(obstacle.collisionShapes, hasLength(2));
      expect(
        obstacle.collisionShapes
            .singleWhere((shape) => shape.shapeId == 'collision_002')
            .vertices
            .first
            .xHalfPixels,
        11,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_undo_button')),
      );
      await tester.pump();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 1);
      expect(obstacle.collisionShapes, hasLength(1));

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_redo_button')),
      );
      await tester.pump();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 2);

      final diagnostic = find.text(
        'prefab_collision_shape_outside_visual_bounds',
      );
      await tester.ensureVisible(diagnostic);
      await tester.tap(diagnostic);
      await tester.pump();
      final shapeTile = tester.widget<ListTile>(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('prefab_polygon_shape_collision_001'),
          ),
          matching: find.byType(ListTile),
        ),
      );
      expect(shapeTile.selected, isTrue);

      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'obstacle',
      ]);
      expect(harness.session.exportError, isNull);
    },
  );
}

Future<_Harness> _buildHarness() async {
  final root = Directory.systemTemp.createTempSync('prefab_stage_page_');
  final document = _stagingDocument();
  final session = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[_StagingPrefabPlugin(document)],
    ),
    initialPluginId: PrefabDomainPlugin.pluginId,
    initialWorkspacePath: root.path,
  );
  await session.loadWorkspace();
  return _Harness(root: root, session: session);
}

PrefabV3StagingDocument _stagingDocument() {
  final data = PrefabV3FileData(
    slices: const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'obstacle_slice',
        sourceImagePath: 'assets/obstacles.png',
        x: 0,
        y: 0,
        width: 20,
        height: 20,
      ),
      AtlasSliceDef(
        id: 'decoration_slice',
        sourceImagePath: 'assets/decorations.png',
        x: 0,
        y: 0,
        width: 12,
        height: 12,
      ),
    ],
    prefabs: <PrefabV3Def>[
      PrefabV3Def(
        prefabKey: 'obstacle',
        id: 'obstacle',
        revision: 1,
        status: PrefabStatus.active,
        kind: PrefabKind.obstacle,
        visualSource: const PrefabVisualSource.atlasSlice('obstacle_slice'),
        anchorXPx: 10,
        anchorYPx: 10,
        collisionShapes: <TerrainSourceShapeDef>[_outsideRectangle()],
        tags: const <String>['test'],
      ),
      PrefabV3Def(
        prefabKey: 'platform',
        id: 'platform',
        revision: 1,
        status: PrefabStatus.active,
        kind: PrefabKind.platform,
        visualSource: const PrefabVisualSource.platformModule('module_a'),
        anchorXPx: 8,
        anchorYPx: 8,
        collisionShapes: <TerrainSourceShapeDef>[_smallRectangle()],
        tags: const <String>[],
      ),
      PrefabV3Def(
        prefabKey: 'decoration',
        id: 'decoration',
        revision: 1,
        status: PrefabStatus.active,
        kind: PrefabKind.decoration,
        visualSource: const PrefabVisualSource.atlasSlice('decoration_slice'),
        anchorXPx: 6,
        anchorYPx: 6,
        collisionShapes: const <TerrainSourceShapeDef>[],
        tags: const <String>[],
      ),
    ],
  );
  return PrefabV3StagingDocument(
    data: data,
    tileData: PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[
        AtlasSliceDef(
          id: 'tile_a',
          sourceImagePath: 'assets/tiles.png',
          x: 0,
          y: 0,
          width: 16,
          height: 16,
        ),
      ],
      platformModules: const <TileModuleDef>[
        TileModuleDef(
          id: 'module_a',
          tileSize: 16,
          cells: <TileModuleCellDef>[
            TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
          ],
        ),
      ],
    ),
    visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
      'obstacle': PrefabV3VisualBounds(widthPx: 20, heightPx: 20),
      'platform': PrefabV3VisualBounds(widthPx: 16, heightPx: 16),
      'decoration': PrefabV3VisualBounds(widthPx: 12, heightPx: 12),
    },
    atlasImagePaths: const <String>[],
    atlasImageSizes: const <String, Size>{},
    prefabBaselineContents: PrefabV3FileCodec.encode(data),
    tileBaselineContents: null,
  );
}

PrefabV3Def _prefab(EditorSessionController session, String prefabKey) {
  final document = session.document! as PrefabV3StagingDocument;
  return document.data.prefabs.singleWhere(
    (prefab) => prefab.prefabKey == prefabKey,
  );
}

TerrainSourceShapeDef _outsideRectangle() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -24, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: -24, yHalfPixels: 8),
  ],
);

TerrainSourceShapeDef _smallRectangle() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: 8),
  ],
);

final class _Harness {
  const _Harness({required this.root, required this.session});

  final Directory root;
  final EditorSessionController session;

  void dispose() {
    session.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
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
