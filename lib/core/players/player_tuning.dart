/// Player tuning (single-file source of truth).
///
/// This module intentionally centralizes all player-specific tuning:
/// movement + resources + abilities + combat + animation (and derived/cache
/// variants). This keeps per-character definitions DRY: they can reference a
/// single import and override only what differs.
library;

import '../snapshots/enums.dart';
import '../util/tick_math.dart';
import '../tuning/utils/anim_tuning.dart' as anim_utils;

// ─────────────────────────────────────────────────────────────────────────────
// Player animation strip definitions (frame counts / step times) live in
// character files (e.g. `lib/core/players/characters/eloise.dart`).
// ─────────────────────────────────────────────────────────────────────────────

// Keep [AnimTuning] windows in sync with the selected character's strips.

// ─────────────────────────────────────────────────────────────────────────────
// Player movement tuning (author in seconds, applied per fixed tick)
// ─────────────────────────────────────────────────────────────────────────────

const int defaultTickHz = 60;

class MovementTuning {
  const MovementTuning({
    this.maxSpeedX = 200,
    this.accelerationX = 600,
    this.decelerationX = 400,
    this.minMoveSpeed = 5,
    this.runSpeedThresholdX = 60,
    this.maxVelX = 1500,
    this.maxVelY = 1500,
    this.jumpSpeed = 500,
    this.coyoteTimeSeconds = 0.10,
    this.jumpBufferSeconds = 0.12,
    this.dashSpeedX = 550,
    this.dashDurationSeconds = 0.20,
    this.dashCooldownSeconds = 2.0,
  });

  final double maxSpeedX;
  final double accelerationX;
  final double decelerationX;
  final double minMoveSpeed;
  final double runSpeedThresholdX;

  final double maxVelX;
  final double maxVelY;

  final double jumpSpeed;

  final double coyoteTimeSeconds;
  final double jumpBufferSeconds;

  final double dashSpeedX;
  final double dashDurationSeconds;
  final double dashCooldownSeconds;
}

class MovementTuningDerived {
  const MovementTuningDerived._({
    required this.tickHz,
    required this.dtSeconds,
    required this.base,
    required this.coyoteTicks,
    required this.jumpBufferTicks,
    required this.dashDurationTicks,
    required this.dashCooldownTicks,
  });

  factory MovementTuningDerived.from(MovementTuning base, {required int tickHz}) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }
    return MovementTuningDerived._(
      tickHz: tickHz,
      dtSeconds: 1.0 / tickHz,
      base: base,
      coyoteTicks: ticksFromSecondsCeil(base.coyoteTimeSeconds, tickHz),
      jumpBufferTicks: ticksFromSecondsCeil(base.jumpBufferSeconds, tickHz),
      dashDurationTicks: ticksFromSecondsCeil(base.dashDurationSeconds, tickHz),
      dashCooldownTicks: ticksFromSecondsCeil(base.dashCooldownSeconds, tickHz),
    );
  }

  final int tickHz;
  final double dtSeconds;
  final MovementTuning base;

  final int coyoteTicks;
  final int jumpBufferTicks;
  final int dashDurationTicks;
  final int dashCooldownTicks;
}

// ─────────────────────────────────────────────────────────────────────────────
// Player resources tuning (hp/mana/stamina + regen + costs)
// ─────────────────────────────────────────────────────────────────────────────

class ResourceTuning {
  const ResourceTuning({
    this.playerHpMax = 100,
    this.playerHpRegenPerSecond = 0.5,
    this.playerManaMax = 100,
    this.playerManaRegenPerSecond = 2.0,
    this.playerStaminaMax = 100,
    this.playerStaminaRegenPerSecond = 1.0,
    this.jumpStaminaCost = 2,
    this.dashStaminaCost = 2,
  });

  final double playerHpMax;
  final double playerHpRegenPerSecond;

  final double playerManaMax;
  final double playerManaRegenPerSecond;

  final double playerStaminaMax;
  final double playerStaminaRegenPerSecond;

  final double jumpStaminaCost;
  final double dashStaminaCost;
}

// ─────────────────────────────────────────────────────────────────────────────
// Player ability tuning (cast, melee)
// ─────────────────────────────────────────────────────────────────────────────

class AbilityTuning {
  const AbilityTuning({
    this.castCooldownSeconds = 0.25,
    this.meleeCooldownSeconds = 0.30,
    this.meleeActiveSeconds = 0.10,
    this.meleeStaminaCost = 5.0,
    this.meleeDamage = 15.0,
    this.meleeHitboxSizeX = 32.0,
    this.meleeHitboxSizeY = 16.0,
  });

  final double castCooldownSeconds;
  final double meleeCooldownSeconds;
  final double meleeActiveSeconds;

  final double meleeStaminaCost;
  final double meleeDamage;

  final double meleeHitboxSizeX;
  final double meleeHitboxSizeY;
}

class AbilityTuningDerived {
  const AbilityTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.castCooldownTicks,
    required this.meleeCooldownTicks,
    required this.meleeActiveTicks,
  });

  factory AbilityTuningDerived.from(AbilityTuning base, {required int tickHz}) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return AbilityTuningDerived._(
      tickHz: tickHz,
      base: base,
      castCooldownTicks: ticksFromSecondsCeil(base.castCooldownSeconds, tickHz),
      meleeCooldownTicks: ticksFromSecondsCeil(base.meleeCooldownSeconds, tickHz),
      meleeActiveTicks: ticksFromSecondsCeil(base.meleeActiveSeconds, tickHz),
    );
  }

  final int tickHz;
  final AbilityTuning base;

  final int castCooldownTicks;
  final int meleeCooldownTicks;
  final int meleeActiveTicks;
}

// ─────────────────────────────────────────────────────────────────────────────
// Player combat tuning (invulnerability)
// ─────────────────────────────────────────────────────────────────────────────

class CombatTuning {
  const CombatTuning({this.invulnerabilitySeconds = 0.25});

  final double invulnerabilitySeconds;
}

class CombatTuningDerived {
  const CombatTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.invulnerabilityTicks,
  });

  factory CombatTuningDerived.from(CombatTuning base, {required int tickHz}) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return CombatTuningDerived._(
      tickHz: tickHz,
      base: base,
      invulnerabilityTicks: ticksFromSecondsCeil(
        base.invulnerabilitySeconds,
        tickHz,
      ),
    );
  }

  final int tickHz;
  final CombatTuning base;

  final int invulnerabilityTicks;
}

// ─────────────────────────────────────────────────────────────────────────────
// Player animation tuning (timing windows)
// ─────────────────────────────────────────────────────────────────────────────

class AnimTuning {
  const AnimTuning({
    this.hitAnimSeconds = 0.40,
    this.castAnimSeconds = 0.40,
    this.attackAnimSeconds = 0.36,
    this.attackBackAnimSeconds = 0.36,
    this.rangedAnimSeconds = 0.40,
    this.deathAnimSeconds = 0.72,
    this.spawnAnimSeconds = 0.56,
  });

  static AnimTuning fromStripFrames({
    required Map<AnimKey, int> frameCounts,
    required Map<AnimKey, double> stepTimeSecondsByKey,
  }) {
    final castSeconds = anim_utils.secondsForKey(
      key: AnimKey.cast,
      frameCounts: frameCounts,
      stepTimeSecondsByKey: stepTimeSecondsByKey,
    );
    final attackSeconds = anim_utils.secondsForKey(
      key: AnimKey.attack,
      frameCounts: frameCounts,
      stepTimeSecondsByKey: stepTimeSecondsByKey,
    );
    return AnimTuning(
      hitAnimSeconds: anim_utils.secondsForKey(
        key: AnimKey.hit,
        frameCounts: frameCounts,
        stepTimeSecondsByKey: stepTimeSecondsByKey,
      ),
      castAnimSeconds: castSeconds,
      attackAnimSeconds: attackSeconds,
      attackBackAnimSeconds:
          (frameCounts.containsKey(AnimKey.attackBack) ||
                  stepTimeSecondsByKey.containsKey(AnimKey.attackBack))
              ? anim_utils.secondsForKey(
                  key: AnimKey.attackBack,
                  frameCounts: frameCounts,
                  stepTimeSecondsByKey: stepTimeSecondsByKey,
                )
              : attackSeconds,
      rangedAnimSeconds:
          (frameCounts.containsKey(AnimKey.ranged) ||
                  stepTimeSecondsByKey.containsKey(AnimKey.ranged))
              ? anim_utils.secondsForKey(
                  key: AnimKey.ranged,
                  frameCounts: frameCounts,
                  stepTimeSecondsByKey: stepTimeSecondsByKey,
                )
              : castSeconds,
      deathAnimSeconds: anim_utils.secondsForKey(
        key: AnimKey.death,
        frameCounts: frameCounts,
        stepTimeSecondsByKey: stepTimeSecondsByKey,
      ),
      spawnAnimSeconds: anim_utils.secondsForKey(
        key: AnimKey.spawn,
        frameCounts: frameCounts,
        stepTimeSecondsByKey: stepTimeSecondsByKey,
      ),
    );
  }

  final double hitAnimSeconds;
  final double castAnimSeconds;
  final double attackAnimSeconds;
  final double attackBackAnimSeconds;
  final double rangedAnimSeconds;
  final double deathAnimSeconds;
  final double spawnAnimSeconds;
}

class AnimTuningDerived {
  const AnimTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.hitAnimTicks,
    required this.castAnimTicks,
    required this.attackAnimTicks,
    required this.attackBackAnimTicks,
    required this.rangedAnimTicks,
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
      attackBackAnimTicks: ticksFromSecondsCeil(base.attackBackAnimSeconds, tickHz),
      rangedAnimTicks: ticksFromSecondsCeil(base.rangedAnimSeconds, tickHz),
      deathAnimTicks: ticksFromSecondsCeil(base.deathAnimSeconds, tickHz),
      spawnAnimTicks: ticksFromSecondsCeil(base.spawnAnimSeconds, tickHz),
    );
  }

  final int tickHz;
  final AnimTuning base;

  final int hitAnimTicks;
  final int castAnimTicks;
  final int attackAnimTicks;
  final int attackBackAnimTicks;
  final int rangedAnimTicks;
  final int deathAnimTicks;
  final int spawnAnimTicks;
}

// ─────────────────────────────────────────────────────────────────────────────
// Player tuning bundle + derived compiler (composition)
// ─────────────────────────────────────────────────────────────────────────────

class PlayerTuning {
  const PlayerTuning({
    this.movement = const MovementTuning(),
    this.resource = const ResourceTuning(),
    this.ability = const AbilityTuning(),
    this.anim = const AnimTuning(),
    this.combat = const CombatTuning(),
  });

  final MovementTuning movement;
  final ResourceTuning resource;
  final AbilityTuning ability;
  final AnimTuning anim;
  final CombatTuning combat;

  PlayerTuning copyWith({
    MovementTuning? movement,
    ResourceTuning? resource,
    AbilityTuning? ability,
    AnimTuning? anim,
    CombatTuning? combat,
  }) {
    return PlayerTuning(
      movement: movement ?? this.movement,
      resource: resource ?? this.resource,
      ability: ability ?? this.ability,
      anim: anim ?? this.anim,
      combat: combat ?? this.combat,
    );
  }
}

class PlayerTuningDerived {
  const PlayerTuningDerived({
    required this.movement,
    required this.ability,
    required this.anim,
    required this.combat,
  });

  final MovementTuningDerived movement;
  final AbilityTuningDerived ability;
  final AnimTuningDerived anim;
  final CombatTuningDerived combat;
}

class PlayerTuningCompiler {
  const PlayerTuningCompiler({required this.tickHz});

  final int tickHz;

  PlayerTuningDerived compile(PlayerTuning base) {
    return PlayerTuningDerived(
      movement: MovementTuningDerived.from(base.movement, tickHz: tickHz),
      ability: AbilityTuningDerived.from(base.ability, tickHz: tickHz),
      anim: AnimTuningDerived.from(base.anim, tickHz: tickHz),
      combat: CombatTuningDerived.from(base.combat, tickHz: tickHz),
    );
  }
}
