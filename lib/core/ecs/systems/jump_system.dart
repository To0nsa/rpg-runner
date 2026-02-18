import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/control_lock.dart';
import '../../util/fixed_math.dart';
import '../../players/player_tuning.dart';
import '../entity_id.dart';
import '../stores/mobility_intent_store.dart';
import '../stores/player/jump_state_store.dart';
import '../world.dart';

/// Executes buffered jump intents with coyote-time and air-jump rules.
///
/// Ground jumps and air jumps may have different resource costs:
/// - Ground jump uses [AbilityDef.defaultCost]
/// - Air jump uses [AbilityDef.airJumpCost]
class JumpSystem {
  JumpSystem({required this.abilities});

  final AbilityResolver abilities;

  void step(
    EcsWorld world,
    MovementTuningDerived tuning, {
    required int currentTick,
  }) {
    final jumpState = world.jumpState;
    final entities = jumpState.denseEntities;
    for (var ji = 0; ji < entities.length; ji += 1) {
      final entity = entities[ji];

      final mi = world.movement.tryIndexOf(entity);
      final ti = world.transform.tryIndexOf(entity);
      final bi = world.body.tryIndexOf(entity);
      final ci = world.collision.tryIndexOf(entity);
      if (mi == null || ti == null || bi == null || ci == null) continue;
      if (!world.body.enabled[bi] || world.body.isKinematic[bi]) continue;

      _tickForgivenessState(
        world,
        jumpState: jumpState,
        jumpStateIndex: ji,
        collisionIndex: ci,
        tuning: tuning,
      );

      final intentIndex = _jumpIntentIndex(world, entity);
      final hasJumpIntent = intentIndex != null;
      if (hasJumpIntent &&
          world.mobilityIntent.commitTick[intentIndex] == currentTick) {
        jumpState.jumpBufferTicksLeft[ji] = tuning.jumpBufferTicks;
      }

      if (jumpState.jumpBufferTicksLeft[ji] <= 0) {
        if (hasJumpIntent) {
          _invalidateIntent(world.mobilityIntent, intentIndex);
        }
        continue;
      }

      if (world.controlLock.isLocked(entity, LockFlag.jump, currentTick)) {
        continue;
      }

      if (!hasJumpIntent) {
        continue;
      }

      final intent = world.mobilityIntent;
      final ability = abilities.resolve(intent.abilityId[intentIndex]);
      if (ability == null) {
        _invalidateIntent(intent, intentIndex);
        jumpState.jumpBufferTicksLeft[ji] = 0;
        continue;
      }

      final canGroundJump =
          world.collision.grounded[ci] || jumpState.coyoteTicksLeft[ji] > 0;
      final canAirJump =
          !canGroundJump && jumpState.airJumpsUsed[ji] < ability.maxAirJumps;
      if (!canGroundJump && !canAirJump) {
        continue;
      }

      final jumpCost = canGroundJump
          ? ability.defaultCost
          : ability.airJumpCost;
      if (!_canAffordJumpCost(world, entity: entity, cost: jumpCost)) {
        continue;
      }

      _payJumpCost(world, entity: entity, cost: jumpCost);
      final jumpSpeedY = canGroundJump
          ? (ability.groundJumpSpeedY ?? tuning.base.jumpSpeed)
          : (ability.airJumpSpeedY ??
                ability.groundJumpSpeedY ??
                tuning.base.jumpSpeed);
      world.transform.velY[ti] = -jumpSpeedY;
      jumpState.jumpBufferTicksLeft[ji] = 0;
      jumpState.coyoteTicksLeft[ji] = 0;
      if (!canGroundJump) {
        jumpState.airJumpsUsed[ji] += 1;
      }

      _invalidateIntent(intent, intentIndex);
      _stampActiveJumpAbility(
        world,
        entity: entity,
        movementIndex: mi,
        intentIndex: intentIndex,
        currentTick: currentTick,
      );
      _startJumpCooldown(world, entity: entity, intentIndex: intentIndex);
    }
  }

  void _tickForgivenessState(
    EcsWorld world, {
    required JumpStateStore jumpState,
    required int jumpStateIndex,
    required int collisionIndex,
    required MovementTuningDerived tuning,
  }) {
    if (jumpState.jumpBufferTicksLeft[jumpStateIndex] > 0) {
      jumpState.jumpBufferTicksLeft[jumpStateIndex] -= 1;
    }

    final grounded = world.collision.grounded[collisionIndex];
    if (grounded) {
      jumpState.coyoteTicksLeft[jumpStateIndex] = tuning.coyoteTicks;
      jumpState.airJumpsUsed[jumpStateIndex] = 0;
    } else if (jumpState.coyoteTicksLeft[jumpStateIndex] > 0) {
      jumpState.coyoteTicksLeft[jumpStateIndex] -= 1;
    }
  }

  int? _jumpIntentIndex(EcsWorld world, EntityId entity) {
    final intentIndex = world.mobilityIntent.tryIndexOf(entity);
    if (intentIndex == null) return null;
    return world.mobilityIntent.slot[intentIndex] == AbilitySlot.jump
        ? intentIndex
        : null;
  }

  bool _canAffordJumpCost(
    EcsWorld world, {
    required EntityId entity,
    required AbilityResourceCost cost,
  }) {
    if (cost.staminaCost100 > 0) {
      final staminaIndex = world.stamina.tryIndexOf(entity);
      if (staminaIndex == null ||
          world.stamina.stamina[staminaIndex] < cost.staminaCost100) {
        return false;
      }
    }
    if (cost.manaCost100 > 0) {
      final manaIndex = world.mana.tryIndexOf(entity);
      if (manaIndex == null || world.mana.mana[manaIndex] < cost.manaCost100) {
        return false;
      }
    }
    if (cost.healthCost100 > 0) {
      final healthIndex = world.health.tryIndexOf(entity);
      if (healthIndex == null) return false;
      if (world.health.hp[healthIndex] - cost.healthCost100 < _minCommitHp100) {
        return false;
      }
    }
    return true;
  }

  void _payJumpCost(
    EcsWorld world, {
    required EntityId entity,
    required AbilityResourceCost cost,
  }) {
    if (cost.staminaCost100 > 0) {
      final staminaIndex = world.stamina.tryIndexOf(entity);
      if (staminaIndex != null) {
        final current = world.stamina.stamina[staminaIndex];
        final max = world.stamina.staminaMax[staminaIndex];
        world.stamina.stamina[staminaIndex] = clampInt(
          current - cost.staminaCost100,
          0,
          max,
        );
      }
    }
    if (cost.manaCost100 > 0) {
      final manaIndex = world.mana.tryIndexOf(entity);
      if (manaIndex != null) {
        final current = world.mana.mana[manaIndex];
        final max = world.mana.manaMax[manaIndex];
        world.mana.mana[manaIndex] = clampInt(
          current - cost.manaCost100,
          0,
          max,
        );
      }
    }
    if (cost.healthCost100 > 0) {
      final healthIndex = world.health.tryIndexOf(entity);
      if (healthIndex != null) {
        final current = world.health.hp[healthIndex];
        final max = world.health.hpMax[healthIndex];
        world.health.hp[healthIndex] = clampInt(
          current - cost.healthCost100,
          _minCommitHp100,
          max,
        );
      }
    }
  }

  void _stampActiveJumpAbility(
    EcsWorld world, {
    required EntityId entity,
    required int movementIndex,
    required int intentIndex,
    required int currentTick,
  }) {
    if (!world.activeAbility.has(entity)) return;
    final intent = world.mobilityIntent;
    world.activeAbility.set(
      entity,
      id: intent.abilityId[intentIndex],
      slot: intent.slot[intentIndex],
      commitTick: currentTick,
      windupTicks: intent.windupTicks[intentIndex],
      activeTicks: intent.activeTicks[intentIndex],
      recoveryTicks: intent.recoveryTicks[intentIndex],
      facingDir: world.movement.facing[movementIndex],
      cooldownGroupId: intent.cooldownGroupId[intentIndex],
      cooldownTicks: intent.cooldownTicks[intentIndex],
      cooldownStarted: intent.cooldownTicks[intentIndex] > 0,
    );
  }

  void _startJumpCooldown(
    EcsWorld world, {
    required EntityId entity,
    required int intentIndex,
  }) {
    final cooldownTicks = world.mobilityIntent.cooldownTicks[intentIndex];
    if (cooldownTicks <= 0) return;
    world.cooldown.startCooldown(
      entity,
      world.mobilityIntent.cooldownGroupId[intentIndex],
      cooldownTicks,
    );
  }

  void _invalidateIntent(MobilityIntentStore intent, int index) {
    intent.tick[index] = -1;
    intent.commitTick[index] = -1;
  }

  static const int _minCommitHp100 = 1;
}
