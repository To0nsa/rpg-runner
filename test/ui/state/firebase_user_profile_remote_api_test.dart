import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/firebase_user_profile_remote_api.dart';

void main() {
  test('loadDisplayName decodes wrapped profile payload', () async {
    final source = _FakeFirebaseUserProfileRemoteSource()
      ..loadResponse = <String, dynamic>{
        'profile': <String, Object?>{
          'displayName': 'HeroName',
          'displayNameLastChangedAtMs': 1700000000000,
        },
      };
    final api = FirebaseUserProfileRemoteApi(source: source);

    final profile = await api.loadDisplayName(userId: 'u1', sessionId: 's1');

    expect(profile, isNotNull);
    expect(profile?.displayName, 'HeroName');
    expect(profile?.displayNameLastChangedAtMs, 1700000000000);
  });

  test(
    'loadDisplayName returns null when profile payload is missing',
    () async {
      final source = _FakeFirebaseUserProfileRemoteSource()
        ..loadResponse = <String, dynamic>{};
      final api = FirebaseUserProfileRemoteApi(source: source);

      final profile = await api.loadDisplayName(userId: 'u1', sessionId: 's1');

      expect(profile, isNull);
    },
  );

  test('saveDisplayName forwards payload to Firebase source', () async {
    final source = _FakeFirebaseUserProfileRemoteSource();
    final api = FirebaseUserProfileRemoteApi(source: source);

    await api.saveDisplayName(
      userId: 'u1',
      sessionId: 's1',
      displayName: 'HeroName',
      displayNameLastChangedAtMs: 1700000000000,
    );

    expect(source.lastSavedUserId, 'u1');
    expect(source.lastSavedSessionId, 's1');
    expect(source.lastSavedDisplayName, 'HeroName');
    expect(source.lastSavedLastChangedAtMs, 1700000000000);
  });
}

class _FakeFirebaseUserProfileRemoteSource
    implements FirebaseUserProfileRemoteSource {
  Map<String, dynamic> loadResponse = <String, dynamic>{};
  Map<String, dynamic> saveResponse = <String, dynamic>{};

  String? lastSavedUserId;
  String? lastSavedSessionId;
  String? lastSavedDisplayName;
  int? lastSavedLastChangedAtMs;

  @override
  Future<Map<String, dynamic>> loadProfile({
    required String userId,
    required String sessionId,
  }) async {
    return loadResponse;
  }

  @override
  Future<Map<String, dynamic>> saveDisplayName({
    required String userId,
    required String sessionId,
    required String displayName,
    required int displayNameLastChangedAtMs,
  }) async {
    lastSavedUserId = userId;
    lastSavedSessionId = sessionId;
    lastSavedDisplayName = displayName;
    lastSavedLastChangedAtMs = displayNameLastChangedAtMs;
    return saveResponse;
  }
}
