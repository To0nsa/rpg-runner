import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:run_protocol/submission_status.dart';

import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/campaign/campaign_catalog.dart';
import 'package:rpg_runner/ui/components/app_button.dart';
import 'package:rpg_runner/ui/components/gold_display.dart';
import 'package:rpg_runner/ui/components/player_level_bar.dart';
import 'package:rpg_runner/ui/components/progress_meter.dart';
import 'package:rpg_runner/ui/levels/level_id_ui.dart';
import 'package:rpg_runner/ui/pages/hub/components/hub_top_row.dart';
import 'package:rpg_runner/ui/pages/hub/components/hub_select_card_frame.dart';
import 'package:rpg_runner/ui/pages/hub/components/hub_card_action.dart';
import 'package:rpg_runner/ui/pages/hub/components/hub_select_card_body.dart';
import 'package:rpg_runner/ui/pages/hub/components/weekly_badge_row.dart';
import 'package:rpg_runner/ui/pages/hub/play_hub_page.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/ownership/campaign_progress.dart';
import 'package:rpg_runner/ui/state/run/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/player_progress.dart';
import 'package:rpg_runner/ui/state/run/run_session_api.dart';
import 'package:rpg_runner/ui/state/run/run_submission_coordinator.dart';
import 'package:rpg_runner/ui/state/run/run_submission_spool_store.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/charging'),
          (_) async => null,
        );
  });
  setUpAll(() async {
    for (final (family, path) in [
      ('CrimsonText', 'assets/fonts/Crimson_Text/CrimsonText-Regular.ttf'),
      ('Inter', 'assets/fonts/Inter/static/Inter_24pt-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });

  for (final size in [const Size(568, 320), const Size(1280, 720)]) {
    for (final language in ['en', 'fr']) {
      testWidgets(
        'hub play footers fit inside their cards at $size in $language',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final app = AppState(
            authApi: _StaticAuthApi(),
            loadoutOwnershipApi: _NoopOwnershipApi(
              gold: 0,
              weekly: WeeklyProgressState.initial.copyWith(
                currentWindowId: '2026-W05',
              ),
            ),
          );
          addTearDown(app.dispose);
          await app.bootstrap(force: true);
          final assets = UiAssetLifecycle();
          addTearDown(assets.dispose);
          await tester.runAsync(
            () => assets.getIdle(app.selection.selectedCharacterId),
          );
          await tester.pumpWidget(
            _TestApp(appState: app, locale: Locale(language), assets: assets),
          );
          await tester.pump();
          expect(
            find.text(
              language == 'en'
                  ? 'WEEKLY RUNNER - W05'
                  : 'RUNNER HEBDOMADAIRE - W05',
            ),
            findsOneWidget,
          );
          final cards = find.byType(HubSelectCardFrame);
          expect(cards, findsNWidgets(3));
          expect(
            tester.getSize(find.byType(WeeklyBadgeRow)).height,
            lessThanOrEqualTo(56),
          );
          expect(
            find.descendant(
              of: find.byType(WeeklyBadgeRow),
              matching: find.text(
                app.weeklyFeaturedLevelId.localizedName(
                  appStringsFor(Locale(language)),
                ),
              ),
            ),
            findsOneWidget,
          );
          for (final footer in find.byType(HubCardAction).evaluate()) {
            expect(
              find.descendant(
                of: find.byWidget(footer.widget),
                matching: find.byType(Icon),
              ),
              findsNothing,
            );
          }
          for (final (key, index) in [
            ('hub-runner-play', 0),
            ('hub-campaign-play', 2),
          ]) {
            final card = tester.getRect(cards.at(index));
            final action = find.byKey(ValueKey(key));
            final button = tester.getRect(action);
            expect(
              find.descendant(of: cards.at(index), matching: action),
              findsOneWidget,
            );
            expect(button.left, closeTo(card.left, .01));
            expect(button.width, closeTo(card.width, .01));
            expect(button.bottom, closeTo(card.bottom, .01));
            expect(button.height, greaterThanOrEqualTo(48));
            expect(button.bottom, lessThanOrEqualTo(size.height));
            expect(action.hitTestable(), findsOneWidget);
          }
          await _capture(tester, '${size.width.toInt()}-$language');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final textScale in [1.6, 2.0]) {
    testWidgets('French text at $textScale keeps all card actions reachable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = AppState(
        authApi: _StaticAuthApi(),
        loadoutOwnershipApi: _NoopOwnershipApi(gold: 0),
      );
      addTearDown(app.dispose);
      await app.bootstrap(force: true);
      await tester.pumpWidget(
        _TestApp(
          appState: app,
          locale: const Locale('fr'),
          textScale: textScale,
        ),
      );
      await tester.pump();
      expect(
        find
            .byTooltip(appStringsFor(const Locale('fr')).uiOptions)
            .hitTestable(),
        findsOneWidget,
      );
      for (final key in ['weekly-play', 'weekly-leaderboard']) {
        final action = find.byKey(ValueKey(key));
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      }
      await _capture(tester, '568-fr-$textScale-top');
      final runnerCard = tester.getRect(find.byType(HubSelectCardFrame).first);
      final characterCard = tester.getRect(
        find.byType(HubSelectCardFrame).at(1),
      );
      expect(characterCard.top, greaterThan(runnerCard.bottom));
      for (final action in find.byType(HubCardAction).evaluate()) {
        final finder = find.byWidget(action.widget);
        await tester.ensureVisible(finder);
        await tester.pump();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: finder, matching: find.byType(Text)),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(finder.hitTestable(), findsOneWidget);
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(finder).top, greaterThanOrEqualTo(0));
        expect(tester.getRect(finder).bottom, lessThanOrEqualTo(320));
      }
      await _capture(tester, '568-fr-$textScale');
      final lastButton = tester.getRect(
        find.byKey(const ValueKey('hub-campaign-play')),
      );
      expect(lastButton.bottom, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('card selection and Play have independent navigation targets', (
    tester,
  ) async {
    final app = AppState(
      authApi: _StaticAuthApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(gold: 0),
    );
    addTearDown(app.dispose);
    final observer = _RecordingNavigatorObserver();
    await app.bootstrap(force: true);
    await tester.pumpWidget(_RoutedTestApp(appState: app, observer: observer));
    await tester.pump();
    for (final (index, route) in [
      (0, UiRoutes.setupLevel),
      (1, UiRoutes.selectCharacter),
      (2, UiRoutes.campaign),
    ]) {
      await tester.tap(
        find
            .ancestor(
              of: find.byType(HubSelectCardBody).at(index),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(observer.pushedRouteNames.last, route);
      Navigator.of(tester.element(find.text('Selection Placeholder'))).pop();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('hub-runner-play')));
    await tester.pump();
    expect(observer.pushedRouteNames.last, UiRoutes.runBootstrap);
  });

  testWidgets(
    'local practice has a compact status without disabled weekly actions',
    (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final app = AppState.developer(store: SharedPrefsDeveloperProfileStore());
      addTearDown(app.dispose);
      await app.bootstrap();
      final assets = UiAssetLifecycle();
      addTearDown(assets.dispose);
      await tester.runAsync(
        () => assets.getIdle(app.selection.selectedCharacterId),
      );
      await tester.pumpWidget(_TestApp(appState: app, assets: assets));
      await tester.pump();
      expect(find.text('Local practice'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WeeklyBadgeRow),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('hub-runner-play')).hitTestable(),
        findsOneWidget,
      );
      await _capture(tester, '568-practice');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'compact weekly actions retain full touch targets and semantics',
    (tester) async {
      var playCount = 0;
      var leaderboardCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: createUiTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 468,
                child: WeeklyBadgeRow(
                  title: 'Weekly Runner',
                  levelName: 'Field',
                  isWeeklyLoading: false,
                  onWeeklyPressed: () => playCount++,
                  onWeeklyLeaderboardPressed: () => leaderboardCount++,
                ),
              ),
            ),
          ),
        ),
      );
      final play = find.byKey(const ValueKey('weekly-play'));
      final leaderboard = find.byKey(const ValueKey('weekly-leaderboard'));
      expect(
        tester.getSize(find.byType(WeeklyBadgeRow)).height,
        lessThanOrEqualTo(56),
      );
      for (final button in [play, leaderboard]) {
        final size = tester.getSize(button);
        expect(size.width, inInclusiveRange(48, 95));
        expect(size.height, greaterThanOrEqualTo(48));
        final fill = find.descendant(
          of: button,
          matching: find.byType(ProgressMeter),
        );
        expect(tester.getSize(fill).height, lessThan(size.height));
        final data = tester.getSemantics(button).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      }
      // The area above the compact fill is still part of the touch target.
      await tester.tapAt(tester.getTopLeft(play) + const Offset(24, 2));
      await tester.pump();
      await tester.tap(leaderboard);
      await tester.pump();
      expect(playCount, 1);
      expect(leaderboardCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('weekly loading and unavailable actions cannot be activated', (
    tester,
  ) async {
    var playCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: createUiTheme(),
        home: Scaffold(
          body: WeeklyBadgeRow(
            title: 'Weekly Runner',
            isWeeklyLoading: true,
            onWeeklyPressed: () => playCount++,
            onWeeklyLeaderboardPressed: null,
          ),
        ),
      ),
    );
    for (final key in ['weekly-play', 'weekly-leaderboard']) {
      final action = find.byKey(ValueKey(key));
      await tester.tap(action);
      final data = tester.getSemantics(action).getSemanticsData();
      expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
    }
    expect(playCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly level name is independent of the Runner selection', (
    tester,
  ) async {
    final app = AppState(
      authApi: _StaticAuthApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(
        gold: 0,
        selection: SelectionState.defaults.copyWith(
          selectedLevelId: LevelId.forest,
        ),
      ),
    );
    addTearDown(app.dispose);
    await app.bootstrap(force: true);
    await tester.pumpWidget(_TestApp(appState: app));
    await tester.pump();
    expect(app.selection.selectedLevelId, LevelId.forest);
    expect(app.weeklyFeaturedLevelId, isNot(app.selection.selectedLevelId));
    final weekly = find.byType(WeeklyBadgeRow);
    expect(
      find.descendant(
        of: weekly,
        matching: find.text(
          app.weeklyFeaturedLevelId.localizedName(
            appStringsFor(const Locale('en')),
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final cleared in [false, true]) {
    testWidgets(
      'campaign quick play follows verified progress (cleared: $cleared)',
      (tester) async {
        final missions = CampaignCatalog.chapters
            .expand((chapter) => chapter.missions)
            .toList();
        final progress = cleared
            ? CampaignProgress.fromJson({
                'schemaVersion': 1,
                'missions': {
                  for (final mission in missions)
                    mission.id: {'cleared': true, 'attempts': 1, 'bests': {}},
                },
              })
            : CampaignProgress.empty;
        final app = AppState(
          authApi: _StaticAuthApi(),
          loadoutOwnershipApi: _NoopOwnershipApi(gold: 0, campaign: progress),
        );
        addTearDown(app.dispose);
        await app.bootstrap(force: true);
        final selection = app.selection;
        final observer = _RecordingNavigatorObserver();
        await tester.pumpWidget(
          _RoutedTestApp(appState: app, observer: observer),
        );
        await tester.pump();
        final campaignButton = find.descendant(
          of: find.byKey(const ValueKey('hub-campaign-play')),
          matching: find.byType(AppButton),
        );
        final eligible = missions
            .where(
              (mission) => mission.available && progress.isUnlocked(mission),
            )
            .toList();
        if (eligible.isEmpty) {
          expect(tester.widget<AppButton>(campaignButton).onPressed, isNull);
        } else {
          await tester.tap(campaignButton);
          await tester.pumpAndSettle();
          expect(observer.pushedRouteNames.last, UiRoutes.runBootstrap);
          final args = observer.lastArguments as RunStartBootstrapArgs;
          expect(args.campaignMissionId, eligible.last.id);
          expect(app.selection, same(selection));
          Navigator.of(tester.element(find.text('Run Bootstrap Placeholder')))
              .pop();
          await tester.pumpAndSettle();
          expect(tester.widget<AppButton>(campaignButton).onPressed, isNotNull);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'hub does not infer local earnings from server provisional gold',
    (tester) async {
      final runSessionApi = _StatusOnlyRunSessionApi(
        SubmissionStatus(
          runSessionId: 'run_hub_pending',
          state: RunSessionState.pendingValidation,
          updatedAtMs: 1,
          reward: SubmissionReward(
            status: SubmissionRewardStatus.provisional,
            provisionalGold: 17,
            effectiveGoldDelta: 0,
            spendableGoldDelta: 0,
            updatedAtMs: 1,
            grantId: 'run_hub_pending',
          ),
        ),
      );
      final coordinator = RunSubmissionCoordinator(
        runSessionApi: runSessionApi,
        spoolStore: _InMemorySpoolStore(),
      );
      final appState = AppState(
        authApi: _StaticAuthApi(),
        loadoutOwnershipApi: _NoopOwnershipApi(gold: 321),
        runSessionApi: runSessionApi,
        runSubmissionCoordinator: coordinator,
      );
      await appState.bootstrap(force: true);
      await appState.refreshRunSubmissionStatus(
        runSessionId: 'run_hub_pending',
      );

      await tester.pumpWidget(_TestApp(appState: appState));
      await tester.pump();

      final topRow = tester.widget<HubTopRow>(find.byType(HubTopRow));
      expect(topRow.gold, 321);
      final row = tester.getRect(find.byType(HubTopRow));
      final gold = tester.getRect(
        find.descendant(
          of: find.byType(HubTopRow),
          matching: find.byType(GoldDisplay),
        ),
      );
      expect(gold.left, greaterThan(row.center.dx));
    },
  );

  testWidgets('hub shows account level and XP beside player name', (
    tester,
  ) async {
    final appState = AppState(
      authApi: _StaticAuthApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(
        gold: 0,
        playerProgress: PlayerProgress(
          totalXp: 150,
          acceptedRuns: 2,
          damageDealt100: 0,
          damageTaken100: 0,
        ),
      ),
    );
    await appState.bootstrap(force: true);
    await tester.pumpWidget(_TestApp(appState: appState));
    await tester.pump();
    expect(find.text('LEVEL 2  ·  50 / 124 XP'), findsOneWidget);
    final name = tester.getRect(find.text('Guest'));
    final level = tester.getRect(find.text('LEVEL 2  ·  50 / 124 XP'));
    final bar = tester.getRect(find.byType(PlayerLevelBar));
    final gold = tester.getRect(
      find.descendant(
        of: find.byType(HubTopRow),
        matching: find.byType(GoldDisplay),
      ),
    );
    expect(level.left, greaterThan(name.right));
    expect((level.center.dy - name.center.dy).abs(), lessThan(2));
    expect(bar.width, greaterThan(190));
    expect(bar.right, lessThan(gold.left));
  });

  testWidgets('XP catches up through a level when returning from a run', (
    tester,
  ) async {
    final ownership = _NoopOwnershipApi(
      gold: 0,
      playerProgress: const PlayerProgress(
        totalXp: 90,
        acceptedRuns: 1,
        damageDealt100: 0,
        damageTaken100: 0,
      ),
    );
    final appState = AppState(
      authApi: _StaticAuthApi(),
      loadoutOwnershipApi: ownership,
    );
    await appState.bootstrap(force: true);
    await tester.pumpWidget(
      _RoutedTestApp(
        appState: appState,
        observer: _RecordingNavigatorObserver(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('hub-runner-play')));
    await tester.pump();
    ownership.playerProgress = const PlayerProgress(
      totalXp: 260,
      acceptedRuns: 2,
      damageDealt100: 0,
      damageTaken100: 0,
    );
    await appState.bootstrap(force: true);
    await tester.pump();

    Navigator.of(tester.element(find.text('Run Bootstrap Placeholder'))).pop();
    await tester.pump();
    expect(find.text('LEVEL 1  ·  90 / 100 XP'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.textContaining(RegExp(r'LEVEL 2  ·  \d+ / 124 XP')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('LEVEL 3  ·  36 / 154 XP'), findsOneWidget);
  });

  testWidgets(
    'local XP animates once and settlement keeps the displayed total',
    (tester) async {
      final ownership = _NoopOwnershipApi(
        gold: 100,
        playerProgress: const PlayerProgress(
          totalXp: 90,
          acceptedRuns: 1,
          damageDealt100: 0,
          damageTaken100: 0,
        ),
      );
      final app = AppState(
        authApi: _StaticAuthApi(),
        loadoutOwnershipApi: ownership,
        runSubmissionCoordinator: RunSubmissionCoordinator(
          runSessionApi: const NoopRunSessionApi(),
          spoolStore: _InMemorySpoolStore(),
        ),
      );
      addTearDown(app.dispose);
      await app.bootstrap(force: true);
      await tester.pumpWidget(
        _RoutedTestApp(appState: app, observer: _RecordingNavigatorObserver()),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('hub-runner-play')));
      await tester.pump();
      await app.journalRunReplay(
        runSessionId: 'hub_local_reward',
        runMode: RunMode.practice,
        replayArtifactId: 'replay',
        canonicalSha256: 'a' * 64,
        contentLengthBytes: 256,
        provisionalSummary: {'goldEarned': 17, 'score': 4000},
      );
      await tester.pump();
      Navigator.of(tester.element(find.text('Run Bootstrap Placeholder')))
          .pop();
      await tester.pump();
      expect(find.text('LEVEL 1  ·  90 / 100 XP'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('LEVEL 2  ·  10 / 124 XP'), findsOneWidget);
      expect(tester.widget<HubTopRow>(find.byType(HubTopRow)).gold, 117);
      expect(app.progression.playerProgress.totalXp, 90);
      expect(app.rewardDisplayRevision, isNull);

      ownership.gold = 117;
      ownership.revision = 1;
      ownership.appliedRewardGrantIds = ['hub_local_reward'];
      ownership.playerProgress = const PlayerProgress(
        totalXp: 110,
        acceptedRuns: 2,
        damageDealt100: 0,
        damageTaken100: 0,
      );
      await app.bootstrap(force: true);
      await tester.pump();
      expect(find.text('LEVEL 2  ·  10 / 124 XP'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('LEVEL 2  ·  10 / 124 XP'), findsOneWidget);
      expect(tester.widget<HubTopRow>(find.byType(HubTopRow)).gold, 117);
      expect(app.rewardDisplayRevision, 1);
    },
  );

  testWidgets('XP arriving after hub return fills from the previous total', (
    tester,
  ) async {
    final ownership = _NoopOwnershipApi(
      gold: 0,
      playerProgress: const PlayerProgress(
        totalXp: 90,
        acceptedRuns: 1,
        damageDealt100: 0,
        damageTaken100: 0,
      ),
    );
    final appState = AppState(
      authApi: _StaticAuthApi(),
      loadoutOwnershipApi: ownership,
    );
    await appState.bootstrap(force: true);
    await tester.pumpWidget(
      _RoutedTestApp(
        appState: appState,
        observer: _RecordingNavigatorObserver(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('hub-runner-play')));
    await tester.pump();
    await tester.pump();
    Navigator.of(tester.element(find.text('Run Bootstrap Placeholder'))).pop();
    await tester.pump();
    ownership.playerProgress = const PlayerProgress(
      totalXp: 110,
      acceptedRuns: 2,
      damageDealt100: 0,
      damageTaken100: 0,
    );
    await appState.bootstrap(force: true);
    await tester.pump();
    expect(find.text('LEVEL 1  ·  90 / 100 XP'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('LEVEL 2  ·  10 / 124 XP'), findsOneWidget);
  });

  testWidgets('wide hub bounds content and keeps status at its right edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final appState = AppState(
      authApi: _StaticAuthApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(
        gold: 321,
        playerProgress: const PlayerProgress(
          totalXp: 150,
          acceptedRuns: 2,
          damageDealt100: 0,
          damageTaken100: 0,
        ),
      ),
    );
    await appState.bootstrap(force: true);
    await tester.pumpWidget(_TestApp(appState: appState));
    await tester.pump();

    final row = tester.getRect(find.byType(HubTopRow));
    final time = tester.getRect(
      find.descendant(
        of: find.byType(HubTopRow),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(PlayerLevelBar));
    final cards = tester.getRect(find.byType(HubSelectCardFrame).last);
    expect(row.width, lessThanOrEqualTo(1100));
    expect(row.right, closeTo(cards.right, .01));
    expect(row.right, lessThan(1500));
    expect((row.right - time.right).abs(), lessThan(1));
    expect(bar.right, lessThan(time.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('play tap transitions immediately to run bootstrap route', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();
    final appState = AppState(
      authApi: _StaticAuthApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(gold: 321),
    );
    await appState.bootstrap(force: true);

    await tester.pumpWidget(
      _RoutedTestApp(appState: appState, observer: observer),
    );
    await tester.pump();

    final previewFinder = find.byType(
      FutureBuilder<IdleAnimBundle>,
      skipOffstage: false,
    );
    final idleFutureBeforeTap = tester
        .widget<FutureBuilder<IdleAnimBundle>>(previewFinder)
        .future;

    await tester.tap(find.byKey(const ValueKey('hub-runner-play')));
    await tester.pump();

    expect(observer.pushedRouteNames, contains(UiRoutes.runBootstrap));
    expect(
      (observer.lastArguments as RunStartBootstrapArgs).campaignMissionId,
      isNull,
    );
    expect(
      tester.widget<FutureBuilder<IdleAnimBundle>>(previewFinder).future,
      same(idleFutureBeforeTap),
    );
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.appState,
    this.locale = const Locale('en'),
    this.textScale = 1,
    this.assets,
  });

  final AppState appState;
  final Locale locale;
  final double textScale;
  final UiAssetLifecycle? assets;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        if (assets != null)
          Provider<UiAssetLifecycle>.value(value: assets!)
        else
          Provider<UiAssetLifecycle>(create: (_) => UiAssetLifecycle()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: RunnerLocalizations.delegates,
        supportedLocales: RunnerLocalizations.supportedLocales,
        theme: createUiTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const RepaintBoundary(
          key: ValueKey('hub-capture'),
          child: PlayHubPage(),
        ),
      ),
    );
  }
}

class _RoutedTestApp extends StatelessWidget {
  const _RoutedTestApp({required this.appState, required this.observer});

  final AppState appState;
  final NavigatorObserver observer;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        Provider<UiAssetLifecycle>(create: (_) => UiAssetLifecycle()),
      ],
      child: MaterialApp(
        theme: createUiTheme(),
        navigatorObservers: [observer],
        home: const PlayHubPage(),
        onGenerateRoute: (settings) {
          if ([
            UiRoutes.setupLevel,
            UiRoutes.selectCharacter,
            UiRoutes.campaign,
          ].contains(settings.name)) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  const Scaffold(body: Text('Selection Placeholder')),
            );
          }
          if (settings.name == UiRoutes.runBootstrap) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(
                body: Center(child: Text('Run Bootstrap Placeholder')),
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_HUB')) return;
  // Preview animations never settle. Allow asset I/O between bounded frames.
  for (var frame = 0; frame < 4; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('hub-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.tmp/hub-refresh-20261113').create(recursive: true);
    await File('.tmp/hub-refresh-20261113/hub-$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];
  Object? lastArguments;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushedRouteNames.add(route.settings.name);
    lastArguments = route.settings.arguments;
  }
}

class _StaticAuthApi implements AuthApi {
  @override
  Future<void> clearSession() async {}

  @override
  Future<AuthSession> ensureAuthenticatedSession() async {
    return const AuthSession(
      userId: 'hub_u1',
      sessionId: 'hub_s1',
      isAnonymous: true,
      expiresAtMs: 0,
    );
  }

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.alreadyLinked,
      session: const AuthSession(
        userId: 'hub_u1',
        sessionId: 'hub_s1',
        isAnonymous: true,
        expiresAtMs: 0,
      ),
    );
  }

  @override
  Future<AuthSession> loadSession() => ensureAuthenticatedSession();

  @override
  Future<AuthSession> reauthenticateForSensitiveOperation() =>
      ensureAuthenticatedSession();
}

class _NoopOwnershipApi extends LoadoutOwnershipApi {
  _NoopOwnershipApi({
    required this.gold,
    this.playerProgress,
    this.weekly,
    this.campaign,
    this.selection,
  });

  int gold;
  int revision = 0;
  List<String> appliedRewardGrantIds = [];
  PlayerProgress? playerProgress;
  final WeeklyProgressState? weekly;
  final CampaignProgress? campaign;
  final SelectionState? selection;

  OwnershipCanonicalState get _canonical => OwnershipCanonicalState(
    profileId: 'profile_hub',
    revision: revision,
    selection: selection ?? SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState.initial.copyWith(
      gold: gold,
      playerProgress: playerProgress,
      weekly: weekly,
      campaign: campaign,
      appliedRewardGrantIds: appliedRewardGrantIds,
    ),
  );

  OwnershipCommandResult get _accepted => OwnershipCommandResult(
    canonicalState: _canonical,
    newRevision: _canonical.revision,
    replayedFromIdempotency: false,
  );

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonical;
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async =>
      _accepted;

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async => _accepted;

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async => _accepted;

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async => _accepted;

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async =>
      _accepted;

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async => _accepted;

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async => _accepted;
}

class _StatusOnlyRunSessionApi extends NoopRunSessionApi {
  _StatusOnlyRunSessionApi(this.status);

  final SubmissionStatus status;

  @override
  Future<RunSubmissionResponse> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    return RunSubmissionResponse(
      SubmissionStatus(
        runSessionId: runSessionId,
        state: status.state,
        updatedAtMs: status.updatedAtMs,
        message: status.message,
        validatedRun: status.validatedRun,
        reward: status.reward,
      ),
    );
  }
}

class _InMemorySpoolStore implements RunSubmissionSpoolStore {
  final Map<String, PendingRunSubmission> _entries =
      <String, PendingRunSubmission>{};

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  @override
  Future<PendingRunSubmission?> load({required String runSessionId}) async {
    return _entries[runSessionId];
  }

  @override
  Future<List<PendingRunSubmission>> loadAll() async {
    return _entries.values.toList(growable: false);
  }

  @override
  Future<void> remove({required String runSessionId}) async {
    _entries.remove(runSessionId);
  }

  @override
  Future<void> upsert({required PendingRunSubmission submission}) async {
    _entries[submission.runSessionId] = submission;
  }
}
