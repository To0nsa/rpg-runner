import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/firebase_auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bootstrap requires Play Games auth when Firebase session is missing',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final source = _FakeFirebaseAuthSessionSource(current: null);
      final authApi = FirebaseAuthApi(source: source, now: () => now);
      final ownershipApi = _SessionScopedOwnershipApi(
        profileId: 'test_profile',
      );
      final appState = AppState(
        authApi: authApi,
        loadoutOwnershipApi: ownershipApi,
      );

      await expectLater(
        appState.bootstrap(force: true),
        throwsA(isA<PlayGamesAuthRequiredException>()),
      );
      expect(appState.isBootstrapped, isFalse);
      expect(source.tryRestorePlayGamesSessionCalls, 1);
      expect(source.readCachedCurrentCalls, 1);
    },
  );

  test(
    'bootstrap restores Play Games session when Firebase session is missing',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final source = _FakeFirebaseAuthSessionSource(
        current: null,
        restoredSession: _snapshot(
          userId: 'restored_u1',
          token: 'token_restored',
          now: now,
        ),
      );
      final authApi = FirebaseAuthApi(source: source, now: () => now);
      final ownershipApi = _SessionScopedOwnershipApi(
        profileId: 'test_profile',
      );
      final appState = AppState(
        authApi: authApi,
        loadoutOwnershipApi: ownershipApi,
      );

      await appState.bootstrap(force: true);

      expect(appState.isBootstrapped, isTrue);
      expect(appState.authSession.userId, 'restored_u1');
      expect(appState.authSession.isAnonymous, isFalse);
      expect(
        appState.authSession.isProviderLinked(AuthLinkProvider.playGames),
        isTrue,
      );
      expect(source.tryRestorePlayGamesSessionCalls, 1);
      expect(source.readCachedCurrentCalls, 0);
    },
  );

  test(
    'bootstrap restores cached session when restore mutates current user',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final source = _FakeFirebaseAuthSessionSource(current: null)
        ..restoreSideEffectSession = _snapshot(
          userId: 'restored_u1',
          token: 'token_restored',
          now: now,
        );
      final authApi = FirebaseAuthApi(source: source, now: () => now);
      final ownershipApi = _SessionScopedOwnershipApi(
        profileId: 'test_profile',
      );
      final appState = AppState(
        authApi: authApi,
        loadoutOwnershipApi: ownershipApi,
      );

      await appState.bootstrap(force: true);

      expect(appState.isBootstrapped, isTrue);
      expect(appState.authSession.userId, 'restored_u1');
      expect(appState.authSession.isAnonymous, isFalse);
      expect(
        appState.authSession.isProviderLinked(AuthLinkProvider.playGames),
        isTrue,
      );
      expect(source.tryRestorePlayGamesSessionCalls, 1);
      expect(source.readCachedCurrentCalls, 1);
    },
  );

  test(
    'bootstrap falls back to cached Firebase user when token lookup fails offline',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final cachedCurrent = _snapshot(
        userId: 'restored_u1',
        token: 'token_cached',
        now: now,
        isAnonymous: false,
        linkedProviders: const <AuthLinkProvider>{AuthLinkProvider.playGames},
      );
      final source = _FakeFirebaseAuthSessionSource(current: cachedCurrent)
        ..readCurrentError = FirebaseAuthException(
          code: 'network-request-failed',
          message:
              'A network error (such as timeout, interrupted connection or unreachable host) has occurred.',
        );
      final authApi = FirebaseAuthApi(source: source, now: () => now);
      final ownershipApi = _SessionScopedOwnershipApi(
        profileId: 'test_profile',
      );
      final appState = AppState(
        authApi: authApi,
        loadoutOwnershipApi: ownershipApi,
      );

      await appState.bootstrap(force: true);

      expect(appState.isBootstrapped, isTrue);
      expect(appState.authSession.userId, 'restored_u1');
      expect(appState.authSession.isAnonymous, isFalse);
      expect(
        appState.authSession.isProviderLinked(AuthLinkProvider.playGames),
        isTrue,
      );
      expect(source.readCachedCurrentCalls, 1);
      expect(source.tryRestorePlayGamesSessionCalls, 0);
    },
  );

  test('bootstrap refreshes expired Firebase token/session', () async {
    final now = DateTime.utc(2026, 3, 10, 12);
    final expired = _snapshot(
      userId: 'u1',
      token: 'token_expired',
      now: now.subtract(const Duration(hours: 1)),
      expiresAt: now.subtract(const Duration(seconds: 30)),
    );
    final refreshed = _snapshot(
      userId: 'u1',
      token: 'token_refreshed',
      now: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    final source = _FakeFirebaseAuthSessionSource(current: expired)
      ..enqueueForceRefresh(refreshed);
    final authApi = FirebaseAuthApi(source: source, now: () => now);
    final ownershipApi = _SessionScopedOwnershipApi(profileId: 'test_profile');
    final appState = AppState(
      authApi: authApi,
      loadoutOwnershipApi: ownershipApi,
    );

    await appState.bootstrap(force: true);

    expect(source.forceRefreshReadCalls, 1);
    expect(appState.authSession.userId, 'u1');
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
        userId: 'user_a',
        token: 'token_user_a',
        now: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final userB = _snapshot(
        userId: 'user_b',
        token: 'token_user_b',
        now: now.add(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final source = _FakeFirebaseAuthSessionSource(current: userA);
      final authApi = FirebaseAuthApi(source: source, now: () => now);
      final ownershipApi = _SessionScopedOwnershipApi(
        profileId: 'test_profile',
      );
      final appState = AppState(
        authApi: authApi,
        loadoutOwnershipApi: ownershipApi,
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

      expect(appState.authSession.userId, 'user_b');
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

  test('ensureAuthenticatedSession is single-flight', () async {
    final now = DateTime.utc(2026, 3, 10, 12);
    final source = _FakeFirebaseAuthSessionSource(
      current: null,
      restoredSession: _snapshot(
        userId: 'u1',
        token: 'token_restored',
        now: now,
      ),
    );
    final authApi = FirebaseAuthApi(source: source, now: () => now);

    final sessions = await Future.wait(<Future<AuthSession>>[
      authApi.ensureAuthenticatedSession(),
      authApi.ensureAuthenticatedSession(),
    ]);

    expect(sessions[0].userId, 'u1');
    expect(sessions[1].userId, 'u1');
    expect(source.tryRestorePlayGamesSessionCalls, 1);
  });

  test(
    'linkAuthProvider throws when Play Games auth is not established',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final anonymous = _snapshot(
        userId: 'anon_u1',
        token: 'token_anon',
        now: now,
        isAnonymous: true,
        linkedProviders: const <AuthLinkProvider>{},
      );
      final source = _FakeFirebaseAuthSessionSource(current: anonymous);
      final authApi = FirebaseAuthApi(source: source, now: () => now);

      await expectLater(
        authApi.linkAuthProvider(AuthLinkProvider.playGames),
        throwsA(isA<PlayGamesAuthRequiredException>()),
      );
      expect(source.linkProviderCalls, 0);
    },
  );

  test('linkAuthProvider returns alreadyLinked without source call', () async {
    final now = DateTime.utc(2026, 3, 10, 12);
    final playGamesOnly = _snapshot(
      userId: 'u1',
      token: 'token_play_games',
      now: now,
      isAnonymous: false,
      linkedProviders: const <AuthLinkProvider>{AuthLinkProvider.playGames},
    );
    final source = _FakeFirebaseAuthSessionSource(current: playGamesOnly);
    final authApi = FirebaseAuthApi(source: source, now: () => now);

    final result = await authApi.linkAuthProvider(AuthLinkProvider.playGames);

    expect(result.status, AuthLinkStatus.alreadyLinked);
    expect(result.session.userId, 'u1');
    expect(result.session.isProviderLinked(AuthLinkProvider.playGames), isTrue);
    expect(source.linkProviderCalls, 0);
  });
}

FirebaseAuthSessionSnapshot _snapshot({
  required String userId,
  required String token,
  required DateTime now,
  DateTime? expiresAt,
  bool isAnonymous = false,
  Set<AuthLinkProvider> linkedProviders = const <AuthLinkProvider>{
    AuthLinkProvider.playGames,
  },
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
    this.restoredSession,
  }) : _current = current;

  FirebaseAuthSessionSnapshot? _current;
  FirebaseAuthSessionSnapshot? restoredSession;
  FirebaseAuthSessionSnapshot? restoreSideEffectSession;
  final List<FirebaseAuthSessionSnapshot?> _forceRefreshQueue =
      <FirebaseAuthSessionSnapshot?>[];
  Object? readCurrentError;

  int tryRestorePlayGamesSessionCalls = 0;
  int forceRefreshReadCalls = 0;
  int readCachedCurrentCalls = 0;
  int linkProviderCalls = 0;
  AuthLinkProvider? lastLinkedProvider;

  void enqueueForceRefresh(FirebaseAuthSessionSnapshot? snapshot) {
    _forceRefreshQueue.add(snapshot);
  }

  void setCurrent(FirebaseAuthSessionSnapshot? snapshot) {
    _current = snapshot;
  }

  @override
  Future<FirebaseAuthSessionSnapshot?> readCurrent({
    required bool forceRefresh,
  }) async {
    final error = readCurrentError;
    if (error != null) {
      throw error;
    }
    if (forceRefresh) {
      forceRefreshReadCalls += 1;
      if (_forceRefreshQueue.isNotEmpty) {
        _current = _forceRefreshQueue.removeAt(0);
      }
    }
    return _current;
  }

  @override
  Future<FirebaseAuthSessionSnapshot?> readCachedCurrent() async {
    readCachedCurrentCalls += 1;
    return _current;
  }

  @override
  Future<FirebaseAuthSessionSnapshot?> tryRestorePlayGamesSession() async {
    tryRestorePlayGamesSessionCalls += 1;
    final restored = restoredSession;
    if (restored != null) {
      _current = restored;
      return restored;
    }
    final sideEffect = restoreSideEffectSession;
    if (sideEffect != null) {
      _current = sideEffect;
    }
    return null;
  }

  @override
  Future<FirebaseAuthSessionSnapshot?> linkAuthProvider(
    AuthLinkProvider provider,
  ) async {
    linkProviderCalls += 1;
    lastLinkedProvider = provider;
    throw UnsupportedError('$provider is not supported by fake source.');
  }

  @override
  Future<void> signOut() async {
    _current = null;
  }
}

class _SessionScopedOwnershipApi implements LoadoutOwnershipApi {
  _SessionScopedOwnershipApi({required this.profileId});

  final String profileId;
  final Map<String, OwnershipCanonicalState> _canonicalByUser =
      <String, OwnershipCanonicalState>{};

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonicalFor(userId);
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    final canonical = _canonicalFor(command.userId);
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

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async {
    return _acceptedFor(command.userId);
  }

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    return _acceptedFor(command.userId);
  }

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async {
    return _acceptedFor(command.userId);
  }

  OwnershipCanonicalState _canonicalFor(String userId) {
    return _canonicalByUser.putIfAbsent(
      userId,
      () => OwnershipCanonicalState(
        profileId: profileId,
        revision: 0,
        selection: SelectionState.defaults,
        meta: const MetaService().createNew(),
        progression: ProgressionState.initial,
      ),
    );
  }

  OwnershipCommandResult _acceptedFor(String userId) {
    final canonical = _canonicalFor(userId);
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    );
  }
}
