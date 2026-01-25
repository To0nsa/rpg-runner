library;

import '../../ecs/stores/body_store.dart';
import '../../ecs/stores/combat/creature_tag_store.dart';
import '../../ecs/stores/combat/damage_resistance_store.dart';
import '../../ecs/stores/combat/equipped_loadout_store.dart';
import '../../ecs/stores/combat/status_immunity_store.dart';
import '../../combat/creature_tag.dart';
import '../../snapshots/enums.dart';
import '../../projectiles/projectile_item_id.dart';
import '../../weapons/weapon_id.dart';
import '../player_character_definition.dart';
import '../player_catalog.dart';
import '../player_tuning.dart';
import '../../contracts/render_anim_set_definition.dart';

/// Baseline character definition: Éloïse.
///
/// All current "default player" values in v0 are treated as belonging to Éloïse.

// -----------------------------------------------------------------------------
// Éloïse render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int eloiseAnimFrameWidth = 100;
const int eloiseAnimFrameHeight = 64;

const int eloiseAnimIdleFrames = 4;
const double eloiseAnimIdleStepSeconds = 0.14;

const int eloiseAnimStunFrames = 4;
const double eloiseAnimStunStepSeconds = 0.14;

const int eloiseAnimRunFrames = 7;
const double eloiseAnimRunStepSeconds = 0.08;

const int eloiseAnimWalkFrames = 7;
const double eloiseAnimWalkStepSeconds = 0.16;

const int eloiseAnimJumpFrames = 6;
const double eloiseAnimJumpStepSeconds = 0.10;

const int eloiseAnimFallFrames = 3;
const double eloiseAnimFallStepSeconds = 0.10;

const int eloiseAnimStrikeFrames = 6;
const double eloiseAnimStrikeStepSeconds = 0.06;

const int eloiseAnimBackStrikeFrames = 5;
const double eloiseAnimBackStrikeStepSeconds = 0.08;

const int eloiseAnimParryFrames = 6;
const double eloiseAnimParryStepSeconds = 0.06;

const int eloiseAnimCastFrames = 5;
const double eloiseAnimCastStepSeconds = 0.08;

const int eloiseAnimRangedFrames = eloiseAnimCastFrames;
const double eloiseAnimRangedStepSeconds = eloiseAnimCastStepSeconds;

const int eloiseAnimDashFrames = 4;
const double eloiseAnimDashStepSeconds = 0.05;

const int eloiseAnimRollFrames = 10;
const double eloiseAnimRollStepSeconds = 0.05;

const int eloiseAnimHitFrames = 4;
const double eloiseAnimHitStepSeconds = 0.10;

const int eloiseAnimDeathFrames = 6;
const double eloiseAnimDeathStepSeconds = 0.12;

// Spawn reuses idle timing/frames until a dedicated strip exists.
const int eloiseAnimSpawnFrames = eloiseAnimIdleFrames;
const double eloiseAnimSpawnStepSeconds = eloiseAnimIdleStepSeconds;

const Map<AnimKey, int> eloiseAnimFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: eloiseAnimIdleFrames,
  AnimKey.stun: eloiseAnimStunFrames,
  AnimKey.run: eloiseAnimRunFrames,
  AnimKey.jump: eloiseAnimJumpFrames,
  AnimKey.fall: eloiseAnimFallFrames,
  AnimKey.strike: eloiseAnimStrikeFrames,
  AnimKey.backStrike: eloiseAnimBackStrikeFrames,
  AnimKey.parry: eloiseAnimParryFrames,
  AnimKey.cast: eloiseAnimCastFrames,
  AnimKey.ranged: eloiseAnimRangedFrames,
  AnimKey.dash: eloiseAnimDashFrames,
  AnimKey.roll: eloiseAnimRollFrames,
  AnimKey.hit: eloiseAnimHitFrames,
  AnimKey.death: eloiseAnimDeathFrames,
  AnimKey.spawn: eloiseAnimSpawnFrames,
  AnimKey.walk: eloiseAnimWalkFrames,
};

const Map<AnimKey, double> eloiseAnimStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: eloiseAnimIdleStepSeconds,
  AnimKey.stun: eloiseAnimStunStepSeconds,
  AnimKey.run: eloiseAnimRunStepSeconds,
  AnimKey.jump: eloiseAnimJumpStepSeconds,
  AnimKey.fall: eloiseAnimFallStepSeconds,
  AnimKey.strike: eloiseAnimStrikeStepSeconds,
  AnimKey.backStrike: eloiseAnimBackStrikeStepSeconds,
  AnimKey.parry: eloiseAnimParryStepSeconds,
  AnimKey.cast: eloiseAnimCastStepSeconds,
  AnimKey.ranged: eloiseAnimRangedStepSeconds,
  AnimKey.dash: eloiseAnimDashStepSeconds,
  AnimKey.roll: eloiseAnimRollStepSeconds,
  AnimKey.hit: eloiseAnimHitStepSeconds,
  AnimKey.death: eloiseAnimDeathStepSeconds,
  AnimKey.spawn: eloiseAnimSpawnStepSeconds,
  AnimKey.walk: eloiseAnimWalkStepSeconds,
};

const Map<AnimKey, String> eloiseAnimSourcesByKey = <AnimKey, String>{
  AnimKey.idle: 'entities/player/idle.png',
  AnimKey.stun: 'entities/player/stun.png',
  AnimKey.run: 'entities/player/move.png',
  AnimKey.jump: 'entities/player/jump.png',
  AnimKey.fall: 'entities/player/fall.png',
  AnimKey.strike: 'entities/player/strike.png',
  AnimKey.backStrike: 'entities/player/back_strike.png',
  AnimKey.parry: 'entities/player/parry.png',
  AnimKey.cast: 'entities/player/cast.png',
  AnimKey.ranged: 'entities/player/cast.png',
  AnimKey.dash: 'entities/player/dash.png',
  AnimKey.roll: 'entities/player/roll.png',
  AnimKey.hit: 'entities/player/hit.png',
  AnimKey.death: 'entities/player/death.png',
  AnimKey.spawn: 'entities/player/idle.png',
  AnimKey.walk: 'entities/player/walk.png',
};

const RenderAnimSetDefinition eloiseRenderAnim = RenderAnimSetDefinition(
  frameWidth: eloiseAnimFrameWidth,
  frameHeight: eloiseAnimFrameHeight,
  sourcesByKey: eloiseAnimSourcesByKey,
  frameCountsByKey: eloiseAnimFrameCountsByKey,
  stepTimeSecondsByKey: eloiseAnimStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Éloïse authored Core values (single-file source of truth)
// -----------------------------------------------------------------------------

const PlayerCatalog eloiseCatalog = PlayerCatalog(
  bodyTemplate: BodyDef(
    isKinematic: false,
    useGravity: true,
    ignoreCeilings: false,
    topOnlyGround: true,
    gravityScale: 1.0,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  colliderWidth: 22.0,
  colliderHeight: 46.0,
  colliderOffsetX: 0.0,
  colliderOffsetY: 0.0,
  tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
  resistance: DamageResistanceDef(),
  statusImmunity: StatusImmunityDef(),
  loadoutSlotMask: LoadoutSlotMask.defaultMask,
  weaponId: WeaponId.basicSword,
  offhandWeaponId: WeaponId.basicShield,
  projectileItemId: ProjectileItemId.fireBolt,
  facing: Facing.right,
);

const PlayerTuning eloiseTuning = PlayerTuning(
  movement: MovementTuning(
    maxSpeedX: 200,
    accelerationX: 600,
    decelerationX: 400,
    minMoveSpeed: 5,
    runSpeedThresholdX: 120,
    maxVelX: 1500,
    maxVelY: 1500,
    jumpSpeed: 500,
    coyoteTimeSeconds: 0.10,
    jumpBufferSeconds: 0.12,
    dashSpeedX: 550,
    dashDurationSeconds: 0.20,
    dashCooldownSeconds: 2.0,
  ),
  resource: ResourceTuning(
    playerHpMax: 100,
    playerHpRegenPerSecond: 0.5,
    playerManaMax: 100,
    playerManaRegenPerSecond: 2.0,
    playerStaminaMax: 100,
    playerStaminaRegenPerSecond: 1.0,
    jumpStaminaCost: 2,
    dashStaminaCost: 2,
  ),
  ability: AbilityTuning(
    castCooldownSeconds: 0.25,
    meleeCooldownSeconds: 0.30,
    meleeActiveSeconds: 0.10,
    meleeStaminaCost: 5.0,
    meleeDamage: 15.0,
    meleeHitboxSizeX: 32.0,
    meleeHitboxSizeY: 32.0,
  ),
  // Keep these windows in sync with Éloïse's render strips above.
  anim: AnimTuning(
    hitAnimSeconds: eloiseAnimHitFrames * eloiseAnimHitStepSeconds,
    castAnimSeconds: eloiseAnimCastFrames * eloiseAnimCastStepSeconds,
    strikeAnimSeconds: eloiseAnimStrikeFrames * eloiseAnimStrikeStepSeconds,
    backStrikeAnimSeconds:
        eloiseAnimBackStrikeFrames * eloiseAnimBackStrikeStepSeconds,
    parryAnimSeconds: eloiseAnimParryFrames * eloiseAnimParryStepSeconds,
    rangedAnimSeconds: eloiseAnimRangedFrames * eloiseAnimRangedStepSeconds,
    dashAnimSeconds: eloiseAnimDashFrames * eloiseAnimDashStepSeconds,
    rollAnimSeconds: eloiseAnimRollFrames * eloiseAnimRollStepSeconds,
    deathAnimSeconds: eloiseAnimDeathFrames * eloiseAnimDeathStepSeconds,
    spawnAnimSeconds: eloiseAnimSpawnFrames * eloiseAnimSpawnStepSeconds,
  ),
  combat: CombatTuning(invulnerabilitySeconds: 0.25),
);

const PlayerCharacterDefinition eloiseCharacter = PlayerCharacterDefinition(
  id: PlayerCharacterId.eloise,
  displayName: 'Éloïse',
  renderAnim: eloiseRenderAnim,
  catalog: eloiseCatalog,
  tuning: eloiseTuning,
);
