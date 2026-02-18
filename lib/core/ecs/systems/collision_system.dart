import '../../collision/static_world_geometry_index.dart';
import '../../players/player_tuning.dart';
import '../../util/fixed_math.dart';
import '../queries.dart';
import '../stores/body_store.dart';
import '../world.dart';

/// Handles physics integration and collision resolution for dynamic entities.
///
/// This system operates in three main steps:
/// 1.  **Integration**: Updates position based on velocity (`pos += vel * dt`).
/// 2.  **Vertical Resolution**:
///     -   Checks floors (ground segments and one-way platforms).
///     -   Checks ceilings (if not ignored).
///     -   Snaps position to the contact surface and zeroes vertical velocity.
/// 3.  **Horizontal Resolution**:
///     -   Checks walls in the direction of movement.
///     -   Stops horizontal movement upon collision.
///
/// Order within a tick:
/// - PlayerMovementSystem computes control velocities (jump/dash/horizontal).
/// - GravitySystem applies vertical gravity acceleration.
/// - CollisionSystem integrates `pos += vel * dt`, resolves collisions, and
///   finalizes grounded/contact state for the tick.
class CollisionSystem {
  // Reusable buffers to avoid allocations during collision queries.
  final List<StaticSolid> _queryBuffer = <StaticSolid>[];
  final List<StaticGroundSegment> _groundSegBuffer = <StaticGroundSegment>[];

  /// Runs the physics update for one tick.
  ///
  /// [tuning] provides the delta time [dtSeconds].
  /// [staticWorld] is the spatial index for static geometry (floors, walls).
  void step(
    EcsWorld world,
    MovementTuningDerived tuning, {
    required StaticWorldGeometryIndex staticWorld,
    bool fixedPointPilotEnabled = false,
    int fixedPointSubpixelScale = defaultPhysicsSubpixelScale,
  }) {
    final dt = tuning.dtSeconds;
    // Epsilon for floating point comparisons and overlap tolerance.
    const eps = 1e-3;

    EcsQueries.forColliders(world, (e, ti, bi, coli, aabbi) {
      if (!world.body.enabled[bi]) return;

      // Reset per-tick collision flags (grounded, hitCeiling, etc.).
      world.collision.resetTick(e);

      // Kinematic bodies are excluded from physics integration/resolution.
      // They are moved manually by other systems.
      if (world.body.isKinematic[bi]) {
        return;
      }


      final prevPosX = world.transform.posX[ti];
      final prevPosY = world.transform.posY[ti];

      // Integrate position from the current velocity.
      if (fixedPointPilotEnabled) {
        world.transform.posX[ti] = integratePerTickFixed(
          position: world.transform.posX[ti],
          velocityPerSecond: world.transform.velX[ti],
          tickHz: tuning.tickHz,
          scale: fixedPointSubpixelScale,
        );
        world.transform.posY[ti] = integratePerTickFixed(
          position: world.transform.posY[ti],
          velocityPerSecond: world.transform.velY[ti],
          tickHz: tuning.tickHz,
          scale: fixedPointSubpixelScale,
        );
      } else {
        world.transform.posX[ti] += world.transform.velX[ti] * dt;
        world.transform.posY[ti] += world.transform.velY[ti] * dt;
      }

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

          if (bestTopY == null || topY < bestTopY) {
            bestTopY = topY;
          }
        }
      }

      // Check ceilings.
      // Only resolve if moving upward and the body collides with ceilings.
      double? bestBottomY;
      if (world.transform.velY[ti] < 0 && !world.body.ignoreCeilings[bi]) {
        final prevTop = prevCenterY - halfY;
        _queryBuffer.clear();
        staticWorld.queryBottoms(minX + eps, maxX - eps, _queryBuffer);
        for (final solid in _queryBuffer) {
          final bottomY = solid.maxY;
          // Check if we crossed the surface from below to above.
          final crossesBottom =
              prevTop >= bottomY - eps && top <= bottomY + eps;
          if (!crossesBottom) continue;

          // Keep the lowest ceiling (maximum Y) encountered.
          if (bestBottomY == null || bottomY > bestBottomY) {
            bestBottomY = bottomY;
          }
        }
      }

      // Check Ground Segments (optimized horizontal strips for ground).
      // Treated same as one-way platforms.
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

      // Apply vertical resolution.
      if (bestTopY != null) {
        // Landed on floor.
        world.transform.posY[ti] = bestTopY - offsetY - halfY;
        if (world.transform.velY[ti] > 0) {
          world.transform.velY[ti] = 0;
        }
        world.collision.grounded[coli] = true;
      } else if (bestBottomY != null) {
        // Hit ceiling.
        world.transform.posY[ti] = bestBottomY - offsetY + halfY;
        if (world.transform.velY[ti] < 0) {
          world.transform.velY[ti] = 0;
        }
        world.collision.hitCeiling[coli] = true;
      }

      // Horizontal Resolution
      // Recompute AABB after vertical resolution for stable side overlap tests.
      // This prevents "snagging" on walls due to slight vertical overlap that should have been resolved.
      final resolvedCenterX = world.transform.posX[ti] + offsetX;
      final resolvedCenterY = world.transform.posY[ti] + offsetY;
      final resolvedMinY = resolvedCenterY - halfY;
      final resolvedMaxY = resolvedCenterY + halfY;

      // Resolve against static walls.
      final sideMask = world.body.sideMask[bi];
      final velX = world.transform.velX[ti];

      if (velX > 0 && (sideMask &  BodyDef.sideRight) != 0) {
        // Moving Right.
        final prevRight = prevCenterX + halfX;
        final right = resolvedCenterX + halfX;
        double? bestWallX;

        _queryBuffer.clear();
        staticWorld.queryLeftWalls(prevRight - eps, right + eps, _queryBuffer);

        for (final solid in _queryBuffer) {
          // Filter by vertical overlap (y-axis).
          final overlapY =
              resolvedMaxY > solid.minY + eps && resolvedMinY < solid.maxY - eps;
          if (!overlapY) continue;

          final wallX = solid.minX;
          // Check if we crossed the wall line.
          final crossesWall = prevRight <= wallX + eps && right >= wallX - eps;
          if (!crossesWall) continue;

          if (bestWallX == null || wallX < bestWallX) {
            bestWallX = wallX;
          }
        }

        if (bestWallX != null) {
          // Hit right wall.
          world.transform.posX[ti] = bestWallX - offsetX - halfX;
          world.transform.velX[ti] = 0;
          world.collision.hitRight[coli] = true;
        }
      } else if (velX < 0 && (sideMask & BodyDef.sideLeft) != 0) {
        // Moving Left.
        final prevLeft = prevCenterX - halfX;
        final left = resolvedCenterX - halfX;
        double? bestWallX;

        _queryBuffer.clear();
        staticWorld.queryRightWalls(left - eps, prevLeft + eps, _queryBuffer);

        for (final solid in _queryBuffer) {
          // Filter by vertical overlap (y-axis).
          final overlapY =
              resolvedMaxY > solid.minY + eps && resolvedMinY < solid.maxY - eps;
          if (!overlapY) continue;

          final wallX = solid.maxX;
          // Check if we crossed the wall line from right to left.
          final crossesWall = prevLeft >= wallX - eps && left <= wallX + eps;
          if (!crossesWall) continue;

          // Keep the rightmost wall (maximum X) encountered.
          if (bestWallX == null || wallX > bestWallX) {
            bestWallX = wallX;
          }
        }

        if (bestWallX != null) {
          // Hit left wall.
          world.transform.posX[ti] = bestWallX - offsetX + halfX;
          world.transform.velX[ti] = 0;
          world.collision.hitLeft[coli] = true;
        }
      }

      if (fixedPointPilotEnabled) {
        world.transform.quantizePosVelAtIndex(
          ti,
          subpixelScale: fixedPointSubpixelScale,
        );
      }
    });
  }
}
