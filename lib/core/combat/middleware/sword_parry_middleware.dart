import '../../abilities/ability_def.dart';
import '../../combat/damage.dart';
import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../ecs/stores/damage_queue_store.dart';
import '../../ecs/systems/damage_middleware_system.dart';
import '../../ecs/world.dart';
import '../../events/game_event.dart';
import '../../util/fixed_math.dart';
import '../../weapons/weapon_proc.dart';

/// Cancels incoming damage while Sword Parry is active and optionally ripostes.
class SwordParryMiddleware implements DamageMiddleware {
  SwordParryMiddleware({
    this.perfectTicks = 8,
    this.reflectBp = 6000,
    this.reflectCap100 = 2000 * 100,
  });

  final int perfectTicks;
  final int reflectBp;
  final int reflectCap100;

  static const AbilityKey _parryAbilityId = 'eloise.sword_parry';

  @override
  void apply(EcsWorld world, DamageQueueStore queue, int index, int currentTick) {
    final target = queue.target[index];

    if (world.deathState.has(target)) return;
    final ai = world.activeAbility.tryIndexOf(target);
    if (ai == null) return;
    if (world.activeAbility.abilityId[ai] != _parryAbilityId) return;

    if (world.activeAbility.phase[ai] != AbilityPhase.active) return;

    final startTick = world.activeAbility.startTick[ai];
    final consumeIndex = world.parryConsume.indexOfOrAdd(target);
    if (world.parryConsume.consumedStartTick[consumeIndex] == startTick) {
      return;
    }

    final elapsed = currentTick - startTick;
    final windup = world.activeAbility.windupTicks[ai];
    final activeElapsed = elapsed - windup;
    if (activeElapsed < 0) return;

    queue.flags[index] |= DamageQueueFlags.canceled;
    world.parryConsume.consumedStartTick[consumeIndex] = startTick;

    if (activeElapsed >= perfectTicks) return;

    final source = queue.sourceEntity[index];
    if (source == null) return;
    if (world.deathState.has(source)) return;
    if (!world.health.has(source)) return;

    final reflected = clampInt(
      (queue.amount100[index] * reflectBp) ~/ bpScale,
      0,
      reflectCap100,
    );
    if (reflected <= 0) return;

    world.damageQueue.add(
      DamageRequest(
        target: source,
        amount100: reflected,
        damageType: DamageType.physical,
        statusProfileId: StatusProfileId.none,
        procs: const <WeaponProc>[],
        source: target,
        sourceKind: DeathSourceKind.meleeHitbox,
      ),
    );
  }
}
