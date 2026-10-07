import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../bosses/boss_utility_delivery.dart';
import '../../combat/ai_cast_aim_policy.dart';
import '../../combat/control_lock.dart';
import '../../enemies/enemy_id.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../world.dart';
import 'boss_utility_system.dart';
import 'enemy_cast_system.dart';
import 'enemy_melee_system.dart';

/// Shared engagement and commit machinery; concrete systems own each boss's kit.
/// State stays per entity. Only matching actors are visited, after engagement and
/// before locomotion. All damage uses the ordinary committed-action executors.
abstract class BossCombatSystem {
  BossCombatSystem({
    required this.tickHz,
    required this.castCommitter,
    required this.utilities,
  });
  final int tickHz;
  final AiCastCommitter castCommitter;
  final BossUtilitySystem utilities;
  late final _melee = AiMeleeCommitter(tickHz: tickHz);
  EnemyId get enemyId;

  /// Desired horizontal spacing in world units on a directly walkable surface.
  double get standOff;
  double get pursuitSpeedScale;

  /// Selects one available action without consuming RNG or mutating shared state.
  /// The sequence advances only after a successful commit.
  String selectAbility(
    EcsWorld world,
    EntityId boss, {
    required int sequence,
    required double distanceX,
    required bool atMeleeHeight,
    required int currentTick,
  });

  /// Updates only this actor's decision state after the executor accepted a cast.
  void onAbilityCommitted(
    EcsWorld world,
    EntityId boss,
    String abilityId,
    int tick,
  ) {}

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    final states = world.bossCombat;
    for (var i = 0; i < states.denseEntities.length; i++) {
      final boss = states.denseEntities[i];
      if (world.enemy.enemyId[world.enemy.indexOf(boss)] != enemyId) continue;
      if (!isLivingCombatActor(world, boss) ||
          world.controlLock.isLocked(boss, LockFlag.allActions, currentTick)) {
        continue;
      }
      final ti = world.transform.indexOf(boss);
      final target = combatTarget(world, boss, player);
      if (target == null) continue;
      final targetTi = world.transform.indexOf(target);
      final targetX = world.transform.posX[targetTi];
      final targetY = world.transform.posY[targetTi];
      final ni = world.navIntent.indexOf(boss);
      final ii = world.engagementIntent.indexOf(boss);
      final direct = world.navIntent.canWalkDirectlyToTarget[ni];
      if (direct) world.navIntent.hasPlan[ni] = false;
      world.engagementIntent.desiredTargetX[ii] = direct
          ? targetX +
                (world.transform.posX[ti] >= targetX ? standOff : -standOff)
          : world.navIntent.navTargetX[ni];
      world.engagementIntent.speedScale[ii] = pursuitSpeedScale;
      world.engagementIntent.arrivalSlowRadiusX[ii] = 30;
      world.engagementIntent.meleeRangeX[ii] = standOff;
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
      final sequence = states.actionIndex[i];
      final dx = (targetX - world.transform.posX[ti]).abs();
      final atHeight = (targetY - world.transform.posY[ti]).abs() <= 50;
      final key = selectAbility(
        world,
        boss,
        sequence: sequence,
        distanceX: dx,
        atMeleeHeight: atHeight,
        currentTick: currentTick,
      );
      final ability = AbilityCatalog.shared.resolve(key)!;
      final bool committed;
      if (ability.hitDelivery is MeleeHitDelivery) {
        committed =
            _melee.commit(
              world,
              actor: boss,
              abilityId: key,
              targetX: targetX,
              currentTick: currentTick,
            ) !=
            null;
      } else if (ability.hitDelivery is BossSummonDelivery ||
          ability.hitDelivery is BossTeleportDelivery) {
        committed = utilities.commit(
          world,
          boss: boss,
          ability: ability,
          targetX: targetX,
          tick: currentTick,
        );
      } else {
        committed = castCommitter.commit(
          world,
          actor: boss,
          castAbility: ability,
          sourceX: world.transform.posX[ti],
          sourceY: world.transform.posY[ti],
          targetX: targetX,
          targetY: targetY,
          targetVelX: 0,
          targetVelY: 0,
          aimPolicy: AiCastAimPolicy.targetCenter,
          casterOriginOffset: 30,
          currentTick: currentTick,
        );
      }
      if (committed) {
        states.actionIndex[i]++;
        onAbilityCommitted(world, boss, key, currentTick);
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
