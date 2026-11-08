import '../../abilities/ability_def.dart';
import '../../snapshots/enums.dart';
import '../../players/player_tuning.dart';
import '../../stats/resolved_stats_cache.dart';
import '../stores/mobility_intent_store.dart';
import '../world.dart';
import '../world_support_view.dart';
import 'world_motion_authority.dart';

/// Executes mobility intents (dash/roll) and applies movement state.
///
/// Activation owns gating, costs and cooldowns. Execution applies velocity and
/// gravity suppression using the same gear scaling as subsequent movement ticks.
class MobilitySystem {
  MobilitySystem({ResolvedStatsCache? statsCache, this.worldMotionAuthority})
    : _statsCache = statsCache ?? ResolvedStatsCache();

  final ResolvedStatsCache _statsCache;
  final WorldMotionAuthority? worldMotionAuthority;

  double step(
    EcsWorld world,
    MovementTuningDerived tuning, {
    required int currentTick,
    int? player,
  }) {
    final intents = world.mobilityIntent;
    if (intents.denseEntities.isEmpty) return 0;
    var blinkDistance = 0.0;

    final movements = world.movement;
    final transforms = world.transform;
    final bodies = world.body;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final entity = intents.denseEntities[ii];
      if (intents.blinkDestination[ii] != null) {
        final delta = _stepBlink(world, ii, currentTick);
        if (entity == player) blinkDistance += delta;
        continue;
      }
      if (intents.slot[ii] == AbilitySlot.jump) {
        continue;
      }
      final executeTick = intents.tick[ii];

      if (executeTick != currentTick) continue;

      _invalidateIntent(intents, ii);

      final mi = movements.tryIndexOf(entity);
      final ti = transforms.tryIndexOf(entity);
      final bi = bodies.tryIndexOf(entity);
      if (mi == null || ti == null || bi == null) continue;
      if (!bodies.enabled[bi] || bodies.isKinematic[bi]) continue;

      final activeTicks = intents.activeTicks[ii];
      if (activeTicks <= 0) continue;
      final dirX = intents.dirX[ii];
      final dirY = intents.dirY[ii];

      final terrainContactIndex = world.terrainContact.tryIndexOf(entity);
      if (terrainContactIndex != null) {
        final fallbackDirection = movements.facing[mi] == Facing.right ? 1 : -1;
        world.terrainContact.mobilityStartedGrounded[terrainContactIndex] =
            WorldSupportView(world).isGrounded(entity);
        world.terrainContact.mobilitySurfaceDirectionSign[terrainContactIndex] =
            dirX.abs() > 1e-6 ? dirX.sign.toInt() : fallbackDirection;
      }

      final modifierIndex = world.statModifier.tryIndexOf(entity);
      final moveSpeedMul = modifierIndex == null
          ? 1.0
          : world.statModifier.moveSpeedMul[modifierIndex];

      final speedScale = intents.speedScaleBp[ii] / 10000.0;
      final baseSpeed = intents.mobilitySpeedX[ii];
      final gearMoveSpeedMul = _statsCache
          .resolveForEntity(world, entity)
          .moveSpeedMultiplier;
      final dashSpeed =
          baseSpeed * gearMoveSpeedMul * moveSpeedMul * speedScale;

      movements.dashDirX[mi] = dirX;
      movements.dashDirY[mi] = dirY;
      movements.dashSpeedScale[mi] = speedScale;
      movements.mobilitySpeedX[mi] = intents.mobilitySpeedX[ii];
      movements.dashTicksLeft[mi] = activeTicks;
      if (dirX.abs() > 1e-6) {
        movements.facing[mi] = dirX >= 0 ? Facing.right : Facing.left;
      }

      transforms.velX[ti] = dirX * dashSpeed;
      transforms.velY[ti] = dirY * dashSpeed;
      world.gravityControl.setSuppressForTicks(entity, activeTicks);
    }
    return blinkDistance;
  }

  double _stepBlink(EcsWorld world, int ii, int tick) {
    final intents = world.mobilityIntent;
    final entity = intents.denseEntities[ii];
    final ai = world.activeAbility.tryIndexOf(entity);
    if (ai == null ||
        world.activeAbility.abilityId[ai] != intents.abilityId[ii] ||
        world.activeAbility.startTick[ai] != intents.commitTick[ii]) {
      intents.blinkDestination[ii] = null;
      _invalidateIntent(intents, ii);
      return 0;
    }
    final ti = world.transform.indexOf(entity);
    final mi = world.movement.indexOf(entity);
    final facing = world.activeAbility.facing[ai];
    world.movement.facing[mi] = facing;
    world.movement.dashTicksLeft[mi] = 0;
    world.transform.velX[ti] = 0;
    world.transform.velY[ti] = 0;
    world.gravityControl.setSuppressForTicks(entity, 1);
    // Protection belongs only to the invisible active phase, never the visible
    // preparation/recovery. Clearing/replacing the action clears protection.
    world.activeAbility.invulnerable[ai] =
        world.activeAbility.phase[ai] == AbilityPhase.active;
    if (intents.tick[ii] != tick) return 0;
    final target = intents.blinkDestination[ii]!;
    final authority = worldMotionAuthority;
    final origin = authority?.beginBodyTeleport(world, entity);
    final startX = world.transform.posX[ti];
    if (authority == null ||
        !authority.tryCommitBodyTeleport(
          world,
          entity,
          bodyX: target.x,
          bodyY: target.y,
          facing: facing,
        )) {
      if (origin != null) authority!.cancelBodyTeleport(world, entity, origin);
      final si = world.stamina.indexOf(entity);
      world.stamina.stamina[si] =
          (world.stamina.stamina[si] + intents.staminaCost100[ii]).clamp(
            0,
            world.stamina.staminaMax[si],
          );
      world.cooldown.setTicksLeft(entity, intents.cooldownGroupId[ii], 0);
      world.activeAbility.clear(entity);
      intents.blinkDestination[ii] = null;
      _invalidateIntent(intents, ii);
      return 0;
    }
    // Keep the commit identity through recovery, but execute this destination once.
    intents.tick[ii] = -1;
    return world.transform.posX[ti] - startX;
  }

  void _invalidateIntent(MobilityIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }
}
