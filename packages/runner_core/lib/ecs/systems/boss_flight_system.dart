import '../../combat/control_lock.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../util/velocity_math.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../stores/enemies/boss_flight_intent_store.dart';
import '../world.dart';

/// Converts boss-owned flight requests into velocity before knockback/terrain.
/// Catalog flight profiles disable gravity; this system never teleports or
/// manufactures support. No request, recovery, locks and death stop both axes.
final class BossFlightSystem {
  const BossFlightSystem({required this.tickHz});
  final int tickHz;

  // World units/second: preserve normal and half-speed combo pursuit cadence.
  static const pursuitSpeed = 240.0;
  static const comboSpeed = 150.0;
  // World units/second: follow jumps gradually, without snapping to the target.
  static const verticalSpeed = 300.0;

  /// Align collider bottoms to retain authored attack height across body sizes.
  static double targetHeight(EcsWorld world, EntityId actor, EntityId target) {
    final ci = world.colliderAabb.indexOf(actor);
    final tci = world.colliderAabb.indexOf(target);
    return world.transform.posY[world.transform.indexOf(target)] +
        world.colliderAabb.offsetY[tci] +
        world.colliderAabb.halfY[tci] -
        world.colliderAabb.offsetY[ci] -
        world.colliderAabb.halfY[ci] -
        terrainCollisionSkinTicks / terrainPhysicsTicksPerWorldUnit;
  }

  void step(EcsWorld world, {required int currentTick}) {
    final intents = world.bossFlightIntent;
    for (var i = 0; i < intents.denseEntities.length; i++) {
      final actor = intents.denseEntities[i];
      final ti = world.transform.indexOf(actor);
      if (intents.tick[i] != currentTick ||
          intents.mode[i] == BossFlightMode.hover ||
          !isLivingCombatActor(world, actor) ||
          world.arenaSuspension.has(actor) ||
          world.controlLock.isStunned(actor, currentTick) ||
          world.controlLock.isLocked(
            actor,
            LockFlag.move | LockFlag.allActions,
            currentTick,
          )) {
        world.transform.velX[ti] = 0;
        world.transform.velY[ti] = 0;
        continue;
      }
      if (intents.mode[i] == BossFlightMode.charge) {
        world.transform.velX[ti] = intents.speedX[i];
        world.transform.velY[ti] = 0;
        continue;
      }
      final si = world.statModifier.tryIndexOf(actor);
      final multiplier = si == null ? 1.0 : world.statModifier.moveSpeedMul[si];
      final dx = intents.targetX[i] - world.transform.posX[ti];
      final dy = intents.targetY[i] - world.transform.posY[ti];
      final speedX = intents.speedX[i] * multiplier;
      final speedY = intents.speedY[i] * multiplier;
      final desiredX = (dx * tickHz).clamp(-speedX, speedX);
      // World units/second², matching the established boss pursuit acceleration.
      final vx = applyAccelDecel(
        current: world.transform.velX[ti],
        desired: desiredX,
        dtSeconds: 1 / tickHz,
        accelPerSecond: 600,
        decelPerSecond: 400,
      );
      world.transform.velX[ti] = speedX == 0 || vx.sign != dx.sign
          ? 0
          : vx.clamp(-dx.abs() * tickHz, dx.abs() * tickHz);
      world.transform.velY[ti] = (dy * tickHz).clamp(-speedY, speedY);
    }
  }
}
