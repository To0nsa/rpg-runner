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
import '../voidborn_goddess_render_catalog.dart';
import 'boss_status_scaling.dart';

/// Voidborn Goddess tuning used by the runtime catalog and source-backed editor.
const voidbornGoddessArchetype = EnemyArchetype(
  body: BodyDef(
    useGravity: true,
    ignoreCeilings: true,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  collider: _voidbornGoddessCollider,
  // Finite encounter health; summons grant no kill points.
  health: HealthDef(hp: 36000, hpMax: 36000, regenPerSecond100: 0),
  mana: ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
  stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  renderAnim: VoidbornGoddessRenderCatalog.actor,
  renderScale: 1.0,
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
  deathAnimSeconds: 1.4,
  spawnAnimSeconds: 0.5,
  deathBehavior: DeathBehavior.groundImpactThenDeath,
  primaryMeleeAbilityId: 'goddess.claw_combo',
  primaryCastAbilityId: 'goddess.orb',
  castTargetPolicy: AiCastAimPolicy.targetCenter,
  meleeRangePolicy: EnemyMeleeRangePolicy.weaponReach,
  artFacingDir: Facing.left,
  statusImmunity: StatusImmunityDef(
    mask: StatusImmunityMask.stun | StatusImmunityMask.silence,
  ),
  statusScaling: bossStatusScaling,
);

const ColliderAabbDef _voidbornGoddessCollider = ColliderAabbDef(
  halfX: 9,
  halfY: 27,
  offsetY: 0,
);

/// Shared terrain policy derived from this enemy's authored collider.
final voidbornGoddessTerrainProfile = createGroundedEnemyTerrainProfile(
  capsule: WorldContactCapsuleDef.fromAabb(_voidbornGoddessCollider),
  canJump: false,
  maxWalkableSlopeDegrees: 45,
  minimumSupportUpComponent: 724,
);
