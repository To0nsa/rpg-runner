import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rpg_runner/playtest.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_page.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_navigation.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_content_projection.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/playtest/authored_playtest_preparation.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  late String root;
  late LevelContentProjection projection;
  setUpAll(() async {
    if (Platform.environment['LEVEL_EDITOR_SCREENSHOT_DIR'] != null) {
      final font = FontLoader('Roboto')
        ..addFont(
          File('C:/Windows/Fonts/segoeui.ttf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
    }
    root = p.normalize(p.absolute('..', '..'));
    projection = LevelContentProjection(
      document: await ChunkDomainPlugin().loadV2FromRepo(
        EditorWorkspace(rootPath: root),
      ),
    );
  });

  testWidgets(
    'Level Play captures focused edits and seed without saving and restores the same workspace',
    (tester) async {
      PlaytestPreparationInput? captured;
      PlaytestScenario? mountedScenario;
      VoidCallback? stop;
      final controller = await mount(
        tester,
        root,
        projection,
        runner: (input) async {
          captured = input;
          final prepared = preparePlaytest(input);
          expectSync(prepared.issues, isEmpty);
          return PlaytestPreparationResult.success(
            scenario: prepared.scenario!,
            appearance: prepared.appearance!,
            fingerprint: prepared.fingerprint!,
            warnings: ['Authored foreground is unsupported.'],
            assetBundle: RunnerCapturedAssetBundle({}),
          );
        },
        hostBuilder:
            ({
              required scenario,
              required controller,
              required assetBundle,
              required appearance,
              required onStop,
            }) {
              mountedScenario = scenario;
              stop = onStop;
              return const Material(child: Text('Captured level runtime'));
            },
      );
      final filesBefore = sourceContents(root);
      if (Platform.environment['LEVEL_EDITOR_SCREENSHOT_DIR'] != null) {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        await captureIfRequested(tester, 'level-workspace-wide');
        await tester.binding.setSurfaceSize(const Size(980, 720));
        await captureIfRequested(tester, 'level-workspace-compact');
        await tester.binding.setSurfaceSize(const Size(1800, 1200));
        await tester.pump();
      }
      final page = tester.state(find.byType(LevelCreatorPage));
      final preview = tester.element(
        find.byKey(const ValueKey('level_persistent_preview')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('level_preview_seed')),
        '7531',
      );
      await tester.enterText(
        find.byKey(const ValueKey('level_input_displayName')),
        'Focused Forest Play',
      );
      final handler = page as EditorPagePlaytestHandler;
      expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.f5), isTrue);
      expect(handler.locksEditorShell, isTrue);
      expect((page as EditorPageSaveHandler).canSaveEditorPage, isFalse);
      await until(
        tester,
        () => find.text('Captured level runtime').evaluate().isNotEmpty,
      );
      expect(captured!.level.displayName, 'Focused Forest Play');
      expect(find.textContaining('Play level — seeded run'), findsOneWidget);
      expect(captured!.seed, 7531);
      expect(captured!.selectedChunkKey, isNull);
      expect(mountedScenario, isA<LevelPlaytestScenario>());
      expect(find.text('Authored foreground is unsupported.'), findsOneWidget);
      expect(controller.pendingChanges.hasChanges, isTrue);
      expect(controller.lastExportResult, isNull);
      expect(sourceContents(root), filesBefore);
      stop!();
      await tester.pump();
      expect(handler.locksEditorShell, isFalse);
      expect(
        identical(page, tester.state(find.byType(LevelCreatorPage))),
        isTrue,
      );
      expect(
        identical(
          preview,
          tester.element(
            find.byKey(const ValueKey('level_persistent_preview')),
          ),
        ),
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('level_input_displayName')),
            )
            .controller!
            .text,
        'Focused Forest Play',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('level_preview_seed')))
            .controller!
            .text,
        '7531',
      );
    },
  );

  testWidgets(
    'invalid pacing remains exact and does not start Level preparation',
    (tester) async {
      var preparations = 0;
      await mount(
        tester,
        root,
        projection,
        runner: (_) async {
          preparations++;
          return PlaytestPreparationResult.failure(const []);
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('level_input_earlyPatternChunks')),
        '-',
      );
      final handler = tester.state(
        find.byType(LevelCreatorPage),
      ) as EditorPagePlaytestHandler;
      expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.f5), isFalse);
      await tester.pump();
      expect(handler.locksEditorShell, isFalse);
      expect(preparations, 0);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('level_input_earlyPatternChunks')),
            )
            .controller!
            .text,
        '-',
      );
    },
  );

  testWidgets(
    'sample preview displays the real first12 Core choices and variation seed',
    (tester) async {
      final capturedSeeds = <int>[];
      await mount(
        tester,
        root,
        projection,
        runner: (input) async {
          capturedSeeds.add(input.seed);
          return preparePlaytest(input);
        },
      );
      await tester.tap(find.byKey(const ValueKey('level_sample_button')));
      await until(
        tester,
        () =>
            find.byKey(const ValueKey('level_sample_0')).evaluate().isNotEmpty,
      );
      expect(find.textContaining('First 12 chunks'), findsOneWidget);
      expect(find.textContaining('seed 4401'), findsOneWidget);
      expect(find.textContaining('Source:'), findsWidgets);
      expect(capturedSeeds, [4401]);
      await tester.tap(find.byKey(const ValueKey('level_new_variation')));
      await until(
        tester,
        () =>
            capturedSeeds.length == 2 &&
            find.textContaining('seed 4402').evaluate().isNotEmpty,
      );
      expect(capturedSeeds, [4401, 4402]);
      expect(
        (tester.state(
          find.byType(LevelCreatorPage),
        ) as EditorPagePlaytestHandler).locksEditorShell,
        isFalse,
      );
    },
  );

  testWidgets('canceled Level preparation ignores a late completion', (
    tester,
  ) async {
    final completion = Completer<PlaytestPreparationResult>();
    var started = false;
    await mount(
      tester,
      root,
      projection,
      runner: (_) {
        started = true;
        return completion.future;
      },
    );
    final handler = tester.state(
      find.byType(LevelCreatorPage),
    ) as EditorPagePlaytestHandler;
    handler.handlePlaytestShortcut(LogicalKeyboardKey.f5);
    await until(tester, () => started);
    expect(find.text('Preparing level playtest'), findsOneWidget);
    expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.escape), isTrue);
    completion.complete(
      PlaytestPreparationResult.failure(const [
        PlaytestPreparationIssue(code: 'late', message: 'Late error'),
      ]),
    );
    await tester.pump();
    expect(handler.locksEditorShell, isFalse);
    expect(find.textContaining('Late error'), findsNothing);
  });
}

Future<EditorSessionController> mount(
  WidgetTester tester,
  String root,
  LevelContentProjection projection, {
  required PlaytestPreparationRunner runner,
  Widget Function({
    required PlaytestScenario scenario,
    required RunnerPlaytestController controller,
    required AssetBundle assetBundle,
    required RunnerPlaytestAppearance appearance,
    required VoidCallback onStop,
  })?
  hostBuilder,
}) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(plugins: [LevelDomainPlugin()]),
    initialPluginId: LevelDomainPlugin.pluginId,
    initialWorkspacePath: root,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF0EA5E9),
        ),
      ),
      home: RepaintBoundary(
        key: const ValueKey('level_workspace_raster'),
        child: Scaffold(
          body: LevelCreatorPage(
            viewStore: null,
            controller: controller,
            contentLoader: (_) async => projection,
            initialReturnContext: const LevelCreatorReturnContext(
              levelId: 'forest',
            ),
            playtestPlatformSupported: true,
            preparationRunner: runner,
            playtestHostBuilder:
                hostBuilder ??
                ({
                  required scenario,
                  required controller,
                  required assetBundle,
                  required appearance,
                  required onStop,
                }) => const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await until(
    tester,
    () =>
        controller.scene is LevelScene &&
        find.byKey(const ValueKey('level_play_button')).evaluate().isNotEmpty &&
        tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('level_play_button')),
                )
                .onPressed !=
            null,
  );
  return controller;
}

Future<void> until(WidgetTester tester, bool Function() done) async {
  for (var index = 0; index < 200; index++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (done()) return;
  }
  fail(
    'The Level workspace did not reach the expected state: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join('\n')}',
  );
}

Map<String, String> sourceContents(String root) => {
  for (final path in [
    'assets/authoring/level/level_defs.json',
    'assets/authoring/level/parallax_defs.json',
  ])
    path: File(p.join(root, path)).readAsStringSync(),
};

Future<void> captureIfRequested(WidgetTester tester, String name) async {
  final output = Platform.environment['LEVEL_EDITOR_SCREENSHOT_DIR'];
  if (output == null) return;
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('level_workspace_raster')),
    );
    final raster = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await raster.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(output);
      await directory.create(recursive: true);
      await File(p.join(output, '$name.png'))
          .writeAsBytes(data!.buffer.asUint8List());
    } finally {
      raster.dispose();
    }
  });
}
