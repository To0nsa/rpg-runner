import '../ecs/entity_id.dart';
import '../ecs/stores/enemies/campaign_enemy_store.dart';
import '../ecs/stores/enemies/hashash_teleport_state_store.dart';
import '../ecs/systems/ability_interrupt.dart';
import '../ecs/world.dart';
import '../ecs/stores/hitbox_store.dart';

/// Marker-local activation, independent of camera/render visibility.
final class CampaignEnemySystem {
  static const activationRadius = 280.0;
  static const territoryRadius = 600.0;
  static const arrivalTolerance = 4.0;

  void step(EcsWorld world, {required EntityId player, required int tick}) {
    final pi = world.transform.indexOf(player);
    final store = world.campaignEnemy;
    for (var i = 0; i < store.denseEntities.length; i++) {
      final actor = store.denseEntities[i];
      if (world.deathState.has(actor) || world.arenaSuspension.has(actor)) {
        continue;
      }
      final hi = world.health.tryIndexOf(actor);
      if (hi == null || world.health.hp[hi] <= 0) continue;
      final ti = world.transform.indexOf(actor);
      final dx = world.transform.posX[pi] - store.homeX[i];
      final dy = world.transform.posY[pi] - store.homeY[i];
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared <= activationRadius * activationRadius) {
        _transition(world, actor, i, CampaignEnemyPhase.engaged);
      } else if (store.phase[i] == CampaignEnemyPhase.engaged &&
          store.returnWhenPlayerRetreats[i] &&
          distanceSquared > territoryRadius * territoryRadius &&
          tick >= store.provokedUntilTick[i]) {
        _transition(world, actor, i, CampaignEnemyPhase.returning);
      }
      if (store.phase[i] == CampaignEnemyPhase.returning &&
          (world.transform.posX[ti] - store.homeX[i]).abs() <=
              arrivalTolerance &&
          (world.transform.posY[ti] - store.homeY[i]).abs() <=
              arrivalTolerance) {
        _transition(world, actor, i, CampaignEnemyPhase.waiting);
      }
    }
  }

  /// Called only for accepted positive HP loss, including detached projectiles.
  /// Retaliation lasts two seconds even when the attacker is outside territory.
  void recordDamage(
    EcsWorld world, {
    required EntityId target,
    required int tick,
    required int tickHz,
  }) {
    final i = world.campaignEnemy.tryIndexOf(target);
    if (i == null) return;
    final hi = world.health.indexOf(target);
    if (world.health.hp[hi] <= 0) return;
    _transition(world, target, i, CampaignEnemyPhase.engaged);
    world.campaignEnemy.provokedUntilTick[i] = tick + 2 * tickHz;
  }

  void _transition(
    EcsWorld world,
    EntityId actor,
    int index,
    CampaignEnemyPhase next,
  ) {
    final store = world.campaignEnemy;
    if (store.phase[index] == next) return;
    store.phase[index] = next;
    // Invalidate the target route, but retain scalar commitments of a jump
    // already in flight; returning still has to land through normal terrain.
    final si = world.surfaceNav.tryIndexOf(actor);
    if (si != null) world.surfaceNav.targetEntity[si] = null;
    if (world.meleeEngagement.has(actor)) world.meleeEngagement.add(actor);
    if (world.meleeCombo.has(actor)) world.meleeCombo.add(actor);
    if (next == CampaignEnemyPhase.engaged) return;
    AbilityInterrupt.clearActiveAndTransient(
      world,
      entity: actor,
      startDeferredCooldown: true,
    );
    final teleport = world.hashashTeleport.tryIndexOf(actor);
    if (teleport != null) {
      world.hashashTeleport.phase[teleport] = HashashTeleportPhase.idle;
      world.hashashTeleport.phaseEndTick[teleport] = -1;
    }
    // Attached melee ends with the action. Released projectiles and anchored
    // impacts keep their ordinary collision, attribution and lifetime.
    for (final hit in world.hitbox.denseEntities.toList()) {
      final hi = world.hitbox.indexOf(hit);
      if (world.hitbox.owner[hi] == actor &&
          world.hitbox.attachment[hi] == HitboxAttachment.followOwner) {
        world.destroyEntity(hit);
      }
    }
  }
}
