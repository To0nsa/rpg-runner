import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/auth/firebase_auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('disabled Play Games account reaches the caller without a sign-in prompt', () async {
    final firebase = _FirebaseAuthStub('user-disabled');
    final api = FirebaseAuthApi(
      source: PluginFirebaseAuthSessionSource(
        firebase,
        playGamesAuthCodeSource: _AuthCodeStub(),
      ),
    );

    await expectLater(
      api.ensureAuthenticatedSession(),
      throwsA(isA<GameAccountDisabledException>()),
    );
    expect(firebase.signInCalls, 1);

    // A failed attempt must release the shared session request for later retry.
    await expectLater(
      api.ensureAuthenticatedSession(),
      throwsA(isA<GameAccountDisabledException>()),
    );
    expect(firebase.signInCalls, 2);
  });

  test(
    'disabled current user cannot fall back to cached credentials',
    () async {
      final firebase = _FirebaseAuthStub('user-disabled')
        ..user = _DisabledUserStub();
      final api = FirebaseAuthApi(
        source: PluginFirebaseAuthSessionSource(firebase),
      );

      await expectLater(
        api.ensureAuthenticatedSession(),
        throwsA(isA<GameAccountDisabledException>()),
      );
      expect(firebase.signInCalls, 0);
    },
  );

  test(
    'invalid Play Games credentials retain the ordinary sign-in recovery',
    () async {
      final api = FirebaseAuthApi(
        source: PluginFirebaseAuthSessionSource(
          _FirebaseAuthStub('invalid-credential'),
          playGamesAuthCodeSource: _AuthCodeStub(),
        ),
      );

      await expectLater(
        api.ensureAuthenticatedSession(),
        throwsA(isA<PlayGamesAuthRequiredException>()),
      );
    },
  );
}

class _FirebaseAuthStub extends Fake implements FirebaseAuth {
  _FirebaseAuthStub(this.errorCode);

  final String errorCode;
  User? user;
  int signInCalls = 0;

  @override
  User? get currentUser => user;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signInCalls++;
    throw FirebaseAuthException(code: errorCode);
  }
}

class _DisabledUserStub extends Fake implements User {
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    throw FirebaseAuthException(code: 'user-disabled');
  }
}

class _AuthCodeStub implements PlayGamesServerAuthCodeSource {
  @override
  Future<String?> requestServerAuthCode() async => 'test-server-auth-code';
}
