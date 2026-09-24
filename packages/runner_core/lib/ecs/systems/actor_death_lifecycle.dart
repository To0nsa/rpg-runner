import '../../enemies/death_behavior.dart';
import '../entity_id.dart';
import '../stores/death_state_store.dart';
import '../world.dart';
import '../world_support_view.dart';

/// Shared death progression. Returns true only when a living actor first enters
/// death, allowing enemy kill accounting to remain separate from NPC outcomes.
bool advanceActorDeath(
  EcsWorld world,
  EntityId entity, {
  required int currentTick,
  required DeathBehavior behavior,
  required int deathAnimTicks,
  required int maxFallTicks,
}) {
  final death = world.deathState;
  final di = death.tryIndexOf(entity);
  final grounded = WorldSupportView(world).isGrounded(entity);
  if (di != null) {
    if (death.phase[di] != DeathPhase.fallingUntilGround) return false;
    final deadline = death.maxFallDespawnTick[di];
    if (!grounded && (deadline < 0 || currentTick < deadline)) return false;
    death.phase[di] = DeathPhase.deathAnim;
    death.deathStartTick[di] = currentTick;
    death.despawnTick[di] = currentTick + deathAnimTicks;
    _stopVelocity(world, entity);
    return false;
  }
  final hi = world.health.tryIndexOf(entity);
  if (hi == null || world.health.hp[hi] > 0) return false;
  if (behavior == DeathBehavior.groundImpactThenDeath && !grounded) {
    death.add(
      entity,
      DeathStateDef(
        phase: DeathPhase.fallingUntilGround,
        deathStartTick: -1,
        despawnTick: -1,
        maxFallDespawnTick: currentTick + maxFallTicks,
      ),
    );
    return true;
  }
  death.add(
    entity,
    DeathStateDef(
      phase: DeathPhase.deathAnim,
      deathStartTick: currentTick,
      despawnTick: currentTick + deathAnimTicks,
    ),
  );
  _stopVelocity(world, entity);
  return true;
}

void _stopVelocity(EcsWorld world, EntityId entity) {
  final ti = world.transform.tryIndexOf(entity);
  if (ti == null) return;
  world.transform.velX[ti] = 0;
  world.transform.velY[ti] = 0;
}
