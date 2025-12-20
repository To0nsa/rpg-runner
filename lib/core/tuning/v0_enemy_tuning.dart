import '../util/tick_math.dart';

class V0EnemyTuning {
  const V0EnemyTuning({
    this.flyingEnemyHoverOffsetY = 150.0,
    this.flyingEnemyDesiredRangeMin = 50.0,
    this.flyingEnemyDesiredRangeMax = 90.0,
    this.flyingEnemyDesiredRangeHoldMinSeconds = 0.60,
    this.flyingEnemyDesiredRangeHoldMaxSeconds = 1.40,
    this.flyingEnemyHoldSlack = 20.0,
    this.flyingEnemyMaxSpeedX = 300.0,
    this.flyingEnemySlowRadiusX = 80.0,
    this.flyingEnemyAccelX = 600.0,
    this.flyingEnemyDecelX = 400.0,
    this.flyingEnemyMinHeightAboveGround = 100.0,
    this.flyingEnemyMaxHeightAboveGround = 240.0,
    this.flyingEnemyFlightTargetHoldMinSeconds = 1.5,
    this.flyingEnemyFlightTargetHoldMaxSeconds = 3.0,
    this.flyingEnemyMaxSpeedY = 300.0,
    this.flyingEnemyVerticalKp = 4.0,
    this.flyingEnemyVerticalDeadzone = 20.0,
    this.flyingEnemyCastCooldownSeconds = 2.0,
    this.flyingEnemyCastOriginOffset = 20.0,
    this.fireWormSpeedX = 140.0,
    this.fireWormStopDistanceX = 6.0,
    this.fireWormMeleeRangeX = 26.0,
    this.fireWormMeleeCooldownSeconds = 1.0,
    this.fireWormMeleeActiveSeconds = 0.10,
    this.fireWormMeleeDamage = 15.0,
    this.fireWormMeleeHitboxSizeX = 28.0,
    this.fireWormMeleeHitboxSizeY = 16.0,
  });

  // Flying enemy steering.
  final double flyingEnemyHoverOffsetY;
  final double flyingEnemyDesiredRangeMin;
  final double flyingEnemyDesiredRangeMax;
  final double flyingEnemyDesiredRangeHoldMinSeconds;
  final double flyingEnemyDesiredRangeHoldMaxSeconds;
  final double flyingEnemyHoldSlack;
  final double flyingEnemyMaxSpeedX;
  final double flyingEnemySlowRadiusX;
  final double flyingEnemyAccelX;
  final double flyingEnemyDecelX;
  final double flyingEnemyMinHeightAboveGround;
  final double flyingEnemyMaxHeightAboveGround;
  final double flyingEnemyFlightTargetHoldMinSeconds;
  final double flyingEnemyFlightTargetHoldMaxSeconds;
  final double flyingEnemyMaxSpeedY;
  final double flyingEnemyVerticalKp;
  final double flyingEnemyVerticalDeadzone;

  // Flying enemy attacks.
  final double flyingEnemyCastCooldownSeconds;
  final double flyingEnemyCastOriginOffset;

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
    required this.flyingEnemyCastCooldownTicks,
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
      flyingEnemyCastCooldownTicks: ticksFromSecondsCeil(
        base.flyingEnemyCastCooldownSeconds,
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

  final int flyingEnemyCastCooldownTicks;
  final int fireWormMeleeCooldownTicks;
  final int fireWormMeleeActiveTicks;
}
