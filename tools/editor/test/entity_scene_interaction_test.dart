import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/entities/entities_editor_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';

import 'test_support/entity_test_support.dart';

void main() {
  testWidgets(
    'entity scene hit testing coalesces a cancelled pointer sequence',
    (WidgetTester tester) async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_widget_fixture_',
      );
      addTearDown(() {
        if (fixtureRoot.existsSync()) {
          fixtureRoot.deleteSync(recursive: true);
        }
      });
      writeEntityColliderFixture(fixtureRoot.path);
      final controller = buildEntitiesControllerForPath(fixtureRoot.path);
      addTearDown(controller.dispose);
      await tester.runAsync(controller.loadWorkspace);
      expect(controller.loadError, isNull);
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MaterialApp(home: EntitiesEditorPage(controller: controller)),
      );
      await tester.pump();
      final canvas = find.byKey(const ValueKey<String>('entity_scene_canvas'));
      expect(canvas, findsOneWidget);

      final miss = await tester.startGesture(
        tester.getTopLeft(canvas) + const Offset(30, 30),
      );
      await miss.moveBy(const Offset(20, 10));
      await miss.up();
      await tester.pump();
      expect(controller.canUndo, isFalse);

      final noMove = await tester.startGesture(tester.getCenter(canvas));
      await noMove.up();
      await tester.pump();
      expect(controller.canUndo, isFalse);

      final drag = await tester.startGesture(tester.getCenter(canvas));
      await drag.moveBy(const Offset(20, 10));
      await tester.pump();
      await drag.cancel();
      await tester.pump();

      final player = (controller.document! as EntityDocument).entries
          .singleWhere((entry) => entry.id == 'player.eloise');
      expect(player.offsetX, 20);
      expect(player.offsetY, 10);
      expect(controller.canUndo, isTrue);
      controller.undo();
      expect(controller.canUndo, isFalse);
      final restored = (controller.document! as EntityDocument).entries
          .singleWhere((entry) => entry.id == 'player.eloise');
      expect(restored.offsetX, 0);
      expect(restored.offsetY, 0);
    },
  );

  testWidgets('inspector draft rebases coherently across undo and redo', (
    WidgetTester tester,
  ) async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_widget_fixture_',
    );
    addTearDown(() {
      if (fixtureRoot.existsSync()) {
        fixtureRoot.deleteSync(recursive: true);
      }
    });
    writeEntityColliderFixture(fixtureRoot.path);
    final controller = buildEntitiesControllerForPath(fixtureRoot.path);
    addTearDown(controller.dispose);
    await tester.runAsync(controller.loadWorkspace);
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      MaterialApp(home: EntitiesEditorPage(controller: controller)),
    );
    await tester.pump();
    final pageState = tester.state(find.byType(EntitiesEditorPage));
    final draftState = pageState as EditorPageLocalDraftState;
    final halfXField = find.widgetWithText(TextField, 'halfX');

    await tester.enterText(halfXField, '12.50');
    await tester.pump();
    expect(draftState.hasLocalDraftChanges, isTrue);
    await tester.tap(find.text('Apply Values'));
    await tester.pump();
    expect(draftState.hasLocalDraftChanges, isFalse);
    expect(controller.canUndo, isTrue);

    controller.undo();
    await tester.pump();
    expect(tester.widget<TextField>(halfXField).controller!.text, '11.00');
    expect(draftState.hasLocalDraftChanges, isFalse);
    expect(controller.canRedo, isTrue);

    controller.redo();
    await tester.pump();
    expect(tester.widget<TextField>(halfXField).controller!.text, '12.50');
    expect(draftState.hasLocalDraftChanges, isFalse);
  });
}
