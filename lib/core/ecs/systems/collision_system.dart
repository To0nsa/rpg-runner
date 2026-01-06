import '../../collision/static_world_geometry_index.dart';
import '../../tuning/movement_tuning.dart';
import '../queries.dart';
import '../stores/body_store.dart';
import '../world.dart';

/// Integrates positions and resolves collisions (V0: ground band only).
///
/// Order within a tick:
/// - PlayerMovementSystem computes control velocities (jump/dash/horizontal).
/// - GravitySystem applies vertical gravity acceleration.
/// - CollisionSystem integrates `pos += vel * dt`, resolves collisions, and
///   finalizes grounded/contact state for the tick.
class CollisionSystem {
  final List<StaticSolid> _queryBuffer = <StaticSolid>[];
  final List<StaticGroundSegment> _groundSegBuffer = <StaticGroundSegment>[];

  void step(
    EcsWorld world,
    MovementTuningDerived tuning, {
    required StaticWorldGeometryIndex staticWorld,
  }) {
    final dt = tuning.dtSeconds;
    const eps = 1e-3;

    EcsQueries.forColliders(world, (e, ti, bi, coli, aabbi) {
      if (!world.body.enabled[bi]) return;

      // Reset per-tick collision results.
      world.collision.resetTick(e);

      // Kinematic bodies are excluded from physics integration/resolution.
      if (world.body.isKinematic[bi]) {
        return;
      }

      final prevPosX = world.transform.posX[ti];
      final prevPosY = world.transform.posY[ti];

      // Integrate position from the current velocity.
      world.transform.posX[ti] += world.transform.velX[ti] * dt;
      world.transform.posY[ti] += world.transform.velY[ti] * dt;

      final halfX = world.colliderAabb.halfX[aabbi];
      final halfY = world.colliderAabb.halfY[aabbi];
      final offsetX = world.colliderAabb.offsetX[aabbi];
      final offsetY = world.colliderAabb.offsetY[aabbi];

      final prevCenterX = prevPosX + offsetX;
      final prevCenterY = prevPosY + offsetY;
      final prevBottom = prevCenterY + halfY;

      final centerX = world.transform.posX[ti] + offsetX;
      final centerY = world.transform.posY[ti] + offsetY;
      final minX = centerX - halfX;
      final maxX = centerX + halfX;
      final bottom = centerY + halfY;
      final top = centerY - halfY;

      // Vertical top resolution (one-way platforms): only while moving downward.
      double? bestTopY;
      if (world.transform.velY[ti] > 0) {
        _queryBuffer.clear();
        staticWorld.queryTops(minX + eps, maxX - eps, _queryBuffer);
        for (final solid in _queryBuffer) {
          final topY = solid.minY;
          final crossesTop =
              prevBottom <= topY + eps && bottom >= topY - eps;
          if (!crossesTop) continue;

          if (solid.oneWayTop == false) {
            // Fully solid top surface; same resolution as one-way, just without
            // any additional gating.
          }

          if (bestTopY == null || topY < bestTopY) {
            bestTopY = topY;
          }
        }
      }

      // Vertical bottom resolution (ceilings): only while moving upward.
      double? bestBottomY;
      if (world.transform.velY[ti] < 0 && !world.body.ignoreCeilings[bi]) {
        final prevTop = prevCenterY - halfY;
        _queryBuffer.clear();
        staticWorld.queryBottoms(minX + eps, maxX - eps, _queryBuffer);
        for (final solid in _queryBuffer) {
          final bottomY = solid.maxY;
          final crossesBottom =
              prevTop >= bottomY - eps && top <= bottomY + eps;
          if (!crossesBottom) continue;

          if (bestBottomY == null || bottomY > bestBottomY) {
            bestBottomY = bottomY;
          }
        }
      }

      // Resolve ground segments (walkable surfaces, possibly split by gaps).
      if (world.transform.velY[ti] > 0) {
        _groundSegBuffer.clear();
        staticWorld.queryGroundSegments(minX + eps, maxX - eps, _groundSegBuffer);
        for (final seg in _groundSegBuffer) {
          final groundTopY = seg.topY;
          final crossesTop =
              prevBottom <= groundTopY + eps && bottom >= groundTopY - eps;
          if (!crossesTop) continue;
          if (bestTopY == null || groundTopY < bestTopY) {
            bestTopY = groundTopY;
          }
        }
      }

      if (bestTopY != null) {
        world.transform.posY[ti] = bestTopY - offsetY - halfY;
        if (world.transform.velY[ti] > 0) {
          world.transform.velY[ti] = 0;
        }
        world.collision.grounded[coli] = true;
      } else if (bestBottomY != null) {
        world.transform.posY[ti] = bestBottomY - offsetY + halfY;
        if (world.transform.velY[ti] < 0) {
          world.transform.velY[ti] = 0;
        }
        world.collision.hitCeiling[coli] = true;
      }

      // Recompute AABB after vertical resolution for stable side overlap tests.
      final resolvedCenterX = world.transform.posX[ti] + offsetX;
      final resolvedCenterY = world.transform.posY[ti] + offsetY;
      //final resolvedMinX = resolvedCenterX - halfX;
      //final resolvedMaxX = resolvedCenterX + halfX;
      final resolvedMinY = resolvedCenterY - halfY;
      final resolvedMaxY = resolvedCenterY + halfY;

      // Horizontal resolution against static solids (V0: obstacles/walls only).
      final sideMask = world.body.sideMask[bi];
      final velX = world.transform.velX[ti];

      if (velX > 0 && (sideMask &  BodyDef.sideRight) != 0) {
        final prevRight = prevCenterX + halfX;
        final right = resolvedCenterX + halfX;
        double? bestWallX;

        _queryBuffer.clear();
        staticWorld.queryLeftWalls(prevRight - eps, right + eps, _queryBuffer);

        for (final solid in _queryBuffer) {
          final overlapY =
              resolvedMaxY > solid.minY + eps && resolvedMinY < solid.maxY - eps;
          if (!overlapY) continue;

          final wallX = solid.minX;
          final crossesWall = prevRight <= wallX + eps && right >= wallX - eps;
          if (!crossesWall) continue;

          if (bestWallX == null || wallX < bestWallX) {
            bestWallX = wallX;
          }
        }

        if (bestWallX != null) {
          world.transform.posX[ti] = bestWallX - offsetX - halfX;
          world.transform.velX[ti] = 0;
          world.collision.hitRight[coli] = true;
        }
      } else if (velX < 0 && (sideMask & BodyDef.sideLeft) != 0) {
        final prevLeft = prevCenterX - halfX;
        final left = resolvedCenterX - halfX;
        double? bestWallX;

        _queryBuffer.clear();
        staticWorld.queryRightWalls(left - eps, prevLeft + eps, _queryBuffer);

        for (final solid in _queryBuffer) {
          final overlapY =
              resolvedMaxY > solid.minY + eps && resolvedMinY < solid.maxY - eps;
          if (!overlapY) continue;

          final wallX = solid.maxX;
          final crossesWall = prevLeft >= wallX - eps && left <= wallX + eps;
          if (!crossesWall) continue;

          if (bestWallX == null || wallX > bestWallX) {
            bestWallX = wallX;
          }
        }

        if (bestWallX != null) {
          world.transform.posX[ti] = bestWallX - offsetX + halfX;
          world.transform.velX[ti] = 0;
          world.collision.hitLeft[coli] = true;
        }
      }
    });
  }
}
