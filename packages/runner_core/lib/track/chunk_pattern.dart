/// Chunk pattern data structures for track streaming.
///
/// Defines the authored building blocks (solids, gaps, spawns) used to compose
/// procedural track chunks.
library;

import '../enemies/enemy_id.dart';

/// Authored chunk template defining static geometry, gaps, and spawns.
///
/// All coordinates are chunk-relative (x in `[0, chunkWidth)`).
/// Heights are expressed as "above ground top" so patterns are ground-agnostic.
///
class ChunkPattern {
  const ChunkPattern({
    required this.name,
    this.chunkKey,
    this.assemblyGroupId = defaultChunkAssemblyGroupId,
    this.solids = const <SolidRel>[],
    this.groundGaps = const <GapRel>[],
    this.spawnMarkers = const <SpawnMarker>[],
    this.visualSprites = const <ChunkVisualSpriteRel>[],
  });

  /// Human-readable identifier for debugging/logging.
  final String name;

  /// Stable chunk identity key (optional during migration from legacy patterns).
  final String? chunkKey;

  /// Authored assembly membership key used by level segment scheduling.
  final String assemblyGroupId;

  /// Generic static solids consumed directly by runtime collision.
  ///
  /// This preserves per-rectangle side masks and vertical placement for
  /// generated authored prefab geometry without any secondary collision
  /// representation.
  final List<SolidRel> solids;

  /// Holes in the ground (pit hazards or visual breaks).
  final List<GapRel> groundGaps;

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

/// Chunk-relative generic static solid.
///
/// This maps directly to runtime `StaticSolid` fields after converting
/// [aboveGroundTop] into a world-space top Y against the active chunk's
/// `groundTopY`.
class SolidRel {
  const SolidRel({
    required this.x,
    required this.aboveGroundTop,
    required this.width,
    required this.height,
    required this.sides,
    this.oneWayTop = false,
  }) : assert(width > 0),
       assert(height > 0),
       assert(aboveGroundTop >= 0);

  /// Left edge offset from chunk start.
  final double x;

  /// Distance from the chunk ground top to this solid's top face.
  final double aboveGroundTop;

  /// Horizontal extent.
  final double width;

  /// Vertical extent.
  final double height;

  /// Collision face bitmask mirrored into runtime `StaticSolid.sides`.
  ///
  /// The values intentionally mirror runtime side flags so generated content can
  /// stay in the `track` contract layer without importing collision classes.
  final int sides;

  /// Whether the top face resolves as one-way while falling.
  final bool oneWayTop;

  static const int sideNone = 0;
  static const int sideTop = 1 << 0;
  static const int sideBottom = 1 << 1;
  static const int sideLeft = 1 << 2;
  static const int sideRight = 1 << 3;
  static const int sideAll = sideTop | sideBottom | sideLeft | sideRight;
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
