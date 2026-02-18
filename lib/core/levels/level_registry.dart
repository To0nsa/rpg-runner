/// Registry for core level definitions.
library;

import '../collision/static_world_geometry.dart';
import '../track/chunk_pattern_pool.dart';
import '../track/chunk_patterns_library.dart';
import 'level_definition.dart';
import 'level_id.dart';
import 'level_world_constants.dart';

/// Default pattern pool (matches current behavior).
const ChunkPatternPool defaultPatternPool = ChunkPatternPool(
  easyPatterns: easyPatterns,
  allPatterns: allPatterns,
);

const StaticWorldGeometry _defaultBaseGeometry = StaticWorldGeometry(
  groundPlane: StaticGroundPlane(topY: defaultLevelGroundTopY),
);

/// Resolves level definitions by stable [LevelId].
class LevelRegistry {
  const LevelRegistry._();

  /// Returns the level definition for a given [LevelId].
  static LevelDefinition byId(LevelId id) {
    switch (id) {
      case LevelId.forest:
        return LevelDefinition(
          id: LevelId.forest,
          patternPool: defaultPatternPool,
          cameraCenterY: defaultLevelCameraCenterY,
          staticWorldGeometry: _defaultBaseGeometry,
          themeId: 'forest',
        );
      case LevelId.field:
        return LevelDefinition(
          id: LevelId.field,
          patternPool: defaultPatternPool,
          cameraCenterY: defaultLevelCameraCenterY,
          staticWorldGeometry: _defaultBaseGeometry,
          themeId: 'field',
        );
    }
  }
}
