import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:run_protocol/submission_status.dart';

import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/components/app_button.dart';
import 'package:rpg_runner/ui/components/gold_display.dart';
import 'package:rpg_runner/ui/components/player_level_bar.dart';
import 'package:rpg_runner/ui/pages/hub/components/hub_top_row.dart';
import 'package:rpg_runner/ui/pages/hub/play_hub_page.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/run/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/player_progress.dart';
import 'package:rpg_runner/ui/state/run/run_session_api.dart';
import 'package:rpg_runner/ui/state/run/run_submission_coordinator.dart';
import 'package:rpg_runner/ui/state/run/run_submission_spool_store.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets('hub top row excludes provisional gold from canonical wallet', (
    tester,
  ) async {
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
    await appState.refreshRunSubmissionStatus(runSessionId: 'run_hub_pending');

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
  });

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

    final play = find.byWidgetPredicate(
      (widget) => widget is AppButton && widget.label == 'PLAY',
    );
    await tester.tap(play.last);
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

    final play = find.byWidgetPredicate(
      (widget) => widget is AppButton && widget.label == 'PLAY',
    );
    await tester.tap(play.last);
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

  testWidgets('hub keeps gold and status at the far right on wide screens', (
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
    expect(row.right, greaterThan(1500));
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

    final playButtonFinder = find.byWidgetPredicate(
      (widget) => widget is AppButton && widget.label == 'PLAY',
    );
    await tester.tap(playButtonFinder.last);
    await tester.pump();

    expect(observer.pushedRouteNames, contains(UiRoutes.runBootstrap));
    expect(
      tester.widget<FutureBuilder<IdleAnimBundle>>(previewFinder).future,
      same(idleFutureBeforeTap),
    );
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        Provider<UiAssetLifecycle>(create: (_) => UiAssetLifecycle()),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: [UiTokens.standard, UiButtonTheme.standard],
        ),
        home: const PlayHubPage(),
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
        theme: ThemeData(
          useMaterial3: true,
          extensions: [UiTokens.standard, UiButtonTheme.standard],
        ),
        navigatorObservers: [observer],
        home: const PlayHubPage(),
        onGenerateRoute: (settings) {
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

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushedRouteNames.add(route.settings.name);
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
  _NoopOwnershipApi({required this.gold, this.playerProgress});

  final int gold;
  PlayerProgress? playerProgress;

  OwnershipCanonicalState get _canonical => OwnershipCanonicalState(
    profileId: 'profile_hub',
    revision: 0,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState.initial.copyWith(
      gold: gold,
      playerProgress: playerProgress,
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
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    return SubmissionStatus(
      runSessionId: runSessionId,
      state: status.state,
      updatedAtMs: status.updatedAtMs,
      message: status.message,
      validatedRun: status.validatedRun,
      reward: status.reward,
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
