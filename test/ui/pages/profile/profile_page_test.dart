import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:runner_core/meta/meta_service.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:rpg_runner/ui/components/app_dialog.dart';
import 'package:rpg_runner/ui/components/gold_display.dart';
import 'package:rpg_runner/ui/pages/profile/profile_page.dart';
import 'package:rpg_runner/ui/state/account_deletion_api.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/run_session_api.dart';
import 'package:rpg_runner/ui/state/run_submission_coordinator.dart';
import 'package:rpg_runner/ui/state/run_submission_spool_store.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_remote_api.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets('shows Play Games upgrade action for anonymous account', (
    tester,
  ) async {
    final authApi = _StaticAuthApi(session: _anonymousSession());
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: _NoopOwnershipApi(),
    );
    await appState.bootstrap(force: true);

    await tester.pumpWidget(_TestApp(appState: appState));

    expect(find.text('Upgrade guest account'), findsOneWidget);
    expect(find.text('Link Play Games'), findsOneWidget);
  });

  testWidgets('hides Play Games upgrade action for non-anonymous account', (
    tester,
  ) async {
    final authApi = _StaticAuthApi(session: _playGamesLinkedSession());
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: _NoopOwnershipApi(),
    );
    await appState.bootstrap(force: true);

    await tester.pumpWidget(_TestApp(appState: appState));

    expect(find.text('Upgrade guest account'), findsNothing);
    expect(find.text('Link Play Games'), findsNothing);
  });

  testWidgets('profile gold row includes unverified gold from app state', (
    tester,
  ) async {
    final authApi = _StaticAuthApi(session: _anonymousSession());
    final runSessionApi = _StatusOnlyRunSessionApi(
      const SubmissionStatus(
        runSessionId: 'run_profile_pending',
        state: RunSessionState.pendingValidation,
        updatedAtMs: 1,
        reward: SubmissionReward(
          status: SubmissionRewardStatus.provisional,
          provisionalGold: 17,
          effectiveGoldDelta: 0,
          spendableGoldDelta: 0,
          updatedAtMs: 1,
          grantId: 'run_profile_pending',
        ),
      ),
    );
    final coordinator = RunSubmissionCoordinator(
      runSessionApi: runSessionApi,
      spoolStore: _InMemorySpoolStore(),
    );
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: _NoopOwnershipApi(gold: 222),
      runSessionApi: runSessionApi,
      runSubmissionCoordinator: coordinator,
    );
    await appState.bootstrap(force: true);
    await appState.refreshRunSubmissionStatus(
      runSessionId: 'run_profile_pending',
    );

    await tester.pumpWidget(_TestApp(appState: appState));
    await tester.pumpAndSettle();

    final goldWidget = tester.widget<GoldDisplay>(
      find.byWidgetPredicate((widget) {
        return widget is GoldDisplay &&
            widget.gold == 239 &&
            widget.variant == GoldDisplayVariant.body;
      }),
    );
    expect(goldWidget.gold, 239);
  });

  testWidgets('name edit shows specific duplicate-name error', (tester) async {
    final authApi = _StaticAuthApi(session: _anonymousSession());
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: _NoopOwnershipApi(),
      userProfileRemoteApi: const _FailingUserProfileRemoteApi(),
    );

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'HeroName');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('That name is already taken.'), findsOneWidget);
  });

  testWidgets(
    'delete account action requires two confirmations and calls app state flow',
    (tester) async {
      final authApi = _StaticAuthApi(session: _anonymousSession());
      final deletionApi = _StaticAccountDeletionApi(
        result: const AccountDeletionResult(
          status: AccountDeletionStatus.unsupported,
        ),
      );
      final appState = AppState(
        authApi: authApi,
        accountDeletionApi: deletionApi,
        loadoutOwnershipApi: _NoopOwnershipApi(),
      );

      await tester.pumpWidget(_TestApp(appState: appState));

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete account and data?'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Final confirmation'), findsOneWidget);

      await tester.tap(_dialogButton('Delete account'));
      await tester.pumpAndSettle();

      expect(deletionApi.calls, 1);
      expect(
        find.text('Account deletion is not available in this environment.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('successful delete account closes app', (tester) async {
    final authApi = _StaticAuthApi(session: _anonymousSession());
    final deletionApi = _StaticAccountDeletionApi(
      result: const AccountDeletionResult(
        status: AccountDeletionStatus.deleted,
      ),
    );
    final appState = AppState(
      authApi: authApi,
      accountDeletionApi: deletionApi,
      loadoutOwnershipApi: _NoopOwnershipApi(),
    );

    final platformCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(_dialogButton('Delete account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(deletionApi.calls, 1);
    expect(
      platformCalls.any((call) => call.method == 'SystemNavigator.pop'),
      isTrue,
    );
  });

  testWidgets('delete account shows loader while request is in flight', (
    tester,
  ) async {
    final authApi = _StaticAuthApi(session: _anonymousSession());
    final deletionApi = _PendingAccountDeletionApi();
    final appState = AppState(
      authApi: authApi,
      accountDeletionApi: deletionApi,
      loadoutOwnershipApi: _NoopOwnershipApi(),
    );

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(_dialogButton('Delete account'));
    await tester.pump();

    expect(deletionApi.calls, 1);
    expect(
      find.byKey(const Key('profile-delete-progress-indicator')),
      findsOneWidget,
    );

    deletionApi.complete(
      const AccountDeletionResult(status: AccountDeletionStatus.unsupported),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profile-delete-progress-indicator')),
      findsNothing,
    );
  });
}

Finder _dialogButton(String label) {
  return find.descendant(
    of: find.byType(AppDialog),
    matching: find.text(label),
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: [UiTokens.standard, UiButtonTheme.standard],
        ),
        home: const ProfilePage(),
      ),
    );
  }
}

class _StaticAuthApi implements AuthApi {
  _StaticAuthApi({required this.session});

  AuthSession session;

  @override
  Future<AuthSession> loadSession() async => session;

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => session;

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.alreadyLinked,
      session: session,
    );
  }

  @override
  Future<void> clearSession() async {
    session = AuthSession.unauthenticated;
  }
}

AuthSession _anonymousSession() {
  return const AuthSession(
    userId: 'anon_u1',
    sessionId: 'sess_anon',
    isAnonymous: true,
    expiresAtMs: 0,
  );
}

AuthSession _playGamesLinkedSession() {
  return const AuthSession(
    userId: 'user_u1',
    sessionId: 'sess_linked',
    isAnonymous: false,
    expiresAtMs: 0,
    linkedProviders: <AuthLinkProvider>{AuthLinkProvider.playGames},
  );
}

class _NoopOwnershipApi implements LoadoutOwnershipApi {
  _NoopOwnershipApi({this.gold = 0});

  final int gold;

  OwnershipCanonicalState get _canonical => OwnershipCanonicalState(
    profileId: 'profile_noop',
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
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
  ) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    return _accepted;
  }

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async {
    return _accepted;
  }
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

class _StaticAccountDeletionApi implements AccountDeletionApi {
  _StaticAccountDeletionApi({required this.result});

  final AccountDeletionResult result;
  int calls = 0;

  @override
  Future<AccountDeletionResult> deleteAccountAndData({
    required String userId,
    required String sessionId,
  }) async {
    calls += 1;
    return result;
  }
}

class _PendingAccountDeletionApi implements AccountDeletionApi {
  final Completer<AccountDeletionResult> _completer =
      Completer<AccountDeletionResult>();
  int calls = 0;

  void complete(AccountDeletionResult result) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete(result);
  }

  @override
  Future<AccountDeletionResult> deleteAccountAndData({
    required String userId,
    required String sessionId,
  }) async {
    calls += 1;
    return _completer.future;
  }
}

class _FailingUserProfileRemoteApi implements UserProfileRemoteApi {
  const _FailingUserProfileRemoteApi();

  @override
  Future<UserProfile> loadProfile({
    required String userId,
    required String sessionId,
  }) async {
    return UserProfile.empty;
  }

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  }) async {
    throw const UserProfileRemoteException(
      code: 'already-exists',
      message: 'displayName is already taken.',
    );
  }
}
