import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/systems/combat_hurtbox_system.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';

/// Mirrors Core's phase-before-pose ordering for synthetic combat worlds.
void resolveCommittedCombatPoses(EcsWorld world, int player, int tick) {
  attachMissingCombatCapsules(world);
  ActiveAbilityPhaseSystem().step(world, currentTick: tick);
  final tuning = PlayerCharacterRegistry.eloise.tuning;
  AnimSystem(
    tickHz: 60,
    enemyCatalog: const EnemyCatalog(),
    playerMovement: MovementTuningDerived.from(tuning.movement, tickHz: 60),
    playerAnimTuning: AnimTuningDerived.from(tuning.anim, tickHz: 60),
  ).step(world, player: player, currentTick: tick);
  const CombatHurtboxSystem(tickHz: 60).step(world);
}

/// Completes synthetic damageable actors with the runtime capsule derived from
/// their authored AABB. Production actors receive the equivalent catalog
/// capsule from terrain-authority initialization before broad-phase rebuild.
void attachMissingCombatCapsules(EcsWorld world) {
  for (final entity in world.health.denseEntities) {
    if (world.worldContactCapsule.has(entity)) continue;
    final colliderIndex = world.colliderAabb.tryIndexOf(entity);
    if (colliderIndex == null) continue;
    world.worldContactCapsule.add(
      entity,
      WorldContactCapsuleDef.fromAabb(
        ColliderAabbDef(
          halfX: world.colliderAabb.halfX[colliderIndex],
          halfY: world.colliderAabb.halfY[colliderIndex],
          offsetX: world.colliderAabb.offsetX[colliderIndex],
          offsetY: world.colliderAabb.offsetY[colliderIndex],
        ),
      ),
    );
  }
}
