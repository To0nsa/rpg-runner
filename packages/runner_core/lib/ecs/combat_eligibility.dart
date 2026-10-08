import '../combat/damage_credit.dart';
import 'entity_id.dart';
import 'world.dart';

/// Shared unconditional gate for hit candidates and queued combat effects.
/// Terminal NPCs and protected action activations retain physical terrain contact.
/// This is independent of ordinary post-hit invulnerability and combo bypasses.
bool isCombatProtected(EcsWorld world, EntityId entity) {
  if (world.npc.isProtected(entity)) return true;
  final i = world.activeAbility.tryIndexOf(entity);
  return i != null &&
      world.activeAbility.abilityId[i] != null &&
      world.activeAbility.invulnerable[i];
}

/// Capture at attack creation so detached effects survive source destruction.
DamageCredit damageCreditFor(EcsWorld world, EntityId source) =>
    world.playerInput.has(source) ? DamageCredit.player : DamageCredit.none;
