/// Chunk pattern data structures for track streaming.
///
/// Defines the authored building blocks (platforms, obstacles, gaps, spawns)
/// used to compose procedural track chunks.
library;

import '../enemies/enemy_id.dart';

/// Authored chunk template defining platforms, obstacles, gaps, and spawns.
///
/// All coordinates are chunk-relative (x in `[0, chunkWidth)`).
/// Heights are expressed as "above ground top" so patterns are ground-agnostic.
class ChunkPattern {
  const ChunkPattern({
    required this.name,
    this.chunkKey,
    this.platforms = const <PlatformRel>[],
    this.obstacles = const <ObstacleRel>[],
    this.groundGaps = const <GapRel>[],
    this.spawnMarkers = const <SpawnMarker>[],
  });

  /// Human-readable identifier for debugging/logging.
  final String name;

  /// Stable chunk identity key (optional during migration from legacy patterns).
  final String? chunkKey;

  /// One-way platforms the player can jump through.
  final List<PlatformRel> platforms;

  /// Solid obstacles the player must jump over.
  final List<ObstacleRel> obstacles;

  /// Holes in the ground (pit hazards or visual breaks).
  final List<GapRel> groundGaps;

  /// Probabilistic enemy spawn points.
  final List<SpawnMarker> spawnMarkers;
}

/// Chunk-relative platform definition (one-way top surface).
class PlatformRel {
  const PlatformRel({
    required this.x,
    required this.width,
    required this.aboveGroundTop,
    required this.thickness,
  }) : assert(width > 0),
       assert(thickness > 0),
       assert(aboveGroundTop > 0);

  /// Left edge offset from chunk start.
  final double x;

  /// Horizontal extent.
  final double width;

  /// Vertical offset above ground (positive = higher).
  final double aboveGroundTop;

  /// Platform thickness (visual/collision depth).
  final double thickness;
}

/// Chunk-relative obstacle definition (solid on all sides).
class ObstacleRel {
  const ObstacleRel({
    required this.x,
    required this.width,
    required this.height,
  }) : assert(width > 0),
       assert(height > 0);

  /// Left edge offset from chunk start.
  final double x;

  /// Horizontal extent.
  final double width;

  /// Vertical extent (sits on ground, extends upward).
  final double height;
}

/// Chunk-relative ground gap (pit hazard).
class GapRel {
  const GapRel({required this.x, required this.width, this.gapId})
    : assert(width > 0);

  /// Left edge offset from chunk start.
  final double x;

  /// Horizontal extent of the gap.
  final double width;

  /// Stable gap identity key (optional during migration from legacy patterns).
  final String? gapId;
}

/// Chunk-relative enemy spawn marker with probabilistic activation.
enum SpawnPlacementMode {
  /// Spawn on chunk ground top Y.
  ground,

  /// Spawn on the highest valid surface at marker X.
  highestSurfaceAtX,

  /// Spawn on obstacle top at marker X, with fallback to highest surface.
  obstacleTop,
}

/// Chunk-relative enemy spawn marker with probabilistic activation.
class SpawnMarker {
  const SpawnMarker({
    required this.enemyId,
    required this.x,
    required this.chancePercent,
    required this.salt,
    this.placement = SpawnPlacementMode.ground,
  }) : assert(chancePercent >= 0),
       assert(chancePercent <= 100);

  /// Enemy type to spawn.
  final EnemyId enemyId;

  /// Spawn X offset from chunk start.
  final double x;

  /// Probability [0–100] that this marker activates.
  final int chancePercent;

  /// Extra entropy to differentiate markers with same position.
  final int salt;

  /// Spawn Y-placement policy at marker X.
  final SpawnPlacementMode placement;
}
