import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/run_session_api.dart';
import 'package:rpg_runner/ui/state/run_start_remote_exception.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

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
      progression: ProgressionState.initial,
    );
    final ownershipApi = _ScriptedOwnershipApi(canonical);
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
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
        progression: ProgressionState.initial,
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
        progression: ProgressionState.initial,
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

  test(
    'prepareRunStartDescriptor uses current selected character loadout',
    () async {
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
          progression: ProgressionState.initial,
        ),
      );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: _ScriptedRunSessionApi(
          RunTicket(
            runSessionId: 'session_123',
            uid: 'u1',
            mode: RunMode.practice,
            seed: 123,
            tickHz: 60,
            gameCompatVersion: '2026.03.0',
            levelId: LevelId.field.name,
            playerCharacterId: PlayerCharacterId.eloise.name,
            loadoutSnapshot: <String, Object?>{
              'mask': loadout.mask,
              'mainWeaponId': loadout.mainWeaponId.name,
              'offhandWeaponId': loadout.offhandWeaponId.name,
              'spellBookId': loadout.spellBookId.name,
              'projectileSlotSpellId': loadout.projectileSlotSpellId.name,
              'accessoryId': loadout.accessoryId.name,
              'abilityPrimaryId': loadout.abilityPrimaryId,
              'abilitySecondaryId': loadout.abilitySecondaryId,
              'abilityProjectileId': loadout.abilityProjectileId,
              'abilitySpellId': loadout.abilitySpellId,
              'abilityMobilityId': loadout.abilityMobilityId,
              'abilityJumpId': loadout.abilityJumpId,
            },
            loadoutDigest:
                '0123456789012345678901234567890123456789012345678901234567890123',
            issuedAtMs: 1,
            expiresAtMs: 2,
            singleUseNonce: 'nonce_1',
          ),
        ),
      );
      await appState.bootstrap(force: true);

      final descriptor = await appState.prepareRunStartDescriptor();

      expect(
        descriptor.equippedLoadout.projectileSlotSpellId,
        ProjectileId.holyBolt,
      );
      expect(descriptor.equippedLoadout.abilitySpellId, 'eloise.focus');
      expect(descriptor.runSessionId, 'session_123');
      expect(descriptor.seed, 123);
    },
  );

  test(
    'prepareRunStartDescriptor fails fast when expected mode no longer matches canonical state',
    () async {
      final selection = SelectionState.defaults.copyWith(
        selectedRunMode: RunMode.competitive,
      );
      final ownershipApi = _ScriptedOwnershipApi(
        OwnershipCanonicalState(
          profileId: 'profile_restart_guard',
          revision: 2,
          selection: selection,
          meta: const MetaService().createNew(),
          progression: ProgressionState.initial,
        ),
      );
      final runSessionApi = _ScriptedRunSessionApi(_practiceTicket());
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
      );
      await appState.bootstrap(force: true);

      await expectLater(
        () =>
            appState.prepareRunStartDescriptor(expectedMode: RunMode.practice),
        throwsA(
          isA<RunStartRemoteException>().having(
            (value) => value.isPreconditionFailed,
            'isPreconditionFailed',
            isTrue,
          ),
        ),
      );
      expect(runSessionApi.createRunSessionCalls, 0);
    },
  );
}

class _ScriptedRunSessionApi implements RunSessionApi {
  _ScriptedRunSessionApi(this.ticket);

  final RunTicket ticket;
  int createRunSessionCalls = 0;

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    createRunSessionCalls += 1;
    return ticket;
  }

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    throw UnimplementedError('createUploadGrant is not used in this test.');
  }

  @override
  Future<SubmissionStatus> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) async {
    throw UnimplementedError('finalizeUpload is not used in this test.');
  }

  @override
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    throw UnimplementedError('loadSubmissionStatus is not used in this test.');
  }
}

RunTicket _practiceTicket() {
  return RunTicket(
    runSessionId: 'session_test',
    uid: 'u1',
    mode: RunMode.practice,
    seed: 123,
    tickHz: 60,
    gameCompatVersion: '2026.03.0',
    levelId: LevelId.field.name,
    playerCharacterId: PlayerCharacterId.eloise.name,
    loadoutSnapshot: const <String, Object?>{
      'mask': 0,
      'mainWeaponId': 'plainsteel',
      'offhandWeaponId': 'roadguard',
      'spellBookId': 'apprenticePrimer',
      'projectileSlotSpellId': 'iceBolt',
      'accessoryId': 'strengthBelt',
      'abilityPrimaryId': 'eloise.seeker_slash',
      'abilitySecondaryId': 'eloise.shield_block',
      'abilityProjectileId': 'eloise.snap_shot',
      'abilitySpellId': 'eloise.arcane_haste',
      'abilityMobilityId': 'eloise.dash',
      'abilityJumpId': 'eloise.jump',
    },
    loadoutDigest:
        '0123456789012345678901234567890123456789012345678901234567890123',
    issuedAtMs: 1,
    expiresAtMs: 2,
    singleUseNonce: 'nonce_test',
  );
}

class _ScriptedOwnershipApi implements LoadoutOwnershipApi {
  _ScriptedOwnershipApi(this._canonical);

  OwnershipCanonicalState _canonical;
  OwnershipCommandResult? nextSetLoadoutResult;
  int setLoadoutCalls = 0;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
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

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async {
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
