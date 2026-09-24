import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_trap_tuning_input.dart';

void main() {
  test('HP and seconds convert exactly to source units', () {
    expect(parseTrapDamage100('6.25'), 625);
    expect(parseTrapDamage100(' .01 '), 1);
    expect(parseTrapDamage100('1000'), 100000);
    expect(parseTrapWindupMs('0'), 0);
    expect(parseTrapWindupMs('.001'), 1);
    expect(parseTrapWindupMs('1.234'), 1234);
    expect(parseTrapWindupMs('30'), 30000);
    expect(formatTrapDamage100(1), '0.01');
    expect(formatTrapDamage100(500), '5');
    expect(formatTrapWindupMs(0), '0');
    expect(formatTrapWindupMs(700), '0.7');
    expect(formatTrapWindupMs(1234), '1.234');
  });

  test('invalid, out-of-range and overprecise input is rejected', () {
    for (final input in ['', '.', '-1', 'NaN', 'Infinity', '1e2', '1,2']) {
      expect(parseTrapDamage100(input), isNull, reason: input);
      expect(parseTrapWindupMs(input), isNull, reason: input);
    }
    for (final input in ['0', '0.001', '1000.01', '1.234']) {
      expect(parseTrapDamage100(input), isNull, reason: input);
    }
    for (final input in ['30.001', '0.0001', '9999999999999999999999']) {
      expect(parseTrapWindupMs(input), isNull, reason: input);
    }
  });
}
