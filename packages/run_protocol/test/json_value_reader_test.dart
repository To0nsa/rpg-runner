import 'package:run_protocol/codecs/json_integer.dart';
import 'package:run_protocol/codecs/json_value_reader.dart';
import 'package:test/test.dart';

void main() {
  for (final value in <Object?>[
    1e100,
    -1e100,
    maxJsonSafeInteger + 1,
    -maxJsonSafeInteger - 1,
    1.5,
    double.nan,
    double.infinity,
    '1',
    true,
  ]) {
    test('integer readers reject $value without coercion', () {
      final json = <String, Object?>{'value': value};
      expect(() => readRequiredInt(json, 'value'), throwsFormatException);
      expect(() => readOptionalInt(json, 'value'), throwsFormatException);
    });
  }

  test('integer readers preserve safe endpoints and integral doubles', () {
    for (final value in <num>[
      -maxJsonSafeInteger,
      maxJsonSafeInteger,
      maxJsonSafeInteger.toDouble(),
      0,
      -0.0,
      30.0,
    ]) {
      final json = <String, Object?>{'value': value};
      expect(readRequiredInt(json, 'value'), value.toInt());
      expect(readOptionalInt(json, 'value'), value.toInt());
    }
    expect(readOptionalInt({}, 'value'), isNull);
    expect(readOptionalInt({'value': null}, 'value'), isNull);
    expect(() => readRequiredInt({}, 'value'), throwsFormatException);
  });
}
