class RemoteDisplayNameProfile {
  const RemoteDisplayNameProfile({
    required this.displayName,
    required this.displayNameLastChangedAtMs,
  });

  final String displayName;
  final int displayNameLastChangedAtMs;
}

abstract class UserProfileRemoteApi {
  Future<RemoteDisplayNameProfile?> loadDisplayName({
    required String userId,
    required String sessionId,
  });

  Future<void> saveDisplayName({
    required String userId,
    required String sessionId,
    required String displayName,
    required int displayNameLastChangedAtMs,
  });
}

class NoopUserProfileRemoteApi implements UserProfileRemoteApi {
  const NoopUserProfileRemoteApi();

  @override
  Future<RemoteDisplayNameProfile?> loadDisplayName({
    required String userId,
    required String sessionId,
  }) async {
    return null;
  }

  @override
  Future<void> saveDisplayName({
    required String userId,
    required String sessionId,
    required String displayName,
    required int displayNameLastChangedAtMs,
  }) async {}
}
