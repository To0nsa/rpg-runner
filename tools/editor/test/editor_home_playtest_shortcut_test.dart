import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_authoring_workspace.dart';
import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/app/pages/shared/editor_zoom_controls.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets(
    'Home routes only unmodified unowned F5 and locks shell during Play',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: <AuthoringDomainPlugin>[
            _UnavailablePlugin(EntityDomainPlugin.pluginId),
            _MemoryChunkPlugin(_document()),
          ],
        ),
        initialPluginId: EntityDomainPlugin.pluginId,
        initialWorkspacePath: '.',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: EditorHomePage(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHUNK CREATOR').last);
      await tester.pumpAndSettle();

      expect(find.byType(ChunkAuthoringWorkspace), findsOneWidget);
      final playButton = find.byKey(
        const ValueKey<String>('chunk_playtest_button'),
      );
      expect(tester.widget<FilledButton>(playButton).onPressed, isNotNull);

      final zoomField = find.descendant(
        of: find.byType(EditorZoomControls),
        matching: find.byType(TextField),
      );
      await tester.tap(zoomField);
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(_playtestHandler(tester).locksEditorShell, isFalse);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_playtestHandler(tester).locksEditorShell, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_owner_edit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit forest_early_00 metadata'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(find.text('Edit forest_early_00 metadata'), findsOneWidget);
      expect(_playtestHandler(tester).locksEditorShell, isFalse);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(_playtestHandler(tester).locksEditorShell, isTrue);
      debugDefaultTargetPlatformOverride = null;
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byType(DropdownButton<String>).first,
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('reload_editor_page_button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('apply_editor_page_button')),
            )
            .onPressed,
        isNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      await tester.pump();
      expect(_playtestHandler(tester).locksEditorShell, isFalse);
      expect(find.byType(ChunkAuthoringWorkspace), findsOneWidget);
    },
  );
}

EditorPagePlaytestHandler _playtestHandler(WidgetTester tester) =>
    tester.state(find.byType(ChunkCreatorPage)) as EditorPagePlaytestHandler;

ChunkV2Document _document() {
  final chunk = ChunkV2FileData(
    chunkKey: 'forest_early_00',
    id: 'forest_early_00',
    revision: 1,
    status: chunkStatusActive,
    levelId: 'forest',
    tileSize: 16,
    width: 100,
    height: 50,
    difficulty: chunkDifficultyNormal,
    assemblyGroupId: defaultChunkAssemblyGroupId,
    tags: const <String>['forest'],
    tileLayers: const [],
    prefabs: const [],
    markers: const [],
    groundBandZIndex: 0,
    collisionShapes: <TerrainSourceShapeDef>[
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
  return ChunkV2Document(
    chunks: <ChunkV2FileData>[chunk],
    sourcePathByChunkKey: const <String, String>{
      'forest_early_00': 'chunks/forest_early_00.json',
    },
    baselineContentsByChunkKey: <String, String>{
      chunk.chunkKey: ChunkV2FileCodec.encode(chunk),
    },
    prefabData: PrefabV3FileData(slices: const [], prefabs: const []),
    tileData: PrefabTileFileData(
      tileSlices: const [],
      platformModules: const [],
    ),
    visualBoundsByPrefabKey: const {},
    groundTopYByLevelId: const <String, double>{'forest': 10},
    levels: const <LevelDef>[
      LevelDef(
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
      ),
    ],
    availableLevelIds: const <String>['forest'],
    activeLevelId: 'forest',
  );
}

final class _MemoryChunkPlugin implements AuthoringDomainPlugin {
  _MemoryChunkPlugin(this.document);

  final ChunkV2Document document;
  final ChunkDomainPlugin _delegate = ChunkDomainPlugin();

  @override
  String get id => ChunkDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async =>
      document;

  @override
  List<ValidationIssue> validate(AuthoringDocument document) => const [];

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      _delegate.buildEditableScene(document);

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) => _delegate.applyEdit(document, command);

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => _delegate.describePendingChanges(workspace, document: document);

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => _delegate.exportToRepo(workspace, document: document);
}

final class _UnavailablePlugin implements AuthoringDomainPlugin {
  const _UnavailablePlugin(this.id);

  @override
  final String id;

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) => document;

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      const _UnavailableScene();

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => PendingChanges.empty;

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async => ExportResult(applied: false);

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async =>
      const _UnavailableDocument();

  @override
  List<ValidationIssue> validate(AuthoringDocument document) => const [];
}

final class _UnavailableDocument extends AuthoringDocument {
  const _UnavailableDocument();
}

final class _UnavailableScene extends EditableScene {
  const _UnavailableScene();
}
