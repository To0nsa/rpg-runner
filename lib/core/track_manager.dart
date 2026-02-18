/// Track streaming and geometry lifecycle management.
///
/// This module handles the procedural generation of track chunks as the
/// player progresses, maintaining both collision geometry and navigation
/// data for enemy AI.
///
/// ## Architecture
///
/// [TrackManager] is owned by [GameCore] and orchestrates:
/// - **Track streaming**: [TrackStreamer] spawns/culls chunks based on camera.
/// - **Collision geometry**: Merges base geometry with streamed chunks.
/// - **Surface graph**: Rebuilds navigation data when geometry changes.
/// - **Item spawning**: Delegates to [SpawnService] for new chunks.
///
/// ## Geometry Lifecycle
///
/// ```
/// Camera moves right
///        ↓
/// TrackStreamer.step() detects chunk spawn/cull needed
///        ↓
/// TrackManager merges base + dynamic geometry
///        ↓
/// StaticWorldGeometryIndex rebuilt (collision)
///        ↓
/// SurfaceGraphBuilder.build() (navigation)
///        ↓
/// SpawnService + enemy navigation systems receive new graphs
/// ```
///
/// ## Chunk Spawning Flow
///
/// When a new chunk enters the horizon:
/// 1. [TrackStreamer] generates platforms and enemy spawn points.
/// 2. [TrackManager] merges the new solids into collision geometry.
/// 3. Collectibles and restoration items are placed via [SpawnService].
/// 4. Surface graph is rebuilt so enemies can navigate new platforms.
library;

import 'collision/static_world_geometry_index.dart';
import 'ecs/stores/restoration_item_store.dart' show RestorationStat;
import 'ecs/systems/ground_enemy_locomotion_system.dart';
import 'ecs/systems/enemy_navigation_system.dart';
import 'enemies/enemy_id.dart';
import 'navigation/surface_graph_builder.dart';
import 'navigation/utils/jump_template.dart';
import 'snapshots/ground_surface_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
import 'spawn_service.dart' hide StaticSolid;
import 'track/chunk_pattern_pool.dart';
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
typedef SpawnEnemyCallback = void Function(EnemyId enemyId, double x);

/// Result of a single [TrackManager.step] call.
///
/// Used by [GameCore] to decide whether to update render snapshots.
class TrackStepResult {
  const TrackStepResult({required this.geometryChanged});

  /// Whether static geometry was updated this step.
  ///
  /// When true, collision indices, surface graphs, and render snapshots
  /// have all been regenerated.
  final bool geometryChanged;
}

// ─────────────────────────────────────────────────────────────────────────────
// TrackManager
// ─────────────────────────────────────────────────────────────────────────────

/// Manages track streaming, collision geometry, and navigation graph updates.
///
/// Responsibilities:
/// - Steps [TrackStreamer] each tick to spawn/cull chunks.
/// - Merges base level geometry with dynamically streamed platforms.
/// - Rebuilds [StaticWorldGeometryIndex] for collision detection.
/// - Rebuilds [SurfaceGraph] for enemy pathfinding.
/// - Triggers collectible/item spawning for new chunks.
///
/// Usage:
/// ```dart
/// final manager = TrackManager(seed: 42, ...);
/// final result = manager.step(
///   cameraLeft: cam.left,
///   cameraRight: cam.right,
///   spawnEnemy: (id, x) => spawner.spawn(id, x),
///   lowestResourceStat: () => player.lowestStat,
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
  /// - [jumpTemplate]: Precomputed jump reachability for pathfinding.
  /// - [enemyNavigationSystem]: Ground enemy navigation (receives graph updates).
  /// - [groundEnemyLocomotionSystem]: Ground locomotion (receives graph updates).
  /// - [spawnService]: Entity spawner (receives surface graph updates).
  /// - [groundTopY]: Y coordinate of the ground surface (for spawning).
  /// - [patternPool]: Chunk pattern pools for procedural generation.
  /// - [earlyPatternChunks]: Number of early chunks using easy patterns.
  /// - [noEnemyChunks]: Number of early chunks that suppress enemy spawns.
  TrackManager({
    required int seed,
    required TrackTuning trackTuning,
    required CollectibleTuning collectibleTuning,
    required RestorationItemTuning restorationItemTuning,
    required StaticWorldGeometry baseGeometry,
    required SurfaceGraphBuilder surfaceGraphBuilder,
    required JumpReachabilityTemplate jumpTemplate,
    required EnemyNavigationSystem enemyNavigationSystem,
    required GroundEnemyLocomotionSystem groundEnemyLocomotionSystem,
    required SpawnService spawnService,
    required double groundTopY,
    required ChunkPatternPool patternPool,
    int earlyPatternChunks = defaultEarlyPatternChunks,
    int noEnemyChunks = defaultNoEnemyChunks,
  }) : _trackTuning = trackTuning,
       _collectibleTuning = collectibleTuning,
       _restorationItemTuning = restorationItemTuning,
       _baseGeometry = baseGeometry,
       _surfaceGraphBuilder = surfaceGraphBuilder,
       _jumpTemplate = jumpTemplate,
       _enemyNavigationSystem = enemyNavigationSystem,
       _groundEnemyLocomotionSystem = groundEnemyLocomotionSystem,
       _spawnService = spawnService,
       _patternPool = patternPool,
       _earlyPatternChunks = earlyPatternChunks,
       _noEnemyChunks = noEnemyChunks {
    // Initialize geometry state from base level.
    _staticGeometry = baseGeometry;
    _staticIndex = StaticWorldGeometryIndex.from(baseGeometry);
    _staticSolidsSnapshot = _buildStaticSolidsSnapshot(baseGeometry);
    _groundSurfacesSnapshot = _buildGroundSurfacesSnapshot(_staticIndex);

    // Create track streamer if procedural generation is enabled.
    if (_trackTuning.enabled) {
      _trackStreamer = TrackStreamer(
        seed: seed,
        tuning: _trackTuning,
        groundTopY: groundTopY,
        patterns: _patternPool,
        earlyPatternChunks: _earlyPatternChunks,
        noEnemyChunks: _noEnemyChunks,
      );
    }

    // Build initial surface graph for enemy navigation.
    _rebuildSurfaceGraph();
  }

  // ─── Dependencies ───
  final TrackTuning _trackTuning;
  final CollectibleTuning _collectibleTuning;
  final RestorationItemTuning _restorationItemTuning;
  final StaticWorldGeometry _baseGeometry;
  final SurfaceGraphBuilder _surfaceGraphBuilder;
  final JumpReachabilityTemplate _jumpTemplate;
  final EnemyNavigationSystem _enemyNavigationSystem;
  final GroundEnemyLocomotionSystem _groundEnemyLocomotionSystem;
  final SpawnService _spawnService;
  final ChunkPatternPool _patternPool;
  final int _earlyPatternChunks;
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

  // ───────────────────────────────────────────────────────────────────────────
  // Public API
  // ───────────────────────────────────────────────────────────────────────────

  /// Current static world geometry (base + streamed chunks).
  ///
  /// Used by physics systems for collision resolution.
  StaticWorldGeometry get staticGeometry => _staticGeometry;

  /// Spatial index for efficient collision queries.
  ///
  /// Rebuilt whenever geometry changes.
  StaticWorldGeometryIndex get staticIndex => _staticIndex;

  /// Immutable snapshot of static solids for rendering.
  ///
  /// Contains platform AABBs, side masks, and one-way flags.
  List<StaticSolidSnapshot> get staticSolidsSnapshot => _staticSolidsSnapshot;

  /// Immutable snapshot of walkable ground surfaces for rendering.
  List<GroundSurfaceSnapshot> get groundSurfacesSnapshot =>
      _groundSurfacesSnapshot;

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
  /// - [lowestResourceStat]: Returns player's lowest resource for item type selection.
  ///
  /// Returns a [TrackStepResult] indicating whether geometry changed.
  TrackStepResult step({
    required double cameraLeft,
    required double cameraRight,
    required SpawnEnemyCallback spawnEnemy,
    required RestorationStat Function() lowestResourceStat,
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
    final combinedSolids = <StaticSolid>[
      ..._baseGeometry.solids,
      ...streamer.dynamicSolids,
    ];
    final combinedSegments = <StaticGroundSegment>[
      ..._baseGeometry.groundSegments,
      ...streamer.dynamicGroundSegments,
    ];
    final combinedGaps = <StaticGroundGap>[
      ..._baseGeometry.groundGaps,
      ...streamer.dynamicGroundGaps,
    ];

    // Apply the new combined geometry (rebuilds index, snapshots, nav graph).
    _setStaticGeometry(
      StaticWorldGeometry(
        groundPlane: _baseGeometry.groundPlane,
        groundSegments: List<StaticGroundSegment>.unmodifiable(
          combinedSegments,
        ),
        solids: List<StaticSolid>.unmodifiable(combinedSolids),
        groundGaps: List<StaticGroundGap>.unmodifiable(combinedGaps),
      ),
    );

    // ─── Spawn items for newly created chunks ───
    if (result.spawnedChunks.isNotEmpty) {
      // Convert geometry to spawn-friendly format (avoids import cycles).
      final solidsForSpawn = _staticGeometry.solids
          .map((s) => (minX: s.minX, maxX: s.maxX, minY: s.minY, maxY: s.maxY))
          .toList();

      for (final chunk in result.spawnedChunks) {
        // Spawn collectibles if enabled.
        if (_collectibleTuning.enabled) {
          _spawnService.spawnCollectiblesForChunk(
            chunkIndex: chunk.index,
            chunkStartX: chunk.startX,
            solids: solidsForSpawn,
          );
        }

        // Spawn restoration items if enabled.
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

    return const TrackStepResult(geometryChanged: true);
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
    final result = _surfaceGraphBuilder.build(
      geometry: _staticGeometry,
      jumpTemplate: _jumpTemplate,
    );

    // Distribute new graph to spawn service.
    _spawnService.setSurfaceGraph(
      graph: result.graph,
      spatialIndex: result.spatialIndex,
    );

    // Distribute new graph to enemy AI system.
    _enemyNavigationSystem.setSurfaceGraph(
      graph: result.graph,
      spatialIndex: result.spatialIndex,
      graphVersion: _surfaceGraphVersion,
    );
    _groundEnemyLocomotionSystem.setSurfaceGraph(graph: result.graph);
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
}
