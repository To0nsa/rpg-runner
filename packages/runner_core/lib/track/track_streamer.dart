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
import 'chunk_pattern_source.dart';

/// Callback to spawn an enemy at a world X position.
typedef SpawnEnemy = void Function(SpawnEnemyRequest request);

/// Spawn request payload emitted by [TrackStreamer].
class SpawnEnemyRequest {
  const SpawnEnemyRequest({
    required this.enemyId,
    required this.x,
    required this.surfaceTopY,
  });

  final EnemyId enemyId;
  final double x;
  final double surfaceTopY;
}

/// Metadata for a newly spawned chunk, returned by [TrackStreamer.step].
class TrackSpawnedChunk {
  const TrackSpawnedChunk({
    required this.index,
    required this.startX,
    required this.patternName,
    this.chunkKey,
  });

  /// Sequential chunk number (0 = first chunk).
  final int index;

  /// World X coordinate where this chunk begins.
  final double startX;

  /// Pattern identifier used to generate this chunk.
  final String patternName;

  /// Stable authored identity key for this chunk (optional during migration).
  final String? chunkKey;
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
    required this.patternSource,
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

  /// Pattern source for early vs full difficulty selection.
  final ChunkPatternSource patternSource;

  /// Number of early chunks that should draw from an easier source pool.
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
    List<ChunkVisualSpriteWorld> _dynamicVisualSprites =
      const <ChunkVisualSpriteWorld>[];

  /// Current streamed solids (excluding any caller-provided base solids).
  List<StaticSolid> get dynamicSolids => _dynamicSolids;

  /// Current streamed ground segments (excluding any base segments).
  List<StaticGroundSegment> get dynamicGroundSegments => _dynamicGroundSegments;

  /// Current streamed ground gaps (excluding any base gaps).
  List<StaticGroundGap> get dynamicGroundGaps => _dynamicGroundGaps;

  /// Current streamed visual sprites for chunk prefab rendering.
  List<ChunkVisualSpriteWorld> get dynamicVisualSprites => _dynamicVisualSprites;

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
      final pattern = patternSource.patternFor(
        seed: seed,
        chunkIndex: chunkIndex,
        isEarlyChunk: chunkIndex < earlyPatternChunks,
      );

      late List<StaticSolid> solids;
      late GroundBuildResult ground;
      try {
        // Build geometry from pattern.
        solids = buildSolids(
          pattern,
          chunkStartX: startX,
          chunkIndex: chunkIndex,
          groundTopY: groundTopY,
          chunkWidth: tuning.chunkWidth,
          gridSnap: tuning.gridSnap,
        );
        ground = buildGroundSegments(
          pattern,
          chunkStartX: startX,
          chunkIndex: chunkIndex,
          groundTopY: groundTopY,
          chunkWidth: tuning.chunkWidth,
          gridSnap: tuning.gridSnap,
        );
      } on Object catch (error, stackTrace) {
        final chunkKey = pattern.chunkKey;
        final chunkKeyPart = (chunkKey == null || chunkKey.isEmpty)
            ? ''
            : ', chunkKey=$chunkKey';
        final wrapped = StateError(
          'TrackStreamer failed to build chunk '
          '(index=$chunkIndex, startX=$startX, pattern=${pattern.name}'
          '$chunkKeyPart): $error',
        );
        Error.throwWithStackTrace(wrapped, stackTrace);
      }

      final pendingHashashSpawns = _spawnEnemiesForChunk(
        pattern,
        chunkIndex,
        chunkStartX: startX,
        solids: solids,
        groundSegments: ground.segments,
        spawnEnemy: spawnEnemy,
      );

      final visualSprites = pattern.visualSprites
          .map(
            (sprite) => ChunkVisualSpriteWorld(
              assetPath: sprite.assetPath,
              srcX: sprite.srcX,
              srcY: sprite.srcY,
              srcWidth: sprite.srcWidth,
              srcHeight: sprite.srcHeight,
              x: startX + sprite.x,
              y: sprite.y,
              width: sprite.width,
              height: sprite.height,
              zIndex: sprite.zIndex,
            ),
          )
          .toList(growable: false);

      // Track active chunk.
      _active.add(
        _ActiveChunk(
          index: chunkIndex,
          startX: startX,
          endX: endX,
          solids: solids,
          groundSegments: ground.segments,
          groundGaps: ground.gaps,
          visualSprites: visualSprites,
          pendingHashashSpawns: pendingHashashSpawns,
        ),
      );
      spawnedChunks.add(
        TrackSpawnedChunk(
          index: chunkIndex,
          startX: startX,
          patternName: pattern.name,
          chunkKey: pattern.chunkKey,
        ),
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

    // ── Spawn deferred hashash entries once their chunk becomes camera-right ──
    _spawnDeferredHashashForVisibleChunk(
      cameraRight: cameraRight,
      spawnEnemy: spawnEnemy,
    );

    // ── Rebuild flattened geometry lists if anything changed ──
    if (changed) {
      final rebuilt = <StaticSolid>[];
      final rebuiltGroundSegments = <StaticGroundSegment>[];
      final rebuiltGroundGaps = <StaticGroundGap>[];
      final rebuiltVisualSprites = <ChunkVisualSpriteWorld>[];
      for (final c in _active) {
        rebuilt.addAll(c.solids);
        rebuiltGroundSegments.addAll(c.groundSegments);
        rebuiltGroundGaps.addAll(c.groundGaps);
        rebuiltVisualSprites.addAll(c.visualSprites);
      }
      _dynamicSolids = List<StaticSolid>.unmodifiable(rebuilt);
      _dynamicGroundSegments = List<StaticGroundSegment>.unmodifiable(
        rebuiltGroundSegments,
      );
      _dynamicGroundGaps = List<StaticGroundGap>.unmodifiable(
        rebuiltGroundGaps,
      );
      _dynamicVisualSprites = List<ChunkVisualSpriteWorld>.unmodifiable(
        rebuiltVisualSprites,
      );
    }

    return TrackStreamStepResult(
      changed: changed,
      spawnedChunks: List<TrackSpawnedChunk>.unmodifiable(spawnedChunks),
    );
  }

  /// Rolls for enemy spawns defined in [pattern].
  ///
  /// Uses deterministic RNG keyed by seed, chunk index, and marker salt.
  ///
  /// Returns how many hashash spawns were deferred for edge-teleport spawning.
  int _spawnEnemiesForChunk(
    ChunkPattern pattern,
    int chunkIndex, {
    required double chunkStartX,
    required List<StaticSolid> solids,
    required List<StaticGroundSegment> groundSegments,
    required SpawnEnemy spawnEnemy,
  }) {
    // Early-game safety: keep first few chunks enemy-free.
    if (chunkIndex < noEnemyChunks) return 0;

    var pendingHashashSpawns = 0;

    for (var i = 0; i < pattern.spawnMarkers.length; i += 1) {
      final m = pattern.spawnMarkers[i];

      // Deterministic roll: hash(seed, chunkIndex, markerIndex, salt).
      final roll = mix32(
        seed ^ (chunkIndex * 0x9e3779b9) ^ (i * 0x85ebca6b) ^ m.salt,
      );
      if ((roll % 100) >= m.chancePercent) continue;

      if (m.enemyId == EnemyId.hashash) {
        pendingHashashSpawns += 1;
        continue;
      }

      final x = chunkStartX + m.x;
      final spawnSurfaceTopY = _resolveSpawnSurfaceTopY(
        marker: m,
        x: x,
        solids: solids,
        groundSegments: groundSegments,
      );
      spawnEnemy(
        SpawnEnemyRequest(
          enemyId: m.enemyId,
          x: x,
          surfaceTopY: spawnSurfaceTopY,
        ),
      );
    }

    return pendingHashashSpawns;
  }

  void _spawnDeferredHashashForVisibleChunk({
    required double cameraRight,
    required SpawnEnemy spawnEnemy,
  }) {
    if (_active.isEmpty) return;

    _ActiveChunk? visibleRightChunk;
    for (final chunk in _active) {
      if (cameraRight >= chunk.startX && cameraRight < chunk.endX) {
        visibleRightChunk = chunk;
        break;
      }
    }
    visibleRightChunk ??= _active.last;
    final pending = visibleRightChunk.pendingHashashSpawns;
    if (pending <= 0) return;

    final spawnX = _hashashEdgeSpawnX(visibleRightChunk);
    for (var i = 0; i < pending; i += 1) {
      spawnEnemy(
        SpawnEnemyRequest(
          enemyId: EnemyId.hashash,
          x: spawnX,
          surfaceTopY: groundTopY,
        ),
      );
    }
    visibleRightChunk.pendingHashashSpawns = 0;
  }

  double _hashashEdgeSpawnX(_ActiveChunk chunk) {
    double minX = chunk.startX;
    double maxX = chunk.endX;

    if (chunk.groundSegments.isNotEmpty) {
      var leftMost = chunk.groundSegments.first;
      for (var i = 1; i < chunk.groundSegments.length; i += 1) {
        final candidate = chunk.groundSegments[i];
        if (candidate.minX < leftMost.minX) {
          leftMost = candidate;
        }
      }
      minX = leftMost.minX;
      maxX = leftMost.maxX;
    }

    final preferred = minX + _hashashEdgeSpawnInsetX;
    if (preferred < minX) return minX;
    if (preferred > maxX) return maxX;
    return preferred;
  }

  static const double _hashashEdgeSpawnInsetX = -96.0;

  double _resolveSpawnSurfaceTopY({
    required SpawnMarker marker,
    required double x,
    required List<StaticSolid> solids,
    required List<StaticGroundSegment> groundSegments,
  }) {
    switch (marker.placement) {
      case SpawnPlacementMode.ground:
        return groundTopY;
      case SpawnPlacementMode.highestSurfaceAtX:
        return _resolveHighestSurfaceTopYAtX(
              x: x,
              solids: solids,
              groundSegments: groundSegments,
            ) ??
            groundTopY;
      case SpawnPlacementMode.obstacleTop:
        return _resolveObstacleTopYAtX(x: x, solids: solids) ??
            _resolveHighestSurfaceTopYAtX(
              x: x,
              solids: solids,
              groundSegments: groundSegments,
            ) ??
            groundTopY;
    }
  }

  double? _resolveObstacleTopYAtX({
    required double x,
    required List<StaticSolid> solids,
  }) {
    _SurfaceCandidate? best;
    for (var i = 0; i < solids.length; i += 1) {
      final solid = solids[i];
      if (solid.oneWayTop) continue;
      if ((solid.sides & StaticSolid.sideTop) == 0) continue;
      if (x < solid.minX || x > solid.maxX) continue;
      final stableId = solid.localSolidIndex >= 0 ? solid.localSolidIndex : i;
      final candidate = _SurfaceCandidate(yTop: solid.minY, stableId: stableId);
      if (best == null || candidate.isHigherPriorityThan(best)) {
        best = candidate;
      }
    }
    return best?.yTop;
  }

  double? _resolveHighestSurfaceTopYAtX({
    required double x,
    required List<StaticSolid> solids,
    required List<StaticGroundSegment> groundSegments,
  }) {
    _SurfaceCandidate? best;

    for (var i = 0; i < groundSegments.length; i += 1) {
      final segment = groundSegments[i];
      if (x < segment.minX || x > segment.maxX) continue;
      final stableId = segment.localSegmentIndex >= 0
          ? 1000000 + segment.localSegmentIndex
          : 1000000 + i;
      final candidate = _SurfaceCandidate(
        yTop: segment.topY,
        stableId: stableId,
      );
      if (best == null || candidate.isHigherPriorityThan(best)) {
        best = candidate;
      }
    }

    for (var i = 0; i < solids.length; i += 1) {
      final solid = solids[i];
      if ((solid.sides & StaticSolid.sideTop) == 0) continue;
      if (x < solid.minX || x > solid.maxX) continue;
      final stableId = solid.localSolidIndex >= 0 ? solid.localSolidIndex : i;
      final candidate = _SurfaceCandidate(yTop: solid.minY, stableId: stableId);
      if (best == null || candidate.isHigherPriorityThan(best)) {
        best = candidate;
      }
    }

    return best?.yTop;
  }
}

/// Tracks a spawned chunk's geometry while it's within camera culling bounds.
class _ActiveChunk {
  _ActiveChunk({
    required this.index,
    required this.startX,
    required this.endX,
    required this.solids,
    required this.groundSegments,
    required this.groundGaps,
    required this.visualSprites,
    this.pendingHashashSpawns = 0,
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

  /// Render sprites for authored prefab visuals in this chunk.
  final List<ChunkVisualSpriteWorld> visualSprites;

  /// Deferred hashash spawns that should trigger when this chunk is camera-right.
  int pendingHashashSpawns;
}

/// World-space visual sprite emitted by [TrackStreamer].
class ChunkVisualSpriteWorld {
  const ChunkVisualSpriteWorld({
    required this.assetPath,
    required this.srcX,
    required this.srcY,
    required this.srcWidth,
    required this.srcHeight,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
  });

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
}

class _SurfaceCandidate {
  const _SurfaceCandidate({required this.yTop, required this.stableId});

  final double yTop;
  final int stableId;

  bool isHigherPriorityThan(_SurfaceCandidate other) {
    if (yTop < other.yTop - 1e-9) return true;
    if ((yTop - other.yTop).abs() <= 1e-9 && stableId < other.stableId) {
      return true;
    }
    return false;
  }
}
