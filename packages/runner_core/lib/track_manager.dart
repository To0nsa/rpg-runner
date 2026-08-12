/// Track streaming and geometry lifecycle management.
///
/// This module handles the procedural generation of track chunks as the
/// player progresses. Polygon terrain owns production collision/navigation;
/// temporary synthetic fixtures may still request legacy read models.
///
/// ## Architecture
///
/// [TrackManager] is owned by [GameCore] and orchestrates:
/// - **Track streaming**: [TrackStreamer] spawns/culls chunks based on camera.
/// - **Legacy fixture geometry**: Optionally merges rectangle test data.
/// - **Deferred item spawning**: Applies a selected batch only after GameCore's
///   terrain-publication barrier.
///
/// ## Geometry Lifecycle
///
/// ```
/// Camera moves right
///        ↓
/// TrackStreamer.step() detects chunk spawn/cull needed
///        ↓
/// TrackManager publishes selection and prefab visuals
///        ↓
/// GameCore builds/publishes matching polygon terrain
///        ↓
/// GameCore applies captured spawns
/// ```
///
/// ## Chunk Spawning Flow
///
/// When a new chunk enters the horizon:
/// 1. [TrackStreamer] generates platforms and enemy spawn points.
/// 2. GameCore completes the matching staged terrain candidate.
/// 3. GameCore publishes terrain, then places enemies and items via
///    [SpawnService].
library;

import 'collision/static_world_geometry_index.dart';
import 'enemies/enemy_id.dart';
import 'ecs/stores/restoration_item_store.dart' show RestorationStat;
import 'ecs/systems/ground_enemy_locomotion_system.dart';
import 'ecs/systems/enemy_navigation_system.dart';
import 'navigation/surface_graph_builder.dart';
import 'navigation/types/surface_graph.dart';
import 'navigation/utils/jump_template.dart';
import 'snapshots/ground_surface_snapshot.dart';
import 'snapshots/static_prefab_sprite_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
import 'spawn_service.dart' hide StaticSolid;
import 'track/chunk_pattern_defaults.dart';
import 'track/chunk_pattern_source.dart';
import 'track/track_streamer.dart';
import 'tuning/collectible_tuning.dart';
import 'tuning/restoration_item_tuning.dart';
import 'tuning/track_tuning.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

/// Callback invoked when a chunk's enemy spawn point enters the horizon.
///
/// - [enemyId]: The type of enemy to spawn (ground or flying).
/// - [x]: The world X coordinate for the spawn.
typedef SpawnEnemyCallback = void Function(SpawnEnemyRequest request);

/// Result of a single [TrackManager.step] call.
///
/// Used by [GameCore] to decide whether to update render snapshots.
class TrackStepResult {
  const TrackStepResult({
    required this.geometryChanged,
    this.spawnedChunks = const <TrackSpawnedChunk>[],
  });

  /// Whether static geometry was updated this step.
  ///
  /// When true, collision indices, surface graphs, and render snapshots
  /// have all been regenerated.
  final bool geometryChanged;

  /// Newly selected chunks whose procedural items have not been spawned yet.
  ///
  /// [GameCore] consumes this batch only after the matching terrain publication
  /// is available, so placement never observes geometry from another selection.
  final List<TrackSpawnedChunk> spawnedChunks;
}

// ─────────────────────────────────────────────────────────────────────────────
// TrackManager
// ─────────────────────────────────────────────────────────────────────────────

/// Manages track streaming and deferred spawn/visual batches.
///
/// Responsibilities:
/// - Steps [TrackStreamer] each tick to spawn/cull chunks.
/// - Optionally maintains legacy geometry/graphs for synthetic fixtures.
/// - Returns new chunks for collectible/item placement after publication.
///
/// Usage:
/// ```dart
/// final manager = TrackManager(seed: 42, ...);
/// final result = manager.step(
///   currentTick: tick,
///   cameraLeft: cam.left,
///   cameraRight: cam.right,
///   spawnEnemy: pendingEnemies.add,
/// );
/// if (result.geometryChanged) {
///   // Update render snapshots
/// }
/// ```
class TrackManager {
  /// Creates a track manager with the given dependencies.
  ///
  /// - [seed]: Master RNG seed for deterministic chunk generation.
  /// - [trackTuning]: Chunk dimensions, spawn horizons, platform density.
  /// - [collectibleTuning]: Collectible spawn parameters.
  /// - [restorationItemTuning]: Restoration item spawn parameters.
  /// - [baseGeometry]: Static level geometry (ground plane, initial platforms).
  /// - [surfaceGraphBuilder]: Builder for navigation surface graphs.
  /// - [enemyJumpTemplatesById]: Per-enemy jump/support profiles for nav graphs.
  /// - [enemyNavigationSystem]: Ground enemy navigation (receives graph updates).
  /// - [groundEnemyLocomotionSystem]: Ground locomotion (receives graph updates).
  /// - [spawnService]: Entity spawner (receives surface graph updates).
  /// - [groundTopY]: Y coordinate of the ground surface (for spawning).
  /// - [chunkPatternSource]: Deterministic tiered chunk pattern source.
  /// - [trackStreamer]: Optional scheduler state already selected at startup.
  /// - [earlyPatternChunks]: Number of chunks requesting the `early` tier.
  /// - [easyPatternChunks]: Number of chunks after the opening window requesting `easy`.
  /// - [normalPatternChunks]: Number of chunks after the easy window requesting `normal`.
  /// - [noEnemyChunks]: Number of early chunks that suppress enemy spawns.
  TrackManager({
    required int seed,
    required TrackTuning trackTuning,
    required CollectibleTuning collectibleTuning,
    required RestorationItemTuning restorationItemTuning,
    required StaticWorldGeometry baseGeometry,
    required SurfaceGraphBuilder? surfaceGraphBuilder,
    required Map<EnemyId, JumpReachabilityTemplate> enemyJumpTemplatesById,
    required EnemyNavigationSystem? enemyNavigationSystem,
    required GroundEnemyLocomotionSystem groundEnemyLocomotionSystem,
    required SpawnService spawnService,
    required bool legacyReadModelsEnabled,
    required double groundTopY,
    required ChunkPatternSource chunkPatternSource,
    TrackStreamer? trackStreamer,
    int earlyPatternChunks = defaultEarlyPatternChunks,
    int easyPatternChunks = defaultEasyPatternChunks,
    int normalPatternChunks = defaultNormalPatternChunks,
    int noEnemyChunks = defaultNoEnemyChunks,
  }) : assert(enemyJumpTemplatesById.isNotEmpty),
       _trackTuning = trackTuning,
       _collectibleTuning = collectibleTuning,
       _restorationItemTuning = restorationItemTuning,
       _baseGeometry = baseGeometry,
       _surfaceGraphBuilder = surfaceGraphBuilder,
       _enemyJumpTemplatesById =
           Map<EnemyId, JumpReachabilityTemplate>.unmodifiable(
             enemyJumpTemplatesById,
           ),
       _enemyNavigationSystem = enemyNavigationSystem,
       _groundEnemyLocomotionSystem = groundEnemyLocomotionSystem,
       _spawnService = spawnService,
       _legacyReadModelsEnabled = legacyReadModelsEnabled,
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
    if (_legacyReadModelsEnabled &&
        (_surfaceGraphBuilder == null || _enemyNavigationSystem == null)) {
      throw ArgumentError(
        'Legacy read models require their rectangle graph dependencies.',
      );
    }

    // Create a track streamer unless the caller already performed the initial
    // deterministic selection before ECS entities were spawned.
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

    // Synthetic fixtures retain the old read models until their Phase 6 test
    // migration. Normal streamed runs publish no rectangle collision/graph
    // projection and do not pay its rebuild cost.
    final streamer = _trackStreamer;
    _staticGeometry = !_legacyReadModelsEnabled
        ? const StaticWorldGeometry()
        : streamer == null
        ? baseGeometry
        : _combinedLegacyGeometry(streamer);
    _staticIndex = StaticWorldGeometryIndex.from(_staticGeometry);
    _staticSolidsSnapshot = _buildStaticSolidsSnapshot(_staticGeometry);
    _groundSurfacesSnapshot = _buildGroundSurfacesSnapshot(_staticIndex);
    if (streamer != null) {
      _staticPrefabSpritesSnapshot =
          List<StaticPrefabSpriteSnapshot>.unmodifiable(
            streamer.dynamicVisualSprites.map(_toStaticPrefabSpriteSnapshot),
          );
    }

    if (_legacyReadModelsEnabled) {
      _rebuildSurfaceGraph();
    }
  }

  // ─── Dependencies ───
  final TrackTuning _trackTuning;
  final CollectibleTuning _collectibleTuning;
  final RestorationItemTuning _restorationItemTuning;
  final StaticWorldGeometry _baseGeometry;
  final SurfaceGraphBuilder? _surfaceGraphBuilder;
  final Map<EnemyId, JumpReachabilityTemplate> _enemyJumpTemplatesById;
  final EnemyNavigationSystem? _enemyNavigationSystem;
  final GroundEnemyLocomotionSystem _groundEnemyLocomotionSystem;
  final SpawnService _spawnService;
  final bool _legacyReadModelsEnabled;
  final ChunkPatternSource _chunkPatternSource;
  final int _earlyPatternChunks;
  final int _easyPatternChunks;
  final int _normalPatternChunks;
  final int _noEnemyChunks;

  // ─── Runtime State ───

  /// The track streamer (null if procedural generation is disabled).
  TrackStreamer? _trackStreamer;

  /// Version counter for surface graph rebuilds (for cache invalidation).
  int _surfaceGraphVersion = 0;

  /// Current merged geometry (base + streamed chunks).
  late StaticWorldGeometry _staticGeometry;

  /// Spatial index for broadphase collision queries.
  late StaticWorldGeometryIndex _staticIndex;

  /// Immutable snapshot of solids for the render layer.
  late List<StaticSolidSnapshot> _staticSolidsSnapshot;

  /// Immutable snapshot of walkable ground surfaces for the render layer.
  late List<GroundSurfaceSnapshot> _groundSurfacesSnapshot;

  /// Immutable snapshot of authored static prefab visual sprites.
  List<StaticPrefabSpriteSnapshot> _staticPrefabSpritesSnapshot =
      const <StaticPrefabSpriteSnapshot>[];

  // ───────────────────────────────────────────────────────────────────────────
  // Public API
  // ───────────────────────────────────────────────────────────────────────────

  /// Current legacy fixture geometry.
  ///
  /// Normal streamed production runs return an empty model because polygon
  /// terrain owns collision, navigation, and rendering.
  StaticWorldGeometry get staticGeometry => _staticGeometry;

  /// Legacy fixture spatial index; empty for normal streamed production runs.
  StaticWorldGeometryIndex get staticIndex => _staticIndex;

  /// Legacy fixture solid snapshots; empty when staged terrain is published.
  List<StaticSolidSnapshot> get staticSolidsSnapshot => _staticSolidsSnapshot;

  /// Legacy fixture ground snapshots; empty when staged terrain is published.
  List<GroundSurfaceSnapshot> get groundSurfacesSnapshot =>
      _groundSurfacesSnapshot;

  /// Immutable snapshot of authored static prefab visual sprites.
  List<StaticPrefabSpriteSnapshot> get staticPrefabSpritesSnapshot =>
      _staticPrefabSpritesSnapshot;

  /// Current canonical scheduler selections for staged terrain binding.
  List<ActiveTrackChunkSnapshot> get activeChunks =>
      _trackStreamer?.activeChunks ?? const <ActiveTrackChunkSnapshot>[];

  /// Resolves the effective render theme id.
  ///
  /// Segment-level render theme overrides are intentionally unsupported; render
  /// theming is level-scoped via `LevelDefinition.visualThemeId`.
  String? resolveRenderVisualThemeId({
    required double cameraCenterX,
    required String? levelVisualThemeId,
  }) {
    // Keep the cameraCenterX parameter in the contract for call-site stability.
    final _ = cameraCenterX;
    return levelVisualThemeId;
  }

  /// Advances the track streamer and updates geometry if needed.
  ///
  /// This method should be called once per tick with the current camera
  /// bounds. It handles:
  /// 1. Chunk spawning/culling based on camera position.
  /// 2. Geometry merging and index rebuilding.
  /// 3. Surface graph updates for enemy AI.
  /// 4. Collectible and restoration item spawning.
  ///
  /// Parameters:
  /// - [cameraLeft], [cameraRight]: Camera X bounds for horizon calculation.
  /// - [spawnEnemy]: Callback invoked for each enemy spawn point in new chunks.
  /// Returns a [TrackStepResult] indicating whether geometry changed.
  TrackStepResult step({
    required int currentTick,
    required double cameraLeft,
    required double cameraRight,
    required SpawnEnemyCallback spawnEnemy,
  }) {
    final streamer = _trackStreamer;
    if (streamer == null) {
      // Procedural generation disabled—geometry never changes.
      return const TrackStepResult(geometryChanged: false);
    }

    // Step the streamer to spawn/cull chunks based on camera position.
    final result = streamer.step(
      cameraLeft: cameraLeft,
      cameraRight: cameraRight,
      spawnEnemy: spawnEnemy,
    );

    if (!result.changed) {
      // No chunks spawned or culled—nothing to update.
      return const TrackStepResult(geometryChanged: false);
    }

    // ─── Merge base geometry with streamed chunks ───
    _staticPrefabSpritesSnapshot =
        List<StaticPrefabSpriteSnapshot>.unmodifiable(
          streamer.dynamicVisualSprites.map(_toStaticPrefabSpriteSnapshot),
        );

    if (_legacyReadModelsEnabled) {
      // Synthetic fixture compatibility only.
      _setStaticGeometry(_combinedLegacyGeometry(streamer));
    }

    return TrackStepResult(
      geometryChanged: true,
      spawnedChunks: result.spawnedChunks,
    );
  }

  /// Spawns procedural items for an already-selected chunk batch.
  ///
  /// Chunk selection and all keyed RNG remain in their historical order. The
  /// caller controls only when placement mutates the ECS, allowing a complete
  /// terrain publication to become visible first.
  void spawnItemsForChunks({
    required Iterable<TrackSpawnedChunk> chunks,
    required RestorationStat Function() lowestResourceStat,
  }) {
    final List<({double minX, double maxX, double minY, double maxY})>
    solidsForSpawn = !_legacyReadModelsEnabled
        ? const <({double minX, double maxX, double minY, double maxY})>[]
        : _staticGeometry.solids
              .map(
                (solid) => (
                  minX: solid.minX,
                  maxX: solid.maxX,
                  minY: solid.minY,
                  maxY: solid.maxY,
                ),
              )
              .toList(growable: false);

    for (final chunk in chunks) {
      if (_collectibleTuning.enabled) {
        _spawnService.spawnCollectiblesForChunk(
          chunkIndex: chunk.index,
          chunkStartX: chunk.startX,
          solids: solidsForSpawn,
        );
      }
      if (_restorationItemTuning.enabled) {
        _spawnService.spawnRestorationItemForChunk(
          chunkIndex: chunk.index,
          chunkStartX: chunk.startX,
          solids: solidsForSpawn,
          lowestResourceStat: lowestResourceStat,
        );
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Private Helpers
  // ───────────────────────────────────────────────────────────────────────────

  /// Applies new static geometry, rebuilding all derived data structures.
  ///
  /// This is the single point of geometry mutation. It ensures that the
  /// collision index, render snapshots, and navigation graph stay in sync.
  void _setStaticGeometry(StaticWorldGeometry geometry) {
    _staticGeometry = geometry;
    _staticIndex = StaticWorldGeometryIndex.from(geometry);
    _staticSolidsSnapshot = _buildStaticSolidsSnapshot(geometry);
    _groundSurfacesSnapshot = _buildGroundSurfacesSnapshot(_staticIndex);
    _rebuildSurfaceGraph();
  }

  StaticWorldGeometry _combinedLegacyGeometry(TrackStreamer streamer) {
    return StaticWorldGeometry(
      groundPlane: _baseGeometry.groundPlane,
      groundSegments: List<StaticGroundSegment>.unmodifiable(
        <StaticGroundSegment>[
          ..._baseGeometry.groundSegments,
          ...streamer.dynamicGroundSegments,
        ],
      ),
      solids: List<StaticSolid>.unmodifiable(<StaticSolid>[
        ..._baseGeometry.solids,
        ...streamer.dynamicSolids,
      ]),
      groundGaps: List<StaticGroundGap>.unmodifiable(<StaticGroundGap>[
        ..._baseGeometry.groundGaps,
        ...streamer.dynamicGroundGaps,
      ]),
    );
  }

  /// Rebuilds the navigation surface graph and distributes it to consumers.
  ///
  /// The surface graph is used by:
  /// - [SpawnService]: To place items "on top of" platforms.
  /// - [EnemyNavigationSystem]: To compute jump/walk paths to the player.
  /// - [GroundEnemyLocomotionSystem]: To snap jump velocity on active edges.
  ///
  /// A version counter is incremented each rebuild so consumers can
  /// invalidate cached paths.
  void _rebuildSurfaceGraph() {
    _surfaceGraphVersion += 1;
    final graphResultsByEnemy = <EnemyId, SurfaceGraphBuildResult>{};
    SurfaceGraphBuildResult? primaryResult;
    for (final entry in _enemyJumpTemplatesById.entries) {
      final result = _surfaceGraphBuilder!.build(
        geometry: _staticGeometry,
        jumpTemplate: entry.value,
      );
      primaryResult ??= result;
      if (primaryResult != result) {
        _assertCompatibleSurfaceGraphs(
          primaryResult.graph,
          result.graph,
          enemyId: entry.key,
        );
      }
      graphResultsByEnemy[entry.key] = result;
    }

    final sharedResult = primaryResult!;

    // Distribute new graph to spawn service.
    _spawnService.setSurfaceGraph(
      graph: sharedResult.graph,
      spatialIndex: sharedResult.spatialIndex,
    );

    final graphsByEnemy = <EnemyId, SurfaceGraph>{
      for (final entry in graphResultsByEnemy.entries)
        entry.key: entry.value.graph,
    };

    // Distribute per-enemy graphs to the AI systems. All graph variants share
    // identical surface IDs/order; only the edge sets differ by enemy profile.
    _enemyNavigationSystem!.setSurfaceGraphs(
      graphsByEnemy: graphsByEnemy,
      spatialIndex: sharedResult.spatialIndex,
      graphVersion: _surfaceGraphVersion,
    );
    _groundEnemyLocomotionSystem.setSurfaceGraphs(graphsByEnemy: graphsByEnemy);
  }

  static void _assertCompatibleSurfaceGraphs(
    SurfaceGraph expected,
    SurfaceGraph actual, {
    required EnemyId enemyId,
  }) {
    if (expected.surfaces.length != actual.surfaces.length) {
      throw StateError(
        'Surface graph for $enemyId changed surface count; per-enemy graphs '
        'must share identical surface extraction.',
      );
    }
    for (var i = 0; i < expected.surfaces.length; i += 1) {
      if (expected.surfaces[i].id != actual.surfaces[i].id) {
        throw StateError(
          'Surface graph for $enemyId changed surface ordering at index $i; '
          'shared spatial-index routing would become invalid.',
        );
      }
    }
  }

  /// Builds an immutable list of [StaticSolidSnapshot] from geometry.
  ///
  /// Converts internal collision representation to render-friendly format.
  static List<StaticSolidSnapshot> _buildStaticSolidsSnapshot(
    StaticWorldGeometry geometry,
  ) {
    return List<StaticSolidSnapshot>.unmodifiable(
      geometry.solids.map(
        (s) => StaticSolidSnapshot(
          minX: s.minX,
          minY: s.minY,
          maxX: s.maxX,
          maxY: s.maxY,
          sides: s.sides,
          oneWayTop: s.oneWayTop,
        ),
      ),
    );
  }

  /// Builds an immutable list of [GroundSurfaceSnapshot] from indexed geometry.
  ///
  /// Uses [StaticWorldGeometryIndex.groundSegments] so both explicit authored
  /// segments and derived plane-minus-gap segments are represented consistently.
  static List<GroundSurfaceSnapshot> _buildGroundSurfacesSnapshot(
    StaticWorldGeometryIndex index,
  ) {
    if (index.groundSegments.isEmpty) {
      return const <GroundSurfaceSnapshot>[];
    }
    return List<GroundSurfaceSnapshot>.unmodifiable(
      index.groundSegments.map(
        (segment) => GroundSurfaceSnapshot(
          minX: segment.minX,
          maxX: segment.maxX,
          topY: segment.topY,
          chunkIndex: segment.chunkIndex,
          localSegmentIndex: segment.localSegmentIndex,
        ),
      ),
    );
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
