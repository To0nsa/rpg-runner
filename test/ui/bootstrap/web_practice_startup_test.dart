@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/app/create_app_services.dart';
import 'package:rpg_runner/ui/app/ui_app.dart';
import 'package:rpg_runner/ui/pages/hub/play_hub_page.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Browser console output is not always forwarded by Flutter's test harness.
  // Preserve failure reporting while attaching the actual exception to the test.
  final originalReporter = reportTestException;
  reportTestException = (details, description) {
    printOnFailure(details.toString());
    originalReporter(details, description);
  };
  tearDownAll(() => reportTestException = originalReporter);
  for (final savedMode in [false, true]) {
    test(
      'web startup is local regardless of saved mode ($savedMode)',
      () async {
        SharedPreferences.setMockInitialValues({
          'developer_practice.enabled.v1': savedMode,
        });
        final services = createAppServices();
        addTearDown(services.dispose);
        final state = await services.initialize();
        await state.bootstrap();
        expect(services.isPracticeOnly, isTrue);
        expect(services.canSwitchProfiles, isFalse);
        expect(state.isDeveloperMode, isTrue);
        expect(state.authSession.isAuthenticated, isFalse);
        await expectLater(services.setDeveloperMode(false), throwsStateError);
        expect(services.appState, same(state));
        expect(
          await SharedPrefsDeveloperProfileStore().loadEnabled(),
          savedMode,
        );
        await state.setBuildName('Browser build');
        expect(
          (await SharedPrefsDeveloperProfileStore().loadSelection()).buildName,
          'Browser build',
        );
      },
    );
  }

  testWidgets('web opens local-only options and prepares a Practice run', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final services = createAppServices();
    await tester.pumpWidget(UiApp(services: services));
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(PlayHubPage), findsOneWidget);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(
      find.textContaining('Account features are unavailable'),
      findsOneWidget,
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    final descriptor = await services.appState.prepareRunStartDescriptor();
    expect(descriptor.isDeveloperPractice, isTrue);
    expect(services.isPracticeOnly, isTrue);
    expect(services.appState.authSession.isAuthenticated, isFalse);
    // Asset-backed readiness, live ticks and Practice game-over are exercised
    // against the compiled app by the mandatory web_smoke.mjs release gate.
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
