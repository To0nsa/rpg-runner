import '../../accessories/accessory_catalog.dart';
import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../util/deterministic_rng.dart';
import '../../util/fixed_math.dart';
import '../../weapons/weapon_catalog.dart';
import '../../weapons/reactive_proc.dart';
import '../entity_id.dart';
import '../stores/combat/equipped_loadout_store.dart';
import '../stores/reactive_proc_cooldown_store.dart';
import '../world.dart';

/// Resolves defensive/reactive gear procs from post-damage outcomes.
///
/// This system consumes [EcsWorld.reactiveDamageEventQueue], evaluates equipped
/// reactive proc definitions (offhand + accessory), and queues status
/// applications through
/// [queueStatus].
class ReactiveProcSystem {
  ReactiveProcSystem({
    required WeaponCatalog weapons,
    AccessoryCatalog accessories = const AccessoryCatalog(),
    required int rngSeed,
  })
    : _weapons = weapons,
      _accessories = accessories,
      _rngState = seedFrom(rngSeed, 0x5f17c8d9);

  final WeaponCatalog _weapons;
  final AccessoryCatalog _accessories;
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
      final source = queue.sourceEntity[i];
      final prevHp100 = queue.prevHp100[i];
      final nextHp100 = queue.nextHp100[i];
      final maxHp100 = queue.maxHp100[i];
      final damageType = queue.damageType[i];

      if ((loadout.mask[loadoutIndex] & LoadoutSlotMask.offHand) != 0) {
        final offhandId = loadout.offhandWeaponId[loadoutIndex];
        final weapon = _weapons.tryGet(offhandId);
        if (weapon != null && weapon.reactiveProcs.isNotEmpty) {
          _resolveReactiveProcs(
            procs: weapon.reactiveProcs,
            owner: owner,
            source: source,
            prevHp100: prevHp100,
            nextHp100: nextHp100,
            maxHp100: maxHp100,
            damageType: damageType,
            cooldown: cooldown,
            currentTick: currentTick,
            queueStatus: queueStatus,
            sourceKeyTag: _sourceTagOffhand,
            itemIndex: offhandId.index,
          );
        }
      }

      final accessoryId = loadout.accessoryId[loadoutIndex];
      final accessory = _accessories.get(accessoryId);
      if (accessory.reactiveProcs.isEmpty) continue;
      _resolveReactiveProcs(
        procs: accessory.reactiveProcs,
        owner: owner,
        source: source,
        prevHp100: prevHp100,
        nextHp100: nextHp100,
        maxHp100: maxHp100,
        damageType: damageType,
        cooldown: cooldown,
        currentTick: currentTick,
        queueStatus: queueStatus,
        sourceKeyTag: _sourceTagAccessory,
        itemIndex: accessoryId.index,
      );
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

  void _resolveReactiveProcs({
    required List<ReactiveProc> procs,
    required EntityId owner,
    required EntityId? source,
    required int prevHp100,
    required int nextHp100,
    required int maxHp100,
    required DamageType damageType,
    required ReactiveProcCooldownStore cooldown,
    required int currentTick,
    required void Function(StatusRequest request) queueStatus,
    required int sourceKeyTag,
    required int itemIndex,
  }) {
    for (var procIndex = 0; procIndex < procs.length; procIndex += 1) {
      final proc = procs[procIndex];
      if (proc.statusProfileId == StatusProfileId.none) continue;

      if (!_passesHookCondition(
        proc: proc,
        prevHp100: prevHp100,
        nextHp100: nextHp100,
        maxHp100: maxHp100,
      )) {
        continue;
      }

      final key = _sourceProcKey(sourceKeyTag, itemIndex, procIndex);
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

  static const int _sourceTagOffhand = 1;
  static const int _sourceTagAccessory = 2;

  int _sourceProcKey(int sourceTag, int itemIndex, int procIndex) =>
      (sourceTag << 28) ^ (itemIndex << 12) ^ procIndex;
}
