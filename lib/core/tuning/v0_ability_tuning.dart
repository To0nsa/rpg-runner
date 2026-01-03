import '../util/tick_math.dart';

class V0AbilityTuning {
  const V0AbilityTuning({
    this.castCooldownSeconds = 0.25,
    this.meleeCooldownSeconds = 0.30,
    this.meleeActiveSeconds = 0.10,
    this.meleeStaminaCost = 5.0,
    this.meleeDamage = 15.0,
    this.meleeHitboxSizeX = 32.0,
    this.meleeHitboxSizeY = 16.0,
  });

  final double castCooldownSeconds;

  final double meleeCooldownSeconds;
  final double meleeActiveSeconds;
  final double meleeStaminaCost;
  final double meleeDamage;

  /// Full extents in world units (virtual pixels).
  final double meleeHitboxSizeX;
  final double meleeHitboxSizeY;
}

class V0AbilityTuningDerived {
  const V0AbilityTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.castCooldownTicks,
    required this.meleeCooldownTicks,
    required this.meleeActiveTicks,
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
      meleeCooldownTicks: ticksFromSecondsCeil(base.meleeCooldownSeconds, tickHz),
      meleeActiveTicks: ticksFromSecondsCeil(base.meleeActiveSeconds, tickHz),
    );
  }

  final int tickHz;
  final V0AbilityTuning base;

  final int castCooldownTicks;
  final int meleeCooldownTicks;
  final int meleeActiveTicks;
}
