import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/hit_payload_builder.dart';
import '../../snapshots/enums.dart';
import '../../projectiles/projectile_item_catalog.dart';
import '../../weapons/weapon_catalog.dart';
import '../../util/tick_math.dart';
import '../entity_id.dart';
import '../stores/combat/equipped_loadout_store.dart';
import '../stores/melee_intent_store.dart';
import '../stores/mobility_intent_store.dart';
import '../stores/projectile_intent_store.dart';
import '../stores/self_intent_store.dart';
import '../world.dart';

/// Routes player input into ability intents based on the equipped loadout.
///
/// **Responsibilities**:
/// - Read player input (strike/projectile/secondary/mobility/jump).
/// - Resolve the equipped ability for each slot.
/// - Emit intent stores (melee/projectile) for execution systems.
///
/// **Determinism**:
/// - No RNG.
/// - No wall-clock time; uses [currentTick].
class AbilityActivationSystem {
  const AbilityActivationSystem({
    required this.tickHz,
    required this.inputBufferTicks,
    required this.abilities,
    required this.weapons,
    required this.projectileItems,
  });

  final int tickHz;
  final int inputBufferTicks;
  final AbilityCatalog abilities;
  final WeaponCatalog weapons;
  final ProjectileItemCatalog projectileItems;

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    final inputIndex = world.playerInput.tryIndexOf(player);
    if (inputIndex == null) return;

    final movementIndex = world.movement.tryIndexOf(player);
    if (movementIndex == null) return;

    final loadoutIndex = world.equippedLoadout.tryIndexOf(player);
    if (loadoutIndex == null) return;

    if (world.controlLock.isStunned(player, currentTick)) return;

    final axis = world.playerInput.moveAxis[inputIndex];
    final Facing facing = axis != 0
        ? (axis > 0 ? Facing.right : Facing.left)
        : world.movement.facing[movementIndex];

    final bufferIndex = world.abilityInputBuffer.tryIndexOf(player);
    if (bufferIndex == null) {
      assert(
        false,
        'AbilityActivationSystem requires AbilityInputBufferStore on the player; add it at spawn time.',
      );
      return;
    }

    _expireBuffer(world, player, bufferIndex, currentTick);

    final activePhase = _activePhaseFor(world, player);
    final hasActive = activePhase != AbilityPhase.idle;
    final isRecovery = activePhase == AbilityPhase.recovery;

    final input = world.playerInput;
    if (input.dashPressed[inputIndex]) {
      _commitSlot(
        world,
        player: player,
        loadoutIndex: loadoutIndex,
        inputIndex: inputIndex,
        movementIndex: movementIndex,
        facing: facing,
        slot: AbilitySlot.mobility,
        commitTick: currentTick,
      );
      return;
    }
    if (input.jumpPressed[inputIndex]) {
      _cancelCombatOnMobilityPress(world, player);
      _commitSlot(
        world,
        player: player,
        loadoutIndex: loadoutIndex,
        inputIndex: inputIndex,
        movementIndex: movementIndex,
        facing: facing,
        slot: AbilitySlot.jump,
        commitTick: currentTick,
      );
      return;
    }

    final slotPressed = _resolvePressedSlot(world, inputIndex);

    if (hasActive) {
      if (slotPressed != null && isRecovery) {
        _bufferInput(
          world,
          player: player,
          bufferIndex: bufferIndex,
          loadoutIndex: loadoutIndex,
          inputIndex: inputIndex,
          facing: facing,
          slot: slotPressed,
          currentTick: currentTick,
        );
      }
      return;
    }

    if (slotPressed != null) {
      _commitSlot(
        world,
        player: player,
        loadoutIndex: loadoutIndex,
        inputIndex: inputIndex,
        movementIndex: movementIndex,
        facing: facing,
        slot: slotPressed,
        commitTick: currentTick,
      );
      return;
    }

    if (world.abilityInputBuffer.hasBuffered[bufferIndex]) {
      _commitBuffered(
        world,
        player: player,
        bufferIndex: bufferIndex,
        loadoutIndex: loadoutIndex,
        movementIndex: movementIndex,
        commitTick: currentTick,
      );
    }
  }

  AbilityPhase _activePhaseFor(EcsWorld world, EntityId entity) {
    if (!world.activeAbility.has(entity)) return AbilityPhase.idle;
    final index = world.activeAbility.indexOf(entity);
    final abilityId = world.activeAbility.abilityId[index];
    if (abilityId == null || abilityId.isEmpty) return AbilityPhase.idle;
    return world.activeAbility.phase[index];
  }

  AbilitySlot? _resolvePressedSlot(EcsWorld world, int inputIndex) {
    final input = world.playerInput;
    if (input.hasAbilitySlotPressed[inputIndex]) {
      return input.lastAbilitySlotPressed[inputIndex];
    }
    if (input.strikePressed[inputIndex]) return AbilitySlot.primary;
    if (input.secondaryPressed[inputIndex]) return AbilitySlot.secondary;
    if (input.projectilePressed[inputIndex]) return AbilitySlot.projectile;
    if (input.bonusPressed[inputIndex]) return AbilitySlot.bonus;
    return null;
  }

  void _expireBuffer(
    EcsWorld world,
    EntityId player,
    int bufferIndex,
    int currentTick,
  ) {
    if (!world.abilityInputBuffer.hasBuffered[bufferIndex]) return;
    final expires = world.abilityInputBuffer.expiresTick[bufferIndex];
    if (expires >= 0 && currentTick > expires) {
      world.abilityInputBuffer.clear(player);
    }
  }

  void _bufferInput(
    EcsWorld world, {
    required EntityId player,
    required int bufferIndex,
    required int loadoutIndex,
    required int inputIndex,
    required Facing facing,
    required AbilitySlot slot,
    required int currentTick,
  }) {
    final abilityId = _abilityIdForSlot(
      world,
      loadoutIndex,
      slot,
      inputIndex: inputIndex,
    );
    if (abilityId == null) return;
    final ability = abilities.resolve(abilityId);
    if (ability == null) return;

    final aim = _aimForAbility(world, inputIndex, slot, ability);

    world.abilityInputBuffer.setBuffer(
      player,
      slot: slot,
      abilityId: abilityId,
      aimDirX: aim.$1,
      aimDirY: aim.$2,
      facing: facing,
      commitTick: currentTick,
      expiresTick: currentTick + inputBufferTicks,
    );
  }

  void _commitBuffered(
    EcsWorld world, {
    required EntityId player,
    required int bufferIndex,
    required int loadoutIndex,
    required int movementIndex,
    required int commitTick,
  }) {
    final slot = world.abilityInputBuffer.slot[bufferIndex];
    final abilityId = world.abilityInputBuffer.abilityId[bufferIndex];
    final aimX = world.abilityInputBuffer.aimDirX[bufferIndex];
    final aimY = world.abilityInputBuffer.aimDirY[bufferIndex];
    final facing = world.abilityInputBuffer.facing[bufferIndex];

    final committed = _commitSlot(
      world,
      player: player,
      loadoutIndex: loadoutIndex,
      inputIndex: null,
      movementIndex: movementIndex,
      facing: facing,
      slot: slot,
      commitTick: commitTick,
      aimOverrideX: aimX,
      aimOverrideY: aimY,
      abilityOverrideId: abilityId,
    );

    if (committed) {
      world.abilityInputBuffer.clear(player);
    }
  }

  AbilityKey? _abilityIdForSlot(
    EcsWorld world,
    int loadoutIndex,
    AbilitySlot slot, {
    int? inputIndex,
  }) {
    final loadout = world.equippedLoadout;
    switch (slot) {
      case AbilitySlot.primary:
        return loadout.abilityPrimaryId[loadoutIndex];
      case AbilitySlot.secondary:
        return loadout.abilitySecondaryId[loadoutIndex];
      case AbilitySlot.projectile:
        return loadout.abilityProjectileId[loadoutIndex];
      case AbilitySlot.mobility:
        return loadout.abilityMobilityId[loadoutIndex];
      case AbilitySlot.jump:
        return loadout.abilityJumpId[loadoutIndex];
      case AbilitySlot.bonus:
        return null;
    }
  }

  (double, double) _aimForAbility(
    EcsWorld world,
    int inputIndex,
    AbilitySlot slot,
    AbilityDef ability,
  ) {
    final input = world.playerInput;
    if (slot == AbilitySlot.primary || slot == AbilitySlot.secondary) {
      return (input.meleeAimDirX[inputIndex], input.meleeAimDirY[inputIndex]);
    }
    if (slot == AbilitySlot.projectile) {
      return (
        input.projectileAimDirX[inputIndex],
        input.projectileAimDirY[inputIndex],
      );
    }
    return (0.0, 0.0);
  }

  bool _commitSlot(
    EcsWorld world, {
    required EntityId player,
    required int loadoutIndex,
    required int movementIndex,
    required Facing facing,
    required AbilitySlot slot,
    required int commitTick,
    int? inputIndex,
    double? aimOverrideX,
    double? aimOverrideY,
    AbilityKey? abilityOverrideId,
  }) {
    final abilityId =
        abilityOverrideId ??
        _abilityIdForSlot(world, loadoutIndex, slot, inputIndex: inputIndex);
    if (abilityId == null) return false;

    final ability = abilities.resolve(abilityId);
    if (ability == null) {
      assert(false, 'Ability not found: $abilityId');
      return false;
    }

    if (ability.category == AbilityCategory.mobility) {
      return _commitMobility(
        world,
        player: player,
        inputIndex: inputIndex,
        facing: facing,
        ability: ability,
        slot: slot,
        commitTick: commitTick,
      );
    }

    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is MeleeHitDelivery) {
      return _commitMelee(
        world,
        player: player,
        loadoutIndex: loadoutIndex,
        inputIndex: inputIndex,
        facing: facing,
        ability: ability,
        slot: slot,
        commitTick: commitTick,
        aimOverrideX: aimOverrideX,
        aimOverrideY: aimOverrideY,
      );
    }
    if (hitDelivery is ProjectileHitDelivery) {
      return _commitProjectile(
        world,
        player: player,
        loadoutIndex: loadoutIndex,
        inputIndex: inputIndex,
        movementIndex: movementIndex,
        facing: facing,
        ability: ability,
        commitTick: commitTick,
        aimOverrideX: aimOverrideX,
        aimOverrideY: aimOverrideY,
      );
    }
    if (hitDelivery is SelfHitDelivery) {
      return _commitSelf(
        world,
        player: player,
        loadoutIndex: loadoutIndex,
        ability: ability,
        slot: slot,
        commitTick: commitTick,
      );
    }

    return false;
  }

  bool _commitSelf(
    EcsWorld world, {
    required EntityId player,
    required int loadoutIndex,
    required AbilityDef ability,
    required AbilitySlot slot,
    required int commitTick,
  }) {
    if (!world.selfIntent.has(player)) {
      assert(
        false,
        'AbilityActivationSystem requires SelfIntentStore on the player; add it at spawn time.',
      );
      return false;
    }

    final mask = world.equippedLoadout.mask[loadoutIndex];
    if (slot == AbilitySlot.primary && (mask & LoadoutSlotMask.mainHand) == 0) {
      return false;
    }
    if (slot == AbilitySlot.secondary &&
        (mask & LoadoutSlotMask.offHand) == 0) {
      return false;
    }
    if (slot == AbilitySlot.projectile &&
        (mask & LoadoutSlotMask.projectile) == 0) {
      return false;
    }

    final windupTicks = _scaleAbilityTicks(ability.windupTicks);
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleAbilityTicks(ability.recoveryTicks);
    final executeTick = commitTick + windupTicks;
    final cooldownGroupId = ability.effectiveCooldownGroup(slot);

    world.selfIntent.set(
      player,
      SelfIntentDef(
        abilityId: ability.id,
        slot: slot,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownTicks: _scaleAbilityTicks(ability.cooldownTicks),
        staminaCost100: ability.staminaCost,
        manaCost100: ability.manaCost,
        cooldownGroupId: cooldownGroupId,
        tick: executeTick,
      ),
    );
    return true;
  }

  bool _commitMobility(
    EcsWorld world, {
    required EntityId player,
    required Facing facing,
    required AbilityDef ability,
    required AbilitySlot slot,
    required int commitTick,
    int? inputIndex,
  }) {
    if (!world.mobilityIntent.has(player)) {
      assert(
        false,
        'AbilityActivationSystem requires MobilityIntentStore on the player; add it at spawn time.',
      );
      return false;
    }

    final axis = inputIndex == null
        ? 0.0
        : world.playerInput.moveAxis[inputIndex];
    final dirX = axis != 0
        ? (axis > 0 ? 1.0 : -1.0)
        : (facing == Facing.right ? 1.0 : -1.0);

    final windupTicks = _scaleAbilityTicks(ability.windupTicks);
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleAbilityTicks(ability.recoveryTicks);
    final executeTick = commitTick + windupTicks;
    final cooldownGroupId = ability.effectiveCooldownGroup(slot);

    world.mobilityIntent.set(
      player,
      MobilityIntentDef(
        abilityId: ability.id,
        slot: slot,
        dirX: dirX,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownTicks: _scaleAbilityTicks(ability.cooldownTicks),
        staminaCost100: ability.staminaCost,
        cooldownGroupId: cooldownGroupId,
        tick: executeTick,
      ),
    );
    return true;
  }

  bool _commitMelee(
    EcsWorld world, {
    required EntityId player,
    required int loadoutIndex,
    required Facing facing,
    required AbilityDef ability,
    required AbilitySlot slot,
    required int commitTick,
    int? inputIndex,
    double? aimOverrideX,
    double? aimOverrideY,
  }) {
    if (!world.meleeIntent.has(player)) {
      assert(
        false,
        'AbilityActivationSystem requires MeleeIntentStore on the player; add it at spawn time.',
      );
      return false;
    }

    final mask = world.equippedLoadout.mask[loadoutIndex];
    if (slot == AbilitySlot.primary && (mask & LoadoutSlotMask.mainHand) == 0) {
      return false;
    }
    if (slot == AbilitySlot.secondary &&
        (mask & LoadoutSlotMask.offHand) == 0) {
      return false;
    }

    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is! MeleeHitDelivery) return false;

    final aimX =
        aimOverrideX ??
        (inputIndex == null ? 0.0 : world.playerInput.meleeAimDirX[inputIndex]);
    final aimY =
        aimOverrideY ??
        (inputIndex == null ? 0.0 : world.playerInput.meleeAimDirY[inputIndex]);
    final len2 = aimX * aimX + aimY * aimY;

    final double dirX;
    final double dirY;
    if (len2 > 1e-12) {
      final invLen = 1.0 / sqrt(len2);
      dirX = aimX * invLen;
      dirY = aimY * invLen;
    } else {
      dirX = facing == Facing.right ? 1.0 : -1.0;
      dirY = 0.0;
    }

    // Resolve hitbox dimensions from the ability.
    final halfX = hitDelivery.sizeX * 0.5;
    final halfY = hitDelivery.sizeY * 0.5;

    // Offset: push the hitbox forward from the player collider.
    var maxHalfExtent = 0.0;
    if (world.colliderAabb.has(player)) {
      final aabbi = world.colliderAabb.indexOf(player);
      final colliderHalfX = world.colliderAabb.halfX[aabbi];
      final colliderHalfY = world.colliderAabb.halfY[aabbi];
      maxHalfExtent = colliderHalfX > colliderHalfY
          ? colliderHalfX
          : colliderHalfY;
    }
    final forward =
        maxHalfExtent * 0.5 + max(halfX, halfY) + hitDelivery.offsetX;
    final offsetX = dirX * forward;
    final offsetY = dirY * forward + hitDelivery.offsetY;

    final weaponId = slot == AbilitySlot.secondary
        ? world.equippedLoadout.offhandWeaponId[loadoutIndex]
        : world.equippedLoadout.mainWeaponId[loadoutIndex];
    final weapon = weapons.get(weaponId);

    final payload = HitPayloadBuilder.build(
      ability: ability,
      source: player,
      weaponStats: weapon.stats,
      weaponDamageType: weapon.damageType,
      weaponProcs: weapon.procs,
    );

    final cooldownGroupId = ability.effectiveCooldownGroup(slot);

    world.meleeIntent.set(
      player,
      MeleeIntentDef(
        abilityId: ability.id,
        slot: slot,
        damage100: payload.damage100,
        damageType: payload.damageType,
        procs: payload.procs,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
        dirX: dirX,
        dirY: dirY,
        commitTick: commitTick,
        windupTicks: _scaleAbilityTicks(ability.windupTicks),
        activeTicks: _scaleAbilityTicks(ability.activeTicks),
        recoveryTicks: _scaleAbilityTicks(ability.recoveryTicks),
        cooldownTicks: _scaleAbilityTicks(ability.cooldownTicks),
        staminaCost100: ability.staminaCost,
        cooldownGroupId: cooldownGroupId,
        tick: commitTick + _scaleAbilityTicks(ability.windupTicks),
      ),
    );
    return true;
  }

  bool _commitProjectile(
    EcsWorld world, {
    required EntityId player,
    required int loadoutIndex,
    required int movementIndex,
    required Facing facing,
    required AbilityDef ability,
    required int commitTick,
    int? inputIndex,
    double? aimOverrideX,
    double? aimOverrideY,
  }) {
    if (!world.projectileIntent.has(player)) {
      assert(
        false,
        'AbilityActivationSystem requires ProjectileIntentStore on the player; add it at spawn time.',
      );
      return false;
    }

    final mask = world.equippedLoadout.mask[loadoutIndex];
    if ((mask & LoadoutSlotMask.projectile) == 0) return false;

    if (ability.category != AbilityCategory.magic &&
        ability.category != AbilityCategory.ranged) {
      return false;
    }

    final projectileItemId =
        world.equippedLoadout.projectileItemId[loadoutIndex];
    final projectileItem = projectileItems.tryGet(projectileItemId);
    if (projectileItem == null) {
      assert(false, 'Projectile item not found: $projectileItemId');
      return false;
    }

    final aimX =
        aimOverrideX ??
        (inputIndex == null
            ? 0.0
            : world.playerInput.projectileAimDirX[inputIndex]);
    final aimY =
        aimOverrideY ??
        (inputIndex == null
            ? 0.0
            : world.playerInput.projectileAimDirY[inputIndex]);
    final len2 = aimX * aimX + aimY * aimY;
    final fallbackDirX = facing == Facing.right ? 1.0 : -1.0;

    if (ability.category == AbilityCategory.ranged) {
      final double dirX;
      if (len2 > 1e-12) {
        final invLen = 1.0 / sqrt(len2);
        dirX = aimX * invLen;
      } else {
        dirX = fallbackDirX;
      }

      if (dirX.abs() > 1e-6) {
        world.movement.facing[movementIndex] = dirX >= 0
            ? Facing.right
            : Facing.left;
        world.movement.facingLockTicksLeft[movementIndex] = 1;
      }
    }

    double originOffset;
    if (projectileItem.weaponType == WeaponType.projectileSpell) {
      var maxHalfExtent = 0.0;
      if (world.colliderAabb.has(player)) {
        final aabbi = world.colliderAabb.indexOf(player);
        final halfX = world.colliderAabb.halfX[aabbi];
        final halfY = world.colliderAabb.halfY[aabbi];
        maxHalfExtent = halfX > halfY ? halfX : halfY;
      }
      originOffset = maxHalfExtent * 0.5;
    } else {
      originOffset = projectileItem.originOffset;
    }

    final payload = HitPayloadBuilder.build(
      ability: ability,
      source: player,
      weaponStats: projectileItem.stats,
      weaponDamageType: projectileItem.damageType,
      weaponProcs: projectileItem.procs,
    );

    final cooldownGroupId = ability.effectiveCooldownGroup(
      AbilitySlot.projectile,
    );

    world.projectileIntent.set(
      player,
      ProjectileIntentDef(
        projectileItemId: projectileItemId,
        abilityId: ability.id,
        slot: AbilitySlot.projectile,
        damage100: payload.damage100,
        staminaCost100: ability.staminaCost,
        manaCost100: ability.manaCost,
        cooldownTicks: _scaleAbilityTicks(ability.cooldownTicks),
        cooldownGroupId: cooldownGroupId,
        projectileId: projectileItem.projectileId,
        damageType: payload.damageType,
        procs: payload.procs,
        ballistic: projectileItem.ballistic,
        gravityScale: projectileItem.gravityScale,
        dirX: aimX,
        dirY: aimY,
        fallbackDirX: fallbackDirX,
        fallbackDirY: 0.0,
        originOffset: originOffset,
        commitTick: commitTick,
        windupTicks: _scaleAbilityTicks(ability.windupTicks),
        activeTicks: _scaleAbilityTicks(ability.activeTicks),
        recoveryTicks: _scaleAbilityTicks(ability.recoveryTicks),
        tick: commitTick + _scaleAbilityTicks(ability.windupTicks),
      ),
    );
    return true;
  }

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (tickHz == _abilityTickHz) return ticks;
    final seconds = ticks / _abilityTickHz;
    return ticksFromSecondsCeil(seconds, tickHz);
  }

  static const int _abilityTickHz = 60;

  void _cancelCombatOnMobilityPress(EcsWorld world, EntityId player) {
    _clearCombatIntents(world, player);
    if (world.abilityInputBuffer.has(player)) {
      world.abilityInputBuffer.clear(player);
    }
    _clearActiveCombatAbility(world, player);
  }

  void _clearCombatIntents(EcsWorld world, EntityId player) {
    if (world.meleeIntent.has(player)) {
      final i = world.meleeIntent.indexOf(player);
      world.meleeIntent.tick[i] = -1;
      world.meleeIntent.commitTick[i] = -1;
    }
    if (world.projectileIntent.has(player)) {
      final i = world.projectileIntent.indexOf(player);
      world.projectileIntent.tick[i] = -1;
      world.projectileIntent.commitTick[i] = -1;
    }
    if (world.selfIntent.has(player)) {
      final i = world.selfIntent.indexOf(player);
      world.selfIntent.tick[i] = -1;
      world.selfIntent.commitTick[i] = -1;
    }
  }

  void _clearActiveCombatAbility(EcsWorld world, EntityId player) {
    if (!world.activeAbility.has(player)) return;
    final i = world.activeAbility.indexOf(player);
    final abilityId = world.activeAbility.abilityId[i];
    if (abilityId == null || abilityId.isEmpty) {
      world.activeAbility.clear(player);
      return;
    }
    final def = abilities.resolve(abilityId);
    if (def == null || def.category != AbilityCategory.mobility) {
      world.activeAbility.clear(player);
    }
  }
}
