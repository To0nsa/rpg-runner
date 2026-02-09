/// Shared animation resolver for Core entities.
library;

import '../enemies/death_behavior.dart';
import '../snapshots/enums.dart';

/// Configuration profile for an entity's animation capabilities and key mappings.
///
/// Defines which animations are supported (walk, jump, cast, etc.) and maps them
/// to specific [AnimKey]s in the animation atlas.
class AnimProfile {
  const AnimProfile({
    required this.minMoveSpeed,
    required this.runSpeedThresholdX,
    this.supportsWalk = true,
    this.supportsJumpFall = true,
    this.supportsDash = false,
    this.supportsCast = false,
    this.supportsRanged = false,
    this.supportsSpawn = false,
    this.supportsStun = false,
    this.directionalStrike = false,
    this.strikeAnimKey = AnimKey.strike,
    this.idleAnimKey = AnimKey.idle,
    this.walkAnimKey = AnimKey.walk,
    this.runAnimKey = AnimKey.run,
    this.jumpAnimKey = AnimKey.jump,
    this.fallAnimKey = AnimKey.fall,
    this.castAnimKey = AnimKey.cast,
    this.rangedAnimKey = AnimKey.ranged,
    this.dashAnimKey = AnimKey.dash,
    this.hitAnimKey = AnimKey.hit,
    this.deathAnimKey = AnimKey.death,
    this.spawnAnimKey = AnimKey.spawn,
    this.stunAnimKey = AnimKey.stun,
  });

  final double minMoveSpeed;
  final double runSpeedThresholdX;
  final bool supportsWalk;
  final bool supportsJumpFall;
  final bool supportsDash;
  final bool supportsCast;
  final bool supportsRanged;
  final bool supportsSpawn;
  final bool supportsStun;
  final bool directionalStrike;

  final AnimKey strikeAnimKey;
  final AnimKey idleAnimKey;
  final AnimKey walkAnimKey;
  final AnimKey runAnimKey;
  final AnimKey jumpAnimKey;
  final AnimKey fallAnimKey;
  final AnimKey castAnimKey;
  final AnimKey rangedAnimKey;
  final AnimKey dashAnimKey;
  final AnimKey hitAnimKey;
  final AnimKey deathAnimKey;
  final AnimKey spawnAnimKey;
  final AnimKey stunAnimKey;
}

/// Input state signals required to resolve the current animation frame.
///
/// Contains all relevant entity state (velocity, flags, timers) that affects
/// animation selection. This class is immutable and typically constructed
/// via [AnimSignals.player] or [AnimSignals.enemy] factories.
class AnimSignals {
  const AnimSignals._({
    required this.tick,
    required this.hp,
    required this.deathPhase,
    this.deathStartTick = -1,
    this.grounded = false,
    this.velX = 0.0,
    this.velY = 0.0,
    this.lastDamageTick = -1,
    this.hitAnimTicks = 0,
    this.spawnStartTick = -1,
    this.spawnAnimTicks = 0,
    this.stunLocked = false,
    this.stunStartTick = -1,
    this.activeActionAnim,
    this.activeActionFrame = 0,
  });

  factory AnimSignals.player({
    required int tick,
    required int hp,
    DeathPhase deathPhase = DeathPhase.none,
    int deathStartTick = -1,
    bool grounded = false,
    double velX = 0.0,
    double velY = 0.0,
    int lastDamageTick = -1,
    int hitAnimTicks = 0,
    int spawnStartTick = 0,
    int spawnAnimTicks = 0,
    bool stunLocked = false,
    int stunStartTick = -1,
    AnimKey? activeActionAnim,
    int activeActionFrame = 0,
  }) {
    return AnimSignals._(
      tick: tick,
      hp: hp,
      deathPhase: deathPhase,
      deathStartTick: deathStartTick,
      grounded: grounded,
      velX: velX,
      velY: velY,
      lastDamageTick: lastDamageTick,
      hitAnimTicks: hitAnimTicks,
      spawnStartTick: spawnStartTick,
      spawnAnimTicks: spawnAnimTicks,
      stunLocked: stunLocked,
      stunStartTick: stunStartTick,
      activeActionAnim: activeActionAnim,
      activeActionFrame: activeActionFrame,
    );
  }

  factory AnimSignals.enemy({
    required int tick,
    required int hp,
    required DeathPhase deathPhase,
    int deathStartTick = -1,
    bool grounded = false,
    double velX = 0.0,
    double velY = 0.0,
    int lastDamageTick = -1,
    int hitAnimTicks = 0,
    bool stunLocked = false,
    int stunStartTick = -1,
    AnimKey? activeActionAnim,
    int activeActionFrame = 0,
  }) {
    return AnimSignals._(
      tick: tick,
      hp: hp,
      deathPhase: deathPhase,
      deathStartTick: deathStartTick,
      grounded: grounded,
      velX: velX,
      velY: velY,
      lastDamageTick: lastDamageTick,
      hitAnimTicks: hitAnimTicks,
      stunLocked: stunLocked,
      stunStartTick: stunStartTick,
      activeActionAnim: activeActionAnim,
      activeActionFrame: activeActionFrame,
    );
  }
  final int tick;
  final int hp;
  final DeathPhase deathPhase;
  final int deathStartTick;
  final bool grounded;
  final double velX;
  final double velY;
  final int lastDamageTick;
  final int hitAnimTicks;
  final int spawnStartTick;
  final int spawnAnimTicks;
  final bool stunLocked;
  final int stunStartTick;
  final AnimKey? activeActionAnim;
  final int activeActionFrame;
}

/// The result of the animation resolution process.
///
/// Contains the resolved [AnimKey] and the specific frame index (or tick) to render.
class AnimResult {
  const AnimResult({required this.anim, required this.animFrame});

  final AnimKey anim;
  final int animFrame;
}

/// Pure logic resolver for determining the current animation.
///
/// Takes a static [AnimProfile] and dynamic [AnimSignals] to determine
/// the correct [AnimResult] based on a strictly prioritized state machine.
class AnimResolver {
  /// Resolves the current animation based on the provided profile and signals.
  ///
  /// Priority Order:
  /// 1. Stun (if stun locked)
  /// 2. Death (if dying or dead)
  /// 3. Hit React (if taking damage)
  /// 4. Active Action (manual overrides from abilities)
  /// 5. Movement (Jump/Fall > Spawn > Run > Walk > Idle)
  ///
  /// Frame-origin policy:
  /// - Relative-to-start: stun, death, hit, active action, spawn.
  /// - Global tick: jump, fall, idle, walk, run.
  ///
  /// Locomotion branches use global tick intentionally to keep loops phase-
  /// continuous through brief state toggles (for example grounded jitter).
  static AnimResult resolve(AnimProfile profile, AnimSignals signals) {
    final tick = signals.tick;
    final lastDamageTick = signals.lastDamageTick;
    final showHit =
        signals.hitAnimTicks > 0 &&
        lastDamageTick >= 0 &&
        (tick - lastDamageTick) < signals.hitAnimTicks;

    // 1. Stun
    if (profile.supportsStun && signals.stunLocked) {
      return AnimResult(
        anim: profile.stunAnimKey,
        animFrame: _frameFromTick(tick, signals.stunStartTick),
      );
    }

    // 2. Death
    if (signals.deathPhase == DeathPhase.deathAnim) {
      return AnimResult(
        anim: profile.deathAnimKey,
        animFrame: _frameFromTick(tick, signals.deathStartTick),
      );
    }
    if (signals.deathPhase == DeathPhase.fallingUntilGround) {
      if (profile.supportsJumpFall && !signals.grounded) {
        return AnimResult(
          anim: signals.velY < 0 ? profile.jumpAnimKey : profile.fallAnimKey,
          animFrame: tick,
        );
      }
      return AnimResult(anim: profile.idleAnimKey, animFrame: tick);
    }
    if (signals.hp <= 0) {
      // Legacy compatibility fallback: if lifecycle plumbing failed to provide
      // deathStartTick, hold at frame 0 instead of deriving from stale hit data.
      if (signals.deathStartTick < 0) {
        return AnimResult(anim: profile.deathAnimKey, animFrame: 0);
      }
      return AnimResult(
        anim: profile.deathAnimKey,
        animFrame: _frameFromTick(tick, signals.deathStartTick),
      );
    }

    // 3. Hit React
    if (showHit) {
      return AnimResult(
        anim: profile.hitAnimKey,
        animFrame: _frameFromTick(tick, lastDamageTick),
      );
    }

    // 4. Active Action Layer.
    if (signals.activeActionAnim != null) {
      final actionKey = _mapActiveActionKey(profile, signals.activeActionAnim!);
      if (actionKey != null) {
        return AnimResult(
          anim: actionKey,
          animFrame: signals.activeActionFrame,
        );
      }
    }

    // Locomotion loops intentionally use global tick as frame origin.
    if (profile.supportsJumpFall && !signals.grounded) {
      return AnimResult(
        anim: signals.velY < 0 ? profile.jumpAnimKey : profile.fallAnimKey,
        animFrame: tick,
      );
    }
    if (profile.supportsSpawn &&
        signals.spawnAnimTicks > 0 &&
        signals.spawnStartTick >= 0) {
      final spawnElapsed = tick - signals.spawnStartTick;
      if (spawnElapsed >= 0 && spawnElapsed < signals.spawnAnimTicks) {
        return AnimResult(
          anim: profile.spawnAnimKey,
          animFrame: _frameFromTick(tick, signals.spawnStartTick),
        );
      }
    }

    final speedX = signals.velX.abs();
    if (speedX <= profile.minMoveSpeed) {
      return AnimResult(anim: profile.idleAnimKey, animFrame: tick);
    }
    if (profile.supportsWalk && speedX < profile.runSpeedThresholdX) {
      return AnimResult(anim: profile.walkAnimKey, animFrame: tick);
    }
    return AnimResult(anim: profile.runAnimKey, animFrame: tick);
  }

  /// Maps a tick to a frame index.
  static int _frameFromTick(int tick, int startTick) {
    if (startTick < 0) return tick;
    final frame = tick - startTick;
    return frame < 0 ? 0 : frame;
  }

  /// Maps an [AnimKey] to the corresponding [AnimKey] for the given [AnimProfile].
  static AnimKey? _mapActiveActionKey(AnimProfile profile, AnimKey key) {
    switch (key) {
      case AnimKey.strike:
        return profile.strikeAnimKey;
      case AnimKey.backStrike:
        return profile.directionalStrike
            ? AnimKey.backStrike
            : profile.strikeAnimKey;
      case AnimKey.cast:
        return profile.supportsCast ? profile.castAnimKey : null;
      case AnimKey.ranged:
        return profile.supportsRanged ? profile.rangedAnimKey : null;
      case AnimKey.dash:
        return profile.supportsDash ? profile.dashAnimKey : null;
      case AnimKey.jump:
        return profile.supportsJumpFall ? profile.jumpAnimKey : null;
      case AnimKey.fall:
        return profile.supportsJumpFall ? profile.fallAnimKey : null;
      case AnimKey.roll:
        return profile.supportsDash ? key : null;
      case AnimKey.parry:
      case AnimKey.shieldBash:
      case AnimKey.shieldBlock:
        // Explicitly allow authored one-off action strips.
        return key;
      default:
        return null;
    }
  }
}
