import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/playtest_launch_dialog.dart';
import 'package:runner_editor/src/playtest/playtest_device_screen.dart';

import 'support/playtest_display_fixture.dart';

import 'package:runner_editor/src/playtest/display_calibration.dart';
import 'package:rpg_runner/playtest.dart';

void main() {
  setUp(installCalibratedDisplayFixture);
  testWidgets(
    'custom physical size stays editable when logical size matches a preset',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlaytestLaunchDialog(
            title: 'Play mission',
            initial: EditorPlaytestSettings(
              presentation: RunnerPlaytestPresentation(
                display: RunnerPlaytestDevicePresets.defaultPhone,
              ),
              screen: PlaytestDeviceScreen(180, 0.1, 'Measured custom screen'),
            ),
          ),
        ),
      );
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byKey(const ValueKey('playtest_display_preset')),
            )
            .value,
        'Custom',
      );
      expect(_field(tester, 'width').enabled, isTrue);
      final diagonal = tester.widget<TextFormField>(
        find.byKey(const ValueKey('playtest_screen_diagonal')),
      );
      expect(diagonal.enabled, isTrue);
      expect(diagonal.controller!.text, '180.00');
    },
  );
  for (final (mode, label) in [
    (MovementControlMode.arrows, 'Arrows'),
    (MovementControlMode.joystick, 'Floating joystick'),
    (MovementControlMode.fixedJoystick, 'Fixed joystick'),
  ]) {
    testWidgets('Play returns the chosen $label controls before launch', (
      tester,
    ) async {
      RunnerPlaytestPresentation? result;
      await _open(tester, onResult: (value) => result = value);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(result, isNull);
      await tester.tap(
        find.byKey(const ValueKey('playtest_movement_controls')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.runAsync(() async => tester.tap(find.text('Play')));
      await tester.pumpAndSettle();
      expect(result!.showMobileHud, isTrue);
      expect(result!.movementControlMode, mode);
      expect(result!.viewportMode, ViewportScaleMode.pixelPerfectCover);
      expect(result!.display, RunnerPlaytestDevicePresets.defaultPhone);
      expect(find.byType(PlaytestLaunchDialog), findsNothing);
    });
  }

  testWidgets(
    'HUD can be disabled while preserving the previous control choice',
    (tester) async {
      RunnerPlaytestPresentation? result;
      await _open(
        tester,
        initial: const RunnerPlaytestPresentation(
          showMobileHud: true,
          movementControlMode: MovementControlMode.fixedJoystick,
        ),
        onResult: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('playtest_show_mobile_hud')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<MovementControlMode>>(
              find.byType(DropdownButtonFormField<MovementControlMode>),
            )
            .onChanged,
        isNull,
      );
      await tester.runAsync(() async => tester.tap(find.text('Play')));
      await tester.pumpAndSettle();
      expect(result!.showMobileHud, isFalse);
      expect(result!.movementControlMode, MovementControlMode.fixedJoystick);
    },
  );

  testWidgets('Cancel discards setup changes', (tester) async {
    var returned = false;
    await _open(
      tester,
      onResult: (value) {
        returned = true;
        expect(value, isNull);
      },
    );
    await tester.tap(find.byKey(const ValueKey('playtest_show_mobile_hud')));
    await tester.pumpAndSettle();
    expect(returned, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  for (final preset in RunnerPlaytestDevicePresets.devices.entries) {
    testWidgets('launch captures ${preset.key} dimensions and density', (
      tester,
    ) async {
      RunnerPlaytestPresentation? result;
      await _open(tester, onResult: (value) => result = value);
      await _chooseDevice(tester, preset.key);
      expect(_field(tester, 'width').controller!.text, '${preset.value.width}');
      expect(
        _field(tester, 'height').controller!.text,
        '${preset.value.height}',
      );
      expect(
        _field(tester, 'density').controller!.text,
        '${preset.value.devicePixelRatio}',
      );
      await tester.runAsync(() async => tester.tap(find.text('Play')));
      await tester.pumpAndSettle();
      expect(result!.display, preset.value);
    });
  }

  testWidgets(
    'custom dimensions reject invalid input and retain accepted values',
    (tester) async {
      RunnerPlaytestPresentation? result;
      await _open(tester, onResult: (value) => result = value);
      await _chooseDevice(tester, 'Custom');
      final diagonal = find.byKey(const ValueKey('playtest_screen_diagonal'));
      for (final invalid in ['', 'NaN', '39', '601']) {
        await tester.ensureVisible(diagonal);
        await tester.enterText(diagonal, invalid);
        await tester.tap(find.text('Play'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.byType(PlaytestLaunchDialog), findsOneWidget);
      }
      await tester.enterText(diagonal, '154');
      for (final (field, invalid, valid) in [
        ('width', '', '960'),
        ('width', '100.5', '960'),
        ('width', '0', '960'),
        ('width', '4097', '960'),
        ('height', '1000', '432'),
        ('density', 'NaN', '2.5'),
        ('density', 'Infinity', '2.5'),
        ('density', '0', '2.5'),
        ('density', '5', '2.5'),
      ]) {
        await _enter(tester, field, invalid);
        await tester.runAsync(() async => tester.tap(find.text('Play')));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.byType(PlaytestLaunchDialog), findsOneWidget);
        await _enter(tester, field, valid);
      }
      await tester.runAsync(() async => tester.tap(find.text('Play')));
      await tester.pumpAndSettle();
      const expected = RunnerPlaytestDisplay(
        width: 960,
        height: 432,
        devicePixelRatio: 2.5,
      );
      expect(result!.display, expected);
      final accepted = result!;
      await _open(
        tester,
        initial: accepted,
        onResult: (value) => result = value,
      );
      expect(_field(tester, 'width').controller!.text, '960');
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('playtest_display_width')),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isFalse,
      );
      await _enter(tester, 'width', '1200');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(accepted.display, expected);
    },
  );

  testWidgets(
    'compact launch form scrolls to all controls and can recover with a preset',
    (tester) async {
      RunnerPlaytestPresentation? result;
      await _open(
        tester,
        size: const Size(640, 480),
        onResult: (value) => result = value,
      );
      await _chooseDevice(tester, 'Custom');
      await _enter(tester, 'width', 'bad');
      await tester.runAsync(() async => tester.tap(find.text('Play')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await _chooseDevice(tester, 'Pixel 7');
      final hud = find.byKey(const ValueKey('playtest_show_mobile_hud'));
      await tester.ensureVisible(hud);
      await tester.tap(hud);
      await tester.pumpAndSettle();
      await tester.runAsync(() async => tester.tap(find.text('Play')));
      await tester.pumpAndSettle();
      expect(result!.showMobileHud, isFalse);
      expect(result!.display, RunnerPlaytestDevicePresets.devices['Pixel 7']);
      expect(tester.takeException(), isNull);
    },
  );
}

TextFormField _field(WidgetTester tester, String name) => tester
    .widget<TextFormField>(find.byKey(ValueKey('playtest_display_$name')));

Future<void> _chooseDevice(WidgetTester tester, String name) async {
  final selector = find.byKey(const ValueKey('playtest_display_preset'));
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(name).last);
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String field, String text) async {
  final finder = find.byKey(ValueKey('playtest_display_$field'));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester, {
  required ValueChanged<RunnerPlaytestPresentation?> onResult,
  RunnerPlaytestPresentation initial = RunnerPlaytestPresentation.mobile,
  Size size = const Size(1024, 800),
}) async {
  await tester.runAsync(() => DisplayCalibrationStore.instance.load());
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(
              (await showDialog<EditorPlaytestSettings>(
                context: context,
                builder: (_) => PlaytestLaunchDialog(
                  title: 'Play mission',
                  initial: EditorPlaytestSettings(
                    presentation: initial,
                    screen: EditorPlaytestSettings.initial.screen,
                  ),
                ),
              ))?.presentation,
            ),
            child: const Text('Launch'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Launch'));
  await tester.pumpAndSettle();
}
