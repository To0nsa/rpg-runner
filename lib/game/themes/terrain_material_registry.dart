/// Render-only terrain material lookup.
library;

part 'authored_terrain_materials.dart';

/// Complete source-region identity used by terrain rendering caches.
final class TerrainMaterialImageRegionSpec {
  const TerrainMaterialImageRegionSpec({
    required this.assetPath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String assetPath;
  final int x;
  final int y;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is TerrainMaterialImageRegionSpec &&
      assetPath == other.assetPath &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(assetPath, x, y, width, height);
}

/// One source region repeated along an exact Core terrain edge.
final class TerrainMaterialEdgeLayerSpec {
  const TerrainMaterialEdgeLayerSpec({
    required this.region,
    required this.anchorY,
  });

  final TerrainMaterialImageRegionSpec region;

  /// Source-image Y, in logical pixels, aligned to the terrain edge.
  final double anchorY;
}

/// Base and optional detail art for one edge-normal orientation.
final class TerrainMaterialEdgeProfileSpec {
  const TerrainMaterialEdgeProfileSpec({required this.base, this.detail});

  final TerrainMaterialEdgeLayerSpec base;
  final TerrainMaterialEdgeLayerSpec? detail;
}

/// Endpoint image and normalized source pixel aligned to an exact edge endpoint.
final class TerrainMaterialCapSpec {
  const TerrainMaterialCapSpec({
    required this.region,
    required this.anchorX,
    required this.anchorY,
  });

  final TerrainMaterialImageRegionSpec region;
  final double anchorX;
  final double anchorY;
}

/// Asset set used to render one Core-authored terrain material key.
final class TerrainMaterialSpec {
  const TerrainMaterialSpec({
    required this.key,
    required this.displayName,
    required this.revision,
    required this.fill,
    required this.top,
    this.leftWall,
    this.rightWall,
    this.underside,
    this.topStartCap,
    this.topEndCap,
    this.undersideStartCap,
    this.undersideEndCap,
  });

  final String key;
  final String displayName;
  final int revision;
  final TerrainMaterialImageRegionSpec fill;
  final TerrainMaterialEdgeProfileSpec top;
  final TerrainMaterialEdgeProfileSpec? leftWall;
  final TerrainMaterialEdgeProfileSpec? rightWall;
  final TerrainMaterialEdgeProfileSpec? underside;
  final TerrainMaterialCapSpec? topStartCap;
  final TerrainMaterialCapSpec? topEndCap;
  final TerrainMaterialCapSpec? undersideStartCap;
  final TerrainMaterialCapSpec? undersideEndCap;

  /// Every image that must be available before the material can render.
  Iterable<String> get assetPaths sync* {
    yield fill.assetPath;
    for (final profile in <TerrainMaterialEdgeProfileSpec?>[
      top,
      leftWall,
      rightWall,
      underside,
    ]) {
      if (profile == null) continue;
      yield profile.base.region.assetPath;
      if (profile.detail case final detail?) yield detail.region.assetPath;
    }
    if (topStartCap case final cap?) yield cap.region.assetPath;
    if (topEndCap case final cap?) yield cap.region.assetPath;
    if (undersideStartCap case final cap?) yield cap.region.assetPath;
    if (undersideEndCap case final cap?) yield cap.region.assetPath;
  }

  /// Every complete source-region identity once in role order.
  Iterable<TerrainMaterialImageRegionSpec> get regions sync* {
    final seen = <TerrainMaterialImageRegionSpec>{};
    Iterable<TerrainMaterialImageRegionSpec> add(
      TerrainMaterialImageRegionSpec region,
    ) sync* {
      if (seen.add(region)) yield region;
    }

    yield* add(fill);
    for (final profile in <TerrainMaterialEdgeProfileSpec?>[
      top,
      leftWall,
      rightWall,
      underside,
    ]) {
      if (profile == null) continue;
      yield* add(profile.base.region);
      if (profile.detail case final detail?) yield* add(detail.region);
    }
    if (topStartCap case final cap?) yield* add(cap.region);
    if (topEndCap case final cap?) yield* add(cap.region);
    if (undersideStartCap case final cap?) yield* add(cap.region);
    if (undersideEndCap case final cap?) yield* add(cap.region);
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
