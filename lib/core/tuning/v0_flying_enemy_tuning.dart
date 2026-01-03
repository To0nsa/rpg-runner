import '../util/tick_math.dart';

class V0FlyingEnemyTuning {
  const V0FlyingEnemyTuning({
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
    this.flyingEnemyAimLeadMinSeconds = 0.08,
    this.flyingEnemyAimLeadMaxSeconds = 0.40,
    this.flyingEnemyCastCooldownSeconds = 2.0,
    this.flyingEnemyCastOriginOffset = 20.0,
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
  final double flyingEnemyAimLeadMinSeconds;
  final double flyingEnemyAimLeadMaxSeconds;
  final double flyingEnemyCastCooldownSeconds;
  final double flyingEnemyCastOriginOffset;
}

class V0FlyingEnemyTuningDerived {
  const V0FlyingEnemyTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.flyingEnemyCastCooldownTicks,
  });

  factory V0FlyingEnemyTuningDerived.from(
    V0FlyingEnemyTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return V0FlyingEnemyTuningDerived._(
      tickHz: tickHz,
      base: base,
      flyingEnemyCastCooldownTicks: ticksFromSecondsCeil(
        base.flyingEnemyCastCooldownSeconds,
        tickHz,
      ),
    );
  }

  final int tickHz;
  final V0FlyingEnemyTuning base;

  final int flyingEnemyCastCooldownTicks;
}
