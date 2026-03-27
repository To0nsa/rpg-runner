import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:rpg_runner/ui/state/profile/account_deletion_api.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/state/profile/user_profile.dart';
import 'package:rpg_runner/ui/state/profile/user_profile_remote_api.dart';

void main() {
  test('deleteAccountAndData clears in-memory state and signs out', () async {
    final authApi = _StaticAuthApi();
    final deletionApi = _StaticAccountDeletionApi(
      result: const AccountDeletionResult(
        status: AccountDeletionStatus.deleted,
      ),
    );
    final appState = AppState(
      authApi: authApi,
      accountDeletionApi: deletionApi,
      userProfileRemoteApi: const _StaticUserProfileRemoteApi(
        profile: UserProfile(
          displayName: 'Hero',
          displayNameLastChangedAtMs: 1,
          namePromptCompleted: true,
        ),
      ),
      loadoutOwnershipApi: _NoopOwnershipApi(profileId: 'profile_u1'),
    );

    await appState.bootstrap(force: true);
    final result = await appState.deleteAccountAndData();

    expect(result.succeeded, isTrue);
    expect(deletionApi.calls.length, 1);
    expect(deletionApi.calls.single.userId, 'u1');
    expect(deletionApi.calls.single.sessionId, 's1');
    expect(authApi.clearSessionCalls, 1);
    expect(appState.authSession.userId, isEmpty);
    expect(appState.profile.displayName, isEmpty);
    expect(appState.progression.gold, 0);
    expect(appState.isBootstrapped, isFalse);
  });

  test(
    'deleteAccountAndData keeps state when backend deletion fails',
    () async {
      final authApi = _StaticAuthApi();
      final deletionApi = _StaticAccountDeletionApi(
        result: const AccountDeletionResult(
          status: AccountDeletionStatus.failed,
          errorCode: 'internal',
        ),
      );
      final appState = AppState(
        authApi: authApi,
        accountDeletionApi: deletionApi,
        userProfileRemoteApi: const _StaticUserProfileRemoteApi(
          profile: UserProfile(
            displayName: 'Hero',
            displayNameLastChangedAtMs: 1,
            namePromptCompleted: true,
          ),
        ),
        loadoutOwnershipApi: _NoopOwnershipApi(profileId: 'profile_u1'),
      );

      await appState.bootstrap(force: true);
      final result = await appState.deleteAccountAndData();

      expect(result.status, AccountDeletionStatus.failed);
      expect(authApi.clearSessionCalls, 0);
      expect(appState.authSession.userId, 'u1');
      expect(appState.profile.displayName, 'Hero');
      expect(appState.profileId, 'profile_u1');
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
  }) async {
    calls.add(_DeleteCall(userId: userId, sessionId: sessionId));
    return result;
  }
}

class _DeleteCall {
  const _DeleteCall({required this.userId, required this.sessionId});

  final String userId;
  final String sessionId;
}

class _StaticUserProfileRemoteApi implements UserProfileRemoteApi {
  const _StaticUserProfileRemoteApi({required this.profile});

  final UserProfile profile;

  @override
  Future<UserProfile> loadProfile({
    required String userId,
    required String sessionId,
  }) async {
    return profile;
  }

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  }) async {
    return profile.copyWith(
      displayName: update.displayName,
      displayNameLastChangedAtMs: update.displayNameLastChangedAtMs,
      namePromptCompleted: update.namePromptCompleted,
    );
  }
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
      progression: const ProgressionState(gold: 7),
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

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async {
    return _accepted();
  }
}
