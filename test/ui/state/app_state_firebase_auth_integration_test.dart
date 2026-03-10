import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/meta/meta_state.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/firebase_auth_api.dart';
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
    'bootstrap signs in anonymously when Firebase session is missing',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final source = _FakeFirebaseAuthSessionSource(
        current: null,
        anonymousSignInSession: _snapshot(
          userId: 'anon_u1',
          token: 'token_u1_bootstrap',
          now: now,
        ),
      );
      final authApi = FirebaseAuthApi(source: source, now: () => now);
      final ownershipApi = LocalLoadoutOwnershipApi(
        selectionStore: _MemorySelectionStore(),
        metaStore: _MemoryMetaStore(saved: const MetaService().createNew()),
        authApi: authApi,
      );
      final appState = AppState(
        authApi: authApi,
        loadoutOwnershipApi: ownershipApi,
        userProfileStore: _MemoryUserProfileStore(),
      );

      await appState.bootstrap(force: true);

      expect(appState.isBootstrapped, isTrue);
      expect(appState.authSession.userId, 'anon_u1');
      expect(appState.authSession.isAnonymous, isTrue);
      expect(
        appState.authSession.isAuthenticatedAt(now.millisecondsSinceEpoch),
        isTrue,
      );
      expect(source.signInAnonymouslyCalls, 1);
    },
  );

  test('bootstrap refreshes expired Firebase token/session', () async {
    final now = DateTime.utc(2026, 3, 10, 12);
    final expired = _snapshot(
      userId: 'anon_u1',
      token: 'token_expired',
      now: now.subtract(const Duration(hours: 1)),
      expiresAt: now.subtract(const Duration(seconds: 30)),
    );
    final refreshed = _snapshot(
      userId: 'anon_u1',
      token: 'token_refreshed',
      now: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    final source = _FakeFirebaseAuthSessionSource(
      current: expired,
      anonymousSignInSession: refreshed,
    )..enqueueForceRefresh(refreshed);
    final authApi = FirebaseAuthApi(source: source, now: () => now);
    final ownershipApi = LocalLoadoutOwnershipApi(
      selectionStore: _MemorySelectionStore(),
      metaStore: _MemoryMetaStore(saved: const MetaService().createNew()),
      authApi: authApi,
    );
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: ownershipApi,
      userProfileStore: _MemoryUserProfileStore(),
    );

    await appState.bootstrap(force: true);

    expect(source.forceRefreshReadCalls, 1);
    expect(appState.authSession.userId, 'anon_u1');
    expect(
      appState.authSession.expiresAtMs,
      refreshed.expiresAt!.millisecondsSinceEpoch,
    );
    expect(
      appState.authSession.isAuthenticatedAt(now.millisecondsSinceEpoch),
      isTrue,
    );
  });

  test(
    'session change causes stale write once then AppState recovers',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final userA = _snapshot(
        userId: 'anon_user_a',
        token: 'token_user_a',
        now: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final userB = _snapshot(
        userId: 'anon_user_b',
        token: 'token_user_b',
        now: now.add(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final source = _FakeFirebaseAuthSessionSource(
        current: userA,
        anonymousSignInSession: userA,
      );
      final authApi = FirebaseAuthApi(source: source, now: () => now);
      final ownershipApi = LocalLoadoutOwnershipApi(
        selectionStore: _MemorySelectionStore(),
        metaStore: _MemoryMetaStore(saved: const MetaService().createNew()),
        authApi: authApi,
      );
      final appState = AppState(
        authApi: authApi,
        loadoutOwnershipApi: ownershipApi,
        userProfileStore: _MemoryUserProfileStore(),
      );

      await appState.bootstrap(force: true);
      await appState.setLoadout(
        const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.holyBolt),
      );
      expect(appState.ownershipRevision, 1);
      expect(
        appState.selection
            .loadoutFor(appState.selection.selectedCharacterId)
            .projectileSlotSpellId,
        ProjectileId.holyBolt,
      );

      source.setCurrent(userB);

      await appState.setLoadout(
        const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.holyBolt),
      );

      expect(appState.authSession.userId, 'anon_user_b');
      expect(appState.ownershipRevision, 0);
      expect(
        appState.selection
            .loadoutFor(appState.selection.selectedCharacterId)
            .projectileSlotSpellId,
        ProjectileId.acidBolt,
      );

      await appState.setLoadout(
        const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.holyBolt),
      );

      expect(appState.ownershipRevision, 1);
      expect(
        appState.selection
            .loadoutFor(appState.selection.selectedCharacterId)
            .projectileSlotSpellId,
        ProjectileId.holyBolt,
      );
    },
  );

  test('linkAuthProvider links Google and flips session anonymity', () async {
    final now = DateTime.utc(2026, 3, 10, 12);
    final anonymous = _snapshot(
      userId: 'anon_u1',
      token: 'token_anon',
      now: now,
      isAnonymous: true,
    );
    final linked = _snapshot(
      userId: 'anon_u1',
      token: 'token_linked',
      now: now.add(const Duration(minutes: 1)),
      isAnonymous: false,
      linkedProviders: const <AuthLinkProvider>{AuthLinkProvider.google},
    );
    final source =
        _FakeFirebaseAuthSessionSource(
          current: anonymous,
          anonymousSignInSession: anonymous,
        )..setLinkOutcome(
          AuthLinkProvider.google,
          _FakeUpgradeOutcome.linked(linked),
        );
    final authApi = FirebaseAuthApi(source: source, now: () => now);

    final result = await authApi.linkAuthProvider(AuthLinkProvider.google);

    expect(result.status, AuthLinkStatus.linked);
    expect(result.session.userId, 'anon_u1');
    expect(result.session.isAnonymous, isFalse);
    expect(result.session.isProviderLinked(AuthLinkProvider.google), isTrue);
    expect(source.linkProviderCalls, 1);
    expect(source.lastLinkedProvider, AuthLinkProvider.google);
  });

  test(
    'linkAuthProvider returns canceled when provider flow is aborted',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final anonymous = _snapshot(
        userId: 'anon_u1',
        token: 'token_anon',
        now: now,
        isAnonymous: true,
      );
      final source =
          _FakeFirebaseAuthSessionSource(
            current: anonymous,
            anonymousSignInSession: anonymous,
          )..setLinkOutcome(
            AuthLinkProvider.google,
            const _FakeUpgradeOutcome.canceled(),
          );
      final authApi = FirebaseAuthApi(source: source, now: () => now);

      final result = await authApi.linkAuthProvider(AuthLinkProvider.google);

      expect(result.status, AuthLinkStatus.canceled);
      expect(result.session.userId, 'anon_u1');
      expect(result.session.isAnonymous, isTrue);
    },
  );

  test(
    'linkAuthProvider links Play Games and flips session anonymity',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final anonymous = _snapshot(
        userId: 'anon_u1',
        token: 'token_anon',
        now: now,
        isAnonymous: true,
      );
      final linked = _snapshot(
        userId: 'anon_u1',
        token: 'token_play_games_linked',
        now: now.add(const Duration(minutes: 1)),
        isAnonymous: false,
        linkedProviders: const <AuthLinkProvider>{AuthLinkProvider.playGames},
      );
      final source =
          _FakeFirebaseAuthSessionSource(
            current: anonymous,
            anonymousSignInSession: anonymous,
          )..setLinkOutcome(
            AuthLinkProvider.playGames,
            _FakeUpgradeOutcome.linked(linked),
          );
      final authApi = FirebaseAuthApi(source: source, now: () => now);

      final result = await authApi.linkAuthProvider(AuthLinkProvider.playGames);

      expect(result.status, AuthLinkStatus.linked);
      expect(result.session.userId, 'anon_u1');
      expect(result.session.isAnonymous, isFalse);
      expect(
        result.session.isProviderLinked(AuthLinkProvider.playGames),
        isTrue,
      );
      expect(source.lastLinkedProvider, AuthLinkProvider.playGames);
    },
  );

  test(
    'linkAuthProvider returns unsupported when Play Games is unavailable',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final anonymous = _snapshot(
        userId: 'anon_u1',
        token: 'token_anon',
        now: now,
        isAnonymous: true,
      );
      final source =
          _FakeFirebaseAuthSessionSource(
            current: anonymous,
            anonymousSignInSession: anonymous,
          )..setLinkOutcome(
            AuthLinkProvider.playGames,
            _FakeUpgradeOutcome.error(
              UnsupportedError(
                'Play Games sign-in is supported on Android only.',
              ),
            ),
          );
      final authApi = FirebaseAuthApi(source: source, now: () => now);

      final result = await authApi.linkAuthProvider(AuthLinkProvider.playGames);

      expect(result.status, AuthLinkStatus.unsupported);
      expect(result.errorCode, 'provider-unsupported');
      expect(result.session.userId, 'anon_u1');
      expect(result.session.isAnonymous, isTrue);
    },
  );

  test(
    'linkAuthProvider can add Play Games for non-anonymous Google session',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final googleOnly = _snapshot(
        userId: 'u1',
        token: 'token_google',
        now: now,
        isAnonymous: false,
        linkedProviders: const <AuthLinkProvider>{AuthLinkProvider.google},
      );
      final googleAndPlayGames = _snapshot(
        userId: 'u1',
        token: 'token_google_play_games',
        now: now.add(const Duration(minutes: 1)),
        isAnonymous: false,
        linkedProviders: const <AuthLinkProvider>{
          AuthLinkProvider.google,
          AuthLinkProvider.playGames,
        },
      );
      final source =
          _FakeFirebaseAuthSessionSource(
            current: googleOnly,
            anonymousSignInSession: _snapshot(
              userId: 'anon_fallback',
              token: 'anon_fallback_token',
              now: now,
            ),
          )..setLinkOutcome(
            AuthLinkProvider.playGames,
            _FakeUpgradeOutcome.linked(googleAndPlayGames),
          );
      final authApi = FirebaseAuthApi(source: source, now: () => now);

      final result = await authApi.linkAuthProvider(AuthLinkProvider.playGames);

      expect(result.status, AuthLinkStatus.linked);
      expect(result.session.isAnonymous, isFalse);
      expect(result.session.isProviderLinked(AuthLinkProvider.google), isTrue);
      expect(
        result.session.isProviderLinked(AuthLinkProvider.playGames),
        isTrue,
      );
      expect(source.linkProviderCalls, 1);
      expect(source.lastLinkedProvider, AuthLinkProvider.playGames);
    },
  );

  test('linkAuthProvider returns alreadyLinked without source call', () async {
    final now = DateTime.utc(2026, 3, 10, 12);
    final googleOnly = _snapshot(
      userId: 'u1',
      token: 'token_google',
      now: now,
      isAnonymous: false,
      linkedProviders: const <AuthLinkProvider>{AuthLinkProvider.google},
    );
    final source = _FakeFirebaseAuthSessionSource(
      current: googleOnly,
      anonymousSignInSession: _snapshot(
        userId: 'anon_fallback',
        token: 'anon_fallback_token',
        now: now,
      ),
    );
    final authApi = FirebaseAuthApi(source: source, now: () => now);

    final result = await authApi.linkAuthProvider(AuthLinkProvider.google);

    expect(result.status, AuthLinkStatus.alreadyLinked);
    expect(result.session.userId, 'u1');
    expect(result.session.isProviderLinked(AuthLinkProvider.google), isTrue);
    expect(source.linkProviderCalls, 0);
  });
}

FirebaseAuthSessionSnapshot _snapshot({
  required String userId,
  required String token,
  required DateTime now,
  DateTime? expiresAt,
  bool isAnonymous = true,
  Set<AuthLinkProvider> linkedProviders = const <AuthLinkProvider>{},
}) {
  return FirebaseAuthSessionSnapshot(
    userId: userId,
    isAnonymous: isAnonymous,
    idToken: token,
    issuedAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(days: 365)),
    linkedProviders: linkedProviders,
  );
}

class _FakeFirebaseAuthSessionSource implements FirebaseAuthSessionSource {
  _FakeFirebaseAuthSessionSource({
    required FirebaseAuthSessionSnapshot? current,
    required FirebaseAuthSessionSnapshot anonymousSignInSession,
  }) : _current = current,
       _anonymousSignInSession = anonymousSignInSession;

  FirebaseAuthSessionSnapshot? _current;
  final FirebaseAuthSessionSnapshot _anonymousSignInSession;
  final List<FirebaseAuthSessionSnapshot?> _forceRefreshQueue =
      <FirebaseAuthSessionSnapshot?>[];
  final Map<AuthLinkProvider, _FakeUpgradeOutcome> _upgradeOutcomes =
      <AuthLinkProvider, _FakeUpgradeOutcome>{};

  int signInAnonymouslyCalls = 0;
  int forceRefreshReadCalls = 0;
  int linkProviderCalls = 0;
  AuthLinkProvider? lastLinkedProvider;

  void enqueueForceRefresh(FirebaseAuthSessionSnapshot? snapshot) {
    _forceRefreshQueue.add(snapshot);
  }

  void setLinkOutcome(AuthLinkProvider provider, _FakeUpgradeOutcome outcome) {
    _upgradeOutcomes[provider] = outcome;
  }

  void setCurrent(FirebaseAuthSessionSnapshot? snapshot) {
    _current = snapshot;
  }

  @override
  Future<FirebaseAuthSessionSnapshot?> readCurrent({
    required bool forceRefresh,
  }) async {
    if (forceRefresh) {
      forceRefreshReadCalls += 1;
      if (_forceRefreshQueue.isNotEmpty) {
        _current = _forceRefreshQueue.removeAt(0);
      }
    }
    return _current;
  }

  @override
  Future<FirebaseAuthSessionSnapshot> signInAnonymously() async {
    signInAnonymouslyCalls += 1;
    _current = _anonymousSignInSession;
    return _anonymousSignInSession;
  }

  @override
  Future<FirebaseAuthSessionSnapshot?> linkAuthProvider(
    AuthLinkProvider provider,
  ) async {
    linkProviderCalls += 1;
    lastLinkedProvider = provider;
    final outcome = _upgradeOutcomes[provider];
    if (outcome == null) {
      throw UnsupportedError('$provider is not supported by fake source.');
    }
    if (outcome.error != null) {
      throw outcome.error!;
    }
    if (outcome.canceled) {
      return null;
    }
    _current = outcome.snapshot;
    return outcome.snapshot;
  }

  @override
  Future<void> signOut() async {
    _current = null;
  }
}

class _FakeUpgradeOutcome {
  const _FakeUpgradeOutcome.linked(this.snapshot)
    : canceled = false,
      error = null;

  const _FakeUpgradeOutcome.canceled()
    : snapshot = null,
      canceled = true,
      error = null;

  const _FakeUpgradeOutcome.error(this.error)
    : snapshot = null,
      canceled = false;

  final FirebaseAuthSessionSnapshot? snapshot;
  final bool canceled;
  final Object? error;
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
