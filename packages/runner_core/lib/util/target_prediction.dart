/// Deterministic linear target prediction helpers.
///
/// Used by enemy systems that need to commit attacks against moving targets.
library;

import 'dart:math';

import 'double_math.dart';

/// Computes clamped lead time from source/target distance and travel speed.
///
/// Returns `0` when [travelSpeedUnitsPerSecond] is non-positive.
double computeTravelLeadSeconds({
  required double sourceX,
  required double sourceY,
  required double targetX,
  required double targetY,
  required double travelSpeedUnitsPerSecond,
  required double minLeadSeconds,
  required double maxLeadSeconds,
}) {
  if (travelSpeedUnitsPerSecond <= 0.0) return 0.0;
  final dx = targetX - sourceX;
  final dy = targetY - sourceY;
  final distance = sqrt(dx * dx + dy * dy);
  return clampDouble(
    distance / travelSpeedUnitsPerSecond,
    minLeadSeconds,
    maxLeadSeconds,
  );
}

/// Predicts target position after [leadSeconds] using linear velocity.
(double x, double y) predictLinearTargetPosition({
  required double targetX,
  required double targetY,
  required double targetVelX,
  required double targetVelY,
  required double leadSeconds,
}) {
  if (leadSeconds <= 0.0) return (targetX, targetY);
  return (
    targetX + targetVelX * leadSeconds,
    targetY + targetVelY * leadSeconds,
  );
}
