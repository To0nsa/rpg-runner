import '../../combat/status/status.dart';
import '../../util/deterministic_rng.dart';
import '../../util/fixed_math.dart';
import '../../weapons/weapon_catalog.dart';
import '../../weapons/reactive_proc.dart';
import '../entity_id.dart';
import '../stores/combat/equipped_loadout_store.dart';
import '../world.dart';

/// Resolves defensive/reactive gear procs from post-damage outcomes.
///
/// This system consumes [EcsWorld.reactiveDamageEventQueue], evaluates offhand
/// [ReactiveProc] definitions, and queues status applications through
/// [queueStatus].
class ReactiveProcSystem {
  ReactiveProcSystem({required WeaponCatalog weapons, required int rngSeed})
    : _weapons = weapons,
      _rngState = seedFrom(rngSeed, 0x5f17c8d9);

  final WeaponCatalog _weapons;
  int _rngState;

  void step(
    EcsWorld world, {
    required int currentTick,
    void Function(StatusRequest request)? queueStatus,
  }) {
    final queue = world.reactiveDamageEventQueue;
    if (queue.length == 0) return;

    if (queueStatus == null) {
      queue.clear();
      return;
    }

    final loadout = world.equippedLoadout;
    final cooldown = world.reactiveProcCooldown;

    for (var i = 0; i < queue.length; i += 1) {
      final owner = queue.target[i];
      final loadoutIndex = loadout.tryIndexOf(owner);
      if (loadoutIndex == null) continue;
      if ((loadout.mask[loadoutIndex] & LoadoutSlotMask.offHand) == 0) {
        continue;
      }

      final offhandId = loadout.offhandWeaponId[loadoutIndex];
      final weapon = _weapons.tryGet(offhandId);
      if (weapon == null || weapon.reactiveProcs.isEmpty) continue;

      final source = queue.sourceEntity[i];
      final prevHp100 = queue.prevHp100[i];
      final nextHp100 = queue.nextHp100[i];
      final maxHp100 = queue.maxHp100[i];
      final damageType = queue.damageType[i];

      for (
        var procIndex = 0;
        procIndex < weapon.reactiveProcs.length;
        procIndex += 1
      ) {
        final proc = weapon.reactiveProcs[procIndex];
        if (proc.statusProfileId == StatusProfileId.none) continue;

        if (!_passesHookCondition(
          proc: proc,
          prevHp100: prevHp100,
          nextHp100: nextHp100,
          maxHp100: maxHp100,
        )) {
          continue;
        }

        final key = _procKey(offhandId.index, procIndex);
        if (cooldown.isOnCooldown(
          entity: owner,
          key: key,
          currentTick: currentTick,
        )) {
          continue;
        }

        if (!_passesChance(proc.chanceBp)) continue;

        final statusTarget = _resolveTarget(
          proc.target,
          owner: owner,
          source: source,
        );
        if (statusTarget == null) continue;

        queueStatus(
          StatusRequest(
            target: statusTarget,
            profileId: proc.statusProfileId,
            damageType: damageType,
          ),
        );

        cooldown.startCooldown(
          entity: owner,
          key: key,
          currentTick: currentTick,
          durationTicks: proc.internalCooldownTicks,
        );
      }
    }

    queue.clear();
  }

  bool _passesHookCondition({
    required ReactiveProc proc,
    required int prevHp100,
    required int nextHp100,
    required int maxHp100,
  }) {
    switch (proc.hook) {
      case ReactiveProcHook.onDamaged:
        return true;
      case ReactiveProcHook.onLowHealth:
        if (maxHp100 <= 0) return false;
        final thresholdHp100 =
            (maxHp100 * proc.lowHealthThresholdBp) ~/ bpScale;
        return prevHp100 > thresholdHp100 && nextHp100 <= thresholdHp100;
    }
  }

  EntityId? _resolveTarget(
    ReactiveProcTarget target, {
    required EntityId owner,
    required EntityId? source,
  }) {
    switch (target) {
      case ReactiveProcTarget.self:
        return owner;
      case ReactiveProcTarget.attacker:
        return source;
    }
  }

  bool _passesChance(int chanceBp) {
    if (chanceBp <= 0) return false;
    if (chanceBp >= bpScale) return true;
    _rngState = nextUint32(_rngState);
    return (_rngState % bpScale) < chanceBp;
  }

  int _procKey(int weaponIdIndex, int procIndex) =>
      (weaponIdIndex << 16) ^ procIndex;
}
