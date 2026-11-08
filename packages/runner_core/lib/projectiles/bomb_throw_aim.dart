import 'dart:math' as math;

import '../abilities/ability_def.dart';
import '../combat/aim_motion_forecast.dart';
import '../ecs/hit/aabb_hit_utils.dart';
import '../ecs/world.dart';
import '../snapshots/enums.dart';
import '../tuning/physics_tuning.dart';

/// Hand origin and launch velocity in world units/seconds; target is null for
/// the forward fallback. Facing mirrors the attachment, never the trajectory.
typedef BombThrowSolution = ({
  double x,
  double y,
  double velocityX,
  double velocityY,
  Facing facing,
  int? target,
});

/// Read-only lob selection shared by commitment and final-position release.
/// Farthest reachable hostile wins, with entity ID breaking distance ties.
final class BombThrowAim {
  BombThrowAim({
    required this.tickHz,
    this.physics = const PhysicsTuning(),
    AimTerrain Function()? terrainProvider,
    this.pathClear,
  }) : _source = AimMotionForecast(
         tickHz: tickHz,
         physics: physics,
         terrainProvider: terrainProvider,
       ),
       _target = AimMotionForecast(
         tickHz: tickHz,
         physics: physics,
         terrainProvider: terrainProvider,
       );

  final int tickHz;
  final PhysicsTuning physics;
  final bool Function(double, double, double, double)? pathClear;
  final AimMotionForecast _source;
  final AimMotionForecast _target;

  /// Forecasts optional pre-release motion, then a fixed-duration upward lob.
  /// Gravity-before-motion matches Core integration; released bombs never steer.
  BombThrowSolution solve(
    EcsWorld world, {
    required int source,
    required BombHitDelivery delivery,
    required double maxSpeed,
    required double gravityScale,
    required Facing fallbackFacing,
    int motionTicksToRelease = 0,
  }) {
    _source.reset(world, source);
    _source.advance(motionTicksToRelease);
    final sourceX = _source.x, sourceY = _source.y;
    final flightTicks = (delivery.flightTicks * tickHz / 60).ceil();
    final seconds = flightTicks / tickHz;
    final gravity = physics.gravityY * gravityScale;
    final gravityVelocity = gravity * (seconds + 1 / tickHz) / 2;
    final faction = world.faction.faction[world.faction.indexOf(source)];
    BombThrowSolution? best;
    var bestDistance = -1.0;

    for (var i = 0; i < world.health.denseEntities.length; i++) {
      final target = world.health.denseEntities[i];
      final fi = world.faction.tryIndexOf(target);
      if (target == source ||
          fi == null ||
          world.health.hp[i] <= 0 ||
          world.deathState.has(target) ||
          world.arenaSuspension.has(target) ||
          !world.transform.has(target) ||
          areAllies(faction, world.faction.faction[fi])) {
        continue;
      }
      _target.reset(world, target);
      _target.advance(motionTicksToRelease);
      final dx = _target.x - sourceX, dy = _target.y - sourceY;
      final distance = dx * dx + dy * dy;
      if (distance > delivery.maxRange * delivery.maxRange ||
          distance < bestDistance ||
          (distance == bestDistance && target > best!.target!)) {
        continue;
      }
      final facing = dx < 0 ? Facing.left : Facing.right;
      final x = sourceX + delivery.releaseOffset.x * (dx < 0 ? -1 : 1);
      final y = sourceY + delivery.releaseOffset.y;
      _target.advance(flightTicks);
      final vx = (_target.x - x) / seconds;
      final vy = (_target.y - y) / seconds - gravityVelocity;
      if (vy >= 0 || vx * vx + vy * vy > maxSpeed * maxSpeed) continue;
      if (!_arcClear(x, y, vx, vy, gravity, flightTicks)) continue;
      bestDistance = distance;
      best = (
        x: x,
        y: y,
        velocityX: vx,
        velocityY: vy,
        facing: facing,
        target: target,
      );
    }
    if (best != null) return best;

    final sign = fallbackFacing == Facing.left ? -1 : 1;
    var vx = sign * delivery.fallbackRange / seconds;
    var vy = -gravityVelocity;
    final speed = math.sqrt(vx * vx + vy * vy);
    if (speed > maxSpeed) {
      vx *= maxSpeed / speed;
      vy *= maxSpeed / speed;
    }
    return (
      x: sourceX + delivery.releaseOffset.x * sign,
      y: sourceY + delivery.releaseOffset.y,
      velocityX: vx,
      velocityY: vy,
      facing: fallbackFacing,
      target: null,
    );
  }

  bool _arcClear(
    double x,
    double y,
    double vx,
    double vy,
    double gravity,
    int ticks,
  ) {
    final clear = pathClear;
    if (clear == null) return true;
    for (var tick = 0; tick < ticks; tick++) {
      vy += gravity / tickHz;
      final nextX = x + vx / tickHz, nextY = y + vy / tickHz;
      if (!clear(x, y, nextX, nextY)) return false;
      x = nextX;
      y = nextY;
    }
    return true;
  }
}
