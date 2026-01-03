class AimQuantizer {
  const AimQuantizer._();

  static const double _aimQuantizeScale = 256.0;

  static double quantize(double value) {
    if (value == 0) return 0;
    return (value * _aimQuantizeScale).roundToDouble() / _aimQuantizeScale;
  }
}
