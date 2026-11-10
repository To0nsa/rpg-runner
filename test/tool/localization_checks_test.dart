import 'package:flutter_test/flutter_test.dart';

import '../../tool/localization_checks.dart';

void main() {
  final english = <String, dynamic>{
    'gifts': '{count, plural, one{One gift for {name}} other{{count} gifts for {name}}}',
    '@gifts': {
      'description': 'Inbox gift count; name is user-authored.',
      'placeholders': {
        'count': {'type': 'int'},
        'name': {'type': 'String'},
      },
    },
  };
  test(
    'nested ICU grammar retains all parameters and inherits source context',
    () {
      final french = {
        'gifts': '{count, plural, one{Un cadeau pour {name}} other{{count} cadeaux pour {name}}}',
      };
      expect(checkResources(english, french), isEmpty);
      expect(
        messagePlaceholders(
          '{kind, select, mana{Mana} other{{count, plural, one{One} other{{count}}}}}',
        ),
        {'kind', 'count'},
      );
      expect(
        checkResources(english, {'gifts': 'Cadeaux pour {name}'}),
        isNotEmpty,
      );
      expect(checkResources(english, {'gift': 'Cadeau'}), isNotEmpty);
      expect(
        checkResources(english, {
          ...english,
          '@gifts': {
            'description': 'Count',
            'placeholders': {
              'count': {'type': 'String'},
            },
          },
        }),
        isNotEmpty,
      );
    },
  );
  test('source audit catches direct, indirect, interpolated and accessibility text', () {
    const source = r"""
      final title = 'New message';
      String label() => 'Play';
      Widget build() => Text('Hello $name');
      final help = Tooltip(message: 'Open menu');
      final semantics = Semantics(label: 'Pause');
    """;
    expect(hardcodedText(source, 'lib/ui/example.dart'), hasLength(5));
  });
  test('technical contexts and pure interpolation do not need translation', () {
    const source = r"""
      import 'package:example/example.dart';
      final a = {'commandId': id};
      final b = raw['field'];
      final c = ValueKey<String>('row-$id');
      final d = RegExp(r'\w+');
      final f = bool.fromEnvironment('DEBUG');
      final g = Locale('fr');
      void fail() { throw StateError('Failure'); }
      Widget build() => Text('$number');
    """;
    expect(hardcodedText(source, 'lib/ui/example.dart'), isEmpty);
  });
}
