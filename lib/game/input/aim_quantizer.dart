// Utility for quantizing aim direction values.
//
// Quantization reduces floating-point precision to avoid scheduling redundant
// aim commands when the direction changes by negligible amounts. This improves
// determinism and reduces command spam in the input queue.
import '../replay/replay_quantization.dart';

/// Quantizes aim direction components to a fixed precision.
///
/// By rounding to 1/256 increments, tiny floating-point variations (e.g., from
/// touch jitter) are collapsed into stable values. This ensures:
/// - Fewer redundant [AimDirCommand] commands.
/// - Consistent behavior across frames when the aim direction is nearly unchanged.
class AimQuantizer {
  /// Private constructor to prevent instantiation; all methods are static.
  const AimQuantizer._();

  /// Returns [value] quantized with the shared replay policy.
  ///
  /// Returns 0 unchanged to preserve exact zero (no aim bias).
  static double quantize(double value) {
    return ReplayQuantization.quantizeAimComponent(value);
  }
}
