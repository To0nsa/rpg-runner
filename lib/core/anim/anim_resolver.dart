/// Shared animation resolver for Core entities.
library;

import '../enemies/death_behavior.dart';
import '../snapshots/enums.dart';

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
    this.lastStrikeTick = -1,
    this.strikeAnimTicks = 0,
    this.backStrikeAnimTicks = 0,
    this.lastStrikeFacing = Facing.right,
    this.lastCastTick = -1,
    this.castAnimTicks = 0,
    this.lastRangedTick = -1,
    this.rangedAnimTicks = 0,
    this.dashTicksLeft = 0,
    this.dashDurationTicks = 0,
    this.facing = Facing.right,
    this.spawnStartTick = -1,
    this.spawnAnimTicks = 0,
    this.stunLocked = false,
    this.activeActionAnim,
    this.activeActionFrame = 0,
  });

  factory AnimSignals.player({
    required int tick,
    required int hp,
    bool grounded = false,
    double velX = 0.0,
    double velY = 0.0,
    int lastDamageTick = -1,
    int hitAnimTicks = 0,
    int lastStrikeTick = -1,
    int strikeAnimTicks = 0,
    int backStrikeAnimTicks = 0,
    Facing lastStrikeFacing = Facing.right,
    int lastCastTick = -1,
    int castAnimTicks = 0,
    int lastRangedTick = -1,
    int rangedAnimTicks = 0,
    int dashTicksLeft = 0,
    int dashDurationTicks = 0,
    Facing facing = Facing.right,
    int spawnStartTick = -1,
    int spawnAnimTicks = 0,
    bool stunLocked = false,
    AnimKey? activeActionAnim,
    int activeActionFrame = 0,
  }) {
    return AnimSignals._(
      tick: tick,
      hp: hp,
      deathPhase: DeathPhase.none,
      grounded: grounded,
      velX: velX,
      velY: velY,
      lastDamageTick: lastDamageTick,
      hitAnimTicks: hitAnimTicks,
      lastStrikeTick: lastStrikeTick,
      strikeAnimTicks: strikeAnimTicks,
      backStrikeAnimTicks: backStrikeAnimTicks,
      lastStrikeFacing: lastStrikeFacing,
      lastCastTick: lastCastTick,
      castAnimTicks: castAnimTicks,
      lastRangedTick: lastRangedTick,
      rangedAnimTicks: rangedAnimTicks,
      dashTicksLeft: dashTicksLeft,
      dashDurationTicks: dashDurationTicks,
      facing: facing,
      spawnStartTick: spawnStartTick,
      spawnAnimTicks: spawnAnimTicks,
      stunLocked: stunLocked,
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
    int lastStrikeTick = -1,
    int strikeAnimTicks = 0,
    Facing lastStrikeFacing = Facing.right,
    bool stunLocked = false,
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
      lastStrikeTick: lastStrikeTick,
      strikeAnimTicks: strikeAnimTicks,
      lastStrikeFacing: lastStrikeFacing,
      stunLocked: stunLocked,
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
  final int lastStrikeTick;
  final int strikeAnimTicks;
  final int backStrikeAnimTicks;
  final Facing lastStrikeFacing;
  final int lastCastTick;
  final int castAnimTicks;
  final int lastRangedTick;
  final int rangedAnimTicks;
  final int dashTicksLeft;
  final int dashDurationTicks;
  final Facing facing;
  final int spawnStartTick;
  final int spawnAnimTicks;
  final bool stunLocked;
  final AnimKey? activeActionAnim;
  final int activeActionFrame;
}

class AnimResult {
  const AnimResult({required this.anim, required this.animFrame});

  final AnimKey anim;
  final int animFrame;
}

class AnimResolver {
  static AnimResult resolve(AnimProfile profile, AnimSignals signals) {
    final tick = signals.tick;
    final lastDamageTick = signals.lastDamageTick;
    final showHit =
        signals.hitAnimTicks > 0 &&
        lastDamageTick >= 0 &&
        (tick - lastDamageTick) < signals.hitAnimTicks;

    // 4. Stun
    // Stun takes priority over actions and movement, but below death/spawn.
    // However, spawn is usually handled by death behavior or a separate phase.
    // Death overrides stun.
    if (profile.supportsStun && signals.stunLocked) {
      // Stun is usually a loop, so we can use tick % duration if it were multi-frame.
      // But usually it's a single frame or simple loop.
      // We'll treat it as a loop for now (or single frame 0 if animation is 1 frame).
      return AnimResult(anim: profile.stunAnimKey, animFrame: signals.tick);
    }

    // 5. Actions (Dash, Strike, Cast, Ranged, Hit)
    // Hit reaction
    final strikeTicks =
        profile.directionalStrike &&
            signals.lastStrikeFacing == Facing.left
        ? signals.backStrikeAnimTicks
        : signals.strikeAnimTicks;
    final showStrike =
        strikeTicks > 0 &&
        signals.lastStrikeTick >= 0 &&
        (tick - signals.lastStrikeTick) < strikeTicks;
    final showCast =
        profile.supportsCast &&
        signals.castAnimTicks > 0 &&
        signals.lastCastTick >= 0 &&
        (tick - signals.lastCastTick) < signals.castAnimTicks;
    final showRanged =
        profile.supportsRanged &&
        signals.rangedAnimTicks > 0 &&
        signals.lastRangedTick >= 0 &&
        (tick - signals.lastRangedTick) < signals.rangedAnimTicks;

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
      return AnimResult(
        anim: profile.deathAnimKey,
        animFrame: _frameFromTick(tick, lastDamageTick),
      );
    }
    if (showHit) {
      return AnimResult(
        anim: profile.hitAnimKey,
        animFrame: _frameFromTick(tick, lastDamageTick),
      );
    }

    // Phase 6: Active Action Layer
    // Overrides legacy action logic (Strike, Cast, Ranged, Dash).
    if (signals.activeActionAnim != null) {
      final actionKey = _mapActiveActionKey(
        profile,
        signals.activeActionAnim!,
      );
      if (actionKey != null) {
        return AnimResult(
          anim: actionKey,
          animFrame: signals.activeActionFrame,
        );
      }
    }

    if (showStrike) {
      final strikeKey =
          profile.directionalStrike &&
              signals.lastStrikeFacing == Facing.left
          ? AnimKey.backStrike
          : profile.strikeAnimKey;
      return AnimResult(
        anim: strikeKey,
        animFrame: _frameFromTick(tick, signals.lastStrikeTick),
      );
    }
    if (showCast) {
      return AnimResult(
        anim: profile.castAnimKey,
        animFrame: _frameFromTick(tick, signals.lastCastTick),
      );
    }
    if (showRanged) {
      return AnimResult(
        anim: profile.rangedAnimKey,
        animFrame: _frameFromTick(tick, signals.lastRangedTick),
      );
    }
    if (profile.supportsDash && signals.dashTicksLeft > 0) {
      final frame = signals.dashDurationTicks - signals.dashTicksLeft;
      return AnimResult(
        anim: profile.dashAnimKey,
        animFrame: frame < 0 ? 0 : frame,
      );
    }
    if (profile.supportsJumpFall && !signals.grounded) {
      return AnimResult(
        anim: signals.velY < 0 ? profile.jumpAnimKey : profile.fallAnimKey,
        animFrame: tick,
      );
    }
    if (profile.supportsSpawn &&
        signals.spawnAnimTicks > 0 &&
        tick < signals.spawnAnimTicks) {
      return AnimResult(anim: profile.spawnAnimKey, animFrame: tick);
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

  static int _frameFromTick(int tick, int startTick) {
    return startTick >= 0 ? tick - startTick : tick;
  }

  static AnimKey? _mapActiveActionKey(AnimProfile profile, AnimKey key) {
    switch (key) {
      case AnimKey.strike:
        return profile.strikeAnimKey;
      case AnimKey.backStrike:
        return profile.directionalStrike ? AnimKey.backStrike : profile.strikeAnimKey;
      case AnimKey.cast:
        return profile.supportsCast ? profile.castAnimKey : null;
      case AnimKey.ranged:
        return profile.supportsRanged ? profile.rangedAnimKey : null;
      case AnimKey.throwItem:
        return profile.supportsRanged ? key : null;
      case AnimKey.dash:
        return profile.supportsDash ? profile.dashAnimKey : null;
      default:
        return key;
    }
  }
}
