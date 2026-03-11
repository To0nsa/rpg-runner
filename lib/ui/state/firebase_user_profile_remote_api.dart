import 'package:cloud_functions/cloud_functions.dart';

import 'user_profile_remote_api.dart';

/// Firebase-backed [UserProfileRemoteApi] for display-name persistence.
class FirebaseUserProfileRemoteApi implements UserProfileRemoteApi {
  FirebaseUserProfileRemoteApi({FirebaseUserProfileRemoteSource? source})
    : _source = source ?? PluginFirebaseUserProfileRemoteSource();

  final FirebaseUserProfileRemoteSource _source;

  @override
  Future<RemoteDisplayNameProfile?> loadDisplayName({
    required String userId,
    required String sessionId,
  }) async {
    final response = await _source.loadProfile(
      userId: userId,
      sessionId: sessionId,
    );
    return _decodeProfile(response);
  }

  @override
  Future<void> saveDisplayName({
    required String userId,
    required String sessionId,
    required String displayName,
    required int displayNameLastChangedAtMs,
  }) async {
    await _source.saveDisplayName(
      userId: userId,
      sessionId: sessionId,
      displayName: displayName,
      displayNameLastChangedAtMs: displayNameLastChangedAtMs,
    );
  }

  RemoteDisplayNameProfile? _decodeProfile(Map<String, dynamic> response) {
    final rawProfile = response['profile'];
    if (rawProfile is! Map) {
      return null;
    }
    final profile = Map<String, dynamic>.from(rawProfile);
    final displayNameRaw = profile['displayName'];
    if (displayNameRaw is! String) {
      return null;
    }
    final displayName = displayNameRaw.trim();
    if (displayName.isEmpty) {
      return null;
    }
    final changedAtRaw = profile['displayNameLastChangedAtMs'];
    final changedAt = changedAtRaw is int
        ? changedAtRaw
        : (changedAtRaw is num ? changedAtRaw.toInt() : 0);
    return RemoteDisplayNameProfile(
      displayName: displayName,
      displayNameLastChangedAtMs: changedAt < 0 ? 0 : changedAt,
    );
  }
}

/// Transport abstraction for Firebase callable profile reads/writes.
abstract class FirebaseUserProfileRemoteSource {
  Future<Map<String, dynamic>> loadProfile({
    required String userId,
    required String sessionId,
  });

  Future<Map<String, dynamic>> saveDisplayName({
    required String userId,
    required String sessionId,
    required String displayName,
    required int displayNameLastChangedAtMs,
  });
}

/// Production callable source backed by `package:cloud_functions`.
class PluginFirebaseUserProfileRemoteSource
    implements FirebaseUserProfileRemoteSource {
  PluginFirebaseUserProfileRemoteSource({
    FirebaseFunctions? functions,
    this.loadCallableName = 'playerProfileLoad',
    this.saveDisplayNameCallableName = 'playerProfileSaveDisplayName',
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final String loadCallableName;
  final String saveDisplayNameCallableName;

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
  Future<Map<String, dynamic>> saveDisplayName({
    required String userId,
    required String sessionId,
    required String displayName,
    required int displayNameLastChangedAtMs,
  }) async {
    final callable = _functions.httpsCallable(saveDisplayNameCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'displayName': displayName,
      'displayNameLastChangedAtMs': displayNameLastChangedAtMs,
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
