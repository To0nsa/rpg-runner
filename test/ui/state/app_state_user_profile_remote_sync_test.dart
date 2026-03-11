import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_remote_api.dart';
import 'package:rpg_runner/ui/state/user_profile_store.dart';

void main() {
  test(
    'bootstrap adopts remote displayName into local profile store',
    () async {
      final store = _MemoryUserProfileStore(
        saved: UserProfile.createNew(profileId: 'test_profile', nowMs: 1),
      );
      final remoteApi = _FakeUserProfileRemoteApi(
        loadResult: const RemoteDisplayNameProfile(
          displayName: 'RemoteHero',
          displayNameLastChangedAtMs: 123,
        ),
      );
      final appState = AppState(
        authApi: const _StaticAuthApi(),
        loadoutOwnershipApi: _NoopOwnershipApi(),
        userProfileStore: store,
        userProfileRemoteApi: remoteApi,
      );

      await appState.bootstrap(force: true);

      expect(appState.profile.displayName, 'RemoteHero');
      expect(appState.profile.displayNameLastChangedAtMs, 123);
      expect(store.saved.displayName, 'RemoteHero');
      expect(remoteApi.savedCalls.length, 0);
    },
  );

  test(
    'bootstrap backfills remote displayName when remote is missing',
    () async {
      final local = UserProfile.createNew(
        profileId: 'test_profile',
        nowMs: 1,
      ).copyWith(displayName: 'LocalHero', displayNameLastChangedAtMs: 0);
      final remoteApi = _FakeUserProfileRemoteApi(loadResult: null);
      final appState = AppState(
        authApi: const _StaticAuthApi(),
        loadoutOwnershipApi: _NoopOwnershipApi(),
        userProfileStore: _MemoryUserProfileStore(saved: local),
        userProfileRemoteApi: remoteApi,
      );

      await appState.bootstrap(force: true);

      expect(remoteApi.savedCalls.length, 1);
      expect(remoteApi.savedCalls.single.displayName, 'LocalHero');
    },
  );

  test('updateProfile syncs remote only when displayName changes', () async {
    final remoteApi = _FakeUserProfileRemoteApi(loadResult: null);
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      userProfileStore: _MemoryUserProfileStore(
        saved: UserProfile.createNew(profileId: 'test_profile', nowMs: 1),
      ),
      userProfileRemoteApi: remoteApi,
    );

    await appState.bootstrap(force: true);
    remoteApi.clearSavedCalls();

    await appState.updateProfile((current) {
      return current.copyWith(counters: <String, int>{'gold': 10});
    });
    expect(remoteApi.savedCalls, isEmpty);

    await appState.updateProfile((current) {
      return current.copyWith(
        displayName: 'HeroName',
        displayNameLastChangedAtMs: 1700000000000,
      );
    });
    expect(remoteApi.savedCalls.length, 1);
    expect(remoteApi.savedCalls.single.displayName, 'HeroName');
    expect(
      remoteApi.savedCalls.single.displayNameLastChangedAtMs,
      1700000000000,
    );
  });

  test(
    'updateProfile keeps local name unchanged when remote save rejects',
    () async {
      final remoteApi = _FakeUserProfileRemoteApi(
        loadResult: null,
        saveError: StateError('already-exists'),
      );
      final appState = AppState(
        authApi: const _StaticAuthApi(),
        loadoutOwnershipApi: _NoopOwnershipApi(),
        userProfileStore: _MemoryUserProfileStore(
          saved: UserProfile.createNew(profileId: 'test_profile', nowMs: 1),
        ),
        userProfileRemoteApi: remoteApi,
      );

      await appState.bootstrap(force: true);

      await expectLater(
        () => appState.updateProfile((current) {
          return current.copyWith(
            displayName: 'TakenName',
            displayNameLastChangedAtMs: 1700000000000,
          );
        }),
        throwsA(isA<StateError>()),
      );
      expect(appState.profile.displayName, isEmpty);
    },
  );
}

class _MemoryUserProfileStore extends UserProfileStore {
  _MemoryUserProfileStore({required this.saved});

  UserProfile saved;

  @override
  Future<UserProfile> load() async => saved;

  @override
  Future<void> save(UserProfile profile) async {
    saved = profile;
  }

  @override
  UserProfile createFresh() => saved;
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
  final MetaService _metaService = const MetaService();

  OwnershipCanonicalState _canonical() {
    return OwnershipCanonicalState(
      profileId: 'test_profile',
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

class _FakeUserProfileRemoteApi implements UserProfileRemoteApi {
  _FakeUserProfileRemoteApi({required this.loadResult, this.saveError});

  final RemoteDisplayNameProfile? loadResult;
  final Object? saveError;
  final List<_SavedDisplayNameCall> savedCalls = <_SavedDisplayNameCall>[];

  @override
  Future<RemoteDisplayNameProfile?> loadDisplayName({
    required String userId,
    required String sessionId,
  }) async {
    return loadResult;
  }

  @override
  Future<void> saveDisplayName({
    required String userId,
    required String sessionId,
    required String displayName,
    required int displayNameLastChangedAtMs,
  }) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    savedCalls.add(
      _SavedDisplayNameCall(
        userId: userId,
        sessionId: sessionId,
        displayName: displayName,
        displayNameLastChangedAtMs: displayNameLastChangedAtMs,
      ),
    );
  }

  void clearSavedCalls() {
    savedCalls.clear();
  }
}

class _SavedDisplayNameCall {
  const _SavedDisplayNameCall({
    required this.userId,
    required this.sessionId,
    required this.displayName,
    required this.displayNameLastChangedAtMs,
  });

  final String userId;
  final String sessionId;
  final String displayName;
  final int displayNameLastChangedAtMs;
}
