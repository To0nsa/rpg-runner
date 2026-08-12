/// Deterministic track-selection, visual, and deferred-item lifecycle.
///
/// Polygon terrain is the only collision/navigation authority. This manager
/// owns scheduler state and publishes the matching prefab-visual/item batches;
/// [GameCore] binds selected chunk keys to admitted terrain before applying
/// the returned ECS mutations.
library;

import 'ecs/stores/restoration_item_store.dart' show RestorationStat;
import 'snapshots/static_prefab_sprite_snapshot.dart';
import 'spawn_service.dart' hide StaticSolid;
import 'track/chunk_pattern_defaults.dart';
import 'track/chunk_pattern_source.dart';
import 'track/track_streamer.dart';
import 'tuning/collectible_tuning.dart';
import 'tuning/restoration_item_tuning.dart';
import 'tuning/track_tuning.dart';

/// Callback invoked when a selected chunk emits an enemy spawn request.
typedef SpawnEnemyCallback = void Function(SpawnEnemyRequest request);

/// Result of one scheduler step.
class TrackStepResult {
  const TrackStepResult({
    required this.selectionChanged,
    this.spawnedChunks = const <TrackSpawnedChunk>[],
  });

  /// Whether the canonical active chunk selection changed.
  final bool selectionChanged;

  /// Newly selected chunks whose procedural items remain deferred.
  final List<TrackSpawnedChunk> spawnedChunks;
}

/// Owns streamed chunk selection and its non-terrain runtime projections.
class TrackManager {
  TrackManager({
    required int seed,
    required TrackTuning trackTuning,
    required CollectibleTuning collectibleTuning,
    required RestorationItemTuning restorationItemTuning,
    required SpawnService spawnService,
    required double groundTopY,
    required ChunkPatternSource chunkPatternSource,
    TrackStreamer? trackStreamer,
    int earlyPatternChunks = defaultEarlyPatternChunks,
    int easyPatternChunks = defaultEasyPatternChunks,
    int normalPatternChunks = defaultNormalPatternChunks,
    int noEnemyChunks = defaultNoEnemyChunks,
  }) : _trackTuning = trackTuning,
       _collectibleTuning = collectibleTuning,
       _restorationItemTuning = restorationItemTuning,
       _spawnService = spawnService,
       _trackStreamer = trackStreamer,
       _chunkPatternSource = chunkPatternSource,
       _earlyPatternChunks = earlyPatternChunks,
       _easyPatternChunks = easyPatternChunks,
       _normalPatternChunks = normalPatternChunks,
       _noEnemyChunks = noEnemyChunks {
    if (!_trackTuning.enabled && _trackStreamer != null) {
      throw ArgumentError.value(
        _trackStreamer,
        'trackStreamer',
        'A prewarmed streamer requires enabled track tuning.',
      );
    }

    if (_trackTuning.enabled && _trackStreamer == null) {
      _trackStreamer = TrackStreamer(
        seed: seed,
        tuning: _trackTuning,
        groundTopY: groundTopY,
        patternSource: _chunkPatternSource,
        earlyPatternChunks: _earlyPatternChunks,
        easyPatternChunks: _easyPatternChunks,
        normalPatternChunks: _normalPatternChunks,
        noEnemyChunks: _noEnemyChunks,
      );
    }

    final streamer = _trackStreamer;
    if (streamer != null) {
      _staticPrefabSpritesSnapshot =
          List<StaticPrefabSpriteSnapshot>.unmodifiable(
            streamer.dynamicVisualSprites.map(_toStaticPrefabSpriteSnapshot),
          );
    }
  }

  final TrackTuning _trackTuning;
  final CollectibleTuning _collectibleTuning;
  final RestorationItemTuning _restorationItemTuning;
  final SpawnService _spawnService;
  final ChunkPatternSource _chunkPatternSource;
  final int _earlyPatternChunks;
  final int _easyPatternChunks;
  final int _normalPatternChunks;
  final int _noEnemyChunks;

  TrackStreamer? _trackStreamer;
  List<StaticPrefabSpriteSnapshot> _staticPrefabSpritesSnapshot =
      const <StaticPrefabSpriteSnapshot>[];

  /// Immutable authored prefab visuals for the active scheduler selection.
  List<StaticPrefabSpriteSnapshot> get staticPrefabSpritesSnapshot =>
      _staticPrefabSpritesSnapshot;

  /// Current canonical selections used for admitted terrain binding.
  List<ActiveTrackChunkSnapshot> get activeChunks =>
      _trackStreamer?.activeChunks ?? const <ActiveTrackChunkSnapshot>[];

  /// Resolves the level-scoped render theme.
  String? resolveRenderVisualThemeId({
    required double cameraCenterX,
    required String? levelVisualThemeId,
  }) {
    final _ = cameraCenterX;
    return levelVisualThemeId;
  }

  /// Advances selection and refreshes its prefab-visual projection.
  TrackStepResult step({
    required double cameraLeft,
    required double cameraRight,
    required SpawnEnemyCallback spawnEnemy,
  }) {
    final streamer = _trackStreamer;
    if (streamer == null) {
      return const TrackStepResult(selectionChanged: false);
    }

    final result = streamer.step(
      cameraLeft: cameraLeft,
      cameraRight: cameraRight,
      spawnEnemy: spawnEnemy,
    );
    if (!result.changed) {
      return const TrackStepResult(selectionChanged: false);
    }

    _staticPrefabSpritesSnapshot =
        List<StaticPrefabSpriteSnapshot>.unmodifiable(
          streamer.dynamicVisualSprites.map(_toStaticPrefabSpriteSnapshot),
        );
    return TrackStepResult(
      selectionChanged: true,
      spawnedChunks: result.spawnedChunks,
    );
  }

  /// Applies procedural item mutations after matching terrain publication.
  void spawnItemsForChunks({
    required Iterable<TrackSpawnedChunk> chunks,
    required RestorationStat Function() lowestResourceStat,
  }) {
    const noLegacySolids =
        <({double minX, double maxX, double minY, double maxY})>[];
    for (final chunk in chunks) {
      if (_collectibleTuning.enabled) {
        _spawnService.spawnCollectiblesForChunk(
          chunkIndex: chunk.index,
          chunkStartX: chunk.startX,
          solids: noLegacySolids,
        );
      }
      if (_restorationItemTuning.enabled) {
        _spawnService.spawnRestorationItemForChunk(
          chunkIndex: chunk.index,
          chunkStartX: chunk.startX,
          solids: noLegacySolids,
          lowestResourceStat: lowestResourceStat,
        );
      }
    }
  }

  static StaticPrefabSpriteSnapshot _toStaticPrefabSpriteSnapshot(
    ChunkVisualSpriteWorld sprite,
  ) {
    return StaticPrefabSpriteSnapshot(
      assetPath: sprite.assetPath,
      srcX: sprite.srcX,
      srcY: sprite.srcY,
      srcWidth: sprite.srcWidth,
      srcHeight: sprite.srcHeight,
      x: sprite.x,
      y: sprite.y,
      width: sprite.width,
      height: sprite.height,
      zIndex: sprite.zIndex,
      flipX: sprite.flipX,
      flipY: sprite.flipY,
    );
  }
}
