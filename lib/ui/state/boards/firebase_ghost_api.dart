import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

import 'ghost_api.dart';
import '../run/run_start_remote_exception.dart';

class FirebaseGhostApi implements GhostApi {
  FirebaseGhostApi({FirebaseGhostSource? source})
    : _source = source ?? PluginFirebaseGhostSource();

  final FirebaseGhostSource _source;

  @override
  Future<GhostManifest> loadManifest({
    required String userId,
    required String sessionId,
    required String boardId,
    required String entryId,
  }) async {
    try {
      final response = await _source.loadManifest(
        userId: userId,
        sessionId: sessionId,
        boardId: boardId,
        entryId: entryId,
      );
      final raw = response['ghostManifest'] ?? response;
      return GhostManifest.fromJson(raw);
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
        code: 'ghost-load-manifest-failed',
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

abstract class FirebaseGhostSource {
  Future<Map<String, dynamic>> loadManifest({
    required String userId,
    required String sessionId,
    required String boardId,
    required String entryId,
  });
}

class PluginFirebaseGhostSource implements FirebaseGhostSource {
  PluginFirebaseGhostSource({
    FirebaseFunctions? functions,
    this.loadManifestCallableName = 'ghostLoadManifest',
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final String loadManifestCallableName;

  @override
  Future<Map<String, dynamic>> loadManifest({
    required String userId,
    required String sessionId,
    required String boardId,
    required String entryId,
  }) async {
    final callable = _functions.httpsCallable(loadManifestCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'boardId': boardId,
      'entryId': entryId,
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
      'Firebase ghost callable returned non-map payload: ${raw.runtimeType}',
    );
  }
}
