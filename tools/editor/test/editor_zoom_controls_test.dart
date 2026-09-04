import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/editor_zoom_controls.dart';

void main() {
  testWidgets('zoom controls fit a narrow editor sidebar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: EditorZoomControls(value: 2, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final controlsRect = tester.getRect(find.byType(EditorZoomControls));
    final sliderRect = tester.getRect(find.byType(Slider));
    expect(sliderRect.right, lessThanOrEqualTo(controlsRect.right));
  });

  testWidgets('zoom controls stack when an inline slider cannot fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 120,
              child: EditorZoomControls(value: 2, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final fieldRect = tester.getRect(find.byType(TextField));
    final sliderRect = tester.getRect(find.byType(Slider));
    expect(sliderRect.top, greaterThanOrEqualTo(fieldRect.bottom));
  });
}
