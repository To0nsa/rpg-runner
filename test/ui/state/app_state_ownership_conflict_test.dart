import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_store.dart';

void main() {
  test(
    'AppState applies stale-revision canonical state and recovers on next command',
    () async {
      final authApi = _QueueAuthApi(
        initial: _session(userId: 'u1', sessionId: 's1'),
      );
      final api = _RevisionedOwnershipApi(profileId: 'test_profile')
        ..forceStaleOnNextSetLoadout = true;
      final appState = AppState(
        authApi: authApi,
        loadoutOwnershipApi: api,
        userProfileStore: _MemoryUserProfileStore(
          saved: UserProfile.createNew(profileId: 'test_profile', nowMs: 1),
        ),
      );

      await appState.bootstrap(force: true);
      final initialRevision = appState.ownershipRevision;
      expect(initialRevision, 0);
      expect(
        appState.selection
            .loadoutFor(appState.selection.selectedCharacterId)
            .projectileSlotSpellId,
        ProjectileId.acidBolt,
      );

      await appState.setLoadout(
        const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.holyBolt),
      );

      // First mutation is force-conflicted and rejected as stale.
      expect(appState.ownershipRevision, initialRevision + 1);
      expect(
        appState.selection
            .loadoutFor(appState.selection.selectedCharacterId)
            .projectileSlotSpellId,
        ProjectileId.acidBolt,
      );

      await appState.setLoadout(
        const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.holyBolt),
      );

      expect(appState.ownershipRevision, initialRevision + 2);
      expect(
        appState.selection
            .loadoutFor(appState.selection.selectedCharacterId)
            .projectileSlotSpellId,
        ProjectileId.holyBolt,
      );
    },
  );

  test('bootstrap creates auth session when none exists', () async {
    final authApi = _QueueAuthApi(
      initial: AuthSession.unauthenticated,
      ensureResponses: <AuthSession>[_session(userId: 'u1', sessionId: 's1')],
    );
    final api = _RevisionedOwnershipApi(profileId: 'test_profile');
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: api,
      userProfileStore: _MemoryUserProfileStore(
        saved: UserProfile.createNew(profileId: 'test_profile', nowMs: 1),
      ),
    );

    await appState.bootstrap(force: true);

    expect(appState.isBootstrapped, isTrue);
    expect(appState.authSession.userId, 'u1');
    expect(appState.authSession.sessionId, 's1');
    expect(
      appState.authSession.isAuthenticatedAt(
        DateTime.now().millisecondsSinceEpoch,
      ),
      isTrue,
    );
    expect(authApi.ensureCallCount, 1);
  });

  test('bootstrap refreshes expired auth session', () async {
    final authApi = _QueueAuthApi(
      initial: const AuthSession(
        userId: 'u1',
        sessionId: 'expired',
        isAnonymous: true,
        expiresAtMs: 1,
      ),
      ensureResponses: <AuthSession>[
        _session(userId: 'u1', sessionId: 'fresh'),
      ],
    );
    final api = _RevisionedOwnershipApi(profileId: 'test_profile');
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: api,
      userProfileStore: _MemoryUserProfileStore(
        saved: UserProfile.createNew(profileId: 'test_profile', nowMs: 1),
      ),
    );

    await appState.bootstrap(force: true);

    expect(appState.authSession.sessionId, 'fresh');
    expect(
      appState.authSession.isAuthenticatedAt(
        DateTime.now().millisecondsSinceEpoch,
      ),
      isTrue,
    );
    expect(authApi.ensureCallCount, 1);
  });
}

class _RevisionedOwnershipApi implements LoadoutOwnershipApi {
  _RevisionedOwnershipApi({required String profileId})
    : _canonicalByUser = <String, OwnershipCanonicalState>{
        'u1': OwnershipCanonicalState(
          profileId: profileId,
          revision: 0,
          selection: SelectionState.defaults,
          meta: const MetaService().createNew(),
        ),
      };

  final Map<String, OwnershipCanonicalState> _canonicalByUser;
  bool forceStaleOnNextSetLoadout = false;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String profileId,
    required String userId,
    required String sessionId,
  }) async {
    return _canonicalByUser[userId] ??
        OwnershipCanonicalState(
          profileId: profileId,
          revision: 0,
          selection: SelectionState.defaults,
          meta: const MetaService().createNew(),
        );
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    var canonical = await loadCanonicalState(
      profileId: command.profileId,
      userId: command.userId,
      sessionId: command.sessionId,
    );
    if (forceStaleOnNextSetLoadout) {
      forceStaleOnNextSetLoadout = false;
      canonical = canonical.copyWith(revision: canonical.revision + 1);
      _canonicalByUser[command.userId] = canonical;
    }
    if (command.expectedRevision != canonical.revision) {
      return OwnershipCommandResult(
        canonicalState: canonical,
        newRevision: canonical.revision,
        replayedFromIdempotency: false,
        rejectedReason: OwnershipRejectedReason.staleRevision,
      );
    }
    final nextCanonical = canonical.copyWith(
      revision: canonical.revision + 1,
      selection: canonical.selection.withLoadoutFor(
        command.characterId,
        command.loadout,
      ),
    );
    _canonicalByUser[command.userId] = nextCanonical;
    return OwnershipCommandResult(
      canonicalState: nextCanonical,
      newRevision: nextCanonical.revision,
      replayedFromIdempotency: false,
    );
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    return _acceptedFor(command.userId);
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
  ) async {
    return _acceptedFor(command.userId);
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
    return _acceptedFor(command.userId);
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    return _acceptedFor(command.userId);
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async {
    return _acceptedFor(command.userId);
  }

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async {
    return _acceptedFor(command.userId);
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async {
    return _acceptedFor(command.userId);
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async {
    return _acceptedFor(command.userId);
  }

  OwnershipCommandResult _acceptedFor(String userId) {
    final canonical = _canonicalByUser[userId] ?? _canonicalByUser.values.first;
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    );
  }
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

AuthSession _session({required String userId, required String sessionId}) {
  return AuthSession(
    userId: userId,
    sessionId: sessionId,
    isAnonymous: true,
    expiresAtMs: 0,
  );
}

class _QueueAuthApi implements AuthApi {
  _QueueAuthApi({
    required AuthSession initial,
    List<AuthSession>? ensureResponses,
  }) : _session = initial,
       _ensureResponses = ensureResponses ?? <AuthSession>[];

  AuthSession _session;
  final List<AuthSession> _ensureResponses;
  int ensureCallCount = 0;

  @override
  Future<AuthSession> ensureAuthenticatedSession() async {
    ensureCallCount += 1;
    if (_ensureResponses.isNotEmpty) {
      _session = _ensureResponses.removeAt(0);
      return _session;
    }
    return _session;
  }

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
    _session = AuthSession.unauthenticated;
  }
}
