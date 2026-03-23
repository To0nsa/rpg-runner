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

/// Computes final lead-time for cast prediction.
///
/// - Always includes [windupSeconds].
/// - Optionally includes projectile travel lead when [includeTravelLead] is true.
double computeCastLeadSeconds({
  required double windupSeconds,
  required bool includeTravelLead,
  required double sourceX,
  required double sourceY,
  required double targetX,
  required double targetY,
  required double travelSpeedUnitsPerSecond,
  required double minTravelLeadSeconds,
  required double maxTravelLeadSeconds,
}) {
  var lead = windupSeconds <= 0.0 ? 0.0 : windupSeconds;
  if (!includeTravelLead) return lead;
  lead += computeTravelLeadSeconds(
    sourceX: sourceX,
    sourceY: sourceY,
    targetX: targetX,
    targetY: targetY,
    travelSpeedUnitsPerSecond: travelSpeedUnitsPerSecond,
    minLeadSeconds: minTravelLeadSeconds,
    maxLeadSeconds: maxTravelLeadSeconds,
  );
  return lead;
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
