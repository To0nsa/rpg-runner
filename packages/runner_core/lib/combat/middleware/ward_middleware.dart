import '../../ecs/stores/damage_queue_store.dart';
import '../../ecs/systems/damage_middleware_system.dart';
import '../../ecs/world.dart';
import '../../events/game_event.dart';
import '../../util/fixed_math.dart';

/// Applies active ward-style damage reduction to queued damage requests.
///
/// Behavior:
/// - direct hits are reduced by ward magnitude basis points
/// - DoT (`DeathSourceKind.statusEffect`) is fully canceled while ward is active
class WardMiddleware implements DamageMiddleware {
  const WardMiddleware();

  @override
  void apply(
    EcsWorld world,
    DamageQueueStore queue,
    int index,
    int currentTick,
  ) {
    final target = queue.target[index];
    if (world.deathState.has(target)) return;

    final wi = world.damageReduction.tryIndexOf(target);
    if (wi == null) return;
    if (world.damageReduction.ticksLeft[wi] <= 0) return;

    if (queue.sourceKind[index] == DeathSourceKind.statusEffect) {
      queue.flags[index] |= DamageQueueFlags.canceled;
      return;
    }

    final reduced = applyBp(
      queue.amount100[index],
      -world.damageReduction.magnitude[wi],
    );
    if (reduced <= 0) {
      queue.flags[index] |= DamageQueueFlags.canceled;
      return;
    }
    queue.amount100[index] = reduced;
  }
}
