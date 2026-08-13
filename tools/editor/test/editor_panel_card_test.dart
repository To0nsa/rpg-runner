import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/editor_panel_card.dart';
import 'package:runner_editor/src/app/pages/shared/editor_section_card.dart';
import 'package:runner_editor/src/app/pages/shared/editor_list_card.dart';
import 'package:runner_editor/src/app/pages/shared/editor_workspace_card.dart';

void main() {
  testWidgets('collapsible panel removes only its body and reports changes', (
    tester,
  ) async {
    final expansionChanges = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPanelCard(
            title: 'Shapes',
            description: 'Direct terrain source.',
            collapsible: true,
            expansionKey: const ValueKey<String>('shapes_toggle'),
            onExpansionChanged: expansionChanges.add,
            child: const Text('shape body', key: ValueKey<String>('body')),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('body')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('shapes_toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('body')), findsNothing);
    expect(expansionChanges, <bool>[false]);

    await tester.tap(find.byKey(const ValueKey<String>('shapes_toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('body')), findsOneWidget);
    expect(expansionChanges, <bool>[false, true]);
  });

  testWidgets('expanded panel gives its body the remaining bounded height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: EditorPanelCard(
              title: 'Scene',
              bodyMode: EditorPanelBodyMode.expanded,
              child: ColoredBox(
                key: ValueKey<String>('expanded_body'),
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('expanded_body')))
          .height,
      greaterThan(150),
    );
  });

  testWidgets('collapsible section keeps natural height and trailing action', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorSectionCard(
            title: 'Markers',
            collapsible: true,
            expansionKey: const ValueKey<String>('markers_toggle'),
            trailing: IconButton(
              onPressed: () => actions += 1,
              icon: const Icon(Icons.add),
            ),
            child: const Text(
              'marker rows',
              key: ValueKey<String>('marker_rows'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    expect(actions, 1);
    expect(find.byKey(const ValueKey<String>('marker_rows')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('markers_toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('marker_rows')), findsNothing);
  });

  testWidgets('shared section and selectable cards preserve their slots', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const EditorSectionCard(
                title: 'Metadata',
                description: 'Shape semantics.',
                child: Text('fields'),
              ),
              EditorListCard(
                isSelected: true,
                onTap: () => taps += 1,
                leading: const Text('leading'),
                preview: const Text('preview'),
                trailing: const Text('trailing'),
                details: const Text('details'),
                child: const Text('owner'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Metadata'), findsOneWidget);
    expect(find.text('leading'), findsOneWidget);
    expect(find.text('preview'), findsOneWidget);
    expect(find.text('trailing'), findsOneWidget);
    expect(find.text('details'), findsOneWidget);
    await tester.tap(find.text('owner'));
    expect(taps, 1);
  });

  testWidgets('workspace card preserves the child bounded route surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorWorkspaceCard(
            child: SizedBox.expand(key: ValueKey<String>('workspace_body')),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('workspace_body')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('workspace_body'))),
      const Size(768, 568),
    );
  });
}
