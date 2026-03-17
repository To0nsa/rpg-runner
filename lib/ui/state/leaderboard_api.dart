import 'package:runner_core/levels/level_id.dart';
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:run_protocol/run_mode.dart';

import 'run_start_remote_exception.dart';

final class OnlineLeaderboardBoard {
  const OnlineLeaderboardBoard({
    required this.boardId,
    required this.topEntries,
    required this.updatedAtMs,
  });

  final String boardId;
  final List<LeaderboardEntry> topEntries;
  final int updatedAtMs;

  factory OnlineLeaderboardBoard.fromJson(Object? raw) {
    if (raw is! Map) {
      throw FormatException('onlineLeaderboardBoard must be a JSON object.');
    }
    final json = Map<Object?, Object?>.from(raw);
    final boardId = json['boardId'];
    final updatedAtMs = json['updatedAtMs'];
    final rawTopEntries = json['topEntries'];
    if (boardId is! String || boardId.trim().isEmpty) {
      throw FormatException('onlineLeaderboardBoard.boardId must be non-empty.');
    }
    if (updatedAtMs is! int || updatedAtMs < 0) {
      throw FormatException(
        'onlineLeaderboardBoard.updatedAtMs must be a non-negative integer.',
      );
    }
    if (rawTopEntries is! List) {
      throw FormatException('onlineLeaderboardBoard.topEntries must be a list.');
    }
    final entries = rawTopEntries
        .map<LeaderboardEntry>(LeaderboardEntry.fromJson)
        .toList(growable: false);
    return OnlineLeaderboardBoard(
      boardId: boardId.trim(),
      topEntries: entries,
      updatedAtMs: updatedAtMs,
    );
  }
}

final class OnlineLeaderboardMyRank {
  const OnlineLeaderboardMyRank({
    required this.boardId,
    required this.myEntry,
    required this.rank,
    required this.totalPlayers,
  });

  final String boardId;
  final LeaderboardEntry? myEntry;
  final int? rank;
  final int totalPlayers;

  factory OnlineLeaderboardMyRank.fromJson(Object? raw) {
    if (raw is! Map) {
      throw FormatException('onlineLeaderboardMyRank must be a JSON object.');
    }
    final json = Map<Object?, Object?>.from(raw);
    final boardId = json['boardId'];
    final rank = json['rank'];
    final totalPlayers = json['totalPlayers'];
    if (boardId is! String || boardId.trim().isEmpty) {
      throw FormatException('onlineLeaderboardMyRank.boardId must be non-empty.');
    }
    if (totalPlayers is! int || totalPlayers < 0) {
      throw FormatException(
        'onlineLeaderboardMyRank.totalPlayers must be a non-negative integer.',
      );
    }
    if (rank != null && (rank is! int || rank <= 0)) {
      throw FormatException('onlineLeaderboardMyRank.rank must be null or > 0.');
    }
    return OnlineLeaderboardMyRank(
      boardId: boardId.trim(),
      myEntry: json['myEntry'] == null
          ? null
          : LeaderboardEntry.fromJson(json['myEntry']),
      rank: rank as int?,
      totalPlayers: totalPlayers,
    );
  }
}

final class OnlineLeaderboardBoardData {
  const OnlineLeaderboardBoardData({required this.board, required this.myRank});

  final OnlineLeaderboardBoard board;
  final OnlineLeaderboardMyRank myRank;

  factory OnlineLeaderboardBoardData.fromJson(Object? raw) {
    if (raw is! Map) {
      throw FormatException('onlineLeaderboardBoardData must be a JSON object.');
    }
    final json = Map<Object?, Object?>.from(raw);
    return OnlineLeaderboardBoardData(
      board: OnlineLeaderboardBoard.fromJson(json['board']),
      myRank: OnlineLeaderboardMyRank.fromJson(json['myRank']),
    );
  }
}

abstract class LeaderboardApi {
  Future<OnlineLeaderboardBoardData> loadActiveBoardData({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  });

  Future<OnlineLeaderboardBoard> loadBoard({
    required String userId,
    required String sessionId,
    required String boardId,
  });

  Future<OnlineLeaderboardMyRank> loadMyRank({
    required String userId,
    required String sessionId,
    required String boardId,
  });
}

class NoopLeaderboardApi implements LeaderboardApi {
  const NoopLeaderboardApi();

  @override
  Future<OnlineLeaderboardBoardData> loadActiveBoardData({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Leaderboard API is not configured for this environment.',
    );
  }

  @override
  Future<OnlineLeaderboardBoard> loadBoard({
    required String userId,
    required String sessionId,
    required String boardId,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Leaderboard API is not configured for this environment.',
    );
  }

  @override
  Future<OnlineLeaderboardMyRank> loadMyRank({
    required String userId,
    required String sessionId,
    required String boardId,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Leaderboard API is not configured for this environment.',
    );
  }
}
