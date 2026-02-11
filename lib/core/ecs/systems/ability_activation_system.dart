import 'dart:math';

import '../../abilities/ability_gate.dart';
import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../accessories/accessory_catalog.dart';
import '../../combat/damage_type.dart';
import '../../combat/hit_payload_builder.dart';
import '../../snapshots/enums.dart';
import '../../projectiles/projectile_id.dart';
import '../../projectiles/projectile_item_catalog.dart';
import '../../projectiles/projectile_item_id.dart';
import '../../spells/spell_book_catalog.dart';
import '../../weapons/weapon_catalog.dart';
import '../../weapons/weapon_proc.dart';
import '../../stats/gear_stat_bonuses.dart';
import '../../stats/character_stats_resolver.dart';
import '../../util/fixed_math.dart';
import '../../util/tick_math.dart';
import '../entity_id.dart';
import '../hit/aabb_hit_utils.dart';
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
  AbilityActivationSystem({
    required this.tickHz,
    required this.inputBufferTicks,
    required this.abilities,
    required this.weapons,
    required this.projectileItems,
    required this.spellBooks,
    required this.accessories,
  }) : _statsResolver = CharacterStatsResolver(
         weapons: weapons,
         projectileItems: projectileItems,
         spellBooks: spellBooks,
         accessories: accessories,
       );

  final int tickHz;
  final int inputBufferTicks;
  final AbilityResolver abilities;
  final WeaponCatalog weapons;
  final ProjectileItemCatalog projectileItems;
  final SpellBookCatalog spellBooks;
  final AccessoryCatalog accessories;

  final CharacterStatsResolver _statsResolver;

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
      _cancelCombatOnMobilityPress(world, player);
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

    final aim = _aimForAbility(world, inputIndex, ability);

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
        return loadout.abilityBonusId[loadoutIndex];
    }
  }

  (double, double) _aimForAbility(
    EcsWorld world,
    int inputIndex,
    AbilityDef ability,
  ) {
    final input = world.playerInput;
    // Aim is a single global channel and is consumed by directional abilities.
    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is MeleeHitDelivery ||
        hitDelivery is ProjectileHitDelivery) {
      return (input.aimDirX[inputIndex], input.aimDirY[inputIndex]);
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

    if (!ability.allowedSlots.contains(slot)) {
      return false;
    }

    if (_isChargeCommitBlocked(
      world,
      player: player,
      slot: slot,
      ability: ability,
    )) {
      return false;
    }

    if (ability.category == AbilityCategory.mobility) {
      return _commitMobility(
        world,
        player: player,
        loadoutIndex: loadoutIndex,
        movementIndex: movementIndex,
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
        slot: slot,
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
        facing: facing,
        ability: ability,
        slot: slot,
        commitTick: commitTick,
      );
    }

    return false;
  }

  bool _isChargeCommitBlocked(
    EcsWorld world, {
    required EntityId player,
    required AbilitySlot slot,
    required AbilityDef ability,
  }) {
    if (ability.chargeProfile == null) return false;
    return world.abilityCharge.slotChargeCanceled(player, slot);
  }

  bool _commitSelf(
    EcsWorld world, {
    required EntityId player,
    required int loadoutIndex,
    required Facing facing,
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

    // Gate by payload source (Bonus can host anything, so slot is irrelevant).
    final mask = world.equippedLoadout.mask[loadoutIndex];
    switch (ability.payloadSource) {
      case AbilityPayloadSource.none:
        break;
      case AbilityPayloadSource.primaryWeapon:
        if ((mask & LoadoutSlotMask.mainHand) == 0) return false;
        break;
      case AbilityPayloadSource.secondaryWeapon:
        // Off-hand unless primary is two-handed.
        final mainId = world.equippedLoadout.mainWeaponId[loadoutIndex];
        final main = weapons.tryGet(mainId);
        if (main != null && main.isTwoHanded) {
          if ((mask & LoadoutSlotMask.mainHand) == 0) return false;
        } else {
          if ((mask & LoadoutSlotMask.offHand) == 0) return false;
        }
        break;
      case AbilityPayloadSource.projectileItem:
        if ((mask & LoadoutSlotMask.projectile) == 0) return false;
        break;
      case AbilityPayloadSource.spellBook:
        final spellBookId = world.equippedLoadout.spellBookId[loadoutIndex];
        if (spellBooks.tryGet(spellBookId) == null) return false;
        break;
    }

    final windupTicks = _scaleAbilityTicks(ability.windupTicks);
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleAbilityTicks(ability.recoveryTicks);
    final executeTick = commitTick + windupTicks;
    final cooldownGroupId = ability.effectiveCooldownGroup(slot);
    final resolvedStats = _resolvedStatsForLoadout(world, loadoutIndex);
    final cooldownTicks = resolvedStats.applyCooldownReduction(
      _scaleAbilityTicks(ability.cooldownTicks),
    );

    final fail = AbilityGate.canCommitCombat(
      world,
      entity: player,
      currentTick: commitTick,
      cooldownGroupId: cooldownGroupId,
      manaCost100: ability.manaCost,
      staminaCost100: ability.staminaCost,
    );
    if (fail != null) return false;
    if (ability.holdMode == AbilityHoldMode.holdToMaintain &&
        ability.holdStaminaDrainPerSecond100 > 0) {
      final staminaIndex = world.stamina.tryIndexOf(player);
      if (staminaIndex == null) return false;
      if (world.stamina.stamina[staminaIndex] <= 0) return false;
    }

    _applyCommitSideEffects(
      world,
      player: player,
      abilityId: ability.id,
      slot: slot,
      commitTick: commitTick,
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      recoveryTicks: recoveryTicks,
      facingDir: facing,
      cooldownGroupId: cooldownGroupId,
      cooldownTicks: cooldownTicks,
      manaCost100: ability.manaCost,
      staminaCost100: ability.staminaCost,
    );

    world.selfIntent.set(
      player,
      SelfIntentDef(
        abilityId: ability.id,
        slot: slot,
        selfStatusProfileId: ability.selfStatusProfileId,
        selfRestoreHealthBp: ability.selfRestoreHealthBp,
        selfRestoreManaBp: ability.selfRestoreManaBp,
        selfRestoreStaminaBp: ability.selfRestoreStaminaBp,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownTicks: cooldownTicks,
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
    required int loadoutIndex,
    required int movementIndex,
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
    final resolvedStats = _resolvedStatsForLoadout(world, loadoutIndex);
    final cooldownTicks = resolvedStats.applyCooldownReduction(
      _scaleAbilityTicks(ability.cooldownTicks),
    );

    // Preserve old behavior: mobility cancels pending combat + buffered input + active combat ability.
    _cancelCombatOnMobilityPress(world, player);

    final fail = AbilityGate.canCommitMobility(
      world,
      entity: player,
      currentTick: commitTick,
      cooldownGroupId: cooldownGroupId,
      staminaCost100: ability.staminaCost,
    );
    if (fail != null) return false;

    final facingDir = dirX >= 0 ? Facing.right : Facing.left;
    _applyCommitSideEffects(
      world,
      player: player,
      abilityId: ability.id,
      slot: slot,
      commitTick: commitTick,
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      recoveryTicks: recoveryTicks,
      facingDir: facingDir,
      cooldownGroupId: cooldownGroupId,
      cooldownTicks: cooldownTicks,
      manaCost100: 0,
      staminaCost100: ability.staminaCost,
      movementIndex: movementIndex,
    );

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
        cooldownTicks: cooldownTicks,
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
    // Gate by payload source, not by triggered slot.
    switch (ability.payloadSource) {
      case AbilityPayloadSource.none:
        break;
      case AbilityPayloadSource.primaryWeapon:
        if ((mask & LoadoutSlotMask.mainHand) == 0) return false;
        break;
      case AbilityPayloadSource.secondaryWeapon:
        final mainId = world.equippedLoadout.mainWeaponId[loadoutIndex];
        final main = weapons.tryGet(mainId);
        if (main != null && main.isTwoHanded) {
          if ((mask & LoadoutSlotMask.mainHand) == 0) return false;
        } else {
          if ((mask & LoadoutSlotMask.offHand) == 0) return false;
        }
        break;
      case AbilityPayloadSource.projectileItem:
        // Melee delivery cannot legally pull payload from projectile item.
        return false;
      case AbilityPayloadSource.spellBook:
        // Melee delivery cannot legally pull payload from spell book.
        return false;
    }

    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is! MeleeHitDelivery) return false;

    final rawAimX =
        aimOverrideX ??
        (inputIndex == null ? 0.0 : world.playerInput.aimDirX[inputIndex]);
    final rawAimY =
        aimOverrideY ??
        (inputIndex == null ? 0.0 : world.playerInput.aimDirY[inputIndex]);
    final fallbackDirX = facing == Facing.right ? 1.0 : -1.0;
    const fallbackDirY = 0.0;
    final resolvedAim = _resolveHomingAimDirection(
      world,
      source: player,
      ability: ability,
      rawAimX: rawAimX,
      rawAimY: rawAimY,
      fallbackDirX: fallbackDirX,
      fallbackDirY: fallbackDirY,
    );
    final aimX = resolvedAim.$1;
    final aimY = resolvedAim.$2;
    final len2 = aimX * aimX + aimY * aimY;

    final double dirX;
    final double dirY;
    if (len2 > 1e-12) {
      final invLen = 1.0 / sqrt(len2);
      dirX = aimX * invLen;
      dirY = aimY * invLen;
    } else {
      dirX = fallbackDirX;
      dirY = fallbackDirY;
    }

    final chargeTicks = _resolveCommitChargeTicks(
      world,
      player: player,
      slot: slot,
      commitTick: commitTick,
    );
    final chargeTuning = _resolveChargeTuning(
      ability: ability,
      chargeTicks: chargeTicks,
      defaults: const _ChargeTuning(
        damageScaleBp: 10000,
        critBonusBp: 0,
        speedScaleBp: 10000,
        hitboxScaleBp: 10000,
      ),
    );

    // Resolve hitbox dimensions from the ability.
    final baseHalfX = hitDelivery.sizeX * 0.5;
    final baseHalfY = hitDelivery.sizeY * 0.5;
    final halfX = (baseHalfX * chargeTuning.hitboxScaleBp) / 10000.0;
    final halfY = (baseHalfY * chargeTuning.hitboxScaleBp) / 10000.0;

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

    final weaponId = () {
      switch (ability.payloadSource) {
        case AbilityPayloadSource.primaryWeapon:
          return world.equippedLoadout.mainWeaponId[loadoutIndex];
        case AbilityPayloadSource.secondaryWeapon:
          final mainId = world.equippedLoadout.mainWeaponId[loadoutIndex];
          final main = weapons.tryGet(mainId);
          if (main != null && main.isTwoHanded) return mainId;
          return world.equippedLoadout.offhandWeaponId[loadoutIndex];
        case AbilityPayloadSource.none:
          // Fallback: preserve old behavior (slot-based) for any legacy melee.
          return slot == AbilitySlot.secondary
              ? world.equippedLoadout.offhandWeaponId[loadoutIndex]
              : world.equippedLoadout.mainWeaponId[loadoutIndex];
        case AbilityPayloadSource.projectileItem:
          return world.equippedLoadout.mainWeaponId[loadoutIndex];
        case AbilityPayloadSource.spellBook:
          return world.equippedLoadout.mainWeaponId[loadoutIndex];
      }
    }();
    final weapon = weapons.get(weaponId);
    final resolvedStats = _resolvedStatsForLoadout(world, loadoutIndex);

    final payload = HitPayloadBuilder.build(
      ability: ability,
      source: player,
      weaponStats: weapon.stats,
      weaponDamageType: weapon.damageType,
      weaponProcs: weapon.procs,
      globalCritChanceBonusBp: resolvedStats.critChanceBonusBp,
    );
    final tunedDamage100 =
        (payload.damage100 * chargeTuning.damageScaleBp) ~/ 10000;
    final tunedCritChanceBp = clampInt(
      payload.critChanceBp + chargeTuning.critBonusBp,
      0,
      10000,
    );

    final cooldownGroupId = ability.effectiveCooldownGroup(slot);
    final cooldownTicks = resolvedStats.applyCooldownReduction(
      _scaleAbilityTicks(ability.cooldownTicks),
    );

    final fail = AbilityGate.canCommitCombat(
      world,
      entity: player,
      currentTick: commitTick,
      cooldownGroupId: cooldownGroupId,
      manaCost100: 0,
      staminaCost100: ability.staminaCost,
    );
    if (fail != null) return false;

    final facingDir = dirX >= 0 ? Facing.right : Facing.left;
    _applyCommitSideEffects(
      world,
      player: player,
      abilityId: ability.id,
      slot: slot,
      commitTick: commitTick,
      windupTicks: _scaleAbilityTicks(ability.windupTicks),
      activeTicks: _scaleAbilityTicks(ability.activeTicks),
      recoveryTicks: _scaleAbilityTicks(ability.recoveryTicks),
      facingDir: facingDir,
      cooldownGroupId: cooldownGroupId,
      cooldownTicks: cooldownTicks,
      manaCost100: 0,
      staminaCost100: ability.staminaCost,
    );

    world.meleeIntent.set(
      player,
      MeleeIntentDef(
        abilityId: ability.id,
        slot: slot,
        damage100: tunedDamage100,
        critChanceBp: tunedCritChanceBp,
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
        cooldownTicks: cooldownTicks,
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
    required AbilitySlot slot,
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

    // Projectile delivery must pull payload from a projectile item or spell book.
    if (ability.payloadSource != AbilityPayloadSource.projectileItem &&
        ability.payloadSource != AbilityPayloadSource.spellBook) {
      return false;
    }
    final mask = world.equippedLoadout.mask[loadoutIndex];
    if ((mask & LoadoutSlotMask.projectile) == 0) return false;

    if (ability.category != AbilityCategory.magic &&
        ability.category != AbilityCategory.ranged) {
      return false;
    }

    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is! ProjectileHitDelivery) return false;
    final windupTicks = _scaleAbilityTicks(ability.windupTicks);
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleAbilityTicks(ability.recoveryTicks);

    final ProjectileItemId projectileItemId;
    final ProjectileId projectileId;
    final bool ballistic;
    final double gravityScale;
    final double originOffset;
    GearStatBonuses? weaponStats;
    DamageType? weaponDamageType;
    List<WeaponProc> weaponProcs = const <WeaponProc>[];

    switch (ability.payloadSource) {
      case AbilityPayloadSource.projectileItem:
        final equippedId = _resolveProjectileItemForSlot(
          world,
          loadoutIndex: loadoutIndex,
          slot: slot,
          ability: ability,
        );
        final projectileItem = projectileItems.tryGet(equippedId);
        if (projectileItem == null) {
          assert(false, 'Projectile item not found: $equippedId');
          return false;
        }
        if (ability.requiredWeaponTypes.isNotEmpty &&
            !ability.requiredWeaponTypes.contains(projectileItem.weaponType)) {
          return false;
        }
        projectileItemId = equippedId;
        projectileId = projectileItem.projectileId;
        ballistic = projectileItem.ballistic;
        gravityScale = projectileItem.gravityScale;
        originOffset =
            projectileItem.weaponType == WeaponType.projectileSpell &&
                projectileItem.originOffset == 0
            ? _spellOriginOffset(world, player)
            : projectileItem.originOffset;
        weaponStats = projectileItem.stats;
        weaponDamageType = projectileItem.damageType;
        weaponProcs = projectileItem.procs;
        break;
      case AbilityPayloadSource.spellBook:
        final spellBookId = world.equippedLoadout.spellBookId[loadoutIndex];
        final spellBook = spellBooks.tryGet(spellBookId);
        if (spellBook == null) {
          assert(false, 'Spell book not found: $spellBookId');
          return false;
        }
        projectileId = hitDelivery.projectileId;
        projectileItemId = _projectileItemIdForProjectile(projectileId);
        ballistic = false;
        gravityScale = 1.0;
        originOffset = _spellOriginOffset(world, player);
        weaponStats = spellBook.stats;
        weaponDamageType = spellBook.damageType;
        weaponProcs = spellBook.procs;
        break;
      case AbilityPayloadSource.none:
      case AbilityPayloadSource.primaryWeapon:
      case AbilityPayloadSource.secondaryWeapon:
        return false;
    }

    final rawAimX =
        aimOverrideX ??
        (inputIndex == null ? 0.0 : world.playerInput.aimDirX[inputIndex]);
    final rawAimY =
        aimOverrideY ??
        (inputIndex == null ? 0.0 : world.playerInput.aimDirY[inputIndex]);
    final fallbackDirX = facing == Facing.right ? 1.0 : -1.0;
    final fallbackDirY = 0.0;
    final resolvedAim = _resolveProjectileAimDirection(
      world,
      source: player,
      ability: ability,
      rawAimX: rawAimX,
      rawAimY: rawAimY,
      fallbackDirX: fallbackDirX,
      fallbackDirY: fallbackDirY,
    );
    final aimX = resolvedAim.$1;
    final aimY = resolvedAim.$2;
    final len2 = aimX * aimX + aimY * aimY;

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

    final resolvedStats = _resolvedStatsForLoadout(world, loadoutIndex);

    final payload = HitPayloadBuilder.build(
      ability: ability,
      source: player,
      weaponStats: weaponStats,
      weaponDamageType: weaponDamageType,
      weaponProcs: weaponProcs,
      globalCritChanceBonusBp: resolvedStats.critChanceBonusBp,
    );
    final chargeTicks = _resolveCommitChargeTicks(
      world,
      player: player,
      slot: slot,
      commitTick: commitTick,
    );
    final basePierce = hitDelivery.pierce;
    final baseMaxPierceHits = _maxPierceHitsFor(hitDelivery);
    final chargeTuning = _resolveChargeTuning(
      ability: ability,
      chargeTicks: chargeTicks,
      defaults: _ChargeTuning(
        damageScaleBp: 10000,
        critBonusBp: 0,
        speedScaleBp: 10000,
        hitboxScaleBp: 10000,
        pierce: basePierce,
        maxPierceHits: baseMaxPierceHits,
      ),
    );
    final tunedDamage100 =
        (payload.damage100 * chargeTuning.damageScaleBp) ~/ 10000;
    final tunedCritChanceBp = clampInt(
      payload.critChanceBp + chargeTuning.critBonusBp,
      0,
      10000,
    );

    final cooldownGroupId = ability.effectiveCooldownGroup(slot);
    final cooldownTicks = resolvedStats.applyCooldownReduction(
      _scaleAbilityTicks(ability.cooldownTicks),
    );

    final fail = AbilityGate.canCommitCombat(
      world,
      entity: player,
      currentTick: commitTick,
      cooldownGroupId: cooldownGroupId,
      manaCost100: ability.manaCost,
      staminaCost100: ability.staminaCost,
    );
    if (fail != null) return false;

    final primaryX = (aimX.abs() > 1e-6) ? aimX : fallbackDirX;
    final facingDir = primaryX >= 0 ? Facing.right : Facing.left;
    _applyCommitSideEffects(
      world,
      player: player,
      abilityId: ability.id,
      slot: slot,
      commitTick: commitTick,
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      recoveryTicks: recoveryTicks,
      facingDir: facingDir,
      cooldownGroupId: cooldownGroupId,
      cooldownTicks: cooldownTicks,
      manaCost100: ability.manaCost,
      staminaCost100: ability.staminaCost,
    );

    world.projectileIntent.set(
      player,
      ProjectileIntentDef(
        projectileItemId: projectileItemId,
        abilityId: ability.id,
        slot: slot,
        damage100: tunedDamage100,
        critChanceBp: tunedCritChanceBp,
        staminaCost100: ability.staminaCost,
        manaCost100: ability.manaCost,
        cooldownTicks: cooldownTicks,
        cooldownGroupId: cooldownGroupId,
        projectileId: projectileId,
        damageType: payload.damageType,
        procs: payload.procs,
        ballistic: ballistic,
        gravityScale: gravityScale,
        speedScaleBp: chargeTuning.speedScaleBp,
        dirX: aimX,
        dirY: aimY,
        fallbackDirX: fallbackDirX,
        fallbackDirY: fallbackDirY,
        originOffset: originOffset,
        pierce: chargeTuning.pierce ?? basePierce,
        maxPierceHits: chargeTuning.maxPierceHits ?? baseMaxPierceHits,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        tick: commitTick + windupTicks,
      ),
    );
    return true;
  }

  _ChargeTuning _resolveChargeTuning({
    required AbilityDef ability,
    required int chargeTicks,
    required _ChargeTuning defaults,
  }) {
    final profile = ability.chargeProfile;
    if (profile == null) return defaults;

    final holdTicks = chargeTicks < 0 ? 0 : chargeTicks;
    var resolved = defaults;
    for (final tier in profile.tiers) {
      final minHoldTicks = _scaleAbilityTicks(tier.minHoldTicks60);
      if (holdTicks < minHoldTicks) continue;
      resolved = _ChargeTuning(
        damageScaleBp: tier.damageScaleBp,
        critBonusBp: tier.critBonusBp,
        speedScaleBp: tier.speedScaleBp,
        hitboxScaleBp: tier.hitboxScaleBp,
        pierce: tier.pierce ?? defaults.pierce,
        maxPierceHits: tier.maxPierceHits ?? defaults.maxPierceHits,
      );
    }
    return resolved;
  }

  int _resolveCommitChargeTicks(
    EcsWorld world, {
    required EntityId player,
    required AbilitySlot slot,
    required int commitTick,
  }) {
    final authoritative = world.abilityCharge.commitChargeTicksOrUntracked(
      player,
      slot: slot,
      currentTick: commitTick,
    );
    return authoritative >= 0 ? authoritative : 0;
  }

  int _maxPierceHitsFor(ProjectileHitDelivery hitDelivery) {
    if (!hitDelivery.pierce) return 1;
    if (hitDelivery.chainCount > 0) return hitDelivery.chainCount;
    // Keep explicit piercing behavior even when no count is authored.
    return 2;
  }

  (double, double) _resolveHomingAimDirection(
    EcsWorld world, {
    required EntityId source,
    required AbilityDef ability,
    required double rawAimX,
    required double rawAimY,
    required double fallbackDirX,
    required double fallbackDirY,
  }) {
    if (ability.targetingModel != TargetingModel.homing) {
      return (rawAimX, rawAimY);
    }

    final nearest = _nearestHostileAim(
      world,
      source: source,
      fallbackDirX: fallbackDirX,
      fallbackDirY: fallbackDirY,
    );
    if (nearest != null) return nearest;
    return (rawAimX, rawAimY);
  }

  (double, double) _resolveProjectileAimDirection(
    EcsWorld world, {
    required EntityId source,
    required AbilityDef ability,
    required double rawAimX,
    required double rawAimY,
    required double fallbackDirX,
    required double fallbackDirY,
  }) {
    return _resolveHomingAimDirection(
      world,
      source: source,
      ability: ability,
      rawAimX: rawAimX,
      rawAimY: rawAimY,
      fallbackDirX: fallbackDirX,
      fallbackDirY: fallbackDirY,
    );
  }

  (double, double)? _nearestHostileAim(
    EcsWorld world, {
    required EntityId source,
    required double fallbackDirX,
    required double fallbackDirY,
  }) {
    final sourceTi = world.transform.tryIndexOf(source);
    if (sourceTi == null) return null;
    final sourceFi = world.faction.tryIndexOf(source);
    if (sourceFi == null) return null;
    final sourceFaction = world.faction.faction[sourceFi];

    final sourceX = world.transform.posX[sourceTi];
    final sourceY = world.transform.posY[sourceTi];

    var bestDist2 = double.infinity;
    var bestDx = 0.0;
    var bestDy = 0.0;
    var bestEntity = -1;

    final targets = world.health.denseEntities;
    for (var i = 0; i < targets.length; i += 1) {
      final target = targets[i];
      if (target == source || world.deathState.has(target)) continue;

      final targetFi = world.faction.tryIndexOf(target);
      if (targetFi == null) continue;
      if (areAllies(sourceFaction, world.faction.faction[targetFi])) continue;

      final targetTi = world.transform.tryIndexOf(target);
      if (targetTi == null) continue;
      final dx = world.transform.posX[targetTi] - sourceX;
      final dy = world.transform.posY[targetTi] - sourceY;
      final dist2 = dx * dx + dy * dy;
      if (dist2 <= 1e-12) continue;

      final closer = dist2 < bestDist2 - 1e-9;
      final sameDist = (dist2 - bestDist2).abs() <= 1e-9;
      final betterTie = sameDist && (bestEntity == -1 || target < bestEntity);
      if (closer || betterTie) {
        bestDist2 = dist2;
        bestDx = dx;
        bestDy = dy;
        bestEntity = target;
      }
    }

    if (bestEntity == -1) {
      final fbLen2 = fallbackDirX * fallbackDirX + fallbackDirY * fallbackDirY;
      if (fbLen2 <= 1e-12) return null;
      final invLen = 1.0 / sqrt(fbLen2);
      return (fallbackDirX * invLen, fallbackDirY * invLen);
    }

    final invLen = 1.0 / sqrt(bestDist2);
    return (bestDx * invLen, bestDy * invLen);
  }

  ProjectileItemId _resolveProjectileItemForSlot(
    EcsWorld world, {
    required int loadoutIndex,
    required AbilitySlot slot,
    required AbilityDef ability,
  }) {
    final loadout = world.equippedLoadout;
    final selectedSpellId = _selectedSpellIdForSlot(
      loadout,
      loadoutIndex: loadoutIndex,
      slot: slot,
    );
    if (selectedSpellId != null) {
      final selectedSpell = projectileItems.tryGet(selectedSpellId);
      final spellBookId = loadout.spellBookId[loadoutIndex];
      final spellBook = spellBooks.tryGet(spellBookId);
      final supportsSpell =
          selectedSpell != null &&
          selectedSpell.weaponType == WeaponType.projectileSpell &&
          spellBook != null &&
          spellBook.containsProjectileSpell(selectedSpellId) &&
          (ability.requiredWeaponTypes.isEmpty ||
              ability.requiredWeaponTypes.contains(WeaponType.projectileSpell));
      if (supportsSpell) {
        return selectedSpellId;
      }
    }
    return loadout.projectileItemId[loadoutIndex];
  }

  ProjectileItemId? _selectedSpellIdForSlot(
    EquippedLoadoutStore loadout, {
    required int loadoutIndex,
    required AbilitySlot slot,
  }) {
    switch (slot) {
      case AbilitySlot.projectile:
        return loadout.projectileSlotSpellId[loadoutIndex];
      case AbilitySlot.primary:
      case AbilitySlot.secondary:
      case AbilitySlot.mobility:
      case AbilitySlot.bonus:
      case AbilitySlot.jump:
        return null;
    }
  }

  double _spellOriginOffset(EcsWorld world, EntityId player) {
    var maxHalfExtent = 0.0;
    if (world.colliderAabb.has(player)) {
      final aabbi = world.colliderAabb.indexOf(player);
      final halfX = world.colliderAabb.halfX[aabbi];
      final halfY = world.colliderAabb.halfY[aabbi];
      maxHalfExtent = halfX > halfY ? halfX : halfY;
    }
    return maxHalfExtent * 0.5;
  }

  ProjectileItemId _projectileItemIdForProjectile(ProjectileId id) {
    switch (id) {
      case ProjectileId.iceBolt:
        return ProjectileItemId.iceBolt;
      case ProjectileId.fireBolt:
        return ProjectileItemId.fireBolt;
      case ProjectileId.thunderBolt:
        return ProjectileItemId.thunderBolt;
      case ProjectileId.throwingKnife:
        return ProjectileItemId.throwingKnife;
      case ProjectileId.throwingAxe:
        return ProjectileItemId.throwingAxe;
    }
  }

  ResolvedCharacterStats _resolvedStatsForLoadout(
    EcsWorld world,
    int loadoutIndex,
  ) {
    final loadout = world.equippedLoadout;
    return _statsResolver.resolveEquipped(
      mask: loadout.mask[loadoutIndex],
      mainWeaponId: loadout.mainWeaponId[loadoutIndex],
      offhandWeaponId: loadout.offhandWeaponId[loadoutIndex],
      projectileItemId: loadout.projectileItemId[loadoutIndex],
      spellBookId: loadout.spellBookId[loadoutIndex],
      accessoryId: loadout.accessoryId[loadoutIndex],
    );
  }

  void _applyCommitSideEffects(
    EcsWorld world, {
    required EntityId player,
    required AbilityKey abilityId,
    required AbilitySlot slot,
    required int commitTick,
    required int windupTicks,
    required int activeTicks,
    required int recoveryTicks,
    required Facing facingDir,
    required int cooldownGroupId,
    required int cooldownTicks,
    required int manaCost100,
    required int staminaCost100,
    int? movementIndex,
  }) {
    final abilityDef = abilities.resolve(abilityId);
    final deferCooldown =
        abilityDef?.holdMode == AbilityHoldMode.holdToMaintain;

    // Deduct mana (fixed-point) — deterministic clamp.
    if (manaCost100 > 0) {
      final mi = world.mana.tryIndexOf(player);
      assert(
        mi != null,
        'Missing ManaStore on $player for manaCost=$manaCost100',
      );
      if (mi != null) {
        final cur = world.mana.mana[mi];
        final max = world.mana.manaMax[mi];
        world.mana.mana[mi] = clampInt(cur - manaCost100, 0, max);
      }
    }

    // Deduct stamina (fixed-point) — deterministic clamp.
    if (staminaCost100 > 0) {
      final si = world.stamina.tryIndexOf(player);
      assert(
        si != null,
        'Missing StaminaStore on $player for staminaCost=$staminaCost100',
      );
      if (si != null) {
        final cur = world.stamina.stamina[si];
        final max = world.stamina.staminaMax[si];
        world.stamina.stamina[si] = clampInt(cur - staminaCost100, 0, max);
      }
    }

    // For hold abilities cooldown starts when hold ends; all others start at commit.
    if (!deferCooldown) {
      world.cooldown.startCooldown(player, cooldownGroupId, cooldownTicks);
    }

    // Mark active ability at commit.
    world.activeAbility.set(
      player,
      id: abilityId,
      slot: slot,
      commitTick: commitTick,
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      recoveryTicks: recoveryTicks,
      facingDir: facingDir,
      cooldownGroupId: cooldownGroupId,
      cooldownTicks: cooldownTicks,
      cooldownStarted: !deferCooldown,
    );

    // Keep movement facing consistent for mobility-like commits (matches old MobilitySystem behavior).
    if (movementIndex != null) {
      world.movement.facing[movementIndex] = facingDir;
    }
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

class _ChargeTuning {
  const _ChargeTuning({
    required this.damageScaleBp,
    required this.speedScaleBp,
    required this.critBonusBp,
    required this.hitboxScaleBp,
    this.pierce,
    this.maxPierceHits,
  });

  final int damageScaleBp;
  final int speedScaleBp;
  final int critBonusBp;
  final int hitboxScaleBp;
  final bool? pierce;
  final int? maxPierceHits;
}
