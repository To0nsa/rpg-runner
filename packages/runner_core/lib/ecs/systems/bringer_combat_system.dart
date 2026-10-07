import '../../abilities/ability_catalog.dart';
import '../../combat/ai_cast_aim_policy.dart';
import '../../combat/combat_pose_catalog.dart';
import '../../combat/control_lock.dart';
import '../../enemies/enemy_id.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../world.dart';
import 'enemy_cast_system.dart';
import 'enemy_melee_system.dart';

/// Boss attack selection reuses the ordinary committed-action executors.
/// A shared cooldown creates recovery space; neither attack tracks after commit.
final class BringerCombatSystem {
  BringerCombatSystem({
    required this.tickHz,
    required this.castCommitter,
    required this.groundEnemyTuning,
  });
  final int tickHz;
  final AiCastCommitter castCommitter;
  final GroundEnemyTuningDerived groundEnemyTuning;
  late final _melee = AiMeleeCommitter(tickHz: tickHz);

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    for (var ei = 0; ei < world.enemy.denseEntities.length; ei++) {
      if (world.enemy.enemyId[ei] != EnemyId.bringerOfDeath) continue;
      final boss = world.enemy.denseEntities[ei];
      if (world.deathState.has(boss) ||
          world.controlLock.isLocked(boss, LockFlag.allActions, currentTick)) {
        continue;
      }
      final target = combatTarget(world, boss, player);
      if (target == null) continue;
      final ti = world.transform.indexOf(boss);
      final targetTi = world.transform.indexOf(target);
      final targetCenter = aiActorCenter(
        world,
        target,
        fallbackX: world.transform.posX[targetTi],
        fallbackY: world.transform.posY[targetTi],
      );
      final targetX = targetCenter.$1;
      final targetY = targetCenter.$2;
      final ex = world.transform.posX[ti];
      final engagement = world.engagementIntent.indexOf(boss);
      final nav = world.navIntent.indexOf(boss);
      final reach = CombatPoseCatalog.bringerScythe.reach;
      final targetAtMeleeHeight =
          (targetY - world.transform.posY[ti]).abs() <= 42;
      final directApproach =
          world.navIntent.canWalkDirectlyToTarget[nav] && targetAtMeleeHeight;
      final directPlan = directApproach && world.navIntent.hasPlan[nav];
      // A direct walk needs engagement arrival steering, not traversal cruise.
      // Retain its graph-proven safe surface; only transfer speed/spacing control.
      if (directApproach) world.navIntent.hasPlan[nav] = false;
      // Keep the enlarged blade over its target instead of running underneath it.
      final standOff = reach * groundEnemyTuning.engagement.meleeStandOffRatio;
      world.engagementIntent.desiredTargetX[engagement] = directApproach
          ? targetX + (ex >= targetX ? standOff : -standOff)
          : world.navIntent.navTargetX[nav];
      world.engagementIntent.meleeRangeX[engagement] = reach;
      // Direct plans previously used full speed; fallback steering used 0.6.
      // Both actual ground-speed paths increase by 20%.
      world.engagementIntent.speedScale[engagement] = directPlan ? 1.2 : .72;
      world.engagementIntent.arrivalSlowRadiusX[engagement] = 30;
      if (world.activeAbility.hasActiveAbility(boss)) {
        world.controlLock.addLock(
          boss,
          LockFlag.move | LockFlag.jump,
          1,
          currentTick,
        );
        continue;
      }
      if (world.cooldown.isOnCooldown(boss, 0)) continue;
      if ((targetX - ex).abs() <= reach && targetAtMeleeHeight) {
        _melee.commit(
          world,
          actor: boss,
          abilityId: 'bringer.scythe_sweep',
          targetX: targetX,
          currentTick: currentTick,
        );
      } else {
        castCommitter.commit(
          world,
          actor: boss,
          castAbility: AbilityCatalog.shared.resolve('bringer.death_pillar')!,
          sourceX: ex,
          sourceY: world.transform.posY[ti],
          targetX: targetX,
          targetY: targetY,
          targetVelX: 0,
          targetVelY: 0,
          aimPolicy: AiCastAimPolicy.targetCenter,
          currentTick: currentTick,
        );
      }
      if (world.activeAbility.hasActiveAbility(boss)) {
        world.controlLock.addLock(
          boss,
          LockFlag.move | LockFlag.jump,
          1,
          currentTick,
        );
      }
    }
  }
}
