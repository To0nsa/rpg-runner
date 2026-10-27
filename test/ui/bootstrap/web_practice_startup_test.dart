@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';
import 'package:rpg_runner/ui/app/create_app_services.dart';
import 'package:rpg_runner/ui/app/ui_app.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/hud/game/game_overlay.dart';
import 'package:rpg_runner/ui/hud/game/ready_overlay.dart';
import 'package:rpg_runner/ui/hud/gameover/game_over_overlay.dart';
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

  testWidgets('web boots, opens options and plays a recorder-free local run', (
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
    // Start the browser's image decoding in the real async zone. Merely yielding
    // to runAsync after mounting leaves decoder futures on the fake test clock.
    await tester.runAsync(() async {
      navigator.pushNamed(UiRoutes.run, arguments: descriptor);
      for (
        var i = 0;
        i < 1200 && find.byType(ReadyOverlay).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(tester.takeException(), isNull);
      }
    });
    if (find.byType(ReadyOverlay).evaluate().isEmpty) {
      for (final host in tester.widgetList<GameWidget<RunnerFlameGame>>(
        find.byType(GameWidget<RunnerFlameGame>),
      )) {
        final load = host.game!.loadState.value;
        printOnFailure(
          'Run startup phase=${load.phase}, error=${load.error}\n'
          '${load.stackTrace}',
        );
      }
      printOnFailure(
        'Visible labels: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(' | ')}',
      );
    }
    expect(find.byType(ReadyOverlay), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final controller = tester
        .widget<GameOverlay>(find.byType(GameOverlay))
        .controller;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
    expect(controller.tick, greaterThan(0));
    controller.giveUp();
    await tester.pump();
    expect(find.byType(GameOverOverlay), findsOneWidget);
    expect(
      tester
          .widget<GameOverOverlay>(find.byType(GameOverOverlay))
          .isDeveloperPractice,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
