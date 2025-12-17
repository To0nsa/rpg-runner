double positiveModDouble(double value, double mod) {
  if (mod <= 0) throw ArgumentError.value(mod, 'mod', 'must be > 0');
  final r = value % mod;
  return r < 0 ? r + mod : r;
}

