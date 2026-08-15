import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

import 'test_support/entity_test_support.dart';

void main() {
  testWidgets('editor page renders collider table after load', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = buildEntitiesController();
    await _preloadController(tester, controller);

    await tester.pumpWidget(
      MaterialApp(home: EditorHomePage(controller: controller)),
    );

    await tester.pump();

    expect(find.text('No scene loaded.'), findsNothing);
    expect(find.text('Search Entries'), findsOneWidget);
    expect(find.byType(FilterChip), findsWidgets);
    expect(find.text('halfX'), findsWidgets);
  });

  testWidgets('caster scene exposes the authored cast origin cue', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = buildEntitiesController();
    await _preloadController(tester, controller);

    await tester.pumpWidget(
      MaterialApp(home: EditorHomePage(controller: controller)),
    );

    await tester.pump();

    expect(
      find.bySemanticsLabel(
        'Cast origin cue: 30.000 world units at 0 degrees from the entity '
        'transform.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cast preview angle'), findsOneWidget);
    final originPointCheckbox = find.byKey(
      const ValueKey('entity_scene_front_origin_point'),
    );
    expect(originPointCheckbox, findsOneWidget);
    await tester.tap(originPointCheckbox);
    await tester.pump();
    expect(tester.widget<Checkbox>(originPointCheckbox).value, isTrue);
    semantics.dispose();
  });
}

Future<void> _preloadController(
  WidgetTester tester,
  EditorSessionController controller,
) async {
  await tester.runAsync(controller.loadWorkspace);
  expect(controller.isLoading, isFalse);
  expect(controller.loadError, isNull);
}
