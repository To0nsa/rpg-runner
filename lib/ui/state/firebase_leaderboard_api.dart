import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

import 'leaderboard_api.dart';
import 'run_start_remote_exception.dart';

class FirebaseLeaderboardApi implements LeaderboardApi {
  FirebaseLeaderboardApi({FirebaseLeaderboardSource? source})
    : _source = source ?? PluginFirebaseLeaderboardSource();

  final FirebaseLeaderboardSource _source;

  @override
  Future<OnlineLeaderboardBoard> loadBoard({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    try {
      final response = await _source.loadBoard(
        userId: userId,
        sessionId: sessionId,
        boardId: boardId,
      );
      final raw = response['board'] ?? response;
      return OnlineLeaderboardBoard.fromJson(raw);
    } on RunStartRemoteException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } on FormatException catch (error) {
      throw RunStartRemoteException(
        code: 'invalid-response',
        message: error.message,
      );
    } catch (error) {
      throw RunStartRemoteException(
        code: 'leaderboard-load-board-failed',
        message: '$error',
      );
    }
  }

  @override
  Future<OnlineLeaderboardMyRank> loadMyRank({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    try {
      final response = await _source.loadMyRank(
        userId: userId,
        sessionId: sessionId,
        boardId: boardId,
      );
      final raw = response['myRank'] ?? response;
      return OnlineLeaderboardMyRank.fromJson(raw);
    } on RunStartRemoteException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } on FormatException catch (error) {
      throw RunStartRemoteException(
        code: 'invalid-response',
        message: error.message,
      );
    } catch (error) {
      throw RunStartRemoteException(
        code: 'leaderboard-load-my-rank-failed',
        message: '$error',
      );
    }
  }

  RunStartRemoteException _mapFunctionsError(FirebaseFunctionsException error) {
    return RunStartRemoteException(
      code: error.code,
      message: error.message ?? _detailsMessage(error.details),
      details: error.details,
    );
  }

  RunStartRemoteException _mapPlatformError(PlatformException error) {
    return RunStartRemoteException(
      code: error.code,
      message: error.message,
      details: error.details,
    );
  }

  String? _detailsMessage(Object? details) {
    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
    }
    return null;
  }
}

abstract class FirebaseLeaderboardSource {
  Future<Map<String, dynamic>> loadBoard({
    required String userId,
    required String sessionId,
    required String boardId,
  });

  Future<Map<String, dynamic>> loadMyRank({
    required String userId,
    required String sessionId,
    required String boardId,
  });
}

class PluginFirebaseLeaderboardSource implements FirebaseLeaderboardSource {
  PluginFirebaseLeaderboardSource({
    FirebaseFunctions? functions,
    this.loadBoardCallableName = 'leaderboardLoadBoard',
    this.loadMyRankCallableName = 'leaderboardLoadMyRank',
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final String loadBoardCallableName;
  final String loadMyRankCallableName;

  @override
  Future<Map<String, dynamic>> loadBoard({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    final callable = _functions.httpsCallable(loadBoardCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'boardId': boardId,
    });
    return _decodeMap(result.data);
  }

  @override
  Future<Map<String, dynamic>> loadMyRank({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    final callable = _functions.httpsCallable(loadMyRankCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'boardId': boardId,
    });
    return _decodeMap(result.data);
  }

  Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw FormatException(
      'Firebase leaderboard callable returned non-map payload: '
      '${raw.runtimeType}',
    );
  }
}
