import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/meta/meta_state.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/local_loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/meta_store.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/selection_store.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'AppState applies stale-revision canonical state and recovers on next command',
    () async {
      final simulator = _OneShotConflictSimulator();
      final api = LocalLoadoutOwnershipApi(
        selectionStore: _MemorySelectionStore(),
        metaStore: _MemoryMetaStore(saved: const MetaService().createNew()),
        conflictSimulator: simulator,
      );
      final appState = AppState(
        loadoutOwnershipApi: api,
        userProfileStore: _MemoryUserProfileStore(),
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
    final api = LocalLoadoutOwnershipApi(
      selectionStore: _MemorySelectionStore(),
      metaStore: _MemoryMetaStore(saved: const MetaService().createNew()),
      authApi: authApi,
    );
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: api,
      userProfileStore: _MemoryUserProfileStore(),
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
    final api = LocalLoadoutOwnershipApi(
      selectionStore: _MemorySelectionStore(),
      metaStore: _MemoryMetaStore(saved: const MetaService().createNew()),
      authApi: authApi,
    );
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: api,
      userProfileStore: _MemoryUserProfileStore(),
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

class _MemorySelectionStore extends SelectionStore {
  _MemorySelectionStore({SelectionState? saved})
    : saved = saved ?? SelectionState.defaults;

  SelectionState saved;

  @override
  Future<SelectionState> load() async => saved;

  @override
  Future<void> save(SelectionState state) async {
    saved = state;
  }
}

class _MemoryMetaStore extends MetaStore {
  _MemoryMetaStore({required this.saved});

  MetaState saved;

  @override
  Future<MetaState> load(MetaService service) async => saved;

  @override
  Future<void> save(MetaState state) async {
    saved = state;
  }
}

class _MemoryUserProfileStore extends UserProfileStore {
  _MemoryUserProfileStore({UserProfile? saved})
    : saved =
          saved ?? UserProfile.createNew(profileId: 'test_profile', nowMs: 1);

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

class _OneShotConflictSimulator implements OwnershipConflictSimulator {
  bool _used = false;

  @override
  bool shouldForceConflictForNextCommand() {
    if (_used) return false;
    _used = true;
    return true;
  }
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
    if (!_session.isAuthenticated) {
      return AuthLinkResult(
        provider: provider,
        status: AuthLinkStatus.failed,
        session: _session,
      );
    }
    if (_session.isProviderLinked(provider)) {
      return AuthLinkResult(
        provider: provider,
        status: AuthLinkStatus.alreadyLinked,
        session: _session,
      );
    }
    final nextProviders = <AuthLinkProvider>{
      ..._session.linkedProviders,
      provider,
    };
    final upgraded = _session.copyWith(
      isAnonymous: false,
      linkedProviders: nextProviders,
      sessionId: '${_session.sessionId}_linked',
    );
    _session = upgraded;
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.linked,
      session: upgraded,
    );
  }

  @override
  Future<void> clearSession() async {
    _session = AuthSession.unauthenticated;
  }
}
