import 'dart:math' as math;

import '../snapshots/enums.dart';

/// Explicit capsule endpoints and radius, in world units relative to an anchor.
/// Rounded ends are part of the shape; no rectangle-size conversion is implied.
final class CombatCapsule {
  const CombatCapsule(this.ax, this.ay, this.bx, this.by, this.radius)
    : assert(radius > 0);

  final double ax;
  final double ay;
  final double bx;
  final double by;
  final double radius;

  double get minX => math.min(ax, bx) - radius;
  double get maxX => math.max(ax, bx) + radius;
  double get minY => math.min(ay, by) - radius;
  double get maxY => math.max(ay, by) + radius;

  /// Mirrors source art first, then rotates the complete pose around its anchor.
  CombatCapsule transformed({double mirror = 1, double angle = 0}) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return CombatCapsule(
      ax * mirror * c - ay * s,
      ax * mirror * s + ay * c,
      bx * mirror * c - by * s,
      bx * mirror * s + by * c,
      radius,
    );
  }

  CombatCapsule translated(double x, double y) =>
      CombatCapsule(ax + x, ay + y, bx + x, by + y, radius);
}

/// Maps committed windup/active/recovery ticks to the corresponding art poses.
/// This keeps impact/release poses aligned when action speed or tick rate changes.
final class ActionFramePolicy {
  const ActionFramePolicy({
    required this.frameCount,
    required this.activeStart,
    required this.activeEnd,
    this.holdActivePose = false,
  }) : assert(frameCount > 0),
       assert(activeStart >= 0 && activeStart < activeEnd),
       assert(activeEnd <= frameCount);

  final int frameCount;
  final int activeStart;
  final int activeEnd;
  final bool holdActivePose;

  int frameAt({
    required int elapsed,
    required int windup,
    required int active,
    required int recovery,
  }) {
    if (windup <= 0 && active <= 0) {
      return _map(elapsed, recovery, 0, frameCount);
    }
    if (elapsed < windup) return _map(elapsed, windup, 0, activeStart);
    if (elapsed < windup + active) {
      return holdActivePose
          ? activeStart
          : _map(elapsed - windup, active, activeStart, activeEnd);
    }
    return _map(elapsed - windup - active, recovery, activeEnd, frameCount);
  }

  int _map(int elapsed, int ticks, int start, int end) {
    if (start >= end) return (start - 1).clamp(0, frameCount - 1);
    if (ticks <= 0) return start;
    final tick = elapsed.clamp(0, ticks - 1);
    if (tick == ticks - 1) return end - 1;
    return (start + tick * (end - start) ~/ ticks).clamp(0, frameCount - 1);
  }
}

/// Reviewed damage capsules for each source-animation pose, including harmless
/// windup/recovery poses. Capsule lists are immutable authored constants.
final class CombatStrikeProfile {
  const CombatStrikeProfile({
    required this.timing,
    required this.frames,
    this.artFacing = Facing.right,
  });

  final ActionFramePolicy timing;
  final List<List<CombatCapsule>> frames;
  final Facing artFacing;

  /// Absolute reach from the source anchor, for AI approach planning only.
  double get reach {
    var result = 0.0;
    for (final frame in frames) {
      for (final capsule in frame) {
        result = math.max(
          result,
          math.max(capsule.minX.abs(), capsule.maxX.abs()),
        );
      }
    }
    return result;
  }
}
