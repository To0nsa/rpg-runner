/// Infinite-runner track streaming system.
///
/// Procedurally generates level geometry (platforms, obstacles, ground gaps)
/// and enemy spawn points by selecting from a pool of pre-authored chunk
/// patterns. Uses deterministic RNG so runs are reproducible given the same
/// seed.
library;

import '../collision/static_world_geometry.dart';
import '../enemies/enemy_id.dart';
import '../tuning/track_tuning.dart';
import '../util/deterministic_rng.dart' show mix32;
import 'chunk_builder.dart';
import 'chunk_pattern.dart';
import 'chunk_pattern_pool.dart';

/// Callback to spawn an enemy at a world X position.
typedef SpawnEnemy = void Function(EnemyId enemyId, double x);

/// Metadata for a newly spawned chunk, returned by [TrackStreamer.step].
class TrackSpawnedChunk {
  const TrackSpawnedChunk({
    required this.index,
    required this.startX,
  });

  /// Sequential chunk number (0 = first chunk).
  final int index;

  /// World X coordinate where this chunk begins.
  final double startX;
}

/// Result of a single [TrackStreamer.step] call.
class TrackStreamStepResult {
  const TrackStreamStepResult({
    required this.changed,
    required this.spawnedChunks,
  });

  /// True if geometry lists were rebuilt (chunk spawned or culled).
  final bool changed;

  /// Chunks created this step (empty on steady-state frames).
  final List<TrackSpawnedChunk> spawnedChunks;
}

/// Streams procedural track chunks based on camera position.
///
/// Call [step] each frame with the current camera bounds. The streamer:
/// 1. Spawns new chunks ahead of the camera (within [TrackTuning.spawnAheadMargin]).
/// 2. Culls old chunks behind the camera (beyond [TrackTuning.cullBehindMargin]).
/// 3. Rebuilds [dynamicSolids], [dynamicGroundSegments], [dynamicGroundGaps].
///
/// Pattern selection is deterministic given [seed] and chunk index.
class TrackStreamer {
  /// Creates a streamer seeded for deterministic generation.
  TrackStreamer({
    required this.seed,
    required this.tuning,
    required this.groundTopY,
    required this.patterns,
    required this.earlyPatternChunks,
    required this.noEnemyChunks,
  }) : _nextChunkIndex = 0,
       _nextChunkStartX = 0.0;

  /// RNG seed for pattern selection and spawn rolls.
  final int seed;

  /// Tuning parameters (chunk width, margins, grid snap).
  final TrackTuning tuning;

  /// World Y of the ground surface (platforms offset from this).
  final double groundTopY;

  /// Pattern pools for early vs full difficulty.
  final ChunkPatternPool patterns;

  /// Number of early chunks that use [patterns.easyPatterns].
  final int earlyPatternChunks;

  /// Number of early chunks that suppress enemy spawns.
  final int noEnemyChunks;

  int _nextChunkIndex;
  double _nextChunkStartX;

  final List<_ActiveChunk> _active = <_ActiveChunk>[];
  List<StaticSolid> _dynamicSolids = const <StaticSolid>[];
  List<StaticGroundSegment> _dynamicGroundSegments =
      const <StaticGroundSegment>[];
  List<StaticGroundGap> _dynamicGroundGaps = const <StaticGroundGap>[];

  /// Current streamed solids (excluding any caller-provided base solids).
  List<StaticSolid> get dynamicSolids => _dynamicSolids;

  /// Current streamed ground segments (excluding any base segments).
  List<StaticGroundSegment> get dynamicGroundSegments => _dynamicGroundSegments;

  /// Current streamed ground gaps (excluding any base gaps).
  List<StaticGroundGap> get dynamicGroundGaps => _dynamicGroundGaps;

  /// Advances chunk streaming based on the current camera bounds.
  ///
  /// Returns a step result (spawned chunks + whether geometry changed).
  TrackStreamStepResult step({
    required double cameraLeft,
    required double cameraRight,
    required SpawnEnemy spawnEnemy,
  }) {
    // Streaming disabled – return no-op.
    if (!tuning.enabled) {
      return const TrackStreamStepResult(
        changed: false,
        spawnedChunks: <TrackSpawnedChunk>[],
      );
    }

    var changed = false;
    final spawnedChunks = <TrackSpawnedChunk>[];

    // ── Spawn new chunks ahead of the camera ──
    final spawnLimitX = cameraRight + tuning.spawnAheadMargin;
    while (_nextChunkStartX <= spawnLimitX) {
      final chunkIndex = _nextChunkIndex;
      final startX = _nextChunkStartX;
      final endX = startX + tuning.chunkWidth;

      // Select pattern deterministically from seed + index.
      final pattern = _patternFor(seed, chunkIndex);

      // Build geometry from pattern.
      final solids = buildSolids(
        pattern,
        chunkStartX: startX,
        chunkIndex: chunkIndex,
        groundTopY: groundTopY,
        chunkWidth: tuning.chunkWidth,
        gridSnap: tuning.gridSnap,
      );
      final ground = buildGroundSegments(
        pattern,
        chunkStartX: startX,
        chunkIndex: chunkIndex,
        groundTopY: groundTopY,
        chunkWidth: tuning.chunkWidth,
        gridSnap: tuning.gridSnap,
      );

      // Track active chunk.
      _active.add(
        _ActiveChunk(
          index: chunkIndex,
          startX: startX,
          endX: endX,
          solids: solids,
          groundSegments: ground.segments,
          groundGaps: ground.gaps,
        ),
      );
      spawnedChunks.add(
        TrackSpawnedChunk(index: chunkIndex, startX: startX),
      );

      // Roll for enemy spawns.
      _spawnEnemiesForChunk(
        pattern,
        chunkIndex,
        chunkStartX: startX,
        spawnEnemy: spawnEnemy,
      );

      _nextChunkIndex += 1;
      _nextChunkStartX += tuning.chunkWidth;
      changed = true;
    }

    // ── Cull old chunks behind the camera ──
    final cullLimitX = cameraLeft - tuning.cullBehindMargin;
    while (_active.isNotEmpty && _active.first.endX < cullLimitX) {
      _active.removeAt(0); // O(n) but chunk count is small (~3-5).
      changed = true;
    }

    // ── Rebuild flattened geometry lists if anything changed ──
    if (changed) {
      final rebuilt = <StaticSolid>[];
      final rebuiltGroundSegments = <StaticGroundSegment>[];
      final rebuiltGroundGaps = <StaticGroundGap>[];
      for (final c in _active) {
        rebuilt.addAll(c.solids);
        rebuiltGroundSegments.addAll(c.groundSegments);
        rebuiltGroundGaps.addAll(c.groundGaps);
      }
      _dynamicSolids = List<StaticSolid>.unmodifiable(rebuilt);
      _dynamicGroundSegments =
          List<StaticGroundSegment>.unmodifiable(rebuiltGroundSegments);
      _dynamicGroundGaps =
          List<StaticGroundGap>.unmodifiable(rebuiltGroundGaps);
    }

    return TrackStreamStepResult(
      changed: changed,
      spawnedChunks: List<TrackSpawnedChunk>.unmodifiable(spawnedChunks),
    );
  }

  /// Rolls for enemy spawns defined in [pattern].
  ///
  /// Uses deterministic RNG keyed by seed, chunk index, and marker salt.
  void _spawnEnemiesForChunk(
    ChunkPattern pattern,
    int chunkIndex, {
    required double chunkStartX,
    required SpawnEnemy spawnEnemy,
  }) {
    // Early-game safety: keep first few chunks enemy-free.
    if (chunkIndex < noEnemyChunks) return;

    for (var i = 0; i < pattern.spawnMarkers.length; i += 1) {
      final m = pattern.spawnMarkers[i];

      // Deterministic roll: hash(seed, chunkIndex, markerIndex, salt).
      final roll = mix32(
        seed ^ (chunkIndex * 0x9e3779b9) ^ (i * 0x85ebca6b) ^ m.salt,
      );
      if ((roll % 100) >= m.chancePercent) continue;

      final x = chunkStartX + m.x;
      spawnEnemy(m.enemyId, x);
    }
  }

  /// Selects a chunk pattern deterministically from [seed] and [chunkIndex].
  ///
  /// Early chunks draw from [patterns.easyPatterns]; later chunks use full pool.
  ChunkPattern _patternFor(int seed, int chunkIndex) {
    final isEarly = chunkIndex < earlyPatternChunks;
    final pool = isEarly ? patterns.easyPatterns : patterns.allPatterns;
    // MurmurHash-style mix for uniform distribution.
    final h = mix32(seed ^ (chunkIndex * 0x9e3779b9) ^ 0x27d4eb2d);
    final idx = h % pool.length;
    return pool[idx];
  }
}

/// Tracks a spawned chunk's geometry while it's within camera culling bounds.
class _ActiveChunk {
  const _ActiveChunk({
    required this.index,
    required this.startX,
    required this.endX,
    required this.solids,
    required this.groundSegments,
    required this.groundGaps,
  });

  /// Sequential chunk number.
  final int index;

  /// World X where chunk begins.
  final double startX;

  /// World X where chunk ends (startX + chunkWidth).
  final double endX;

  /// Platforms and obstacles in this chunk.
  final List<StaticSolid> solids;

  /// Walkable ground spans.
  final List<StaticGroundSegment> groundSegments;

  /// Holes in the ground.
  final List<StaticGroundGap> groundGaps;
}
