import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/bootstrap/app_bootstrapper.dart';
import 'package:rpg_runner/ui/state/auth/firebase_auth_api.dart';

import '../../test_support/app_startup_fakes.dart';

void main() {
  test(
    'initialization is shared and state is constructed only after success',
    () async {
      final fixture = StartupFixture()..initializationGate = Completer<void>();
      addTearDown(fixture.services.dispose);
      final first = fixture.services.initialize();
      final second = fixture.services.initialize();
      expect(fixture.initializationCalls, 1);
      expect(fixture.stateCreations, 0);
      fixture.initializationGate!.complete();
      expect(await first, same(await second));
      expect(
        await fixture.services.initialize(),
        same(fixture.services.appState),
      );
      expect(fixture.stateCreations, 1);
      expect(fixture.auth.calls, 0);
    },
  );

  test('failed service initialization can retry without constructing clients early', () async {
    final fixture = StartupFixture()
      ..initializationError = StateError('App Check failed');
    addTearDown(fixture.services.dispose);
    const bootstrapper = AppBootstrapper();
    final failed = await bootstrapper.run(fixture.services, force: false);
    expect(failed.stage, BootstrapStage.services);
    expect(failed.ok, isFalse);
    expect(fixture.stateCreations, 0);
    expect(fixture.auth.calls, 0);
    fixture.initializationError = null;
    expect((await bootstrapper.run(fixture.services, force: false)).ok, isTrue);
    expect(fixture.initializationCalls, 2);
    expect(fixture.stateCreations, 1);
  });

  test(
    'auth retry reuses initialized services and successful bootstrap is cached',
    () async {
      final fixture = StartupFixture();
      addTearDown(fixture.services.dispose);
      fixture.auth.error = const PlayGamesAuthRequiredException();
      const bootstrapper = AppBootstrapper();
      final failed = await bootstrapper.run(fixture.services, force: false);
      expect(failed.retryLabel, 'Retry Play Games sign-in');
      fixture.auth.error = null;
      expect(
        (await bootstrapper.run(fixture.services, force: false)).ok,
        isTrue,
      );
      expect(
        (await bootstrapper.run(fixture.services, force: false)).ok,
        isTrue,
      );
      expect(fixture.initializationCalls, 1);
      expect(fixture.stateCreations, 1);
      expect(fixture.profile.calls, 1);
    },
  );

  test('disposal fences unfinished initialization', () async {
    final fixture = StartupFixture()..initializationGate = Completer<void>();
    final pending = fixture.services.initialize();
    final failed = expectLater(pending, throwsStateError);
    fixture.services.dispose();
    fixture.initializationGate!.complete();
    await failed;
    expect(fixture.stateCreations, 0);
    await expectLater(fixture.services.initialize(), throwsStateError);
  });
}
