/// Render-only terrain material lookup.
library;

part 'authored_terrain_materials.dart';

/// One source image repeated along an exact Core terrain edge.
final class TerrainMaterialEdgeLayerSpec {
  const TerrainMaterialEdgeLayerSpec({
    required this.assetPath,
    required this.anchorY,
  });

  final String assetPath;

  /// Source-image Y, in logical pixels, aligned to the terrain edge.
  final double anchorY;
}

/// Base and optional detail art for one edge-normal orientation.
final class TerrainMaterialEdgeProfileSpec {
  const TerrainMaterialEdgeProfileSpec({required this.base, this.detail});

  final TerrainMaterialEdgeLayerSpec base;
  final TerrainMaterialEdgeLayerSpec? detail;
}

/// Endpoint image and the source pixel aligned to an exact top-edge endpoint.
final class TerrainMaterialCapSpec {
  const TerrainMaterialCapSpec({
    required this.assetPath,
    required this.anchorX,
    required this.anchorY,
  });

  final String assetPath;
  final double anchorX;
  final double anchorY;
}

/// Asset set used to render one Core-authored terrain material key.
final class TerrainMaterialSpec {
  const TerrainMaterialSpec({
    required this.key,
    required this.displayName,
    required this.revision,
    required this.fillAssetPath,
    required this.top,
    this.leftWall,
    this.rightWall,
    this.underside,
    this.topStartCap,
    this.topEndCap,
  });

  final String key;
  final String displayName;
  final int revision;
  final String fillAssetPath;
  final TerrainMaterialEdgeProfileSpec top;
  final TerrainMaterialEdgeProfileSpec? leftWall;
  final TerrainMaterialEdgeProfileSpec? rightWall;
  final TerrainMaterialEdgeProfileSpec? underside;
  final TerrainMaterialCapSpec? topStartCap;
  final TerrainMaterialCapSpec? topEndCap;

  /// Every image that must be available before the material can render.
  Iterable<String> get assetPaths sync* {
    yield fillAssetPath;
    for (final profile in <TerrainMaterialEdgeProfileSpec?>[
      top,
      leftWall,
      rightWall,
      underside,
    ]) {
      if (profile == null) continue;
      yield profile.base.assetPath;
      if (profile.detail case final detail?) yield detail.assetPath;
    }
    if (topStartCap case final cap?) yield cap.assetPath;
    if (topEndCap case final cap?) yield cap.assetPath;
  }
}

/// Central registry mapping optional Core material metadata to visual assets.
abstract final class TerrainMaterialRegistry {
  static const Map<String, TerrainMaterialSpec> byKey =
      _authoredTerrainMaterials;

  static TerrainMaterialSpec require(String key) {
    return byKey[key] ??
        (throw StateError(
          'No terrain render material is registered for "$key".',
        ));
  }
}
