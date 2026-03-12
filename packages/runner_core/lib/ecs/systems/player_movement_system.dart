import '../../stats/character_stats_resolver.dart';
import '../../stats/resolved_stats_cache.dart';
import '../../snapshots/enums.dart';
import '../../players/player_tuning.dart';
import '../../util/fixed_math.dart';
import '../../util/velocity_math.dart';
import '../queries.dart';
import '../world.dart';

/// Applies platformer-style movement for entities with:
/// - Transform
/// - PlayerInput
/// - Movement
/// - Body
///
/// PlayerMovementSystem writes movement velocities only (input/dash/clamps).
/// Dash initiation is handled by [MobilitySystem].
/// Position integration and collision resolution are handled by CollisionSystem.
///
/// **Responsibilities**:
/// *   Update movement state timers (dash + facing locks).
/// *   Process horizontal input and dash movement state.
/// *   Apply horizontal/active-dash velocities.
class PlayerMovementSystem {
  PlayerMovementSystem({
    CharacterStatsResolver statsResolver = const CharacterStatsResolver(),
    ResolvedStatsCache? statsCache,
  }) : _statsCache = statsCache ?? ResolvedStatsCache(resolver: statsResolver);

  final ResolvedStatsCache _statsCache;

  void step(
    EcsWorld world,
    MovementTuningDerived tuning, {
    required int currentTick,
    bool fixedPointPilotEnabled = false,
    int fixedPointSubpixelScale = defaultPhysicsSubpixelScale,
  }) {
    final dt = tuning.dtSeconds;

    // Iterate over all controllable entities (Join: Movement + Input + Body +...).
    // Uses EcsQueries to efficiently fetch entities with all required components.
    EcsQueries.forMovementBodies(world, (e, mi, ti, ii, bi) {
      if (!world.body.enabled[bi]) return;

      // Kinematic bodies are moved by scripts/physics directly, not by player input.
      if (world.body.isKinematic[bi]) {
        return;
      }

      // -- Stun Check --
      // If stunned, Zero horizontal velocity and skip input input processing.
      // Vertical velocity (gravity) continues to apply normally (falling).
      if (world.controlLock.isStunned(e, currentTick)) {
        // Cancel dash if active (so we don't float)
        if (world.movement.dashTicksLeft[mi] > 0) {
          world.movement.dashTicksLeft[mi] = 0;
          // Restore gravity if it was suppressed by dash
          if (world.gravityControl.suppressGravityTicksLeft[world.gravityControl
                  .indexOf(e)] >
              0) {
            world.gravityControl.suppressGravityTicksLeft[world.gravityControl
                    .indexOf(e)] =
                0;
          }
        }
        world.transform.velX[ti] = 0;
        return;
      }

      // -- Timers --
      // Decrement state timers. These track temporary movement states.

      if (world.movement.dashTicksLeft[mi] > 0) {
        world.movement.dashTicksLeft[mi] -= 1;
      }
      final dashing = world.movement.dashTicksLeft[mi] > 0;
      final gearMoveSpeedMul = _gearMoveSpeedMultiplier(world, e);
      final modifierIndex = world.statModifier.tryIndexOf(e);
      final statusMoveSpeedMul = modifierIndex == null
          ? 1.0
          : world.statModifier.moveSpeedMul[modifierIndex];
      final moveSpeedMul = gearMoveSpeedMul * statusMoveSpeedMul;

      if (world.movement.facingLockTicksLeft[mi] > 0) {
        world.movement.facingLockTicksLeft[mi] -= 1;
      }

      // -- Horizontal Movement --
      if (dashing) {
        // [State: Dashing]
        // Lock velocity to the authored mobility speed and sampled scale.
        final baseSpeed = world.movement.mobilitySpeedX[mi];
        final dashSpeed =
            baseSpeed * moveSpeedMul * world.movement.dashSpeedScale[mi];
        world.transform.velX[ti] = world.movement.dashDirX[mi] * dashSpeed;
        world.transform.velY[ti] = world.movement.dashDirY[mi] * dashSpeed;
      } else {
        // [State: Normal Control]
        final axis = world.playerInput.moveAxis[ii];

        // Visuals: Update facing direction based on input.
        // This is decoupled from velocity to allow "turning" animations before velocity flips.
        if (world.movement.facingLockTicksLeft[mi] == 0 && axis != 0) {
          world.movement.facing[mi] = axis > 0 ? Facing.right : Facing.left;
        }

        // Apply horizontal acceleration/deceleration.
        world.transform.velX[ti] = _applyHorizontalMove(
          world.transform.velX[ti],
          axis,
          dt,
          tuning,
          moveSpeedMul,
        );
      }

      // -- Limits --
      // Soft cap on horizontal velocity to prevent runaway speeds from external forces.
      world.transform.velX[ti] = world.transform.velX[ti].clamp(
        -world.body.maxVelX[bi],
        world.body.maxVelX[bi],
      );

      if (fixedPointPilotEnabled) {
        world.transform.quantizeVelAtIndex(
          ti,
          subpixelScale: fixedPointSubpixelScale,
        );
      }
    });
  }

  double _gearMoveSpeedMultiplier(EcsWorld world, int entity) {
    final resolved = _statsCache.resolveForEntity(world, entity);
    return resolved.moveSpeedMultiplier;
  }

  /// Calculates the new horizontal velocity using linear acceleration/deceleration.
  ///
  /// Note:
  /// - Uses [t.decelerationX] when `axis == 0` (Stopping).
  /// - Uses [t.accelerationX] for both Speeding Up and Turning (changing direction).
  /// - Snaps to 0 if speed is below [t.minMoveSpeed] and input is 0.
  double _applyHorizontalMove(
    double velocityX,
    double axis,
    double dt,
    MovementTuningDerived tuning,
    double moveSpeedMul,
  ) {
    final t = tuning.base;
    final desiredX = axis == 0.0 ? 0.0 : axis * t.maxSpeedX * moveSpeedMul;
    return applyAccelDecel(
      current: velocityX,
      desired: desiredX,
      dtSeconds: dt,
      accelPerSecond: t.accelerationX * moveSpeedMul,
      decelPerSecond: t.decelerationX * moveSpeedMul,
      minStopSpeed: t.minMoveSpeed,
    );
  }

  // Dash initiation moved to MobilitySystem (ability-driven).
}
