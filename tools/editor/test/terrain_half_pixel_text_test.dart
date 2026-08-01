import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_half_pixel_text.dart';

void main() {
  test('parses exact integer and half-pixel text without doubles', () {
    expect(TerrainHalfPixelText.tryParseTicks('0'), 0);
    expect(TerrainHalfPixelText.tryParseTicks('-2'), -4);
    expect(TerrainHalfPixelText.tryParseTicks('.5'), 1);
    expect(TerrainHalfPixelText.tryParseTicks('-.5'), -1);
    expect(TerrainHalfPixelText.tryParseTicks('+12.0'), 24);
    expect(TerrainHalfPixelText.tryParseTicks(' 1,5 '), 3);
  });

  test('rejects other fractions, malformed values, and source overflow', () {
    expect(TerrainHalfPixelText.tryParseTicks('1.25'), isNull);
    expect(TerrainHalfPixelText.tryParseTicks('1.'), isNull);
    expect(TerrainHalfPixelText.tryParseTicks('NaN'), isNull);
    expect(TerrainHalfPixelText.tryParseTicks(''), isNull);
    expect(
      TerrainHalfPixelText.tryParseTicks(
        '${(terrainMaxAbsSourceTicks ~/ 2) + 1}',
      ),
      isNull,
    );
  });

  test('formats canonical pixel text and rejects out-of-range ticks', () {
    expect(TerrainHalfPixelText.formatTicks(0), '0');
    expect(TerrainHalfPixelText.formatTicks(3), '1.5');
    expect(TerrainHalfPixelText.formatTicks(-1), '-0.5');
    expect(
      () => TerrainHalfPixelText.formatTicks(terrainMaxAbsSourceTicks + 1),
      throwsRangeError,
    );
  });
}
