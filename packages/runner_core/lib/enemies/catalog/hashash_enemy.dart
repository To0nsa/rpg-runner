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

/// Hashash tuning used by the runtime catalog and source-backed editor.
const hashashArchetype = EnemyArchetype(
  body: BodyDef(
    isKinematic: false,
    useGravity: true,
    ignoreCeilings: true,
    gravityScale: 1.0,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  collider: _hashashCollider,
  health: HealthDef(hp: 1600, hpMax: 1600, regenPerSecond100: 50),
  mana: ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
  stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  renderAnim: _hashashRenderAnim,
  renderScale: 1.5,
  animProfile: _hashashAnimProfile,
  hitAnimSeconds: _hashashHitAnimSeconds,
  deathAnimSeconds: _hashashDeathAnimSeconds,
  spawnAnimSeconds: _hashashSpawnAnimSeconds,
  deathBehavior: DeathBehavior.groundImpactThenDeath,
  primaryMeleeAbilityId: 'hashash.strike',
  tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
);

const ColliderAabbDef _hashashCollider = ColliderAabbDef(
  halfX: 14.0,
  halfY: 21.5,
  offsetX: -1.0,
  offsetY: 7.0,
);

/// Shared terrain policy derived from this enemy's authored collider.
final EnemyTerrainContactProfile hashashTerrainProfile =
    createGroundedEnemyTerrainProfile(
      capsule: WorldContactCapsuleDef.fromAabb(_hashashCollider),
      maxWalkableSlopeDegrees: 60,
      minimumSupportUpComponent: 512,
    );

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
  anchorPoint: Vec2(32.0, 19.0),
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
