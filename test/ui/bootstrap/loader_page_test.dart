import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/bootstrap/app_bootstrapper.dart';
import 'package:rpg_runner/ui/bootstrap/loader_page.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_remote_api.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets('continue with defaults navigates when fallback succeeds', (
    tester,
  ) async {
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      userProfileRemoteApi: const _StaticUserProfileRemoteApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
    );
    final bootstrapper = _StaticBootstrapper(
      result: BootstrapResult.failure(
        StateError('bootstrap failed'),
        StackTrace.current,
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        appState: appState,
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bootstrap failed'), findsOneWidget);

    await tester.tap(find.text('Continue with defaults'));
    await tester.pumpAndSettle();

    expect(find.text('hub-page'), findsOneWidget);
  });

  testWidgets('continue with defaults keeps loader when fallback throws', (
    tester,
  ) async {
    final appState = AppState(
      authApi: const _FailingAuthApi(),
      userProfileRemoteApi: const _StaticUserProfileRemoteApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
    );
    final bootstrapper = _StaticBootstrapper(
      result: BootstrapResult.failure(
        StateError('bootstrap failed'),
        StackTrace.current,
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        appState: appState,
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Continue with defaults'));
    await tester.pumpAndSettle();

    expect(find.text('Bootstrap failed'), findsOneWidget);
    expect(find.textContaining('auth fallback failed'), findsOneWidget);
    expect(find.text('hub-page'), findsNothing);
  });

  testWidgets('long bootstrap error stays renderable without overflow', (
    tester,
  ) async {
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      userProfileRemoteApi: const _StaticUserProfileRemoteApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
    );
    final bootstrapper = _StaticBootstrapper(
      result: BootstrapResult.failure(
        StateError(List<String>.filled(80, 'very long bootstrap error').join('\n')),
        StackTrace.current,
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        appState: appState,
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bootstrap failed'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.appState,
    required this.bootstrapper,
  });

  final AppState appState;
  final AppBootstrapper bootstrapper;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: [UiTokens.standard],
        ),
        home: LoaderPage(
          args: const LoaderArgs(isResume: true),
          bootstrapper: bootstrapper,
        ),
        routes: <String, WidgetBuilder>{
          UiRoutes.setupProfileName: (_) => const _RouteMarker('setup-page'),
          UiRoutes.hub: (_) => const _RouteMarker('hub-page'),
        },
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _StaticBootstrapper extends AppBootstrapper {
  const _StaticBootstrapper({required this.result});

  final BootstrapResult result;

  @override
  Future<BootstrapResult> run(AppState appState, {required bool force}) async {
    return result;
  }
}

class _StaticAuthApi implements AuthApi {
  const _StaticAuthApi();

  static const AuthSession _session = AuthSession(
    userId: 'u1',
    sessionId: 's1',
    isAnonymous: true,
    expiresAtMs: 0,
  );

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

  @override
  Future<AuthSession> loadSession() async => _session;

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.alreadyLinked,
      session: _session,
    );
  }

  @override
  Future<void> clearSession() async {}
}

class _FailingAuthApi implements AuthApi {
  const _FailingAuthApi();

  @override
  Future<AuthSession> ensureAuthenticatedSession() async {
    throw StateError('auth fallback failed');
  }

  @override
  Future<AuthSession> loadSession() async {
    throw StateError('auth fallback failed');
  }

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    throw StateError('auth fallback failed');
  }

  @override
  Future<void> clearSession() async {}
}

class _StaticUserProfileRemoteApi implements UserProfileRemoteApi {
  const _StaticUserProfileRemoteApi();

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
    return UserProfile.empty.copyWith(
      displayName: update.displayName,
      displayNameLastChangedAtMs: update.displayNameLastChangedAtMs,
      namePromptCompleted: update.namePromptCompleted,
    );
  }
}

class _NoopOwnershipApi implements LoadoutOwnershipApi {
  final OwnershipCanonicalState _canonical = OwnershipCanonicalState(
    profileId: defaultOwnershipProfileId,
    revision: 0,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState.initial,
  );

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonical;
  }

  @override
  Future<OwnershipCommandResult> setSelection(SetSelectionCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> awardRunGold(AwardRunGoldCommand command) async {
    return _accepted();
  }

  OwnershipCommandResult _accepted() {
    return OwnershipCommandResult(
      canonicalState: _canonical,
      newRevision: _canonical.revision,
      replayedFromIdempotency: false,
    );
  }
}
