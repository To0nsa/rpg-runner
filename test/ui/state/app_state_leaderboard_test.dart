import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/board_manifest.dart';
import 'package:run_protocol/leaderboard_entry.dart';

import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/leaderboard_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/run_boards_api.dart';
import 'package:rpg_runner/ui/state/run_start_remote_exception.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

void main() {
  test(
    'loadOnlineLeaderboardBoard resolves board and loads top entries',
    () async {
      final runBoardsApi = _RecordingRunBoardsApi();
      final leaderboardApi = _RecordingLeaderboardApi();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: _StaticOwnershipApi(),
        runBoardsApi: runBoardsApi,
        leaderboardApi: leaderboardApi,
      );
      await appState.bootstrap(force: true);

      final board = await appState.loadOnlineLeaderboardBoard(
        mode: RunMode.competitive,
        levelId: LevelId.field,
      );

      expect(runBoardsApi.loadCalls, 1);
      expect(runBoardsApi.lastMode, RunMode.competitive);
      expect(runBoardsApi.lastLevelId, LevelId.field);
      expect(leaderboardApi.lastLoadBoardBoardId, 'board_2026_03_field');
      expect(board.boardId, 'board_2026_03_field');
      expect(board.topEntries, hasLength(1));
      expect(board.topEntries.single.uid, 'u1');
    },
  );

  test('loadOnlineLeaderboardBoard supports weekly mode', () async {
    final runBoardsApi = _RecordingRunBoardsApi();
    final leaderboardApi = _RecordingLeaderboardApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _StaticOwnershipApi(),
      runBoardsApi: runBoardsApi,
      leaderboardApi: leaderboardApi,
    );
    await appState.bootstrap(force: true);

    final board = await appState.loadOnlineLeaderboardBoard(
      mode: RunMode.weekly,
      levelId: LevelId.field,
    );

    expect(runBoardsApi.loadCalls, 1);
    expect(runBoardsApi.lastMode, RunMode.weekly);
    expect(runBoardsApi.lastLevelId, LevelId.field);
    expect(leaderboardApi.lastLoadBoardBoardId, 'board_2026_w11_field');
    expect(board.boardId, 'board_2026_w11_field');
    expect(board.topEntries, hasLength(1));
  });

  test('loadOnlineLeaderboardMyRank delegates to leaderboard api', () async {
    final leaderboardApi = _RecordingLeaderboardApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _StaticOwnershipApi(),
      runBoardsApi: _RecordingRunBoardsApi(),
      leaderboardApi: leaderboardApi,
    );
    await appState.bootstrap(force: true);

    final myRank = await appState.loadOnlineLeaderboardMyRank(
      boardId: 'board_2026_03_field',
    );

    expect(myRank.boardId, 'board_2026_03_field');
    expect(myRank.rank, 7);
    expect(myRank.totalPlayers, 99);
    expect(leaderboardApi.lastLoadMyRankBoardId, 'board_2026_03_field');
  });

  test('loadOnlineLeaderboardBoard rejects practice mode', () async {
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _StaticOwnershipApi(),
      runBoardsApi: _RecordingRunBoardsApi(),
      leaderboardApi: _RecordingLeaderboardApi(),
    );
    await appState.bootstrap(force: true);

    await expectLater(
      () => appState.loadOnlineLeaderboardBoard(
        mode: RunMode.practice,
        levelId: LevelId.field,
      ),
      throwsA(
        isA<RunStartRemoteException>().having(
          (value) => value.code,
          'code',
          'failed-precondition',
        ),
      ),
    );
  });
}

class _RecordingRunBoardsApi implements RunBoardsApi {
  int loadCalls = 0;
  RunMode? lastMode;
  LevelId? lastLevelId;

  @override
  Future<BoardManifest> loadActiveBoard({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    loadCalls += 1;
    lastMode = mode;
    lastLevelId = levelId;
    final boardId = switch (mode) {
      RunMode.competitive => 'board_2026_03_field',
      RunMode.weekly => 'board_2026_w11_field',
      RunMode.practice => 'board_practice_unsupported',
    };
    final windowId = switch (mode) {
      RunMode.competitive => '2026-03',
      RunMode.weekly => '2026-W11',
      RunMode.practice => 'practice',
    };
    return BoardManifest(
      boardId: boardId,
      boardKey: BoardKey(
        mode: mode,
        levelId: LevelId.field.name,
        windowId: windowId,
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      ),
      gameCompatVersion: gameCompatVersion,
      ghostVersion: 'ghost-v1',
      tickHz: 60,
      seed: 123,
      opensAtMs: 1,
      closesAtMs: 2,
      status: BoardStatus.active,
    );
  }
}

class _RecordingLeaderboardApi implements LeaderboardApi {
  String? lastLoadBoardBoardId;
  String? lastLoadMyRankBoardId;

  @override
  Future<OnlineLeaderboardBoard> loadBoard({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    lastLoadBoardBoardId = boardId;
    return OnlineLeaderboardBoard(
      boardId: boardId,
      topEntries: <LeaderboardEntry>[
        LeaderboardEntry(
          boardId: boardId,
          entryId: 'entry_1',
          runSessionId: 'run_1',
          uid: 'u1',
          displayName: 'Player 1',
          characterId: 'eloise',
          score: 1234,
          distanceMeters: 456,
          durationSeconds: 78,
          sortKey: '00001:00001:00078:entry_1',
          ghostEligible: true,
          updatedAtMs: 1000,
          rank: 1,
        ),
      ],
      updatedAtMs: 1000,
    );
  }

  @override
  Future<OnlineLeaderboardMyRank> loadMyRank({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    lastLoadMyRankBoardId = boardId;
    return OnlineLeaderboardMyRank(
      boardId: boardId,
      myEntry: LeaderboardEntry(
        boardId: boardId,
        entryId: 'entry_me',
        runSessionId: 'run_me',
        uid: 'u1',
        displayName: 'Player 1',
        characterId: 'eloise',
        score: 1000,
        distanceMeters: 300,
        durationSeconds: 80,
        sortKey: '00005:00005:00080:entry_me',
        ghostEligible: false,
        updatedAtMs: 1000,
        rank: 7,
      ),
      rank: 7,
      totalPlayers: 99,
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
