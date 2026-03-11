import 'user_profile.dart';

class UserProfileRemoteException implements Exception {
  const UserProfileRemoteException({
    required this.code,
    this.message,
    this.details,
  });

  final String code;
  final String? message;
  final Object? details;

  bool get isDuplicateDisplayName => code == 'already-exists';
  bool get isInvalidArgument => code == 'invalid-argument';
  bool get isUnauthorized =>
      code == 'unauthenticated' || code == 'permission-denied';
  bool get isUnavailable =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'network-request-failed';
  bool get isUnsupported => code == 'not-found' || code == 'unimplemented';

  @override
  String toString() {
    final resolvedMessage = message?.trim();
    if (resolvedMessage != null && resolvedMessage.isNotEmpty) {
      return 'UserProfileRemoteException($code): $resolvedMessage';
    }
    return 'UserProfileRemoteException($code)';
  }
}

class UserProfileUpdate {
  const UserProfileUpdate({
    this.displayName,
    this.displayNameLastChangedAtMs,
    this.namePromptCompleted,
  });

  final String? displayName;
  final int? displayNameLastChangedAtMs;
  final bool? namePromptCompleted;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (displayName != null) 'displayName': displayName,
      if (displayNameLastChangedAtMs != null)
        'displayNameLastChangedAtMs': displayNameLastChangedAtMs,
      if (namePromptCompleted != null)
        'namePromptCompleted': namePromptCompleted,
    };
  }
}

abstract class UserProfileRemoteApi {
  Future<UserProfile> loadProfile({
    required String userId,
    required String sessionId,
  });

  Future<UserProfile> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  });
}

class NoopUserProfileRemoteApi implements UserProfileRemoteApi {
  const NoopUserProfileRemoteApi();

  @override
  Future<UserProfile> loadProfile({
    required String userId,
    required String sessionId,
  }) async {
    return UserProfile.empty;
  }

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  }) async {
    return UserProfile.empty.copyWith(
      displayName: update.displayName,
      displayNameLastChangedAtMs: update.displayNameLastChangedAtMs,
      namePromptCompleted: update.namePromptCompleted,
    );
  }
}
