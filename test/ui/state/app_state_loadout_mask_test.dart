import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/board_manifest.dart';
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/ghost_api.dart';
import 'package:rpg_runner/ui/state/ghost_replay_cache.dart';
import 'package:rpg_runner/ui/state/leaderboard_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/run_boards_api.dart';
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

  test(
    'prepareRunStartDescriptor carries board identity for ranked modes',
    () async {
      final boardKey = BoardKey(
        mode: RunMode.competitive,
        levelId: LevelId.field.name,
        windowId: '2026-03',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      );
      final selection = SelectionState.defaults.copyWith(
        selectedRunMode: RunMode.competitive,
        selectedLevelId: LevelId.field,
      );
      final ownershipApi = _ScriptedOwnershipApi(
        OwnershipCanonicalState(
          profileId: 'profile_ranked_descriptor',
          revision: 3,
          selection: selection,
          meta: const MetaService().createNew(),
          progression: ProgressionState.initial,
        ),
      );
      final runSessionApi = _ScriptedRunSessionApi(
        RunTicket(
          runSessionId: 'session_competitive',
          uid: 'u1',
          mode: RunMode.competitive,
          boardId: 'board_2026_03_field',
          boardKey: boardKey,
          seed: 999,
          tickHz: 60,
          gameCompatVersion: '2026.03.0',
          rulesetVersion: boardKey.rulesetVersion,
          scoreVersion: boardKey.scoreVersion,
          ghostVersion: 'ghost-v1',
          levelId: LevelId.field.name,
          playerCharacterId: PlayerCharacterId.eloise.name,
          loadoutSnapshot: _practiceTicket().loadoutSnapshot,
          loadoutDigest:
              '0123456789012345678901234567890123456789012345678901234567890123',
          issuedAtMs: 1,
          expiresAtMs: 2,
          singleUseNonce: 'nonce_competitive',
        ),
      );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
      );
      await appState.bootstrap(force: true);

      final descriptor = await appState.prepareRunStartDescriptor();

      expect(descriptor.runMode, RunMode.competitive);
      expect(descriptor.boardId, 'board_2026_03_field');
      expect(descriptor.boardKey, boardKey);
    },
  );

  test(
    'prepareRunStartDescriptor does not preflight run boards before creating run session',
    () async {
      final boardKey = BoardKey(
        mode: RunMode.competitive,
        levelId: LevelId.field.name,
        windowId: '2026-03',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      );
      final selection = SelectionState.defaults.copyWith(
        selectedRunMode: RunMode.competitive,
        selectedLevelId: LevelId.field,
      );
      final ownershipApi = _ScriptedOwnershipApi(
        OwnershipCanonicalState(
          profileId: 'profile_ranked_board_soft_fail',
          revision: 3,
          selection: selection,
          meta: const MetaService().createNew(),
          progression: ProgressionState.initial,
        ),
      );
      final runSessionApi = _RecordingRunSessionApi(
        RunTicket(
          runSessionId: 'session_competitive_after_soft_fail',
          uid: 'u1',
          mode: RunMode.competitive,
          boardId: 'board_2026_03_field',
          boardKey: boardKey,
          seed: 999,
          tickHz: 60,
          gameCompatVersion: '2026.03.0',
          rulesetVersion: boardKey.rulesetVersion,
          scoreVersion: boardKey.scoreVersion,
          ghostVersion: 'ghost-v1',
          levelId: LevelId.field.name,
          playerCharacterId: PlayerCharacterId.eloise.name,
          loadoutSnapshot: _practiceTicket().loadoutSnapshot,
          loadoutDigest:
              '0123456789012345678901234567890123456789012345678901234567890123',
          issuedAtMs: 1,
          expiresAtMs: 2,
          singleUseNonce: 'nonce_competitive_soft_fail',
        ),
      );
      final runBoardsApi = _ThrowingRunBoardsApi(
        const RunStartRemoteException(
          code: 'failed-precondition',
          message: 'board preflight should not be called',
        ),
      );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runBoardsApi: runBoardsApi,
        runSessionApi: runSessionApi,
      );
      await appState.bootstrap(force: true);

      final descriptor = await appState.prepareRunStartDescriptor();

      expect(runBoardsApi.loadCalls, 0);
      expect(runSessionApi.createRunSessionCalls, 1);
      expect(descriptor.runMode, RunMode.competitive);
      expect(descriptor.boardId, 'board_2026_03_field');
    },
  );

  test(
    'prepareRunStartDescriptor does not attach ghost bootstrap unless a ghost entry is requested',
    () async {
      final boardKey = BoardKey(
        mode: RunMode.competitive,
        levelId: LevelId.field.name,
        windowId: '2026-03',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      );
      final selection = SelectionState.defaults.copyWith(
        selectedRunMode: RunMode.competitive,
        selectedLevelId: LevelId.field,
      );
      final ownershipApi = _ScriptedOwnershipApi(
        OwnershipCanonicalState(
          profileId: 'profile_ghost_bootstrap_soft_fail',
          revision: 3,
          selection: selection,
          meta: const MetaService().createNew(),
          progression: ProgressionState.initial,
        ),
      );
      final runSessionApi = _RecordingRunSessionApi(
        RunTicket(
          runSessionId: 'session_competitive_ghost_bootstrap_fail',
          uid: 'u1',
          mode: RunMode.competitive,
          boardId: 'board_2026_03_field',
          boardKey: boardKey,
          seed: 999,
          tickHz: 60,
          gameCompatVersion: '2026.03.0',
          rulesetVersion: boardKey.rulesetVersion,
          scoreVersion: boardKey.scoreVersion,
          ghostVersion: 'ghost-v1',
          levelId: LevelId.field.name,
          playerCharacterId: PlayerCharacterId.eloise.name,
          loadoutSnapshot: _practiceTicket().loadoutSnapshot,
          loadoutDigest:
              '0123456789012345678901234567890123456789012345678901234567890123',
          issuedAtMs: 1,
          expiresAtMs: 2,
          singleUseNonce: 'nonce_competitive_ghost_bootstrap_fail',
        ),
      );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
        leaderboardApi: const _SingleGhostEntryLeaderboardApi(),
        ghostApi: const _SingleGhostManifestApi(),
        ghostReplayCache: const _ThrowingGhostReplayCache(
          RunStartRemoteException(
            code: 'ghost-download-failed',
            message: 'Ghost download failed with status 403.',
          ),
        ),
      );
      await appState.bootstrap(force: true);

      final descriptor = await appState.prepareRunStartDescriptor();

      expect(runSessionApi.createRunSessionCalls, 1);
      expect(descriptor.boardId, 'board_2026_03_field');
      expect(descriptor.ghostReplayBootstrap, isNull);
    },
  );

  test(
    'prepareRunStartDescriptor with blank ghostEntryId skips ghost bootstrap fetch',
    () async {
      final boardKey = BoardKey(
        mode: RunMode.competitive,
        levelId: LevelId.field.name,
        windowId: '2026-03',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      );
      final selection = SelectionState.defaults.copyWith(
        selectedRunMode: RunMode.competitive,
        selectedLevelId: LevelId.field,
      );
      final ownershipApi = _ScriptedOwnershipApi(
        OwnershipCanonicalState(
          profileId: 'profile_blank_ghost_entry_skips_fetch',
          revision: 3,
          selection: selection,
          meta: const MetaService().createNew(),
          progression: ProgressionState.initial,
        ),
      );
      final runSessionApi = _RecordingRunSessionApi(
        RunTicket(
          runSessionId: 'session_competitive_blank_ghost_entry',
          uid: 'u1',
          mode: RunMode.competitive,
          boardId: 'board_2026_03_field',
          boardKey: boardKey,
          seed: 999,
          tickHz: 60,
          gameCompatVersion: '2026.03.0',
          rulesetVersion: boardKey.rulesetVersion,
          scoreVersion: boardKey.scoreVersion,
          ghostVersion: 'ghost-v1',
          levelId: LevelId.field.name,
          playerCharacterId: PlayerCharacterId.eloise.name,
          loadoutSnapshot: _practiceTicket().loadoutSnapshot,
          loadoutDigest:
              '0123456789012345678901234567890123456789012345678901234567890123',
          issuedAtMs: 1,
          expiresAtMs: 2,
          singleUseNonce: 'nonce_competitive_blank_ghost_entry',
        ),
      );
      final ghostApi = _RecordingGhostManifestApi();
      final ghostReplayCache = _RecordingGhostReplayCacheForMaskTests();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
        ghostApi: ghostApi,
        ghostReplayCache: ghostReplayCache,
      );
      await appState.bootstrap(force: true);

      final descriptor = await appState.prepareRunStartDescriptor(
        ghostEntryId: '   ',
      );

      expect(runSessionApi.createRunSessionCalls, 1);
      expect(descriptor.boardId, 'board_2026_03_field');
      expect(descriptor.ghostReplayBootstrap, isNull);
      expect(ghostApi.loadCalls, 0);
      expect(ghostReplayCache.loadCalls, 0);
    },
  );

  test(
    'prepareRunStartDescriptor fetches requested ghost entry using ticket boardId',
    () async {
      final boardKey = BoardKey(
        mode: RunMode.competitive,
        levelId: LevelId.field.name,
        windowId: '2026-03',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      );
      final selection = SelectionState.defaults.copyWith(
        selectedRunMode: RunMode.competitive,
        selectedLevelId: LevelId.field,
      );
      final ownershipApi = _ScriptedOwnershipApi(
        OwnershipCanonicalState(
          profileId: 'profile_requested_ghost_fetch',
          revision: 3,
          selection: selection,
          meta: const MetaService().createNew(),
          progression: ProgressionState.initial,
        ),
      );
      final runSessionApi = _RecordingRunSessionApi(
        RunTicket(
          runSessionId: 'session_competitive_requested_ghost_fetch',
          uid: 'u1',
          mode: RunMode.competitive,
          boardId: 'board_2026_03_field',
          boardKey: boardKey,
          seed: 999,
          tickHz: 60,
          gameCompatVersion: '2026.03.0',
          rulesetVersion: boardKey.rulesetVersion,
          scoreVersion: boardKey.scoreVersion,
          ghostVersion: 'ghost-v1',
          levelId: LevelId.field.name,
          playerCharacterId: PlayerCharacterId.eloise.name,
          loadoutSnapshot: _practiceTicket().loadoutSnapshot,
          loadoutDigest:
              '0123456789012345678901234567890123456789012345678901234567890123',
          issuedAtMs: 1,
          expiresAtMs: 2,
          singleUseNonce: 'nonce_competitive_requested_ghost_fetch',
        ),
      );
      final ghostApi = _RecordingGhostManifestApi();
      final ghostReplayCache = _RecordingGhostReplayCacheForMaskTests();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
        ghostApi: ghostApi,
        ghostReplayCache: ghostReplayCache,
      );
      await appState.bootstrap(force: true);

      final descriptor = await appState.prepareRunStartDescriptor(
        ghostEntryId: 'entry_ghost_42',
      );

      expect(runSessionApi.createRunSessionCalls, 1);
      expect(descriptor.boardId, 'board_2026_03_field');
      expect(descriptor.ghostReplayBootstrap, isNotNull);
      expect(ghostApi.loadCalls, 1);
      expect(ghostApi.lastBoardId, 'board_2026_03_field');
      expect(ghostApi.lastEntryId, 'entry_ghost_42');
      expect(ghostReplayCache.loadCalls, 1);
      expect(ghostReplayCache.lastManifestBoardId, 'board_2026_03_field');
      expect(ghostReplayCache.lastManifestEntryId, 'entry_ghost_42');
    },
  );

  test(
    'prepareRunStartDescriptor fails when requested ghost bootstrap download fails',
    () async {
      final boardKey = BoardKey(
        mode: RunMode.competitive,
        levelId: LevelId.field.name,
        windowId: '2026-03',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      );
      final selection = SelectionState.defaults.copyWith(
        selectedRunMode: RunMode.competitive,
        selectedLevelId: LevelId.field,
      );
      final ownershipApi = _ScriptedOwnershipApi(
        OwnershipCanonicalState(
          profileId: 'profile_ghost_bootstrap_requested_soft_fail',
          revision: 3,
          selection: selection,
          meta: const MetaService().createNew(),
          progression: ProgressionState.initial,
        ),
      );
      final runSessionApi = _RecordingRunSessionApi(
        RunTicket(
          runSessionId: 'session_competitive_ghost_bootstrap_requested_fail',
          uid: 'u1',
          mode: RunMode.competitive,
          boardId: 'board_2026_03_field',
          boardKey: boardKey,
          seed: 999,
          tickHz: 60,
          gameCompatVersion: '2026.03.0',
          rulesetVersion: boardKey.rulesetVersion,
          scoreVersion: boardKey.scoreVersion,
          ghostVersion: 'ghost-v1',
          levelId: LevelId.field.name,
          playerCharacterId: PlayerCharacterId.eloise.name,
          loadoutSnapshot: _practiceTicket().loadoutSnapshot,
          loadoutDigest:
              '0123456789012345678901234567890123456789012345678901234567890123',
          issuedAtMs: 1,
          expiresAtMs: 2,
          singleUseNonce: 'nonce_competitive_ghost_bootstrap_requested_fail',
        ),
      );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
        leaderboardApi: const _SingleGhostEntryLeaderboardApi(),
        ghostApi: const _SingleGhostManifestApi(),
        ghostReplayCache: const _ThrowingGhostReplayCache(
          RunStartRemoteException(
            code: 'ghost-download-failed',
            message: 'Ghost download failed with status 403.',
          ),
        ),
      );
      await appState.bootstrap(force: true);

      await expectLater(
        () => appState.prepareRunStartDescriptor(ghostEntryId: 'entry_ghost_1'),
        throwsA(
          isA<RunStartRemoteException>().having(
            (value) => value.code,
            'code',
            'ghost-download-failed',
          ),
        ),
      );

      expect(runSessionApi.createRunSessionCalls, 1);
    },
  );

  test('setRunMode forces weekly to featured level', () async {
    final initialSelection = SelectionState.defaults.copyWith(
      selectedLevelId: LevelId.forest,
      selectedRunMode: RunMode.practice,
    );
    final ownershipApi = _ScriptedOwnershipApi(
      OwnershipCanonicalState(
        profileId: 'profile_weekly_mode_force',
        revision: 1,
        selection: initialSelection,
        meta: const MetaService().createNew(),
        progression: ProgressionState.initial,
      ),
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
    );
    await appState.bootstrap(force: true);

    await appState.setRunMode(RunMode.weekly);

    expect(appState.selection.selectedRunMode, RunMode.weekly);
    expect(appState.selection.selectedLevelId, appState.weeklyFeaturedLevelId);
  });

  test('setLevel keeps featured level while weekly mode is selected', () async {
    final initialSelection = SelectionState.defaults.copyWith(
      selectedRunMode: RunMode.weekly,
      selectedLevelId: LevelId.field,
    );
    final ownershipApi = _ScriptedOwnershipApi(
      OwnershipCanonicalState(
        profileId: 'profile_weekly_level_lock',
        revision: 1,
        selection: initialSelection,
        meta: const MetaService().createNew(),
        progression: ProgressionState.initial,
      ),
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: ownershipApi,
    );
    await appState.bootstrap(force: true);

    await appState.setLevel(LevelId.forest);

    expect(appState.selection.selectedRunMode, RunMode.weekly);
    expect(appState.selection.selectedLevelId, appState.weeklyFeaturedLevelId);
  });

  test(
    'prepareRunStartDescriptor normalizes stale weekly level before run start',
    () async {
      final boardKey = BoardKey(
        mode: RunMode.weekly,
        levelId: LevelId.field.name,
        windowId: '2026-W11',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      );
      final staleWeeklySelection = SelectionState.defaults.copyWith(
        selectedRunMode: RunMode.weekly,
        selectedLevelId: LevelId.forest,
      );
      final ownershipApi = _ScriptedOwnershipApi(
        OwnershipCanonicalState(
          profileId: 'profile_weekly_normalize',
          revision: 1,
          selection: staleWeeklySelection,
          meta: const MetaService().createNew(),
          progression: ProgressionState.initial,
        ),
      );
      final runSessionApi = _RecordingRunSessionApi(
        RunTicket(
          runSessionId: 'session_weekly_normalized',
          uid: 'u1',
          mode: RunMode.weekly,
          boardId: 'board_2026_w11_field',
          boardKey: boardKey,
          seed: 999,
          tickHz: 60,
          gameCompatVersion: '2026.03.0',
          rulesetVersion: boardKey.rulesetVersion,
          scoreVersion: boardKey.scoreVersion,
          ghostVersion: 'ghost-v1',
          levelId: LevelId.field.name,
          playerCharacterId: PlayerCharacterId.eloise.name,
          loadoutSnapshot: _practiceTicket().loadoutSnapshot,
          loadoutDigest:
              '0123456789012345678901234567890123456789012345678901234567890123',
          issuedAtMs: 1,
          expiresAtMs: 2,
          singleUseNonce: 'nonce_weekly',
        ),
      );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
      );
      await appState.bootstrap(force: true);

      await appState.prepareRunStartDescriptor();

      expect(runSessionApi.lastLevelId, appState.weeklyFeaturedLevelId);
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

class _RecordingRunSessionApi extends _ScriptedRunSessionApi {
  _RecordingRunSessionApi(super.ticket);

  LevelId? lastLevelId;

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    lastLevelId = levelId;
    return super.createRunSession(
      userId: userId,
      sessionId: sessionId,
      mode: mode,
      levelId: levelId,
      gameCompatVersion: gameCompatVersion,
    );
  }
}

class _ThrowingRunBoardsApi implements RunBoardsApi {
  _ThrowingRunBoardsApi(this.error);

  final Object error;
  int loadCalls = 0;

  @override
  Future<BoardManifest> loadActiveBoard({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    loadCalls += 1;
    throw error;
  }
}

class _SingleGhostEntryLeaderboardApi implements LeaderboardApi {
  const _SingleGhostEntryLeaderboardApi();

  @override
  Future<OnlineLeaderboardBoardData> loadActiveBoardData({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    final board = await loadBoard(
      userId: userId,
      sessionId: sessionId,
      boardId: 'board_2026_03_field',
    );
    return OnlineLeaderboardBoardData(
      board: board,
      myRank: const OnlineLeaderboardMyRank(
        boardId: 'board_2026_03_field',
        myEntry: null,
        rank: null,
        totalPlayers: 1,
      ),
    );
  }

  @override
  Future<OnlineLeaderboardBoard> loadBoard({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    return OnlineLeaderboardBoard(
      boardId: boardId,
      topEntries: <LeaderboardEntry>[
        LeaderboardEntry(
          boardId: 'board_2026_03_field',
          entryId: 'entry_ghost_1',
          runSessionId: 'run_ghost_1',
          uid: 'u_ghost',
          displayName: 'Ghost Player',
          characterId: 'eloise',
          score: 1000,
          distanceMeters: 400,
          durationSeconds: 120,
          sortKey: '00001:00001:00120:entry_ghost_1',
          ghostEligible: true,
          updatedAtMs: 1,
          rank: 1,
        ),
      ],
      updatedAtMs: 1,
    );
  }

  @override
  Future<OnlineLeaderboardMyRank> loadMyRank({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    throw UnimplementedError('loadMyRank is not used in this test.');
  }
}

class _RecordingGhostManifestApi implements GhostApi {
  int loadCalls = 0;
  String? lastBoardId;
  String? lastEntryId;

  @override
  Future<GhostManifest> loadManifest({
    required String userId,
    required String sessionId,
    required String boardId,
    required String entryId,
  }) async {
    loadCalls += 1;
    lastBoardId = boardId;
    lastEntryId = entryId;
    return GhostManifest(
      boardId: boardId,
      entryId: entryId,
      runSessionId: 'run_ghost_recording',
      uid: 'u_ghost',
      replayStorageRef: 'ghosts/$boardId/$entryId/ghost.bin.gz',
      sourceReplayStorageRef:
          'replay-submissions/pending/u_ghost/run_ghost_recording/replay.bin.gz',
      downloadUrl: 'https://example.test/ghost.bin.gz',
      downloadUrlExpiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
      score: 1000,
      distanceMeters: 400,
      durationSeconds: 120,
      sortKey: '00001:00001:00120:$entryId',
      rank: 1,
      updatedAtMs: 1,
    );
  }
}

class _RecordingGhostReplayCacheForMaskTests implements GhostReplayCache {
  int loadCalls = 0;
  String? lastManifestBoardId;
  String? lastManifestEntryId;

  @override
  Future<GhostReplayBootstrap> loadReplay({
    required GhostManifest manifest,
  }) async {
    loadCalls += 1;
    lastManifestBoardId = manifest.boardId;
    lastManifestEntryId = manifest.entryId;
    final replayBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: manifest.runSessionId,
      boardId: manifest.boardId,
      boardKey: const BoardKey(
        mode: RunMode.competitive,
        levelId: 'field',
        windowId: '2026-03',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      ),
      tickHz: 60,
      seed: 123,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: _practiceTicket().loadoutSnapshot,
      totalTicks: 0,
      commandStream: const <ReplayCommandFrameV1>[],
    );
    return GhostReplayBootstrap(
      manifest: manifest,
      replayBlob: replayBlob,
      cachedFile: File('ghost.recording.replay.json'),
      cachedAtMs: 1,
    );
  }
}

class _SingleGhostManifestApi implements GhostApi {
  const _SingleGhostManifestApi();

  @override
  Future<GhostManifest> loadManifest({
    required String userId,
    required String sessionId,
    required String boardId,
    required String entryId,
  }) async {
    return GhostManifest(
      boardId: boardId,
      entryId: entryId,
      runSessionId: 'run_ghost_1',
      uid: 'u_ghost',
      replayStorageRef: 'ghosts/$boardId/$entryId/ghost.bin.gz',
      sourceReplayStorageRef:
          'replay-submissions/pending/u_ghost/run_ghost_1/replay.bin.gz',
      downloadUrl: 'https://example.test/ghost.bin.gz',
      downloadUrlExpiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
      score: 1000,
      distanceMeters: 400,
      durationSeconds: 120,
      sortKey: '00001:00001:00120:$entryId',
      rank: 1,
      updatedAtMs: 1,
    );
  }
}

class _ThrowingGhostReplayCache implements GhostReplayCache {
  const _ThrowingGhostReplayCache(this.error);

  final Object error;

  @override
  Future<GhostReplayBootstrap> loadReplay({
    required GhostManifest manifest,
  }) async {
    throw error;
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
    final nextCanonical = _canonical.copyWith(
      revision: _canonical.revision + 1,
      selection: command.selection,
    );
    _canonical = nextCanonical;
    return OwnershipCommandResult(
      canonicalState: nextCanonical,
      newRevision: nextCanonical.revision,
      replayedFromIdempotency: false,
    );
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
