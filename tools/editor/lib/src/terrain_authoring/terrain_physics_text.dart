import 'package:runner_core/collision/terrain/terrain_numeric.dart';

/// Exact display formatting for Core fixed-point terrain measurements.
abstract final class TerrainPhysicsText {
  /// Formats a `1/1024 px` physics coordinate without floating-point rounding.
  static String formatTicks(int ticks) =>
      _formatBinaryFraction(ticks, terrainPhysicsTicksPerWorldUnit);

  /// Formats Core's `1/1024 degree` absolute slope-angle units exactly.
  static String formatSlopeAngleUnits(int angleUnits) =>
      _formatBinaryFraction(angleUnits, terrainSlopeAngleUnitsPerDegree);
}

String _formatBinaryFraction(int numerator, int denominator) {
  final magnitude = numerator.abs();
  final whole = magnitude ~/ denominator;
  final remainder = magnitude.remainder(denominator);
  final sign = numerator.isNegative ? '-' : '';
  if (remainder == 0) return '$sign$whole';
  var decimalScale = 1;
  var decimalPlaces = 0;
  while (decimalScale.remainder(denominator) != 0) {
    decimalScale *= 10;
    decimalPlaces += 1;
    if (decimalPlaces > 32) {
      throw StateError('Core fixed-point scale has no bounded decimal form.');
    }
  }
  final decimal = (remainder * (decimalScale ~/ denominator))
      .toString()
      .padLeft(decimalPlaces, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$sign$whole.$decimal';
}
