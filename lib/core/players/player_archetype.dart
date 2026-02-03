import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/combat/creature_tag_store.dart';
import '../ecs/stores/combat/damage_resistance_store.dart';
import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../ecs/stores/combat/status_immunity_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import '../snapshots/enums.dart';
import '../projectiles/projectile_item_id.dart';
import '../weapons/weapon_id.dart';

/// Fully-resolved player configuration used to spawn the player entity.
///
/// **Purpose**:
/// Contains all the component definitions needed to instantiate a player
/// entity in the ECS world. Unlike [PlayerCatalog], which holds authoring-time
/// templates, this class holds final, tick-rate-independent values ready for
/// entity creation.
///
/// **Lifecycle**:
/// 1. [PlayerCatalog] defines base templates (physics flags, default facing).
/// 2. [PlayerCatalogDerived.from] merges templates with tuning data to produce
///    a [PlayerArchetype].
/// 3. [EntityFactory.createPlayer] uses the archetype to add components..
class PlayerArchetype {
  const PlayerArchetype({
    required this.collider,
    required this.body,
    required this.health,
    required this.mana,
    required this.stamina,
    this.tags = const CreatureTagDef(),
    this.resistance = const DamageResistanceDef(),
    this.statusImmunity = const StatusImmunityDef(),
    this.loadoutSlotMask = LoadoutSlotMask.defaultMask,
    this.weaponId = WeaponId.basicSword,
    this.offhandWeaponId = WeaponId.basicShield,
    this.projectileItemId = ProjectileItemId.fireBolt,
    this.facing = Facing.right,
  });

  /// AABB collider definition (half-extents and offset).
  ///
  /// Determines the player's collision bounds for physics and hit detection.
  /// Typically derived from [PlayerCatalog.colliderWidth] and
  /// [PlayerCatalog.colliderHeight].
  final ColliderAabbDef collider;

  /// Physics body configuration (gravity, kinematic flags, velocity clamps).
  ///
  /// Controls how the player interacts with the physics simulation:
  /// - `useGravity`: Whether gravity affects the player.
  /// - `maxVelX/maxVelY`: Velocity clamps from movement tuning.
  /// - `sideMask`: Which collision sides are active.
  final BodyDef body;

  /// Health pool definition (current HP, max HP, regeneration rate).
  ///
  /// Values derived from [ResourceTuning.playerHpMax] and related fields.
  final HealthDef health;

  /// Mana pool definition (current mana, max mana, regeneration rate).
  ///
  /// Used for projectile abilities. Values from [ResourceTuning.playerManaMax].
  final ManaDef mana;

  /// Stamina pool definition (current stamina, max stamina, regeneration rate).
  ///
  /// Used for abilities like dash. Values from [ResourceTuning.playerStaminaMax].
  final StaminaDef stamina;

  /// Broad tags used by combat rules and content filters.
  final CreatureTagDef tags;

  /// Resistance/vulnerability modifiers by damage type.
  final DamageResistanceDef resistance;

  /// Status effect immunities for the player.
  final StatusImmunityDef statusImmunity;

  /// Bitmask of enabled loadout slots (see [LoadoutSlotMask]).
  final int loadoutSlotMask;

  /// Equipped weapon used for melee strikes.
  final WeaponId weaponId;

  /// Equipped off-hand weapon or shield.
  final WeaponId offhandWeaponId;

  /// Equipped projectile item used for thrown/ballistic projectiles.
  final ProjectileItemId projectileItemId;

  /// Initial facing direction when the player spawns.
  ///
  /// Affects sprite rendering and directional abilities.
  final Facing facing;
}
