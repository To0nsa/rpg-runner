import 'package:run_protocol/run_duration.dart';
import 'package:test/test.dart';

void main() {
  test('canonical duration truncates partial seconds', () {
    expect(canonicalRunDurationSeconds(tick: 59, tickHz: 60), 0);
    expect(canonicalRunDurationSeconds(tick: 60, tickHz: 60), 1);
    expect(canonicalRunDurationSeconds(tick: 119, tickHz: 60), 1);
    expect(canonicalRunDurationSeconds(tick: 120, tickHz: 60), 2);
  });

  test('canonical duration rejects invalid inputs', () {
    expect(
      () => canonicalRunDurationSeconds(tick: -1, tickHz: 60),
      throwsArgumentError,
    );
    expect(
      () => canonicalRunDurationSeconds(tick: 1, tickHz: 0),
      throwsArgumentError,
    );
  });
}
