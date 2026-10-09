import '../abilities/ability_def.dart';
import '../anim/anim_resolver.dart';
import '../combat/ai_cast_aim_policy.dart';
import '../contracts/render_anim_set_definition.dart';
import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/combat/creature_tag_store.dart';
import '../ecs/stores/combat/damage_resistance_store.dart';
import '../ecs/stores/combat/status_immunity_store.dart';
import '../ecs/stores/combat/status_scaling_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import '../snapshots/enums.dart';
import 'death_behavior.dart';

/// Whether a ground melee enemy engages at close range or its authored reach.
enum EnemyMeleeRangePolicy { closeRange, weaponReach }

/// When enemy decisions update their facing toward the selected combat target.
enum EnemyFacingPolicy {
  /// Facing is derived from movement/commits.
  movementDriven,

  /// Facing updates continuously toward the selected combat target.
  facePlayerAlways,
}

/// Immutable spawn, combat, and presentation defaults shared by enemy definitions.
class EnemyArchetype {
  const EnemyArchetype({
    required this.body,
    required this.collider,
    required this.health,
    required this.mana,
    required this.stamina,
    required this.renderAnim,
    required this.renderScale,
    required this.animProfile,
    required this.hitAnimSeconds,
    required this.deathAnimSeconds,
    this.spawnAnimSeconds = 0.0,
    this.deathBehavior = DeathBehavior.instant,
    this.preserveReleasedSpellsOnDefeat = false,
    this.primaryCastAbilityId,
    this.castOriginOffset,
    this.castTargetPolicy = AiCastAimPolicy.predictedTargetCenter,
    this.previewAnimKey = AnimKey.idle,
    this.facingPolicy = EnemyFacingPolicy.movementDriven,
    this.meleeRangePolicy = EnemyMeleeRangePolicy.closeRange,
    this.primaryMeleeAbilityId,
    this.comboMeleeAbilityId,
    this.artFacingDir = Facing.left,
    this.tags = const CreatureTagDef(),
    this.resistance = const DamageResistanceDef(),
    this.statusImmunity = const StatusImmunityDef(),
    this.statusScaling = const StatusScalingDef(),
  });

  /// Physics configuration (Gravity, Constraints, Kinematics).
  final BodyDef body;

  /// Hitbox size (Collision).
  final ColliderAabbDef collider;

  /// Vitals (HP, Mana, Stamina) configuration.
  final HealthDef health;
  final ManaDef mana;
  final StaminaDef stamina;

  /// Render-only animation metadata (strip paths, frame size, timing).
  final RenderAnimSetDefinition renderAnim;

  /// Positive uniform sprite scale applied by runtime renderers.
  ///
  /// Keeping this beside [renderAnim] lets non-Flame consumers reproduce the
  /// runtime sprite footprint without duplicating presentation tuning.
  final double renderScale;

  /// Core animation profile (movement thresholds and supported keys).
  final AnimProfile animProfile;

  /// Duration the hit animation should be visible (seconds).
  final double hitAnimSeconds;

  /// Duration the death animation should be visible (seconds).
  final double deathAnimSeconds;

  /// Duration the spawn animation should be visible (seconds).
  final double spawnAnimSeconds;

  /// Behavior for death transition timing (instant vs ground impact).
  final DeathBehavior deathBehavior;

  /// Arena defeat preserves this actor's launched projectiles and world-anchored
  /// spells until their normal impact/expiry. Pending casts and melee still end.
  final bool preserveReleasedSpellsOnDefeat;

  /// Optional primary cast ability for this enemy.
  final AbilityKey? primaryCastAbilityId;

  /// Optional projectile cast origin offset owned by this caster.
  ///
  /// When null, cast systems derive a fallback offset from collider size.
  final double? castOriginOffset;

  /// Target selection policy used by enemy cast systems.
  final AiCastAimPolicy castTargetPolicy;

  /// Catalog-owned pose used by static authoring previews.
  final AnimKey previewAnimKey;

  /// Facing updates for the caster phase; melee commits own their facing.
  final EnemyFacingPolicy facingPolicy;

  /// Source of horizontal melee engagement range; geometry owns weapon reach.
  final EnemyMeleeRangePolicy meleeRangePolicy;

  /// Optional primary melee ability for this enemy.
  ///
  /// When present, melee engagement/commit systems resolve timing + payload from
  /// this ability definition.
  final AbilityKey? primaryMeleeAbilityId;

  /// Optional follow-up melee ability used by combo-capable enemies.
  final AbilityKey? comboMeleeAbilityId;

  /// Direction the authored art faces when not mirrored.
  ///
  /// Most sprites face right by default, but some packs are authored facing
  /// left. The renderer uses this to mirror correctly based on logical [Facing].
  final Facing artFacingDir;

  /// Broad tags used by combat rules and content filters.
  final CreatureTagDef tags;

  /// Resistance/vulnerability modifiers by damage type.
  final DamageResistanceDef resistance;

  /// Status effect immunities for this enemy.
  final StatusImmunityDef statusImmunity;

  /// Incoming debuff strength/duration multipliers, independent of damage type.
  final StatusScalingDef statusScaling;
}
