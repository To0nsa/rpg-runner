import '../anim/anim_resolver.dart';
import '../abilities/ability_def.dart';
import '../contracts/render_anim_set_definition.dart';
import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import '../ecs/stores/world_contact_capsule_store.dart';
import '../enemies/enemy_terrain_profile.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';
import 'npc_id.dart';

/// Close-range opener followed by repeat attacks against each successfully hit foe.
/// History belongs to the NPC and survives target changes and bleed expiry.
final class NpcMeleeSequence {
  const NpcMeleeSequence({
    required this.openerAbilityId,
    required this.followUpAbilityId,
    required this.range,
  });

  final AbilityKey openerAbilityId;
  final AbilityKey followUpAbilityId;

  /// Horizontal reach in world pixels; the NPC's half-height gates vertical reach.
  final double range;
}

/// Allied actor tuning uses its own identity, never an enemy score identifier.
final class NpcArchetype {
  const NpcArchetype({
    required this.collider,
    required this.renderAnim,
    required this.attackAbilityId,
    // 37 HP in hundredths gives all allied archetypes the same health budget.
    this.health = const HealthDef(hp: 3700, hpMax: 3700, regenPerSecond100: 0),
    this.renderScale = 1.5,
    this.speedX = 100,
    this.jumpSpeed = 360,
    this.attackRange = 52,
    this.meleeSequence,
    this.castOriginOffset,
    this.castOriginOffsetY = 0,
  });
  final ColliderAabbDef collider;
  final HealthDef health;
  final RenderAnimSetDefinition renderAnim;
  final String attackAbilityId;
  final double renderScale;
  final double speedX;
  final double jumpSpeed;
  final double attackRange;

  /// Takes priority over the default attack when the opponent is in melee reach.
  final NpcMeleeSequence? meleeSequence;
  final double? castOriginOffset;
  final double castOriginOffsetY;
  Facing get artFacing => Facing.right;
  BodyDef get body => const BodyDef(
    useGravity: true,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  );
  ManaDef get mana => const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0);
  StaminaDef get stamina =>
      const StaminaDef(stamina: 4000, staminaMax: 4000, regenPerSecond100: 600);
  AnimProfile get animProfile => const AnimProfile(
    minMoveSpeed: 1,
    runSpeedThresholdX: 0,
    supportsWalk: false,
    supportsJumpFall: true,
    supportsStun: true,
    supportsCast: true,
    strikeAnimKey: AnimKey.strike,
  );
}

/// Imported allies share actor mechanics while retaining catalog-owned shapes.
class NpcCatalog {
  const NpcCatalog();
  static const supportedIds = NpcId.values;

  NpcArchetype get(NpcId id) => switch (id) {
    NpcId.warrior => _warrior,
    NpcId.huntress => _huntress,
    NpcId.huntress2 => _huntress2,
  };

  EnemyTerrainContactProfile terrainContactProfile(NpcId id) => switch (id) {
    NpcId.warrior => _warriorTerrain,
    NpcId.huntress => _huntressTerrain,
    NpcId.huntress2 => _huntress2Terrain,
  };
}

// Reviewed source: 135px cells, idle body pixels approximately x=59..78,
// y=48..86. The capsule follows the torso/legs rather than the sword silhouette.
const _warriorCollider = ColliderAabbDef(
  halfX: 13.5,
  halfY: 27,
  offsetX: 1.5,
  offsetY: 0,
);
final _warriorTerrain = createGroundedEnemyTerrainProfile(
  capsule: WorldContactCapsuleDef.fromAabb(_warriorCollider),
  maxWalkableSlopeDegrees: 45,
  minimumSupportUpComponent: 724,
);
const _warrior = NpcArchetype(
  renderScale: 1.5,
  collider: _warriorCollider,
  attackAbilityId: 'npc_warrior.slash',
  renderAnim: RenderAnimSetDefinition(
    frameWidth: 135,
    frameHeight: 135,
    anchorPoint: Vec2(67, 68),
    sourcesByKey: {
      AnimKey.idle: 'entities/npc/medieval_warrior_pack_3/idle.png',
      AnimKey.stun: 'entities/npc/medieval_warrior_pack_3/idle.png',
      AnimKey.run: 'entities/npc/medieval_warrior_pack_3/run.png',
      AnimKey.jump: 'entities/npc/medieval_warrior_pack_3/jump.png',
      AnimKey.fall: 'entities/npc/medieval_warrior_pack_3/fall.png',
      AnimKey.strike: 'entities/npc/medieval_warrior_pack_3/attack1.png',
      AnimKey.hit: 'entities/npc/medieval_warrior_pack_3/get_hit.png',
      AnimKey.death: 'entities/npc/medieval_warrior_pack_3/death.png',
    },
    frameCountsByKey: {
      AnimKey.idle: 10,
      AnimKey.stun: 10,
      AnimKey.run: 6,
      AnimKey.jump: 2,
      AnimKey.fall: 2,
      AnimKey.strike: 4,
      AnimKey.hit: 3,
      AnimKey.death: 9,
    },
    stepTimeSecondsByKey: {
      AnimKey.idle: .12,
      AnimKey.stun: .12,
      AnimKey.run: .1,
      AnimKey.jump: .12,
      AnimKey.fall: .12,
      AnimKey.strike: .1,
      AnimKey.hit: .1,
      AnimKey.death: .12,
    },
  ),
);

// Feet end at source y=97/67. Anchors keep each standing capsule on that line;
// spear, bow, hair and transient attack arcs are excluded from the body capsule.
const _huntressCollider = ColliderAabbDef(
  halfX: 13.5,
  halfY: 27,
  offsetX: 3,
  offsetY: 0,
);
const _huntress2Collider = ColliderAabbDef(
  halfX: 12,
  halfY: 27,
  offsetX: 0,
  offsetY: 0,
);
final _huntressTerrain = createGroundedEnemyTerrainProfile(
  capsule: WorldContactCapsuleDef.fromAabb(_huntressCollider),
  maxWalkableSlopeDegrees: 45,
  minimumSupportUpComponent: 724,
);
final _huntress2Terrain = createGroundedEnemyTerrainProfile(
  capsule: WorldContactCapsuleDef.fromAabb(_huntress2Collider),
  maxWalkableSlopeDegrees: 45,
  minimumSupportUpComponent: 724,
);
const _huntress = NpcArchetype(
  renderScale: 1.5,
  collider: _huntressCollider,
  health: HealthDef(hp: 3700, hpMax: 3700, regenPerSecond100: 0),
  speedX: 90,
  attackRange: 260,
  attackAbilityId: 'npc_huntress.throw_spear',
  meleeSequence: NpcMeleeSequence(
    openerAbilityId: 'npc_huntress.stab',
    followUpAbilityId: 'npc_huntress.slash',
    range: 52, // World pixels: same engagement reach as the allied warrior.
  ),
  castOriginOffset: 18,
  castOriginOffsetY: -31.5,
  renderAnim: RenderAnimSetDefinition(
    frameWidth: 150,
    frameHeight: 150,
    anchorPoint: Vec2(75, 79),
    sourcesByKey: {
      AnimKey.idle: 'entities/npc/huntress/idle.png',
      AnimKey.stun: 'entities/npc/huntress/idle.png',
      AnimKey.run: 'entities/npc/huntress/run.png',
      AnimKey.jump: 'entities/npc/huntress/jump.png',
      AnimKey.fall: 'entities/npc/huntress/fall.png',
      AnimKey.cast: 'entities/npc/huntress/attack3.png',
      AnimKey.strike: 'entities/npc/huntress/attack2.png',
      AnimKey.strike2: 'entities/npc/huntress/attack1.png',
      AnimKey.hit: 'entities/npc/huntress/take_hit.png',
      AnimKey.death: 'entities/npc/huntress/death.png',
    },
    frameCountsByKey: {
      AnimKey.idle: 8,
      AnimKey.stun: 8,
      AnimKey.run: 8,
      AnimKey.jump: 2,
      AnimKey.fall: 2,
      AnimKey.cast: 7,
      AnimKey.strike: 5,
      AnimKey.strike2: 5,
      AnimKey.hit: 3,
      AnimKey.death: 8,
    },
    stepTimeSecondsByKey: {
      AnimKey.idle: .12,
      AnimKey.stun: .12,
      AnimKey.run: .1,
      AnimKey.jump: .12,
      AnimKey.fall: .12,
      AnimKey.cast: .1,
      AnimKey.strike: .1,
      AnimKey.strike2: .1,
      AnimKey.hit: .1,
      AnimKey.death: .12,
    },
  ),
);
const _huntress2 = NpcArchetype(
  renderScale: 1.5,
  collider: _huntress2Collider,
  health: HealthDef(hp: 3700, hpMax: 3700, regenPerSecond100: 0),
  speedX: 110,
  attackRange: 320,
  attackAbilityId: 'npc_huntress2.shoot_arrow',
  castOriginOffset: 30,
  castOriginOffsetY: -10.5,
  renderAnim: RenderAnimSetDefinition(
    frameWidth: 100,
    frameHeight: 100,
    anchorPoint: Vec2(50, 49),
    sourcesByKey: {
      AnimKey.idle: 'entities/npc/huntress_2/character/idle.png',
      AnimKey.stun: 'entities/npc/huntress_2/character/idle.png',
      AnimKey.run: 'entities/npc/huntress_2/character/run.png',
      AnimKey.jump: 'entities/npc/huntress_2/character/jump.png',
      AnimKey.fall: 'entities/npc/huntress_2/character/fall.png',
      AnimKey.cast: 'entities/npc/huntress_2/character/attack.png',
      AnimKey.hit: 'entities/npc/huntress_2/character/get_hit.png',
      AnimKey.death: 'entities/npc/huntress_2/character/death.png',
    },
    frameCountsByKey: {
      AnimKey.idle: 10,
      AnimKey.stun: 10,
      AnimKey.run: 8,
      AnimKey.jump: 2,
      AnimKey.fall: 2,
      AnimKey.cast: 6,
      AnimKey.hit: 3,
      AnimKey.death: 10,
    },
    stepTimeSecondsByKey: {
      AnimKey.idle: .12,
      AnimKey.stun: .12,
      AnimKey.run: .1,
      AnimKey.jump: .12,
      AnimKey.fall: .12,
      AnimKey.cast: .1,
      AnimKey.hit: .1,
      AnimKey.death: .12,
    },
  ),
);
