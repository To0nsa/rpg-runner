class JumpProfile {
  const JumpProfile({
    required this.jumpSpeed,
    required this.gravityY,
    required this.maxAirTicks,
    required this.airSpeedX,
    required this.dtSeconds,
    required this.agentHalfWidth,
  }) : assert(maxAirTicks > 0),
       assert(dtSeconds > 0);

  /// Instantaneous jump vertical speed (negative is upward).
  final double jumpSpeed;

  /// Gravity acceleration (positive is downward).
  final double gravityY;

  /// Fixed tick timestep (seconds).
  final double dtSeconds;

  /// Maximum air time horizon to consider (ticks).
  final int maxAirTicks;

  /// Assumed constant horizontal speed while airborne.
  final double airSpeedX;

  /// Collider half-width (used by callers when clamping landing ranges).
  final double agentHalfWidth;
}

class JumpSample {
  const JumpSample({
    required this.tick,
    required this.prevY,
    required this.y,
    required this.velY,
    required this.maxDx,
  });

  final int tick;
  final double prevY;
  final double y;
  final double velY;
  final double maxDx;
}

class JumpLanding {
  const JumpLanding({required this.tick, required this.maxDx});

  final int tick;
  final double maxDx;
}

class JumpReachabilityTemplate {
  JumpReachabilityTemplate._({
    required this.profile,
    required this.samples,
    required this.minDy,
    required this.maxDy,
    required this.maxDx,
  });

  final JumpProfile profile;
  final List<JumpSample> samples;
  final double minDy;
  final double maxDy;
  final double maxDx;

  factory JumpReachabilityTemplate.build(JumpProfile profile) {
    final samples = <JumpSample>[];

    var y = 0.0;
    var velY = -profile.jumpSpeed;
    final dt = profile.dtSeconds;
    var minDy = 0.0;
    var maxDy = 0.0;
    var maxDxOverall = 0.0;

    for (var tick = 1; tick <= profile.maxAirTicks; tick += 1) {
      final prevY = y;
      velY += profile.gravityY * dt;
      y += velY * dt;
      final maxDx = profile.airSpeedX * dt * tick;
      if (y < minDy) minDy = y;
      if (y > maxDy) maxDy = y;
      if (maxDx > maxDxOverall) maxDxOverall = maxDx;
      samples.add(
        JumpSample(
          tick: tick,
          prevY: prevY,
          y: y,
          velY: velY,
          maxDx: maxDx,
        ),
      );
    }

    return JumpReachabilityTemplate._(
      profile: profile,
      samples: List<JumpSample>.unmodifiable(samples),
      minDy: minDy,
      maxDy: maxDy,
      maxDx: maxDxOverall,
    );
  }

  /// Returns the earliest landing tick whose vertical crossing is descending
  /// and whose horizontal reach overlaps [dxMin, dxMax].
  JumpLanding? findFirstLanding({
    required double dy,
    required double dxMin,
    required double dxMax,
    double eps = 1e-6,
  }) {
    if (dxMin > dxMax) return null;

    for (final sample in samples) {
      if (sample.velY < 0) continue; // Still ascending.
      final crosses =
          (sample.prevY <= dy + eps) && (sample.y >= dy - eps);
      if (!crosses) continue;

      final maxDx = sample.maxDx;
      if (dxMin > maxDx + eps) continue;
      if (dxMax < -maxDx - eps) continue;
      return JumpLanding(tick: sample.tick, maxDx: maxDx);
    }

    return null;
  }
}

int estimateFallTicks({
  required double dy,
  required double gravityY,
  required double dtSeconds,
  required int maxTicks,
}) {
  if (dy <= 0) return 0;
  var y = 0.0;
  var velY = 0.0;
  for (var tick = 1; tick <= maxTicks; tick += 1) {
    velY += gravityY * dtSeconds;
    y += velY * dtSeconds;
    if (y >= dy) return tick;
  }
  return maxTicks;
}
