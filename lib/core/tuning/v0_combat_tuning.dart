import '../util/tick_math.dart';

class V0CombatTuning {
  const V0CombatTuning({this.invulnerabilitySeconds = 0.25});

  final double invulnerabilitySeconds;
}

class V0CombatTuningDerived {
  const V0CombatTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.invulnerabilityTicks,
  });

  factory V0CombatTuningDerived.from(
    V0CombatTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return V0CombatTuningDerived._(
      tickHz: tickHz,
      base: base,
      invulnerabilityTicks: ticksFromSecondsCeil(
        base.invulnerabilitySeconds,
        tickHz,
      ),
    );
  }

  final int tickHz;
  final V0CombatTuning base;

  final int invulnerabilityTicks;
}

