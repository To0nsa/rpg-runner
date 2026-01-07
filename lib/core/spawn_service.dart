/// Entity spawning service for GameCore.
///
/// Centralizes all entity creation logic (enemies, collectibles, restoration
/// items) with deterministic placement algorithms.
library;

import 'ecs/entity_id.dart';
import 'ecs/entity_factory.dart';
import 'ecs/hit/aabb_hit_utils.dart';
import 'ecs/stores/body_store.dart';
import 'ecs/stores/collider_aabb_store.dart';
import 'ecs/stores/collectible_store.dart';
import 'ecs/stores/restoration_item_store.dart';
import 'ecs/world.dart';
import 'enemies/enemy_catalog.dart';
import 'enemies/enemy_id.dart';
import 'navigation/types/nav_tolerances.dart';
import 'navigation/types/surface_graph.dart';
import 'navigation/utils/surface_spatial_index.dart';
import 'snapshots/enums.dart';
import 'tuning/collectible_tuning.dart';
import 'tuning/flying_enemy_tuning.dart';
import 'tuning/movement_tuning.dart';
import 'tuning/restoration_item_tuning.dart';
import 'tuning/track_tuning.dart';
import 'util/deterministic_rng.dart';

/// Service for spawning entities with deterministic placement.
class SpawnService {
  SpawnService({
    required EcsWorld world,
    required EntityFactory entityFactory,
    required EnemyCatalog enemyCatalog,
    required FlyingEnemyTuningDerived flyingEnemyTuning,
    required MovementTuningDerived movement,
    required CollectibleTuning collectibleTuning,
    required RestorationItemTuning restorationItemTuning,
    required TrackTuning trackTuning,
    required int seed,
  })  : _world = world,
        _entityFactory = entityFactory,
        _enemyCatalog = enemyCatalog,
        _flyingEnemyTuning = flyingEnemyTuning,
        _movement = movement,
        _collectibleTuning = collectibleTuning,
        _restorationItemTuning = restorationItemTuning,
        _trackTuning = trackTuning,
        _seed = seed;

  final EcsWorld _world;
  final EntityFactory _entityFactory;
  final EnemyCatalog _enemyCatalog;
  final FlyingEnemyTuningDerived _flyingEnemyTuning;
  final MovementTuningDerived _movement;
  final CollectibleTuning _collectibleTuning;
  final RestorationItemTuning _restorationItemTuning;
  final TrackTuning _trackTuning;
  final int _seed;

  // Scratch lists for spawning algorithms.
  final List<double> _collectibleSpawnXs = <double>[];
  final List<int> _surfaceQueryCandidates = <int>[];

  // Surface graph state (updated by TrackManager).
  SurfaceGraph? _surfaceGraph;
  SurfaceSpatialIndex? _surfaceSpatialIndex;
  double _surfaceMinY = 0.0;
  double _surfaceMaxY = 0.0;

  /// Updates the surface graph reference for collectible/item placement.
  void setSurfaceGraph({
    required SurfaceGraph? graph,
    required SurfaceSpatialIndex? spatialIndex,
  }) {
    _surfaceGraph = graph;
    _surfaceSpatialIndex = spatialIndex;
    _surfaceMinY = 0.0;
    _surfaceMaxY = 0.0;
    if (graph != null && graph.surfaces.isNotEmpty) {
      var minY = graph.surfaces.first.yTop;
      var maxY = minY;
      for (var i = 1; i < graph.surfaces.length; i += 1) {
        final y = graph.surfaces[i].yTop;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
      _surfaceMinY = minY;
      _surfaceMaxY = maxY;
    }
  }

  /// Spawns a flying enemy at [spawnX] above [groundTopY].
  EntityId spawnFlyingEnemy({
    required double spawnX,
    required double groundTopY,
  }) {
    final archetype = _enemyCatalog.get(EnemyId.flyingEnemy);
    final flyingEnemy = _entityFactory.createEnemy(
      enemyId: EnemyId.flyingEnemy,
      posX: spawnX,
      posY: groundTopY - _flyingEnemyTuning.base.flyingEnemyHoverOffsetY,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      body: archetype.body,
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
    );

    // Avoid immediate spawn-tick casting (keeps early-game tests stable).
    _world.cooldown.castCooldownTicksLeft[_world.cooldown.indexOf(flyingEnemy)] =
        _flyingEnemyTuning.flyingEnemyCastCooldownTicks;

    return flyingEnemy;
  }

  /// Spawns a ground enemy at [spawnX] on [groundTopY].
  EntityId spawnGroundEnemy({
    required double spawnX,
    required double groundTopY,
  }) {
    final archetype = _enemyCatalog.get(EnemyId.groundEnemy);

    return _entityFactory.createEnemy(
      enemyId: EnemyId.groundEnemy,
      posX: spawnX,
      posY: groundTopY - archetype.collider.halfY,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      body: BodyDef(
        enabled: archetype.body.enabled,
        isKinematic: archetype.body.isKinematic,
        useGravity: archetype.body.useGravity,
        ignoreCeilings: archetype.body.ignoreCeilings,
        topOnlyGround: archetype.body.topOnlyGround,
        gravityScale: archetype.body.gravityScale,
        maxVelX: _movement.base.maxVelX,
        maxVelY: _movement.base.maxVelY,
        sideMask: archetype.body.sideMask,
      ),
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
    );
  }

  /// Spawns a collectible at ([x], [y]).
  EntityId spawnCollectibleAt(double x, double y) {
    final half = _collectibleTuning.collectibleSize * 0.5;
    final entity = _world.createEntity();
    _world.transform.add(entity, posX: x, posY: y, velX: 0.0, velY: 0.0);
    _world.colliderAabb.add(entity, ColliderAabbDef(halfX: half, halfY: half));
    _world.collectible.add(
      entity,
      CollectibleDef(value: _collectibleTuning.valuePerCollectible),
    );
    return entity;
  }

  /// Spawns a restoration item at ([x], [y]) for [stat].
  EntityId spawnRestorationItemAt(double x, double y, RestorationStat stat) {
    final half = _restorationItemTuning.itemSize * 0.5;
    final entity = _world.createEntity();
    _world.transform.add(entity, posX: x, posY: y, velX: 0.0, velY: 0.0);
    _world.colliderAabb.add(entity, ColliderAabbDef(halfX: half, halfY: half));
    _world.restorationItem.add(entity, RestorationItemDef(stat: stat));
    return entity;
  }

  /// Spawns collectibles for a chunk using deterministic placement.
  void spawnCollectiblesForChunk({
    required int chunkIndex,
    required double chunkStartX,
    required List<StaticSolid> solids,
  }) {
    final tuning = _collectibleTuning;
    if (!tuning.enabled) return;
    if (chunkIndex < tuning.spawnStartChunkIndex) return;
    if (tuning.maxPerChunk <= 0) return;

    final graph = _surfaceGraph;
    final spatialIndex = _surfaceSpatialIndex;
    if (graph == null || spatialIndex == null || graph.surfaces.isEmpty) {
      return;
    }

    final minX = chunkStartX + tuning.chunkEdgeMarginX;
    final maxX = chunkStartX + _trackTuning.chunkWidth - tuning.chunkEdgeMarginX;
    if (maxX <= minX) return;

    var rngState = seedFrom(_seed, chunkIndex ^ 0xC011EC7);
    rngState = nextUint32(rngState);
    final countRange = tuning.maxPerChunk - tuning.minPerChunk + 1;
    final targetCount = tuning.minPerChunk + (rngState % countRange);
    if (targetCount <= 0) return;

    _collectibleSpawnXs.clear();
    final halfSize = tuning.collectibleSize * 0.5;
    final maxAttempts = tuning.maxAttemptsPerChunk;
    for (var attempt = 0;
        attempt < maxAttempts && _collectibleSpawnXs.length < targetCount;
        attempt += 1) {
      rngState = nextUint32(rngState);
      var x = rangeDouble(rngState, minX, maxX);
      x = _snapToGrid(x, _trackTuning.gridSnap);
      if (x < minX || x > maxX) continue;

      if (tuning.minSpacingX > 0.0) {
        var spaced = true;
        for (final prevX in _collectibleSpawnXs) {
          if ((prevX - x).abs() < tuning.minSpacingX) {
            spaced = false;
            break;
          }
        }
        if (!spaced) continue;
      }

      final surfaceY = _highestSurfaceYAtX(x);
      if (surfaceY == null) continue;
      final centerY = surfaceY - tuning.surfaceClearanceY - halfSize;
      if (_overlapsAnySolid(
        centerX: x,
        centerY: centerY,
        halfSize: halfSize,
        margin: tuning.noSpawnMargin,
        solids: solids,
      )) {
        continue;
      }

      spawnCollectibleAt(x, centerY);
      _collectibleSpawnXs.add(x);
    }
  }

  /// Spawns a restoration item for a chunk using deterministic placement.
  void spawnRestorationItemForChunk({
    required int chunkIndex,
    required double chunkStartX,
    required List<StaticSolid> solids,
    required RestorationStat Function() lowestResourceStat,
  }) {
    final tuning = _restorationItemTuning;
    if (!tuning.enabled) return;
    if (chunkIndex < tuning.spawnStartChunkIndex) return;
    if (tuning.spawnEveryChunks <= 0) return;

    final phase = seedFrom(_seed, 0xA17E5A7) % tuning.spawnEveryChunks;
    if ((chunkIndex - phase) % tuning.spawnEveryChunks != 0) return;

    final graph = _surfaceGraph;
    final spatialIndex = _surfaceSpatialIndex;
    if (graph == null || spatialIndex == null || graph.surfaces.isEmpty) {
      return;
    }

    final minX = chunkStartX + tuning.chunkEdgeMarginX;
    final maxX = chunkStartX + _trackTuning.chunkWidth - tuning.chunkEdgeMarginX;
    if (maxX <= minX) return;

    final stat = lowestResourceStat();
    var rngState = seedFrom(_seed, chunkIndex ^ 0xA57A11);
    final halfSize = tuning.itemSize * 0.5;
    for (var attempt = 0; attempt < tuning.maxAttemptsPerSpawn; attempt += 1) {
      rngState = nextUint32(rngState);
      var x = rangeDouble(rngState, minX, maxX);
      x = _snapToGrid(x, _trackTuning.gridSnap);
      if (x < minX || x > maxX) continue;

      final surfaceY = _highestSurfaceYAtX(x);
      if (surfaceY == null) continue;
      final centerY = surfaceY - tuning.surfaceClearanceY - halfSize;
      if (_overlapsAnySolid(
        centerX: x,
        centerY: centerY,
        halfSize: halfSize,
        margin: tuning.noSpawnMargin,
        solids: solids,
      )) {
        continue;
      }
      if (_overlapsAnyCollectible(
        centerX: x,
        centerY: centerY,
        halfSize: halfSize,
        margin: tuning.noSpawnMargin,
      )) {
        continue;
      }

      spawnRestorationItemAt(x, centerY, stat);
      return;
    }
  }

  double _snapToGrid(double x, double grid) {
    if (grid <= 0) return x;
    return (x / grid).roundToDouble() * grid;
  }

  double? _highestSurfaceYAtX(double x) {
    final graph = _surfaceGraph;
    final spatialIndex = _surfaceSpatialIndex;
    if (graph == null || spatialIndex == null || graph.surfaces.isEmpty) {
      return null;
    }

    final minY = _surfaceMinY - navSpatialEps;
    final maxY = _surfaceMaxY + navSpatialEps;
    _surfaceQueryCandidates.clear();
    spatialIndex.queryAabb(
      minX: x - navSpatialEps,
      minY: minY,
      maxX: x + navSpatialEps,
      maxY: maxY,
      outSurfaceIndices: _surfaceQueryCandidates,
    );

    double? bestY;
    int? bestId;
    for (final i in _surfaceQueryCandidates) {
      final s = graph.surfaces[i];
      if (x < s.xMin - navGeomEps || x > s.xMax + navGeomEps) continue;
      if (bestY == null || s.yTop < bestY - navTieEps) {
        bestY = s.yTop;
        bestId = s.id;
      } else if ((s.yTop - bestY).abs() <= navTieEps && s.id < bestId!) {
        bestY = s.yTop;
        bestId = s.id;
      }
    }

    return bestY;
  }

  bool _overlapsAnySolid({
    required double centerX,
    required double centerY,
    required double halfSize,
    required double margin,
    required List<StaticSolid> solids,
  }) {
    if (solids.isEmpty) return false;

    final minX = centerX - halfSize - margin;
    final maxX = centerX + halfSize + margin;
    final minY = centerY - halfSize - margin;
    final maxY = centerY + halfSize + margin;

    for (final solid in solids) {
      final overlaps = aabbOverlapsMinMax(
        aMinX: minX,
        aMaxX: maxX,
        aMinY: minY,
        aMaxY: maxY,
        bMinX: solid.minX,
        bMaxX: solid.maxX,
        bMinY: solid.minY,
        bMaxY: solid.maxY,
      );
      if (overlaps) return true;
    }
    return false;
  }

  bool _overlapsAnyCollectible({
    required double centerX,
    required double centerY,
    required double halfSize,
    required double margin,
  }) {
    final collectibles = _world.collectible;
    if (collectibles.denseEntities.isEmpty) return false;

    final minX = centerX - halfSize - margin;
    final maxX = centerX + halfSize + margin;
    final minY = centerY - halfSize - margin;
    final maxY = centerY + halfSize + margin;

    for (var ci = 0; ci < collectibles.denseEntities.length; ci += 1) {
      final e = collectibles.denseEntities[ci];
      if (!(_world.transform.has(e) && _world.colliderAabb.has(e))) continue;
      final ti = _world.transform.indexOf(e);
      final ai = _world.colliderAabb.indexOf(e);
      final cx = _world.transform.posX[ti] + _world.colliderAabb.offsetX[ai];
      final cy = _world.transform.posY[ti] + _world.colliderAabb.offsetY[ai];
      final overlaps = aabbOverlapsMinMax(
        aMinX: minX,
        aMaxX: maxX,
        aMinY: minY,
        aMaxY: maxY,
        bMinX: cx - _world.colliderAabb.halfX[ai],
        bMaxX: cx + _world.colliderAabb.halfX[ai],
        bMinY: cy - _world.colliderAabb.halfY[ai],
        bMaxY: cy + _world.colliderAabb.halfY[ai],
      );
      if (overlaps) return true;
    }

    return false;
  }
}

/// Static solid geometry (re-exported for spawn overlap checks).
typedef StaticSolid = ({
  double minX,
  double maxX,
  double minY,
  double maxY,
});
