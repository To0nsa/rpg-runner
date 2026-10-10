import 'dart:math' as math;

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../combat/ai_cast_aim_policy.dart';
import '../../combat/control_lock.dart';
import '../../combat/voidborn_goddess_pose_catalog.dart';
import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../../util/vec2.dart';
import '../actor_facing.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../stores/enemies/goddess_tactics_store.dart';
import '../world.dart';
import 'boss_flight_system.dart';
import 'ability_interrupt.dart';
import 'boss_utility_system.dart';
import 'enemy_cast_system.dart';
import 'enemy_melee_system.dart';

/// Distance decisions and cancellable spell/teleport transitions for Goddess.
/// Damage, cooldowns, and motion still use the ordinary authoritative executors.
final class GoddessTacticsSystem {
  GoddessTacticsSystem({
    required this.tickHz,
    required this.casts,
    required this.utilities,
    required this.onBarrage,
  });
  final int tickHz;
  final AiCastCommitter casts;
  final BossUtilitySystem utilities;
  final void Function(EcsWorld, EntityId, int) onBarrage;
  late final _melee = AiMeleeCommitter(tickHz: tickHz);

  GoddessTactics _state(EcsWorld world, EntityId boss, int tick) {
    final s = world.goddessTactics.stateFor(boss);
    if (!s.initialized) {
      s.initialized = true;
      s.orbsRemaining = 1 + s.roll(2);
      _resetTeleport(s, tick);
    }
    return s;
  }

  void _resetTeleport(GoddessTactics s, int tick) {
    s.nextTeleportTick = tick + (4 * tickHz) + s.roll(2 * tickHz + 1);
  }

  /// Reactive counters restart the voluntary teleport clock and cancel approach.
  void didDodge(EcsWorld world, EntityId boss, int tick) {
    final s = _state(world, boss, tick);
    s.clearTransition();
    _resetTeleport(s, tick);
    s.orbsRemaining = 1 + s.roll(2);
  }

  /// The final hand relinquishes protection before the ordinary exit orb begins.
  void endBarrage(EcsWorld world, EntityId boss, int tick) {
    final s = _state(world, boss, tick);
    s.clearTransition();
    s.phase = GoddessTactic.exitPending;
  }

  void step(EcsWorld world, EntityId boss, EntityId player, int tick) {
    final s = _state(world, boss, tick);
    final ti = world.transform.indexOf(boss);
    _hold(world, boss, tick);
    final target = combatTarget(world, boss, player);
    final available =
        isLivingCombatActor(world, boss) &&
        !world.arenaSuspension.has(boss) &&
        !world.controlLock.isLocked(boss, LockFlag.allActions, tick) &&
        !world.controlLock.isStunned(boss, tick);
    if (!available || target == null) {
      _cancel(world, boss, s);
      _hold(world, boss, tick);
      return;
    }
    final ai = world.activeAbility.tryIndexOf(boss);
    if (ai != null &&
        world.activeAbility.abilityId[ai] == 'goddess.claw_combo') {
      _trackCombo(world, boss, target, ai, tick);
      return;
    }
    if (s.phase == GoddessTactic.exitPending) {
      _hold(world, boss, tick);
      // The scripted exit belongs to the barrage and preserves its cooldown.
      final remaining = world.cooldown.getTicksLeft(boss, 0);
      world.cooldown.setTicksLeft(boss, 0, 0);
      final committed = _commit(world, boss, target, 'goddess.orb', tick);
      world.cooldown.startCooldown(boss, 0, remaining);
      if (committed) {
        s.phase = GoddessTactic.exitOrb;
        _capture(world, boss, s);
      } else {
        _cancel(world, boss, s);
      }
      return;
    }
    if (world.activeAbility.hasActiveAbility(boss) ||
        world.goddessBarrage.has(boss) ||
        world.cooldown.isOnCooldown(boss, 0) ||
        (s.phase != GoddessTactic.idle && s.phase != GoddessTactic.approach)) {
      _hold(world, boss, tick);
      return;
    }
    final hi = world.goddessHealthPhase.indexOf(boss);
    if (world.goddessHealthPhase.committed[hi] <
        world.goddessHealthPhase.reached[hi]) {
      s.clearTransition();
      if (_commit(world, boss, target, 'goddess.eruption', tick)) {
        _resetTeleport(s, tick);
        onBarrage(world, boss, tick);
      }
      _hold(world, boss, tick);
      return;
    }
    final targetTi = world.transform.indexOf(target);
    final dx = world.transform.posX[targetTi] - world.transform.posX[ti];
    final direct = utilities.motion.canFlyDirectlyTo(
      world,
      boss,
      world.transform.posX[targetTi],
      BossFlightSystem.targetHeight(world, boss, target),
    );
    final atHeight =
        (world.transform.posY[targetTi] - world.transform.posY[ti]).abs() <= 50;
    var approached = false;
    if (s.phase == GoddessTactic.approach) {
      if (tick < s.approachEndTick &&
          (s.approachX - world.transform.posX[ti]).abs() > 1 &&
          dx.abs() > 45 &&
          atHeight &&
          direct) {
        _approachIntent(world, boss, s, tick);
        return;
      }
      s.phase = GoddessTactic.idle;
      approached = true;
    }
    if (!approached && dx.abs() > 45 && dx.abs() <= 70 && atHeight && direct) {
      s.phase = GoddessTactic.approach;
      s.approachX =
          world.transform.posX[ti] + dx.sign * math.min(25, dx.abs() - 35);
      s.approachEndTick = tick + (tickHz * .5).ceil();
      _approachIntent(world, boss, s, tick);
      return;
    }
    final close = dx.abs() <= 45 && atHeight && direct;
    final wantsTeleport =
        tick >= s.nextTeleportTick &&
        (close ? s.roll(10) >= 7 : dx.abs() > 240 || s.orbsRemaining == 0);
    if (!wantsTeleport || !_beginTeleport(world, boss, target, s, tick)) {
      final key = close ? 'goddess.claw_combo' : 'goddess.orb';
      if (_commit(world, boss, target, key, tick) && !close) {
        s.orbsRemaining = math.max(0, s.orbsRemaining - 1);
      }
    }
    _hold(world, boss, tick);
  }

  void _approachIntent(
    EcsWorld world,
    EntityId boss,
    GoddessTactics s,
    int tick,
  ) {
    world.bossFlightIntent.pursue(
      boss,
      currentTick: tick,
      x: s.approachX,
      y: world.transform.posY[world.transform.indexOf(boss)],
      horizontalSpeed: BossFlightSystem.comboSpeed,
      verticalSpeed: 0,
    );
  }

  // World units: stop within claw reach without walking through the target.
  static const _comboStandOff = 35.0;

  void _trackCombo(
    EcsWorld world,
    EntityId boss,
    EntityId target,
    int ai,
    int tick,
  ) {
    final active = world.activeAbility;
    final elapsed = tick - active.startTick[ai];
    if (elapsed >= active.windupTicks[ai] + active.activeTicks[ai]) {
      _hold(world, boss, tick);
      return;
    }
    final profile = VoidbornGoddessPoseCatalog.goddessClaws;
    int frameAt(int age) => profile.timing.frameAt(
      elapsed: age,
      windup: active.windupTicks[ai],
      active: active.activeTicks[ai],
      recovery: active.recoveryTicks[ai],
    );
    final frame = frameAt(elapsed);
    final previous = frameAt(math.max(0, elapsed - 1));
    final ti = world.transform.indexOf(boss);
    final targetX = world.transform.posX[world.transform.indexOf(target)];
    final dx = targetX - world.transform.posX[ti];
    // Track in harmless poses and at the start of each distinct swipe, never
    // flip a live swipe across the player. Two units avoid overlap jitter.
    if (dx.abs() > 2 &&
        (profile.frames[frame].isEmpty ||
            profile.combo!.strikeWindowAt(frame) !=
                profile.combo!.strikeWindowAt(previous))) {
      active.facing[ai] = dx > 0 ? Facing.right : Facing.left;
      final mi = world.meleeIntent.indexOf(boss);
      world.meleeIntent.dirX[mi] = dx.sign;
    }
    final direction = active.facing[ai] == Facing.right ? 1.0 : -1.0;
    setActorFacing(world, boss, active.facing[ai]);
    world.bossFlightIntent.pursue(
      boss,
      currentTick: tick,
      x: dx * direction > _comboStandOff
          ? targetX - direction * _comboStandOff
          : world.transform.posX[ti],
      y: BossFlightSystem.targetHeight(world, boss, target),
      horizontalSpeed: BossFlightSystem.comboSpeed,
      verticalSpeed: BossFlightSystem.verticalSpeed,
    );
  }

  void _hold(EcsWorld world, EntityId boss, int tick) {
    world.bossFlightIntent.hover(boss, tick);
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
    final x = world.transform.posX[targetTi];
    final committed = key == 'goddess.claw_combo'
        ? _melee.commit(
                world,
                actor: boss,
                abilityId: key,
                targetX: x,
                currentTick: tick,
              ) !=
              null
        : casts.commit(
            world,
            actor: boss,
            castAbility: AbilityCatalog.shared.resolve(key)!,
            sourceX: world.transform.posX[ti],
            sourceY: world.transform.posY[ti],
            targetX: x,
            targetY: world.transform.posY[targetTi],
            targetVelX: 0,
            targetVelY: 0,
            aimPolicy: AiCastAimPolicy.targetCenter,
            casterOriginOffset: 30,
            currentTick: tick,
          );
    if (committed) {
      world.bossCombat.actionIndex[world.bossCombat.indexOf(boss)]++;
    }
    return committed;
  }

  bool _beginTeleport(
    EcsWorld world,
    EntityId boss,
    EntityId target,
    GoddessTactics s,
    int tick,
  ) {
    if (world.controlLock.isLocked(boss, LockFlag.cast, tick) ||
        world.activeAbility.hasActiveAbility(boss)) {
      return false;
    }
    final x = world.transform.posX[world.transform.indexOf(target)];
    final bossX = world.transform.posX[world.transform.indexOf(boss)];
    final options = <Vec2>[];
    for (final offset in [-220.0, -180.0, -140.0, 140.0, 180.0, 220.0]) {
      final result = utilities.resolveArenaPlacement(
        world,
        boss,
        EnemyId.voidbornGoddess,
        x + offset,
      );
      if (result == null) continue;
      final position = Vec2(
        result.bodyCenter!.xTicks / terrainPhysicsTicksPerWorldUnit,
        result.bodyCenter!.yTicks / terrainPhysicsTicksPerWorldUnit,
      );
      if ((position.x - bossX).abs() < 64 ||
          (position.x - x).abs() < 140 ||
          (position.x - x).abs() > 220) {
        continue;
      }
      options.add(position);
    }
    if (options.isEmpty) {
      s.nextTeleportTick = tick + tickHz;
      return false;
    }
    s.destination = options[s.roll(options.length)];
    s.phase = GoddessTactic.teleportOut;
    _setTeleportAction(world, boss, s, 'goddess.reposition_out', tick);
    return true;
  }

  void _setTeleportAction(
    EcsWorld world,
    EntityId boss,
    GoddessTactics s,
    String key,
    int tick,
  ) {
    final ability = AbilityCatalog.shared.resolve(key)!;
    world.activeAbility.set(
      boss,
      id: key,
      slot: AbilitySlot.mobility,
      commitTick: tick,
      windupTicks: 0,
      activeTicks: (ability.activeTicks * tickHz / 60).ceil(),
      recoveryTicks: (ability.recoveryTicks * tickHz / 60).ceil(),
      facingDir: actorFacing(world, boss),
    );
    _capture(world, boss, s);
    // Retain action identity until this system commits placement before motion.
    if (s.phase == GoddessTactic.teleportOut) {
      s.endTick =
          tick +
          world.activeAbility.activeTicks[world.activeAbility.indexOf(boss)];
    }
  }

  void _capture(EcsWorld world, EntityId boss, GoddessTactics s) {
    final ai = world.activeAbility.indexOf(boss);
    s.abilityId = world.activeAbility.abilityId[ai];
    s.startTick = world.activeAbility.startTick[ai];
    s.endTick = s.startTick + world.activeAbility.totalTicks[ai];
  }

  /// Execute captured destinations before water and navigation read the body.
  void prepare(EcsWorld world, EntityId player, int tick) {
    for (var i = 0; i < world.goddessTactics.states.length; i++) {
      final boss = world.goddessTactics.denseEntities[i];
      final s = world.goddessTactics.states[i];
      if (s.phase == GoddessTactic.idle) continue;
      final target = combatTarget(world, boss, player);
      if (!isLivingCombatActor(world, boss) ||
          target == null ||
          world.arenaSuspension.has(boss) ||
          world.controlLock.isStunned(boss, tick)) {
        _cancel(world, boss, s);
        continue;
      }
      if (s.abilityId == null) continue;
      final ai = world.activeAbility.indexOf(boss);
      final current =
          world.activeAbility.abilityId[ai] == s.abilityId &&
          world.activeAbility.startTick[ai] == s.startTick;
      final finished =
          tick >= s.endTick && !world.activeAbility.hasActiveAbility(boss);
      if (!current && !finished) {
        _cancel(world, boss, s);
        continue;
      }
      if (tick < s.endTick) continue;
      if (s.phase == GoddessTactic.exitOrb) {
        if (current) world.activeAbility.clear(boss);
        if (!_beginTeleport(world, boss, target, s, tick)) {
          _cancel(world, boss, s);
        }
      } else if (s.phase == GoddessTactic.teleportOut) {
        final destination = s.destination!;
        final motion = utilities.motion;
        final origin = motion.beginBodyTeleport(world, boss);
        final targetX = world.transform.posX[world.transform.indexOf(target)];
        if (!motion.tryCommitBodyTeleport(
          world,
          boss,
          bodyX: destination.x,
          bodyY: destination.y,
          facing: targetX >= destination.x ? Facing.right : Facing.left,
        )) {
          motion.cancelBodyTeleport(world, boss, origin);
          _cancel(world, boss, s);
          s.nextTeleportTick = tick + tickHz;
          continue;
        }
        s.destination = null;
        s.phase = GoddessTactic.teleportIn;
        _setTeleportAction(world, boss, s, 'goddess.reposition_in', tick);
        _resetTeleport(s, tick);
        s.orbsRemaining = 1 + s.roll(2);
      } else if (s.phase == GoddessTactic.teleportIn) {
        _cancel(world, boss, s);
      }
    }
  }

  void _cancel(EcsWorld world, EntityId boss, GoddessTactics s) {
    final ai = world.activeAbility.tryIndexOf(boss);
    if (s.abilityId != null &&
        ai != null &&
        world.activeAbility.abilityId[ai] == s.abilityId &&
        world.activeAbility.startTick[ai] == s.startTick) {
      AbilityInterrupt.clearActiveAndTransient(
        world,
        entity: boss,
        startDeferredCooldown: true,
      );
    }
    s.clearTransition();
  }
}
