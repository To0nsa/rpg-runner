import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/meta/meta_state.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/local_loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/meta_store.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/selection_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profileId = 'p1';
  const userId = 'u1';
  const sessionId = 's1';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('LocalLoadoutOwnershipApi revision + idempotency', () {
    test('expected revision match applies and increments revision', () async {
      final api = _buildApi();
      final canonical = await api.loadCanonicalState(
        profileId: profileId,
        userId: userId,
        sessionId: sessionId,
      );
      expect(canonical.revision, 0);

      final result = await api.setLoadout(
        SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
          expectedRevision: canonical.revision,
          commandId: 'cmd-1',
          characterId: PlayerCharacterId.eloise,
          loadout: const EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.holyBolt,
          ),
        ),
      );

      expect(result.accepted, isTrue);
      expect(result.newRevision, 1);
      expect(
        result.canonicalState.selection
            .loadoutFor(PlayerCharacterId.eloise)
            .projectileSlotSpellId,
        ProjectileId.holyBolt,
      );
    });

    test('stale revision rejects and keeps canonical state', () async {
      final api = _buildApi();
      final canonical = await api.loadCanonicalState(
        profileId: profileId,
        userId: userId,
        sessionId: sessionId,
      );

      final result = await api.setLoadout(
        SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
          expectedRevision: canonical.revision + 1,
          commandId: 'cmd-stale',
          characterId: PlayerCharacterId.eloise,
          loadout: const EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.holyBolt,
          ),
        ),
      );

      expect(result.accepted, isFalse);
      expect(result.rejectedReason, OwnershipRejectedReason.staleRevision);
      expect(result.newRevision, canonical.revision);
      expect(
        result.canonicalState.selection
            .loadoutFor(PlayerCharacterId.eloise)
            .projectileSlotSpellId,
        canonical.selection
            .loadoutFor(PlayerCharacterId.eloise)
            .projectileSlotSpellId,
      );
    });

    test(
      'duplicate commandId with same payload replays previous result',
      () async {
        final api = _buildApi();
        final canonical = await api.loadCanonicalState(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
        );
        const commandId = 'cmd-replay';
        final command = SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
          expectedRevision: canonical.revision,
          commandId: commandId,
          characterId: PlayerCharacterId.eloise,
          loadout: const EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.holyBolt,
          ),
        );

        final first = await api.setLoadout(command);
        final second = await api.setLoadout(command);

        expect(first.accepted, isTrue);
        expect(second.accepted, isTrue);
        expect(second.replayedFromIdempotency, isTrue);
        expect(second.newRevision, first.newRevision);
        expect(second.canonicalState.revision, first.canonicalState.revision);
      },
    );

    test('duplicate commandId with different payload rejects', () async {
      final api = _buildApi();
      final canonical = await api.loadCanonicalState(
        profileId: profileId,
        userId: userId,
        sessionId: sessionId,
      );
      const commandId = 'cmd-mismatch';

      final first = await api.setLoadout(
        SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
          expectedRevision: canonical.revision,
          commandId: commandId,
          characterId: PlayerCharacterId.eloise,
          loadout: const EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.holyBolt,
          ),
        ),
      );

      final second = await api.setLoadout(
        SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
          expectedRevision: first.newRevision,
          commandId: commandId,
          characterId: PlayerCharacterId.eloise,
          loadout: const EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.acidBolt,
          ),
        ),
      );

      expect(first.accepted, isTrue);
      expect(second.accepted, isFalse);
      expect(
        second.rejectedReason,
        OwnershipRejectedReason.idempotencyKeyReuseMismatch,
      );
      expect(second.newRevision, first.newRevision);
    });

    test('conflict simulator can force stale revision rejection', () async {
      final simulator = _OneShotConflictSimulator();
      final api = _buildApi(conflictSimulator: simulator);
      final canonical = await api.loadCanonicalState(
        profileId: profileId,
        userId: userId,
        sessionId: sessionId,
      );

      final stale = await api.setLoadout(
        SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
          expectedRevision: canonical.revision,
          commandId: 'cmd-conflict-1',
          characterId: PlayerCharacterId.eloise,
          loadout: const EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.holyBolt,
          ),
        ),
      );

      expect(stale.accepted, isFalse);
      expect(stale.rejectedReason, OwnershipRejectedReason.staleRevision);
      expect(stale.newRevision, canonical.revision + 1);

      final recovered = await api.setLoadout(
        SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
          expectedRevision: stale.newRevision,
          commandId: 'cmd-conflict-2',
          characterId: PlayerCharacterId.eloise,
          loadout: const EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.holyBolt,
          ),
        ),
      );

      expect(recovered.accepted, isTrue);
      expect(recovered.newRevision, stale.newRevision + 1);
    });

    test('unauthenticated commands are rejected as unauthorized', () async {
      final api = _buildApi(authApi: _TestAuthApi.unauthenticated());

      final result = await api.setLoadout(
        const SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
          expectedRevision: 0,
          commandId: 'cmd-unauthorized',
          characterId: PlayerCharacterId.eloise,
          loadout: EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.holyBolt,
          ),
        ),
      );

      expect(result.accepted, isFalse);
      expect(result.rejectedReason, OwnershipRejectedReason.unauthorized);
      expect(result.newRevision, 0);
    });

    test('session rotation invalidates stale actor session ids', () async {
      final authApi = _TestAuthApi.authenticated(
        userId: userId,
        sessionId: sessionId,
      );
      final api = _buildApi(authApi: authApi);
      final canonical = await api.loadCanonicalState(
        profileId: profileId,
        userId: userId,
        sessionId: sessionId,
      );
      expect(canonical.revision, 0);

      authApi.setSession(_makeSession(userId: userId, sessionId: 's2'));

      final staleSessionResult = await api.setLoadout(
        const SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
          expectedRevision: 0,
          commandId: 'cmd-stale-session',
          characterId: PlayerCharacterId.eloise,
          loadout: EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.holyBolt,
          ),
        ),
      );
      expect(staleSessionResult.accepted, isFalse);
      expect(
        staleSessionResult.rejectedReason,
        OwnershipRejectedReason.unauthorized,
      );

      final currentSessionResult = await api.setLoadout(
        const SetLoadoutCommand(
          profileId: profileId,
          userId: userId,
          sessionId: 's2',
          expectedRevision: 0,
          commandId: 'cmd-current-session',
          characterId: PlayerCharacterId.eloise,
          loadout: EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.holyBolt,
          ),
        ),
      );
      expect(currentSessionResult.accepted, isTrue);
      expect(currentSessionResult.newRevision, 1);
    });
  });
}

LocalLoadoutOwnershipApi _buildApi({
  OwnershipConflictSimulator? conflictSimulator,
  AuthApi? authApi,
}) {
  return LocalLoadoutOwnershipApi(
    selectionStore: _MemorySelectionStore(),
    metaStore: _MemoryMetaStore(saved: const MetaService().createNew()),
    authApi:
        authApi ?? _TestAuthApi.authenticated(userId: 'u1', sessionId: 's1'),
    conflictSimulator: conflictSimulator,
  );
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

class _OneShotConflictSimulator implements OwnershipConflictSimulator {
  bool _used = false;

  @override
  bool shouldForceConflictForNextCommand() {
    if (_used) return false;
    _used = true;
    return true;
  }
}

AuthSession _makeSession({required String userId, required String sessionId}) {
  return AuthSession(
    userId: userId,
    sessionId: sessionId,
    isAnonymous: true,
    expiresAtMs: 0,
  );
}

class _TestAuthApi implements AuthApi {
  _TestAuthApi(this._session);

  factory _TestAuthApi.authenticated({
    required String userId,
    required String sessionId,
  }) {
    return _TestAuthApi(_makeSession(userId: userId, sessionId: sessionId));
  }

  factory _TestAuthApi.unauthenticated() {
    return _TestAuthApi(AuthSession.unauthenticated);
  }

  AuthSession _session;

  void setSession(AuthSession session) {
    _session = session;
  }

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

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
