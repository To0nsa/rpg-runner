import 'package:runner_core/collision/terrain/terrain_numeric.dart';

/// Exact text conversion for authored half-pixel coordinates.
///
/// Parsing never routes through a floating-point value. Integer, `.0`, and
/// `.5` forms are accepted (with either decimal separator); every other
/// fraction and every value outside Core's source-coordinate range is rejected.
final class TerrainHalfPixelText {
  TerrainHalfPixelText._();

  static int? tryParseTicks(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    final match = RegExp(
      r'^([+-]?)(?:(\d+)(?:\.([05]))?|\.([05]))$',
    ).firstMatch(normalized);
    if (match == null) return null;

    final whole = int.tryParse(match.group(2) ?? '0');
    if (whole == null) return null;
    final fraction = match.group(3) ?? match.group(4);
    final magnitude =
        whole * terrainSourceTicksPerWorldUnit + (fraction == '5' ? 1 : 0);
    final ticks = match.group(1) == '-' ? -magnitude : magnitude;
    if (ticks.abs() > terrainMaxAbsSourceTicks) return null;
    return ticks;
  }

  static String formatTicks(int ticks) {
    if (ticks.abs() > terrainMaxAbsSourceTicks) {
      throw RangeError.range(
        ticks,
        -terrainMaxAbsSourceTicks,
        terrainMaxAbsSourceTicks,
        'ticks',
      );
    }
    final magnitude = ticks.abs();
    final whole = magnitude ~/ terrainSourceTicksPerWorldUnit;
    final fraction = magnitude.isOdd ? '.5' : '';
    return '${ticks < 0 ? '-' : ''}$whole$fraction';
  }
}
