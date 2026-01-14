/// Ground enemy AI tuning (steering, melee).
library;

import '../util/tick_math.dart';

class GroundEnemyTuning {
  const GroundEnemyTuning({
    this.groundEnemySpeedX = 300.0,
    this.groundEnemyStopDistanceX = 6.0,
    this.groundEnemyAccelX = 600.0,
    this.groundEnemyDecelX = 400.0,
    this.groundEnemyChaseOffsetMaxX = 18.0,
    this.groundEnemyChaseOffsetMinAbsX = 6.0,
    this.groundEnemyChaseOffsetMeleeX = 3.0,
    this.groundEnemyChaseSpeedScaleMin = 0.92,
    this.groundEnemyChaseSpeedScaleMax = 1.08,
    this.groundEnemyJumpSpeed = 500.0,
    this.groundEnemyMeleeRangeX = 26.0,
    this.groundEnemyMeleeCooldownSeconds = 1.0,
    this.groundEnemyMeleeActiveSeconds = 0.10,
    this.groundEnemyMeleeAnimSeconds = 0.60,
    this.groundEnemyMeleeDamage = 5.0,
    this.groundEnemyMeleeHitboxSizeX = 28.0,
    this.groundEnemyMeleeHitboxSizeY = 16.0,
  });

  // ── Steering ──

  /// Target horizontal speed (world units/sec).
  final double groundEnemySpeedX;

  /// Distance at which enemy stops chasing (world units).
  final double groundEnemyStopDistanceX;

  /// Horizontal acceleration (world units/sec²).
  final double groundEnemyAccelX;

  /// Horizontal deceleration (world units/sec²).
  final double groundEnemyDecelX;

  /// Max random chase offset from player (world units).
  final double groundEnemyChaseOffsetMaxX;

  /// Min absolute chase offset (prevents clumping).
  final double groundEnemyChaseOffsetMinAbsX;

  /// Chase offset when in melee range (world units).
  final double groundEnemyChaseOffsetMeleeX;

  /// Min speed scale for chase variance.
  final double groundEnemyChaseSpeedScaleMin;

  /// Max speed scale for chase variance.
  final double groundEnemyChaseSpeedScaleMax;

  /// Jump velocity (world units/sec, positive = upward).
  final double groundEnemyJumpSpeed;

  // ── Melee ──

  /// Horizontal range to trigger melee attack (world units).
  final double groundEnemyMeleeRangeX;

  /// Cooldown between melee attacks (seconds).
  final double groundEnemyMeleeCooldownSeconds;

  /// Duration melee hitbox is active (seconds).
  final double groundEnemyMeleeActiveSeconds;

  /// Duration the melee attack animation should be visible (seconds).
  ///
  /// This can be longer than [groundEnemyMeleeActiveSeconds] since the hitbox
  /// window is often only a subset of the full animation.
  final double groundEnemyMeleeAnimSeconds;

  /// Damage dealt by melee attack.
  final double groundEnemyMeleeDamage;

  /// Melee hitbox width (world units).
  final double groundEnemyMeleeHitboxSizeX;

  /// Melee hitbox height (world units).
  final double groundEnemyMeleeHitboxSizeY;
}

class GroundEnemyTuningDerived {
  const GroundEnemyTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.groundEnemyMeleeCooldownTicks,
    required this.groundEnemyMeleeActiveTicks,
    required this.groundEnemyMeleeAnimTicks,
  });

  factory GroundEnemyTuningDerived.from(
    GroundEnemyTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return GroundEnemyTuningDerived._(
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
      groundEnemyMeleeAnimTicks: ticksFromSecondsCeil(
        base.groundEnemyMeleeAnimSeconds,
        tickHz,
      ),
    );
  }

  final int tickHz;
  final GroundEnemyTuning base;

  final int groundEnemyMeleeCooldownTicks;
  final int groundEnemyMeleeActiveTicks;
  final int groundEnemyMeleeAnimTicks;
}
