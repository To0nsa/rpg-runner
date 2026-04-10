/// Registry for core level definitions.
library;

import '../collision/static_world_geometry.dart';
import '../track/authored_chunk_patterns.dart';
import '../track/chunk_pattern_source.dart';
import 'level_definition.dart';
import 'level_id.dart';
import 'level_world_constants.dart';

/// Default runtime-authored chunk pattern source.
final ChunkPatternSource defaultChunkPatternSource =
    authoredChunkPatternSourceForLevel(LevelId.field.name);

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
          chunkPatternSource: authoredChunkPatternSourceForLevel(
            LevelId.forest.name,
          ),
          cameraCenterY: defaultLevelCameraCenterY,
          staticWorldGeometry: _defaultBaseGeometry,
          themeId: 'forest',
        );
      case LevelId.field:
        return LevelDefinition(
          id: LevelId.field,
          chunkPatternSource: authoredChunkPatternSourceForLevel(
            LevelId.field.name,
          ),
          cameraCenterY: defaultLevelCameraCenterY,
          staticWorldGeometry: _defaultBaseGeometry,
          themeId: 'field',
        );
    }
  }
}
