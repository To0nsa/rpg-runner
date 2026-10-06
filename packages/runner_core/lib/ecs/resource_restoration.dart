import '../util/fixed_math.dart';
import 'entity_id.dart';
import 'stores/restoration_item_store.dart';
import 'world.dart';

/// Restores a percentage of the current maximum, rounded down and capped.
///
/// The caller owns eligibility (pickup contact, living victory, etc.). Resource
/// rates, equipment and fractional regeneration accumulators are preserved.
abstract final class ResourceRestoration {
  /// Adds [percentBp] basis points of the current maximum (10,000 = 100%).
  /// Missing pools do nothing; the return value uses the pool's integer units.
  static int restorePercent(
    EcsWorld world, {
    required EntityId entity,
    required RestorationStat stat,
    required int percentBp,
  }) {
    assert(percentBp >= 0 && percentBp <= bpScale);
    final List<int> values;
    final List<int> maxima;
    final int? index;
    switch (stat) {
      case RestorationStat.health:
        index = world.health.tryIndexOf(entity);
        values = world.health.hp;
        maxima = world.health.hpMax;
      case RestorationStat.mana:
        index = world.mana.tryIndexOf(entity);
        values = world.mana.mana;
        maxima = world.mana.manaMax;
      case RestorationStat.stamina:
        index = world.stamina.tryIndexOf(entity);
        values = world.stamina.stamina;
        maxima = world.stamina.staminaMax;
    }
    if (index == null || maxima[index] <= 0) return 0;
    final previous = values[index];
    final restored = (maxima[index] * percentBp) ~/ bpScale;
    final next = previous + restored;
    values[index] = next > maxima[index] ? maxima[index] : next;
    return values[index] - previous;
  }
}
