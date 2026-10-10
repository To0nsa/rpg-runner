import 'package:runner_core/util/deterministic_rng.dart';
import 'package:test/test.dart';

void main() {
  test('32-bit mixing matches exact integer arithmetic', () {
    final mask = BigInt.from(0xffffffff);
    for (final input in [
      0,
      1,
      -1,
      42,
      857469563,
      0xffffffff,
      0x12345678,
      0x80000000,
      ...List.generate(1024, (i) => i * 0x9e3779b9),
    ]) {
      var v = BigInt.from(input) & mask;
      v ^= v >> 16;
      v = (v * BigInt.from(0x7feb352d)) & mask;
      v ^= v >> 15;
      v = (v * BigInt.from(0x846ca68b)) & mask;
      v ^= v >> 16;
      expect(mix32(input), v.toInt(), reason: 'input $input');
    }
  });
}
