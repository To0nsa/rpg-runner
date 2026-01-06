import '../util/tick_math.dart';

class CombatTuning {
  const CombatTuning({this.invulnerabilitySeconds = 0.25});

  final double invulnerabilitySeconds;
}

class CombatTuningDerived {
  const CombatTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.invulnerabilityTicks,
  });

  factory CombatTuningDerived.from(
    CombatTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return CombatTuningDerived._(
      tickHz: tickHz,
      base: base,
      invulnerabilityTicks: ticksFromSecondsCeil(
        base.invulnerabilitySeconds,
        tickHz,
      ),
    );
  }

  final int tickHz;
  final CombatTuning base;

  final int invulnerabilityTicks;
}

