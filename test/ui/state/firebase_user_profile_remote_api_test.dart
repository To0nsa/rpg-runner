import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/profile/firebase_user_profile_remote_api.dart';
import 'package:rpg_runner/ui/state/profile/user_profile_remote_api.dart';

void main() {
  test('loadProfile decodes wrapped profile payload', () async {
    final source = _FakeFirebaseUserProfileRemoteSource()
      ..loadResponse = <String, dynamic>{
        'profile': <String, Object?>{
          'displayName': 'HeroName',
          'displayNameLastChangedAtMs': 1700000000000,
          'namePromptCompleted': true,
        },
      };
    final api = FirebaseUserProfileRemoteApi(source: source);

    final profile = await api.loadProfile(userId: 'u1', sessionId: 's1');

    expect(profile.displayName, 'HeroName');
    expect(profile.displayNameLastChangedAtMs, 1700000000000);
    expect(profile.namePromptCompleted, isTrue);
  });

  test('loadProfile falls back to empty profile when payload is missing', () async {
    final source = _FakeFirebaseUserProfileRemoteSource()
      ..loadResponse = <String, dynamic>{};
    final api = FirebaseUserProfileRemoteApi(source: source);

    final profile = await api.loadProfile(userId: 'u1', sessionId: 's1');

    expect(profile.displayName, isEmpty);
    expect(profile.namePromptCompleted, isFalse);
  });

  test('updateProfile forwards patch payload to Firebase source', () async {
    final source = _FakeFirebaseUserProfileRemoteSource();
    final api = FirebaseUserProfileRemoteApi(source: source);

    await api.updateProfile(
      userId: 'u1',
      sessionId: 's1',
      update: const UserProfileUpdate(
        displayName: 'HeroName',
        displayNameLastChangedAtMs: 1700000000000,
        namePromptCompleted: true,
      ),
    );

    expect(source.lastSavedUserId, 'u1');
    expect(source.lastSavedSessionId, 's1');
    expect(source.lastSavedDisplayName, 'HeroName');
    expect(source.lastSavedLastChangedAtMs, 1700000000000);
    expect(source.lastSavedNamePromptCompleted, isTrue);
  });

  test(
    'updateProfile maps Firebase callable failures to domain exception',
    () async {
      final source = _FakeFirebaseUserProfileRemoteSource()
        ..error = _TestFirebaseFunctionsException(
          code: 'already-exists',
          message: 'displayName is already taken.',
        );
      final api = FirebaseUserProfileRemoteApi(source: source);

      await expectLater(
        () => api.updateProfile(
          userId: 'u1',
          sessionId: 's1',
          update: const UserProfileUpdate(
            displayName: 'HeroName',
            displayNameLastChangedAtMs: 1700000000000,
          ),
        ),
        throwsA(
          isA<UserProfileRemoteException>()
              .having((e) => e.code, 'code', 'already-exists')
              .having(
                (e) => e.message,
                'message',
                'displayName is already taken.',
              ),
        ),
      );
    },
  );

  test('loadProfile maps platform failures to domain exception', () async {
    final source = _FakeFirebaseUserProfileRemoteSource()
      ..error = PlatformException(
        code: 'unavailable',
        message: 'network down',
      );
    final api = FirebaseUserProfileRemoteApi(source: source);

    await expectLater(
      () => api.loadProfile(userId: 'u1', sessionId: 's1'),
      throwsA(
        isA<UserProfileRemoteException>()
            .having((e) => e.code, 'code', 'unavailable')
            .having((e) => e.message, 'message', 'network down'),
      ),
    );
  });
}

class _FakeFirebaseUserProfileRemoteSource
    implements FirebaseUserProfileRemoteSource {
  Map<String, dynamic> loadResponse = <String, dynamic>{};
  Map<String, dynamic> saveResponse = <String, dynamic>{};
  Object? error;

  String? lastSavedUserId;
  String? lastSavedSessionId;
  String? lastSavedDisplayName;
  int? lastSavedLastChangedAtMs;
  bool? lastSavedNamePromptCompleted;

  @override
  Future<Map<String, dynamic>> loadProfile({
    required String userId,
    required String sessionId,
  }) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    return loadResponse;
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  }) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    lastSavedUserId = userId;
    lastSavedSessionId = sessionId;
    lastSavedDisplayName = update.displayName;
    lastSavedLastChangedAtMs = update.displayNameLastChangedAtMs;
    lastSavedNamePromptCompleted = update.namePromptCompleted;
    return saveResponse;
  }
}

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({
    required super.code,
    required super.message,
  });
}
