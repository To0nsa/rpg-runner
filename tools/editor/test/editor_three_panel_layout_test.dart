import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/editor_three_panel_layout.dart';

void main() {
  testWidgets('wide layout exposes all panels without tab indirection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(width: 1200));

    expect(
      find.byKey(const ValueKey<String>('editor_three_panel_wide')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('first_panel')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('second_panel')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('third_panel')), findsOneWidget);
  });

  testWidgets('narrow layout exposes every panel through accessible tabs', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(width: 700));

    expect(
      find.byKey(const ValueKey<String>('editor_three_panel_narrow')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Editor panel selector'), findsOneWidget);
    expect(find.text('Second panel'), findsOneWidget);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(find.text('First panel'), findsOneWidget);

    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();
    expect(find.text('Third panel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Widget _app({required double width}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        height: 500,
        child: EditorThreePanelLayout(
          firstLabel: 'First',
          secondLabel: 'Second',
          thirdLabel: 'Third',
          first: const Center(
            key: ValueKey<String>('first_panel'),
            child: Text('First panel'),
          ),
          second: const Center(
            key: ValueKey<String>('second_panel'),
            child: Text('Second panel'),
          ),
          third: const Center(
            key: ValueKey<String>('third_panel'),
            child: Text('Third panel'),
          ),
        ),
      ),
    ),
  ),
);
