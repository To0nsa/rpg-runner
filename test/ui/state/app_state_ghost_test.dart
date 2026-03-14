import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/board_key.dart';
import 'package:runner_core/meta/meta_service.dart';

import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/ghost_api.dart';
import 'package:rpg_runner/ui/state/ghost_replay_cache.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:run_protocol/replay_blob.dart';

void main() {
  test(
    'loadGhostManifest delegates to GhostApi with authenticated identity',
    () async {
      final ghostApi = _RecordingGhostApi();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: _StaticOwnershipApi(),
        ghostApi: ghostApi,
      );
      await appState.bootstrap(force: true);

      final manifest = await appState.loadGhostManifest(
        boardId: 'board_1',
        entryId: 'entry_1',
      );

      expect(ghostApi.lastUserId, 'u1');
      expect(ghostApi.lastSessionId, 's1');
      expect(ghostApi.lastBoardId, 'board_1');
      expect(ghostApi.lastEntryId, 'entry_1');
      expect(manifest.boardId, 'board_1');
      expect(manifest.entryId, 'entry_1');
    },
  );

  test(
    'loadGhostReplayBootstrap delegates to cache after manifest load',
    () async {
      final ghostApi = _RecordingGhostApi();
      final replayCache = _RecordingGhostReplayCache();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: _StaticOwnershipApi(),
        ghostApi: ghostApi,
        ghostReplayCache: replayCache,
      );
      await appState.bootstrap(force: true);

      final bootstrap = await appState.loadGhostReplayBootstrap(
        boardId: 'board_1',
        entryId: 'entry_1',
      );

      expect(replayCache.lastManifest?.boardId, 'board_1');
      expect(replayCache.lastManifest?.entryId, 'entry_1');
      expect(bootstrap.manifest.entryId, 'entry_1');
      expect(bootstrap.replayBlob.runSessionId, 'run_1');
    },
  );
}

class _RecordingGhostApi implements GhostApi {
  String? lastUserId;
  String? lastSessionId;
  String? lastBoardId;
  String? lastEntryId;

  @override
  Future<GhostManifest> loadManifest({
    required String userId,
    required String sessionId,
    required String boardId,
    required String entryId,
  }) async {
    lastUserId = userId;
    lastSessionId = sessionId;
    lastBoardId = boardId;
    lastEntryId = entryId;
    return const GhostManifest(
      boardId: 'board_1',
      entryId: 'entry_1',
      runSessionId: 'run_1',
      uid: 'u1',
      replayStorageRef: 'ghosts/board_1/entry_1/ghost.bin.gz',
      sourceReplayStorageRef:
          'replay-submissions/pending/u1/run_1/replay.bin.gz',
      downloadUrl: 'https://example.test/ghosts/board_1/entry_1/ghost.bin.gz',
      downloadUrlExpiresAtMs: 9999999999999,
      score: 1000,
      distanceMeters: 400,
      durationSeconds: 120,
      sortKey: '0000000001:0000000001:0000000120:entry_1',
      rank: 1,
      updatedAtMs: 1,
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
  Future<void> clearSession() async {}

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.alreadyLinked,
      session: _session,
    );
  }

  @override
  Future<AuthSession> loadSession() async => _session;
}

class _StaticOwnershipApi implements LoadoutOwnershipApi {
  _StaticOwnershipApi()
    : _canonical = OwnershipCanonicalState(
        profileId: 'profile_static',
        revision: 1,
        selection: SelectionState.defaults,
        meta: const MetaService().createNew(),
        progression: ProgressionState.initial,
      );

  final OwnershipCanonicalState _canonical;

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
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
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonical;
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

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
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

class _RecordingGhostReplayCache implements GhostReplayCache {
  GhostManifest? lastManifest;

  @override
  Future<GhostReplayBootstrap> loadReplay({
    required GhostManifest manifest,
  }) async {
    lastManifest = manifest;
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
      seed: 1,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: const <String, Object?>{
        'mask': 0,
        'mainWeaponId': 'debugSword',
        'offhandWeaponId': 'none',
        'spellBookId': 'emptyBook',
        'projectileSlotSpellId': 'iceBolt',
        'accessoryId': 'none',
        'abilityPrimaryId': 'slash',
        'abilitySecondaryId': 'parry',
        'abilityProjectileId': 'projectileBasic',
        'abilitySpellId': 'spellBasic',
        'abilityMobilityId': 'dash',
        'abilityJumpId': 'jump',
      },
      totalTicks: 0,
      commandStream: const <ReplayCommandFrameV1>[],
    );
    return GhostReplayBootstrap(
      manifest: manifest,
      replayBlob: replayBlob,
      cachedFile: File('ghost.replay.json'),
      cachedAtMs: 1,
    );
  }
}
