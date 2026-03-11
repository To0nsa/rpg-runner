import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/ui/state/account_deletion_api.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_store.dart';

void main() {
  test(
    'deleteAccountAndData clears local stores and resets app state',
    () async {
      final profile = UserProfile.createNew(profileId: 'profile_u1', nowMs: 1);
      final authApi = _StaticAuthApi();
      final deletionApi = _StaticAccountDeletionApi(
        result: const AccountDeletionResult(
          status: AccountDeletionStatus.deleted,
        ),
      );
      final profileStore = _MemoryUserProfileStore(saved: profile);
      final appState = AppState(
        authApi: authApi,
        accountDeletionApi: deletionApi,
        userProfileStore: profileStore,
        loadoutOwnershipApi: _NoopOwnershipApi(profileId: profile.profileId),
      );

      await appState.bootstrap(force: true);
      final result = await appState.deleteAccountAndData();

      expect(result.succeeded, isTrue);
      expect(deletionApi.calls.length, 1);
      expect(deletionApi.calls.single.userId, 'u1');
      expect(deletionApi.calls.single.sessionId, 's1');
      expect(deletionApi.calls.single.profileId, profile.profileId);
      expect(profileStore.clearCalls, 1);
      expect(authApi.clearSessionCalls, 1);
      expect(appState.authSession.userId, isEmpty);
      expect(appState.profile.profileId, 'guest');
      expect(appState.isBootstrapped, isFalse);
    },
  );

  test(
    'deleteAccountAndData keeps local state when backend deletion fails',
    () async {
      final profile = UserProfile.createNew(profileId: 'profile_u1', nowMs: 1);
      final authApi = _StaticAuthApi();
      final deletionApi = _StaticAccountDeletionApi(
        result: const AccountDeletionResult(
          status: AccountDeletionStatus.failed,
          errorCode: 'internal',
        ),
      );
      final profileStore = _MemoryUserProfileStore(saved: profile);
      final appState = AppState(
        authApi: authApi,
        accountDeletionApi: deletionApi,
        userProfileStore: profileStore,
        loadoutOwnershipApi: _NoopOwnershipApi(profileId: profile.profileId),
      );

      await appState.bootstrap(force: true);
      final result = await appState.deleteAccountAndData();

      expect(result.status, AccountDeletionStatus.failed);
      expect(profileStore.clearCalls, 0);
      expect(authApi.clearSessionCalls, 0);
      expect(appState.authSession.userId, 'u1');
      expect(appState.profile.profileId, profile.profileId);
      expect(appState.isBootstrapped, isTrue);
    },
  );
}

class _StaticAuthApi implements AuthApi {
  static const AuthSession _session = AuthSession(
    userId: 'u1',
    sessionId: 's1',
    isAnonymous: true,
    expiresAtMs: 0,
  );

  int clearSessionCalls = 0;

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
  Future<void> clearSession() async {
    clearSessionCalls += 1;
  }
}

class _StaticAccountDeletionApi implements AccountDeletionApi {
  _StaticAccountDeletionApi({required this.result});

  final AccountDeletionResult result;
  final List<_DeleteCall> calls = <_DeleteCall>[];

  @override
  Future<AccountDeletionResult> deleteAccountAndData({
    required String userId,
    required String sessionId,
    required String profileId,
  }) async {
    calls.add(
      _DeleteCall(userId: userId, sessionId: sessionId, profileId: profileId),
    );
    return result;
  }
}

class _DeleteCall {
  const _DeleteCall({
    required this.userId,
    required this.sessionId,
    required this.profileId,
  });

  final String userId;
  final String sessionId;
  final String profileId;
}

class _MemoryUserProfileStore extends UserProfileStore {
  _MemoryUserProfileStore({required this.saved});

  UserProfile saved;
  int clearCalls = 0;

  @override
  Future<UserProfile> load() async => saved;

  @override
  Future<void> save(UserProfile profile) async {
    saved = profile;
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
  }

  @override
  UserProfile createFresh() => saved;
}

class _NoopOwnershipApi implements LoadoutOwnershipApi {
  _NoopOwnershipApi({required this.profileId});

  final String profileId;
  final MetaService _metaService = const MetaService();

  OwnershipCanonicalState _canonical() {
    return OwnershipCanonicalState(
      profileId: profileId,
      revision: 0,
      selection: SelectionState.defaults,
      meta: _metaService.createNew(),
    );
  }

  OwnershipCommandResult _accepted() {
    final canonical = _canonical();
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    );
  }

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String profileId,
    required String userId,
    required String sessionId,
  }) async {
    return _canonical();
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
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
}
