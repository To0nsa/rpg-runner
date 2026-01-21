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
    this.directionalAttack = false,
    this.attackAnimKey = AnimKey.attack,
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
  });

  final double minMoveSpeed;
  final double runSpeedThresholdX;
  final bool supportsWalk;
  final bool supportsJumpFall;
  final bool supportsDash;
  final bool supportsCast;
  final bool supportsRanged;
  final bool supportsSpawn;
  final bool directionalAttack;

  final AnimKey attackAnimKey;
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
}

class AnimSignals {
  const AnimSignals._({
    required this.tick,
    required this.hp,
    required this.deathPhase,
    required this.deathStartTick,
    required this.grounded,
    required this.velX,
    required this.velY,
    required this.lastDamageTick,
    required this.hitAnimTicks,
    required this.lastAttackTick,
    required this.attackAnimTicks,
    required this.attackBackAnimTicks,
    required this.lastAttackFacing,
    required this.lastCastTick,
    required this.castAnimTicks,
    required this.lastRangedTick,
    required this.rangedAnimTicks,
    required this.dashTicksLeft,
    required this.dashDurationTicks,
    required this.spawnAnimTicks,
  });

  const AnimSignals.player({
    required int tick,
    required double hp,
    required bool grounded,
    required double velX,
    required double velY,
    required int lastDamageTick,
    required int hitAnimTicks,
    required int lastAttackTick,
    required int attackAnimTicks,
    required int attackBackAnimTicks,
    required Facing lastAttackFacing,
    required int lastCastTick,
    required int castAnimTicks,
    required int lastRangedTick,
    required int rangedAnimTicks,
    required int dashTicksLeft,
    required int dashDurationTicks,
    required int spawnAnimTicks,
  }) : this._(
          tick: tick,
          hp: hp,
          deathPhase: DeathPhase.none,
          deathStartTick: -1,
          grounded: grounded,
          velX: velX,
          velY: velY,
          lastDamageTick: lastDamageTick,
         hitAnimTicks: hitAnimTicks,
         lastAttackTick: lastAttackTick,
         attackAnimTicks: attackAnimTicks,
         attackBackAnimTicks: attackBackAnimTicks,
         lastAttackFacing: lastAttackFacing,
         lastCastTick: lastCastTick,
         castAnimTicks: castAnimTicks,
         lastRangedTick: lastRangedTick,
         rangedAnimTicks: rangedAnimTicks,
         dashTicksLeft: dashTicksLeft,
         dashDurationTicks: dashDurationTicks,
         spawnAnimTicks: spawnAnimTicks,
       );

  const AnimSignals.enemy({
    required int tick,
    required double hp,
    required DeathPhase deathPhase,
    required int deathStartTick,
    required bool grounded,
    required double velX,
    required double velY,
    required int lastDamageTick,
    required int hitAnimTicks,
    required int lastAttackTick,
    required int attackAnimTicks,
    required Facing lastAttackFacing,
  }) : this._(
          tick: tick,
          hp: hp,
          deathPhase: deathPhase,
          deathStartTick: deathStartTick,
          grounded: grounded,
          velX: velX,
          velY: velY,
          lastDamageTick: lastDamageTick,
         hitAnimTicks: hitAnimTicks,
         lastAttackTick: lastAttackTick,
         attackAnimTicks: attackAnimTicks,
         attackBackAnimTicks: attackAnimTicks,
         lastAttackFacing: lastAttackFacing,
         lastCastTick: -1,
         castAnimTicks: 0,
         lastRangedTick: -1,
         rangedAnimTicks: 0,
         dashTicksLeft: 0,
         dashDurationTicks: 0,
         spawnAnimTicks: 0,
       );

  final int tick;
  final double hp;
  final DeathPhase deathPhase;
  final int deathStartTick;
  final bool grounded;
  final double velX;
  final double velY;
  final int lastDamageTick;
  final int hitAnimTicks;
  final int lastAttackTick;
  final int attackAnimTicks;
  final int attackBackAnimTicks;
  final Facing lastAttackFacing;
  final int lastCastTick;
  final int castAnimTicks;
  final int lastRangedTick;
  final int rangedAnimTicks;
  final int dashTicksLeft;
  final int dashDurationTicks;
  final int spawnAnimTicks;
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

    final attackTicks =
        profile.directionalAttack &&
            signals.lastAttackFacing == Facing.left
        ? signals.attackBackAnimTicks
        : signals.attackAnimTicks;
    final showAttack =
        attackTicks > 0 &&
        signals.lastAttackTick >= 0 &&
        (tick - signals.lastAttackTick) < attackTicks;
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
    if (showAttack) {
      final attackKey =
          profile.directionalAttack &&
              signals.lastAttackFacing == Facing.left
          ? AnimKey.attackBack
          : profile.attackAnimKey;
      return AnimResult(
        anim: attackKey,
        animFrame: _frameFromTick(tick, signals.lastAttackTick),
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
}
