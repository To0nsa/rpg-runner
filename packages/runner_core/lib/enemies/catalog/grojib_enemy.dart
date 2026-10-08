import '../../anim/anim_resolver.dart';
import '../../combat/creature_tag.dart';
import '../../contracts/render_anim_set_definition.dart';
import '../../ecs/stores/body_store.dart';
import '../../ecs/stores/collider_aabb_store.dart';
import '../../ecs/stores/combat/creature_tag_store.dart';
import '../../ecs/stores/health_store.dart';
import '../../ecs/stores/mana_store.dart';
import '../../ecs/stores/stamina_store.dart';
import '../../ecs/stores/world_contact_capsule_store.dart';
import '../../snapshots/enums.dart';
import '../../util/vec2.dart';
import '../death_behavior.dart';
import '../enemy_archetype.dart';
import '../enemy_terrain_profile.dart';

/// Grojib tuning used by the runtime catalog and source-backed editor.
const grojibArchetype = EnemyArchetype(
  body: BodyDef(
    isKinematic: false,
    useGravity: true,
    ignoreCeilings: true,
    gravityScale: 1.0,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  collider: _grojibCollider,
  health: HealthDef(hp: 2000, hpMax: 2000, regenPerSecond100: 50),
  mana: ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
  stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  renderAnim: _grojibRenderAnim,
  renderScale: 1.5,
  animProfile: _grojibAnimProfile,
  hitAnimSeconds: _grojibHitAnimSeconds,
  deathAnimSeconds: _grojibDeathAnimSeconds,
  deathBehavior: DeathBehavior.groundImpactThenDeath,
  primaryMeleeAbilityId: 'grojib.strike',
  comboMeleeAbilityId: 'grojib.strike2',
  tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
);

const ColliderAabbDef _grojibCollider = ColliderAabbDef(
  halfX: 19.5,
  halfY: 25.0,
  offsetX: -4.0,
  offsetY: 18.0,
);

/// Shared terrain policy derived from this enemy's authored collider.
final EnemyTerrainContactProfile grojibTerrainProfile =
    createGroundedEnemyTerrainProfile(
      capsule: WorldContactCapsuleDef.fromAabb(_grojibCollider),
      maxWalkableSlopeDegrees: 45,
      minimumSupportUpComponent: 724,
    );

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
  anchorPoint: Vec2(77.0, 30.0),
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
