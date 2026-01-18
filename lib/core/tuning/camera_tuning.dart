/// Camera auto-scroll and follow tuning.
library;

import 'dart:math';

import '../players/player_tuning.dart';

class CameraTuning {
  const CameraTuning({
    this.speedLagMulX = 1.0,
    this.accelX = 1200.0,
    this.followThresholdRatio = 0.5,
    this.catchupLerp = 8.0,
    this.targetCatchupLerp = 2.5,
  });

  /// Baseline auto-scroll lags behind `MovementTuning.maxSpeedX` by this multiplier.
  final double speedLagMulX;

  /// Acceleration used to ease camera speed toward its target speed.
  final double accelX;

  /// Threshold ratio (from left edge) after which the player can pull the camera forward.
  final double followThresholdRatio;

  /// Smoothing for camera center toward its target (per-second).
  final double catchupLerp;

  /// Smoothing for camera target toward player (per-second).
  final double targetCatchupLerp;
}

class CameraTuningDerived {
  const CameraTuningDerived({
    required this.targetSpeedX,
    required this.accelX,
    required this.followThresholdRatio,
    required this.catchupLerp,
    required this.targetCatchupLerp,
  });

  factory CameraTuningDerived.from(
    CameraTuning tuning, {
    required MovementTuningDerived movement,
  }) {
    final targetSpeedX = max(0.0, movement.base.maxSpeedX * tuning.speedLagMulX);
    return CameraTuningDerived(
      targetSpeedX: targetSpeedX,
      accelX: tuning.accelX,
      followThresholdRatio: tuning.followThresholdRatio,
      catchupLerp: tuning.catchupLerp,
      targetCatchupLerp: tuning.targetCatchupLerp,
    );
  }

  final double targetSpeedX;
  final double accelX;
  final double followThresholdRatio;
  final double catchupLerp;
  final double targetCatchupLerp;
}
