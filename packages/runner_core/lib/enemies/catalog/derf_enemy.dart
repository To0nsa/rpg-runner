import '../../anim/anim_resolver.dart';
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

/// Derf tuning used by the runtime catalog and source-backed editor.
const derfArchetype = EnemyArchetype(
  body: BodyDef(
    isKinematic: false,
    useGravity: true,
    ignoreCeilings: true,
    gravityScale: 1,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  collider: _derfCollider,
  health: HealthDef(hp: 2200, hpMax: 2200, regenPerSecond100: 40),
  mana: ManaDef(mana: 10000, manaMax: 10000, regenPerSecond100: 600),
  stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  renderAnim: _derfRenderAnim,
  renderScale: 1.5,
  animProfile: _derfAnimProfile,
  hitAnimSeconds: .3,
  deathAnimSeconds: 1.2,
  deathBehavior: DeathBehavior.groundImpactThenDeath,
  primaryMeleeAbilityId: 'derf.tentacle_strike',
  primaryCastAbilityId: 'derf.fire_explosion',
  previewAnimKey: AnimKey.casterIdle,
  facingPolicy: EnemyFacingPolicy.facePlayerAlways,
  meleeRangePolicy: EnemyMeleeRangePolicy.weaponReach,
  artFacingDir: Facing.left,
  tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
  resistance: DamageResistanceDef(fireBp: -3000, iceBp: 2000),
);

const ColliderAabbDef _derfCollider = ColliderAabbDef(
  halfX: 11.5,
  halfY: 24.25,
  offsetX: 0.0,
  offsetY: 7.0,
);

/// Shared terrain policy derived from this enemy's authored collider.
final EnemyTerrainContactProfile derfTerrainProfile =
    createGroundedEnemyTerrainProfile(
      capsule: WorldContactCapsuleDef.fromAabb(_derfCollider),
      maxWalkableSlopeDegrees: 45,
      minimumSupportUpComponent: 724,
    );

// -----------------------------------------------------------------------------
// Derf's wider cells retain the original body's world pivot at (72, 21).
const String _derfCasterSheet = 'entities/enemies/derf/caster_sheet.png';
const String _derfSheet = 'entities/enemies/derf/twisted_cultist.png';
const RenderAnimSetDefinition _derfRenderAnim = RenderAnimSetDefinition(
  frameWidth: 91,
  frameHeight: 42,
  anchorPoint: Vec2(72, 21),
  sourcesByKey: {
    AnimKey.casterIdle: _derfCasterSheet,
    AnimKey.casterHit: _derfCasterSheet,
    AnimKey.casterDeath: _derfCasterSheet,
    AnimKey.transform: _derfSheet,
    AnimKey.idle: _derfSheet,
    AnimKey.walk: _derfSheet,
    AnimKey.run: _derfSheet,
    AnimKey.strike: _derfSheet,
    AnimKey.cast: _derfCasterSheet,
    AnimKey.hit: _derfSheet,
    AnimKey.stun: _derfSheet,
    AnimKey.death: _derfSheet,
    AnimKey.jump: _derfSheet,
    AnimKey.fall: _derfSheet,
  },
  rowByKey: {
    AnimKey.casterIdle: 0,
    AnimKey.casterHit: 5,
    AnimKey.casterDeath: 6,
    AnimKey.transform: 10,
    AnimKey.idle: 1,
    AnimKey.walk: 3,
    AnimKey.run: 3,
    AnimKey.strike: 4,
    AnimKey.cast: 2,
    AnimKey.hit: 5,
    AnimKey.stun: 5,
    AnimKey.death: 6,
    AnimKey.jump: 7,
    AnimKey.fall: 9,
  },
  frameCountsByKey: {
    AnimKey.casterIdle: 6,
    AnimKey.casterHit: 3,
    AnimKey.casterDeath: 12,
    AnimKey.transform: 12,
    AnimKey.idle: 6,
    AnimKey.walk: 8,
    AnimKey.run: 8,
    AnimKey.strike: 7,
    AnimKey.cast: 10,
    AnimKey.hit: 3,
    AnimKey.stun: 3,
    AnimKey.death: 12,
    AnimKey.jump: 3,
    AnimKey.fall: 3,
  },
  stepTimeSecondsByKey: {
    AnimKey.casterIdle: .1,
    AnimKey.casterHit: .1,
    AnimKey.casterDeath: .1,
    AnimKey.transform: .08,
    AnimKey.idle: .1,
    AnimKey.walk: .08,
    AnimKey.run: .08,
    AnimKey.strike: .1,
    AnimKey.cast: .08,
    AnimKey.hit: .1,
    AnimKey.stun: .1,
    AnimKey.death: .1,
    AnimKey.jump: .1,
    AnimKey.fall: .1,
  },
);
const AnimProfile _derfAnimProfile = AnimProfile(
  minMoveSpeed: 1,
  runSpeedThresholdX: 120,
  supportsStun: true,
  supportsCast: true,
);
