/// Pre-authored chunk pattern library for track streaming.
///
/// Notes:
/// - All coordinates are relative to the chunk start (x in [0, chunkWidth)).
/// - Y is expressed as "above ground top" (so 48 means 48 units above ground).
/// - Values are authored on a 16-unit grid for stability.
library;

import '../enemies/enemy_id.dart';
import 'chunk_pattern.dart';

/// Standard platform thickness (visual/collision depth).
const double kPlatformThickness = 16.0;

/// Shorthand for [kPlatformThickness] in pattern definitions.
const double _t = kPlatformThickness;

/// Simpler patterns for early-game chunks (default early window).
///
/// These give the player breathing room before harder patterns appear.
const List<ChunkPattern> easyPatterns = <ChunkPattern>[
  ChunkPattern(
    name: 'recovery-flat',
    platforms: <PlatformRel>[],
    obstacles: <ObstacleRel>[],
    groundGaps: <GapRel>[],
    spawnMarkers: <SpawnMarker>[],
  ),
  ChunkPattern(
    name: 'single-low-platform',
    platforms: <PlatformRel>[
      PlatformRel(x: 160, width: 160, aboveGroundTop: 48, thickness: _t),
    ],
    obstacles: <ObstacleRel>[],
    groundGaps: <GapRel>[
      GapRel(x: 64, width: 96),
    ],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 240, chancePercent: 10, salt: 0x11),
    ],
  ),
  ChunkPattern(
    name: 'two-low-platforms',
    platforms: <PlatformRel>[
      PlatformRel(x: 64, width: 144, aboveGroundTop: 48, thickness: _t),
      PlatformRel(x: 272, width: 144, aboveGroundTop: 64, thickness: _t),
    ],
    obstacles: <ObstacleRel>[],
    groundGaps: <GapRel>[],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 448, chancePercent: 10, salt: 0x12),
    ],
  ),
];

/// Full pattern pool for later chunks (index >= 3).
///
/// Includes [easyPatterns] plus more challenging layouts.
const List<ChunkPattern> allPatterns = <ChunkPattern>[
  // ── Recovery / breathers ──
  ...easyPatterns,

  // ── Platforming ──
  ChunkPattern(
    name: 'staggered-mid-platforms',
    platforms: <PlatformRel>[
      PlatformRel(x: 48, width: 160, aboveGroundTop: 64, thickness: _t),
      PlatformRel(x: 256, width: 160, aboveGroundTop: 96, thickness: _t),
    ],
    groundGaps: <GapRel>[
      GapRel(x: 240, width: 128),
    ],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 352, chancePercent: 17, salt: 0x01),
    ],
  ),
  ChunkPattern(
    name: 'triple-runner-platforms',
    platforms: <PlatformRel>[
      PlatformRel(x: 32, width: 128, aboveGroundTop: 48, thickness: _t),
      PlatformRel(x: 192, width: 128, aboveGroundTop: 80, thickness: _t),
      PlatformRel(x: 352, width: 96, aboveGroundTop: 64, thickness: _t),
    ],
    groundGaps: <GapRel>[],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 288, chancePercent: 15, salt: 0x02),
    ],
  ),
  ChunkPattern(
    name: 'high-platform-over-obstacle',
    platforms: <PlatformRel>[
      PlatformRel(x: 224, width: 192, aboveGroundTop: 112, thickness: _t),
    ],
    obstacles: <ObstacleRel>[
      ObstacleRel(x: 128, width: 48, height: 64),
    ],
    groundGaps: <GapRel>[
      GapRel(x: 176, width: 96),
    ],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 320, chancePercent: 22, salt: 0x03),
    ],
  ),

  // ── Obstacles (ground blocks that force a jump/dash) ──
  ChunkPattern(
    name: 'single-block',
    obstacles: <ObstacleRel>[
      ObstacleRel(x: 224, width: 48, height: 64),
    ],
    groundGaps: <GapRel>[
      GapRel(x: 128, width: 96),
    ],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 320, chancePercent: 17, salt: 0x04),
    ],
  ),
  ChunkPattern(
    name: 'double-blocks',
    obstacles: <ObstacleRel>[
      ObstacleRel(x: 160, width: 32, height: 48),
      ObstacleRel(x: 288, width: 48, height: 64),
    ],
    groundGaps: <GapRel>[],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 96, chancePercent: 12, salt: 0x05),
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 352, chancePercent: 15, salt: 0x06),
    ],
  ),
  ChunkPattern(
    name: 'low-staircase-platforms',
    platforms: <PlatformRel>[
      PlatformRel(x: 48, width: 128, aboveGroundTop: 48, thickness: _t),
      PlatformRel(x: 208, width: 128, aboveGroundTop: 64, thickness: _t),
      PlatformRel(x: 368, width: 128, aboveGroundTop: 80, thickness: _t),
    ],
    groundGaps: <GapRel>[
      GapRel(x: 304, width: 96),
    ],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 112, chancePercent: 15, salt: 0x07),
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 320, chancePercent: 15, salt: 0x08),
    ],
  ),
  ChunkPattern(
    name: 'wide-platform-gap',
    platforms: <PlatformRel>[
      PlatformRel(x: 32, width: 192, aboveGroundTop: 64, thickness: _t),
      PlatformRel(x: 288, width: 192, aboveGroundTop: 64, thickness: _t),
    ],
    groundGaps: <GapRel>[],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 192, chancePercent: 17, salt: 0x09),
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 448, chancePercent: 15, salt: 0x0A),
    ],
  ),
  ChunkPattern(
    name: 'double-obstacle-lane',
    obstacles: <ObstacleRel>[
      ObstacleRel(x: 144, width: 48, height: 64),
      ObstacleRel(x: 336, width: 48, height: 64),
    ],
    groundGaps: <GapRel>[],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 256, chancePercent: 17, salt: 0x0B),
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 80, chancePercent: 12, salt: 0x0C),
    ],
  ),
  ChunkPattern(
    name: 'mid-platform-overhang',
    platforms: <PlatformRel>[
      PlatformRel(x: 96, width: 160, aboveGroundTop: 96, thickness: _t),
      PlatformRel(x: 384, width: 128, aboveGroundTop: 64, thickness: _t),
    ],
    obstacles: <ObstacleRel>[
      ObstacleRel(x: 320, width: 64, height: 80),
    ],
    groundGaps: <GapRel>[],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 176, chancePercent: 15, salt: 0x0D),
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 448, chancePercent: 15, salt: 0x0E),
    ],
  ),
  ChunkPattern(
    name: 'tight-platforms',
    platforms: <PlatformRel>[
      PlatformRel(x: 32, width: 96, aboveGroundTop: 80, thickness: _t),
      PlatformRel(x: 160, width: 96, aboveGroundTop: 96, thickness: _t),
      PlatformRel(x: 288, width: 96, aboveGroundTop: 80, thickness: _t),
    ],
    obstacles: <ObstacleRel>[
      ObstacleRel(x: 448, width: 48, height: 64),
    ],
    groundGaps: <GapRel>[
      GapRel(x: 112, width: 128),
    ],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 240, chancePercent: 15, salt: 0x0F),
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 480, chancePercent: 12, salt: 0x10),
    ],
  ),

  // ── Ground gaps ──
  ChunkPattern(
    name: 'ground-gap-small',
    groundGaps: <GapRel>[
      GapRel(x: 256, width: 64),
    ],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 160, chancePercent: 12, salt: 0x21),
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 416, chancePercent: 12, salt: 0x22),
    ],
  ),
  ChunkPattern(
    name: 'ground-gap-wide',
    groundGaps: <GapRel>[
      GapRel(x: 224, width: 128),
    ],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
          enemyId: EnemyId.flyingEnemy, x: 96, chancePercent: 12, salt: 0x23),
      SpawnMarker(
          enemyId: EnemyId.groundEnemy, x: 480, chancePercent: 12, salt: 0x24),
    ],
  ),
];
