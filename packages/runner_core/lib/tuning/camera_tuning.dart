/// Camera auto-scroll and follow tuning.
library;

import 'dart:math';

import '../players/player_tuning.dart';

/// Vertical camera behavior mode.
enum CameraVerticalMode {
  /// Keep camera Y fixed at the authored level default.
  lockY,

  /// Follow player Y with smoothing/dead-zone.
  followPlayer,
}

class CameraTuning {
  const CameraTuning({
    this.speedLagMulX = 1.0,
    this.accelX = 1200.0,
    this.followThresholdRatio = 0.5,
    this.catchupLerp = 8.0,
    this.targetCatchupLerp = 2.5,
    this.verticalMode = CameraVerticalMode.lockY,
    this.verticalCatchupLerp = 8.0,
    this.verticalTargetCatchupLerp = 6.0,
    this.verticalDeadZone = 6.0,
  }) : assert(followThresholdRatio >= 0.0 && followThresholdRatio <= 1.0);

  /// Baseline auto-scroll lags behind `MovementTuning.maxSpeedX` by this multiplier.
  final double speedLagMulX;

  /// Acceleration used to ease camera speed toward its target speed.
  final double accelX;

  /// Threshold ratio measured from the left edge of the viewport.
  ///
  /// Threshold formula in world coordinates:
  /// `thresholdX = cameraLeft + followThresholdRatio * viewWidth`.
  ///
  /// Runner-typical guidance:
  /// - `0.45-0.65`: balanced pull-forward behavior.
  /// - closer to `0.0`: camera is pulled earlier.
  /// - closer to `1.0`: camera is pulled later.
  final double followThresholdRatio;

  /// Smoothing for camera center toward its target (per-second).
  final double catchupLerp;

  /// Smoothing for camera target toward player (per-second).
  final double targetCatchupLerp;

  /// Vertical camera behavior mode.
  final CameraVerticalMode verticalMode;

  /// Smoothing for camera center Y toward target Y (per-second).
  final double verticalCatchupLerp;

  /// Smoothing for camera target Y toward player Y (per-second).
  final double verticalTargetCatchupLerp;

  /// Dead-zone around target Y where no vertical retarget occurs.
  final double verticalDeadZone;
}

class CameraTuningDerived {
  const CameraTuningDerived({
    required this.targetSpeedX,
    required this.accelX,
    required this.followThresholdRatio,
    required this.catchupLerp,
    required this.targetCatchupLerp,
    required this.verticalMode,
    required this.verticalCatchupLerp,
    required this.verticalTargetCatchupLerp,
    required this.verticalDeadZone,
  });

  factory CameraTuningDerived.from(
    CameraTuning tuning, {
    required MovementTuningDerived movement,
  }) {
    final targetSpeedX = max(
      0.0,
      movement.base.maxSpeedX * tuning.speedLagMulX,
    );
    return CameraTuningDerived(
      targetSpeedX: targetSpeedX,
      accelX: tuning.accelX,
      followThresholdRatio: tuning.followThresholdRatio,
      catchupLerp: tuning.catchupLerp,
      targetCatchupLerp: tuning.targetCatchupLerp,
      verticalMode: tuning.verticalMode,
      verticalCatchupLerp: tuning.verticalCatchupLerp,
      verticalTargetCatchupLerp: tuning.verticalTargetCatchupLerp,
      verticalDeadZone: tuning.verticalDeadZone,
    );
  }

  final double targetSpeedX;
  final double accelX;
  final double followThresholdRatio;
  final double catchupLerp;
  final double targetCatchupLerp;
  final CameraVerticalMode verticalMode;
  final double verticalCatchupLerp;
  final double verticalTargetCatchupLerp;
  final double verticalDeadZone;
}
