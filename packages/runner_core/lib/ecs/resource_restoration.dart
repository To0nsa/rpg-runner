import '../util/fixed_math.dart';
import 'entity_id.dart';
import 'stores/restoration_item_store.dart';
import 'world.dart';

/// Selects and restores resource pools using integer fractions and percentages.
///
/// The caller owns eligibility (pickup contact, living victory, etc.). Resource
/// rates, equipment and fractional regeneration accumulators are preserved.
abstract final class ResourceRestoration {
  /// Lowest current/maximum fraction among [candidates], using integer math.
  /// Candidate order breaks ties; missing and zero-maximum pools are skipped.
  /// Full pools remain eligible, so callers can offer a pickup for later use.
  static RestorationStat? lowestStat(
    EcsWorld world, {
    required EntityId entity,
    required Iterable<RestorationStat> candidates,
  }) {
    RestorationStat? best;
    var bestValue = 0;
    var bestMax = 1;
    for (final stat in candidates) {
      final int? index;
      final List<int> values;
      final List<int> maxima;
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
      if (index == null || maxima[index] <= 0) continue;
      if (best == null || values[index] * bestMax < bestValue * maxima[index]) {
        best = stat;
        bestValue = values[index];
        bestMax = maxima[index];
      }
    }
    return best;
  }

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
