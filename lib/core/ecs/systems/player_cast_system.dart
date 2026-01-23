import '../../snapshots/enums.dart';
import '../../players/player_tuning.dart';
import '../entity_id.dart';
import '../stores/combat/equipped_loadout_store.dart';
import '../stores/cast_intent_store.dart';
import '../world.dart';
import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../projectiles/projectile_id.dart';
import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';

/// Translates player input into a [CastIntentDef] for the [SpellCastSystem].
///
/// **Responsibilities**:
/// *   Checks if the cast button is pressed.
/// *   Determines aiming direction based on input or facing direction.
/// *   Registers a cast intent to be processed (cooldown/mana checks happen downstream).
class PlayerCastSystem {
  const PlayerCastSystem({required this.abilities});

  final AbilityTuningDerived abilities;

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    // -- 1. Component Checks --

    // We need input to know if casting.
    final inputIndex = world.playerInput.tryIndexOf(player);
    if (inputIndex == null) return;

    // We need movement data for facing direction (fallback aim).
    final movementIndex = world.movement.tryIndexOf(player);
    if (movementIndex == null) return;

    // Check if the store exists (should be added at spawn).
    if (!world.castIntent.has(player)) {
      assert(
        false,
        'PlayerCastSystem requires CastIntentStore on the player; add it at spawn time.',
      );
      return;
    }

    final actionAnimIndex = world.actionAnim.tryIndexOf(player);
    if (actionAnimIndex == null) {
      assert(
        false,
        'PlayerCastSystem requires ActionAnimStore on the player; add it at spawn time.',
      );
      return;
    }

    final li = world.equippedLoadout.tryIndexOf(player);
    if (li == null) {
      assert(
        false,
        'PlayerCastSystem requires EquippedLoadoutStore on the player; add it at spawn time.',
      );
      return;
    }

    // -- 2. Input Logic --

    // If button not pressed, do nothing.
    if (!world.playerInput.castPressed[inputIndex]) return;

    final mask = world.equippedLoadout.mask[li];
    if ((mask & LoadoutSlotMask.spell) == 0) return;

    // Block intent creation if stunned
    if (world.controlLock.isStunned(player, currentTick)) return;

    final spellId = world.equippedLoadout.spellId[li];

    final facing = world.movement.facing[movementIndex];

    final rawAimX = world.playerInput.projectileAimDirX[inputIndex];
    final rawAimY = world.playerInput.projectileAimDirY[inputIndex];

    // Determine aim direction.
    // If rawAim is essentially zero/unbiased (e.g. controller neutral), use facing.
    // However, currently we pass fallbackDirX to the intent store separately.
    final fallbackDirX = facing == Facing.right ? 1.0 : -1.0;

    // Offset from the player's center where the spell appears.
    //
    // We use a conservative value (max half-extent) to avoid spawning inside
    // the player's AABB when the collider is not square.
    var maxHalfExtent = 0.0;
    if (world.colliderAabb.has(player)) {
      final aabbi = world.colliderAabb.indexOf(player);
      final halfX = world.colliderAabb.halfX[aabbi];
      final halfY = world.colliderAabb.halfY[aabbi];
      maxHalfExtent = halfX > halfY ? halfX : halfY;
    }
    final spawnOffset = maxHalfExtent * 0.5;

    // -- 3. Write Intent --

    // IMPORTANT: PlayerCastSystem writes intent only; execution happens in
    // `SpellCastSystem` which owns mana/cooldown rules and projectile spawning.
    // Use Ability ID from Loadout (Phase 4 requirement) (assumes mapped to spell/projectile slot)
    // Fallback: use legacy spellId to lookup ability? No, we need AbilityDef.
    // We'll use `abilityProjectileId` if it's a spell.
    final abilityId = world.equippedLoadout.abilityProjectileId[li];
    final ability = AbilityCatalog.tryGet(abilityId);
    
    if (ability == null) {
      assert(false, 'Ability not found: $abilityId');
      return;
    }

    // Resolve Payload from Ability Structure (Spells own their nature)
    var damageType = DamageType.physical;
    var status = StatusProfileId.none;

    if (ability.tags.contains(AbilityTag.fire)) {
      damageType = DamageType.fire;
      status = StatusProfileId.fireBolt; // Heuristic
    } else if (ability.tags.contains(AbilityTag.ice)) {
      damageType = DamageType.ice;
      status = StatusProfileId.iceBolt; // Heuristic
    } else if (ability.tags.contains(AbilityTag.lightning)) {
      damageType = DamageType.thunder; // Assuming 'thunder' matches 'lightning' tag
    }

    // Resolve Projectile ID
    ProjectileId projectileId;
    if (ability.hitDelivery is ProjectileHitDelivery) {
      projectileId = (ability.hitDelivery as ProjectileHitDelivery).projectileId;
    } else {
      projectileId = ProjectileId.iceBolt; // Fallback? Or Assert?
    }

    world.castIntent.set(
      player,
      CastIntentDef(
        spellId: spellId, // Legacy
        damage: ability.baseDamage / 100.0,
        manaCost: ability.manaCost / 100.0,
        projectileId: projectileId,
        damageType: damageType,
        statusProfileId: status,
        originOffset: spawnOffset,
        cooldownTicks: ability.cooldownTicks,
        tick: currentTick,
        dirX: rawAimX,
        dirY: rawAimY,
        fallbackDirX: fallbackDirX,
        fallbackDirY: 0.0,
      ),
    );
    world.actionAnim.lastCastTick[actionAnimIndex] = currentTick;
  }
}
