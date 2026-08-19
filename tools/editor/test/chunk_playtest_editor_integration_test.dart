import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rpg_runner/playtest.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_authoring_workspace.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_coordinator.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_metadata_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/playtest/chunk_playtest_preparation.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  late String workspaceRoot;
  late ui.Image fixtureImage;
  late ChunkPlaytestScenario repositoryScenario;

  setUpAll(() async {
    workspaceRoot = p.normalize(
      p.absolute(p.join(Directory.current.path, '..', '..')),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0x00000000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    fixtureImage = await picture.toImage(2048, 2048);
    picture.dispose();
    final repositoryDocument = await ChunkDomainPlugin().loadV2FromRepo(
      EditorWorkspace(rootPath: workspaceRoot),
    );
    final prepared = prepareChunkPlaytest(
      captureChunkPlaytestPreparationInput(
        document: repositoryDocument,
        selectedChunkKey: 'forest_early_00',
      ),
    );
    repositoryScenario = prepared.scenario!;
  });

  tearDownAll(() => fixtureImage.dispose());

  testWidgets(
    'accepted pending snapshot plays and restores the exact Edit projection',
    (tester) async {
      final session = await _loadedSession(workspaceRoot);
      addTearDown(session.dispose);
      _stageAcceptedPendingChange(session);
      final documentBefore = session.document;
      final pendingBefore = session.pendingChanges;
      final canUndoBefore = session.canUndo;
      final filesBefore = _sourceHashes(workspaceRoot);
      var shellNotifications = 0;
      ChunkPlaytestPreparationInput? capturedInput;

      await _mountPage(
        tester,
        session: session,
        fixtureImage: fixtureImage,
        onShellStateChanged: () => shellNotifications += 1,
        preparationRunner: (input) async {
          capturedInput = input;
          return ChunkPlaytestPreparationResult.success(repositoryScenario);
        },
      );

      final workspaceFinder = find.byType(
        ChunkAuthoringWorkspace,
        skipOffstage: false,
      );
      final workspaceBefore = tester.state<ChunkAuthoringWorkspaceState>(
        workspaceFinder,
      );
      final selectedOwner = workspaceBefore.selectedChunkKey;
      expect(session.pendingChanges.hasChanges, isTrue);
      expect(workspaceBefore.playtestReadiness.isReady, isTrue);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_show_grid_toggle')),
      );
      final domainSelector = tester.widget<SegmentedButton<ChunkSceneDomain>>(
        find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
      );
      domainSelector.onSelectionChanged!(<ChunkSceneDomain>{
        ChunkSceneDomain.prefabs,
      });
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_playtest_button')),
      );
      await tester.pump();
      final pageHandler = _pageHandler(tester);
      expect(pageHandler.locksEditorShell, isTrue);
      expect(
        find.byType(ChunkAuthoringWorkspace, skipOffstage: false),
        findsOneWidget,
      );
      await _pumpUntilHostPhase(tester, RunnerChunkPlaytestPhase.ready);
      expect(capturedInput!.chunkContents, contains('phase5_pending'));

      final host = tester.widget<RunnerChunkPlaytestHost>(
        find.byType(RunnerChunkPlaytestHost),
      );
      expect(
        pageHandler.handlePlaytestShortcut(LogicalKeyboardKey.enter),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(host.controller.status.phase, RunnerChunkPlaytestPhase.running);

      final firstGeneration = host.controller.status.runtimeGeneration;
      expect(pageHandler.handlePlaytestShortcut(LogicalKeyboardKey.f6), isTrue);
      expect(host.controller.status.runtimeGeneration, firstGeneration + 1);
      await _pumpUntilHostPhase(tester, RunnerChunkPlaytestPhase.ready);
      expect(
        pageHandler.handlePlaytestShortcut(LogicalKeyboardKey.enter),
        isTrue,
      );
      await tester.pump();
      expect(
        pageHandler.handlePlaytestShortcut(LogicalKeyboardKey.keyP),
        isTrue,
      );
      expect(host.controller.status.phase, RunnerChunkPlaytestPhase.paused);
      expect(
        pageHandler.handlePlaytestShortcut(LogicalKeyboardKey.keyP),
        isTrue,
      );
      await tester.pump();
      pageHandler.handlePlaytestAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();
      expect(host.controller.status.phase, RunnerChunkPlaytestPhase.paused);

      expect(
        pageHandler.handlePlaytestShortcut(LogicalKeyboardKey.escape),
        isTrue,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(RunnerChunkPlaytestHost), findsNothing);
      expect(_pageHandler(tester).locksEditorShell, isFalse);
      final workspaceAfter = tester.state<ChunkAuthoringWorkspaceState>(
        workspaceFinder,
      );
      expect(workspaceAfter, same(workspaceBefore));
      expect(workspaceAfter.selectedChunkKey, selectedOwner);
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey<String>('chunk_show_grid_toggle')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<SegmentedButton<ChunkSceneDomain>>(
              find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
            )
            .selected,
        <ChunkSceneDomain>{ChunkSceneDomain.prefabs},
      );
      expect(session.document, same(documentBefore));
      expect(session.pendingChanges.fileDiffs, pendingBefore.fileDiffs);
      expect(
        session.pendingChanges.changedItemIds,
        pendingBefore.changedItemIds,
      );
      expect(session.canUndo, canUndoBefore);
      expect(shellNotifications, greaterThanOrEqualTo(2));
      expect(_sourceHashes(workspaceRoot), filesBefore);
    },
  );

  testWidgets('canceled preparation ignores its stale successful result', (
    tester,
  ) async {
    final session = await _loadedSession(workspaceRoot);
    addTearDown(session.dispose);
    final completer = Completer<ChunkPlaytestPreparationResult>();
    await _mountPage(
      tester,
      session: session,
      fixtureImage: fixtureImage,
      preparationRunner: (_) => completer.future,
    );
    final workspaceFinder = find.byType(
      ChunkAuthoringWorkspace,
      skipOffstage: false,
    );
    final workspaceState = tester.state<ChunkAuthoringWorkspaceState>(
      workspaceFinder,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_playtest_button')),
    );
    await tester.pump();
    expect(find.text('Preparing chunk playtest'), findsOneWidget);
    expect(_pageHandler(tester).locksEditorShell, isTrue);

    expect(
      _pageHandler(tester).handlePlaytestShortcut(LogicalKeyboardKey.escape),
      isTrue,
    );
    await tester.pump();
    expect(_pageHandler(tester).locksEditorShell, isFalse);
    completer.complete(
      ChunkPlaytestPreparationResult.success(repositoryScenario),
    );
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.byType(RunnerChunkPlaytestHost), findsNothing);
    expect(
      tester.state<ChunkAuthoringWorkspaceState>(workspaceFinder),
      same(workspaceState),
    );
  });

  testWidgets('preparation failure is retryable with the same captured input', (
    tester,
  ) async {
    final session = await _loadedSession(workspaceRoot);
    addTearDown(session.dispose);
    var attempts = 0;
    await _mountPage(
      tester,
      session: session,
      fixtureImage: fixtureImage,
      preparationRunner: (input) async {
        attempts += 1;
        if (attempts == 1) {
          return ChunkPlaytestPreparationResult.failure(
            const <ChunkPlaytestPreparationIssue>[
              ChunkPlaytestPreparationIssue(
                code: 'fixture_blocked',
                message: 'Deliberate preparation failure.',
              ),
            ],
          );
        }
        return ChunkPlaytestPreparationResult.success(repositoryScenario);
      },
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_playtest_button')),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Chunk playtest could not start'), findsOneWidget);
    expect(find.textContaining('fixture_blocked'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_playtest_retry_button')),
    );
    await tester.pump();
    await _pumpUntilHostPhase(tester, RunnerChunkPlaytestPhase.ready);
    expect(attempts, 2);

    _pageHandler(tester).handlePlaytestShortcut(LogicalKeyboardKey.f5);
    await tester.pump();
    await tester.pump();
  });

  testWidgets('platform and active local draft block button and F5 equally', (
    tester,
  ) async {
    final session = await _loadedSession(workspaceRoot);
    addTearDown(session.dispose);
    await _mountPage(
      tester,
      session: session,
      fixtureImage: fixtureImage,
      playtestPlatformSupported: false,
    );
    var playButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('chunk_playtest_button')),
    );
    expect(playButton.onPressed, isNull);
    expect(
      _pageHandler(tester).handlePlaytestShortcut(LogicalKeyboardKey.f5),
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _mountPage(
      tester,
      session: session,
      fixtureImage: fixtureImage,
      playtestPlatformSupported: true,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_polygon_new_shape')),
    );
    await tester.pump();
    playButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('chunk_playtest_button')),
    );
    expect(playButton.onPressed, isNull);
    expect(
      _pageHandler(tester).handlePlaytestShortcut(LogicalKeyboardKey.f5),
      isFalse,
    );
    expect(find.textContaining('Finish, save, or cancel'), findsOneWidget);
  });
}

Future<EditorSessionController> _loadedSession(String workspaceRoot) async {
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
  const level = LevelDef(
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
  final document = ChunkV2Document(
    chunks: <ChunkV2FileData>[chunk],
    sourcePathByChunkKey: const <String, String>{
      'forest_early_00':
          'assets/authoring/level/chunks/forest/forest_early_00.json',
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
    levels: const <LevelDef>[level],
    parallaxThemes: const [],
    availableLevelIds: const <String>['forest'],
    activeLevelId: 'forest',
  );
  final controller = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[_MemoryChunkPlugin(document)],
    ),
    initialPluginId: ChunkDomainPlugin.pluginId,
    initialWorkspacePath: workspaceRoot,
  );
  await controller.loadWorkspace();
  return controller;
}

void _stageAcceptedPendingChange(EditorSessionController session) {
  session.applyCommand(
    AuthoringCommand(
      kind: 'set_active_level',
      payload: <String, Object?>{'levelId': 'forest'},
    ),
  );
  final document = session.document! as ChunkV2Document;
  final chunk = document.chunks.singleWhere(
    (candidate) => candidate.chunkKey == 'forest_early_00',
  );
  final before = ChunkV2MetadataSnapshot.fromChunk(chunk);
  final tags = <String>[...before.tags, 'phase5_pending']..sort();
  session.applyCommand(
    AuthoringCommand(
      kind: ChunkDomainPlugin.commitChunkMetadataCommandKind,
      payload: <String, Object?>{
        'chunkKey': chunk.chunkKey,
        'commit': ChunkV2MetadataCommit(
          before: before,
          after: ChunkV2MetadataSnapshot(
            status: before.status,
            levelId: before.levelId,
            difficulty: before.difficulty,
            assemblyGroupId: before.assemblyGroupId,
            tags: tags,
            groundBandZIndex: before.groundBandZIndex,
          ),
        ),
      },
    ),
  );
}

Future<void> _mountPage(
  WidgetTester tester, {
  required EditorSessionController session,
  required ui.Image fixtureImage,
  ChunkPlaytestPreparationRunner preparationRunner =
      prepareChunkPlaytestInBackground,
  bool playtestPlatformSupported = true,
  VoidCallback? onShellStateChanged,
}) async {
  tester.view.physicalSize = const Size(1800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: ChunkCreatorPage(
          controller: session,
          onShellStateChanged: onShellStateChanged,
          playtestPlatformSupported: playtestPlatformSupported,
          preparationRunner: preparationRunner,
          playtestHostBuilder:
              ({
                required scenario,
                required controller,
                required assetBundle,
                required onStop,
              }) => RunnerChunkPlaytestHost(
                scenario: scenario,
                controller: controller,
                assetBundle: assetBundle,
                imagesFactory: (_) => _FixtureImages(fixtureImage),
                onStop: onStop,
              ),
        ),
      ),
    ),
  );
}

EditorPagePlaytestHandler _pageHandler(WidgetTester tester) =>
    tester.state(find.byType(ChunkCreatorPage)) as EditorPagePlaytestHandler;

Future<void> _pumpUntilHostPhase(
  WidgetTester tester,
  RunnerChunkPlaytestPhase phase,
) async {
  for (var attempt = 0; attempt < 240; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    final hostFinder = find.byType(RunnerChunkPlaytestHost);
    if (hostFinder.evaluate().isEmpty) continue;
    final controller = tester
        .widget<RunnerChunkPlaytestHost>(hostFinder)
        .controller;
    if (controller.status.phase == phase) {
      await tester.pump();
      return;
    }
  }
  fail('Timed out waiting for editor host phase ${phase.name}.');
}

Map<String, String> _sourceHashes(String workspaceRoot) {
  const paths = <String>[
    'assets/authoring/level/prefab_defs.json',
    'assets/authoring/level/tile_defs.json',
    'assets/authoring/level/chunks/forest/forest_early_00.json',
    'packages/runner_core/lib/track/authored_chunk_patterns.dart',
    'packages/runner_core/lib/track/staged_authored_terrain.dart',
    'lib/game/themes/authored_parallax_themes.dart',
    'lib/game/themes/authored_terrain_materials.dart',
  ];
  return <String, String>{
    for (final path in paths)
      path: sha256
          .convert(File(p.join(workspaceRoot, path)).readAsBytesSync())
          .toString(),
  };
}

final class _FixtureImages extends Images {
  _FixtureImages(this.image);

  final ui.Image image;

  @override
  Future<ui.Image> load(
    String fileName, {
    String? key,
    String? package,
  }) async => image;

  @override
  void clearCache() {}
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
