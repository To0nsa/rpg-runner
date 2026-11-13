import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/playtest_launch_dialog.dart';
import 'package:runner_editor/src/playtest/display_calibration.dart';

/// Mocked monitor/calibration for workflow tests; never evidence of real size.
void installCalibratedDisplayFixture() {
  const monitor = EditorMonitor(
    id: 'test-monitor',
    name: 'Test monitor',
    bounds: Rect.fromLTWH(0, 0, 5000, 5000),
    orientation: 0,
    identified: true,
  );
  DisplayCalibrationStore.instance.confirm(
    monitor,
    DisplayCalibration(
      signature: monitor.signature,
      pixelsPerMm: 4,
      label: 'Test ruler',
    ),
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('lothringen.editor/display'),
        (_) async => {
          'originX': 0,
          'originY': 0,
          'remote': false,
          'monitors': [
            {
              'id': monitor.id,
              'name': monitor.name,
              'left': 0,
              'top': 0,
              'width': 5000,
              'height': 5000,
              'orientation': 0,
              'identified': true,
            },
          ],
        },
      );
}

Future<void> acceptPlaySetupIfVisible(WidgetTester tester) async {
  if (find.byType(PlaytestLaunchDialog).evaluate().isEmpty) return;
  await tester.pump(const Duration(milliseconds: 300));
  final play = find.descendant(
    of: find.byType(PlaytestLaunchDialog),
    matching: find.widgetWithText(FilledButton, 'Play'),
  );
  if (play.evaluate().isEmpty) return;
  if (tester.widget<FilledButton>(play).onPressed == null) return;
  await tester.runAsync(() async {
    await tester.tap(play);
  });
  await tester.pump(const Duration(milliseconds: 300));
}
