/// Ground enemy AI tuning grouped by navigation/engagement/locomotion/combat.
library;

import '../util/tick_math.dart';

class GroundEnemyTuning {
  const GroundEnemyTuning({
    this.navigation = const GroundEnemyNavigationTuning(),
    this.engagement = const GroundEnemyEngagementTuning(),
    this.locomotion = const GroundEnemyLocomotionTuning(),
    this.combat = const GroundEnemyCombatTuning(),
  });

  final GroundEnemyNavigationTuning navigation;
  final GroundEnemyEngagementTuning engagement;
  final GroundEnemyLocomotionTuning locomotion;
  final GroundEnemyCombatTuning combat;
}

/// Navigation tuning (chase offset + speed variance).
class GroundEnemyNavigationTuning {
  const GroundEnemyNavigationTuning({
    this.chaseOffsetMaxX = 18.0,
    this.chaseOffsetMinAbsX = 6.0,
    this.chaseOffsetMeleeX = 3.0,
    this.chaseSpeedScaleMin = 0.92,
    this.chaseSpeedScaleMax = 1.08,
  });

  /// Max random chase offset from player (world units).
  final double chaseOffsetMaxX;

  /// Min absolute chase offset (prevents clumping).
  final double chaseOffsetMinAbsX;

  /// Chase offset when in melee range (world units).
  final double chaseOffsetMeleeX;

  /// Min speed scale for chase variance.
  final double chaseSpeedScaleMin;

  /// Max speed scale for chase variance.
  final double chaseSpeedScaleMax;
}

/// Engagement tuning (slot selection + melee state movement).
class GroundEnemyEngagementTuning {
  const GroundEnemyEngagementTuning({
    this.meleeEngageBufferX = 4.0,
    this.meleeEngageHysteresisX = 2.0,
    this.meleeArriveSlowRadiusX = 12.0,
    this.meleeAttackSpeedMul = 0.25,
    this.meleeRecoverSpeedMul = 0.5,
  });

  /// Extra buffer beyond melee range to enter engage state.
  final double meleeEngageBufferX;

  /// Hysteresis added to engage buffer for disengage threshold.
  final double meleeEngageHysteresisX;

  /// Radius within which arrival steering slows to zero.
  final double meleeArriveSlowRadiusX;

  /// Speed multiplier during attack state.
  final double meleeAttackSpeedMul;

  /// Speed multiplier during recover state.
  final double meleeRecoverSpeedMul;
}

/// Locomotion tuning (movement + jump).
class GroundEnemyLocomotionTuning {
  const GroundEnemyLocomotionTuning({
    this.speedX = 300.0,
    this.stopDistanceX = 6.0,
    this.accelX = 600.0,
    this.decelX = 400.0,
    this.jumpSpeed = 500.0,
  });

  /// Target horizontal speed (world units/sec).
  final double speedX;

  /// Distance at which enemy stops chasing (world units).
  final double stopDistanceX;

  /// Horizontal acceleration (world units/sec^2).
  final double accelX;

  /// Horizontal deceleration (world units/sec^2).
  final double decelX;

  /// Jump velocity (world units/sec, positive = upward).
  final double jumpSpeed;
}

/// Combat tuning (melee timing + damage).
class GroundEnemyCombatTuning {
  const GroundEnemyCombatTuning({
    this.meleeRangeX = 26.0,
    this.meleeCooldownSeconds = 1.0,
    this.meleeActiveSeconds = 0.10,
    this.meleeAnimSeconds = 0.60,
    this.meleeWindupSeconds = 0.18,
    this.meleeDamage = 5.0,
    this.meleeHitboxSizeX = 28.0,
    this.meleeHitboxSizeY = 16.0,
  });

  /// Horizontal range to trigger melee attack (world units).
  final double meleeRangeX;

  /// Cooldown between melee attacks (seconds).
  final double meleeCooldownSeconds;

  /// Duration melee hitbox is active (seconds).
  final double meleeActiveSeconds;

  /// Duration the melee attack animation should be visible (seconds).
  ///
  /// This can be longer than [meleeActiveSeconds] since the hitbox
  /// window is often only a subset of the full animation.
  final double meleeAnimSeconds;

  /// Telegraph window before the melee hitbox becomes active (seconds).
  ///
  /// This delays hitbox spawn relative to the start of the attack animation.
  final double meleeWindupSeconds;

  /// Damage dealt by melee attack.
  final double meleeDamage;

  /// Melee hitbox width (world units).
  final double meleeHitboxSizeX;

  /// Melee hitbox height (world units).
  final double meleeHitboxSizeY;
}

class GroundEnemyTuningDerived {
  const GroundEnemyTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.navigation,
    required this.engagement,
    required this.locomotion,
    required this.combat,
  });

  factory GroundEnemyTuningDerived.from(
    GroundEnemyTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    final combat = base.combat;
    final engagement = base.engagement;

    final meleeStandOffX = () {
      final desired = combat.meleeHitboxSizeX * (2.0 / 3.0);
      if (desired.isNaN || desired.isInfinite) return 0.0;
      final clampedToRange = desired > combat.meleeRangeX
          ? combat.meleeRangeX
          : desired;
      return clampedToRange < 0.0 ? 0.0 : clampedToRange;
    }();

    return GroundEnemyTuningDerived._(
      tickHz: tickHz,
      base: base,
      navigation: base.navigation,
      engagement: GroundEnemyEngagementTuningDerived(
        meleeEngageBufferX: engagement.meleeEngageBufferX,
        meleeEngageHysteresisX: engagement.meleeEngageHysteresisX,
        meleeArriveSlowRadiusX: engagement.meleeArriveSlowRadiusX,
        meleeAttackSpeedMul: engagement.meleeAttackSpeedMul,
        meleeRecoverSpeedMul: engagement.meleeRecoverSpeedMul,
        meleeStandOffX: meleeStandOffX,
      ),
      locomotion: base.locomotion,
      combat: () {
        final meleeCooldownTicks = ticksFromSecondsCeil(
          combat.meleeCooldownSeconds,
          tickHz,
        );
        final meleeActiveTicks = ticksFromSecondsCeil(
          combat.meleeActiveSeconds,
          tickHz,
        );
        final meleeAnimTicks = ticksFromSecondsCeil(
          combat.meleeAnimSeconds,
          tickHz,
        );
        final rawWindupTicks = ticksFromSecondsCeil(
          combat.meleeWindupSeconds,
          tickHz,
        );
        // Ensure the hit tick occurs while the attack animation is still visible.
        final maxWindupTicks = meleeAnimTicks > 0 ? meleeAnimTicks - 1 : 0;
        final meleeWindupTicks =
            rawWindupTicks > maxWindupTicks ? maxWindupTicks : rawWindupTicks;
        return GroundEnemyCombatTuningDerived(
        meleeRangeX: combat.meleeRangeX,
        meleeCooldownSeconds: combat.meleeCooldownSeconds,
        meleeActiveSeconds: combat.meleeActiveSeconds,
        meleeAnimSeconds: combat.meleeAnimSeconds,
        meleeWindupSeconds: combat.meleeWindupSeconds,
        meleeDamage: combat.meleeDamage,
        meleeHitboxSizeX: combat.meleeHitboxSizeX,
        meleeHitboxSizeY: combat.meleeHitboxSizeY,
        meleeCooldownTicks: meleeCooldownTicks,
        meleeActiveTicks: meleeActiveTicks,
        meleeAnimTicks: meleeAnimTicks,
        meleeWindupTicks: meleeWindupTicks,
      );
      }(),
    );
  }

  final int tickHz;
  final GroundEnemyTuning base;
  final GroundEnemyNavigationTuning navigation;
  final GroundEnemyEngagementTuningDerived engagement;
  final GroundEnemyLocomotionTuning locomotion;
  final GroundEnemyCombatTuningDerived combat;
}

class GroundEnemyEngagementTuningDerived extends GroundEnemyEngagementTuning {
  const GroundEnemyEngagementTuningDerived({
    required super.meleeEngageBufferX,
    required super.meleeEngageHysteresisX,
    required super.meleeArriveSlowRadiusX,
    required super.meleeAttackSpeedMul,
    required super.meleeRecoverSpeedMul,
    required this.meleeStandOffX,
  });

  /// Stand-off target used in engage/attack/recover phases.
  ///
  /// Derived from [GroundEnemyCombatTuning.meleeHitboxSizeX] so the player
  /// sits well within the hitbox when the enemy is at its preferred slot.
  final double meleeStandOffX;
}

class GroundEnemyCombatTuningDerived extends GroundEnemyCombatTuning {
  const GroundEnemyCombatTuningDerived({
    required super.meleeRangeX,
    required super.meleeCooldownSeconds,
    required super.meleeActiveSeconds,
    required super.meleeAnimSeconds,
    required super.meleeWindupSeconds,
    required super.meleeDamage,
    required super.meleeHitboxSizeX,
    required super.meleeHitboxSizeY,
    required this.meleeCooldownTicks,
    required this.meleeActiveTicks,
    required this.meleeAnimTicks,
    required this.meleeWindupTicks,
  });

  final int meleeCooldownTicks;
  final int meleeActiveTicks;
  final int meleeAnimTicks;
  final int meleeWindupTicks;
}
