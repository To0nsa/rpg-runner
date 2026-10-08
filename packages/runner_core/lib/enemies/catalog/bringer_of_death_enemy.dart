import '../../anim/anim_resolver.dart';
import '../../combat/ai_cast_aim_policy.dart';
import '../../combat/creature_tag.dart';
import '../../contracts/render_anim_set_definition.dart';
import '../../contracts/render_frame_rect.dart';
import '../../ecs/stores/body_store.dart';
import '../../ecs/stores/collider_aabb_store.dart';
import '../../ecs/stores/combat/creature_tag_store.dart';
import '../../ecs/stores/combat/status_immunity_store.dart';
import '../../ecs/stores/health_store.dart';
import '../../ecs/stores/mana_store.dart';
import '../../ecs/stores/stamina_store.dart';
import '../../ecs/stores/world_contact_capsule_store.dart';
import '../../snapshots/enums.dart';
import '../../util/vec2.dart';
import '../death_behavior.dart';
import '../enemy_archetype.dart';
import '../enemy_terrain_profile.dart';
import 'boss_status_scaling.dart';

/// Bringer of Death tuning used by the runtime catalog and source-backed editor.
const bringerArchetype = EnemyArchetype(
  body: BodyDef(
    isKinematic: false,
    useGravity: true,
    ignoreCeilings: true,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  collider: _bringerCollider,
  // 120 HP, no passive healing: the first boss remains a finite fight.
  health: HealthDef(hp: 12000, hpMax: 12000, regenPerSecond100: 0),
  mana: ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
  stamina: StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  renderAnim: _bringerRenderAnim,
  renderScale: 1.5,
  animProfile: AnimProfile(
    supportsCast: true,
    supportsWalk: true,
    supportsSpawn: true,
    supportsJumpFall: false,
    minMoveSpeed: 1,
    runSpeedThresholdX: 100,
  ),
  hitAnimSeconds: .3,
  deathAnimSeconds: 1.2,
  spawnAnimSeconds: 1.2,
  deathBehavior: DeathBehavior.groundImpactThenDeath,
  primaryMeleeAbilityId: 'bringer.scythe_sweep',
  primaryCastAbilityId: 'bringer.death_pillar',
  castTargetPolicy: AiCastAimPolicy.targetCenter,
  meleeRangePolicy: EnemyMeleeRangePolicy.weaponReach,
  artFacingDir: Facing.left,
  tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
  statusImmunity: StatusImmunityDef(
    mask: StatusImmunityMask.stun | StatusImmunityMask.silence,
  ),
  statusScaling: bossStatusScaling,
);

const ColliderAabbDef _bringerCollider = ColliderAabbDef(
  // World units at 1.5x source size, matching the enlarged boss presentation.
  halfX: 18,
  halfY: 40.5,
  offsetX: 0,
  offsetY: -4.5,
);

/// Shared terrain policy derived from this enemy's authored collider.
final EnemyTerrainContactProfile bringerTerrainProfile =
    createGroundedEnemyTerrainProfile(
      capsule: WorldContactCapsuleDef.fromAabb(_bringerCollider),
      canJump: false,
      maxWalkableSlopeDegrees: 45,
      minimumSupportUpComponent: 724,
    );

// The pack uses eight columns; Attack, Hurt, Death and Cast share wrapped rows.
const String _bringerSheet = 'entities/enemies/bringer_of_death/sheet.png';
const RenderAnimSetDefinition _bringerRenderAnim = RenderAnimSetDefinition(
  frameWidth: 140,
  frameHeight: 93,
  anchorPoint: Vec2(104, 68),
  sourcesByKey: {
    AnimKey.idle: _bringerSheet,
    AnimKey.walk: _bringerSheet,
    AnimKey.run: _bringerSheet,
    AnimKey.strike: _bringerSheet,
    AnimKey.cast: _bringerSheet,
    AnimKey.hit: _bringerSheet,
    AnimKey.death: _bringerSheet,
    AnimKey.spawn: _bringerSheet,
  },
  rowByKey: {
    AnimKey.walk: 1,
    AnimKey.run: 1,
    AnimKey.strike: 2,
    AnimKey.hit: 3,
    AnimKey.death: 3,
    AnimKey.cast: 4,
  },
  frameStartByKey: {AnimKey.hit: 2, AnimKey.death: 5, AnimKey.cast: 7},
  gridColumnsByKey: {
    AnimKey.strike: 8,
    AnimKey.hit: 8,
    AnimKey.death: 8,
    AnimKey.cast: 8,
  },
  sourceFramesByKey: {
    // Reverse the authored dissolution for a complete, deterministic entrance.
    AnimKey.spawn: [
      RenderFrameRect(840, 372, 140, 93),
      RenderFrameRect(700, 372, 140, 93),
      RenderFrameRect(560, 372, 140, 93),
      RenderFrameRect(420, 372, 140, 93),
      RenderFrameRect(280, 372, 140, 93),
      RenderFrameRect(140, 372, 140, 93),
      RenderFrameRect(0, 372, 140, 93),
      RenderFrameRect(980, 279, 140, 93),
      RenderFrameRect(840, 279, 140, 93),
      RenderFrameRect(700, 279, 140, 93),
    ],
  },
  frameCountsByKey: {
    AnimKey.idle: 8,
    AnimKey.walk: 8,
    AnimKey.run: 8,
    AnimKey.strike: 10,
    AnimKey.cast: 9,
    AnimKey.hit: 3,
    AnimKey.death: 10,
    AnimKey.spawn: 10,
  },
  stepTimeSecondsByKey: {
    AnimKey.idle: .12,
    AnimKey.walk: .10 / 1.2,
    AnimKey.run: .10 / 1.2,
    AnimKey.strike: .10 / 1.5,
    AnimKey.cast: .10 / 1.5,
    AnimKey.hit: .10,
    AnimKey.death: .12,
    AnimKey.spawn: .12,
  },
);
