import '../../combat/control_lock.dart';
import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/ai_cast_aim_policy.dart';
import '../../npcs/npc_catalog.dart';
import '../../projectiles/projectile_catalog.dart';
import '../combat_target.dart';
import '../world.dart';
import '../world_support_view.dart';
import 'enemy_melee_system.dart';
import 'enemy_cast_system.dart';
import 'ground_enemy_locomotion_system.dart';

/// Encounter allies consume selected targets and shared terrain navigation.
final class NpcAiSystem {
  NpcAiSystem({
    required int tickHz,
    required this.locomotion,
    this.catalog = const NpcCatalog(),
  }) : melee = AiMeleeCommitter(tickHz: tickHz),
       casts = AiCastCommitter(
         tickHz: tickHz,
         projectiles: const ProjectileCatalog(),
       );
  final GroundEnemyLocomotionSystem locomotion;
  final NpcCatalog catalog;
  final AiMeleeCommitter melee;
  final AiCastCommitter casts;

  void step(
    EcsWorld world, {
    required int currentTick,
    required double dtSeconds,
  }) {
    final support = WorldSupportView(world);
    for (var i = 0; i < world.npc.denseEntities.length; i++) {
      final actor = world.npc.denseEntities[i];
      final ti = world.transform.tryIndexOf(actor);
      if (ti == null) continue;
      final grounded = support.isGrounded(actor);
      final target = world.aiTarget.has(actor)
          ? combatTarget(world, actor, -1)
          : null;
      if (!isLivingCombatActor(world, actor) ||
          target == null ||
          world.controlLock.isStunned(actor, currentTick)) {
        world.transform.velX[ti] = 0;
        if (grounded) world.transform.velY[ti] = 0;
        continue;
      }
      final archetype = catalog.get(world.npc.npcId[i]);
      final targetTi = world.transform.indexOf(target);
      final targetX = world.transform.posX[targetTi];
      final x = world.transform.posX[ti];
      final ability = AbilityCatalog.shared.resolve(archetype.attackAbilityId)!;
      final ranged = ability.hitDelivery is ProjectileHitDelivery;
      final targetCenter = aiActorCenter(
        world,
        target,
        fallbackX: targetX,
        fallbackY: world.transform.posY[targetTi],
      );
      final sourceCenter = aiActorCenter(
        world,
        actor,
        fallbackX: x,
        fallbackY: world.transform.posY[ti],
      );
      final dx = targetCenter.$1 - sourceCenter.$1;
      final dy = targetCenter.$2 - sourceCenter.$2;
      final inRange = ranged
          ? dx * dx + dy * dy <= archetype.attackRange * archetype.attackRange
          : (targetX - x).abs() <= archetype.attackRange &&
                (world.transform.posY[targetTi] - world.transform.posY[ti])
                        .abs() <=
                    archetype.collider.halfY;
      if (inRange) {
        if (ranged) {
          casts.commit(
            world,
            actor: actor,
            castAbility: ability,
            sourceX: sourceCenter.$1,
            sourceY: sourceCenter.$2,
            targetX: targetCenter.$1,
            targetY: targetCenter.$2,
            targetVelX: world.transform.velX[targetTi],
            targetVelY: world.transform.velY[targetTi],
            aimPolicy: AiCastAimPolicy.predictedTargetCenter,
            casterOriginOffset: archetype.castOriginOffset,
            casterOriginOffsetY: archetype.castOriginOffsetY,
            currentTick: currentTick,
          );
        } else {
          melee.commit(
            world,
            actor: actor,
            abilityId: archetype.attackAbilityId,
            targetX: targetX,
            currentTick: currentTick,
          );
        }
      }
      if (world.activeAbility.hasActiveAbility(actor) ||
          inRange ||
          world.controlLock.isLocked(actor, LockFlag.move, currentTick)) {
        if (grounded) {
          world.transform.velX[ti] = 0;
          world.transform.velY[ti] = 0;
        }
        continue;
      }
      final nav = world.navIntent.indexOf(actor);
      final intents = world.navIntent;
      final margin =
          archetype.collider.halfX + archetype.collider.offsetX.abs();
      final minimum = world.npc.minX[i] + margin;
      final maximum = world.npc.maxX[i] - margin;
      final desired = intents.desiredX[nav].clamp(minimum, maximum);
      if (world.swimState.isSwimming(actor)) {
        final engagement = world.engagementIntent.indexOf(actor);
        world.engagementIntent.desiredTargetX[engagement] = desired;
        world.engagementIntent.speedScale[engagement] = 1;
        world.engagementIntent.stateSpeedMul[engagement] = 1;
        world.engagementIntent.arrivalSlowRadiusX[engagement] = 0;
        locomotion.swimToward(
          world,
          enemy: actor,
          enemyTi: ti,
          engagementIndex: engagement,
          target: target,
          targetTi: targetTi,
          currentTick: currentTick,
          dtSeconds: dtSeconds,
          speedX: archetype.speedX,
        );
        continue;
      }
      locomotion.applyGroundMotion(
        world,
        actor: actor,
        enemyTi: ti,
        navIntentIndex: nav,
        ex: x,
        desiredX: desired,
        jumpNow:
            intents.jumpNow[nav] &&
            grounded &&
            !world.controlLock.isLocked(actor, LockFlag.jump, currentTick),
        hasPlan: intents.hasPlan[nav],
        commitMoveDirX: intents.commitMoveDirX[nav],
        hasSafeSurface: true,
        safeSurfaceMinX: intents.hasSafeSurface[nav]
            ? intents.safeSurfaceMinX[nav].clamp(minimum, maximum)
            : minimum,
        safeSurfaceMaxX: intents.hasSafeSurface[nav]
            ? intents.safeSurfaceMaxX[nav].clamp(minimum, maximum)
            : maximum,
        effectiveSpeedScale: 1,
        arrivalSlowRadiusX: 0,
        stateSpeedMul: 1,
        lockFacingToTarget: false,
        grounded: grounded,
        dtSeconds: dtSeconds,
        targetX: targetX,
        speedX: archetype.speedX,
        jumpSpeed: archetype.jumpSpeed,
      );
    }
  }
}
