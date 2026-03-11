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
      expect(result.session.sessionId, isNot(anonymous.sessionId));
      final persisted = await api.loadSession();
      expect(persisted.isAnonymous, isFalse);
    },
  );

  test('linkAuthProvider returns alreadyLinked for upgraded session', () async {
    final now = DateTime.utc(2026, 3, 10, 12);
    final api = LocalAuthApi(random: Random(42), now: () => now);

    await api.linkAuthProvider(AuthLinkProvider.playGames);
    final second = await api.linkAuthProvider(AuthLinkProvider.playGames);

    expect(second.status, AuthLinkStatus.alreadyLinked);
    expect(second.session.isAnonymous, isFalse);
  });
}
