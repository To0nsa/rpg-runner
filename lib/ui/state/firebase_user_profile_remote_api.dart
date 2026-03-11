import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

import 'user_profile.dart';
import 'user_profile_remote_api.dart';

/// Firebase-backed [UserProfileRemoteApi] for backend-authoritative profile
/// reads and updates.
class FirebaseUserProfileRemoteApi implements UserProfileRemoteApi {
  FirebaseUserProfileRemoteApi({FirebaseUserProfileRemoteSource? source})
    : _source = source ?? PluginFirebaseUserProfileRemoteSource();

  final FirebaseUserProfileRemoteSource _source;

  @override
  Future<UserProfile> loadProfile({
    required String userId,
    required String sessionId,
  }) async {
    try {
      final response = await _source.loadProfile(
        userId: userId,
        sessionId: sessionId,
      );
      return _decodeProfile(response);
    } on UserProfileRemoteException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw _mapFirebaseFunctionsError(error);
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } catch (error) {
      throw UserProfileRemoteException(
        code: 'user-profile-load-failed',
        message: '$error',
      );
    }
  }

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  }) async {
    try {
      final response = await _source.updateProfile(
        userId: userId,
        sessionId: sessionId,
        update: update,
      );
      return _decodeProfile(response);
    } on UserProfileRemoteException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw _mapFirebaseFunctionsError(error);
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } catch (error) {
      throw UserProfileRemoteException(
        code: 'user-profile-update-failed',
        message: '$error',
      );
    }
  }

  UserProfile _decodeProfile(Map<String, dynamic> response) {
    final rawProfile = response['profile'];
    if (rawProfile is Map<String, dynamic>) {
      return UserProfile.fromJson(rawProfile);
    }
    if (rawProfile is Map) {
      return UserProfile.fromJson(Map<String, dynamic>.from(rawProfile));
    }
    return UserProfile.fromJson(response);
  }

  UserProfileRemoteException _mapFirebaseFunctionsError(
    FirebaseFunctionsException error,
  ) {
    return UserProfileRemoteException(
      code: error.code,
      message: error.message ?? _detailsMessage(error.details),
      details: error.details,
    );
  }

  UserProfileRemoteException _mapPlatformError(PlatformException error) {
    return UserProfileRemoteException(
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

/// Transport abstraction for Firebase callable profile reads/writes.
abstract class FirebaseUserProfileRemoteSource {
  Future<Map<String, dynamic>> loadProfile({
    required String userId,
    required String sessionId,
  });

  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  });
}

/// Production callable source backed by `package:cloud_functions`.
class PluginFirebaseUserProfileRemoteSource
    implements FirebaseUserProfileRemoteSource {
  PluginFirebaseUserProfileRemoteSource({
    FirebaseFunctions? functions,
    this.loadCallableName = 'playerProfileLoad',
    this.updateCallableName = 'playerProfileUpdate',
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final String loadCallableName;
  final String updateCallableName;

  @override
  Future<Map<String, dynamic>> loadProfile({
    required String userId,
    required String sessionId,
  }) async {
    final callable = _functions.httpsCallable(loadCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
    });
    return _decodeMap(result.data);
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  }) async {
    final callable = _functions.httpsCallable(updateCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      ...update.toJson(),
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
      'Firebase user profile callable returned non-map payload: '
      '${raw.runtimeType}',
    );
  }
}
