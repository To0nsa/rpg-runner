import '../entity_id.dart';
import '../world.dart';

/// Shared forced-interruption cleanup helpers.
///
/// Keeps interruption side-effects consistent across systems:
/// - End active ability (optionally starting deferred cooldown first).
/// - Clear buffered input.
/// - Drop pending ability intents.
abstract final class AbilityInterrupt {
  /// Clears active ability state and all transient ability state for [entity].
  ///
  /// When [startDeferredCooldown] is true and the interrupted ability has not
  /// started cooldown yet (hold-to-maintain pattern), cooldown is started
  /// before clearing active state.
  static void clearActiveAndTransient(
    EcsWorld world, {
    required EntityId entity,
    required bool startDeferredCooldown,
  }) {
    final activeIndex = world.activeAbility.tryIndexOf(entity);
    if (activeIndex != null) {
      if (startDeferredCooldown &&
          !world.activeAbility.cooldownStarted[activeIndex]) {
        world.activeAbility.cooldownStarted[activeIndex] = true;
        world.cooldown.startCooldown(
          entity,
          world.activeAbility.cooldownGroupId[activeIndex],
          world.activeAbility.cooldownTicks[activeIndex],
        );
      }
      world.activeAbility.clear(entity);
    }

    if (world.abilityInputBuffer.has(entity)) {
      world.abilityInputBuffer.clear(entity);
    }

    if (world.meleeIntent.has(entity)) {
      final i = world.meleeIntent.indexOf(entity);
      world.meleeIntent.tick[i] = -1;
      world.meleeIntent.commitTick[i] = -1;
    }
    if (world.projectileIntent.has(entity)) {
      final i = world.projectileIntent.indexOf(entity);
      world.projectileIntent.tick[i] = -1;
      world.projectileIntent.commitTick[i] = -1;
    }
    if (world.mobilityIntent.has(entity)) {
      final i = world.mobilityIntent.indexOf(entity);
      world.mobilityIntent.tick[i] = -1;
      world.mobilityIntent.commitTick[i] = -1;
    }
    if (world.selfIntent.has(entity)) {
      final i = world.selfIntent.indexOf(entity);
      world.selfIntent.tick[i] = -1;
      world.selfIntent.commitTick[i] = -1;
    }
  }
}
