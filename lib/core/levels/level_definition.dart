/// Data-first definition of a level configuration (Core-only).
library;

import '../collision/static_world_geometry.dart';
import '../track/chunk_pattern_pool.dart';
import '../tuning/core_tuning.dart';
import 'level_id.dart';
import 'level_world_constants.dart';

/// Core configuration for a single level.
///
/// This is pure data: no Flutter/Flame imports and no runtime side effects.
class LevelDefinition {
  LevelDefinition({
    required this.id,
    required this.patternPool,
    required this.staticWorldGeometry,
    this.tuning = const CoreTuning(),
    this.cameraCenterY = defaultLevelCameraCenterY,
    this.earlyPatternChunks = defaultEarlyPatternChunks,
    this.noEnemyChunks = defaultNoEnemyChunks,
    this.themeId,
  }) : assert(earlyPatternChunks >= 0),
       assert(noEnemyChunks >= 0),
       assert(
         staticWorldGeometry.groundPlane != null,
         'LevelDefinition.staticWorldGeometry.groundPlane must be set',
       ) {
    if (staticWorldGeometry.groundPlane == null) {
      throw StateError(
        'LevelDefinition($id) requires staticWorldGeometry.groundPlane',
      );
    }
  }

  /// Stable identifier for this level.
  final LevelId id;

  /// Core tuning overrides for this level.
  final CoreTuning tuning;

  /// Base collision geometry for the level (ground + fixed platforms).
  final StaticWorldGeometry staticWorldGeometry;

  /// World-space camera center Y for snapshot/render framing.
  final double cameraCenterY;

  /// Authoritative world-space ground top Y for gameplay and spawning.
  ///
  /// This is derived from [staticWorldGeometry.groundPlane] and is guaranteed
  /// to exist by constructor validation.
  double get groundTopY => staticWorldGeometry.groundPlane!.topY;

  /// Pattern pool used for procedural chunk generation.
  final ChunkPatternPool patternPool;

  /// Number of early chunks that use [patternPool.easyPatterns].
  final int earlyPatternChunks;

  /// Number of early chunks that suppress enemy spawns.
  final int noEnemyChunks;

  /// Optional render theme identifier (e.g., lookup key for assets).
  final String? themeId;

  /// Returns a copy with selected fields overridden.
  LevelDefinition copyWith({
    LevelId? id,
    CoreTuning? tuning,
    double? cameraCenterY,
    StaticWorldGeometry? staticWorldGeometry,
    ChunkPatternPool? patternPool,
    int? earlyPatternChunks,
    int? noEnemyChunks,
    String? themeId,
  }) {
    return LevelDefinition(
      id: id ?? this.id,
      patternPool: patternPool ?? this.patternPool,
      tuning: tuning ?? this.tuning,
      cameraCenterY: cameraCenterY ?? this.cameraCenterY,
      staticWorldGeometry: staticWorldGeometry ?? this.staticWorldGeometry,
      earlyPatternChunks: earlyPatternChunks ?? this.earlyPatternChunks,
      noEnemyChunks: noEnemyChunks ?? this.noEnemyChunks,
      themeId: themeId ?? this.themeId,
    );
  }
}
