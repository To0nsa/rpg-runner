import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/inbox/inbox_models.dart';

void main() {
  final fixture = jsonDecode(
    File('functions/test/fixtures/localized_message.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  test('producer fixture selects regional French, defaults to English and preserves identities', () {
    final message = InboxMessage.fromJson(fixture);
    expect(message.textFor('fr_CA').title, 'Niveau 2 atteint');
    expect(message.textFor('en').title, fixture['title']);
    expect(message.textFor('de').body, fixture['body']);
    expect(message.goldAmount, 25);
    expect(message.id, fixture['id']);
    final legacy = InboxMessage.fromJson({...fixture}..remove('localization'));
    expect(legacy.textFor('fr').title, fixture['title']);
    expect(legacy.textFor('fr').body, fixture['body']);
  });
  test('malformed translated mail fails closed', () {
    for (final bad in [
      null,
      {'schemaVersion': 2, 'translations': {}},
      {
        'schemaVersion': 1,
        'translations': {
          'fr': {'title': 'Bonjour', 'body': ''},
        },
      },
      {
        'schemaVersion': 1,
        'translations': {
          'fr_ca': {'title': 'Bonjour', 'body': 'Cadeau'},
        },
      },
    ]) {
      expect(
        () => InboxMessage.fromJson({...fixture, 'localization': bad}),
        throwsFormatException,
      );
    }
  });
}
