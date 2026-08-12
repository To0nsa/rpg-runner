/// Render-only terrain material lookup.
library;

/// Asset set used to render one Core-authored terrain material key.
final class TerrainMaterialSpec {
  const TerrainMaterialSpec({
    required this.key,
    required this.fillAssetPath,
    required this.surfaceAssetPath,
    required this.foregroundAssetPath,
    required this.leftCapAssetPath,
    required this.rightCapAssetPath,
    required this.surfaceAnchorY,
  });

  final String key;
  final String fillAssetPath;
  final String surfaceAssetPath;
  final String foregroundAssetPath;
  final String leftCapAssetPath;
  final String rightCapAssetPath;

  /// Source-image Y aligned to the compiler-owned support edge.
  final double surfaceAnchorY;
}

/// Central registry mapping optional Core material metadata to visual assets.
abstract final class TerrainMaterialRegistry {
  static const TerrainMaterialSpec grassDirt = TerrainMaterialSpec(
    key: 'grass_dirt',
    fillAssetPath: 'terrain/grass_dirt/fill.png',
    surfaceAssetPath: 'terrain/grass_dirt/surface.png',
    foregroundAssetPath: 'terrain/grass_dirt/foreground.png',
    leftCapAssetPath: 'terrain/grass_dirt/cap_left.png',
    rightCapAssetPath: 'terrain/grass_dirt/cap_right.png',
    surfaceAnchorY: 12,
  );

  static const Map<String, TerrainMaterialSpec> byKey =
      <String, TerrainMaterialSpec>{'grass_dirt': grassDirt};

  static TerrainMaterialSpec require(String key) {
    return byKey[key] ??
        (throw StateError(
          'No terrain render material is registered for "$key".',
        ));
  }
}
