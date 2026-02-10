import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../events/game_event.dart';
import '../entity_id.dart';
import '../world.dart';

/// Maintains committed hold abilities based on slot hold state and stamina.
///
/// This system:
/// - Ends hold abilities when the owning slot is released.
/// - Drains stamina deterministically while hold windows are maintained.
/// - Emits [AbilityHoldEndedEvent] when hold ends automatically (timeout/deplete).
class HoldAbilitySystem {
  HoldAbilitySystem({required this.tickHz, required this.abilities})
    : assert(tickHz > 0, 'tickHz must be > 0');

  final int tickHz;
  final AbilityResolver abilities;

  void step(
    EcsWorld world, {
    required int currentTick,
    void Function(GameEvent event)? queueEvent,
  }) {
    final active = world.activeAbility;
    if (active.denseEntities.isEmpty) return;

    for (var i = 0; i < active.denseEntities.length; i += 1) {
      final entity = active.denseEntities[i];
      final abilityId = active.abilityId[i];
      if (abilityId == null || abilityId.isEmpty) continue;

      final ability = abilities.resolve(abilityId);
      if (ability == null ||
          ability.holdMode != AbilityHoldMode.holdToMaintain) {
        continue;
      }

      final slot = active.slot[i];
      final slotHeld = world.playerInput.isAbilitySlotHeld(entity, slot);
      final phase = active.phase[i];
      final elapsed = active.elapsedTicks[i];
      final windupTicks = active.windupTicks[i];
      final activeTicks = active.activeTicks[i];
      final activeElapsed = elapsed - windupTicks;
      final isTimeoutTick =
          slotHeld &&
          phase == AbilityPhase.recovery &&
          activeTicks > 0 &&
          activeElapsed == activeTicks;

      if ((phase == AbilityPhase.windup || phase == AbilityPhase.active) &&
          !slotHeld) {
        _forceRecovery(world, entity: entity, index: i, elapsedTicks: elapsed);
        continue;
      }

      final drainSampleTick = switch (phase) {
        AbilityPhase.active when slotHeld => activeElapsed,
        AbilityPhase.recovery when isTimeoutTick => activeElapsed,
        _ => null,
      };

      final depleted =
          slotHeld &&
          drainSampleTick != null &&
          ability.holdStaminaDrainPerSecond100 > 0 &&
          _drainStamina(
            world,
            entity: entity,
            activeElapsedTick: drainSampleTick,
            drainPerSecond100: ability.holdStaminaDrainPerSecond100,
          );

      if (depleted) {
        _forceRecovery(world, entity: entity, index: i, elapsedTicks: elapsed);
        queueEvent?.call(
          AbilityHoldEndedEvent(
            tick: currentTick,
            entity: entity,
            slot: slot,
            abilityId: ability.id,
            reason: AbilityHoldEndReason.staminaDepleted,
          ),
        );
        continue;
      }

      if (isTimeoutTick) {
        _startCooldownIfDeferred(world, entity: entity, index: i);
        queueEvent?.call(
          AbilityHoldEndedEvent(
            tick: currentTick,
            entity: entity,
            slot: slot,
            abilityId: ability.id,
            reason: AbilityHoldEndReason.timeout,
          ),
        );
      }
    }
  }

  bool _drainStamina(
    EcsWorld world, {
    required EntityId entity,
    required int activeElapsedTick,
    required int drainPerSecond100,
  }) {
    if (activeElapsedTick < 0) return false;

    final totalDrainNow = (activeElapsedTick * drainPerSecond100) ~/ tickHz;
    final prevElapsed = activeElapsedTick - 1;
    final totalDrainPrev = prevElapsed >= 0
        ? (prevElapsed * drainPerSecond100) ~/ tickHz
        : 0;
    final delta = totalDrainNow - totalDrainPrev;
    if (delta <= 0) return false;

    final staminaIndex = world.stamina.tryIndexOf(entity);
    assert(
      staminaIndex != null,
      'Hold ability drain requires StaminaStore on entity $entity.',
    );
    if (staminaIndex == null) return true;

    final current = world.stamina.stamina[staminaIndex];
    final next = current - delta;
    if (next <= 0) {
      world.stamina.stamina[staminaIndex] = 0;
      return true;
    }

    world.stamina.stamina[staminaIndex] = next;
    return false;
  }

  void _forceRecovery(
    EcsWorld world, {
    required EntityId entity,
    required int index,
    required int elapsedTicks,
  }) {
    _startCooldownIfDeferred(world, entity: entity, index: index);

    final active = world.activeAbility;
    final recoveryTicks = active.recoveryTicks[index];
    if (recoveryTicks <= 0) {
      active.clear(entity);
      return;
    }

    final normalizedElapsed = elapsedTicks < 0 ? 0 : elapsedTicks;
    active.windupTicks[index] = normalizedElapsed;
    active.activeTicks[index] = 0;
    active.totalTicks[index] = normalizedElapsed + recoveryTicks;
    active.phase[index] = AbilityPhase.recovery;
  }

  void _startCooldownIfDeferred(
    EcsWorld world, {
    required EntityId entity,
    required int index,
  }) {
    final active = world.activeAbility;
    if (active.cooldownStarted[index]) return;
    active.cooldownStarted[index] = true;
    world.cooldown.startCooldown(
      entity,
      active.cooldownGroupId[index],
      active.cooldownTicks[index],
    );
  }
}
