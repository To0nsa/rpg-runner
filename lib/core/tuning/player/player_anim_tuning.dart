/// Animation timing tuning (Core-owned, deterministic).
library;

import '../../snapshots/enums.dart';
import '../../util/tick_math.dart';
import 'player_anim_defs.dart';

class AnimTuning {
  const AnimTuning({
    this.hitAnimSeconds = playerAnimHitSeconds,
    this.castAnimSeconds = playerAnimCastSeconds,
    this.attackAnimSeconds = playerAnimAttackSeconds,
    this.deathAnimSeconds = playerAnimDeathSeconds,
    this.spawnAnimSeconds = playerAnimSpawnSeconds,
  });

  /// Computes a recommended duration for a strip based on frame count and step time.
  static double secondsForStrip({
    required int frameCount,
    required double stepTimeSeconds,
  }) {
    if (frameCount <= 0 || stepTimeSeconds <= 0) return 0.0;
    return frameCount * stepTimeSeconds;
  }

  /// Builds an [AnimTuning] from strip frame counts and step times.
  ///
  /// The step times should match the renderer's timing map.
  static AnimTuning fromStripFrames({
    required Map<AnimKey, int> frameCounts,
    required Map<AnimKey, double> stepTimeSecondsByKey,
  }) {
    double secondsFor(AnimKey key) {
      final frames = frameCounts[key] ?? 1;
      final step = stepTimeSecondsByKey[key] ?? 0.10;
      return secondsForStrip(frameCount: frames, stepTimeSeconds: step);
    }

    return AnimTuning(
      hitAnimSeconds: secondsFor(AnimKey.hit),
      castAnimSeconds: secondsFor(AnimKey.cast),
      attackAnimSeconds: secondsFor(AnimKey.attack),
      deathAnimSeconds: secondsFor(AnimKey.death),
      spawnAnimSeconds: secondsFor(AnimKey.spawn),
    );
  }

  /// Duration to hold `AnimKey.hit` after a hit (seconds).
  final double hitAnimSeconds;

  /// Duration to hold `AnimKey.cast` after a cast intent (seconds).
  final double castAnimSeconds;

  /// Duration to hold `AnimKey.attack` after a melee intent (seconds).
  final double attackAnimSeconds;

  /// Duration to hold `AnimKey.death` before ending the run (seconds).
  final double deathAnimSeconds;

  /// Duration to hold `AnimKey.spawn` at run start (seconds).
  final double spawnAnimSeconds;
}

class AnimTuningDerived {
  const AnimTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.hitAnimTicks,
    required this.castAnimTicks,
    required this.attackAnimTicks,
    required this.deathAnimTicks,
    required this.spawnAnimTicks,
  });

  factory AnimTuningDerived.from(AnimTuning base, {required int tickHz}) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return AnimTuningDerived._(
      tickHz: tickHz,
      base: base,
      hitAnimTicks: ticksFromSecondsCeil(base.hitAnimSeconds, tickHz),
      castAnimTicks: ticksFromSecondsCeil(base.castAnimSeconds, tickHz),
      attackAnimTicks: ticksFromSecondsCeil(base.attackAnimSeconds, tickHz),
      deathAnimTicks: ticksFromSecondsCeil(base.deathAnimSeconds, tickHz),
      spawnAnimTicks: ticksFromSecondsCeil(base.spawnAnimSeconds, tickHz),
    );
  }

  final int tickHz;
  final AnimTuning base;

  final int hitAnimTicks;
  final int castAnimTicks;
  final int attackAnimTicks;
  final int deathAnimTicks;
  final int spawnAnimTicks;
}
