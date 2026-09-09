import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_navigation.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_page.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

import 'test_support/chunk_level_fixture.dart';

void main() {
  testWidgets(
    'create, save, add undoable starter, save and return to exact Level',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workspace = (await tester.runAsync(createChunkLevelFixture))!;
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: [
            LevelDomainPlugin(),
            ChunkDomainPlugin(),
            ParallaxDomainPlugin(),
          ],
        ),
        initialPluginId: LevelDomainPlugin.pluginId,
        initialWorkspacePath: workspace.rootPath,
      );
      addTearDown(controller.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
      });
      await tester.pumpWidget(
        MaterialApp(home: EditorHomePage(controller: controller)),
      );
      await _drain(
        tester,
        () => find
            .byKey(const ValueKey('new_level_button'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('new_level_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new_level_name')),
        'Crystal Depths',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('create_level_button')),
      );
      await tester.tap(find.byKey(const ValueKey('create_level_button')));
      await tester.pumpAndSettle();
      final created = (controller.document! as LevelDefsDocument).levels
          .singleWhere((level) => level.displayName == 'Crystal Depths');
      expect(created.includeInBuild, isFalse);
      expect(controller.pendingChanges.hasChanges, isTrue);

      // The contextual handoff resolves the entire Level Save before creating
      // a Chunk-owned command. Both domains use their actual repository stores.
      await tester.ensureVisible(find.text('Add flat starter'));
      await tester.tap(find.text('Add flat starter'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Save all changes'));
      await _drain(
        tester,
        () =>
            controller.selectedPluginId == ChunkDomainPlugin.pluginId &&
            !controller.isLoading,
      );
      expect(controller.document, isA<ChunkV2Document>());
      final starter = (controller.document! as ChunkV2Document).chunks.single;
      expect(starter.levelId, created.levelId);
      expect(starter.collisionShapes, isNotEmpty);
      expect(controller.pendingChanges.hasChanges, isTrue);
      expect(controller.canUndo, isTrue);
      controller.undo();
      expect((controller.document! as ChunkV2Document).chunks, isEmpty);
      controller.redo();
      expect(
        (controller.document! as ChunkV2Document).chunks.single.chunkKey,
        starter.chunkKey,
      );
      await tester.pump();

      await tester.tap(find.text('Save and return to level'));
      await _drain(
        tester,
        () =>
            controller.selectedPluginId == LevelDomainPlugin.pluginId &&
            !controller.isLoading,
      );
      await _drain(
        tester,
        () => find
            .byKey(ValueKey('level_chunk_${starter.chunkKey}'))
            .evaluate()
            .isNotEmpty,
      );
      expect(
        (controller.document! as LevelDefsDocument).activeLevelId,
        created.levelId,
      );
      expect(controller.pendingChanges.hasChanges, isFalse);
      expect(
        find.byKey(ValueKey('level_chunk_${starter.chunkKey}')),
        findsOneWidget,
      );
      final files =
          Directory(workspace.resolve('assets/authoring/level/chunks'))
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.json'))
              .toList();
      expect(files, hasLength(1));
      final savedBytes = files.single.readAsBytesSync();

      // Repeating the reserved operation opens its saved target unchanged.
      final page = tester.widget<LevelCreatorPage>(
        find.byType(LevelCreatorPage),
      );
      final navigation = tester.state(
        find.byType(LevelCreatorPage),
      ) as LevelCreatorNavigationState;
      final request = page.onOpenChunk!(
        LevelCreatorChunkTarget(
          levelId: created.levelId,
          intent: LevelCreatorChunkIntent.flatStarter,
          returnContext: navigation.returnContext,
        ),
      );
      await _drain(
        tester,
        () =>
            controller.selectedPluginId == ChunkDomainPlugin.pluginId &&
            !controller.isLoading,
      );
      expect(await request, isTrue);
      expect(
        (controller.document! as ChunkV2Document).chunks.single.chunkKey,
        starter.chunkKey,
      );
      expect(controller.pendingChanges.hasChanges, isFalse);
      expect(files.single.readAsBytesSync(), savedBytes);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
    },
  );
}

Future<void> _drain(WidgetTester tester, bool Function() complete) async {
  for (var i = 0; i < 250; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (complete() &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      return;
    }
  }
  fail('Repository-backed editor transition did not complete.');
}
