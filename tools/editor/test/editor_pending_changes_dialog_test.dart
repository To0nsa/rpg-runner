import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/editor_pending_changes_dialog.dart';

void main() {
  for (final testCase
      in <({String label, Key key, EditorPendingChangesAction action})>[
        (
          label: 'Save',
          key: const ValueKey<String>('save'),
          action: EditorPendingChangesAction.save,
        ),
        (
          label: 'Discard',
          key: const ValueKey<String>('discard'),
          action: EditorPendingChangesAction.discard,
        ),
        (
          label: 'Cancel',
          key: const ValueKey<String>('cancel'),
          action: EditorPendingChangesAction.cancel,
        ),
      ]) {
    testWidgets('returns ${testCase.label.toLowerCase()} explicitly', (
      tester,
    ) async {
      EditorPendingChangesAction? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showEditorPendingChangesDialog(
                  context: context,
                  dialogKey: const ValueKey<String>('dialog'),
                  title: 'Resolve draft',
                  content: const Text('Pending content'),
                  cancelKey: const ValueKey<String>('cancel'),
                  discardKey: const ValueKey<String>('discard'),
                  saveKey: const ValueKey<String>('save'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('dialog')), findsOneWidget);

      await tester.tap(find.byKey(testCase.key));
      await tester.pumpAndSettle();
      expect(result, testCase.action);
    });
  }

  testWidgets('cannot be dismissed by tapping the barrier', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEditorPendingChangesDialog(
              context: context,
              dialogKey: const ValueKey<String>('dialog'),
              title: 'Resolve draft',
              content: const Text('Pending content'),
              cancelKey: const ValueKey<String>('cancel'),
              discardKey: const ValueKey<String>('discard'),
              saveKey: const ValueKey<String>('save'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('dialog')), findsOneWidget);
  });
}
