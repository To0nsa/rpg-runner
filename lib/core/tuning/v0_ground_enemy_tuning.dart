import '../util/tick_math.dart';

class V0GroundEnemyTuning {
  const V0GroundEnemyTuning({
    this.groundEnemySpeedX = 300.0,
    this.groundEnemyStopDistanceX = 6.0,
    this.groundEnemyAccelX = 600.0,
    this.groundEnemyDecelX = 400.0,
    this.groundEnemyChaseOffsetMaxX = 18.0,
    this.groundEnemyChaseOffsetMinAbsX = 6.0,
    this.groundEnemyChaseOffsetMeleeX = 3.0,
    this.groundEnemyChaseSpeedScaleMin = 0.92,
    this.groundEnemyChaseSpeedScaleMax = 1.08,
    this.groundEnemyJumpSpeed = 600.0,
    this.groundEnemyMeleeRangeX = 26.0,
    this.groundEnemyMeleeCooldownSeconds = 1.0,
    this.groundEnemyMeleeActiveSeconds = 0.10,
    this.groundEnemyMeleeDamage = 5.0,
    this.groundEnemyMeleeHitboxSizeX = 28.0,
    this.groundEnemyMeleeHitboxSizeY = 16.0,
  });

  // Ground enemy steering.
  final double groundEnemySpeedX;
  final double groundEnemyStopDistanceX;
  final double groundEnemyAccelX;
  final double groundEnemyDecelX;
  final double groundEnemyChaseOffsetMaxX;
  final double groundEnemyChaseOffsetMinAbsX;
  final double groundEnemyChaseOffsetMeleeX;
  final double groundEnemyChaseSpeedScaleMin;
  final double groundEnemyChaseSpeedScaleMax;

  /// Instantaneous jump vertical speed (negative is upward).
  final double groundEnemyJumpSpeed;

  // Ground enemy melee.
  final double groundEnemyMeleeRangeX;
  final double groundEnemyMeleeCooldownSeconds;
  final double groundEnemyMeleeActiveSeconds;
  final double groundEnemyMeleeDamage;
  final double groundEnemyMeleeHitboxSizeX;
  final double groundEnemyMeleeHitboxSizeY;
}

class V0GroundEnemyTuningDerived {
  const V0GroundEnemyTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.groundEnemyMeleeCooldownTicks,
    required this.groundEnemyMeleeActiveTicks,
  });

  factory V0GroundEnemyTuningDerived.from(
    V0GroundEnemyTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return V0GroundEnemyTuningDerived._(
      tickHz: tickHz,
      base: base,
      groundEnemyMeleeCooldownTicks: ticksFromSecondsCeil(
        base.groundEnemyMeleeCooldownSeconds,
        tickHz,
      ),
      groundEnemyMeleeActiveTicks: ticksFromSecondsCeil(
        base.groundEnemyMeleeActiveSeconds,
        tickHz,
      ),
    );
  }

  final int tickHz;
  final V0GroundEnemyTuning base;

  final int groundEnemyMeleeCooldownTicks;
  final int groundEnemyMeleeActiveTicks;
}
