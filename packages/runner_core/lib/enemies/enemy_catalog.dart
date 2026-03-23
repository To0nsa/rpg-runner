import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/combat/creature_tag_store.dart';
import '../ecs/stores/combat/damage_resistance_store.dart';
import '../ecs/stores/combat/status_immunity_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import '../combat/creature_tag.dart';
import '../abilities/ability_def.dart';
import '../anim/anim_resolver.dart';
import '../contracts/render_anim_set_definition.dart';
import 'death_behavior.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';
import 'enemy_id.dart';

// -----------------------------------------------------------------------------
// Unoco Demon render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _unocoAnimFrameWidth = 81;
const int _unocoAnimFrameHeight = 71;

const int _unocoAnimIdleFrames = 4;
const double _unocoAnimIdleStepSeconds = 0.12;

const int _unocoAnimStunFrames = 4;
const double _unocoAnimStunStepSeconds = 0.12;

const int _unocoAnimMoveFrames = 4;
const double _unocoAnimMoveStepSeconds = 0.12;

const int _unocoAnimStrikeFrames = 8;
const double _unocoAnimStrikeStepSeconds = 0.06;

const int _unocoAnimHitFrames = 4;
const double _unocoAnimHitStepSeconds = 0.10;

const int _unocoAnimDeathFrames = 7;
const double _unocoAnimDeathStepSeconds = 0.12;

const double _unocoHitAnimSeconds =
    _unocoAnimHitFrames * _unocoAnimHitStepSeconds;
const double _unocoDeathAnimSeconds =
    _unocoAnimDeathFrames * _unocoAnimDeathStepSeconds;

const Map<AnimKey, int> _unocoAnimFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: _unocoAnimIdleFrames,
  AnimKey.stun: _unocoAnimStunFrames,
  AnimKey.run: _unocoAnimMoveFrames,
  AnimKey.strike: _unocoAnimStrikeFrames,
  AnimKey.hit: _unocoAnimHitFrames,
  AnimKey.death: _unocoAnimDeathFrames,
};

const Map<AnimKey, double> _unocoAnimStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: _unocoAnimIdleStepSeconds,
  AnimKey.stun: _unocoAnimStunStepSeconds,
  AnimKey.run: _unocoAnimMoveStepSeconds,
  AnimKey.strike: _unocoAnimStrikeStepSeconds,
  AnimKey.hit: _unocoAnimHitStepSeconds,
  AnimKey.death: _unocoAnimDeathStepSeconds,
};

const Map<AnimKey, String> _unocoAnimSourcesByKey = <AnimKey, String>{
  AnimKey.idle: 'entities/enemies/unoco/flying.png',
  AnimKey.stun: 'entities/enemies/unoco/stun.png',
  AnimKey.run: 'entities/enemies/unoco/flying.png',
  AnimKey.strike: 'entities/enemies/unoco/strike.png',
  AnimKey.hit: 'entities/enemies/unoco/hit.png',
  AnimKey.death: 'entities/enemies/unoco/death.png',
};

const RenderAnimSetDefinition _unocoRenderAnim = RenderAnimSetDefinition(
  frameWidth: _unocoAnimFrameWidth,
  frameHeight: _unocoAnimFrameHeight,
  anchorPoint: Vec2(_unocoAnimFrameWidth * 0.5, _unocoAnimFrameHeight * 0.5),
  sourcesByKey: _unocoAnimSourcesByKey,
  frameCountsByKey: _unocoAnimFrameCountsByKey,
  stepTimeSecondsByKey: _unocoAnimStepTimeSecondsByKey,
);

const AnimProfile _unocoAnimProfile = AnimProfile(
  minMoveSpeed: 1.0,
  runSpeedThresholdX: 0.0,
  supportsWalk: false,
  supportsJumpFall: false,
  supportsStun: true,
  strikeAnimKey: AnimKey.strike,
);

// -----------------------------------------------------------------------------
// grojib (ground enemy) render animation sheet definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _grojibAnimFrameWidth = 108;
const int _grojibAnimFrameHeight = 59;

const int _grojibAnimIdleFrames = 8;
const double _grojibAnimIdleStepSeconds = 0.14;

const int _grojibAnimStunFrames = 8;
const double _grojibAnimStunStepSeconds = 0.14;

const int _grojibAnimMoveFrames = 8;
const double _grojibAnimMoveStepSeconds = 0.08;

const int _grojibAnimWalkFrames = _grojibAnimMoveFrames;
const double _grojibAnimWalkStepSeconds = _grojibAnimMoveStepSeconds;

const int _grojibAnimHitFrames = 3;
const double _grojibAnimHitStepSeconds = 0.10;

const int _grojibAnimDeathFrames = 12;
const double _grojibAnimDeathStepSeconds = 0.12;

// The authored sheet has 20 columns on the strike row:
// - frames 1..8  = Strike
// - frames 9..20 = Strike2
const int _grojibAnimStrikeFrames = 8;
const int _grojibAnimStrike2FrameStart = 8;
const int _grojibAnimStrike2Frames = 12;
const double _grojibAnimStrikeStepSeconds = 0.06;

const int _grojibAnimJumpFrames = 3;
const double _grojibAnimJumpStepSeconds = 0.10;

const int _grojibAnimFallFrames = 3;
const double _grojibAnimFallStepSeconds = 0.10;
const double _grojibHitAnimSeconds =
    _grojibAnimHitFrames * _grojibAnimHitStepSeconds;
const double _grojibDeathAnimSeconds =
    _grojibAnimDeathFrames * _grojibAnimDeathStepSeconds;

const Map<AnimKey, int> _grojibAnimFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: _grojibAnimIdleFrames,
  AnimKey.stun: _grojibAnimStunFrames,
  AnimKey.run: _grojibAnimMoveFrames,
  AnimKey.walk: _grojibAnimWalkFrames,
  AnimKey.strike: _grojibAnimStrikeFrames,
  AnimKey.backStrike: _grojibAnimStrike2Frames,
  AnimKey.strike2: _grojibAnimStrike2Frames,
  AnimKey.hit: _grojibAnimHitFrames,
  AnimKey.death: _grojibAnimDeathFrames,
  AnimKey.jump: _grojibAnimJumpFrames,
  AnimKey.fall: _grojibAnimFallFrames,
};

const Map<AnimKey, double> _grojibAnimStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: _grojibAnimIdleStepSeconds,
  AnimKey.stun: _grojibAnimStunStepSeconds,
  AnimKey.run: _grojibAnimMoveStepSeconds,
  AnimKey.walk: _grojibAnimWalkStepSeconds,
  AnimKey.strike: _grojibAnimStrikeStepSeconds,
  AnimKey.backStrike: _grojibAnimStrikeStepSeconds,
  AnimKey.strike2: _grojibAnimStrikeStepSeconds,
  AnimKey.hit: _grojibAnimHitStepSeconds,
  AnimKey.death: _grojibAnimDeathStepSeconds,
  AnimKey.jump: _grojibAnimJumpStepSeconds,
  AnimKey.fall: _grojibAnimFallStepSeconds,
};

const String _grojibAnimSpriteSheetPath = 'entities/enemies/grojib/grojib.png';

const Map<AnimKey, String> _grojibAnimSourcesByKey = <AnimKey, String>{
  AnimKey.idle: _grojibAnimSpriteSheetPath,
  AnimKey.stun: _grojibAnimSpriteSheetPath,
  AnimKey.run: _grojibAnimSpriteSheetPath,
  AnimKey.walk: _grojibAnimSpriteSheetPath,
  AnimKey.strike: _grojibAnimSpriteSheetPath,
  AnimKey.backStrike: _grojibAnimSpriteSheetPath,
  AnimKey.strike2: _grojibAnimSpriteSheetPath,
  AnimKey.hit: _grojibAnimSpriteSheetPath,
  AnimKey.death: _grojibAnimSpriteSheetPath,
  AnimKey.jump: _grojibAnimSpriteSheetPath,
  AnimKey.fall: _grojibAnimSpriteSheetPath,
};

const Map<AnimKey, int> _grojibAnimRowByKey = <AnimKey, int>{
  AnimKey.idle: 0,
  AnimKey.stun: 0,
  AnimKey.run: 1,
  AnimKey.walk: 1,
  AnimKey.strike: 2,
  AnimKey.backStrike: 2,
  AnimKey.strike2: 2,
  AnimKey.hit: 3,
  AnimKey.death: 4,
  AnimKey.jump: 5,
  AnimKey.fall: 7,
};

const Map<AnimKey, int> _grojibAnimFrameStartByKey = <AnimKey, int>{
  AnimKey.backStrike: _grojibAnimStrike2FrameStart,
  AnimKey.strike2: _grojibAnimStrike2FrameStart,
};

const RenderAnimSetDefinition _grojibRenderAnim = RenderAnimSetDefinition(
  frameWidth: _grojibAnimFrameWidth,
  frameHeight: _grojibAnimFrameHeight,
  anchorPoint: Vec2(77, _grojibAnimFrameHeight * 0.5),
  sourcesByKey: _grojibAnimSourcesByKey,
  rowByKey: _grojibAnimRowByKey,
  frameStartByKey: _grojibAnimFrameStartByKey,
  frameCountsByKey: _grojibAnimFrameCountsByKey,
  stepTimeSecondsByKey: _grojibAnimStepTimeSecondsByKey,
);

const AnimProfile _grojibAnimProfile = AnimProfile(
  minMoveSpeed: 1.0,
  runSpeedThresholdX: 120.0,
  supportsStun: true,
  directionalStrike: true,
);

// -----------------------------------------------------------------------------
// Hashash (ground enemy) render animation sheet definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _hashashAnimFrameWidth = 53;
const int _hashashAnimFrameHeight = 38;

const int _hashashAnimIdleFrames = 8;
const double _hashashAnimIdleStepSeconds = 0.12;

const int _hashashAnimWalkFrames = 8;
const double _hashashAnimWalkStepSeconds = 0.08;

const int _hashashAnimRunFrames = 8;
const double _hashashAnimRunStepSeconds = 0.08;

const int _hashashAnimDashFrames = 8;
const double _hashashAnimDashStepSeconds = 0.07;

const int _hashashAnimStrikeFrames = 13;
const double _hashashAnimStrikeStepSeconds = 0.06;

const int _hashashAnimHitFrames = 3;
const double _hashashAnimHitStepSeconds = 0.10;

const int _hashashAnimDeathFrames = 16;
const double _hashashAnimDeathStepSeconds = 0.10;

const int _hashashAnimJumpFrames = 3;
const double _hashashAnimJumpStepSeconds = 0.10;

const int _hashashAnimFallFrames = 3;
const double _hashashAnimFallStepSeconds = 0.10;

const int _hashashAnimSpawnFrames = 8;
const double _hashashAnimSpawnStepSeconds = 0.12;

const int _hashashAnimTeleportOutFrames = 8;
const double _hashashAnimTeleportOutStepSeconds = 0.06;

const int _hashashAnimAmbushFrames = 12;
const double _hashashAnimAmbushStepSeconds = 0.06;

const double _hashashHitAnimSeconds =
    _hashashAnimHitFrames * _hashashAnimHitStepSeconds;
const double _hashashDeathAnimSeconds =
    _hashashAnimDeathFrames * _hashashAnimDeathStepSeconds;
const double _hashashSpawnAnimSeconds =
    _hashashAnimSpawnFrames * _hashashAnimSpawnStepSeconds;

const Map<AnimKey, int> _hashashAnimFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: _hashashAnimIdleFrames,
  AnimKey.stun: _hashashAnimHitFrames,
  AnimKey.walk: _hashashAnimWalkFrames,
  AnimKey.run: _hashashAnimRunFrames,
  AnimKey.dash: _hashashAnimDashFrames,
  AnimKey.strike: _hashashAnimStrikeFrames,
  AnimKey.hit: _hashashAnimHitFrames,
  AnimKey.death: _hashashAnimDeathFrames,
  AnimKey.jump: _hashashAnimJumpFrames,
  AnimKey.fall: _hashashAnimFallFrames,
  AnimKey.spawn: _hashashAnimSpawnFrames,
  AnimKey.teleportOut: _hashashAnimTeleportOutFrames,
  AnimKey.ambush: _hashashAnimAmbushFrames,
};

const Map<AnimKey, double> _hashashAnimStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: _hashashAnimIdleStepSeconds,
  AnimKey.stun: _hashashAnimHitStepSeconds,
  AnimKey.walk: _hashashAnimWalkStepSeconds,
  AnimKey.run: _hashashAnimRunStepSeconds,
  AnimKey.dash: _hashashAnimDashStepSeconds,
  AnimKey.strike: _hashashAnimStrikeStepSeconds,
  AnimKey.hit: _hashashAnimHitStepSeconds,
  AnimKey.death: _hashashAnimDeathStepSeconds,
  AnimKey.jump: _hashashAnimJumpStepSeconds,
  AnimKey.fall: _hashashAnimFallStepSeconds,
  AnimKey.spawn: _hashashAnimSpawnStepSeconds,
  AnimKey.teleportOut: _hashashAnimTeleportOutStepSeconds,
  AnimKey.ambush: _hashashAnimAmbushStepSeconds,
};

const String _hashashAnimSpriteSheetPath =
    'entities/enemies/hashash/hashash.png';

const Map<AnimKey, String> _hashashAnimSourcesByKey = <AnimKey, String>{
  AnimKey.idle: _hashashAnimSpriteSheetPath,
  AnimKey.stun: _hashashAnimSpriteSheetPath,
  AnimKey.walk: _hashashAnimSpriteSheetPath,
  AnimKey.run: _hashashAnimSpriteSheetPath,
  AnimKey.dash: _hashashAnimSpriteSheetPath,
  AnimKey.strike: _hashashAnimSpriteSheetPath,
  AnimKey.hit: _hashashAnimSpriteSheetPath,
  AnimKey.death: _hashashAnimSpriteSheetPath,
  AnimKey.jump: _hashashAnimSpriteSheetPath,
  AnimKey.fall: _hashashAnimSpriteSheetPath,
  AnimKey.spawn: _hashashAnimSpriteSheetPath,
  AnimKey.teleportOut: _hashashAnimSpriteSheetPath,
  AnimKey.ambush: _hashashAnimSpriteSheetPath,
};

const Map<AnimKey, int> _hashashAnimRowByKey = <AnimKey, int>{
  AnimKey.idle: 0,
  AnimKey.walk: 1,
  AnimKey.run: 1,
  AnimKey.dash: 2,
  AnimKey.strike: 3,
  AnimKey.hit: 4,
  AnimKey.stun: 4,
  AnimKey.death: 5,
  AnimKey.jump: 6,
  AnimKey.fall: 8,
  AnimKey.teleportOut: 9,
  AnimKey.spawn: 11,
  AnimKey.ambush: 10,
};

const RenderAnimSetDefinition _hashashRenderAnim = RenderAnimSetDefinition(
  frameWidth: _hashashAnimFrameWidth,
  frameHeight: _hashashAnimFrameHeight,
  anchorPoint: Vec2(
    _hashashAnimFrameWidth * 0.5,
    _hashashAnimFrameHeight * 0.5,
  ),
  sourcesByKey: _hashashAnimSourcesByKey,
  rowByKey: _hashashAnimRowByKey,
  frameCountsByKey: _hashashAnimFrameCountsByKey,
  stepTimeSecondsByKey: _hashashAnimStepTimeSecondsByKey,
);

const AnimProfile _hashashAnimProfile = AnimProfile(
  minMoveSpeed: 1.0,
  runSpeedThresholdX: 120.0,
  locomotionDashSpeedThresholdX: 260.0,
  supportsDash: true,
  supportsSpawn: true,
  supportsStun: true,
);

// -----------------------------------------------------------------------------
// Derf (stationary caster) render animation sheet definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _derfAnimFrameWidth = 45;
const int _derfAnimFrameHeight = 42;
const String _derfAnimSpriteSheetPath = 'entities/enemies/derf/derf.png';

const int _derfAnimIdleFrames = 6;
const int _derfAnimCastFrames = 10;
const int _derfAnimHitFrames = 3;
const int _derfAnimDeathFrames = 12;

const double _derfAnimIdleStepSeconds = 0.10;
const double _derfAnimCastStepSeconds = 0.08;
const double _derfAnimHitStepSeconds = 0.10;
const double _derfAnimDeathStepSeconds = 0.10;

const double _derfHitAnimSeconds = _derfAnimHitFrames * _derfAnimHitStepSeconds;
const double _derfDeathAnimSeconds =
    _derfAnimDeathFrames * _derfAnimDeathStepSeconds;

const Map<AnimKey, String> _derfAnimSourcesByKey = <AnimKey, String>{
  AnimKey.idle: _derfAnimSpriteSheetPath,
  AnimKey.run: _derfAnimSpriteSheetPath,
  AnimKey.cast: _derfAnimSpriteSheetPath,
  AnimKey.hit: _derfAnimSpriteSheetPath,
  AnimKey.death: _derfAnimSpriteSheetPath,
};

const Map<AnimKey, int> _derfAnimRowByKey = <AnimKey, int>{
  AnimKey.idle: 0,
  AnimKey.run: 0,
  AnimKey.cast: 2,
  AnimKey.hit: 5,
  AnimKey.death: 6,
};

const Map<AnimKey, int> _derfAnimFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: _derfAnimIdleFrames,
  AnimKey.run: _derfAnimIdleFrames,
  AnimKey.cast: _derfAnimCastFrames,
  AnimKey.hit: _derfAnimHitFrames,
  AnimKey.death: _derfAnimDeathFrames,
};

const Map<AnimKey, double> _derfAnimStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: _derfAnimIdleStepSeconds,
  AnimKey.run: _derfAnimIdleStepSeconds,
  AnimKey.cast: _derfAnimCastStepSeconds,
  AnimKey.hit: _derfAnimHitStepSeconds,
  AnimKey.death: _derfAnimDeathStepSeconds,
};

const RenderAnimSetDefinition _derfRenderAnim = RenderAnimSetDefinition(
  frameWidth: _derfAnimFrameWidth,
  frameHeight: _derfAnimFrameHeight,
  anchorPoint: Vec2(_derfAnimFrameWidth * 0.5, _derfAnimFrameHeight * 0.5),
  sourcesByKey: _derfAnimSourcesByKey,
  rowByKey: _derfAnimRowByKey,
  frameCountsByKey: _derfAnimFrameCountsByKey,
  stepTimeSecondsByKey: _derfAnimStepTimeSecondsByKey,
);

const AnimProfile _derfAnimProfile = AnimProfile(
  minMoveSpeed: 1.0,
  runSpeedThresholdX: 120.0,
  supportsJumpFall: false,
  supportsCast: true,
  supportsStun: false,
);

/// Defines the base stats and physics properties for an enemy type.
///
/// This data is "static" (read-only) configuration used to initialize
/// the ECS components effectively when an enemy spawns.
enum EnemyCastTargetPolicy {
  /// Casts directly at the player's current center position.
  playerCenter,

  /// Predicts player center using deterministic lead.
  predictedPlayerCenter,
}

enum EnemyFacingPolicy {
  /// Facing is derived from movement/commits.
  movementDriven,

  /// Facing updates continuously toward the player.
  facePlayerAlways,
}

class EnemyArchetype {
  const EnemyArchetype({
    required this.body,
    required this.collider,
    required this.health,
    required this.mana,
    required this.stamina,
    required this.renderAnim,
    required this.animProfile,
    required this.hitAnimSeconds,
    required this.deathAnimSeconds,
    this.spawnAnimSeconds = 0.0,
    this.deathBehavior = DeathBehavior.instant,
    this.primaryCastAbilityId,
    this.castTargetPolicy = EnemyCastTargetPolicy.predictedPlayerCenter,
    this.facingPolicy = EnemyFacingPolicy.movementDriven,
    this.primaryMeleeAbilityId,
    this.comboMeleeAbilityId,
    this.artFacingDir = Facing.left,
    this.tags = const CreatureTagDef(),
    this.resistance = const DamageResistanceDef(),
    this.statusImmunity = const StatusImmunityDef(),
  });

  /// Physics configuration (Gravity, Constraints, Kinematics).
  final BodyDef body;

  /// Hitbox size (Collision).
  final ColliderAabbDef collider;

  /// Vitals (HP, Mana, Stamina) configuration.
  final HealthDef health;
  final ManaDef mana;
  final StaminaDef stamina;

  /// Render-only animation metadata (strip paths, frame size, timing).
  final RenderAnimSetDefinition renderAnim;

  /// Core animation profile (movement thresholds and supported keys).
  final AnimProfile animProfile;

  /// Duration the hit animation should be visible (seconds).
  final double hitAnimSeconds;

  /// Duration the death animation should be visible (seconds).
  final double deathAnimSeconds;

  /// Duration the spawn animation should be visible (seconds).
  final double spawnAnimSeconds;

  /// Behavior for death transition timing (instant vs ground impact).
  final DeathBehavior deathBehavior;

  /// Optional primary cast ability for this enemy.
  final AbilityKey? primaryCastAbilityId;

  /// Target selection policy used by enemy cast systems.
  final EnemyCastTargetPolicy castTargetPolicy;

  /// Facing update policy for this archetype.
  final EnemyFacingPolicy facingPolicy;

  /// Optional primary melee ability for this enemy.
  ///
  /// When present, melee engagement/commit systems resolve timing + payload from
  /// this ability definition.
  final AbilityKey? primaryMeleeAbilityId;

  /// Optional follow-up melee ability used by combo-capable enemies.
  final AbilityKey? comboMeleeAbilityId;

  /// Direction the authored art faces when not mirrored.
  ///
  /// Most sprites face right by default, but some packs are authored facing
  /// left. The renderer uses this to mirror correctly based on logical [Facing].
  final Facing artFacingDir;

  /// Broad tags used by combat rules and content filters.
  final CreatureTagDef tags;

  /// Resistance/vulnerability modifiers by damage type.
  final DamageResistanceDef resistance;

  /// Status effect immunities for this enemy.
  final StatusImmunityDef statusImmunity;
}

/// Central registry for Enemy Definitions.
///
/// **Usage**:
/// - Accessed by `EnemySpawnSystem` (or similar) to hydration entities.
/// - Decouples "What an enemy is" from "How to spawn it".
class EnemyCatalog {
  const EnemyCatalog();

  /// Returns the static archetype definition for a given [EnemyId].
  ///
  /// Note: The returned objects are `const` and allocation-light.
  EnemyArchetype get(EnemyId id) {
    switch (id) {
      case EnemyId.unocoDemon:
        return const EnemyArchetype(
          body: BodyDef(
            isKinematic: false,
            useGravity: false,
            gravityScale: 0.0,
            sideMask: BodyDef.sideNone,
            maxVelX: 800.0,
            maxVelY: 800.0,
          ),
          collider: ColliderAabbDef(halfX: 12.0, halfY: 12.0),
          health: HealthDef(hp: 2000, hpMax: 2000, regenPerSecond100: 50),
          mana: ManaDef(mana: 8000, manaMax: 8000, regenPerSecond100: 500),
          stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
          renderAnim: _unocoRenderAnim,
          animProfile: _unocoAnimProfile,
          hitAnimSeconds: _unocoHitAnimSeconds,
          deathAnimSeconds: _unocoDeathAnimSeconds,
          deathBehavior: DeathBehavior.instant,
          primaryCastAbilityId: 'unoco.fire_bolt_cast',
          castTargetPolicy: EnemyCastTargetPolicy.predictedPlayerCenter,
          primaryMeleeAbilityId: 'unoco.strike',
          artFacingDir: Facing.left,
          tags: CreatureTagDef(
            mask: CreatureTagMask.flying | CreatureTagMask.demon,
          ),
          resistance: DamageResistanceDef(fireBp: -5000, iceBp: 5000),
        );

      case EnemyId.grojib:
        return const EnemyArchetype(
          body: BodyDef(
            isKinematic: false,
            useGravity: true,
            ignoreCeilings: true,
            gravityScale: 1.0,
            sideMask: BodyDef.sideLeft | BodyDef.sideRight,
          ),
          collider: ColliderAabbDef(
            halfX: 25.0,
            halfY: 25.0,
            offsetX: 0.0,
            offsetY: 20.0,
          ),
          health: HealthDef(hp: 2000, hpMax: 2000, regenPerSecond100: 50),
          mana: ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
          stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
          renderAnim: _grojibRenderAnim,
          animProfile: _grojibAnimProfile,
          hitAnimSeconds: _grojibHitAnimSeconds,
          deathAnimSeconds: _grojibDeathAnimSeconds,
          deathBehavior: DeathBehavior.groundImpactThenDeath,
          primaryMeleeAbilityId: 'grojib.strike',
          comboMeleeAbilityId: 'grojib.strike2',
          tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
        );
      case EnemyId.hashash:
        return const EnemyArchetype(
          body: BodyDef(
            isKinematic: false,
            useGravity: true,
            ignoreCeilings: true,
            gravityScale: 1.0,
            sideMask: BodyDef.sideLeft | BodyDef.sideRight,
          ),
          collider: ColliderAabbDef(
            halfX: 14.0,
            halfY: 16.0,
            offsetX: 0.0,
            offsetY: 12.0,
          ),
          health: HealthDef(hp: 1600, hpMax: 1600, regenPerSecond100: 50),
          mana: ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
          stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
          renderAnim: _hashashRenderAnim,
          animProfile: _hashashAnimProfile,
          hitAnimSeconds: _hashashHitAnimSeconds,
          deathAnimSeconds: _hashashDeathAnimSeconds,
          spawnAnimSeconds: _hashashSpawnAnimSeconds,
          deathBehavior: DeathBehavior.groundImpactThenDeath,
          primaryMeleeAbilityId: 'hashash.strike',
          tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
        );
      case EnemyId.derf:
        return const EnemyArchetype(
          body: BodyDef(
            isKinematic: true,
            useGravity: false,
            gravityScale: 0.0,
            sideMask: BodyDef.sideNone,
          ),
          collider: ColliderAabbDef(
            halfX: 12.0,
            halfY: 16.0,
            offsetX: 0.0,
            offsetY: 6.0,
          ),
          health: HealthDef(hp: 2200, hpMax: 2200, regenPerSecond100: 40),
          mana: ManaDef(mana: 10000, manaMax: 10000, regenPerSecond100: 600),
          stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
          renderAnim: _derfRenderAnim,
          animProfile: _derfAnimProfile,
          hitAnimSeconds: _derfHitAnimSeconds,
          deathAnimSeconds: _derfDeathAnimSeconds,
          deathBehavior: DeathBehavior.instant,
          primaryCastAbilityId: 'derf.fire_explosion',
          castTargetPolicy: EnemyCastTargetPolicy.predictedPlayerCenter,
          facingPolicy: EnemyFacingPolicy.facePlayerAlways,
          artFacingDir: Facing.left,
          tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
          resistance: DamageResistanceDef(fireBp: -3000, iceBp: 2000),
        );
    }
  }
}
