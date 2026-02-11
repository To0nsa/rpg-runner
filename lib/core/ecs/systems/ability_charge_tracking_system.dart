import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../events/game_event.dart';
import '../../util/tick_math.dart';
import '../world.dart';

/// Tracks authoritative slot hold durations for charged ability commits.
///
/// This system derives charge purely from simulation-time hold state:
/// - hold start tick on transition to held
/// - current hold ticks while held
/// - released hold ticks captured on release transition
class AbilityChargeTrackingSystem {
  AbilityChargeTrackingSystem({required this.tickHz, required this.abilities});

  final int tickHz;
  final AbilityResolver abilities;

  void step(
    EcsWorld world, {
    required int currentTick,
    void Function(GameEvent event)? queueEvent,
  }) {
    final charge = world.abilityCharge;
    if (charge.denseEntities.isEmpty) return;

    for (var ci = 0; ci < charge.denseEntities.length; ci += 1) {
      final entity = charge.denseEntities[ci];
      if (!world.playerInput.has(entity)) continue;
      if (!world.equippedLoadout.has(entity)) continue;

      final loadoutIndex = world.equippedLoadout.indexOf(entity);

      var heldMask = charge.heldMask[ci];
      for (final slot in AbilitySlot.values) {
        final bit = 1 << slot.index;
        final slotOffset = charge.slotOffsetForDenseIndex(ci, slot);
        var heldNow = world.playerInput.isAbilitySlotHeld(entity, slot);
        final heldBefore = (heldMask & bit) != 0;
        final ability = _abilityForSlot(world, loadoutIndex, slot);

        if (heldNow) {
          if (!heldBefore) {
            charge.holdStartTickBySlot[slotOffset] = currentTick;
            charge.currentHoldTicksBySlot[slotOffset] = 0;
            charge.releasedHoldTicksBySlot[slotOffset] = 0;
            charge.releasedTickBySlot[slotOffset] = -1;
            charge.setSlotChargeCanceled(entity, slot: slot, canceled: false);
          } else {
            final start = charge.holdStartTickBySlot[slotOffset];
            final ticks = start >= 0 ? currentTick - start : 0;
            charge.currentHoldTicksBySlot[slotOffset] = ticks < 0 ? 0 : ticks;
          }

          final timedOut = _isChargeHoldTimedOut(
            ability,
            holdTicks: charge.currentHoldTicksBySlot[slotOffset],
          );
          if (timedOut) {
            world.playerInput.setAbilitySlotHeld(entity, slot, false);
            heldNow = false;
            charge.setSlotChargeCanceled(entity, slot: slot, canceled: true);
            if (ability != null) {
              queueEvent?.call(
                AbilityChargeEndedEvent(
                  tick: currentTick,
                  entity: entity,
                  slot: slot,
                  abilityId: ability.id,
                  reason: AbilityChargeEndReason.timeout,
                ),
              );
            }
          }
        }

        if (heldNow) {
          heldMask |= bit;
          continue;
        }

        if (heldBefore) {
          final start = charge.holdStartTickBySlot[slotOffset];
          final releasedTicks = start >= 0 ? currentTick - start : 0;
          charge.releasedHoldTicksBySlot[slotOffset] = releasedTicks < 0
              ? 0
              : releasedTicks;
          charge.releasedTickBySlot[slotOffset] = currentTick;
          charge.holdStartTickBySlot[slotOffset] = -1;
          charge.currentHoldTicksBySlot[slotOffset] = 0;
        } else {
          charge.currentHoldTicksBySlot[slotOffset] = 0;
        }
        heldMask &= ~bit;
      }

      charge.heldMask[ci] = heldMask;
    }
  }

  AbilityDef? _abilityForSlot(
    EcsWorld world,
    int loadoutIndex,
    AbilitySlot slot,
  ) {
    final loadout = world.equippedLoadout;
    final key = switch (slot) {
      AbilitySlot.primary => loadout.abilityPrimaryId[loadoutIndex],
      AbilitySlot.secondary => loadout.abilitySecondaryId[loadoutIndex],
      AbilitySlot.projectile => loadout.abilityProjectileId[loadoutIndex],
      AbilitySlot.mobility => loadout.abilityMobilityId[loadoutIndex],
      AbilitySlot.bonus => loadout.abilityBonusId[loadoutIndex],
      AbilitySlot.jump => loadout.abilityJumpId[loadoutIndex],
    };
    return abilities.resolve(key);
  }

  bool _isChargeHoldTimedOut(AbilityDef? ability, {required int holdTicks}) {
    if (ability == null) return false;
    if (ability.chargeProfile == null) return false;
    if (ability.chargeMaxHoldTicks60 <= 0) return false;
    final maxHoldTicks = _scaleAbilityTicks(ability.chargeMaxHoldTicks60);
    if (maxHoldTicks <= 0) return false;
    return holdTicks >= maxHoldTicks;
  }

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (tickHz == _abilityTickHz) return ticks;
    final seconds = ticks / _abilityTickHz;
    return ticksFromSecondsCeil(seconds, tickHz);
  }

  static const int _abilityTickHz = 60;
}
