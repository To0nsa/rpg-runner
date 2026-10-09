import 'dart:math' as math;

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/control_lock.dart';
import '../../enemies/enemy_id.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../snapshots/enums.dart';
import '../../util/deterministic_rng.dart';
import '../actor_facing.dart';
import '../combat_eligibility.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../world.dart';
import 'ability_interrupt.dart';
import 'boss_combat_system.dart';
import 'enemy_melee_system.dart';
import '../../util/vec2.dart';

/// Goddess uses orbs/claws normally and reserves hands for health thresholds.
final class VoidbornGoddessCombatSystem extends BossCombatSystem {
  VoidbornGoddessCombatSystem({
    required super.tickHz,
    required super.castCommitter,
    required super.utilities,
  });

  @override
  EnemyId get enemyId => EnemyId.voidbornGoddess;
  @override
  // World units: keep the target inside the smaller actor's claw reach.
  double get standOff => 35;
  @override
  double get pursuitSpeedScale => .8;

  static const _clawRange = 45.0;

  @override
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    // Observe crossings even while an action or cooldown delays the next cast.
    final phases = world.goddessHealthPhase;
    for (final boss in world.bossCombat.denseEntities) {
      if (world.enemy.enemyId[world.enemy.indexOf(boss)] != enemyId ||
          !isLivingCombatActor(world, boss) ||
          world.arenaSuspension.has(boss)) {
        continue;
      }
      final hi = world.health.tryIndexOf(boss);
      if (hi == null || world.health.hpMax[hi] <= 0) continue;
      final i = phases.tryIndexOf(boss) ?? phases.addEntity(boss);
      final hp = world.health.hp[hi];
      final maxHp = world.health.hpMax[hi];
      var reached = 0;
      for (var quarter = 3; quarter >= 1; quarter--) {
        if (hp * 4 <= maxHp * quarter) reached++;
      }
      phases.reached[i] = math.max(phases.reached[i], reached);
    }
    super.step(world, player: player, currentTick: currentTick);
  }

  @override
  String selectAbility(
    EcsWorld world,
    EntityId boss, {
    required int sequence,
    required double distanceX,
    required bool atMeleeHeight,
    required int currentTick,
  }) {
    final phases = world.goddessHealthPhase;
    final phase = phases.tryIndexOf(boss);
    if (phase != null && phases.committed[phase] < phases.reached[phase]) {
      return 'goddess.eruption';
    }
    if (distanceX <= _clawRange && atMeleeHeight && sequence % 3 == 0) {
      return 'goddess.claw_combo';
    }
    return 'goddess.orb';
  }

  late final _counterMelee = AiMeleeCommitter(tickHz: tickHz);

  /// Starts a reactive vanish with a checked landing in claw range of the player.
  /// Close attacks cross the player; distant attacks choose either legal side.
  /// Damage middleware cancels the selected attack; this never grants blanket
  /// protection that could erase earlier hits already queued on the same tick.
  bool tryBeginDodge(EcsWorld world, EntityId boss, EntityId player, int tick) {
    final states = world.goddessDodge;
    final i = states.tryIndexOf(boss) ?? states.addEntity(boss);
    if (!isLivingCombatActor(world, boss) ||
        !isLivingCombatActor(world, player) ||
        isCombatProtected(world, boss) ||
        world.goddessBarrage.has(boss) ||
        world.arenaSuspension.has(boss) ||
        states.executeTick[i] >= 0 ||
        world.controlLock.isLocked(boss, LockFlag.strike, tick) ||
        !world.cooldown.has(boss) ||
        !world.meleeIntent.has(boss) ||
        !world.activeAbility.has(boss)) {
      return false;
    }
    final targetX = world.transform.posX[world.transform.indexOf(player)];
    final bossX = world.transform.posX[world.transform.indexOf(boss)];
    var side = 0;
    if ((bossX - targetX).abs() > _clawRange) {
      final left = _dodgePosition(world, boss, player, side: -1);
      final right = _dodgePosition(world, boss, player, side: 1);
      if (left == null && right == null) return false;
      if (left != null && right != null) {
        final roll = nextUint32(states.rngState[i]);
        states.rngState[i] = roll;
        side = roll.isEven ? -1 : 1;
      } else {
        side = left != null ? -1 : 1;
      }
    } else if (_dodgePosition(world, boss, player) == null) {
      return false;
    }
    final ability = AbilityCatalog.shared.resolve('goddess.dodge')!;
    final duration = (ability.activeTicks * tickHz / 60).ceil();
    AbilityInterrupt.clearActiveAndTransient(
      world,
      entity: boss,
      startDeferredCooldown: true,
    );
    world.activeAbility.set(
      boss,
      id: ability.id,
      slot: AbilitySlot.mobility,
      commitTick: tick,
      windupTicks: 0,
      activeTicks: duration,
      recoveryTicks: 1,
      facingDir: actorFacing(world, boss),
    );
    states.startTick[i] = tick;
    states.executeTick[i] = tick + duration;
    states.player[i] = player;
    states.landingSide[i] = side;
    world.controlLock.addLock(
      boss,
      LockFlag.move | LockFlag.jump | LockFlag.nav,
      duration + 1,
      tick,
    );
    return true;
  }

  /// Commits reactive teleports before water/navigation and then ordinary claws.
  void prepareDodge(EcsWorld world, {required int currentTick}) {
    final states = world.goddessDodge;
    for (var i = 0; i < states.denseEntities.length; i++) {
      if (states.executeTick[i] < 0) continue;
      final boss = states.denseEntities[i];
      final player = states.player[i];
      final ai = world.activeAbility.tryIndexOf(boss);
      final current =
          ai != null &&
          world.activeAbility.abilityId[ai] == 'goddess.dodge' &&
          world.activeAbility.startTick[ai] == states.startTick[i];
      if (!current ||
          !isLivingCombatActor(world, boss) ||
          !isLivingCombatActor(world, player) ||
          world.arenaSuspension.has(boss) ||
          world.controlLock.isStunned(boss, currentTick)) {
        _finishDodge(world, boss, i);
        continue;
      }
      final ti = world.transform.indexOf(boss);
      if (currentTick < states.executeTick[i]) {
        world.transform.velX[ti] = 0;
        world.transform.velY[ti] = 0;
        world.gravityControl.setSuppressForTicks(boss, 1);
        continue;
      }
      final position = _dodgePosition(
        world,
        boss,
        player,
        side: states.landingSide[i],
      );
      if (position == null ||
          world.controlLock.isLocked(boss, LockFlag.strike, currentTick)) {
        _finishDodge(world, boss, i);
        continue;
      }
      final targetX = world.transform.posX[world.transform.indexOf(player)];
      final motion = utilities.motion;
      final origin = motion.beginBodyTeleport(world, boss);
      final placed = motion.tryCommitBodyTeleport(
        world,
        boss,
        bodyX: position.x,
        bodyY: position.y,
        facing: targetX >= position.x ? Facing.right : Facing.left,
      );
      _finishDodge(world, boss, i);
      if (!placed) {
        motion.cancelBodyTeleport(world, boss, origin);
        continue;
      }
      // Reactive claws bypass the rotation's cooldown, then retain whichever
      // cooldown is longer so dodging cannot accelerate the next normal cast.
      final remaining = world.cooldown.getTicksLeft(boss, 0);
      world.cooldown.setTicksLeft(boss, 0, 0);
      final committed = _counterMelee.commit(
        world,
        actor: boss,
        abilityId: 'goddess.claw_combo',
        targetX: targetX,
        currentTick: currentTick,
      );
      world.cooldown.startCooldown(boss, 0, remaining);
      if (committed == null) motion.cancelBodyTeleport(world, boss, origin);
    }
  }

  Vec2? _dodgePosition(
    EcsWorld world,
    EntityId boss,
    EntityId player, {
    int side = 0,
  }) {
    final targetX = world.transform.posX[world.transform.indexOf(player)];
    final bossX = world.transform.posX[world.transform.indexOf(boss)];
    final landingSide = side == 0 ? (bossX >= targetX ? -1 : 1) : side;
    final placement = utilities.resolveArenaPlacement(
      world,
      boss,
      enemyId,
      targetX + landingSide * standOff,
    );
    if (placement == null) return null;
    final body = placement.bodyCenter!;
    final x = body.xTicks / terrainPhysicsTicksPerWorldUnit;
    if ((x - targetX) * landingSide <= 0 || (x - targetX).abs() > _clawRange) {
      return null;
    }
    return Vec2(x, body.yTicks / terrainPhysicsTicksPerWorldUnit);
  }

  void _finishDodge(EcsWorld world, EntityId boss, int i) {
    final states = world.goddessDodge;
    final ai = world.activeAbility.tryIndexOf(boss);
    if (ai != null &&
        world.activeAbility.abilityId[ai] == 'goddess.dodge' &&
        world.activeAbility.startTick[ai] == states.startTick[i]) {
      AbilityInterrupt.clearActiveAndTransient(
        world,
        entity: boss,
        startDeferredCooldown: false,
      );
    }
    world.gravityControl.removeEntity(boss);
    states.startTick[i] = -1;
    states.executeTick[i] = -1;
    states.player[i] = -1;
    states.landingSide[i] = 0;
  }

  @override
  void onAbilityCommitted(
    EcsWorld world,
    EntityId boss,
    String abilityId,
    int tick,
  ) {
    if (abilityId != 'goddess.eruption') return;
    // A failed commit never reaches this callback. An interrupted accepted
    // barrage still consumes its threshold rather than casting it twice.
    final phases = world.goddessHealthPhase;
    final phase = phases.tryIndexOf(boss);
    if (phase != null && phases.committed[phase] < phases.reached[phase]) {
      phases.committed[phase]++;
    }
    final boundsIndex = world.actorMotionBounds.tryIndexOf(boss);
    final bounds = boundsIndex == null
        ? null
        : world.actorMotionBounds.bounds[boundsIndex];
    if (bounds == null) return;
    final states = world.goddessBarrage;
    final i = states.addEntity(boss);
    final ti = world.transform.indexOf(boss);
    final ii = world.targetPointIntent.indexOf(boss);
    states.commitTick[i] = tick;
    states.firstHandTick[i] = world.targetPointIntent.tick[ii];
    states.nextHand[i] = 0;
    // Stay aloft through the final hand's full visible impact/recovery.
    states.returnTick[i] =
        states.firstHandTick[i] +
        5 * _handInterval +
        17 * world.targetPointIntent.frameStepTicks[ii];
    states.originX[i] = world.transform.posX[ti];
    states.originY[i] = world.transform.posY[ti];
    states.originFacing[i] = actorFacing(world, boss);
    states.fromLeft[i] =
        world.targetPointIntent.targetX[ii] >=
        (bounds.minXTicks + bounds.maxXTicks) /
            (2 * terrainPhysicsTicksPerWorldUnit);
    states.positioned[i] = false;
    states.hovering[i] = false;
    states.returning[i] = false;
    states.returnDeadlineTick[i] = -1;
    final active = world.activeAbility;
    final ai = active.indexOf(boss);
    active.invulnerable[ai] = true;
    // Animate all thirty casting frames through the final hand's visible end.
    // Keep one recovery tick so prepareBarrage owns the transition to travel.
    active.activeTicks[ai] = states.returnTick[i] - states.firstHandTick[i];
    active.recoveryTicks[ai] = 1;
    active.totalTicks[ai] = states.returnTick[i] - tick + 1;
    // This system schedules all six impacts using the captured cast payload.
    world.targetPointIntent.tick[ii] = -1;
  }

  // 0.35 seconds between fixed marks keeps adjacent warnings overlapping.
  int get _handInterval => (tickHz * .35).ceil();

  /// World units/second: a visible glide across the arena, resolved by terrain.
  static const _returnSpeed = 180.0;

  /// Half a world unit absorbs terrain quantization without a position snap.
  static const _returnArrivalRadius = .5;

  /// Runs before water/navigation so every consumer observes the corner teleport.
  /// Each hand keeps the normal impact executor, warning art and damage clock.
  void prepareBarrage(EcsWorld world, {required int currentTick}) {
    final states = world.goddessBarrage;
    for (final boss in states.denseEntities.toList()) {
      final i = states.indexOf(boss);
      final ai = world.activeAbility.tryIndexOf(boss);
      final living = isLivingCombatActor(world, boss);
      final current =
          living &&
          !world.arenaSuspension.has(boss) &&
          !world.controlLock.isStunned(boss, currentTick) &&
          (states.returning[i]
              ? !world.activeAbility.hasActiveAbility(boss)
              : ai != null &&
                    world.activeAbility.abilityId[ai] == 'goddess.eruption' &&
                    world.activeAbility.startTick[ai] == states.commitTick[i]);
      if (!current) {
        _finishBarrage(world, boss);
        continue;
      }
      if (!states.returning[i] && currentTick >= states.returnTick[i]) {
        world.activeAbility.clear(boss);
        if (!states.hovering[i]) {
          _finishBarrage(world, boss);
          continue;
        }
        states.returning[i] = true;
        // One extra second lets collision/knockback delay arrival without
        // leaving a blocked boss hovering forever or snapping through terrain.
        states.returnDeadlineTick[i] =
            currentTick +
            (_distanceToOrigin(world, boss, i) / _returnSpeed * tickHz).ceil() +
            tickHz;
      }
      if (states.returning[i]) {
        if (_distanceToOrigin(world, boss, i) <= _returnArrivalRadius ||
            currentTick >= states.returnDeadlineTick[i]) {
          setActorFacing(world, boss, states.originFacing[i]);
          _finishBarrage(world, boss);
          continue;
        }
        world.controlLock.addLock(boss, LockFlag.allExceptStun, 1, currentTick);
        continue;
      }
      final bi = world.actorMotionBounds.indexOf(boss);
      final bounds = world.actorMotionBounds.bounds[bi]!;
      final left = bounds.minXTicks / terrainPhysicsTicksPerWorldUnit;
      final right = bounds.maxXTicks / terrainPhysicsTicksPerWorldUnit;
      if (!states.positioned[i]) {
        states.positioned[i] = true;
        for (final fromLeft in [states.fromLeft[i], !states.fromLeft[i]]) {
          if (_teleport(
            world,
            boss,
            fromLeft ? left + 64 : right - 64,
            utilities.groundTopY - 150,
            fromLeft ? Facing.right : Facing.left,
          )) {
            states.hovering[i] = true;
            states.fromLeft[i] = fromLeft;
            break;
          }
        }
      }
      final hand = states.nextHand[i];
      if (hand >= 6 ||
          currentTick != states.firstHandTick[i] + hand * _handInterval) {
        continue;
      }
      states.nextHand[i]++;
      final fraction = (states.fromLeft[i] ? hand : 5 - hand) / 5;
      final x = left + 50 + (right - left - 100) * fraction;
      final surface = castCommitter.surfaceTarget?.call(
        x,
        utilities.groundTopY - 1,
      );
      if (surface == null) continue;
      final intents = world.targetPointIntent;
      final ii = intents.indexOf(boss);
      intents.targetX[ii] = surface.x;
      intents.targetY[ii] = surface.y;
      intents.commitTick[ii] = states.commitTick[i];
      intents.tick[ii] = currentTick;
    }
  }

  /// Locomotion runs first; the terrain authority still integrates this body once.
  void composeMotion(EcsWorld world) {
    final states = world.goddessBarrage;
    for (var i = 0; i < states.denseEntities.length; i++) {
      if (!states.hovering[i]) continue;
      final boss = states.denseEntities[i];
      final ti = world.transform.indexOf(boss);
      if (states.returning[i]) {
        final distance = _distanceToOrigin(world, boss, i);
        final scale = distance > 0
            ? math.min(_returnSpeed / distance, tickHz.toDouble())
            : 0.0;
        final dx = states.originX[i] - world.transform.posX[ti];
        world.transform.velX[ti] = dx * scale;
        world.transform.velY[ti] =
            (states.originY[i] - world.transform.posY[ti]) * scale;
        if (dx.abs() > .5) {
          setActorFacing(world, boss, dx > 0 ? Facing.right : Facing.left);
        }
      } else {
        world.transform.velX[ti] = 0;
        world.transform.velY[ti] = 0;
      }
      world.gravityControl.setSuppressForTicks(boss, 1);
    }
  }

  double _distanceToOrigin(EcsWorld world, EntityId boss, int i) {
    final ti = world.transform.indexOf(boss);
    final dx = world.goddessBarrage.originX[i] - world.transform.posX[ti];
    final dy = world.goddessBarrage.originY[i] - world.transform.posY[ti];
    return math.sqrt(dx * dx + dy * dy);
  }

  void _finishBarrage(EcsWorld world, EntityId boss) {
    final state = world.goddessBarrage.indexOf(boss);
    final ai = world.activeAbility.tryIndexOf(boss);
    if (ai != null &&
        world.activeAbility.abilityId[ai] == 'goddess.eruption' &&
        world.activeAbility.startTick[ai] ==
            world.goddessBarrage.commitTick[state]) {
      AbilityInterrupt.clearActiveAndTransient(
        world,
        entity: boss,
        startDeferredCooldown: true,
      );
    }
    world.gravityControl.removeEntity(boss);
    world.goddessBarrage.removeEntity(boss);
  }

  bool _teleport(
    EcsWorld world,
    EntityId boss,
    double x,
    double y,
    Facing facing,
  ) {
    final motion = utilities.motion;
    final origin = motion.beginBodyTeleport(world, boss);
    if (motion.tryCommitBodyTeleport(
      world,
      boss,
      bodyX: x,
      bodyY: y,
      facing: facing,
    )) {
      return true;
    }
    motion.cancelBodyTeleport(world, boss, origin);
    return false;
  }
}
