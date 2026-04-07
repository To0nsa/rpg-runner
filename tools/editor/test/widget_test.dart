import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';

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

    await tester.pumpWidget(
      MaterialApp(home: EditorHomePage(controller: controller)),
    );

    await tester.pumpAndSettle();

    expect(find.text('No scene loaded.'), findsNothing);
    expect(find.text('Search Entries'), findsOneWidget);
    expect(find.byType(FilterChip), findsWidgets);
    expect(find.text('halfX'), findsWidgets);
  });
}
