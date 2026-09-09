import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/authored_playtest_session.dart';
import 'package:runner_editor/src/playtest/authored_playtest_preparation.dart';

void main() {
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
