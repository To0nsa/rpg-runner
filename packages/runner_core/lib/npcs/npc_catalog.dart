import '../anim/anim_resolver.dart';
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

/// Allied actor tuning uses its own identity, never an enemy score identifier.
final class NpcArchetype {
  const NpcArchetype({
    required this.collider,
    required this.renderAnim,
    required this.attackAbilityId,
    this.health = const HealthDef(hp: 3500, hpMax: 3500, regenPerSecond100: 0),
    this.renderScale = 1.5,
    this.speedX = 100,
    this.jumpSpeed = 360,
    this.attackRange = 52,
  });
  final ColliderAabbDef collider;
  final HealthDef health;
  final RenderAnimSetDefinition renderAnim;
  final String attackAbilityId;
  final double renderScale;
  final double speedX;
  final double jumpSpeed;
  final double attackRange;
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
    strikeAnimKey: AnimKey.strike,
  );
}

/// The warrior is the first integration fixture. Other imported archetypes are
/// admitted only after their authored attack/render contracts are registered.
class NpcCatalog {
  const NpcCatalog();
  static const supportedIds = [NpcId.warrior];

  NpcArchetype get(NpcId id) => switch (id) {
    NpcId.warrior => _warrior,
    _ => throw ArgumentError.value(
      id,
      'npcId',
      'NPC archetype is not registered.',
    ),
  };

  EnemyTerrainContactProfile terrainContactProfile(NpcId id) => switch (id) {
    NpcId.warrior => _warriorTerrain,
    _ => throw ArgumentError.value(
      id,
      'npcId',
      'NPC terrain profile is not registered.',
    ),
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
