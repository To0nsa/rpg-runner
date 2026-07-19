import 'package:run_protocol/codecs/canonical_json_codec.dart';
import 'package:test/test.dart';

void main() {
  group('canonicalJsonEncode', () {
    test('sorts nested object keys without changing list order', () {
      expect(
        canonicalJsonEncode(<String, Object?>{
          'z': 3,
          'list': <Object?>[
            <String, Object?>{'b': 2, 'a': 1},
            null,
          ],
          'a': <String, Object?>{'b': 2, 'a': 1},
        }),
        '{"a":{"a":1,"b":2},"list":[{"a":1,"b":2},null],"z":3}',
      );
    });

    test(
      'rejects non-string keys, non-finite numbers, and unsupported values',
      () {
        expect(
          () => canonicalJsonEncode(<Object?, Object?>{1: 'value'}),
          throwsFormatException,
        );
        expect(() => canonicalJsonEncode(double.nan), throwsFormatException);
        expect(
          () => canonicalJsonEncode(<Object?>[double.infinity]),
          throwsFormatException,
        );
        expect(
          () => canonicalJsonEncode(DateTime(2026)),
          throwsFormatException,
        );
      },
    );
  });
}
