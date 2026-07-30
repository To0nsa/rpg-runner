import 'dart:math' as math;

import '../models/models.dart';
import 'prefab_domain_models.dart';

/// Resolves one prefab's visual source rectangle without inspecting pixels.
///
/// Atlas prefabs use their authored slice size. Platform prefabs use the exact
/// bounding rectangle of module cells and their referenced slice dimensions.
/// Missing references fail closed instead of falling back to guessed bounds.
abstract final class PrefabVisualBoundsResolver {
  static Map<String, PrefabV3VisualBounds> resolveAll({
    required PrefabV3FileData prefabData,
    required PrefabTileFileData tileData,
  }) {
    final prefabSlices = <String, AtlasSliceDef>{
      for (final slice in prefabData.slices) slice.id: slice,
    };
    final tileSlices = <String, AtlasSliceDef>{
      for (final slice in tileData.tileSlices) slice.id: slice,
    };
    final modules = <String, TileModuleDef>{
      for (final module in tileData.platformModules) module.id: module,
    };
    final resolved = <String, PrefabV3VisualBounds>{};
    for (final prefab in prefabData.prefabs) {
      final bounds = switch (prefab.visualSource.type) {
        PrefabVisualSourceType.atlasSlice => _boundsForSlice(
          prefabSlices[prefab.visualSource.sliceId],
        ),
        PrefabVisualSourceType.platformModule => resolvePlatformModule(
          modules[prefab.visualSource.moduleId],
          tileSlicesById: tileSlices,
        ),
        PrefabVisualSourceType.unknown => null,
      };
      if (bounds != null) resolved[prefab.prefabKey] = bounds;
    }
    return Map<String, PrefabV3VisualBounds>.unmodifiable(resolved);
  }

  static PrefabV3VisualBounds? resolvePlatformModule(
    TileModuleDef? module, {
    required Map<String, AtlasSliceDef> tileSlicesById,
  }) {
    if (module == null || module.tileSize <= 0 || module.cells.isEmpty) {
      return null;
    }
    int? minLeft;
    int? minTop;
    int? maxRight;
    int? maxBottom;
    for (final cell in module.cells) {
      final slice = tileSlicesById[cell.sliceId];
      if (slice == null || slice.width <= 0 || slice.height <= 0) return null;
      final left = cell.gridX * module.tileSize;
      final top = cell.gridY * module.tileSize;
      final right = left + slice.width;
      final bottom = top + slice.height;
      minLeft = minLeft == null ? left : math.min(minLeft, left);
      minTop = minTop == null ? top : math.min(minTop, top);
      maxRight = maxRight == null ? right : math.max(maxRight, right);
      maxBottom = maxBottom == null ? bottom : math.max(maxBottom, bottom);
    }
    if (minLeft == null ||
        minTop == null ||
        maxRight == null ||
        maxBottom == null) {
      return null;
    }
    final width = maxRight - minLeft;
    final height = maxBottom - minTop;
    return width > 0 && height > 0
        ? PrefabV3VisualBounds(widthPx: width, heightPx: height)
        : null;
  }

  static PrefabV3VisualBounds? _boundsForSlice(AtlasSliceDef? slice) =>
      slice != null && slice.width > 0 && slice.height > 0
      ? PrefabV3VisualBounds(widthPx: slice.width, heightPx: slice.height)
      : null;
}
