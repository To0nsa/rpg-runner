/// Returns `value % mod`, always in the range `[0, mod)`.
///
/// Dart's `%` operator can return negative results for negative [value];
/// this function corrects that.
double positiveModDouble(double value, double mod) {
  if (mod <= 0) throw ArgumentError.value(mod, 'mod', 'must be > 0');
  final r = value % mod;
  return r < 0 ? r + mod : r;
}

/// Integer floor division that correctly handles negative dividends.
///
/// Dart's `~/` operator truncates toward zero, which gives incorrect results
/// for negative numbers when you want true floor division (toward -∞).
///
/// Example: `-1 ~/ 16` returns `0`, but `floorDivInt(-1, 16)` returns `-1`.
int floorDivInt(int a, int b) {
  if (b <= 0) throw ArgumentError.value(b, 'b', 'must be > 0');
  if (a >= 0) return a ~/ b;
  return -(((-a) + b - 1) ~/ b);
}

