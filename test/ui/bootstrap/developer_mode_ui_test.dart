import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/app/app_services.dart';
import 'package:rpg_runner/ui/app/create_app_services.dart';
import 'package:rpg_runner/ui/app/ui_app.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/pages/selectLevel/level_setup_page.dart';
import 'package:rpg_runner/ui/pages/hub/play_hub_page.dart';
import 'package:rpg_runner/ui/pages/hub/components/hub_menu_icon_column.dart';
import 'package:rpg_runner/ui/pages/hub/components/weekly_badge_row.dart';
import 'package:rpg_runner/ui/pages/options/options_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:rpg_runner/ui/state/profile/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_runner/ui/controls/movement_control_mode.dart';
import 'package:rpg_runner/ui/state/settings/control_settings.dart';
import 'package:rpg_runner/ui/runner_game_widget.dart';
import 'package:rpg_runner/ui/controls/move_joystick.dart';
import 'package:rpg_runner/ui/controls/move_buttons.dart';

import '../../test_support/app_startup_fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, AppServices services) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UiApp(services: services));
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'Options switches existing screens to the local profile and back',
    (tester) async {
      final fixture = StartupFixture();
      fixture.profile.profile = const UserProfile(
        displayName: 'Real Player',
        displayNameLastChangedAtMs: 0,
        namePromptCompleted: true,
      );
      final services = AppServices(
        initialize: () async {},
        createAppState: () => AppState(
          authApi: fixture.auth,
          userProfileRemoteApi: fixture.profile,
          loadoutOwnershipApi: fixture.ownership,
        ),
        developerProfileStore: SharedPrefsDeveloperProfileStore(),
        controlSettingsStore: SharedPrefsControlSettingsStore(),
      );
      await mount(tester, services);
      expect(find.byType(PlayHubPage), findsOneWidget);
      expect(find.text('Real Player'), findsOneWidget);
      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      expect(find.byType(OptionsPage), findsOneWidget);
      await tester.tap(find.text('CONTROLS'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNothing);
      await tester.tap(find.text('Floating joystick'));
      await tester.pumpAndSettle();
      expect(
        services.controlSettings.movementMode,
        MovementControlMode.joystick,
      );
      expect(
        await SharedPrefsControlSettingsStore().loadMovementMode(),
        MovementControlMode.joystick,
      );
      await tester.tap(find.text('Fixed joystick'));
      await tester.pumpAndSettle();
      expect(
        services.controlSettings.movementMode,
        MovementControlMode.fixedJoystick,
      );
      expect(
        await SharedPrefsControlSettingsStore().loadMovementMode(),
        MovementControlMode.fixedJoystick,
      );
      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(PlayHubPage), findsOneWidget);
      expect(find.text('Developer'), findsOneWidget);
      expect(services.appState.isDeveloperMode, isTrue);
      final menu = tester.widget<HubMenuIconColumn>(
        find.byType(HubMenuIconColumn),
      );
      expect(menu.onTownPressed, isNull);
      expect(menu.onProfilePressed, isNull);
      expect(menu.onLeaderboardsPressed, isNull);
      final weekly = tester.widget<WeeklyBadgeRow>(find.byType(WeeklyBadgeRow));
      expect(weekly.onWeeklyPressed, isNull);
      expect(weekly.onWeeklyLeaderboardPressed, isNull);
      await services.appState.setBuildName('Remember me');
      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Real Player'), findsOneWidget);
      expect(services.appState.isDeveloperMode, isFalse);
      expect(
        services.controlSettings.movementMode,
        MovementControlMode.fixedJoystick,
      );
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'launch flag reaches the hub on a fresh install without Firebase',
    (tester) async {
      final services = createAppServices();
      await mount(tester, services);
      await tester.pumpAndSettle();
      expect(find.byType(PlayHubPage), findsOneWidget);
      expect(find.text('Developer'), findsOneWidget);
      expect(services.appState.authSession.isAuthenticated, isFalse);
      expect(
        (await services.appState.prepareRunStartDescriptor())
            .isDeveloperPractice,
        isTrue,
      );
      expect(await SharedPrefsDeveloperProfileStore().loadEnabled(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    skip: !const bool.fromEnvironment('DEVELOPER_PRACTICE'),
  );

  testWidgets(
    'saved developer mode reaches the existing hub without online services',
    (tester) async {
      const charging = MethodChannel('dev.fluttercommunity.plus/charging');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        charging,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          charging,
          null,
        ),
      );
      final store = SharedPrefsDeveloperProfileStore();
      await store.saveEnabled(true);
      final controlsStore = SharedPrefsControlSettingsStore();
      await controlsStore.saveMovementMode(MovementControlMode.fixedJoystick);
      final services = AppServices(
        initialize: () async =>
            throw StateError('Must not initialize Firebase'),
        createAppState: () =>
            throw StateError('Must not construct online state'),
        developerProfileStore: store,
        controlSettingsStore: controlsStore,
      );
      await mount(tester, services);
      await tester.pumpAndSettle();
      expect(find.byType(PlayHubPage), findsOneWidget);
      expect(find.text('Developer'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(PlayHubPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed(UiRoutes.setupLevel);
      await tester.pumpAndSettle();
      expect(find.byType(LevelSetupPage), findsOneWidget);
      expect(find.text('PRACTICE'), findsOneWidget);
      expect(find.text('COMPETITIVE'), findsNothing);
      final descriptor = await services.appState.prepareRunStartDescriptor();
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed(UiRoutes.run, arguments: descriptor);
      for (
        var i = 0;
        i < 800 && find.text('Tap to start').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        expect(tester.takeException(), isNull);
      }
      expect(
        tester
            .widget<RunnerGameWidget>(find.byType(RunnerGameWidget))
            .movementControlMode,
        MovementControlMode.fixedJoystick,
      );
      expect(find.byType(MoveJoystick), findsOneWidget);
      expect(find.byType(MoveButtons), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('Options omits the toggle when developer support is not wired', (
    tester,
  ) async {
    final fixture = StartupFixture();
    fixture.profile.profile = const UserProfile(
      displayName: 'Real Player',
      displayNameLastChangedAtMs: 0,
      namePromptCompleted: true,
    );
    await mount(tester, fixture.services);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.byType(OptionsPage), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Developer mode'), findsNothing);
    await tester.tap(find.text('CONTROLS'));
    await tester.pumpAndSettle();
    expect(find.text('Arrows'), findsOneWidget);
    expect(find.text('Floating joystick'), findsOneWidget);
    expect(find.text('Fixed joystick'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
