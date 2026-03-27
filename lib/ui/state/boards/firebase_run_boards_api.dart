import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

import 'package:runner_core/levels/level_id.dart';
import 'package:run_protocol/board_manifest.dart';
import 'package:run_protocol/run_mode.dart';

import 'run_boards_api.dart';
import '../run/run_start_remote_exception.dart';

class FirebaseRunBoardsApi implements RunBoardsApi {
  FirebaseRunBoardsApi({FirebaseRunBoardsSource? source})
    : _source = source ?? PluginFirebaseRunBoardsSource();

  final FirebaseRunBoardsSource _source;

  @override
  Future<BoardManifest> loadActiveBoard({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    try {
      final response = await _source.loadActiveBoard(
        userId: userId,
        sessionId: sessionId,
        mode: mode,
        levelId: levelId,
        gameCompatVersion: gameCompatVersion,
      );
      final rawManifest = response['boardManifest'] ?? response;
      return BoardManifest.fromJson(rawManifest);
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
        code: 'run-boards-load-failed',
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

abstract class FirebaseRunBoardsSource {
  Future<Map<String, dynamic>> loadActiveBoard({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  });
}

class PluginFirebaseRunBoardsSource implements FirebaseRunBoardsSource {
  PluginFirebaseRunBoardsSource({
    FirebaseFunctions? functions,
    this.loadCallableName = 'runBoardsLoadActive',
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final String loadCallableName;

  @override
  Future<Map<String, dynamic>> loadActiveBoard({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    final callable = _functions.httpsCallable(loadCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'mode': mode.name,
      'levelId': levelId.name,
      'gameCompatVersion': gameCompatVersion,
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
      'Firebase run boards callable returned non-map payload: '
      '${raw.runtimeType}',
    );
  }
}
