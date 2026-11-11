import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_ui/tool_ui.dart';

void main() {
  testWidgets(
    'short windows and larger text retain the workspace while scrolling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: ToolPreviewWorkspace(
                scrollKey: const PageStorageKey('workspace'),
                header: const Text('Selected mission'),
                preview: const ToolPanelCard(
                  key: ValueKey('preview'),
                  title: 'Preview',
                  bodyMode: ToolPanelBodyMode.expanded,
                  child: ColoredBox(color: Colors.blue),
                ),
                tabs: const Text('Contents / Route / Markers'),
                content: ListView(
                  children: [TextField(controller: controller)],
                ),
              ),
            ),
          ),
        ),
      );
      final preview = tester.element(find.byKey(const ValueKey('preview')));
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'retained filter');
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const ValueKey('preview'))),
        same(preview),
      );
      expect(controller.text, 'retained filter');
      expect(tester.takeException(), isNull);
    },
  );
}
