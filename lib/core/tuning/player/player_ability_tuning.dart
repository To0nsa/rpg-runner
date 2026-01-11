/// Player ability tuning (cast, melee).
library;

import '../../util/tick_math.dart';

class AbilityTuning {
  const AbilityTuning({
    this.castCooldownSeconds = 0.25,
    this.meleeCooldownSeconds = 0.30,
    this.meleeActiveSeconds = 0.10,
    this.meleeStaminaCost = 5.0,
    this.meleeDamage = 15.0,
    this.meleeHitboxSizeX = 32.0,
    this.meleeHitboxSizeY = 16.0,
  });

  /// Cooldown between spell casts (seconds).
  final double castCooldownSeconds;

  /// Cooldown between melee attacks (seconds).
  final double meleeCooldownSeconds;

  /// Duration melee hitbox is active (seconds).
  final double meleeActiveSeconds;

  /// Stamina spent per melee attack.
  final double meleeStaminaCost;

  /// Damage dealt by melee attack.
  final double meleeDamage;

  /// Melee hitbox width (world units).
  final double meleeHitboxSizeX;

  /// Melee hitbox height (world units).
  final double meleeHitboxSizeY;
}

class AbilityTuningDerived {
  const AbilityTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.castCooldownTicks,
    required this.meleeCooldownTicks,
    required this.meleeActiveTicks,
  });

  factory AbilityTuningDerived.from(
    AbilityTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return AbilityTuningDerived._(
      tickHz: tickHz,
      base: base,
      castCooldownTicks: ticksFromSecondsCeil(base.castCooldownSeconds, tickHz),
      meleeCooldownTicks: ticksFromSecondsCeil(base.meleeCooldownSeconds, tickHz),
      meleeActiveTicks: ticksFromSecondsCeil(base.meleeActiveSeconds, tickHz),
    );
  }

  final int tickHz;
  final AbilityTuning base;

  final int castCooldownTicks;
  final int meleeCooldownTicks;
  final int meleeActiveTicks;
}
