/// Registry for core level definitions.
library;

import '../track/chunk_pattern_pool.dart';
import '../track/chunk_patterns_library.dart';
import 'level_definition.dart';
import 'level_id.dart';

/// Default V0 pattern pool (matches current behavior).
const ChunkPatternPool v0PatternPool = ChunkPatternPool(
  easyPatterns: easyPatterns,
  allPatterns: allPatterns,
);

/// Default V0 level definition.
const LevelDefinition v0LevelDefinition = LevelDefinition(
  id: LevelId.v0Default,
  patternPool: v0PatternPool,
);

/// Resolves level definitions by stable [LevelId].
class LevelRegistry {
  const LevelRegistry._();

  /// Default level used when no level is specified.
  static const LevelDefinition defaultLevel = v0LevelDefinition;

  /// Returns the level definition for a given [LevelId].
  static LevelDefinition byId(LevelId id) {
    switch (id) {
      case LevelId.v0Default:
        return v0LevelDefinition;
    }
  }
}
