part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateBoardsController extends _AppStateController {
  _AppStateBoardsController(super._app);
  Future<OnlineLeaderboardBoard> loadOnlineLeaderboardBoard({
    required RunMode mode,
    required LevelId levelId,
  }) async {
    if (!mode.requiresBoard) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message: 'Practice mode does not have an online leaderboard board.',
      );
    }
    final session = await _ensureAuthSession();
    final boardManifest = await _runBoardsApi.loadActiveBoard(
      userId: session.userId,
      sessionId: session.sessionId,
      mode: mode,
      levelId: levelId,
      gameCompatVersion: _defaultGameCompatVersion,
    );
    return _leaderboardApi.loadBoard(
      userId: session.userId,
      sessionId: session.sessionId,
      boardId: boardManifest.boardId,
    );
  }

  Future<OnlineLeaderboardBoardData> loadOnlineLeaderboardData({
    required RunMode mode,
    required LevelId levelId,
  }) async {
    if (!mode.requiresBoard) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message: 'Practice mode does not have an online leaderboard board.',
      );
    }
    final session = await _ensureAuthSession();
    return _leaderboardApi.loadActiveBoardData(
      userId: session.userId,
      sessionId: session.sessionId,
      mode: mode,
      levelId: levelId,
      gameCompatVersion: _defaultGameCompatVersion,
    );
  }

  Future<OnlineLeaderboardMyRank> loadOnlineLeaderboardMyRank({
    required String boardId,
  }) async {
    final session = await _ensureAuthSession();
    return _leaderboardApi.loadMyRank(
      userId: session.userId,
      sessionId: session.sessionId,
      boardId: boardId,
    );
  }

  Future<GhostManifest> loadGhostManifest({
    required String boardId,
    required String entryId,
  }) async {
    final session = await _ensureAuthSession();
    return _ghostApi.loadManifest(
      userId: session.userId,
      sessionId: session.sessionId,
      boardId: boardId,
      entryId: entryId,
    );
  }

  @override
  Future<GhostReplayBootstrap> loadGhostReplayBootstrap({
    required String boardId,
    required String entryId,
  }) async {
    final manifest = await loadGhostManifest(
      boardId: boardId,
      entryId: entryId,
    );
    return _ghostReplayCache.loadReplay(manifest: manifest);
  }
}
