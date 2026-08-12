/// Infinite-runner track streaming system.
///
/// Selects pre-authored chunks and emits their visual and spawn metadata.
/// Polygon terrain is published separately from the same selected chunk keys;
/// this scheduler never constructs a second collision representation.
library;

import '../enemies/enemy_id.dart';
import '../tuning/track_tuning.dart';
import '../util/deterministic_rng.dart' show mix32;
import 'chunk_pattern.dart';
import 'chunk_pattern_source.dart';

/// Callback to spawn an enemy at a world X position.
typedef SpawnEnemy = void Function(SpawnEnemyRequest request);

/// Why a streamed enemy request was emitted.
enum EnemySpawnRequestSource { authoredMarker, deferredHashashEdge }

/// Spawn request payload emitted by [TrackStreamer].
class SpawnEnemyRequest {
  const SpawnEnemyRequest({
    required this.enemyId,
    required this.x,
    required this.fallbackSupportY,
    this.source = EnemySpawnRequestSource.authoredMarker,
    this.placement = SpawnPlacementMode.ground,
  });

  final EnemyId enemyId;
  final double x;

  /// Historical flat-ground Y used only to seed the desired body transform.
  ///
  /// Polygon terrain resolves the actual support from [placement]. This value
  /// remains deterministic input for flying placement and scheduler-only
  /// fixtures that do not resolve placement.
  final double fallbackSupportY;
  final EnemySpawnRequestSource source;

  /// Authored marker placement intent resolved by world terrain authority.
  final SpawnPlacementMode placement;
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

  /// Stable authored identity key, or null in scheduler-only fixtures.
  final String? chunkKey;
}

/// Immutable selection identity for one currently streamed chunk.
///
/// This is read-only scheduling evidence. It deliberately exposes no collision
/// list or mutable pattern data; polygon publication binds this exact active
/// selection without re-running pattern choice.
class ActiveTrackChunkSnapshot {
  const ActiveTrackChunkSnapshot({
    required this.index,
    required this.startX,
    required this.endX,
    required this.patternName,
    required this.chunkKey,
  });

  /// Deterministic sequential streamed instance index.
  final int index;

  /// Inclusive world-X start in world units.
  final double startX;

  /// Exclusive world-X end in world units.
  final double endX;

  /// Selected authored pattern name retained for diagnostics.
  final String patternName;

  /// Stable authored chunk key, or null in scheduler-only fixtures.
  final String? chunkKey;
}

/// Result of a single [TrackStreamer.step] call.
class TrackStreamStepResult {
  const TrackStreamStepResult({
    required this.changed,
    required this.spawnedChunks,
  });

  /// True if the active chunk selection was rebuilt (spawn or cull).
  final bool changed;

  /// Chunks created this step (empty on steady-state frames).
  final List<TrackSpawnedChunk> spawnedChunks;
}

/// Streams procedural track chunks based on camera position.
///
/// Call [step] each frame with the current camera bounds. The streamer:
/// 1. Spawns new chunks ahead of the camera (within [TrackTuning.spawnAheadMargin]).
/// 2. Culls old chunks behind the camera (beyond [TrackTuning.cullBehindMargin]).
/// 3. Rebuilds the active selection and prefab-visual snapshots.
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
    this.easyPatternChunks = 0,
    this.normalPatternChunks = 0,
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

  /// Number of chunks that should request the `early` tier.
  final int earlyPatternChunks;

  /// Number of chunks after the opening window that should request `easy`.
  final int easyPatternChunks;

  /// Number of chunks after the easy window that should request `normal`.
  final int normalPatternChunks;

  /// Number of early chunks that suppress enemy spawns.
  final int noEnemyChunks;

  int _nextChunkIndex;
  double _nextChunkStartX;

  final List<_ActiveChunk> _active = <_ActiveChunk>[];
  List<ChunkVisualSpriteWorld> _dynamicVisualSprites =
      const <ChunkVisualSpriteWorld>[];
  List<ActiveTrackChunkSnapshot> _activeChunksSnapshot =
      const <ActiveTrackChunkSnapshot>[];

  /// Current streamed visual sprites for chunk prefab rendering.
  List<ChunkVisualSpriteWorld> get dynamicVisualSprites =>
      _dynamicVisualSprites;

  /// Current scheduler selections in canonical streamed-index order.
  ///
  /// The list changes only with the same spawn/cull rebuild that updates visual
  /// metadata. Consumers must treat missing [chunkKey] as incompatible with
  /// polygon-terrain binding rather than selecting a fallback record.
  List<ActiveTrackChunkSnapshot> get activeChunks => _activeChunksSnapshot;

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
      final selection = patternSource.selectionFor(
        seed: seed,
        chunkIndex: chunkIndex,
        tier: _tierForChunkIndex(chunkIndex),
      );
      final pattern = selection.pattern;

      final pendingHashashSpawns = _spawnEnemiesForChunk(
        pattern,
        chunkIndex,
        chunkStartX: startX,
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
              flipX: sprite.flipX,
              flipY: sprite.flipY,
            ),
          )
          .toList(growable: false);

      // Track active chunk.
      _active.add(
        _ActiveChunk(
          index: chunkIndex,
          startX: startX,
          endX: endX,
          patternName: pattern.name,
          chunkKey: pattern.chunkKey,
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

    // ── Rebuild flattened selection/visual lists if anything changed ──
    if (changed) {
      final rebuiltVisualSprites = <ChunkVisualSpriteWorld>[];
      final rebuiltActiveChunks = <ActiveTrackChunkSnapshot>[];
      for (final c in _active) {
        rebuiltVisualSprites.addAll(c.visualSprites);
        rebuiltActiveChunks.add(
          ActiveTrackChunkSnapshot(
            index: c.index,
            startX: c.startX,
            endX: c.endX,
            patternName: c.patternName,
            chunkKey: c.chunkKey,
          ),
        );
      }
      _dynamicVisualSprites = List<ChunkVisualSpriteWorld>.unmodifiable(
        rebuiltVisualSprites,
      );
      _activeChunksSnapshot = List<ActiveTrackChunkSnapshot>.unmodifiable(
        rebuiltActiveChunks,
      );
    }

    return TrackStreamStepResult(
      changed: changed,
      spawnedChunks: List<TrackSpawnedChunk>.unmodifiable(spawnedChunks),
    );
  }

  ChunkPatternTier _tierForChunkIndex(int chunkIndex) {
    if (chunkIndex < earlyPatternChunks) {
      return ChunkPatternTier.early;
    }
    final easyStart = earlyPatternChunks;
    final normalStart = easyStart + easyPatternChunks;
    final hardStart = normalStart + normalPatternChunks;
    if (chunkIndex < normalStart) {
      return ChunkPatternTier.easy;
    }
    if (chunkIndex < hardStart) {
      return ChunkPatternTier.normal;
    }
    return ChunkPatternTier.hard;
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
      spawnEnemy(
        SpawnEnemyRequest(
          enemyId: m.enemyId,
          x: x,
          fallbackSupportY: groundTopY,
          placement: m.placement,
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
          fallbackSupportY: groundTopY,
          source: EnemySpawnRequestSource.deferredHashashEdge,
        ),
      );
    }
    visibleRightChunk.pendingHashashSpawns = 0;
  }

  double _hashashEdgeSpawnX(_ActiveChunk chunk) {
    final minX = chunk.startX;
    final maxX = chunk.endX;
    final preferred = minX + _hashashEdgeSpawnInsetX;
    if (preferred < minX) return minX;
    if (preferred > maxX) return maxX;
    return preferred;
  }

  static const double _hashashEdgeSpawnInsetX = -96.0;
}

/// Tracks a spawned chunk's geometry while it's within camera culling bounds.
class _ActiveChunk {
  _ActiveChunk({
    required this.index,
    required this.startX,
    required this.endX,
    required this.patternName,
    required this.chunkKey,
    required this.visualSprites,
    this.pendingHashashSpawns = 0,
  });

  /// Sequential chunk number.
  final int index;

  /// World X where chunk begins.
  final double startX;

  /// World X where chunk ends (startX + chunkWidth).
  final double endX;

  /// Selected authored pattern name retained for read-only diagnostics.
  final String patternName;

  /// Stable authored chunk identity, if the fixture provides one.
  final String? chunkKey;

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
    this.flipX = false,
    this.flipY = false,
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
  final bool flipX;
  final bool flipY;
}
