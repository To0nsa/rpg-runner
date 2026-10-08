import '../../anim/anim_resolver.dart';
import '../../combat/ai_cast_aim_policy.dart';
import '../../ecs/stores/body_store.dart';
import '../../ecs/stores/collider_aabb_store.dart';
import '../../ecs/stores/combat/status_immunity_store.dart';
import '../../ecs/stores/health_store.dart';
import '../../ecs/stores/mana_store.dart';
import '../../ecs/stores/stamina_store.dart';
import '../../ecs/stores/world_contact_capsule_store.dart';
import '../../snapshots/enums.dart';
import '../death_behavior.dart';
import '../enemy_archetype.dart';
import '../enemy_terrain_profile.dart';
import '../void_tentacle_render_catalog.dart';

/// Void Tentacle tuning used by the runtime catalog and source-backed editor.
const voidTentacleArchetype = EnemyArchetype(
  body: BodyDef(
    useGravity: true,
    ignoreCeilings: true,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  collider: _voidTentacleCollider,
  // Finite encounter health; summons grant no kill points.
  health: HealthDef(hp: 1600, hpMax: 1600, regenPerSecond100: 0),
  mana: ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
  stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  renderAnim: VoidTentacleRenderCatalog.actor,
  renderScale: 1.5,
  animProfile: AnimProfile(
    supportsCast: true,
    supportsRanged: true,
    supportsWalk: true,
    supportsSpawn: true,
    supportsJumpFall: false,
    minMoveSpeed: 1,
    runSpeedThresholdX: 100,
  ),
  hitAnimSeconds: .3,
  deathAnimSeconds: 0.6,
  spawnAnimSeconds: 0.5,
  deathBehavior: DeathBehavior.groundImpactThenDeath,
  primaryMeleeAbilityId: 'void_tentacle.lash',
  primaryCastAbilityId: null,
  castTargetPolicy: AiCastAimPolicy.targetCenter,
  meleeRangePolicy: EnemyMeleeRangePolicy.weaponReach,
  artFacingDir: Facing.left,
  statusImmunity: StatusImmunityDef(mask: 0),
);

const ColliderAabbDef _voidTentacleCollider = ColliderAabbDef(
  halfX: 15,
  halfY: 36,
  offsetY: 0,
);

/// Shared terrain policy derived from this enemy's authored collider.
final voidTentacleTerrainProfile = createGroundedEnemyTerrainProfile(
  capsule: WorldContactCapsuleDef.fromAabb(_voidTentacleCollider),
  canJump: false,
  maxWalkableSlopeDegrees: 45,
  minimumSupportUpComponent: 724,
);
