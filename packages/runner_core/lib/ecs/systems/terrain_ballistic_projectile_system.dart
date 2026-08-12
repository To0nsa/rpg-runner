import '../../collision/terrain/terrain_aabb_segment_sweep.dart';
import '../../collision/terrain/terrain_edge.dart';
import '../../collision/terrain/terrain_edge_index.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../collision/terrain/terrain_polygon.dart';
import '../../collision/terrain/terrain_query_buffer.dart';
import '../../players/player_tuning.dart';
import '../collider_aabb_utils.dart';
import '../stores/body_store.dart';
import '../world.dart';

/// Integrates physics-driven projectile AABBs against polygon terrain.
///
/// Gravity remains owned by the existing gravity system. This consumes the resulting
/// velocity in the world-motion phase, sets the existing collision flags, and
/// leaves same-tick destruction to the existing projectile-world system.
final class TerrainBallisticProjectileSystem {
  TerrainBallisticProjectileSystem({required TerrainEdgeIndex edgeIndex})
    : _edgeIndex = edgeIndex,
      _queryBuffer = edgeIndex.createQueryBuffer();

  final TerrainEdgeIndex _edgeIndex;
  final TerrainQueryBuffer _queryBuffer;
  final TerrainAabbSegmentSweepKernel _kernel = TerrainAabbSegmentSweepKernel();
  final TerrainAabbSweepHit _scratchHit = TerrainAabbSweepHit();
  final TerrainAabbSweepHit _bestHit = TerrainAabbSweepHit();

  int lastIntegratedProjectileCount = 0;

  void step(EcsWorld world, MovementTuningDerived movement) {
    lastIntegratedProjectileCount = 0;
    final projectiles = world.projectile;
    for (
      var projectileIndex = 0;
      projectileIndex < projectiles.denseEntities.length;
      projectileIndex += 1
    ) {
      if (!projectiles.usePhysics[projectileIndex]) continue;
      final entity = projectiles.denseEntities[projectileIndex];
      final bodyIndex = world.body.indexOf(entity);
      if (!world.body.enabled[bodyIndex]) continue;

      world.collision.resetTick(entity);
      if (world.body.isKinematic[bodyIndex]) continue;

      _integrateProjectile(world, entity, bodyIndex, movement);
      lastIntegratedProjectileCount += 1;
    }
  }

  void _integrateProjectile(
    EcsWorld world,
    int entity,
    int bodyIndex,
    MovementTuningDerived movement,
  ) {
    final transformIndex = world.transform.indexOf(entity);
    final colliderIndex = world.colliderAabb.indexOf(entity);
    final collisionIndex = world.collision.indexOf(entity);
    final offsetXTicks = physicsCoordinateToTicks(
      colliderEffectiveOffsetX(
        world,
        entity: entity,
        colliderIndex: colliderIndex,
      ),
      name: 'ballisticColliderOffsetX',
    );
    final offsetYTicks = physicsCoordinateToTicks(
      world.colliderAabb.offsetY[colliderIndex],
      name: 'ballisticColliderOffsetY',
    );
    final centerX =
        physicsCoordinateToTicks(
          world.transform.posX[transformIndex],
          name: 'ballisticBodyX',
        ) +
        offsetXTicks;
    final centerY =
        physicsCoordinateToTicks(
          world.transform.posY[transformIndex],
          name: 'ballisticBodyY',
        ) +
        offsetYTicks;
    final halfWidth = physicsCoordinateToTicks(
      world.colliderAabb.halfX[colliderIndex],
      name: 'ballisticHalfWidth',
    );
    final halfHeight = physicsCoordinateToTicks(
      world.colliderAabb.halfY[colliderIndex],
      name: 'ballisticHalfHeight',
    );
    final displacementX = physicsCoordinateToTicks(
      world.transform.velX[transformIndex] * movement.dtSeconds,
      name: 'ballisticDisplacementX',
    );
    final displacementY = physicsCoordinateToTicks(
      world.transform.velY[transformIndex] * movement.dtSeconds,
      name: 'ballisticDisplacementY',
    );

    if (displacementX == 0 && displacementY == 0) return;

    final endX = centerX + displacementX;
    final endY = centerY + displacementY;
    _edgeIndex.queryBounds(
      minX:
          (centerX < endX ? centerX : endX) -
          halfWidth -
          terrainContactEpsilonTicks,
      minY:
          (centerY < endY ? centerY : endY) -
          halfHeight -
          terrainContactEpsilonTicks,
      maxX:
          (centerX > endX ? centerX : endX) +
          halfWidth +
          terrainContactEpsilonTicks,
      maxY:
          (centerY > endY ? centerY : endY) +
          halfHeight +
          terrainContactEpsilonTicks,
      buffer: _queryBuffer,
    );

    TerrainEdge? bestEdge;
    _bestHit.reset();
    for (var index = 0; index < _queryBuffer.candidateCount; index += 1) {
      final edge = _queryBuffer.edgeAt(index, _edgeIndex.edges);
      if (!_approachesCollidableSide(
        edge: edge,
        bodyIndex: bodyIndex,
        world: world,
        centerX: centerX,
        centerY: centerY,
        halfWidth: halfWidth,
        halfHeight: halfHeight,
        displacementX: displacementX,
        displacementY: displacementY,
      )) {
        continue;
      }
      _kernel.sweepAtCenter(
        centerXTicks: centerX,
        centerYTicks: centerY,
        halfWidthTicks: halfWidth,
        halfHeightTicks: halfHeight,
        displacementXTicks: displacementX,
        displacementYTicks: displacementY,
        edge: edge,
        out: _scratchHit,
      );
      if (!_scratchHit.hit || _scratchHit.startedOverlapping) continue;
      if (bestEdge == null || _kernel.compareHits(_scratchHit, _bestHit) < 0) {
        bestEdge = edge;
        _bestHit.copyFrom(_scratchHit);
      }
    }

    if (bestEdge == null) {
      _writeBodyPosition(
        world,
        transformIndex: transformIndex,
        centerX: endX,
        centerY: endY,
        offsetX: offsetXTicks,
        offsetY: offsetYTicks,
      );
      return;
    }

    final finalCenterX =
        centerX +
        terrainPhysicsTickValueToInt(
          displacementX * _bestHit.timeOfImpact,
          name: 'ballisticResolvedDisplacementX',
        );
    final finalCenterY =
        centerY +
        terrainPhysicsTickValueToInt(
          displacementY * _bestHit.timeOfImpact,
          name: 'ballisticResolvedDisplacementY',
        );
    _writeBodyPosition(
      world,
      transformIndex: transformIndex,
      centerX: finalCenterX,
      centerY: finalCenterY,
      offsetX: offsetXTicks,
      offsetY: offsetYTicks,
    );
    _removeEnteringVelocity(world, transformIndex, bestEdge);

    final normal = bestEdge.outwardNormal;
    if (normal.yTicks < 0) world.collision.grounded[collisionIndex] = true;
    if (normal.yTicks > 0) world.collision.hitCeiling[collisionIndex] = true;
    if (normal.xTicks < 0) world.collision.hitRight[collisionIndex] = true;
    if (normal.xTicks > 0) world.collision.hitLeft[collisionIndex] = true;
  }

  bool _approachesCollidableSide({
    required TerrainEdge edge,
    required int bodyIndex,
    required EcsWorld world,
    required int centerX,
    required int centerY,
    required int halfWidth,
    required int halfHeight,
    required int displacementX,
    required int displacementY,
  }) {
    final normal = edge.outwardNormal;
    final approach =
        displacementX * normal.xTicks + displacementY * normal.yTicks;
    if (approach >= 0) return false;
    if (edge.collisionMode == TerrainCollisionMode.solid) {
      final horizontalDominant = normal.xTicks.abs() > normal.yTicks.abs();
      if (!horizontalDominant) {
        return normal.yTicks <= 0 || !world.body.ignoreCeilings[bodyIndex];
      }
      final sideMask = world.body.sideMask[bodyIndex];
      return normal.xTicks < 0
          ? (sideMask & BodyDef.sideRight) != 0
          : (sideMask & BodyDef.sideLeft) != 0;
    }
    if (normal.yTicks >= 0) return false;

    final centerProjection =
        (centerX - edge.start.xTicks) * normal.xTicks +
        (centerY - edge.start.yTicks) * normal.yTicks;
    final extentProjection =
        halfWidth * normal.xTicks.abs() + halfHeight * normal.yTicks.abs();
    return centerProjection - extentProjection >=
        terrainContactEpsilonTicks * terrainDirectionScale;
  }

  void _writeBodyPosition(
    EcsWorld world, {
    required int transformIndex,
    required int centerX,
    required int centerY,
    required int offsetX,
    required int offsetY,
  }) {
    world.transform.posX[transformIndex] =
        (centerX - offsetX) / terrainPhysicsTicksPerWorldUnit;
    world.transform.posY[transformIndex] =
        (centerY - offsetY) / terrainPhysicsTicksPerWorldUnit;
  }

  void _removeEnteringVelocity(
    EcsWorld world,
    int transformIndex,
    TerrainEdge edge,
  ) {
    final normalX = edge.outwardNormal.xTicks.toDouble();
    final normalY = edge.outwardNormal.yTicks.toDouble();
    final velocityX = world.transform.velX[transformIndex];
    final velocityY = world.transform.velY[transformIndex];
    final dot = velocityX * normalX + velocityY * normalY;
    if (dot >= 0) return;
    final lengthSquared = normalX * normalX + normalY * normalY;
    world.transform.velX[transformIndex] =
        velocityX - dot * normalX / lengthSquared;
    world.transform.velY[transformIndex] =
        velocityY - dot * normalY / lengthSquared;
  }
}
