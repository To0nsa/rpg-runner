import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:runner_editor/src/playtest/display_calibration.dart';
import 'package:runner_editor/src/playtest/playtest_device_screen.dart';
import 'package:runner_editor/src/app/pages/shared/calibrated_playtest_preview.dart';
import 'package:runner_editor/src/app/pages/shared/display_calibration_dialog.dart';

const _monitor = EditorMonitor(
  id: 'panel-a',
  name: 'Panel A',
  bounds: Rect.fromLTWH(0, 0, 4000, 2400),
  orientation: 0,
  identified: true,
);
void main() {
  testWidgets(
    'calibration requires a measurement and invalidates it on DPI change',
    (tester) async {
      final reader = _Reader();
      final store = DisplayCalibrationStore();
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: DisplayCalibrationDialog(reader: reader, store: store),
        ),
      );
      await tester.pump();
      final measurement = find.byKey(const ValueKey('calibration_measured_mm'));
      expect(tester.widget<TextField>(measurement).controller!.text, isEmpty);
      await tester.tap(find.byKey(const ValueKey('calibration_save')));
      await tester.pump();
      expect(store.profiles, isEmpty);
      expect(find.textContaining('enter its measured length'), findsOneWidget);
      await tester.enterText(measurement, '100');
      tester.view.devicePixelRatio = 1.5;
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<TextField>(measurement).controller!.text, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a new ruler measurement saves scale; remote profile reuse needs no new measurement',
    (tester) async {
      final reader = _Reader();
      final store = DisplayCalibrationStore();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      DisplayCalibrationDialog(reader: reader, store: store),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.enterText(
        find.byKey(const ValueKey('calibration_measured_mm')),
        '100',
      );
      await tester.tap(find.byKey(const ValueKey('calibration_save')));
      await tester.pumpAndSettle();
      expect(store.profiles.single.pixelsPerMm, 4);
      expect(find.byType(DisplayCalibrationDialog), findsNothing);
      reader.environment = const EditorDisplayEnvironment(
        origin: Offset.zero,
        monitors: [_monitor],
        remote: true,
      );
      await open();
      await tester.tap(
        find.byType(DropdownButtonFormField<DisplayCalibration>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(store.profiles.single.label).last);
      await tester.pumpAndSettle();
      expect(find.byType(DisplayCalibrationDialog), findsNothing);
      expect(store.resolve(_monitor, remote: true)!.pixelsPerMm, 4);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('physical scale uses monitor DPR once and never the device DPR', () {
    final calibration = DisplayCalibration(
      signature: _monitor.signature,
      pixelsPerMm: 4,
      label: 'Ruler',
    );
    for (final dpr in [1.0, 1.25, 2.0]) {
      final scale = calibration.scale(
        screenWidthMm: 140,
        logicalWidth: 844,
        monitorDpr: dpr,
      );
      expect(scale * 844 * dpr, closeTo(560, 1e-9));
    }
    expect(
      () => DisplayCalibration(
        signature: 'bad',
        pixelsPerMm: double.nan,
        label: 'Bad',
      ),
      throwsArgumentError,
    );
  });

  test('profiles match monitor, resolution and orientation; remote needs confirmation', () async {
    final store = DisplayCalibrationStore();
    final profile = DisplayCalibration(
      signature: _monitor.signature,
      pixelsPerMm: 4,
      label: 'Ruler',
    );
    await store.save(profile);
    expect(store.resolve(_monitor, remote: false), same(profile));
    final other = EditorMonitor(
      id: 'panel-b',
      name: 'Panel B',
      bounds: _monitor.bounds,
      orientation: 0,
      identified: true,
    );
    const rotated = EditorMonitor(
      id: 'panel-a',
      name: 'Panel A',
      bounds: Rect.fromLTWH(0, 0, 2400, 4000),
      orientation: 1,
      identified: true,
    );
    expect(store.resolve(other, remote: false), isNull);
    expect(store.resolve(rotated, remote: false), isNull);
    final directory = await Directory.systemTemp.createTemp(
      'editor-calibration-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/profiles.json');
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'profiles': [
          profile.toJson(),
          {'pixelsPerMm': 'bad'},
        ],
      }),
    );
    final reopened = DisplayCalibrationStore(file: file);
    await reopened.load();
    expect(reopened.resolve(_monitor, remote: true), isNull);
    reopened.confirm(_monitor, reopened.profiles.single);
    expect(reopened.resolve(_monitor, remote: true)!.pixelsPerMm, 4);
    reopened.confirm(other, reopened.profiles.single);
    await reopened.save(profile);
    final nextLaunch = DisplayCalibrationStore(file: file);
    await nextLaunch.load();
    expect(nextLaunch.resolve(_monitor, remote: true), isNull);
    expect(
      nextLaunch.resolve(other, remote: false),
      isNull,
      reason: 'Manual confirmation must not become a persisted monitor match.',
    );
  });

  test('screen rectangles preserve logical aspect; monitor straddling is unresolved', () {
    for (final entry in RunnerPlaytestDevicePresets.devices.entries) {
      final screen = PlaytestDeviceScreen.presets[entry.key]!;
      final width = screen.widthMm(entry.value);
      final height = width * entry.value.height / entry.value.width;
      expect(
        width * width + height * height,
        closeTo(screen.diagonalMm * screen.diagonalMm, .001),
      );
      expect(screen.source, startsWith('https://'));
    }
    const second = EditorMonitor(
      id: 'panel-b',
      name: 'Panel B',
      bounds: Rect.fromLTWH(4000, 0, 4000, 2400),
      orientation: 0,
      identified: true,
    );
    const environment = EditorDisplayEnvironment(
      origin: Offset(3900, 0),
      monitors: [_monitor, second],
      remote: false,
    );
    expect(
      environment.containing(
        environment.physicalBounds(const Rect.fromLTWH(0, 0, 200, 100), 1),
      ),
      isNull,
    );
    expect(
      environment.containing(const Rect.fromLTWH(4100, 20, 200, 100)),
      same(second),
    );
  });

  testWidgets(
    'resize and OS scaling retain physical width and the live child',
    (tester) async {
      final store = DisplayCalibrationStore();
      await store.save(
        DisplayCalibration(
          signature: _monitor.signature,
          pixelsPerMm: 4,
          label: 'Ruler',
        ),
      );
      final reader = _Reader();
      final controller = RunnerPlaytestController();
      final childKey = GlobalKey();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CalibratedPlaytestPreview(
            settings: EditorPlaytestSettings.initial,
            controller: controller,
            reader: reader,
            store: store,
            child: SizedBox.expand(key: childKey),
          ),
        ),
      );
      final element = childKey.currentContext;
      final display = EditorPlaytestSettings.initial.presentation.display!;
      final expected =
          EditorPlaytestSettings.initial.screen.widthMm(display) * 4;
      for (final (size, dpr) in [
        (const Size(1400, 900), 1.0),
        (const Size(900, 600), 1.5),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpr;
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final box = childKey.currentContext!.findRenderObject()! as RenderBox;
        final width =
            box.localToGlobal(Offset(display.width.toDouble(), 0)).dx -
            box.localToGlobal(Offset.zero).dx;
        expect(width * dpr, closeTo(expected, 1e-6));
        expect(childKey.currentContext, same(element));
        expect(
          find.textContaining('Calibrated physical screen'),
          findsOneWidget,
        );
      }
      reader.environment = const EditorDisplayEnvironment(
        origin: Offset(3900, 0),
        monitors: [_monitor],
        remote: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
        find.text('Move the preview entirely onto one monitor.'),
        findsOneWidget,
      );
      expect(childKey.currentContext, same(element));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}

class _Reader implements EditorDisplayReader {
  EditorDisplayEnvironment environment = const EditorDisplayEnvironment(
    origin: Offset.zero,
    monitors: [_monitor],
    remote: false,
  );
  @override
  Future<EditorDisplayEnvironment?> read() async => environment;
}
