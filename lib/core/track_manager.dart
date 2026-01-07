/// Track streaming and geometry lifecycle management.
///
/// Handles procedural chunk generation, static geometry updates, and
/// surface graph rebuilding for enemy navigation.
library;

import 'collision/static_world_geometry_index.dart';
import 'ecs/stores/restoration_item_store.dart' show RestorationStat;
import 'ecs/systems/enemy_system.dart';
import 'enemies/enemy_id.dart';
import 'navigation/surface_graph_builder.dart';
import 'navigation/utils/jump_template.dart';
import 'snapshots/static_ground_gap_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
import 'spawn_service.dart' hide StaticSolid;
import 'track/track_streamer.dart';
import 'tuning/collectible_tuning.dart';
import 'tuning/restoration_item_tuning.dart';
import 'tuning/track_tuning.dart';

/// Callback to spawn an enemy at a world position.
typedef SpawnEnemyCallback = void Function(EnemyId enemyId, double x);

/// Result of a track manager step.
class TrackStepResult {
  const TrackStepResult({
    required this.geometryChanged,
  });

  /// Whether static geometry was updated this step.
  final bool geometryChanged;
}

/// Manages track streaming, geometry updates, and surface graph rebuilding.
class TrackManager {
  TrackManager({
    required int seed,
    required TrackTuning trackTuning,
    required CollectibleTuning collectibleTuning,
    required RestorationItemTuning restorationItemTuning,
    required StaticWorldGeometry baseGeometry,
    required SurfaceGraphBuilder surfaceGraphBuilder,
    required JumpReachabilityTemplate jumpTemplate,
    required EnemySystem enemySystem,
    required SpawnService spawnService,
    required double groundTopY,
  })  : _trackTuning = trackTuning,
        _collectibleTuning = collectibleTuning,
        _restorationItemTuning = restorationItemTuning,
        _baseGeometry = baseGeometry,
        _surfaceGraphBuilder = surfaceGraphBuilder,
        _jumpTemplate = jumpTemplate,
        _enemySystem = enemySystem,
        _spawnService = spawnService {
    _staticGeometry = baseGeometry;
    _staticIndex = StaticWorldGeometryIndex.from(baseGeometry);
    _staticSolidsSnapshot = _buildStaticSolidsSnapshot(baseGeometry);
    _staticGroundGapsSnapshot = _buildGroundGapsSnapshot(baseGeometry);

    if (_trackTuning.enabled) {
      _trackStreamer = TrackStreamer(
        seed: seed,
        tuning: _trackTuning,
        groundTopY: groundTopY,
      );
    }

    _rebuildSurfaceGraph();
  }

  final TrackTuning _trackTuning;
  final CollectibleTuning _collectibleTuning;
  final RestorationItemTuning _restorationItemTuning;
  final StaticWorldGeometry _baseGeometry;
  final SurfaceGraphBuilder _surfaceGraphBuilder;
  final JumpReachabilityTemplate _jumpTemplate;
  final EnemySystem _enemySystem;
  final SpawnService _spawnService;

  TrackStreamer? _trackStreamer;
  int _surfaceGraphVersion = 0;

  late StaticWorldGeometry _staticGeometry;
  late StaticWorldGeometryIndex _staticIndex;
  late List<StaticSolidSnapshot> _staticSolidsSnapshot;
  late List<StaticGroundGapSnapshot> _staticGroundGapsSnapshot;

  /// Current static world geometry (base + streamed chunks).
  StaticWorldGeometry get staticGeometry => _staticGeometry;

  /// Spatial index for collision queries.
  StaticWorldGeometryIndex get staticIndex => _staticIndex;

  /// Snapshot of static solids for rendering.
  List<StaticSolidSnapshot> get staticSolidsSnapshot => _staticSolidsSnapshot;

  /// Snapshot of ground gaps for rendering.
  List<StaticGroundGapSnapshot> get staticGroundGapsSnapshot =>
      _staticGroundGapsSnapshot;

  /// Steps the track streamer and updates geometry if needed.
  ///
  /// [spawnEnemy] is called for each enemy spawn point in new chunks.
  /// [lowestResourceStat] returns the player's lowest resource for item spawns.
  TrackStepResult step({
    required double cameraLeft,
    required double cameraRight,
    required SpawnEnemyCallback spawnEnemy,
    required RestorationStat Function() lowestResourceStat,
  }) {
    final streamer = _trackStreamer;
    if (streamer == null) {
      return const TrackStepResult(geometryChanged: false);
    }

    final result = streamer.step(
      cameraLeft: cameraLeft,
      cameraRight: cameraRight,
      spawnEnemy: spawnEnemy,
    );

    if (!result.changed) {
      return const TrackStepResult(geometryChanged: false);
    }

    // Rebuild collision index only when geometry changes (spawn/cull).
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
    _setStaticGeometry(
      StaticWorldGeometry(
        groundPlane: _baseGeometry.groundPlane,
        groundSegments: List<StaticGroundSegment>.unmodifiable(combinedSegments),
        solids: List<StaticSolid>.unmodifiable(combinedSolids),
        groundGaps: List<StaticGroundGap>.unmodifiable(combinedGaps),
      ),
    );

    // Spawn collectibles and restoration items for newly spawned chunks.
    if (result.spawnedChunks.isNotEmpty) {
      final solidsForSpawn = _staticGeometry.solids
          .map((s) => (minX: s.minX, maxX: s.maxX, minY: s.minY, maxY: s.maxY))
          .toList();

      for (final chunk in result.spawnedChunks) {
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

    return const TrackStepResult(geometryChanged: true);
  }

  void _setStaticGeometry(StaticWorldGeometry geometry) {
    _staticGeometry = geometry;
    _staticIndex = StaticWorldGeometryIndex.from(geometry);
    _staticSolidsSnapshot = _buildStaticSolidsSnapshot(geometry);
    _staticGroundGapsSnapshot = _buildGroundGapsSnapshot(geometry);
    _rebuildSurfaceGraph();
  }

  void _rebuildSurfaceGraph() {
    _surfaceGraphVersion += 1;
    final result = _surfaceGraphBuilder.build(
      geometry: _staticGeometry,
      jumpTemplate: _jumpTemplate,
    );

    // Update spawn service with new surface graph.
    _spawnService.setSurfaceGraph(
      graph: result.graph,
      spatialIndex: result.spatialIndex,
    );

    // Update enemy system with new surface graph.
    _enemySystem.setSurfaceGraph(
      graph: result.graph,
      spatialIndex: result.spatialIndex,
      graphVersion: _surfaceGraphVersion,
    );
  }

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

  static List<StaticGroundGapSnapshot> _buildGroundGapsSnapshot(
    StaticWorldGeometry geometry,
  ) {
    if (geometry.groundGaps.isEmpty) {
      return const <StaticGroundGapSnapshot>[];
    }
    return List<StaticGroundGapSnapshot>.unmodifiable(
      geometry.groundGaps.map(
        (g) => StaticGroundGapSnapshot(minX: g.minX, maxX: g.maxX),
      ),
    );
  }
}
