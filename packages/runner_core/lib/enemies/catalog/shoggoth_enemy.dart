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
import '../shoggoth_render_catalog.dart';
import 'boss_status_scaling.dart';

/// Shoggoth tuning used by the runtime catalog and source-backed editor.
const shoggothArchetype = EnemyArchetype(
  body: BodyDef(
    useGravity: true,
    ignoreCeilings: true,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  collider: _shoggothCollider,
  // Finite encounter health; summons grant no kill points.
  health: HealthDef(hp: 12000, hpMax: 12000, regenPerSecond100: 0),
  mana: ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
  stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  renderAnim: ShoggothRenderCatalog.actor,
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
  deathAnimSeconds: 0.8,
  spawnAnimSeconds: 0.9,
  deathBehavior: DeathBehavior.groundImpactThenDeath,
  primaryMeleeAbilityId: 'shoggoth.tentacle_sweep',
  primaryCastAbilityId: 'shoggoth.orb',
  castTargetPolicy: AiCastAimPolicy.targetCenter,
  meleeRangePolicy: EnemyMeleeRangePolicy.weaponReach,
  artFacingDir: Facing.left,
  statusImmunity: StatusImmunityDef(
    mask: StatusImmunityMask.stun | StatusImmunityMask.silence,
  ),
  statusScaling: bossStatusScaling,
);

const ColliderAabbDef _shoggothCollider = ColliderAabbDef(
  halfX: 24,
  halfY: 39,
  offsetY: 9,
);

/// Shared terrain policy derived from this enemy's authored collider.
final shoggothTerrainProfile = createGroundedEnemyTerrainProfile(
  capsule: WorldContactCapsuleDef.fromAabb(_shoggothCollider),
  canJump: false,
  maxWalkableSlopeDegrees: 45,
  minimumSupportUpComponent: 724,
);
