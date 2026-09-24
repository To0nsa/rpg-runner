import 'dart:math' as math;

import '../../combat/damage.dart';
import '../../combat/faction.dart';
import '../../combat/hit_target_policy.dart';
import '../../events/game_event.dart';
import '../../snapshots/enums.dart';
import '../../snapshots/trap_snapshot.dart';
import '../../traps/spawn_trap_dart.dart';
import '../../traps/trap_catalog.dart';
import '../../traps/trap_geometry.dart';
import '../hit/aabb_hit_utils.dart';
import '../hit/hit_resolver.dart';
import '../spatial/broadphase_grid.dart';
import '../stores/trap_store.dart';
import '../world.dart';

/// Fixed-tick environmental activation and attack policy. Movement and ordinary
/// self defenses precede this system; common damage processing follows it.
final class TrapSystem {
  TrapSystem({required this.tickHz});
  final int tickHz;
  final HitResolver _resolver = HitResolver();
  final List<int> _overlaps = [];

  void step(
    EcsWorld world,
    BroadphaseGrid broadphase, {
    required int currentTick,
    required double cameraLeft,
    required double cameraTop,
    required double cameraRight,
    required double cameraBottom,
  }) {
    for (final state in world.traps.states) {
      final definition = TrapCatalog.get(state.source.trapId);
      final sign = state.placement.facing == Facing.left ? -1.0 : 1.0;
      final trigger = state.placement.trigger;
      _resolver.collectOrderedPoseSweepOverlaps(
        broadphase: broadphase,
        ax: state.x + trigger.offsetX,
        ay: state.y + trigger.offsetY,
        bx: state.x + trigger.right,
        by: state.y + trigger.offsetY,
        previousAx: state.x + trigger.offsetX,
        previousAy: state.y + trigger.bottom,
        previousBx: state.x + trigger.right,
        previousBy: state.y + trigger.bottom,
        radius: 0,
        owner: 0,
        sourceFaction: Faction.player,
        targetPolicy: HitTargetPolicy.allActors,
        outTargetIndices: _overlaps,
      );
      final occupied = _overlaps.isNotEmpty;
      bool visible(TrapRect source) {
        final rect = sign < 0 ? source.mirrored() : source;
        return aabbOverlapsMinMax(
          aMinX: state.x + rect.offsetX,
          aMaxX: state.x + rect.right,
          aMinY: state.y + rect.offsetY,
          aMaxY: state.y + rect.bottom,
          bMinX: cameraLeft,
          bMaxX: cameraRight,
          bMinY: cameraTop,
          bMaxY: cameraBottom,
        );
      }

      final inView =
          visible(definition.restingBounds) &&
          visible(definition.activationVisibilityBounds);
      if (state.phase == TrapPhase.cooldown) {
        if (currentTick < state.cooldownUntilTick) continue;
        state.phase = TrapPhase.waitingForClear;
      }
      if (state.phase == TrapPhase.waitingForClear) {
        if (!occupied && state.dart == null) state.phase = TrapPhase.idle;
        continue;
      }
      if (state.phase == TrapPhase.idle) {
        if (!occupied || !inView) continue;
        state.phase = TrapPhase.warning;
        state.activationTick = currentTick;
        state.frameIndex = 0;
        state.fired = false;
        state.attemptedTargets.clear();
      }
      void cooldown() {
        state.phase = TrapPhase.cooldown;
        state.cooldownUntilTick =
            currentTick + definition.cooldownTicks(tickHz);
        state.frameIndex = definition.idleFrameIndex;
      }

      if (!inView) {
        cooldown();
        continue;
      }
      final elapsed = currentTick - state.activationTick;
      final completed = elapsed >= definition.durationTicks(tickHz);
      final previousFrame = state.frameIndex;
      final frame = definition.frameAtTick(elapsed, tickHz);
      state.frameIndex = frame;
      state.phase = elapsed < definition.firstHarmfulTick(tickHz)
          ? TrapPhase.warning
          : TrapPhase.active;
      // Include crossed poses at lower tick rates; fire exactly once even when
      // the fixed-tick frame selector jumps over the mapped fire pose.
      for (
        var i = frame == previousFrame ? frame : previousFrame + 1;
        i <= frame;
        i++
      ) {
        final pose = definition.frames[i];
        if (pose.firesDart && !state.fired) {
          state.fired = true;
          state.dart = spawnTrapDart(
            world,
            source: state.source,
            x: state.x + definition.muzzle.x * sign,
            y: state.y + definition.muzzle.y,
            directionX: sign,
            tick: currentTick,
            tickHz: tickHz,
          );
        }
        final hit = pose.hitbox;
        if (hit == null) continue;
        final previous = i > previousFrame
            ? definition.frames[i - 1].hitbox ?? hit
            : hit;
        _queuePose(
          world,
          broadphase,
          state,
          hit,
          previous,
          sign,
          definition.damage100,
        );
      }
      if (completed) cooldown();
    }
  }

  void _queuePose(
    EcsWorld world,
    BroadphaseGrid broadphase,
    TrapState state,
    TrapHitCapsule hit,
    TrapHitCapsule previous,
    double sign,
    int damage100,
  ) {
    _resolver.collectOrderedPoseSweepOverlaps(
      broadphase: broadphase,
      ax: state.x + hit.ax * sign,
      ay: state.y + hit.ay,
      bx: state.x + hit.bx * sign,
      by: state.y + hit.by,
      previousAx: state.x + previous.ax * sign,
      previousAy: state.y + previous.ay,
      previousBx: state.x + previous.bx * sign,
      previousBy: state.y + previous.by,
      radius: math.max(hit.radius, previous.radius),
      owner: 0,
      sourceFaction: Faction.player,
      targetPolicy: HitTargetPolicy.allActors,
      outTargetIndices: _overlaps,
    );
    for (final targetIndex in _overlaps) {
      final target = broadphase.targets.entities[targetIndex];
      if (!state.attemptedTargets.add(target)) continue;
      world.damageQueue.add(
        DamageRequest(
          target: target,
          amount100: damage100,
          sourceKind: DeathSourceKind.trap,
          sourceTrap: state.source,
        ),
      );
    }
  }
}
