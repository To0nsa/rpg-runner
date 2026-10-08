import '../../enemies/enemy_id.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../snapshots/enums.dart';
import '../actor_facing.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../world.dart';
import 'boss_combat_system.dart';

/// Goddess alternates her ranged threats, using claws when the target is close.
final class VoidbornGoddessCombatSystem extends BossCombatSystem {
  VoidbornGoddessCombatSystem({
    required super.tickHz,
    required super.castCommitter,
    required super.utilities,
  });

  @override
  EnemyId get enemyId => EnemyId.voidbornGoddess;
  @override
  double get standOff => 65;
  @override
  double get pursuitSpeedScale => .8;

  @override
  String selectAbility(
    EcsWorld world,
    EntityId boss, {
    required int sequence,
    required double distanceX,
    required bool atMeleeHeight,
    required int currentTick,
  }) {
    final state = world.bossCombat.indexOf(boss);
    if (sequence >= 3 &&
        currentTick >= world.bossCombat.nextTeleportTick[state]) {
      return 'goddess.teleport';
    }
    if (distanceX <= 85 && atMeleeHeight && sequence % 3 == 0) {
      return 'goddess.claw_combo';
    }
    return sequence.isEven ? 'goddess.orb' : 'goddess.eruption';
  }

  @override
  void onAbilityCommitted(
    EcsWorld world,
    EntityId boss,
    String abilityId,
    int tick,
  ) {
    if (abilityId == 'goddess.teleport') {
      // Eight seconds between relocations leaves time to attack her in place.
      world.bossCombat.nextTeleportTick[world.bossCombat.indexOf(boss)] =
          tick + 8 * tickHz;
    }
    if (abilityId != 'goddess.eruption') return;
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
    // This system schedules all six impacts using the captured cast payload.
    world.targetPointIntent.tick[ii] = -1;
  }

  int get _handInterval => (tickHz / 2).ceil();

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
          ai != null &&
          world.activeAbility.abilityId[ai] == 'goddess.eruption' &&
          world.activeAbility.startTick[ai] == states.commitTick[i];
      if (!current || currentTick >= states.returnTick[i]) {
        world.gravityControl.removeEntity(boss);
        if (living && states.hovering[i]) {
          _teleport(
            world,
            boss,
            states.originX[i],
            states.originY[i],
            states.originFacing[i],
          );
        }
        states.removeEntity(boss);
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
