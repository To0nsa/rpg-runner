/// Chunk pattern data structures for track streaming.
///
/// Defines the scheduler metadata used to compose procedural track chunks.
library;

import '../enemies/enemy_id.dart';

/// Generated chunk template defining identity, visuals, and spawn markers.
///
/// All coordinates are chunk-relative (x in `[0, chunkWidth)`).
class ChunkPattern {
  const ChunkPattern({
    required this.name,
    this.chunkKey,
    this.assemblyGroupId = defaultChunkAssemblyGroupId,
    this.spawnMarkers = const <SpawnMarker>[],
    this.visualSprites = const <ChunkVisualSpriteRel>[],
  });

  /// Human-readable identifier for debugging/logging.
  final String name;

  /// Stable chunk identity key (optional during migration from legacy patterns).
  final String? chunkKey;

  /// Authored assembly membership key used by level segment scheduling.
  final String assemblyGroupId;

  /// Probabilistic enemy spawn points.
  final List<SpawnMarker> spawnMarkers;

  /// Author-authored visual sprites for this chunk.
  final List<ChunkVisualSpriteRel> visualSprites;
}

/// Default chunk assembly group used by legacy-authored chunks.
const String defaultChunkAssemblyGroupId = 'default';

/// Chunk-relative visual sprite entry used by runtime renderer.
class ChunkVisualSpriteRel {
  const ChunkVisualSpriteRel({
    required this.assetPath,
    required this.srcX,
    required this.srcY,
    required this.srcWidth,
    required this.srcHeight,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.zIndex = 0,
    this.flipX = false,
    this.flipY = false,
  }) : assert(srcWidth > 0),
       assert(srcHeight > 0),
       assert(width > 0),
       assert(height > 0);

  final String assetPath;
  final int srcX;
  final int srcY;
  final int srcWidth;
  final int srcHeight;
  final double x;
  final double y;
  final double width;
  final double height;
  final int zIndex;
  final bool flipX;
  final bool flipY;
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
