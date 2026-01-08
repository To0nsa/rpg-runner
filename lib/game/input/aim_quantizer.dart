// Utility for quantizing aim direction values.
//
// Quantization reduces floating-point precision to avoid scheduling redundant
// aim commands when the direction changes by negligible amounts. This improves
// determinism and reduces command spam in the input queue.

/// Quantizes aim direction components to a fixed precision.
///
/// By rounding to 1/256 increments, tiny floating-point variations (e.g., from
/// touch jitter) are collapsed into stable values. This ensures:
/// - Fewer redundant [ProjectileAimDirCommand] / [MeleeAimDirCommand] commands.
/// - Consistent behavior across frames when the aim direction is nearly unchanged.
class AimQuantizer {
  /// Private constructor to prevent instantiation; all methods are static.
  const AimQuantizer._();

  /// Quantization scale factor (256 levels per unit).
  ///
  /// Chosen to provide ~0.4% precision, which is imperceptible to players
  /// but sufficient to filter out floating-point noise.
  static const double _aimQuantizeScale = 256.0;

  /// Returns [value] rounded to the nearest 1/256 increment.
  ///
  /// Returns 0 unchanged to preserve exact zero (no aim bias).
  static double quantize(double value) {
    if (value == 0) return 0;
    return (value * _aimQuantizeScale).roundToDouble() / _aimQuantizeScale;
  }
}
