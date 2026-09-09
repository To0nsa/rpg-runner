import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/editor_three_panel_layout.dart';

void main() {
  testWidgets(
    'diagnostic requests reveal a panel again after manual selection',
    (tester) async {
      final controller = EditorThreePanelController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorThreePanelLayout(
              controller: controller,
              firstLabel: 'Library',
              secondLabel: 'Workspace',
              thirdLabel: 'Settings',
              first: const Text('Sources'),
              second: const Text('Scene'),
              third: const TextField(key: ValueKey('retained_field')),
            ),
          ),
        ),
      );
      controller.revealPanel(2);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('retained_field')),
        'retained draft',
      );
      await tester.tap(find.text('Workspace'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('retained_field')), findsNothing);
      controller.revealPanel(2);
      await tester.pumpAndSettle();
      expect(find.text('retained draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('panel state survives tab changes and both resize directions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final panelKey = GlobalKey<_PersistentPanelState>();
    Widget app(double width) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 500,
          child: EditorThreePanelLayout(
            firstLabel: 'First',
            secondLabel: 'Second',
            thirdLabel: 'Third',
            first: _PersistentPanel(key: panelKey),
            second: const Text('Preview'),
            third: const Text('Settings'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(1200));
    final originalState = panelKey.currentState;
    await tester.enterText(find.byType(TextField), 'retained input');
    await tester.pumpWidget(app(700));
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(find.text('retained input'), findsOneWidget);
    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(1200));
    expect(panelKey.currentState, same(originalState));
    expect(find.text('retained input'), findsOneWidget);
    await tester.pumpWidget(app(700));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(panelKey.currentState, same(originalState));
    expect(tester.takeException(), isNull);
  });
}

class _PersistentPanel extends StatefulWidget {
  const _PersistentPanel({super.key});
  @override
  State<_PersistentPanel> createState() => _PersistentPanelState();
}

class _PersistentPanelState extends State<_PersistentPanel> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: controller);
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
