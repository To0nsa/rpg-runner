import 'dart:math' as math;

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../bosses/boss_utility_delivery.dart';
import '../../combat/ai_cast_aim_policy.dart';
import '../../combat/control_lock.dart';
import '../../combat/shoggoth_pose_catalog.dart';
import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../actor_facing.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../stores/enemies/shoggoth_tactics_store.dart';
import '../world.dart';
import '../world_support_view.dart';
import 'boss_combat_system.dart';
import 'enemy_melee_system.dart';

/// Pursuit, health-triggered swarms and committed charge chains for Shoggoth.
/// Shared executors retain damage, utility placement and terrain authority.
final class ShoggothCombatSystem extends BossCombatSystem {
  ShoggothCombatSystem({
    required super.tickHz,
    required super.castCommitter,
    required super.utilities,
  });

  @override
  EnemyId get enemyId => EnemyId.shoggoth;
  late final _melee = AiMeleeCommitter(tickHz: tickHz);

  // World-unit spacing keeps the native-scale tentacle arcs within body reach.
  static const _standOff = 45.0;
  static const _chargeSpeed = 360.0;

  /// Inspect identity before the phase system clears completed actions. A clear,
  /// replacement, suspension or interruption must never become a queued counter.
  void prepare(EcsWorld world, {required int currentTick}) {
    for (var i = 0; i < world.shoggothTactics.states.length; i++) {
      final boss = world.shoggothTactics.denseEntities[i];
      final s = world.shoggothTactics.states[i];
      if (s.chainStartTick < 0) continue;
      final ai = world.activeAbility.tryIndexOf(boss);
      if (!_available(world, boss, currentTick) ||
          ai == null ||
          world.activeAbility.abilityId[ai] != 'shoggoth.spinning_charge' ||
          world.activeAbility.startTick[ai] != s.chainStartTick) {
        s.clearChain();
      } else if (currentTick == s.chainEndTick) {
        s.returnReadyTick = currentTick;
      } else if (currentTick > s.chainEndTick) {
        s.clearChain();
      }
    }
  }

  bool _available(EcsWorld world, EntityId boss, int tick) =>
      isLivingCombatActor(world, boss) &&
      !world.arenaSuspension.has(boss) &&
      !world.controlLock.isLocked(boss, LockFlag.allActions, tick) &&
      !world.controlLock.isStunned(boss, tick);

  @override
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    for (final boss in world.bossCombat.denseEntities) {
      if (world.enemy.enemyId[world.enemy.indexOf(boss)] != enemyId) continue;
      final s = world.shoggothTactics.stateFor(boss);
      final target = combatTarget(world, boss, player);
      if (!_available(world, boss, currentTick) || target == null) {
        s.clearChain();
        s.separatedSinceTick = -1;
        _hold(world, boss, currentTick);
        continue;
      }
      final hi = world.health.indexOf(boss);
      final hp = world.health.hp[hi];
      final maxHp = world.health.hpMax[hi];
      final reached = hp * 100 <= maxHp * 35
          ? 2
          : hp * 100 <= maxHp * 70
          ? 1
          : 0;
      s.phasesReached = math.max(s.phasesReached, reached);

      final ti = world.transform.indexOf(boss);
      final targetTi = world.transform.indexOf(target);
      final targetX = world.transform.posX[targetTi];
      final dx = targetX - world.transform.posX[ti];
      final atHeight =
          (world.transform.posY[targetTi] - world.transform.posY[ti]).abs() <=
          50;
      final ni = world.navIntent.indexOf(boss);
      final ii = world.engagementIntent.indexOf(boss);
      final direct = world.navIntent.canWalkDirectlyToTarget[ni];
      if (direct) world.navIntent.hasPlan[ni] = false;
      world.engagementIntent.desiredTargetX[ii] = direct
          ? targetX - (dx >= 0 ? _standOff : -_standOff)
          : world.navIntent.navTargetX[ni];
      world.engagementIntent.speedScale[ii] = .8;
      world.engagementIntent.arrivalSlowRadiusX[ii] = 30;
      world.engagementIntent.meleeRangeX[ii] = _standOff;
      final separated = dx.abs() > 300 || !direct;
      s.separatedSinceTick = separated
          ? (s.separatedSinceTick < 0 ? currentTick : s.separatedSinceTick)
          : -1;

      final ai = world.activeAbility.indexOf(boss);
      if (s.returnReadyTick == currentTick) {
        // Only reverse toward a target behind the first pass, with a walkable
        // approach. The second pass is a fresh activation with its full warning.
        final firstDirection = world.activeAbility.facing[ai] == Facing.right
            ? 1.0
            : -1.0;
        s.clearChain();
        if (!world.activeAbility.hasActiveAbility(boss) &&
            direct &&
            atHeight &&
            dx * firstDirection < -20 &&
            dx.abs() <= 260) {
          final remaining = world.cooldown.getTicksLeft(boss, 0);
          world.cooldown.setTicksLeft(boss, 0, 0);
          final committed = _commit(
            world,
            boss,
            target,
            'shoggoth.return_charge',
            currentTick,
          );
          if (!committed) world.cooldown.setTicksLeft(boss, 0, remaining);
        }
      }
      final key = world.activeAbility.abilityId[ai];
      if (key != null) {
        _trackAction(world, boss, target, s, ai, ni, ii, currentTick);
        continue;
      }
      if (world.cooldown.isOnCooldown(boss, 0)) continue;

      String choice;
      if (s.phasesCommitted < s.phasesReached) {
        choice = s.phasesCommitted == 0
            ? 'shoggoth.summon'
            : 'shoggoth.summon_swarm';
      } else if (s.separatedSinceTick >= 0 &&
          currentTick - s.separatedSinceTick >= 3 * tickHz &&
          currentTick >= s.nextTeleportTick) {
        s.nextTeleportTick = currentTick + tickHz;
        if (_commit(world, boss, target, 'shoggoth.teleport', currentTick)) {
          s.nextTeleportTick = currentTick + 8 * tickHz;
          s.separatedSinceTick = -1;
          _hold(world, boss, currentTick);
          continue;
        }
        choice = 'shoggoth.orb';
      } else if (atHeight && direct && dx.abs() <= 70) {
        choice = 'shoggoth.tentacle_sweep';
      } else if (atHeight && direct && dx.abs() <= 260) {
        choice = 'shoggoth.spinning_charge';
      } else {
        choice = 'shoggoth.orb';
      }
      if (!_commit(world, boss, target, choice, currentTick)) continue;
      if (choice == 'shoggoth.summon' || choice == 'shoggoth.summon_swarm') {
        s.phasesCommitted++;
      } else if (choice == 'shoggoth.tentacle_sweep') {
        s.sweepStartTick = currentTick;
        s.sweepApproachX =
            world.transform.posX[ti] +
            dx.sign * math.min(24, math.max(0, dx.abs() - _standOff));
      } else if (choice == 'shoggoth.spinning_charge' && s.phasesReached == 2) {
        // Alternate normal and double passes in the final phase. Each actor's
        // count advances only when its own charge is accepted.
        if (s.frenzyCharges++ % 2 == 0) {
          s.chainStartTick = currentTick;
          s.chainEndTick = currentTick + world.activeAbility.totalTicks[ai];
        }
      }
      _trackAction(world, boss, target, s, ai, ni, ii, currentTick);
    }
  }

  void _trackAction(
    EcsWorld world,
    EntityId boss,
    EntityId target,
    ShoggothTactics s,
    int ai,
    int ni,
    int ii,
    int tick,
  ) {
    final active = world.activeAbility;
    final key = active.abilityId[ai];
    final elapsed = tick - active.startTick[ai];
    final ti = world.transform.indexOf(boss);
    final dx =
        world.transform.posX[world.transform.indexOf(target)] -
        world.transform.posX[ti];
    final windup = elapsed < active.windupTicks[ai];
    final attacking = elapsed < active.windupTicks[ai] + active.activeTicks[ai];
    var canTurn = false;
    if (key == 'shoggoth.tentacle_sweep' && attacking) {
      final profile = ShoggothPoseCatalog.shoggothSweep;
      int frameAt(int age) => profile.timing.frameAt(
        elapsed: age,
        windup: active.windupTicks[ai],
        active: active.activeTicks[ai],
        recovery: active.recoveryTicks[ai],
      );
      final frame = frameAt(elapsed);
      final previous = frameAt(math.max(0, elapsed - 1));
      canTurn =
          profile.frames[frame].isEmpty ||
          profile.combo!.strikeWindowAt(frame) !=
              profile.combo!.strikeWindowAt(previous);
    } else if (_isCharge(key)) {
      canTurn = windup;
    }
    if (canTurn && dx.abs() > 2) {
      active.facing[ai] = dx > 0 ? Facing.right : Facing.left;
      world.meleeIntent.dirX[world.meleeIntent.indexOf(boss)] = dx.sign;
    }
    if (key == 'shoggoth.tentacle_sweep' || _isCharge(key)) {
      setActorFacing(world, boss, active.facing[ai]);
    }
    final direction = active.facing[ai] == Facing.right ? 1.0 : -1.0;
    if (key == 'shoggoth.tentacle_sweep' &&
        windup &&
        s.sweepStartTick == active.startTick[ai] &&
        world.navIntent.canWalkDirectlyToTarget[ni] &&
        WorldSupportView(world).isGrounded(boss) &&
        dx * direction > _standOff &&
        (s.sweepApproachX - world.transform.posX[ti]) * direction > 0) {
      final remaining = math.min(
        (s.sweepApproachX - world.transform.posX[ti]).abs(),
        dx.abs() - _standOff,
      );
      world.engagementIntent.desiredTargetX[ii] =
          world.transform.posX[ti] + direction * remaining;
      world.engagementIntent.speedScale[ii] = .5;
      world.engagementIntent.arrivalSlowRadiusX[ii] = 0;
      world.controlLock.addLock(boss, LockFlag.jump, 1, tick);
    } else {
      _hold(world, boss, tick);
    }
  }

  bool _isCharge(String? key) =>
      key == 'shoggoth.spinning_charge' || key == 'shoggoth.return_charge';

  void _hold(EcsWorld world, EntityId boss, int tick) {
    world.controlLock.addLock(boss, LockFlag.move | LockFlag.jump, 1, tick);
  }

  bool _commit(
    EcsWorld world,
    EntityId boss,
    EntityId target,
    String key,
    int tick,
  ) {
    final ti = world.transform.indexOf(boss);
    final targetTi = world.transform.indexOf(target);
    final targetX = world.transform.posX[targetTi];
    final ability = AbilityCatalog.shared.resolve(key)!;
    final bool committed;
    if (ability.hitDelivery is MeleeHitDelivery) {
      committed =
          _melee.commit(
            world,
            actor: boss,
            abilityId: key,
            targetX: targetX,
            currentTick: tick,
          ) !=
          null;
    } else if (ability.hitDelivery is BossSummonDelivery ||
        ability.hitDelivery is BossTeleportDelivery) {
      committed = utilities.commit(
        world,
        boss: boss,
        ability: ability,
        targetX: targetX,
        tick: tick,
      );
    } else {
      committed = castCommitter.commit(
        world,
        actor: boss,
        castAbility: ability,
        sourceX: world.transform.posX[ti],
        sourceY: world.transform.posY[ti],
        targetX: targetX,
        targetY: world.transform.posY[targetTi],
        targetVelX: 0,
        targetVelY: 0,
        aimPolicy: AiCastAimPolicy.targetCenter,
        casterOriginOffset: 30,
        currentTick: tick,
      );
    }
    if (committed) {
      world.bossCombat.actionIndex[world.bossCombat.indexOf(boss)]++;
    }
    return committed;
  }

  /// Preserve strike facing after locomotion, then compose horizontal motion
  /// before knockback, gravity and the single terrain integration.
  void composeMotion(EcsWorld world, {required int currentTick}) {
    for (final boss in world.bossCombat.denseEntities) {
      if (world.enemy.enemyId[world.enemy.indexOf(boss)] != enemyId ||
          !_available(world, boss, currentTick)) {
        continue;
      }
      final ai = world.activeAbility.indexOf(boss);
      final key = world.activeAbility.abilityId[ai];
      if (key != 'shoggoth.tentacle_sweep' && !_isCharge(key)) continue;
      final facing = world.activeAbility.facing[ai];
      setActorFacing(world, boss, facing);
      final ti = world.transform.indexOf(boss);
      if (_isCharge(key) &&
          world.activeAbility.phase[ai] == AbilityPhase.active) {
        world.transform.velX[ti] = facing == Facing.left
            ? -_chargeSpeed
            : _chargeSpeed;
      } else if (key == 'shoggoth.tentacle_sweep') {
        final ii = world.engagementIntent.indexOf(boss);
        final dx =
            world.engagementIntent.desiredTargetX[ii] -
            world.transform.posX[ti];
        final vx = world.transform.velX[ti];
        final capped = vx.sign == dx.sign
            ? dx.sign * math.min(vx.abs(), dx.abs() * tickHz)
            : 0.0;
        world.transform.velX[ti] = capped;
        if (vx != 0 && WorldSupportView(world).isGrounded(boss)) {
          world.transform.velY[ti] *= capped / vx;
        }
      }
    }
  }
}
