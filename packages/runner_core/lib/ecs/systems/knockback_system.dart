import '../../combat/control_lock.dart';
import '../../combat/knockback.dart';
import '../../util/tick_math.dart';
import '../entity_id.dart';
import '../world.dart';
import 'ability_interrupt.dart';
import '../../abilities/ability_def.dart';

/// Overrides horizontal control before gravity and ordinary terrain integration.
///
/// It never changes positions or adds an upward launch. The discrete linear
/// taper sums to the authored distance in unobstructed, uncapped motion.
class KnockbackSystem {
  const KnockbackSystem({required this.tickHz});

  final int tickHz;

  static void queueAfterDamage(
    EcsWorld world, {
    required EntityId target,
    required KnockbackHit hit,
    required int currentTick,
    required int tickHz,
  }) {
    final bi = world.body.tryIndexOf(target);
    if (bi == null ||
        !world.body.enabled[bi] ||
        world.body.isKinematic[bi] ||
        !world.transform.has(target)) {
      return;
    }
    final duration = ticksFromSecondsCeil(hit.effect.durationSeconds, tickHz);
    world.knockback.set(
      target,
      distance: hit.directionX * hit.effect.distance,
      start: currentTick + 1,
      duration: duration,
    );
    world.controlLock.addLock(
      target,
      LockFlag.move | LockFlag.dash | LockFlag.nav,
      duration + 1,
      currentTick,
    );
    final mi = world.movement.tryIndexOf(target);
    if (mi != null && world.movement.dashTicksLeft[mi] > 0) {
      world.movement.dashTicksLeft[mi] = 0;
      final gi = world.gravityControl.tryIndexOf(target);
      if (gi != null) world.gravityControl.suppressGravityTicksLeft[gi] = 0;
    }
    final ai = world.activeAbility.tryIndexOf(target);
    if (ai != null && world.activeAbility.slot[ai] == AbilitySlot.mobility) {
      AbilityInterrupt.clearActiveAndTransient(
        world,
        entity: target,
        startDeferredCooldown: true,
      );
    }
    final ni = world.navIntent.tryIndexOf(target);
    if (ni != null) world.navIntent.clearActiveJumpTraversalAt(ni);
    final si = world.surfaceNav.tryIndexOf(target);
    if (si != null) {
      final state = world.surfaceNav.terrainState[si];
      state.invalidateForBundle(
        state.bundleVersion < 0 ? 0 : state.bundleVersion,
      );
    }
  }

  void step(EcsWorld world, {required int currentTick}) {
    final store = world.knockback;
    for (var i = store.denseEntities.length - 1; i >= 0; i--) {
      final entity = store.denseEntities[i];
      final ti = world.transform.tryIndexOf(entity);
      final bi = world.body.tryIndexOf(entity);
      final hi = world.health.tryIndexOf(entity);
      final bounds = world.actorMotionBounds.tryIndexOf(entity);
      final remaining =
          store.startTick[i] + store.durationTicks[i] - currentTick;
      if (ti == null ||
          bi == null ||
          !world.body.enabled[bi] ||
          world.body.isKinematic[bi] ||
          world.deathState.has(entity) ||
          (hi != null && world.health.hp[hi] <= 0) ||
          world.arenaSuspension.has(entity) ||
          (bounds != null && world.actorMotionBounds.frozen[bounds]) ||
          remaining <= 0) {
        store.removeEntity(entity);
        continue;
      }
      if (currentTick < store.startTick[i]) continue;
      final duration = store.durationTicks[i];
      final velocity =
          2 *
          store.signedDistance[i] *
          tickHz *
          remaining /
          (duration * (duration + 1));
      world.transform.velX[ti] = velocity.clamp(
        -world.body.maxVelX[bi],
        world.body.maxVelX[bi],
      );
      if (world.resolvedMotion.has(entity)) {
        world.resolvedMotion.setLocomotionReferenceSpeed(
          entity,
          ticksPerSecond: 0,
        );
      }
    }
  }
}
