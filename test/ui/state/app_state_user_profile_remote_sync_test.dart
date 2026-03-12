import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_remote_api.dart';

void main() {
  test('bootstrap loads remote profile before canonical ownership', () async {
    final remoteApi = _FakeUserProfileRemoteApi(
      loadedProfile: const UserProfile(
        displayName: 'RemoteHero',
        displayNameLastChangedAtMs: 123,
        namePromptCompleted: true,
      ),
    );
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      userProfileRemoteApi: remoteApi,
    );

    await appState.bootstrap(force: true);

    expect(appState.profile.displayName, 'RemoteHero');
    expect(appState.profile.displayNameLastChangedAtMs, 123);
    expect(appState.profile.namePromptCompleted, isTrue);
    expect(appState.progression.gold, 5);
    expect(remoteApi.loadCalls, 1);
  });

  test('updateDisplayName updates remote profile and local state', () async {
    final remoteApi = _FakeUserProfileRemoteApi(
      loadedProfile: const UserProfile(
        displayName: '',
        displayNameLastChangedAtMs: 0,
        namePromptCompleted: false,
      ),
    );
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      userProfileRemoteApi: remoteApi,
    );

    await appState.bootstrap(force: true);
    await appState.updateDisplayName('HeroName');

    expect(remoteApi.updateCalls.length, 1);
    expect(remoteApi.updateCalls.single.update.displayName, 'HeroName');
    expect(appState.profile.displayName, 'HeroName');
  });

  test(
    'completeNamePrompt can update flag without changing the name',
    () async {
      final remoteApi = _FakeUserProfileRemoteApi(
        loadedProfile: const UserProfile(
          displayName: '',
          displayNameLastChangedAtMs: 0,
          namePromptCompleted: false,
        ),
      );
      final appState = AppState(
        authApi: const _StaticAuthApi(),
        loadoutOwnershipApi: _NoopOwnershipApi(),
        userProfileRemoteApi: remoteApi,
      );

      await appState.bootstrap(force: true);
      await appState.completeNamePrompt();

      expect(remoteApi.updateCalls.length, 1);
      expect(remoteApi.updateCalls.single.update.displayName, isNull);
      expect(remoteApi.updateCalls.single.update.namePromptCompleted, isTrue);
      expect(appState.profile.namePromptCompleted, isTrue);
    },
  );

  test(
    'awardRunGold updates canonical progression without touching profile',
    () async {
      final remoteApi = _FakeUserProfileRemoteApi(
        loadedProfile: const UserProfile(
          displayName: 'Hero',
          displayNameLastChangedAtMs: 10,
          namePromptCompleted: true,
        ),
      );
      final ownershipApi = _NoopOwnershipApi();
      final appState = AppState(
        authApi: const _StaticAuthApi(),
        loadoutOwnershipApi: ownershipApi,
        userProfileRemoteApi: remoteApi,
      );

      await appState.bootstrap(force: true);
      await appState.awardRunGold(runId: 99, goldEarned: 7);

      expect(ownershipApi.awardRunGoldCalls.length, 1);
      expect(ownershipApi.awardRunGoldCalls.single.runId, 99);
      expect(appState.progression.gold, 12);
      expect(appState.profile.displayName, 'Hero');
      expect(remoteApi.updateCalls, isEmpty);
    },
  );

  test('awardRunGold retries staleRevision with a fresh command id', () async {
    final remoteApi = _FakeUserProfileRemoteApi(
      loadedProfile: const UserProfile(
        displayName: 'Hero',
        displayNameLastChangedAtMs: 10,
        namePromptCompleted: true,
      ),
    );
    final ownershipApi = _NoopOwnershipApi(staleOnFirstAward: true);
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      loadoutOwnershipApi: ownershipApi,
      userProfileRemoteApi: remoteApi,
    );

    await appState.bootstrap(force: true);
    await appState.awardRunGold(runId: 100, goldEarned: 4);

    expect(ownershipApi.awardRunGoldCalls.length, 2);
    expect(ownershipApi.loadCanonicalStateCalls, 2);
    expect(
      ownershipApi.awardRunGoldCalls[0].commandId,
      isNot(ownershipApi.awardRunGoldCalls[1].commandId),
    );
    expect(appState.progression.gold, 9);
  });

  test(
    'updateDisplayName keeps local name unchanged when remote update rejects',
    () async {
      final remoteApi = _FakeUserProfileRemoteApi(
        loadedProfile: const UserProfile(
          displayName: '',
          displayNameLastChangedAtMs: 0,
          namePromptCompleted: false,
        ),
        updateError: StateError('already-exists'),
      );
      final appState = AppState(
        authApi: const _StaticAuthApi(),
        loadoutOwnershipApi: _NoopOwnershipApi(),
        userProfileRemoteApi: remoteApi,
      );

      await appState.bootstrap(force: true);

      await expectLater(
        () => appState.updateDisplayName('TakenName'),
        throwsA(isA<StateError>()),
      );
      expect(appState.profile.displayName, isEmpty);
    },
  );

  test(
    'applyDefaults falls back to empty profile when remote profile load fails',
    () async {
      final remoteApi = _FakeUserProfileRemoteApi(
        loadedProfile: const UserProfile(
          displayName: 'RemoteHero',
          displayNameLastChangedAtMs: 123,
          namePromptCompleted: true,
        ),
        loadError: StateError('profile load failed'),
      );
      final ownershipApi = _NoopOwnershipApi();
      final appState = AppState(
        authApi: const _StaticAuthApi(),
        loadoutOwnershipApi: ownershipApi,
        userProfileRemoteApi: remoteApi,
      );

      await appState.applyDefaults();

      expect(appState.isBootstrapped, isTrue);
      expect(appState.profile, UserProfile.empty);
      expect(appState.progression.gold, 5);
      expect(ownershipApi.resetOwnershipCalls, 1);
    },
  );

  test(
    'applyDefaults keeps local canonical defaults when ownership fallback fails',
    () async {
      final remoteApi = _FakeUserProfileRemoteApi(
        loadedProfile: const UserProfile(
          displayName: 'RemoteHero',
          displayNameLastChangedAtMs: 123,
          namePromptCompleted: true,
        ),
      );
      final ownershipApi = _NoopOwnershipApi(
        loadCanonicalError: StateError('ownership load failed'),
        resetError: StateError('ownership reset failed'),
      );
      final appState = AppState(
        authApi: const _StaticAuthApi(),
        loadoutOwnershipApi: ownershipApi,
        userProfileRemoteApi: remoteApi,
      );

      await appState.applyDefaults();

      expect(appState.isBootstrapped, isTrue);
      expect(appState.profile.displayName, 'RemoteHero');
      expect(appState.selection, SelectionState.defaults);
      expect(appState.progression, ProgressionState.initial);
      expect(appState.profileId, defaultOwnershipProfileId);
      expect(appState.ownershipRevision, 0);
      expect(ownershipApi.resetOwnershipCalls, 1);
    },
  );
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

class _NoopOwnershipApi implements LoadoutOwnershipApi {
  _NoopOwnershipApi({
    this.staleOnFirstAward = false,
    this.loadCanonicalError,
    this.resetError,
  });

  final bool staleOnFirstAward;
  final Object? loadCanonicalError;
  final Object? resetError;
  OwnershipCanonicalState _canonical = OwnershipCanonicalState(
    profileId: 'test_profile',
    revision: 0,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: const ProgressionState(gold: 5),
  );

  final List<AwardRunGoldCommand> awardRunGoldCalls = <AwardRunGoldCommand>[];
  int loadCanonicalStateCalls = 0;
  int resetOwnershipCalls = 0;
  bool _returnedStaleForAward = false;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    final error = loadCanonicalError;
    if (error != null) {
      throw error;
    }
    loadCanonicalStateCalls += 1;
    return _canonical;
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
    resetOwnershipCalls += 1;
    final error = resetError;
    if (error != null) {
      throw error;
    }
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
    awardRunGoldCalls.add(command);
    if (staleOnFirstAward && !_returnedStaleForAward) {
      _returnedStaleForAward = true;
      return OwnershipCommandResult(
        canonicalState: _canonical,
        newRevision: _canonical.revision,
        replayedFromIdempotency: false,
        rejectedReason: OwnershipRejectedReason.staleRevision,
      );
    }
    _canonical = _canonical.copyWith(
      revision: _canonical.revision + 1,
      progression: _canonical.progression.copyWith(
        gold: _canonical.progression.gold + command.goldEarned,
      ),
    );
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

  OwnershipCommandResult _accepted() {
    return OwnershipCommandResult(
      canonicalState: _canonical,
      newRevision: _canonical.revision,
      replayedFromIdempotency: false,
    );
  }
}

class _FakeUserProfileRemoteApi implements UserProfileRemoteApi {
  _FakeUserProfileRemoteApi({
    required this.loadedProfile,
    this.loadError,
    this.updateError,
  }) : _currentProfile = loadedProfile;

  final UserProfile loadedProfile;
  final Object? loadError;
  final Object? updateError;
  final List<_UserProfileUpdateCall> updateCalls = <_UserProfileUpdateCall>[];
  int loadCalls = 0;
  UserProfile _currentProfile;

  @override
  Future<UserProfile> loadProfile({
    required String userId,
    required String sessionId,
  }) async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    loadCalls += 1;
    return _currentProfile;
  }

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  }) async {
    final error = updateError;
    if (error != null) {
      throw error;
    }
    updateCalls.add(
      _UserProfileUpdateCall(
        userId: userId,
        sessionId: sessionId,
        update: update,
      ),
    );
    _currentProfile = _currentProfile.copyWith(
      displayName: update.displayName,
      displayNameLastChangedAtMs: update.displayNameLastChangedAtMs,
      namePromptCompleted: update.namePromptCompleted,
    );
    return _currentProfile;
  }
}

class _UserProfileUpdateCall {
  const _UserProfileUpdateCall({
    required this.userId,
    required this.sessionId,
    required this.update,
  });

  final String userId;
  final String sessionId;
  final UserProfileUpdate update;
}
