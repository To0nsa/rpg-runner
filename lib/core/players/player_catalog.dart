import '../combat/creature_tag.dart';
import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/combat/ammo_store.dart';
import '../ecs/stores/combat/creature_tag_store.dart';
import '../ecs/stores/combat/damage_resistance_store.dart';
import '../ecs/stores/combat/status_immunity_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import '../snapshots/enums.dart';
import 'player_tuning.dart';
import '../weapons/weapon_id.dart';
import '../weapons/ranged_weapon_id.dart';
import 'player_archetype.dart';

/// Authoring-time configuration for the player entity.
///
/// **Purpose**:
/// Defines the base template for player physics and spawn behavior. This class
/// holds values that are independent of tick rate or specific tuning numbers,
/// focusing on structural configuration (what physics flags to use, etc.).
///
/// **Relationship to Tuning**:
/// - [PlayerCatalog]: Structural config (physics flags, collision sides).
/// - [MovementTuning]: Numeric movement values (speed, collider size, velocity clamps).
/// - [ResourceTuning]: Numeric resource values (HP, mana, stamina).
///
/// The [PlayerCatalogDerived.from] factory merges all three to produce a
/// complete [PlayerArchetype] ready for entity creation.
class PlayerCatalog {
  const PlayerCatalog({
    this.bodyTemplate = const BodyDef(
      isKinematic: false,
      useGravity: true,
      ignoreCeilings: false,
      topOnlyGround: true,
      gravityScale: 1.0,
      sideMask: BodyDef.sideLeft | BodyDef.sideRight,
    ),
    this.colliderWidth = 22.0,
    this.colliderHeight = 46.0,
    this.colliderOffsetX = 0.0,
    this.colliderOffsetY = -6.0,
    this.tags = const CreatureTagDef(mask: CreatureTagMask.humanoid),
    this.resistance = const DamageResistanceDef(),
    this.statusImmunity = const StatusImmunityDef(),
    this.weaponId = WeaponId.basicSword,
    this.rangedWeaponId = RangedWeaponId.bow,
    this.ammo = const AmmoDef(arrows: 20, throwingAxes: 6),
    this.facing = Facing.right,
  });

  /// Template for how the player participates in physics.
  ///
  /// **Fields used from template**:
  /// - `isKinematic`: False for player (affected by forces).
  /// - `useGravity`: True (player falls).
  /// - `ignoreCeilings`: False (player collides with ceilings).
  /// - `topOnlyGround`: True (only collide with top of ground, not sides).
  /// - `gravityScale`: 1.0 (normal gravity).
  /// - `sideMask`: Left + Right (collide with walls on both sides).
  ///
  /// **Fields filled from [MovementTuning] during derivation**:
  /// - `maxVelX`: Horizontal velocity clamp.
  /// - `maxVelY`: Vertical velocity clamp.
  ///
  /// This split ensures movement tuning remains the single source of truth
  /// for velocity limits.
  final BodyDef bodyTemplate;

  /// Player collision AABB size (full extents) in world units.
  ///
  /// Core uses center-based AABBs, so `halfX = width * 0.5` and
  /// `halfY = height * 0.5`.
  final double colliderWidth;
  final double colliderHeight;

  /// Optional collider center offset from entity `Transform.pos`.
  final double colliderOffsetX;
  final double colliderOffsetY;

  double get colliderHalfX => colliderWidth * 0.5;
  double get colliderHalfY => colliderHeight * 0.5;
  double get colliderMaxHalfExtent =>
      colliderHalfX > colliderHalfY ? colliderHalfX : colliderHalfY;

  /// Broad tags used by combat rules and content filters.
  final CreatureTagDef tags;

  /// Resistance/vulnerability modifiers by damage type.
  final DamageResistanceDef resistance;

  /// Status effect immunities for the player.
  final StatusImmunityDef statusImmunity;

  /// Default equipped weapon at spawn time.
  final WeaponId weaponId;

  /// Default equipped ranged weapon at spawn time.
  final RangedWeaponId rangedWeaponId;

  /// Default ammo pool at spawn time.
  final AmmoDef ammo;

  /// Default facing direction at spawn time.
  ///
  /// Determines initial sprite orientation and directional ability targeting.
  final Facing facing;
}

/// Derived player configuration with tick-rate-resolved values.
///
/// **Purpose**:
/// Combines [PlayerCatalog] templates with [MovementTuning] and [ResourceTuning]
/// to produce a complete [PlayerArchetype]. This is the "compiled" form of
/// player configuration, ready for entity creation.
///
/// **Why a Separate Class?**:
/// - Tuning values may be tick-rate dependent (e.g., regen per second → per tick).
/// - Collider size comes from movement tuning, not catalog.
/// - Resource pools (HP, mana, stamina) come from resource tuning.
/// - Keeping derivation explicit makes dependencies clear and testable.
///
/// **Lifecycle**:
/// Created once at game initialization, stored in [GameCore], used whenever
/// the player needs to be spawned or respawned.
class PlayerCatalogDerived {
  const PlayerCatalogDerived._({required this.archetype});

  /// Creates a derived catalog by merging base config with tuning data.
  ///
  /// **Parameters**:
  /// - [base]: The authoring-time catalog with physics flags.
  /// - [movement]: Movement tuning for collider size and velocity clamps.
  /// - [resources]: Resource tuning for HP, mana, and stamina pools.
  ///
/// **Derivation Logic**:
/// 1. Copy physics flags from [base.bodyTemplate].
/// 2. Fill `maxVelX`/`maxVelY` from [movement].
/// 3. Create AABB collider from [base].
/// 4. Create resource pools from [resources].
/// 5. Bundle everything into a [PlayerArchetype].
  factory PlayerCatalogDerived.from(
    PlayerCatalog base, {
    required MovementTuningDerived movement,
    required ResourceTuning resources,
  }) {
    // Merge body template with velocity clamps from movement tuning.
    final body = BodyDef(
      enabled: base.bodyTemplate.enabled,
      isKinematic: base.bodyTemplate.isKinematic,
      useGravity: base.bodyTemplate.useGravity,
      ignoreCeilings: base.bodyTemplate.ignoreCeilings,
      topOnlyGround: base.bodyTemplate.topOnlyGround,
      gravityScale: base.bodyTemplate.gravityScale,
      maxVelX: movement.base.maxVelX,
      maxVelY: movement.base.maxVelY,
      sideMask: base.bodyTemplate.sideMask,
    );

    // AABB collider from catalog.
    final collider = ColliderAabbDef(
      halfX: base.colliderHalfX,
      halfY: base.colliderHalfY,
      offsetX: base.colliderOffsetX,
      offsetY: base.colliderOffsetY,
    );

    // Resource pools from resource tuning.
    final health = HealthDef(
      hp: resources.playerHpMax,
      hpMax: resources.playerHpMax,
      regenPerSecond: resources.playerHpRegenPerSecond,
    );
    final mana = ManaDef(
      mana: resources.playerManaMax,
      manaMax: resources.playerManaMax,
      regenPerSecond: resources.playerManaRegenPerSecond,
    );
    final stamina = StaminaDef(
      stamina: resources.playerStaminaMax,
      staminaMax: resources.playerStaminaMax,
      regenPerSecond: resources.playerStaminaRegenPerSecond,
    );

    return PlayerCatalogDerived._(
      archetype: PlayerArchetype(
        collider: collider,
        body: body,
        health: health,
        mana: mana,
        stamina: stamina,
        tags: base.tags,
        resistance: base.resistance,
        statusImmunity: base.statusImmunity,
        weaponId: base.weaponId,
        rangedWeaponId: base.rangedWeaponId,
        ammo: base.ammo,
        facing: base.facing,
      ),
    );
  }

  /// The fully-resolved player archetype ready for entity creation.
  ///
  /// Use this with [EntityFactory.createPlayer] to spawn the player entity.
  final PlayerArchetype archetype;
}
