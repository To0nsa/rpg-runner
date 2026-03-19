import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:run_protocol/submission_status.dart';

import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/components/app_button.dart';
import 'package:rpg_runner/ui/pages/hub/components/hub_top_row.dart';
import 'package:rpg_runner/ui/pages/hub/play_hub_page.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/run_session_api.dart';
import 'package:rpg_runner/ui/state/run_submission_coordinator.dart';
import 'package:rpg_runner/ui/state/run_submission_spool_store.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets('hub top row includes unverified gold from app state', (
    tester,
  ) async {
    final runSessionApi = _StatusOnlyRunSessionApi(
      const SubmissionStatus(
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
    expect(topRow.gold, 338);
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

    final playButtonFinder = find.byWidgetPredicate(
      (widget) => widget is AppButton && widget.label == 'PLAY',
    );
    await tester.tap(playButtonFinder.last);
    await tester.pump();

    expect(observer.pushedRouteNames, contains(UiRoutes.runBootstrap));
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
}

class _NoopOwnershipApi implements LoadoutOwnershipApi {
  _NoopOwnershipApi({required this.gold});

  final int gold;

  OwnershipCanonicalState get _canonical => OwnershipCanonicalState(
    profileId: 'profile_hub',
    revision: 0,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState.initial.copyWith(gold: gold),
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
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async => _accepted;

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async =>
      _accepted;

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async => _accepted;

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async => _accepted;

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async => _accepted;

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async => _accepted;

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
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

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async =>
      _accepted;
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
