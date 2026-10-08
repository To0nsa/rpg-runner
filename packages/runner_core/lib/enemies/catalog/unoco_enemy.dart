import '../../anim/anim_resolver.dart';
import '../../combat/ai_cast_aim_policy.dart';
import '../../combat/creature_tag.dart';
import '../../contracts/render_anim_set_definition.dart';
import '../../ecs/stores/body_store.dart';
import '../../ecs/stores/collider_aabb_store.dart';
import '../../ecs/stores/combat/creature_tag_store.dart';
import '../../ecs/stores/combat/damage_resistance_store.dart';
import '../../ecs/stores/health_store.dart';
import '../../ecs/stores/mana_store.dart';
import '../../ecs/stores/stamina_store.dart';
import '../../ecs/stores/world_contact_capsule_store.dart';
import '../../snapshots/enums.dart';
import '../../util/vec2.dart';
import '../death_behavior.dart';
import '../enemy_archetype.dart';
import '../enemy_terrain_profile.dart';

/// Unoco Demon tuning used by the runtime catalog and source-backed editor.
const unocoArchetype = EnemyArchetype(
  body: BodyDef(
    isKinematic: false,
    useGravity: false,
    gravityScale: 0.0,
    sideMask: BodyDef.sideNone,
    maxVelX: 800.0,
    maxVelY: 800.0,
  ),
  collider: _unocoCollider,
  health: HealthDef(hp: 2000, hpMax: 2000, regenPerSecond100: 50),
  mana: ManaDef(mana: 8000, manaMax: 8000, regenPerSecond100: 500),
  stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  renderAnim: _unocoRenderAnim,
  renderScale: 0.5,
  animProfile: _unocoAnimProfile,
  hitAnimSeconds: _unocoHitAnimSeconds,
  deathAnimSeconds: _unocoDeathAnimSeconds,
  deathBehavior: DeathBehavior.instant,
  primaryCastAbilityId: 'unoco.fire_bolt_cast',
  castOriginOffset: 20.0,
  castTargetPolicy: AiCastAimPolicy.predictedTargetCenter,
  primaryMeleeAbilityId: 'unoco.strike',
  artFacingDir: Facing.left,
  tags: CreatureTagDef(mask: CreatureTagMask.flying | CreatureTagMask.demon),
  resistance: DamageResistanceDef(fireBp: -5000, iceBp: 5000),
);

const ColliderAabbDef _unocoCollider = ColliderAabbDef(
  halfX: 8.125,
  halfY: 8.625,
  offsetX: 0.0,
  offsetY: 2.0,
);

/// Shared terrain policy derived from this enemy's authored collider.
final EnemyTerrainContactProfile unocoTerrainProfile =
    createFlyingEnemyTerrainProfile(
      capsule: WorldContactCapsuleDef.fromAabb(_unocoCollider),
    );

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
  AnimKey.cast: _unocoAnimStrikeFrames,
  AnimKey.hit: _unocoAnimHitFrames,
  AnimKey.death: _unocoAnimDeathFrames,
};

const Map<AnimKey, double> _unocoAnimStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: _unocoAnimIdleStepSeconds,
  AnimKey.stun: _unocoAnimStunStepSeconds,
  AnimKey.run: _unocoAnimMoveStepSeconds,
  AnimKey.strike: _unocoAnimStrikeStepSeconds,
  AnimKey.cast: _unocoAnimStrikeStepSeconds,
  AnimKey.hit: _unocoAnimHitStepSeconds,
  AnimKey.death: _unocoAnimDeathStepSeconds,
};

const Map<AnimKey, String> _unocoAnimSourcesByKey = <AnimKey, String>{
  AnimKey.idle: 'entities/enemies/unoco/flying.png',
  AnimKey.stun: 'entities/enemies/unoco/stun.png',
  AnimKey.run: 'entities/enemies/unoco/flying.png',
  AnimKey.strike: 'entities/enemies/unoco/strike.png',
  AnimKey.cast: 'entities/enemies/unoco/strike.png',
  AnimKey.hit: 'entities/enemies/unoco/hit.png',
  AnimKey.death: 'entities/enemies/unoco/death.png',
};

const RenderAnimSetDefinition _unocoRenderAnim = RenderAnimSetDefinition(
  frameWidth: _unocoAnimFrameWidth,
  frameHeight: _unocoAnimFrameHeight,
  anchorPoint: Vec2(29.0, 36.0),
  sourcesByKey: _unocoAnimSourcesByKey,
  frameCountsByKey: _unocoAnimFrameCountsByKey,
  stepTimeSecondsByKey: _unocoAnimStepTimeSecondsByKey,
);

const AnimProfile _unocoAnimProfile = AnimProfile(
  supportsCast: true,
  minMoveSpeed: 1.0,
  runSpeedThresholdX: 0.0,
  supportsWalk: false,
  supportsJumpFall: false,
  supportsStun: true,
  strikeAnimKey: AnimKey.strike,
);
