import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runner_editor/src/app/pages/shared/playtest_launch_dialog.dart';
import 'package:runner_editor/src/app/pages/shared/display_calibration_dialog.dart';
import 'package:runner_editor/src/playtest/playtest_device_screen.dart';
import 'package:runner_editor/src/playtest/display_calibration.dart';
import 'package:runner_editor/src/app/pages/shared/authored_playtest_session.dart';
import 'package:runner_editor/src/playtest/authored_playtest_preparation.dart';

void main() {
  testWidgets(
    'setup is single-flight and rejects target/controller changes before capture',
    (tester) async {
      final session = AuthoredPlaytestSession();
      addTearDown(session.dispose);
      await tester.runAsync(DisplayCalibrationStore.instance.load);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      final source = Object();
      var current = true;
      final pending = session.configure(
        context: context,
        title: 'Test chunk',
        source: source,
        isSourceCurrent: () => current,
      );
      await tester.pumpAndSettle();
      expect(session.locksEditor, isTrue);
      expect(
        await session.configure(
          context: context,
          title: 'Duplicate',
          source: source,
          isSourceCurrent: () => true,
        ),
        isFalse,
      );
      expect(session.handleShortcut(LogicalKeyboardKey.f5), isTrue);
      await tester.pump();
      expect(find.byType(PlaytestLaunchDialog), findsOneWidget);
      current = false;
      Navigator.of(context).pop(EditorPlaytestSettings.initial);
      await tester.pumpAndSettle();
      expect(await pending, isFalse);
      expect(session.mode, AuthoredPlaytestMode.edit);
      expect(session.settings, same(EditorPlaytestSettings.initial));
      expect(session.controller, isNull);

      final replaced = session.configure(
        context: context,
        title: 'Play level',
        source: source,
        isSourceCurrent: () => true,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Calibrate monitor…'));
      // The launch flow loads the machine-local store outside the fake clock.
      await tester.runAsync(() => tester.tap(find.text('Calibrate monitor…')));
      await tester.pumpAndSettle();
      expect(find.byType(DisplayCalibrationDialog), findsOneWidget);
      session.reconcileSource(Object());
      await tester.pumpAndSettle();
      expect(await replaced, isFalse);
      expect(find.byType(PlaytestLaunchDialog), findsNothing);
      expect(find.byType(DisplayCalibrationDialog), findsNothing);
      expect(session.locksEditor, isFalse);
    },
  );

  testWidgets(
    'capture locks immediately and canceled late errors cannot reopen Play',
    (tester) async {
      final play = AuthoredPlaytestSession();
      addTearDown(play.dispose);
      final capture = Completer<PlaytestPreparationInput>();
      final source = Object();
      final pending = play.prepare(
        source: source,
        isSourceCurrent: () => true,
        capture: () => capture.future,
        runner: (_) async => throw StateError('must not run'),
      );
      expect(play.mode, AuthoredPlaytestMode.preparing);
      expect(play.locksEditor, isTrue);
      play.stop();
      capture.completeError(
        const PlaytestPreparationException(
          code: 'stale',
          message: 'stale failure',
        ),
      );
      await pending;
      expect(play.mode, AuthoredPlaytestMode.edit);
      expect(play.issues, isEmpty);
    },
  );

  testWidgets(
    'source replacement cancels capture without accepting the previous source',
    (tester) async {
      final play = AuthoredPlaytestSession();
      addTearDown(play.dispose);
      final capture = Completer<PlaytestPreparationInput>();
      final source = Object();
      final pending = play.prepare(
        source: source,
        isSourceCurrent: () => false,
        capture: () => capture.future,
        runner: (_) async => throw StateError('must not run'),
      );
      play.reconcileSource(Object());
      capture.completeError(StateError('previous workspace failed'));
      await pending;
      expect(play.mode, AuthoredPlaytestMode.edit);
      expect(play.issues, isEmpty);
    },
  );

  testWidgets(
    'capture failure retains the error until return and retry captures again',
    (tester) async {
      final play = AuthoredPlaytestSession();
      addTearDown(play.dispose);
      var captures = 0;
      Future<void> start() => play.prepare(
        source: Object(),
        isSourceCurrent: () => true,
        capture: () async {
          captures++;
          throw const PlaytestPreparationException(
            code: 'missing_theme',
            message: 'Create the missing background.',
          );
        },
        runner: (_) async => throw StateError('must not run'),
      );
      await start();
      expect(play.mode, AuthoredPlaytestMode.preparationFailed);
      expect(play.locksEditor, isTrue);
      expect(play.issues.single.code, 'missing_theme');
      await start();
      expect(captures, 1);
      play.stop();
      await start();
      expect(captures, 2);
      expect(play.issues.single.message, 'Create the missing background.');
    },
  );
}
