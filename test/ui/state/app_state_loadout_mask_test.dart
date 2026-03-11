import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_store.dart';

void main() {
  test('bootstrap hydrates AppState from canonical ownership state', () async {
    final customLoadout = const EquippedLoadoutDef(
      projectileSlotSpellId: ProjectileId.holyBolt,
      abilitySpellId: 'eloise.focus',
    );
    final canonicalSelection = SelectionState.defaults
        .copyWith(
          selectedCharacterId: PlayerCharacterId.eloiseWip,
          buildName: 'Hybrid Build',
        )
        .withLoadoutFor(PlayerCharacterId.eloiseWip, customLoadout);
    final canonical = OwnershipCanonicalState(
      profileId: 'profile_bootstrap',
      revision: 9,
      selection: canonicalSelection,
      meta: const MetaService().createNew(),
    );
    final ownershipApi = _ScriptedOwnershipApi(canonical);
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
      userProfileStore: _MemoryUserProfileStore(
        saved: UserProfile.createNew(profileId: 'profile_bootstrap', nowMs: 1),
      ),
    );

    await appState.bootstrap(force: true);

    expect(appState.ownershipRevision, 9);
    expect(appState.selection.selectedCharacterId, PlayerCharacterId.eloiseWip);
    expect(appState.selection.buildName, 'Hybrid Build');
    expect(
      appState.selection
          .loadoutFor(PlayerCharacterId.eloiseWip)
          .projectileSlotSpellId,
      ProjectileId.holyBolt,
    );
  });

  test(
    'setLoadout applies canonical command result from ownership API',
    () async {
      final initial = OwnershipCanonicalState(
        profileId: 'profile_set_loadout',
        revision: 0,
        selection: SelectionState.defaults,
        meta: const MetaService().createNew(),
      );
      final updatedSelection = SelectionState.defaults.withLoadoutFor(
        PlayerCharacterId.eloise,
        const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.holyBolt),
      );
      final updatedCanonical = OwnershipCanonicalState(
        profileId: 'profile_set_loadout',
        revision: 1,
        selection: updatedSelection,
        meta: const MetaService().createNew(),
      );
      final ownershipApi = _ScriptedOwnershipApi(initial)
        ..nextSetLoadoutResult = OwnershipCommandResult(
          canonicalState: updatedCanonical,
          newRevision: 1,
          replayedFromIdempotency: false,
        );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        userProfileStore: _MemoryUserProfileStore(
          saved: UserProfile.createNew(
            profileId: 'profile_set_loadout',
            nowMs: 1,
          ),
        ),
      );
      await appState.bootstrap(force: true);

      await appState.setLoadout(
        const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.holyBolt),
      );

      expect(ownershipApi.setLoadoutCalls, 1);
      expect(appState.ownershipRevision, 1);
      expect(
        appState.selection
            .loadoutFor(appState.selection.selectedCharacterId)
            .projectileSlotSpellId,
        ProjectileId.holyBolt,
      );
    },
  );

  test('buildRunStartArgs uses current selected character loadout', () async {
    final loadout = const EquippedLoadoutDef(
      projectileSlotSpellId: ProjectileId.holyBolt,
      abilitySpellId: 'eloise.focus',
    );
    final selection = SelectionState.defaults.withLoadoutFor(
      PlayerCharacterId.eloise,
      loadout,
    );
    final ownershipApi = _ScriptedOwnershipApi(
      OwnershipCanonicalState(
        profileId: 'profile_run_args',
        revision: 1,
        selection: selection,
        meta: const MetaService().createNew(),
      ),
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
      userProfileStore: _MemoryUserProfileStore(
        saved: UserProfile.createNew(profileId: 'profile_run_args', nowMs: 1),
      ),
    );
    await appState.bootstrap(force: true);

    final args = appState.buildRunStartArgs(seed: 123);

    expect(args.equippedLoadout.projectileSlotSpellId, ProjectileId.holyBolt);
    expect(args.equippedLoadout.abilitySpellId, 'eloise.focus');
  });
}

class _ScriptedOwnershipApi implements LoadoutOwnershipApi {
  _ScriptedOwnershipApi(this._canonical);

  OwnershipCanonicalState _canonical;
  OwnershipCommandResult? nextSetLoadoutResult;
  int setLoadoutCalls = 0;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String profileId,
    required String userId,
    required String sessionId,
  }) async {
    return _canonical;
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    setLoadoutCalls += 1;
    final scripted = nextSetLoadoutResult;
    if (scripted != null) {
      nextSetLoadoutResult = null;
      _canonical = scripted.canonicalState;
      return scripted;
    }
    final nextCanonical = _canonical.copyWith(
      revision: _canonical.revision + 1,
      selection: _canonical.selection.withLoadoutFor(
        command.characterId,
        command.loadout,
      ),
    );
    _canonical = nextCanonical;
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
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async {
    return _acceptedNoop();
  }

  OwnershipCommandResult _acceptedNoop() {
    return OwnershipCommandResult(
      canonicalState: _canonical,
      newRevision: _canonical.revision,
      replayedFromIdempotency: false,
    );
  }
}

class _StaticAuthApi implements AuthApi {
  _StaticAuthApi._(this._session);

  factory _StaticAuthApi.authenticated() {
    return _StaticAuthApi._(
      const AuthSession(
        userId: 'u1',
        sessionId: 's1',
        isAnonymous: true,
        expiresAtMs: 0,
      ),
    );
  }

  final AuthSession _session;

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
