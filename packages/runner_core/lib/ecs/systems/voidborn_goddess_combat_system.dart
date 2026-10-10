import 'dart:math' as math;

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/control_lock.dart';
import '../../enemies/enemy_id.dart';
import '../../events/game_event.dart';
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
import 'enemy_cast_system.dart';
import 'enemy_melee_system.dart';
import 'goddess_tactics_system.dart';
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
  static const _clawRange = 45.0;
  late final _tactics = GoddessTacticsSystem(
    tickHz: tickHz,
    casts: castCommitter,
    utilities: utilities,
    onBarrage: _beginBarrage,
  );

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
      _tactics.step(world, boss, player, currentTick);
    }
  }

  /// Advances readable repositioning before navigation and water observe it.
  void prepareTactics(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    _tactics.prepare(world, player, currentTick);
  }

  /// After movement and self abilities, face the current target and refresh this
  /// activation's pending orb. Turning preserves cast timing; released orbs keep
  /// their direction. Call immediately before projectile launch.
  void refreshOrbCast(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    for (final boss in world.bossCombat.denseEntities) {
      if (world.enemy.enemyId[world.enemy.indexOf(boss)] != enemyId) continue;
      final intents = world.projectileIntent;
      final pi = intents.indexOf(boss);
      final active = world.activeAbility;
      final ai = active.indexOf(boss);
      final target = combatTarget(world, boss, player);
      final casting =
          active.abilityId[ai] == 'goddess.orb' &&
          isLivingCombatActor(world, boss) &&
          !world.arenaSuspension.has(boss) &&
          !world.controlLock.isLocked(boss, LockFlag.allActions, currentTick) &&
          !world.controlLock.isStunned(boss, currentTick) &&
          target != null;
      final pending =
          intents.abilityId[pi] == 'goddess.orb' && intents.tick[pi] >= 0;
      if (pending &&
          (!casting || intents.commitTick[pi] != active.startTick[ai])) {
        intents.tick[pi] = -1;
        intents.commitTick[pi] = -1;
      }
      if (!casting) continue;
      final ti = world.transform.indexOf(boss);
      final targetTi = world.transform.indexOf(target);
      final center = aiActorCenter(
        world,
        target,
        fallbackX: world.transform.posX[targetTi],
        fallbackY: world.transform.posY[targetTi],
      );
      final dx = center.$1 - world.transform.posX[ti];
      // Match claw/Shoggoth tracking without jitter when bodies overlap.
      if (dx.abs() > 2) {
        active.facing[ai] = dx > 0 ? Facing.right : Facing.left;
      }
      final facing = active.facing[ai];
      setActorFacing(world, boss, facing);
      if (intents.tick[pi] < currentTick ||
          intents.abilityId[pi] != 'goddess.orb' ||
          intents.commitTick[pi] != active.startTick[ai]) {
        continue;
      }
      intents.dirX[pi] =
          center.$1 - world.transform.posX[ti] - intents.sourceOffsetX[pi];
      intents.dirY[pi] =
          center.$2 - world.transform.posY[ti] - intents.sourceOffsetY[pi];
      intents.fallbackDirX[pi] = facing == Facing.left ? -1 : 1;
      intents.fallbackDirY[pi] = 0;
    }
  }

  late final _counterMelee = AiMeleeCommitter(tickHz: tickHz);

  /// Observes positive HP loss after damage interrupts, so both projectiles land
  /// before the second triggers a counter. Direct melee/spell hits break the
  /// streak; DoT and NPC damage do not affect it. Blocked placement stays ready.
  void onDamageApplied(
    EcsWorld world, {
    required EntityId target,
    required EntityId? source,
    required DeathSourceKind sourceKind,
    required int currentTick,
  }) {
    final ei = world.enemy.tryIndexOf(target);
    if (ei == null ||
        world.enemy.enemyId[ei] != enemyId ||
        source == null ||
        !world.playerInput.has(source) ||
        !isLivingCombatActor(world, target) ||
        !isLivingCombatActor(world, source)) {
      return;
    }
    if (sourceKind != DeathSourceKind.projectile &&
        sourceKind != DeathSourceKind.meleeHitbox &&
        sourceKind != DeathSourceKind.spellImpact) {
      return;
    }
    final state = world.goddessDodge;
    final i = state.tryIndexOf(target) ?? state.addEntity(target);
    if (state.executeTick[i] >= 0 ||
        world.goddessBarrage.has(target) ||
        _hasScriptedTransition(world, target) ||
        world.arenaSuspension.has(target) ||
        world.controlLock.isStunned(target, currentTick)) {
      return;
    }
    if (sourceKind != DeathSourceKind.projectile) {
      state.consecutiveProjectileHits[i] = 0;
      return;
    }
    // Two landed projectiles force a response to sustained ranged pressure.
    state.consecutiveProjectileHits[i] = math.min(
      2,
      state.consecutiveProjectileHits[i] + 1,
    );
    if (state.consecutiveProjectileHits[i] == 2 &&
        tryBeginDodge(world, target, source, currentTick)) {
      state.resetAfterDodge(i);
    }
  }

  /// Starts a reactive vanish with a checked landing in claw range of the player.
  /// Close attacks cross the player; distant attacks choose either legal side.
  /// Only the cadence middleware cancels its selected attack; a post-hit counter
  /// accepts both hits. Neither trigger grants blanket protection.
  bool tryBeginDodge(EcsWorld world, EntityId boss, EntityId player, int tick) {
    final states = world.goddessDodge;
    final i = states.tryIndexOf(boss) ?? states.addEntity(boss);
    if (!isLivingCombatActor(world, boss) ||
        !isLivingCombatActor(world, player) ||
        isCombatProtected(world, boss) ||
        world.goddessBarrage.has(boss) ||
        _hasScriptedTransition(world, boss) ||
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
      if (committed == null) {
        motion.cancelBodyTeleport(world, boss, origin);
      } else {
        _tactics.didDodge(world, boss, currentTick);
      }
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
      targetX + landingSide * 35,
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

  bool _hasScriptedTransition(EcsWorld world, EntityId boss) {
    final i = world.goddessTactics.tryIndexOf(boss);
    if (i == null) return false;
    return world.goddessTactics.states[i].scriptedTransition;
  }

  void _beginBarrage(EcsWorld world, EntityId boss, int tick) {
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
    final ii = world.targetPointIntent.indexOf(boss);
    states.commitTick[i] = tick;
    states.firstHandTick[i] = world.targetPointIntent.tick[ii];
    states.nextHand[i] = 0;
    // Stay aloft through the final hand's full visible impact/recovery.
    states.endTick[i] =
        states.firstHandTick[i] +
        5 * _handInterval +
        17 * world.targetPointIntent.frameStepTicks[ii];
    states.fromLeft[i] =
        world.targetPointIntent.targetX[ii] >=
        (bounds.minXTicks + bounds.maxXTicks) /
            (2 * terrainPhysicsTicksPerWorldUnit);
    states.positioned[i] = false;
    states.hovering[i] = false;
    final active = world.activeAbility;
    final ai = active.indexOf(boss);
    active.invulnerable[ai] = true;
    // Animate all thirty casting frames through the final hand's visible end.
    // Keep one recovery tick so prepareBarrage owns the exit transition.
    active.activeTicks[ai] = states.endTick[i] - states.firstHandTick[i];
    active.recoveryTicks[ai] = 1;
    active.totalTicks[ai] = states.endTick[i] - tick + 1;
    // This system schedules all six impacts using the captured cast payload.
    world.targetPointIntent.tick[ii] = -1;
  }

  // 0.35 seconds between fixed marks keeps adjacent warnings overlapping.
  int get _handInterval => (tickHz * .35).ceil();

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
          (ai != null &&
              world.activeAbility.abilityId[ai] == 'goddess.eruption' &&
              world.activeAbility.startTick[ai] == states.commitTick[i]);
      if (!current) {
        _finishBarrage(world, boss);
        continue;
      }
      if (currentTick >= states.endTick[i]) {
        final hovering = states.hovering[i];
        _finishBarrage(world, boss);
        _tactics.endBarrage(world, boss, hovering, currentTick);
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
      world.transform.velX[ti] = 0;
      world.transform.velY[ti] = 0;
      world.gravityControl.setSuppressForTicks(boss, 1);
    }
    _tactics.composeMotion(world);
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
