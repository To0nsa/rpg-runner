import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/control_lock.dart';
import '../../snapshots/enums.dart';
import '../../util/ability_timing.dart';
import '../../util/target_prediction.dart';
import '../entity_id.dart';
import '../stores/enemies/hashash_teleport_state_store.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

/// Resolves Hashash teleport-out transitions into teleport-in ambush commits.
class HashashTeleportAmbushSystem {
  HashashTeleportAmbushSystem({
    required this.tickHz,
    this.abilityResolver = AbilityCatalog.shared,
    this.ambushAbilityId = 'hashash.ambush',
    this.ambushRightOffsetX = 36.0,
    this.ambushDropHeightY = 36.0,
  }) : assert(tickHz > 0, 'tickHz must be > 0.'),
       assert(ambushRightOffsetX >= 0.0, 'ambushRightOffsetX must be >= 0.'),
       assert(ambushDropHeightY >= 0.0, 'ambushDropHeightY must be >= 0.');

  static const int _ambushLockMask = LockFlag.allExceptStun;

  final int tickHz;
  final AbilityResolver abilityResolver;
  final AbilityKey ambushAbilityId;
  final double ambushRightOffsetX;
  final double ambushDropHeightY;

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.transform.has(player)) return;

    final playerTransformIndex = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTransformIndex];
    final playerY = world.transform.posY[playerTransformIndex];
    final playerVelX = world.transform.velX[playerTransformIndex];
    final playerVelY = world.transform.velY[playerTransformIndex];

    final teleport = world.hashashTeleport;
    for (var i = 0; i < teleport.denseEntities.length; i += 1) {
      final enemy = teleport.denseEntities[i];
      if (world.deathState.has(enemy)) {
        teleport.phase[i] = HashashTeleportPhase.idle;
        teleport.phaseEndTick[i] = -1;
        continue;
      }

      final phase = teleport.phase[i];
      if (phase == HashashTeleportPhase.idle) continue;

      final transformIndex = world.transform.tryIndexOf(enemy);
      final enemyIndex = world.enemy.tryIndexOf(enemy);
      if (transformIndex == null || enemyIndex == null) continue;

      // Keep teleporting Hashash stationary during teleport-out.
      //
      // During ambush we keep horizontal stillness but let gravity affect velY
      // so he can visually "drop in" from above the player.
      world.transform.velX[transformIndex] = 0.0;
      if (phase == HashashTeleportPhase.evadeOut) {
        world.transform.velY[transformIndex] = 0.0;
      }

      if (phase == HashashTeleportPhase.evadeOut) {
        if (currentTick < teleport.phaseEndTick[i]) continue;

        final ambushAbility = abilityResolver.resolve(ambushAbilityId);
        if (ambushAbility == null) {
          teleport.phase[i] = HashashTeleportPhase.idle;
          teleport.phaseEndTick[i] = -1;
          continue;
        }

        final windupTicks = _scaleAbilityTicks(ambushAbility.windupTicks);
        final activeTicks = _scaleAbilityTicks(ambushAbility.activeTicks);
        final recoveryTicks = _scaleAbilityTicks(ambushAbility.recoveryTicks);
        final totalTicks = max(1, windupTicks + activeTicks + recoveryTicks);
        final cooldownTicks = _scaleAbilityTicks(ambushAbility.cooldownTicks);
        final leadSeconds = windupTicks / tickHz;
        final predictedPlayer = predictLinearTargetPosition(
          targetX: playerX,
          targetY: playerY,
          targetVelX: playerVelX,
          targetVelY: playerVelY,
          leadSeconds: leadSeconds,
        );

        final ambushX = predictedPlayer.$1 + ambushRightOffsetX;
        final ambushY = predictedPlayer.$2 - ambushDropHeightY;
        world.transform.posX[transformIndex] = ambushX;
        world.transform.posY[transformIndex] = ambushY;

        final facing = predictedPlayer.$1 >= ambushX
            ? Facing.right
            : Facing.left;
        world.enemy.facing[enemyIndex] = facing;

        _queueAmbushStrike(
          world,
          enemy: enemy,
          enemyTransformIndex: transformIndex,
          ability: ambushAbility,
          commitTick: currentTick,
          windupTicks: windupTicks,
          activeTicks: activeTicks,
          recoveryTicks: recoveryTicks,
          cooldownTicks: cooldownTicks,
          facing: facing,
        );

        world.controlLock.addLock(
          enemy,
          _ambushLockMask,
          totalTicks,
          currentTick,
        );
        teleport.phase[i] = HashashTeleportPhase.ambush;
        teleport.phaseEndTick[i] = currentTick + totalTicks;
        teleport.cooldownUntilTick[i] =
            currentTick + totalTicks + cooldownTicks;
        continue;
      }

      if (phase == HashashTeleportPhase.ambush &&
          currentTick >= teleport.phaseEndTick[i]) {
        teleport.phase[i] = HashashTeleportPhase.idle;
        teleport.phaseEndTick[i] = -1;
      }
    }
  }

  void _queueAmbushStrike(
    EcsWorld world, {
    required EntityId enemy,
    required int enemyTransformIndex,
    required AbilityDef ability,
    required int commitTick,
    required int windupTicks,
    required int activeTicks,
    required int recoveryTicks,
    required int cooldownTicks,
    required Facing facing,
  }) {
    if (!world.meleeIntent.has(enemy)) return;
    if (!world.colliderAabb.has(enemy)) return;

    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is! MeleeHitDelivery) return;

    final cooldownGroupId = ability.effectiveCooldownGroup(AbilitySlot.primary);
    if (world.cooldown.has(enemy)) {
      world.cooldown.startCooldown(enemy, cooldownGroupId, cooldownTicks);
    }

    final dirX = facing == Facing.right ? 1.0 : -1.0;
    final halfX = hitDelivery.sizeX * 0.5;
    final halfY = hitDelivery.sizeY * 0.5;

    final colliderIndex = world.colliderAabb.indexOf(enemy);
    final ownerHalfX = world.colliderAabb.halfX[colliderIndex];
    final ownerHalfY = world.colliderAabb.halfY[colliderIndex];
    final maxHalfExtent = max(ownerHalfX, ownerHalfY);
    final forward =
        maxHalfExtent * 0.5 + max(halfX, halfY) + hitDelivery.offsetX;
    final offsetX = dirX * forward;
    final offsetY = hitDelivery.offsetY;

    world.meleeIntent.set(
      enemy,
      MeleeIntentDef(
        abilityId: ability.id,
        slot: AbilitySlot.primary,
        damage100: ability.baseDamage,
        critChanceBp: 0,
        damageType: ability.baseDamageType,
        procs: ability.procs,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
        dirX: dirX,
        dirY: 0.0,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownTicks: cooldownTicks,
        staminaCost100: 0,
        cooldownGroupId: cooldownGroupId,
        tick: commitTick + windupTicks,
      ),
    );

    world.activeAbility.set(
      enemy,
      id: ability.id,
      slot: AbilitySlot.primary,
      commitTick: commitTick,
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      recoveryTicks: recoveryTicks,
      facingDir: facing,
      cooldownGroupId: cooldownGroupId,
      cooldownTicks: cooldownTicks,
    );

    world.transform.velX[enemyTransformIndex] = 0.0;
    world.transform.velY[enemyTransformIndex] = 0.0;
  }

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (tickHz == abilityAuthoringTickHz) return ticks;
    final seconds = ticks / abilityAuthoringTickHz;
    return (seconds * tickHz).ceil();
  }
}
