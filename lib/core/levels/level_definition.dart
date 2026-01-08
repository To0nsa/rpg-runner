/// Data-first definition of a level configuration (Core-only).
library;

import '../collision/static_world_geometry.dart';
import '../contracts/render_contract.dart';
import '../track/chunk_pattern_pool.dart';
import '../tuning/core_tuning.dart';
import 'level_id.dart';

/// Core configuration for a single level.
///
/// This is pure data: no Flutter/Flame imports and no runtime side effects.
class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.patternPool,
    this.tuning = const CoreTuning(),
    this.staticWorldGeometry = const StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: groundTopY * 1.0),
    ),
    this.earlyPatternChunks = defaultEarlyPatternChunks,
    this.noEnemyChunks = defaultNoEnemyChunks,
    this.themeId,
  }) : assert(earlyPatternChunks >= 0),
       assert(noEnemyChunks >= 0);

  /// Stable identifier for this level.
  final LevelId id;

  /// Core tuning overrides for this level.
  final CoreTuning tuning;

  /// Base collision geometry for the level (ground + fixed platforms).
  final StaticWorldGeometry staticWorldGeometry;

  /// Pattern pool used for procedural chunk generation.
  final ChunkPatternPool patternPool;

  /// Number of early chunks that use [patternPool.easyPatterns].
  final int earlyPatternChunks;

  /// Number of early chunks that suppress enemy spawns.
  final int noEnemyChunks;

  /// Optional render theme identifier (e.g., lookup key for assets).
  final String? themeId;
}
