import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_runner/ui/state/user_profile_store.dart';

void main() {
  test('load creates and persists profile when missing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = UserProfileStore(
      random: Random(1),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final first = await store.load();
    final second = await store.load();

    expect(first.profileId, isNotEmpty);
    expect(second.profileId, first.profileId);
    expect(second.createdAtMs, first.createdAtMs);
  });

  test('load repairs missing profileId', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ui.user_profile': jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'createdAtMs': 10,
        'updatedAtMs': 10,
        'revision': 0,
        'flags': <String, bool>{},
        'counters': <String, int>{},
      }),
    });
    final store = UserProfileStore(
      random: Random(7),
      now: () => DateTime.fromMillisecondsSinceEpoch(2000),
    );

    final profile = await store.load();
    expect(profile.profileId, isNotEmpty);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('ui.user_profile');
    expect(stored, isNotNull);
    final decoded = jsonDecode(stored!) as Map<String, dynamic>;
    expect(decoded['profileId'], profile.profileId);
  });
}
