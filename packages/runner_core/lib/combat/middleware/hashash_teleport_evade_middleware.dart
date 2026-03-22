import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../ecs/stores/damage_queue_store.dart';
import '../../ecs/stores/enemies/hashash_teleport_state_store.dart';
import '../../ecs/systems/damage_middleware_system.dart';
import '../../ecs/world.dart';
import '../../enemies/enemy_id.dart';
import '../../events/game_event.dart';
import '../../util/ability_timing.dart';
import '../../util/deterministic_rng.dart';
import '../../util/fixed_math.dart';
import '../control_lock.dart';

/// Gives Hashash a chance to evade incoming direct hits by teleporting out.
///
/// Applies only to direct projectile/melee hit requests and never to status DoT.
class HashashTeleportEvadeMiddleware implements DamageMiddleware {
  HashashTeleportEvadeMiddleware({
    required this.tickHz,
    this.abilityResolver = AbilityCatalog.shared,
    this.teleportOutAbilityId = 'hashash.teleport_out',
    this.evadeChanceBp = _defaultEvadeChanceBp,
  }) : assert(
         evadeChanceBp >= 0 && evadeChanceBp <= bpScale,
         'evadeChanceBp must be in range [0, $bpScale].',
       ),
       assert(tickHz > 0, 'tickHz must be > 0.');

  static const int _defaultEvadeChanceBp = 5000; // 50%
  static const int _evadeLockMask = LockFlag.allExceptStun;

  final int tickHz;
  final AbilityResolver abilityResolver;
  final AbilityKey teleportOutAbilityId;
  final int evadeChanceBp;

  @override
  void apply(
    EcsWorld world,
    DamageQueueStore queue,
    int index,
    int currentTick,
  ) {
    final sourceKind = queue.sourceKind[index];
    if (sourceKind != DeathSourceKind.projectile &&
        sourceKind != DeathSourceKind.meleeHitbox) {
      return;
    }

    final target = queue.target[index];
    if (world.deathState.has(target)) return;
    if (world.controlLock.isStunned(target, currentTick)) return;

    final enemyIndex = world.enemy.tryIndexOf(target);
    if (enemyIndex == null) return;
    if (world.enemy.enemyId[enemyIndex] != EnemyId.hashash) return;

    final teleport = world.hashashTeleport;
    final teleportIndex = teleport.tryIndexOf(target);
    if (teleportIndex == null) return;

    final phase = teleport.phase[teleportIndex];
    if (phase == HashashTeleportPhase.evadeOut) {
      queue.cancel(index);
      return;
    }
    if (phase != HashashTeleportPhase.idle) {
      return;
    }
    if (currentTick < teleport.cooldownUntilTick[teleportIndex]) {
      return;
    }

    final teleportOutAbility = abilityResolver.resolve(teleportOutAbilityId);
    if (teleportOutAbility == null) return;

    var rngState = teleport.rngState[teleportIndex];
    rngState = nextUint32(rngState);
    teleport.rngState[teleportIndex] = rngState;
    if ((rngState % bpScale) >= evadeChanceBp) {
      return;
    }

    final windupTicks = _scaleAbilityTicks(teleportOutAbility.windupTicks);
    final activeTicks = _scaleAbilityTicks(teleportOutAbility.activeTicks);
    final recoveryTicks = _scaleAbilityTicks(teleportOutAbility.recoveryTicks);
    final totalTicks = max(1, windupTicks + activeTicks + recoveryTicks);

    teleport.phase[teleportIndex] = HashashTeleportPhase.evadeOut;
    teleport.phaseEndTick[teleportIndex] = currentTick + totalTicks;

    world.controlLock.addLock(target, _evadeLockMask, totalTicks, currentTick);
    world.activeAbility.set(
      target,
      id: teleportOutAbility.id,
      slot: AbilitySlot.mobility,
      commitTick: currentTick,
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      recoveryTicks: recoveryTicks,
      facingDir: world.enemy.facing[enemyIndex],
      cooldownGroupId: teleportOutAbility.effectiveCooldownGroup(
        AbilitySlot.mobility,
      ),
      cooldownTicks: _scaleAbilityTicks(teleportOutAbility.cooldownTicks),
    );

    final transformIndex = world.transform.tryIndexOf(target);
    if (transformIndex != null) {
      world.transform.velX[transformIndex] = 0.0;
      world.transform.velY[transformIndex] = 0.0;
    }

    queue.cancel(index);
  }

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (tickHz == abilityAuthoringTickHz) return ticks;
    final seconds = ticks / abilityAuthoringTickHz;
    return (seconds * tickHz).ceil();
  }
}
