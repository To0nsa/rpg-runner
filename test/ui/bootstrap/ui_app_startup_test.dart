import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/app/ui_app.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/bootstrap/brand_splash_screen.dart';
import 'package:rpg_runner/ui/bootstrap/loader_page.dart';
import 'package:rpg_runner/ui/bootstrap/profile_name_setup_page.dart';
import 'package:rpg_runner/ui/pages/hub/play_hub_page.dart';
import 'package:rpg_runner/ui/state/auth/firebase_auth_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/app_startup_fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, StartupFixture fixture) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UiApp(services: fixture.services));
  }

  Future<void> finishBranding(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('cold start preserves both brand timings and has no hidden hub', (
    tester,
  ) async {
    final fixture = StartupFixture();
    await mount(tester, fixture);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
    expect(find.byType(PlayHubPage, skipOffstage: false), findsNothing);
    await tester.pump(const Duration(milliseconds: 1799));
    expect(find.byType(BrandSplashScreen), findsOneWidget);
    expect(fixture.initializationCalls, 0);
    expect(fixture.auth.calls, 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(LoaderPage), findsOneWidget);
    expect(fixture.services.appState.isBootstrapped, isTrue);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byType(LoaderPage), findsOneWidget);
    expect(find.byType(ProfileNameSetupPage), findsNothing);
    expect(navigator.canPop(), isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ProfileNameSetupPage), findsOneWidget);
    expect(find.byType(PlayHubPage, skipOffstage: false), findsNothing);
    expect(navigator.canPop(), isFalse);
    expect(await navigator.maybePop(), isFalse);
  });

  testWidgets(
    'initialization failure is visible and retry creates clients only after success',
    (tester) async {
      final fixture = StartupFixture()
        ..initializationError = StateError('verification failed');
      await mount(tester, fixture);
      await finishBranding(tester);
      expect(find.text('Unable to start the game'), findsOneWidget);
      expect(fixture.stateCreations, 0);
      expect(find.byType(PlayHubPage, skipOffstage: false), findsNothing);
      fixture.initializationError = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ProfileNameSetupPage), findsOneWidget);
      expect(fixture.initializationCalls, 2);
      expect(fixture.stateCreations, 1);
    },
  );

  testWidgets(
    'native sign-in lifecycle events do not stack loaders or retry auth',
    (tester) async {
      final fixture = StartupFixture();
      fixture.auth.error = const PlayGamesAuthRequiredException();
      await mount(tester, fixture);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await finishBranding(tester);
      expect(find.text('Retry Play Games sign-in'), findsOneWidget);
      expect(fixture.auth.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fixture.auth.calls, 1);
      expect(find.byType(LoaderPage, skipOffstage: false), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
    },
  );

  testWidgets(
    'resume is a single gate and returns to the prior page after retry',
    (tester) async {
      final fixture = StartupFixture();
      await mount(tester, fixture);
      await finishBranding(tester);
      fixture.profile.error = StateError('backend unavailable');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Unable to load player data'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();
      expect(find.byType(LoaderPage), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(LoaderPage, skipOffstage: false), findsOneWidget);
      fixture.profile.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileNameSetupPage), findsOneWidget);
      expect(find.byType(LoaderPage), findsNothing);
      expect(fixture.initializationCalls, 1);
      expect(navigator.canPop(), isFalse);
    },
  );

  testWidgets('a returning player reaches one hub after bootstrap', (
    tester,
  ) async {
    final fixture = StartupFixture();
    fixture.profile.profile = fixture.profile.profile.copyWith(
      displayName: 'Runner',
      namePromptCompleted: true,
    );
    await mount(tester, fixture);
    await finishBranding(tester);
    expect(find.byType(PlayHubPage, skipOffstage: false), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(fixture.services.appState.isBootstrapped, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('resume leaves a run page with an open dialog in place', (
    tester,
  ) async {
    final fixture = StartupFixture();
    await mount(tester, fixture);
    await finishBranding(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: UiRoutes.run),
          builder: (_) => const Scaffold(body: Text('run-marker')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    unawaited(
      showDialog<void>(
        context: tester.element(find.text('run-marker')),
        builder: (_) => const AlertDialog(content: Text('pause-marker')),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('pause-marker'), findsOneWidget);
    expect(find.byType(LoaderPage, skipOffstage: false), findsNothing);
  });

  testWidgets('display-channel failure does not prevent startup', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations' ||
            call.method == 'SystemChrome.setEnabledSystemUIMode') {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mount(tester, StartupFixture());
    await finishBranding(tester);
    expect(find.byType(ProfileNameSetupPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the splash cancels its pending transition', (
    tester,
  ) async {
    await mount(tester, StartupFixture());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disposing the loader cancels its timer and fences initialization',
    (tester) async {
      final fixture = StartupFixture()..initializationGate = Completer<void>();
      await mount(tester, fixture);
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump();
      expect(find.byType(LoaderPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.initializationGate!.complete();
      await tester.pump();
      expect(fixture.stateCreations, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
