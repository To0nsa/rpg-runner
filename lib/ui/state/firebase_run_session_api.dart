import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

import 'package:runner_core/levels/level_id.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:run_protocol/run_ticket.dart';

import 'run_session_api.dart';
import 'run_start_remote_exception.dart';

class FirebaseRunSessionApi implements RunSessionApi {
  FirebaseRunSessionApi({FirebaseRunSessionSource? source})
    : _source = source ?? PluginFirebaseRunSessionSource();

  final FirebaseRunSessionSource _source;

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    try {
      final response = await _source.createRunSession(
        userId: userId,
        sessionId: sessionId,
        mode: mode,
        levelId: levelId,
        gameCompatVersion: gameCompatVersion,
      );
      final rawTicket = response['runTicket'] ?? response;
      return RunTicket.fromJson(rawTicket);
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
        code: 'run-session-create-failed',
        message: '$error',
      );
    }
  }

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    try {
      final response = await _source.createUploadGrant(
        userId: userId,
        sessionId: sessionId,
        runSessionId: runSessionId,
      );
      final rawGrant = response['uploadGrant'] ?? response;
      return RunUploadGrant.fromJson(rawGrant);
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
        code: 'run-session-upload-grant-failed',
        message: '$error',
      );
    }
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
    try {
      final response = await _source.finalizeUpload(
        userId: userId,
        sessionId: sessionId,
        runSessionId: runSessionId,
        canonicalSha256: canonicalSha256,
        contentLengthBytes: contentLengthBytes,
        contentType: contentType,
        objectPath: objectPath,
        provisionalSummary: provisionalSummary,
      );
      final rawStatus = response['submissionStatus'] ?? response;
      return SubmissionStatus.fromJson(rawStatus);
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
        code: 'run-session-finalize-upload-failed',
        message: '$error',
      );
    }
  }

  @override
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    try {
      final response = await _source.loadSubmissionStatus(
        userId: userId,
        sessionId: sessionId,
        runSessionId: runSessionId,
      );
      final rawStatus = response['submissionStatus'] ?? response;
      return SubmissionStatus.fromJson(rawStatus);
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
        code: 'run-session-load-status-failed',
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

abstract class FirebaseRunSessionSource {
  Future<Map<String, dynamic>> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  });

  Future<Map<String, dynamic>> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  });

  Future<Map<String, dynamic>> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  });

  Future<Map<String, dynamic>> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  });
}

class PluginFirebaseRunSessionSource implements FirebaseRunSessionSource {
  PluginFirebaseRunSessionSource({
    FirebaseFunctions? functions,
    this.createCallableName = 'runSessionCreate',
    this.createUploadGrantCallableName = 'runSessionCreateUploadGrant',
    this.finalizeUploadCallableName = 'runSessionFinalizeUpload',
    this.loadStatusCallableName = 'runSessionLoadStatus',
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final String createCallableName;
  final String createUploadGrantCallableName;
  final String finalizeUploadCallableName;
  final String loadStatusCallableName;

  @override
  Future<Map<String, dynamic>> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    final callable = _functions.httpsCallable(createCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'mode': mode.name,
      'levelId': levelId.name,
      'gameCompatVersion': gameCompatVersion,
    });
    return _decodeMap(result.data);
  }

  @override
  Future<Map<String, dynamic>> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    final callable = _functions.httpsCallable(createUploadGrantCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'runSessionId': runSessionId,
    });
    return _decodeMap(result.data);
  }

  @override
  Future<Map<String, dynamic>> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) async {
    final callable = _functions.httpsCallable(finalizeUploadCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'runSessionId': runSessionId,
      'canonicalSha256': canonicalSha256,
      'contentLengthBytes': contentLengthBytes,
      'contentType': ?contentType,
      'objectPath': ?objectPath,
      'provisionalSummary': ?provisionalSummary,
    });
    return _decodeMap(result.data);
  }

  @override
  Future<Map<String, dynamic>> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    final callable = _functions.httpsCallable(loadStatusCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'runSessionId': runSessionId,
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
      'Firebase run session callable returned non-map payload: '
      '${raw.runtimeType}',
    );
  }
}
