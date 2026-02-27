import 'dart:math';

import '../../abilities/ability_gate.dart';
import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../abilities/effective_ability_cost.dart';
import '../../accessories/accessory_catalog.dart';
import '../../combat/damage_type.dart';
import '../../combat/hit_payload_builder.dart';
import '../../snapshots/enums.dart';
import '../../projectiles/projectile_id.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../spellBook/spell_book_catalog.dart';
import '../../weapons/weapon_catalog.dart';
import '../../weapons/weapon_proc.dart';
import '../../stats/gear_stat_bonuses.dart';
import '../../stats/character_stats_resolver.dart';
import '../../stats/resolved_stats_cache.dart';
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
    required this.projectiles,
    required this.spellBooks,
    required this.accessories,
    ResolvedStatsCache? statsCache,
  }) : _statsCache =
           statsCache ??
           ResolvedStatsCache(
             resolver: CharacterStatsResolver(
               weapons: weapons,
               projectiles: projectiles,
               spellBooks: spellBooks,
               accessories: accessories,
             ),
           );

  final int tickHz;
  final int inputBufferTicks;
  final AbilityResolver abilities;
  final WeaponCatalog weapons;
  final ProjectileCatalog projectiles;
  final SpellBookCatalog spellBooks;
  final AccessoryCatalog accessories;

  final ResolvedStatsCache _statsCache;

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

    final isStunned = world.controlLock.isStunned(player, currentTick);

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

    if (isStunned) {
      if (slotPressed == null) return;
      final stunnedAbilityId = _abilityIdForSlot(
        world,
        loadoutIndex,
        slotPressed,
        inputIndex: inputIndex,
      );
      if (stunnedAbilityId == null) return;
      final stunnedAbility = abilities.resolve(stunnedAbilityId);
      if (stunnedAbility == null || !stunnedAbility.canCommitWhileStunned) {
        return;
      }
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
    if (input.spellPressed[inputIndex]) return AbilitySlot.spell;
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
      case AbilitySlot.spell:
        return loadout.abilitySpellId[loadoutIndex];
    }
  }

  (double, double) _aimForAbility(
    EcsWorld world,
    int inputIndex,
    AbilityDef ability,
  ) {
    final input = world.playerInput;
    if (ability.targetingModel == TargetingModel.none) return (0.0, 0.0);
    return (input.aimDirX[inputIndex], input.aimDirY[inputIndex]);
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
        ability: ability,
        slot: slot,
        commitTick: commitTick,
        aimOverrideX: aimOverrideX,
        aimOverrideY: aimOverrideY,
      );
    }

    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is MeleeHitDelivery) {
      return _commitMelee(
        world,
        player: player,
        loadoutIndex: loadoutIndex,
        inputIndex: inputIndex,
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
      case AbilityPayloadSource.projectile:
        if ((mask & LoadoutSlotMask.projectile) == 0) return false;
        break;
      case AbilityPayloadSource.spellBook:
        final spellBookId = world.equippedLoadout.spellBookId[loadoutIndex];
        final spellBook = spellBooks.tryGet(spellBookId);
        if (spellBook == null) return false;
        break;
    }

    final commitCost = resolveEffectiveAbilityCostForSlot(
      ability: ability,
      loadout: world.equippedLoadout,
      loadoutIndex: loadoutIndex,
      slot: slot,
      weapons: weapons,
      projectiles: projectiles,
      spellBooks: spellBooks,
    );
    final actionSpeedBp = _actionSpeedBpFor(world, player, slot: slot);
    final windupTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.windupTicks),
      actionSpeedBp,
    );
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.recoveryTicks),
      actionSpeedBp,
    );
    final executeTick = commitTick + windupTicks;
    final cooldownGroupId = ability.effectiveCooldownGroup(slot);
    final resolvedStats = _resolvedStatsForLoadout(world, player);
    final baseCooldownTicks = resolvedStats.applyCooldownReduction(
      _scaleAbilityTicks(ability.cooldownTicks),
    );
    final cooldownTicks = _scaleTicksForActionSpeed(
      baseCooldownTicks,
      actionSpeedBp,
    );

    final fail = AbilityGate.canCommitCombat(
      world,
      entity: player,
      currentTick: commitTick,
      cooldownGroupId: cooldownGroupId,
      healthCost100: commitCost.healthCost100,
      manaCost100: commitCost.manaCost100,
      staminaCost100: commitCost.staminaCost100,
      ignoreStun: ability.canCommitWhileStunned,
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
      healthCost100: commitCost.healthCost100,
      manaCost100: commitCost.manaCost100,
      staminaCost100: commitCost.staminaCost100,
    );

    world.selfIntent.set(
      player,
      SelfIntentDef(
        abilityId: ability.id,
        slot: slot,
        selfStatusProfileId: ability.selfStatusProfileId,
        selfPurgeProfileId: ability.selfPurgeProfileId,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownTicks: cooldownTicks,
        staminaCost100: commitCost.staminaCost100,
        manaCost100: commitCost.manaCost100,
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
    required AbilityDef ability,
    required AbilitySlot slot,
    required int commitTick,
    int? inputIndex,
    double? aimOverrideX,
    double? aimOverrideY,
  }) {
    if (!world.mobilityIntent.has(player)) {
      assert(
        false,
        'AbilityActivationSystem requires MobilityIntentStore on the player; add it at spawn time.',
      );
      return false;
    }

    final rawAimX =
        aimOverrideX ??
        (inputIndex == null ? 0.0 : world.playerInput.aimDirX[inputIndex]);
    final rawAimY =
        aimOverrideY ??
        (inputIndex == null ? 0.0 : world.playerInput.aimDirY[inputIndex]);
    final windupTicks = _scaleAbilityTicks(ability.windupTicks);
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleAbilityTicks(ability.recoveryTicks);
    final directionalFallback = _directionalFallbackDirection(
      world,
      movementIndex: movementIndex,
      inputIndex: inputIndex,
    );
    final dir = _resolveCommitDirection(
      world,
      source: player,
      ability: ability,
      rawAimX: rawAimX,
      rawAimY: rawAimY,
      directionalFallbackX: directionalFallback.$1,
      directionalFallbackY: directionalFallback.$2,
      homingWindupTicks: windupTicks,
      homingProjectileSpeedUnitsPerSecond: null,
    );
    final dirX = dir.$1;
    final dirY = dir.$2;
    final executeTick = commitTick + windupTicks;
    final cooldownGroupId = ability.effectiveCooldownGroup(slot);
    final resolvedStats = _resolvedStatsForLoadout(world, player);
    final cooldownTicks = resolvedStats.applyCooldownReduction(
      _scaleAbilityTicks(ability.cooldownTicks),
    );
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
      ),
    );
    final commitCost = resolveEffectiveAbilityCostForSlot(
      ability: ability,
      loadout: world.equippedLoadout,
      loadoutIndex: loadoutIndex,
      slot: slot,
      weapons: weapons,
      projectiles: projectiles,
      spellBooks: spellBooks,
    );

    // Preserve old behavior: mobility cancels pending combat + buffered input + active combat ability.
    _cancelCombatOnMobilityPress(world, player);

    final isJump = slot == AbilitySlot.jump;
    final fail = AbilityGate.canCommitMobility(
      world,
      entity: player,
      currentTick: commitTick,
      cooldownGroupId: cooldownGroupId,
      healthCost100: isJump ? 0 : commitCost.healthCost100,
      manaCost100: isJump ? 0 : commitCost.manaCost100,
      staminaCost100: isJump ? 0 : commitCost.staminaCost100,
    );
    if (fail != null) return false;

    // Jump resolves resources/execution in JumpSystem (ground vs air costs).
    if (!isJump) {
      final facingDir = _facingFromDirectionX(
        dirX,
        fallbackDirX: directionalFallback.$1,
      );
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
        healthCost100: commitCost.healthCost100,
        manaCost100: commitCost.manaCost100,
        staminaCost100: commitCost.staminaCost100,
        movementIndex: movementIndex,
      );
    }

    world.mobilityIntent.set(
      player,
      MobilityIntentDef(
        abilityId: ability.id,
        slot: slot,
        dirX: dirX,
        dirY: dirY,
        speedScaleBp: chargeTuning.speedScaleBp,
        mobilitySpeedX: ability.mobilitySpeedX ?? 0,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownTicks: cooldownTicks,
        staminaCost100: commitCost.staminaCost100,
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
      case AbilityPayloadSource.projectile:
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
    final actionSpeedBp = _actionSpeedBpFor(world, player, slot: slot);
    final windupTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.windupTicks),
      actionSpeedBp,
    );
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.recoveryTicks),
      actionSpeedBp,
    );
    final directionalFallback = _directionalFallbackDirection(
      world,
      movementIndex: world.movement.indexOf(player),
      inputIndex: inputIndex,
    );
    final dir = _resolveCommitDirection(
      world,
      source: player,
      ability: ability,
      rawAimX: rawAimX,
      rawAimY: rawAimY,
      directionalFallbackX: directionalFallback.$1,
      directionalFallbackY: directionalFallback.$2,
      homingWindupTicks: windupTicks,
      homingProjectileSpeedUnitsPerSecond: null,
    );
    final dirX = dir.$1;
    final dirY = dir.$2;

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
      ),
    );

    // Resolve hitbox dimensions from the ability.
    final baseHalfX = hitDelivery.sizeX * 0.5;
    final baseHalfY = hitDelivery.sizeY * 0.5;
    final halfX = baseHalfX;
    final halfY = baseHalfY;

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
        case AbilityPayloadSource.projectile:
          return world.equippedLoadout.mainWeaponId[loadoutIndex];
        case AbilityPayloadSource.spellBook:
          return world.equippedLoadout.mainWeaponId[loadoutIndex];
      }
    }();
    final weapon = weapons.get(weaponId);
    final commitCost = resolveEffectiveAbilityCostForSlot(
      ability: ability,
      loadout: world.equippedLoadout,
      loadoutIndex: loadoutIndex,
      slot: slot,
      weapons: weapons,
      projectiles: projectiles,
      spellBooks: spellBooks,
    );
    final resolvedStats = _resolvedStatsForLoadout(world, player);
    final offenseBuff = _offenseBuffBonusesFor(world, player);

    final payload = HitPayloadBuilder.build(
      ability: ability,
      source: player,
      weaponStats: weapon.stats,
      globalPowerBonusBp: resolvedStats.globalPowerBonusBp + offenseBuff.$1,
      weaponDamageType: weapon.damageType,
      weaponProcs: weapon.procs,
      globalCritChanceBonusBp:
          resolvedStats.globalCritChanceBonusBp + offenseBuff.$2,
    );
    final tunedDamage100 =
        (payload.damage100 * chargeTuning.damageScaleBp) ~/ 10000;
    final tunedCritChanceBp = clampInt(
      payload.critChanceBp + chargeTuning.critBonusBp,
      0,
      10000,
    );

    final cooldownGroupId = ability.effectiveCooldownGroup(slot);
    final baseCooldownTicks = resolvedStats.applyCooldownReduction(
      _scaleAbilityTicks(ability.cooldownTicks),
    );
    final cooldownTicks = _scaleTicksForActionSpeed(
      baseCooldownTicks,
      actionSpeedBp,
    );

    final fail = AbilityGate.canCommitCombat(
      world,
      entity: player,
      currentTick: commitTick,
      cooldownGroupId: cooldownGroupId,
      healthCost100: commitCost.healthCost100,
      manaCost100: commitCost.manaCost100,
      staminaCost100: commitCost.staminaCost100,
    );
    if (fail != null) return false;

    final facingDir = _facingFromDirectionX(
      dirX,
      fallbackDirX: directionalFallback.$1,
    );
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
      healthCost100: commitCost.healthCost100,
      manaCost100: commitCost.manaCost100,
      staminaCost100: commitCost.staminaCost100,
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
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownTicks: cooldownTicks,
        staminaCost100: commitCost.staminaCost100,
        cooldownGroupId: cooldownGroupId,
        tick: commitTick + windupTicks,
      ),
    );
    return true;
  }

  bool _commitProjectile(
    EcsWorld world, {
    required EntityId player,
    required int loadoutIndex,
    required int movementIndex,
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
    if (ability.payloadSource != AbilityPayloadSource.projectile &&
        ability.payloadSource != AbilityPayloadSource.spellBook) {
      return false;
    }
    final mask = world.equippedLoadout.mask[loadoutIndex];
    if ((mask & LoadoutSlotMask.projectile) == 0) return false;

    if (ability.category != AbilityCategory.ranged) {
      return false;
    }

    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is! ProjectileHitDelivery) return false;
    final actionSpeedBp = _actionSpeedBpFor(world, player, slot: slot);
    final windupTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.windupTicks),
      actionSpeedBp,
    );
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.recoveryTicks),
      actionSpeedBp,
    );

    final ProjectileId projectileId;
    final bool ballistic;
    final double gravityScale;
    final double originOffset;
    final double projectileBaseSpeedUnitsPerSecond;
    GearStatBonuses? weaponStats;
    DamageType? weaponDamageType;
    List<WeaponProc> weaponProcs = const <WeaponProc>[];

    switch (ability.payloadSource) {
      case AbilityPayloadSource.projectile:
        final equippedId = resolveProjectilePayloadForAbilitySlot(
          ability: ability,
          loadout: world.equippedLoadout,
          loadoutIndex: loadoutIndex,
          slot: slot,
          projectiles: projectiles,
        );
        final projectile = projectiles.tryGet(equippedId);
        if (projectile == null) {
          assert(false, 'Projectile item not found: $equippedId');
          return false;
        }
        if (ability.requiredWeaponTypes.isNotEmpty &&
            !ability.requiredWeaponTypes.contains(projectile.weaponType)) {
          return false;
        }
        projectileId = equippedId;
        ballistic = projectile.ballistic;
        gravityScale = projectile.gravityScale;
        projectileBaseSpeedUnitsPerSecond = projectile.speedUnitsPerSecond;
        originOffset =
            projectile.weaponType == WeaponType.spell &&
                projectile.originOffset == 0
            ? _spellOriginOffset(world, player)
            : projectile.originOffset;
        weaponStats = projectile.stats;
        weaponDamageType = projectile.damageType;
        weaponProcs = projectile.procs;
        break;
      case AbilityPayloadSource.spellBook:
        final spellBookId = world.equippedLoadout.spellBookId[loadoutIndex];
        final spellBook = spellBooks.tryGet(spellBookId);
        if (spellBook == null) {
          assert(false, 'Spell book not found: $spellBookId');
          return false;
        }
        projectileId = hitDelivery.projectileId;
        projectileBaseSpeedUnitsPerSecond = projectiles
            .get(projectileId)
            .speedUnitsPerSecond;
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
        pierce: basePierce,
        maxPierceHits: baseMaxPierceHits,
      ),
    );

    final rawAimX =
        aimOverrideX ??
        (inputIndex == null ? 0.0 : world.playerInput.aimDirX[inputIndex]);
    final rawAimY =
        aimOverrideY ??
        (inputIndex == null ? 0.0 : world.playerInput.aimDirY[inputIndex]);
    final directionalFallback = _directionalFallbackDirection(
      world,
      movementIndex: movementIndex,
      inputIndex: inputIndex,
    );
    final fallbackDirX = directionalFallback.$1;
    final fallbackDirY = directionalFallback.$2;
    final resolvedDir = _resolveCommitDirection(
      world,
      source: player,
      ability: ability,
      rawAimX: rawAimX,
      rawAimY: rawAimY,
      directionalFallbackX: fallbackDirX,
      directionalFallbackY: fallbackDirY,
      homingWindupTicks: windupTicks,
      homingProjectileSpeedUnitsPerSecond:
          projectileBaseSpeedUnitsPerSecond *
          (chargeTuning.speedScaleBp / 10000.0),
    );
    final aimX = resolvedDir.$1;
    final aimY = resolvedDir.$2;

    if (ability.category == AbilityCategory.ranged) {
      final dirX = aimX;
      if (dirX.abs() > 1e-6) {
        world.movement.facing[movementIndex] = dirX >= 0
            ? Facing.right
            : Facing.left;
        world.movement.facingLockTicksLeft[movementIndex] = 1;
      }
    }

    final resolvedStats = _resolvedStatsForLoadout(world, player);
    final offenseBuff = _offenseBuffBonusesFor(world, player);

    final payload = HitPayloadBuilder.build(
      ability: ability,
      source: player,
      weaponStats: weaponStats,
      globalPowerBonusBp: resolvedStats.globalPowerBonusBp + offenseBuff.$1,
      weaponDamageType: weaponDamageType,
      weaponProcs: weaponProcs,
      globalCritChanceBonusBp:
          resolvedStats.globalCritChanceBonusBp + offenseBuff.$2,
    );
    final tunedDamage100 =
        (payload.damage100 * chargeTuning.damageScaleBp) ~/ 10000;
    final tunedCritChanceBp = clampInt(
      payload.critChanceBp + chargeTuning.critBonusBp,
      0,
      10000,
    );

    final cooldownGroupId = ability.effectiveCooldownGroup(slot);
    final baseCooldownTicks = resolvedStats.applyCooldownReduction(
      _scaleAbilityTicks(ability.cooldownTicks),
    );
    final cooldownTicks = _scaleTicksForActionSpeed(
      baseCooldownTicks,
      actionSpeedBp,
    );
    final commitCost = resolveEffectiveAbilityCostForSlot(
      ability: ability,
      loadout: world.equippedLoadout,
      loadoutIndex: loadoutIndex,
      slot: slot,
      weapons: weapons,
      projectiles: projectiles,
      spellBooks: spellBooks,
    );

    final fail = AbilityGate.canCommitCombat(
      world,
      entity: player,
      currentTick: commitTick,
      cooldownGroupId: cooldownGroupId,
      healthCost100: commitCost.healthCost100,
      manaCost100: commitCost.manaCost100,
      staminaCost100: commitCost.staminaCost100,
    );
    if (fail != null) return false;

    final facingDir = _facingFromDirectionX(aimX, fallbackDirX: fallbackDirX);
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
      healthCost100: commitCost.healthCost100,
      manaCost100: commitCost.manaCost100,
      staminaCost100: commitCost.staminaCost100,
    );

    world.projectileIntent.set(
      player,
      ProjectileIntentDef(
        projectileId: projectileId,
        abilityId: ability.id,
        slot: slot,
        damage100: tunedDamage100,
        critChanceBp: tunedCritChanceBp,
        staminaCost100: commitCost.staminaCost100,
        manaCost100: commitCost.manaCost100,
        cooldownTicks: cooldownTicks,
        cooldownGroupId: cooldownGroupId,
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

  (double, double) _resolveCommitDirection(
    EcsWorld world, {
    required EntityId source,
    required AbilityDef ability,
    required double rawAimX,
    required double rawAimY,
    required double directionalFallbackX,
    required double directionalFallbackY,
    required int homingWindupTicks,
    required double? homingProjectileSpeedUnitsPerSecond,
  }) {
    final targetSpecific = _resolveTargetSpecificDirection(
      world,
      source: source,
      ability: ability,
      rawAimX: rawAimX,
      rawAimY: rawAimY,
      directionalFallbackX: directionalFallbackX,
      directionalFallbackY: directionalFallbackY,
      homingWindupTicks: homingWindupTicks,
      homingProjectileSpeedUnitsPerSecond: homingProjectileSpeedUnitsPerSecond,
    );
    if (targetSpecific != null) return targetSpecific;

    final inputIndex = world.playerInput.tryIndexOf(source);
    if (inputIndex != null) {
      final globalAim = _normalizeDirectionOrNull(
        world.playerInput.aimDirX[inputIndex],
        world.playerInput.aimDirY[inputIndex],
      );
      if (globalAim != null) return globalAim;
    }

    final directionalFallback = _normalizeDirectionOrNull(
      directionalFallbackX,
      directionalFallbackY,
    );
    if (directionalFallback != null) return directionalFallback;
    return (1.0, 0.0);
  }

  (double, double)? _resolveTargetSpecificDirection(
    EcsWorld world, {
    required EntityId source,
    required AbilityDef ability,
    required double rawAimX,
    required double rawAimY,
    required double directionalFallbackX,
    required double directionalFallbackY,
    required int homingWindupTicks,
    required double? homingProjectileSpeedUnitsPerSecond,
  }) {
    switch (ability.targetingModel) {
      case TargetingModel.none:
        return null;
      case TargetingModel.homing:
        return _nearestHostileAim(
          world,
          source: source,
          windupTicks: homingWindupTicks,
          projectileSpeedUnitsPerSecond: homingProjectileSpeedUnitsPerSecond,
        );
      case TargetingModel.directional:
        return _normalizeDirectionOrNull(rawAimX, rawAimY) ??
            _normalizeDirectionOrNull(
              directionalFallbackX,
              directionalFallbackY,
            );
      case TargetingModel.aimed:
      case TargetingModel.aimedLine:
      case TargetingModel.aimedCharge:
      case TargetingModel.groundTarget:
        return _normalizeDirectionOrNull(rawAimX, rawAimY);
    }
  }

  (double, double)? _normalizeDirectionOrNull(double x, double y) {
    final len2 = x * x + y * y;
    if (len2 <= 1e-12) return null;
    final invLen = 1.0 / sqrt(len2);
    return (x * invLen, y * invLen);
  }

  (double, double) _directionalFallbackDirection(
    EcsWorld world, {
    required int movementIndex,
    required int? inputIndex,
  }) {
    final axis = inputIndex == null
        ? 0.0
        : world.playerInput.moveAxis[inputIndex];
    if (axis.abs() > 1e-6) {
      return (axis > 0 ? 1.0 : -1.0, 0.0);
    }
    final facing = world.movement.facing[movementIndex];
    return (facing == Facing.right ? 1.0 : -1.0, 0.0);
  }

  Facing _facingFromDirectionX(double dirX, {required double fallbackDirX}) {
    final primaryX = dirX.abs() > 1e-6 ? dirX : fallbackDirX;
    return primaryX >= 0 ? Facing.right : Facing.left;
  }

  (double, double)? _nearestHostileAim(
    EcsWorld world, {
    required EntityId source,
    required int windupTicks,
    required double? projectileSpeedUnitsPerSecond,
  }) {
    final sourceTi = world.transform.tryIndexOf(source);
    if (sourceTi == null) return null;
    final sourceFi = world.faction.tryIndexOf(source);
    if (sourceFi == null) return null;
    final sourceFaction = world.faction.faction[sourceFi];

    final sourceX = world.transform.posX[sourceTi];
    final sourceY = world.transform.posY[sourceTi];
    final sourceVelX = world.transform.velX[sourceTi];
    final sourceVelY = world.transform.velY[sourceTi];
    final windupSeconds = max(0.0, windupTicks.toDouble()) / tickHz;
    final sourceExecuteX = sourceX + sourceVelX * windupSeconds;
    final sourceExecuteY = sourceY + sourceVelY * windupSeconds;

    final hasProjectileLead =
        projectileSpeedUnitsPerSecond != null &&
        projectileSpeedUnitsPerSecond > 1e-6;

    var bestDist2 = double.infinity;
    var bestInterceptSeconds = double.infinity;
    var bestHasIntercept = false;
    var bestAimX = 0.0;
    var bestAimY = 0.0;
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
      final targetX = world.transform.posX[targetTi];
      final targetY = world.transform.posY[targetTi];
      final targetVelX = world.transform.velX[targetTi];
      final targetVelY = world.transform.velY[targetTi];

      final targetExecuteX = targetX + targetVelX * windupSeconds;
      final targetExecuteY = targetY + targetVelY * windupSeconds;
      final relX = targetExecuteX - sourceExecuteX;
      final relY = targetExecuteY - sourceExecuteY;
      final relDist2 = relX * relX + relY * relY;
      if (relDist2 <= 1e-12) continue;

      var candidateHasIntercept = false;
      var candidateInterceptSeconds = double.infinity;
      var candidateAimX = relX;
      var candidateAimY = relY;

      if (hasProjectileLead) {
        final interceptSeconds = _solveInterceptSeconds(
          relX: relX,
          relY: relY,
          targetVelX: targetVelX,
          targetVelY: targetVelY,
          projectileSpeedUnitsPerSecond: projectileSpeedUnitsPerSecond,
        );
        if (interceptSeconds != null) {
          candidateHasIntercept = true;
          candidateInterceptSeconds = interceptSeconds;
          candidateAimX = relX + targetVelX * interceptSeconds;
          candidateAimY = relY + targetVelY * interceptSeconds;
        }
      }

      final candidateAimLen2 =
          candidateAimX * candidateAimX + candidateAimY * candidateAimY;
      if (candidateAimLen2 <= 1e-12) continue;

      var take = false;
      if (bestEntity == -1) {
        take = true;
      } else if (hasProjectileLead) {
        if (candidateHasIntercept != bestHasIntercept) {
          take = candidateHasIntercept && !bestHasIntercept;
        } else if (candidateHasIntercept) {
          final faster =
              candidateInterceptSeconds < bestInterceptSeconds - 1e-9;
          final sameTime =
              (candidateInterceptSeconds - bestInterceptSeconds).abs() <= 1e-9;
          final betterTie = sameTime && target < bestEntity;
          take = faster || betterTie;
        } else {
          final closer = relDist2 < bestDist2 - 1e-9;
          final sameDist = (relDist2 - bestDist2).abs() <= 1e-9;
          final betterTie = sameDist && target < bestEntity;
          take = closer || betterTie;
        }
      } else {
        final closer = relDist2 < bestDist2 - 1e-9;
        final sameDist = (relDist2 - bestDist2).abs() <= 1e-9;
        final betterTie = sameDist && target < bestEntity;
        take = closer || betterTie;
      }

      if (take) {
        bestEntity = target;
        bestDist2 = relDist2;
        bestInterceptSeconds = candidateInterceptSeconds;
        bestHasIntercept = candidateHasIntercept;
        bestAimX = candidateAimX;
        bestAimY = candidateAimY;
      }
    }

    if (bestEntity == -1) return null;

    final bestAimLen2 = bestAimX * bestAimX + bestAimY * bestAimY;
    if (bestAimLen2 <= 1e-12) return null;
    final invLen = 1.0 / sqrt(bestAimLen2);
    return (bestAimX * invLen, bestAimY * invLen);
  }

  double? _solveInterceptSeconds({
    required double relX,
    required double relY,
    required double targetVelX,
    required double targetVelY,
    required double projectileSpeedUnitsPerSecond,
  }) {
    if (projectileSpeedUnitsPerSecond <= 1e-9) return null;
    final c = relX * relX + relY * relY;
    if (c <= 1e-12) return 0.0;

    final speed2 =
        projectileSpeedUnitsPerSecond * projectileSpeedUnitsPerSecond;
    final vv = targetVelX * targetVelX + targetVelY * targetVelY;
    final rv = relX * targetVelX + relY * targetVelY;
    final a = vv - speed2;
    final b = 2.0 * rv;

    // Degenerate to linear solve when quadratic term is tiny.
    if (a.abs() <= 1e-9) {
      if (b.abs() <= 1e-9) return null;
      final t = -c / b;
      return t >= 0.0 ? t : null;
    }

    final discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) return null;
    final sqrtDisc = sqrt(discriminant);
    final denom = 2.0 * a;
    final t0 = (-b - sqrtDisc) / denom;
    final t1 = (-b + sqrtDisc) / denom;

    double? best;
    if (t0 >= 0.0) best = t0;
    if (t1 >= 0.0 && (best == null || t1 < best)) best = t1;
    return best;
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

  ResolvedCharacterStats _resolvedStatsForLoadout(
    EcsWorld world,
    EntityId entity,
  ) {
    return _statsCache.resolveForEntity(world, entity);
  }

  (int, int) _offenseBuffBonusesFor(EcsWorld world, EntityId entity) {
    final index = world.offenseBuff.tryIndexOf(entity);
    if (index == null) return (0, 0);
    if (world.offenseBuff.ticksLeft[index] <= 0) return (0, 0);
    return (
      world.offenseBuff.powerBonusBp[index],
      world.offenseBuff.critBonusBp[index],
    );
  }

  int _actionSpeedBpFor(
    EcsWorld world,
    EntityId entity, {
    required AbilitySlot slot,
  }) {
    if (!_isAttackOrCastSlot(slot)) return bpScale;
    final modifierIndex = world.statModifier.tryIndexOf(entity);
    if (modifierIndex == null) return bpScale;
    return world.statModifier.actionSpeedBp[modifierIndex];
  }

  bool _isAttackOrCastSlot(AbilitySlot slot) {
    switch (slot) {
      case AbilitySlot.primary:
      case AbilitySlot.secondary:
      case AbilitySlot.projectile:
      case AbilitySlot.spell:
        return true;
      case AbilitySlot.mobility:
      case AbilitySlot.jump:
        return false;
    }
  }

  int _scaleTicksForActionSpeed(int ticks, int actionSpeedBp) {
    if (ticks <= 0) return 0;
    final clampedSpeedBp = clampInt(actionSpeedBp, 1000, 20000);
    if (clampedSpeedBp == bpScale) return ticks;
    return (ticks * bpScale + clampedSpeedBp - 1) ~/ clampedSpeedBp;
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
    required int healthCost100,
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

    // Deduct health (fixed-point) with non-lethal floor.
    if (healthCost100 > 0) {
      final hi = world.health.tryIndexOf(player);
      assert(
        hi != null,
        'Missing HealthStore on $player for healthCost=$healthCost100',
      );
      if (hi != null) {
        final cur = world.health.hp[hi];
        final max = world.health.hpMax[hi];
        final next = clampInt(cur - healthCost100, _minCommitHp100, max);
        world.health.hp[hi] = next;
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
  static const int _minCommitHp100 = 1;

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
    this.pierce,
    this.maxPierceHits,
  });

  final int damageScaleBp;
  final int speedScaleBp;
  final int critBonusBp;
  final bool? pierce;
  final int? maxPierceHits;
}
