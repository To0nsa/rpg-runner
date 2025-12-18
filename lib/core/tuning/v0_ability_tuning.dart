import '../util/tick_math.dart';

class V0AbilityTuning {
  const V0AbilityTuning({this.castCooldownSeconds = 0.25});

  final double castCooldownSeconds;
}

class V0AbilityTuningDerived {
  const V0AbilityTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.castCooldownTicks,
  });

  factory V0AbilityTuningDerived.from(
    V0AbilityTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return V0AbilityTuningDerived._(
      tickHz: tickHz,
      base: base,
      castCooldownTicks: ticksFromSecondsCeil(base.castCooldownSeconds, tickHz),
    );
  }

  final int tickHz;
  final V0AbilityTuning base;

  final int castCooldownTicks;
}
