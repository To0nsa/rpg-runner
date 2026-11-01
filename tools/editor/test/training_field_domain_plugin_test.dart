import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:tool_ui/tool_ui.dart';
import 'package:runner_editor/src/app/pages/trainingField/training_field_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/training/training_field_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  late Directory fixture;
  late EditorWorkspace workspace;
  late TrainingFieldDomainPlugin plugin;
  final repo = Directory.current.parent.parent.path;
  const sources = [
    trainingFieldSourcePath,
    'assets/authoring/level/prefab_defs.json',
    'assets/authoring/level/tile_defs.json',
    'assets/authoring/level/parallax_defs.json',
    'assets/authoring/level/terrain_material_defs.json',
  ];
  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('training_field_editor_');
    for (final path in sources) {
      final file = File('${fixture.path}/$path');
      await file.parent.create(recursive: true);
      await File('$repo/$path').copy(file.path);
    }
    final materialText = File('$repo/${sources.last}').readAsStringSync();
    for (final path in RegExp(
      r'assets/images/[^\"]+\.png',
    ).allMatches(materialText).map((m) => m.group(0)!).toSet()) {
      final target = File('${fixture.path}/$path');
      await target.parent.create(recursive: true);
      await File('$repo/$path').copy(target.path);
    }
    workspace = EditorWorkspace(rootPath: fixture.path);
    plugin = TrainingFieldDomainPlugin();
  });
  tearDown(() async {
    // Image.file can finish a pending read after its widget is unmounted.
    for (var attempt = 0; ; attempt++) {
      try {
        await fixture.delete(recursive: true);
        break;
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 32 || attempt >= 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });
  AuthoringCommand spawn(int x) => AuthoringCommand(
    kind: TrainingFieldDomainPlugin.setSpawns,
    payload: {'enemyX': x},
  );

  test(
    'clean load, no-op Save, independent write and dependency drift',
    () async {
      final original =
          await plugin.loadFromRepo(workspace) as TrainingFieldDocument;
      expect(plugin.validate(original), isEmpty);
      expect(
        plugin.describePendingChanges(workspace, document: original).hasChanges,
        isFalse,
      );
      expect(
        (await plugin.exportToRepo(workspace, document: original)).outcome,
        ExportOutcome.noChanges,
      );
      final edited = plugin.applyEdit(original, spawn(350));
      final before = {
        for (final path in sources)
          path: File(workspace.resolve(path)).readAsStringSync(),
      };
      final pending = plugin.describePendingChanges(
        workspace,
        document: edited,
      );
      expect(pending.fileDiffs.map((diff) => diff.relativePath), [
        trainingFieldSourcePath,
      ]);
      expect(
        (await plugin.exportToRepo(workspace, document: edited)).applied,
        isTrue,
      );
      for (final path in sources.skip(1)) {
        expect(File(workspace.resolve(path)).readAsStringSync(), before[path]);
      }
      final saved =
          await plugin.loadFromRepo(workspace) as TrainingFieldDocument;
      expect(saved.source.revision, original.source.revision + 1);
      expect(saved.source.enemySpawnX, 350);
      expect(
        plugin.describePendingChanges(workspace, document: saved).hasChanges,
        isFalse,
      );
      final targetBefore = File(workspace.resolve(trainingFieldSourcePath))
          .readAsStringSync();
      File(workspace.resolve(sources[1]))
          .writeAsStringSync('${before[sources[1]]}\n');
      final rejected = await plugin.exportToRepo(
        workspace,
        document: plugin.applyEdit(saved, spawn(400)),
      );
      expect(rejected.outcome, ExportOutcome.sourceDrift);
      expect(
        File(workspace.resolve(trainingFieldSourcePath)).readAsStringSync(),
        targetBefore,
      );
    },
  );
  test(
    'Save then Undo/Redo retains the current baseline and content history',
    () async {
      final session = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
        initialPluginId: plugin.id,
        initialWorkspacePath: fixture.path,
      );
      addTearDown(session.dispose);
      await session.loadWorkspace();
      session.applyCommand(spawn(350));
      await session.exportDirectWrite();
      expect(session.exportError, isNull);
      expect(session.pendingChanges.hasChanges, isFalse);
      session.undo();
      expect(
        (session.document as TrainingFieldDocument).source.enemySpawnX,
        300,
      );
      expect(session.pendingChanges.hasChanges, isTrue);
      session.redo();
      expect(
        (session.document as TrainingFieldDocument).source.enemySpawnX,
        350,
      );
      expect(session.pendingChanges.hasChanges, isFalse);
      session.undo();
      await session.exportDirectWrite();
      expect(session.exportError, isNull);
      expect((session.document as TrainingFieldDocument).source.revision, 3);
    },
  );
  test('invalid placement is saveable as a draft but blocks Build', () async {
    final original = await plugin.loadFromRepo(workspace);
    final invalid = plugin.applyEdit(
      original,
      AuthoringCommand(
        kind: TrainingFieldDomainPlugin.setSpawns,
        payload: {'enemyY': 200},
      ),
    );
    final issues = plugin.validate(invalid);
    expect(issues.any((i) => i.blocks(AuthoringOperation.build)), isTrue);
    expect(issues.any((i) => i.blocks(AuthoringOperation.save)), isFalse);
    expect(
      () => plugin.applyEdit(original, AuthoringCommand(kind: 'create_chunk')),
      throwsArgumentError,
    );
  });
  testWidgets(
    'dedicated page exposes layout and spawn positions only and saves visible input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1500, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
        initialPluginId: plugin.id,
        initialWorkspacePath: fixture.path,
      );
      addTearDown(session.dispose);
      await tester.runAsync(session.loadWorkspace);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: createToolTheme(),
          home: Scaffold(
            body: TrainingFieldPage(key: key, controller: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shortcuts = key.currentState! as EditorPageSessionShortcutHandler;
      expect(shortcuts.canHandleUndoSessionShortcut, isFalse);
      expect(shortcuts.canHandleRedoSessionShortcut, isFalse);
      expect(find.text('Chunk 1'), findsAtLeastNWidgets(1));
      expect(find.text('Chunk 2'), findsAtLeastNWidgets(1));
      expect(find.text('Spawn positions'), findsOneWidget);
      for (final forbidden in [
        'Encounters',
        'Markers',
        'Traps',
        'Camera behavior',
        'Enemy selection',
      ]) {
        expect(find.text(forbidden), findsNothing);
      }
      await tester.enterText(
        find.byKey(const ValueKey('training-spawn-2')),
        '350',
      );
      final page = key.currentState! as EditorPageSaveHandler;
      final result = await tester.runAsync(page.saveEditorPage);
      await tester.pumpAndSettle();
      expect(result, EditorPageSaveResult.saved);
      expect(
        (session.document as TrainingFieldDocument).source.enemySpawnX,
        350,
      );
      expect(session.pendingChanges.hasChanges, isFalse);
      expect(shortcuts.canHandleUndoSessionShortcut, isTrue);
      expect(shortcuts.handleUndoSessionShortcut(), isTrue);
      await tester.pumpAndSettle();
      expect(
        (session.document as TrainingFieldDocument).source.enemySpawnX,
        300,
      );
      expect(shortcuts.canHandleRedoSessionShortcut, isTrue);
      expect(shortcuts.handleRedoSessionShortcut(), isTrue);
      await tester.pumpAndSettle();
      expect(session.pendingChanges.hasChanges, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      // Drain file/decode completions in the test's fake-async zone before
      // Windows removes the temporary atlas files.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    },
  );
}
