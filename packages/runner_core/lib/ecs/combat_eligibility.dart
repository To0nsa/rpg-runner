import '../combat/damage_credit.dart';
import 'entity_id.dart';
import 'world.dart';

/// Shared terminal-NPC gate for AI, hit candidates and queued combat effects.
/// This does not affect physical terrain contact or ordinary invulnerability.
bool isCombatProtected(EcsWorld world, EntityId entity) =>
    world.npc.isProtected(entity);

/// Capture at attack creation so detached effects survive source destruction.
DamageCredit damageCreditFor(EcsWorld world, EntityId source) =>
    world.playerInput.has(source) ? DamageCredit.player : DamageCredit.none;
