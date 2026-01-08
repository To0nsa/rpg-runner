/// Registry for core level definitions.
library;

import '../track/chunk_pattern_pool.dart';
import '../track/chunk_patterns_library.dart';
import 'level_definition.dart';
import 'level_id.dart';

/// Default pattern pool (matches current behavior).
const ChunkPatternPool defaultPatternPool = ChunkPatternPool(
  easyPatterns: easyPatterns,
  allPatterns: allPatterns,
);

/// Default level definition.
const LevelDefinition defaultLevelDefinition = LevelDefinition(
  id: LevelId.defaultLevel,
  patternPool: defaultPatternPool,
  themeId: 'forest',
);

/// Resolves level definitions by stable [LevelId].
class LevelRegistry {
  const LevelRegistry._();

  /// Default level used when no level is specified.
  static const LevelDefinition defaultLevel = defaultLevelDefinition;

  /// Returns the level definition for a given [LevelId].
  static LevelDefinition byId(LevelId id) {
    switch (id) {
      case LevelId.defaultLevel:
        return defaultLevelDefinition;
    }
  }
}
