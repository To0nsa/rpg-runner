/// Entity spawning service for GameCore.
///
/// Centralizes all entity creation logic (enemies, collectibles, restoration
/// items) with deterministic placement algorithms. Determinism is critical
/// for replay consistency—given the same seed and chunk index, the same
/// entities spawn at the same positions.
///
/// ## Architecture
///
/// [SpawnService] is owned by [GameCore] and called during:
/// - **Enemy spawning**: When the spawn horizon advances, enemies are placed
///   at fixed X offsets ahead of the camera.
/// - **Chunk generation**: When [TrackManager] streams new chunks,
///   collectibles and restoration items are procedurally scattered.
///
/// ## Determinism Strategy
///
/// All RNG operations use [seedFrom] and [nextUint32] from the deterministic
/// RNG module. Each spawn type uses a unique salt (e.g., `0xC011EC7` for
/// collectibles) XOR'd with the chunk index to ensure:
/// - Same seed + chunk → same spawn pattern
/// - Different chunks → independent sequences
/// - Different spawn types → no correlation
///
/// ## Placement Algorithm
///
/// For collectibles and restoration items:
/// 1. Compute valid X range (chunk bounds minus edge margins).
/// 2. Generate random X, snap to grid.
/// 3. Query the [SurfaceGraph] for the highest platform at that X.
/// 4. Place item above the surface with clearance.
/// 5. Reject if overlapping solids or existing entities.
/// 6. Retry up to `maxAttempts` times.
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

// ─────────────────────────────────────────────────────────────────────────────
// RNG Salt Constants
// ─────────────────────────────────────────────────────────────────────────────

/// RNG salt for collectible spawn positions ("COLLECT" in hex-speak).
const int _collectibleSalt = 0xC011EC7;

/// RNG salt for restoration item spawn phase offset ("ALTESAT" - alternate stat).
const int _restorationPhaseSalt = 0xA17E5A7;

/// RNG salt for restoration item spawn positions ("ASTALL" - a stall/restore).
const int _restorationSpawnSalt = 0xA57A11;

// ─────────────────────────────────────────────────────────────────────────────
// SpawnService
// ─────────────────────────────────────────────────────────────────────────────

/// Service for spawning game entities with deterministic, seeded placement.
///
/// Handles creation of:
/// - **Flying enemies**: Hover above ground, cast projectiles.
/// - **Ground enemies**: Walk on platforms, chase player.
/// - **Collectibles**: Score pickups scattered across chunks.
/// - **Restoration items**: Health/mana/stamina orbs on periodic chunks.
///
/// Usage:
/// ```dart
/// final spawner = SpawnService(world: ..., seed: 42, ...);
/// spawner.setSurfaceGraph(graph: navGraph, spatialIndex: index);
/// spawner.spawnFlyingEnemy(spawnX: 500, groundTopY: 0);
/// spawner.spawnCollectiblesForChunk(chunkIndex: 3, ...);
/// ```
class SpawnService {
  /// Creates a spawn service with the given dependencies.
  ///
  /// - [world]: ECS world for entity creation and component access.
  /// - [entityFactory]: Factory for creating complex entities (enemies).
  /// - [enemyCatalog]: Archetype definitions for enemy types.
  /// - [flyingEnemyTuning]: Flying enemy hover offset and cooldowns.
  /// - [movement]: Movement tuning for ground enemy velocity limits.
  /// - [collectibleTuning]: Spawn density, spacing, and margins.
  /// - [restorationItemTuning]: Spawn frequency and item sizing.
  /// - [trackTuning]: Chunk dimensions and grid snap settings.
  /// - [seed]: Master RNG seed for deterministic spawning.
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
  }) : _world = world,
       _entityFactory = entityFactory,
       _enemyCatalog = enemyCatalog,
       _flyingEnemyTuning = flyingEnemyTuning,
       _movement = movement,
       _collectibleTuning = collectibleTuning,
       _restorationItemTuning = restorationItemTuning,
       _trackTuning = trackTuning,
       _seed = seed;

  // ─── Dependencies ───
  final EcsWorld _world;
  final EntityFactory _entityFactory;
  final EnemyCatalog _enemyCatalog;
  final FlyingEnemyTuningDerived _flyingEnemyTuning;
  final MovementTuningDerived _movement;
  final CollectibleTuning _collectibleTuning;
  final RestorationItemTuning _restorationItemTuning;
  final TrackTuning _trackTuning;
  final int _seed;

  // ─── Scratch buffers (reused to avoid allocation) ───

  /// X positions of collectibles spawned in the current chunk (for spacing).
  final List<double> _collectibleSpawnXs = <double>[];

  /// Surface indices returned by spatial queries.
  final List<int> _surfaceQueryCandidates = <int>[];

  // ─── Surface graph state (updated by TrackManager) ───
  SurfaceGraph? _surfaceGraph;
  SurfaceSpatialIndex? _surfaceSpatialIndex;
  double _surfaceMinY = 0.0;
  double _surfaceMaxY = 0.0;

  // ───────────────────────────────────────────────────────────────────────────
  // Surface Graph Management
  // ───────────────────────────────────────────────────────────────────────────

  /// Updates the navigation surface graph for item placement queries.
  ///
  /// Called by [TrackManager] whenever the track geometry changes.
  /// The surface graph provides platform positions for placing items
  /// "on top of" surfaces rather than floating in mid-air.
  ///
  /// Also caches the Y-axis bounds for efficient spatial queries.
  void setSurfaceGraph({
    required SurfaceGraph? graph,
    required SurfaceSpatialIndex? spatialIndex,
  }) {
    _surfaceGraph = graph;
    _surfaceSpatialIndex = spatialIndex;
    _surfaceMinY = 0.0;
    _surfaceMaxY = 0.0;

    // Pre-compute Y bounds to avoid repeated iteration during queries.
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

  // ───────────────────────────────────────────────────────────────────────────
  // Enemy Spawning
  // ───────────────────────────────────────────────────────────────────────────

  /// Spawns a flying enemy at [spawnX], hovering above [groundTopY].
  ///
  /// Flying enemies are placed at a fixed vertical offset above the ground
  /// (defined by [FlyingEnemyTuning.flyingEnemyHoverOffsetY]). They don't
  /// use gravity and will begin AI behavior on the next tick.
  ///
  /// The enemy's cast cooldown is pre-set to avoid immediate projectile
  /// spam on the spawn tick—this keeps early-game pacing predictable.
  ///
  /// Returns the [EntityId] of the newly created enemy.
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
      tags: archetype.tags,
      resistance: archetype.resistance,
      statusImmunity: archetype.statusImmunity,
    );

    // Pre-set cooldown to prevent immediate casting on spawn tick.
    // This ensures consistent early-game difficulty across runs.
    _world.cooldown.castCooldownTicksLeft[_world.cooldown.indexOf(
          flyingEnemy,
        )] =
        _flyingEnemyTuning.flyingEnemyCastCooldownTicks;

    return flyingEnemy;
  }

  /// Spawns a ground enemy at [spawnX], standing on [groundTopY].
  ///
  /// Ground enemies use gravity and collision. Their Y position is
  /// computed so their collider's bottom edge rests on the ground surface.
  ///
  /// The enemy inherits movement velocity limits from [MovementTuning]
  /// to ensure consistent chase behavior relative to player speed.
  ///
  /// Returns the [EntityId] of the newly created enemy.
  EntityId spawnGroundEnemy({
    required double spawnX,
    required double groundTopY,
  }) {
    final archetype = _enemyCatalog.get(EnemyId.groundEnemy);

    // Position so collider bottom touches ground.
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
      tags: archetype.tags,
      resistance: archetype.resistance,
      statusImmunity: archetype.statusImmunity,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Collectible & Restoration Item Spawning
  // ───────────────────────────────────────────────────────────────────────────

  /// Spawns a single collectible at the given world position.
  ///
  /// Collectibles are stationary pickups that grant score when touched.
  /// They have an AABB collider for overlap detection but no physics body.
  ///
  /// Prefer [spawnCollectiblesForChunk] for procedural placement.
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

  /// Spawns a restoration item at the given world position.
  ///
  /// Restoration items restore the specified [stat] (health, mana, or
  /// stamina) when collected. Like collectibles, they're stationary with
  /// an AABB collider.
  ///
  /// Prefer [spawnRestorationItemForChunk] for procedural placement.
  EntityId spawnRestorationItemAt(double x, double y, RestorationStat stat) {
    final half = _restorationItemTuning.itemSize * 0.5;
    final entity = _world.createEntity();
    _world.transform.add(entity, posX: x, posY: y, velX: 0.0, velY: 0.0);
    _world.colliderAabb.add(entity, ColliderAabbDef(halfX: half, halfY: half));
    _world.restorationItem.add(entity, RestorationItemDef(stat: stat));
    return entity;
  }

  /// Spawns collectibles for a track chunk using deterministic placement.
  ///
  /// This method:
  /// 1. Skips if collectibles are disabled or chunk is too early.
  /// 2. Determines spawn count from RNG (between min and max per chunk).
  /// 3. For each collectible, picks a random X within chunk bounds.
  /// 4. Snaps X to grid and enforces minimum spacing between items.
  /// 5. Queries the highest surface at that X for vertical placement.
  /// 6. Rejects positions overlapping platforms or existing items.
  ///
  /// The RNG is seeded with `seed XOR chunkIndex XOR 0xC011EC7` to ensure
  /// deterministic but unique sequences per chunk.
  void spawnCollectiblesForChunk({
    required int chunkIndex,
    required double chunkStartX,
    required List<StaticSolid> solids,
  }) {
    final tuning = _collectibleTuning;

    // ─── Early-out checks ───
    if (!tuning.enabled) return;
    if (chunkIndex < tuning.spawnStartChunkIndex) return;
    if (tuning.maxPerChunk <= 0) return;

    final graph = _surfaceGraph;
    final spatialIndex = _surfaceSpatialIndex;
    if (graph == null || spatialIndex == null || graph.surfaces.isEmpty) {
      return;
    }

    // ─── Compute valid X range ───
    final minX = chunkStartX + tuning.chunkEdgeMarginX;
    final maxX =
        chunkStartX + _trackTuning.chunkWidth - tuning.chunkEdgeMarginX;
    if (maxX <= minX) return;

    // ─── Initialize RNG and determine target count ───
    var rngState = seedFrom(_seed, chunkIndex ^ _collectibleSalt);
    rngState = nextUint32(rngState);
    final countRange = tuning.maxPerChunk - tuning.minPerChunk + 1;
    final targetCount = tuning.minPerChunk + (rngState % countRange);
    if (targetCount <= 0) return;

    // ─── Spawn loop with rejection sampling ───
    _collectibleSpawnXs.clear();
    final halfSize = tuning.collectibleSize * 0.5;
    final maxAttempts = tuning.maxAttemptsPerChunk;

    for (
      var attempt = 0;
      attempt < maxAttempts && _collectibleSpawnXs.length < targetCount;
      attempt += 1
    ) {
      // Generate candidate X position.
      rngState = nextUint32(rngState);
      var x = rangeDouble(rngState, minX, maxX);
      x = _snapToGrid(x, _trackTuning.gridSnap);
      if (x < minX || x > maxX) continue;

      // Enforce minimum spacing from already-spawned collectibles.
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

      // Find surface Y and compute item center position.
      final surfaceY = _highestSurfaceYAtX(x);
      if (surfaceY == null) continue;
      final centerY = surfaceY - tuning.surfaceClearanceY - halfSize;

      // Reject if overlapping static geometry.
      if (_overlapsAnySolid(
        centerX: x,
        centerY: centerY,
        halfSize: halfSize,
        margin: tuning.noSpawnMargin,
        solids: solids,
      )) {
        continue;
      }

      // Success—spawn and record position.
      spawnCollectibleAt(x, centerY);
      _collectibleSpawnXs.add(x);
    }
  }

  /// Spawns a restoration item for a chunk if eligible.
  ///
  /// Restoration items spawn on a periodic schedule (e.g., every N chunks)
  /// with a phase offset derived from the seed to avoid predictable timing.
  ///
  /// The item type is determined by [lowestResourceStat], which should
  /// return the player's most depleted resource (health, mana, or stamina).
  ///
  /// Placement follows the same rejection-sampling algorithm as collectibles,
  /// with an additional check to avoid overlapping existing collectibles.
  void spawnRestorationItemForChunk({
    required int chunkIndex,
    required double chunkStartX,
    required List<StaticSolid> solids,
    required RestorationStat Function() lowestResourceStat,
  }) {
    final tuning = _restorationItemTuning;

    // ─── Early-out checks ───
    if (!tuning.enabled) return;
    if (chunkIndex < tuning.spawnStartChunkIndex) return;
    if (tuning.spawnEveryChunks <= 0) return;

    // ─── Periodic spawn check (with seeded phase offset) ───
    final phase =
        seedFrom(_seed, _restorationPhaseSalt) % tuning.spawnEveryChunks;
    if ((chunkIndex - phase) % tuning.spawnEveryChunks != 0) return;

    final graph = _surfaceGraph;
    final spatialIndex = _surfaceSpatialIndex;
    if (graph == null || spatialIndex == null || graph.surfaces.isEmpty) {
      return;
    }

    // ─── Compute valid X range ───
    final minX = chunkStartX + tuning.chunkEdgeMarginX;
    final maxX =
        chunkStartX + _trackTuning.chunkWidth - tuning.chunkEdgeMarginX;
    if (maxX <= minX) return;

    // ─── Determine which stat to restore ───
    final stat = lowestResourceStat();

    // ─── Spawn with rejection sampling ───
    var rngState = seedFrom(_seed, chunkIndex ^ _restorationSpawnSalt);
    final halfSize = tuning.itemSize * 0.5;

    for (var attempt = 0; attempt < tuning.maxAttemptsPerSpawn; attempt += 1) {
      rngState = nextUint32(rngState);
      var x = rangeDouble(rngState, minX, maxX);
      x = _snapToGrid(x, _trackTuning.gridSnap);
      if (x < minX || x > maxX) continue;

      final surfaceY = _highestSurfaceYAtX(x);
      if (surfaceY == null) continue;
      final centerY = surfaceY - tuning.surfaceClearanceY - halfSize;

      // Reject if overlapping static geometry.
      if (_overlapsAnySolid(
        centerX: x,
        centerY: centerY,
        halfSize: halfSize,
        margin: tuning.noSpawnMargin,
        solids: solids,
      )) {
        continue;
      }

      // Reject if overlapping existing collectibles.
      if (_overlapsAnyCollectible(
        centerX: x,
        centerY: centerY,
        halfSize: halfSize,
        margin: tuning.noSpawnMargin,
      )) {
        continue;
      }

      // Success—spawn and exit.
      spawnRestorationItemAt(x, centerY, stat);
      return;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Private Helpers
  // ───────────────────────────────────────────────────────────────────────────

  /// Snaps [x] to the nearest multiple of [grid].
  ///
  /// Grid snapping ensures items align visually with the track's tile grid,
  /// avoiding sub-pixel positioning artifacts.
  double _snapToGrid(double x, double grid) {
    if (grid <= 0) return x;
    return (x / grid).roundToDouble() * grid;
  }

  /// Returns the Y coordinate of the highest surface at [x], or null if none.
  ///
  /// Uses the [SurfaceSpatialIndex] for efficient lookup, then filters
  /// candidates to find the topmost platform. Ties are broken by surface ID
  /// for determinism.
  double? _highestSurfaceYAtX(double x) {
    final graph = _surfaceGraph;
    final spatialIndex = _surfaceSpatialIndex;
    if (graph == null || spatialIndex == null || graph.surfaces.isEmpty) {
      return null;
    }

    // Query all surfaces that might contain X.
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

    // Find highest (smallest Y in screen coords) surface containing X.
    double? bestY;
    int? bestId;
    for (final i in _surfaceQueryCandidates) {
      final s = graph.surfaces[i];
      if (x < s.xMin - navGeomEps || x > s.xMax + navGeomEps) continue;

      // Prefer lower Y (higher on screen). Break ties by ID for determinism.
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

  /// Checks if an AABB centered at ([centerX], [centerY]) overlaps any solid.
  ///
  /// The AABB is expanded by [margin] to prevent items from spawning too
  /// close to platform edges.
  bool _overlapsAnySolid({
    required double centerX,
    required double centerY,
    required double halfSize,
    required double margin,
    required List<StaticSolid> solids,
  }) {
    if (solids.isEmpty) return false;

    // Expand bounds by half-size and margin.
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

  /// Checks if an AABB overlaps any existing collectible entity.
  ///
  /// Used by restoration item spawning to avoid stacking pickups.
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

      // Read collectible's world-space AABB.
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

// ─────────────────────────────────────────────────────────────────────────────
// Supporting Types
// ─────────────────────────────────────────────────────────────────────────────

/// Axis-aligned bounding box for static world geometry.
///
/// Used by [SpawnService] for overlap rejection during item placement.
/// Re-exported here to avoid circular imports with collision module.
typedef StaticSolid = ({double minX, double maxX, double minY, double maxY});
