import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/local_auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'linkAuthProvider with Google upgrades current anonymous session',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final api = LocalAuthApi(random: Random(42), now: () => now);
      final anonymous = await api.ensureAuthenticatedSession();

      final result = await api.linkAuthProvider(AuthLinkProvider.google);

      expect(result.status, AuthLinkStatus.linked);
      expect(result.session.userId, anonymous.userId);
      expect(result.session.isAnonymous, isFalse);
      expect(result.session.isProviderLinked(AuthLinkProvider.google), isTrue);
      expect(result.session.sessionId, isNot(anonymous.sessionId));
      final persisted = await api.loadSession();
      expect(persisted.isAnonymous, isFalse);
    },
  );

  test('linkAuthProvider returns alreadyLinked for upgraded session', () async {
    final now = DateTime.utc(2026, 3, 10, 12);
    final api = LocalAuthApi(random: Random(42), now: () => now);

    await api.linkAuthProvider(AuthLinkProvider.google);
    final second = await api.linkAuthProvider(AuthLinkProvider.google);

    expect(second.status, AuthLinkStatus.alreadyLinked);
    expect(second.session.isAnonymous, isFalse);
  });

  test(
    'linkAuthProvider with Play Games upgrades current anonymous session',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final api = LocalAuthApi(random: Random(42), now: () => now);
      final anonymous = await api.ensureAuthenticatedSession();

      final result = await api.linkAuthProvider(AuthLinkProvider.playGames);

      expect(result.status, AuthLinkStatus.linked);
      expect(result.session.userId, anonymous.userId);
      expect(result.session.isAnonymous, isFalse);
      expect(
        result.session.isProviderLinked(AuthLinkProvider.playGames),
        isTrue,
      );
      final persisted = await api.loadSession();
      expect(persisted.isAnonymous, isFalse);
    },
  );

  test(
    'linkAuthProvider can link Google and Play Games on same session',
    () async {
      final now = DateTime.utc(2026, 3, 10, 12);
      final api = LocalAuthApi(random: Random(42), now: () => now);

      await api.linkAuthProvider(AuthLinkProvider.google);
      final second = await api.linkAuthProvider(AuthLinkProvider.playGames);

      expect(second.status, AuthLinkStatus.linked);
      expect(second.session.isAnonymous, isFalse);
      expect(second.session.linkedProviders.length, 2);
      expect(second.session.isProviderLinked(AuthLinkProvider.google), isTrue);
      expect(
        second.session.isProviderLinked(AuthLinkProvider.playGames),
        isTrue,
      );
    },
  );
}
