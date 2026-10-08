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
import '../voidcaller_render_catalog.dart';
import 'boss_status_scaling.dart';

/// Voidcaller tuning used by the runtime catalog and source-backed editor.
const voidcallerArchetype = EnemyArchetype(
  body: BodyDef(
    useGravity: true,
    ignoreCeilings: true,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  collider: _voidcallerCollider,
  // Finite encounter health; summons grant no kill points.
  health: HealthDef(hp: 12000, hpMax: 12000, regenPerSecond100: 0),
  mana: ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
  stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  renderAnim: VoidcallerRenderCatalog.actor,
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
  deathAnimSeconds: 0.9,
  spawnAnimSeconds: 1.7,
  deathBehavior: DeathBehavior.groundImpactThenDeath,
  primaryMeleeAbilityId: null,
  primaryCastAbilityId: 'voidcaller.vertical_beam',
  castTargetPolicy: AiCastAimPolicy.targetCenter,
  meleeRangePolicy: EnemyMeleeRangePolicy.weaponReach,
  artFacingDir: Facing.left,
  statusImmunity: StatusImmunityDef(
    mask: StatusImmunityMask.stun | StatusImmunityMask.silence,
  ),
  statusScaling: bossStatusScaling,
);

const ColliderAabbDef _voidcallerCollider = ColliderAabbDef(
  halfX: 24,
  halfY: 45,
  offsetY: 0,
);

/// Shared terrain policy derived from this enemy's authored collider.
final voidcallerTerrainProfile = createGroundedEnemyTerrainProfile(
  capsule: WorldContactCapsuleDef.fromAabb(_voidcallerCollider),
  canJump: false,
  maxWalkableSlopeDegrees: 45,
  minimumSupportUpComponent: 724,
);
