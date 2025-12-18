import 'dart:math';

int _ticksFromSecondsCeil(double seconds, int tickHz) {
  if (seconds <= 0) return 0;
  return max(1, (seconds * tickHz).ceil());
}

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
      castCooldownTicks: _ticksFromSecondsCeil(base.castCooldownSeconds, tickHz),
    );
  }

  final int tickHz;
  final V0AbilityTuning base;

  final int castCooldownTicks;
}

