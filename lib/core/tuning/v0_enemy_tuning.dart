import '../util/tick_math.dart';

class V0EnemyTuning {
  const V0EnemyTuning({
    this.demonHoverOffsetY = 90.0,
    this.demonDesiredRangeX = 160.0,
    this.demonRangeSlack = 20.0,
    this.demonMaxSpeedX = 180.0,
    this.demonMaxSpeedY = 120.0,
    this.demonVerticalKp = 4.0,
    this.demonVerticalDeadzone = 5.0,
    this.demonCastCooldownSeconds = 2.0,
    this.demonCastOriginOffset = 20.0,
    this.fireWormSpeedX = 140.0,
    this.fireWormStopDistanceX = 6.0,
    this.fireWormMeleeRangeX = 26.0,
    this.fireWormMeleeCooldownSeconds = 1.0,
    this.fireWormMeleeActiveSeconds = 0.10,
    this.fireWormMeleeDamage = 15.0,
    this.fireWormMeleeHitboxSizeX = 28.0,
    this.fireWormMeleeHitboxSizeY = 16.0,
  });

  // Demon steering.
  final double demonHoverOffsetY;
  final double demonDesiredRangeX;
  final double demonRangeSlack;
  final double demonMaxSpeedX;
  final double demonMaxSpeedY;
  final double demonVerticalKp;
  final double demonVerticalDeadzone;

  // Demon attacks.
  final double demonCastCooldownSeconds;
  final double demonCastOriginOffset;

  // FireWorm steering.
  final double fireWormSpeedX;
  final double fireWormStopDistanceX;

  // FireWorm melee.
  final double fireWormMeleeRangeX;
  final double fireWormMeleeCooldownSeconds;
  final double fireWormMeleeActiveSeconds;
  final double fireWormMeleeDamage;
  final double fireWormMeleeHitboxSizeX;
  final double fireWormMeleeHitboxSizeY;
}

class V0EnemyTuningDerived {
  const V0EnemyTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.demonCastCooldownTicks,
    required this.fireWormMeleeCooldownTicks,
    required this.fireWormMeleeActiveTicks,
  });

  factory V0EnemyTuningDerived.from(
    V0EnemyTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return V0EnemyTuningDerived._(
      tickHz: tickHz,
      base: base,
      demonCastCooldownTicks: ticksFromSecondsCeil(
        base.demonCastCooldownSeconds,
        tickHz,
      ),
      fireWormMeleeCooldownTicks: ticksFromSecondsCeil(
        base.fireWormMeleeCooldownSeconds,
        tickHz,
      ),
      fireWormMeleeActiveTicks: ticksFromSecondsCeil(
        base.fireWormMeleeActiveSeconds,
        tickHz,
      ),
    );
  }

  final int tickHz;
  final V0EnemyTuning base;

  final int demonCastCooldownTicks;
  final int fireWormMeleeCooldownTicks;
  final int fireWormMeleeActiveTicks;
}

