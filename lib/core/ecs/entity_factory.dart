import '../combat/faction.dart';
import '../enemies/enemy_id.dart';
import '../snapshots/enums.dart';
import '../util/deterministic_rng.dart';
import 'entity_id.dart';
import 'stores/body_store.dart';
import 'stores/collider_aabb_store.dart';
import 'stores/combat/creature_tag_store.dart';
import 'stores/combat/damage_resistance_store.dart';
import 'stores/combat/equipped_loadout_store.dart';
import 'stores/combat/stat_modifier_store.dart';
import 'stores/combat/status_immunity_store.dart';
import 'stores/enemies/enemy_store.dart';
import 'stores/faction_store.dart';
import 'stores/enemies/flying_enemy_steering_store.dart';
import 'stores/enemies/ground_enemy_chase_offset_store.dart';
import 'stores/health_store.dart';
import 'stores/mana_store.dart';
import 'stores/stamina_store.dart';
import 'world.dart';

/// Factory for creating complex entities composed of multiple components.
///
/// This class encapsulates the logic for assembling entities from their constituent
/// components. It ensures that all necessary components are added and initialized
/// correctly for each entity type (e.g., Player, Enemy).
class EntityFactory {
  /// Creates a factory bound to the given [world].
  EntityFactory(this.world);

  /// The [EcsWorld] into which entities will be created.
  final EcsWorld world;

  /// Creates a fully assembled Player entity.
  ///
  /// Adds the following components:
  /// - [TransformStore]: Position and velocity.
  /// - [PlayerInputStore]: Marks this entity as controllable by player input.
  /// - [AnimStateStore]: Stores resolved animation state for rendering.
  /// - [MovementStore]: Handles movement logic and facing direction.
  /// - [JumpStateStore]: Tracks coyote/buffer/air-jump runtime counters.
  /// - [BodyStore]: Physics body properties (mass, friction, etc.).
  /// - [ColliderAabbStore]: Axis-aligned bounding box for collision detection.
  /// - [CollisionStateStore]: Tracks current collision state.
  /// - [CooldownStore]: Manages ability cooldowns.
  /// - [ProjectileIntentStore]: Tracks intent to fire projectile items.
  /// - [CreatureTagStore]: Broad combat classification tags.
  /// - [FactionStore]: Sets the faction to [Faction.player].
  /// - [HealthStore]: Health points and max health.
  /// - [DamageResistanceStore]: Damage modifiers per type.
  /// - [InvulnerabilityStore]: Grants temporary invulnerability after damage.
  /// - [LastDamageStore]: Tracks the last source of damage for UI/effects.
  /// - [StatusImmunityStore]: Status effect immunities.
  /// - [ManaStore]: Mana points and max mana.
  /// - [EquippedLoadoutStore]: Equipped abilities and gear.
  /// - [MeleeIntentStore]: Tracks intent to perform melee strikes.
  /// - [MobilityIntentStore]: Tracks intent to perform mobility actions.
  /// - [StatModifierStore]: Runtime stat modifiers from statuses.
  /// - [StaminaStore]: Stamina points and max stamina.
  ///
  /// The [grounded] parameter sets the initial ground state in the collision store.
  EntityId createPlayer({
    required double posX,
    required double posY,
    required double velX,
    required double velY,
    required Facing facing,
    required bool grounded,
    required BodyDef body,
    required ColliderAabbDef collider,
    required HealthDef health,
    required ManaDef mana,
    required StaminaDef stamina,
    CreatureTagDef tags = const CreatureTagDef(),
    DamageResistanceDef resistance = const DamageResistanceDef(),
    StatusImmunityDef statusImmunity = const StatusImmunityDef(),
    EquippedLoadoutDef equippedLoadout = const EquippedLoadoutDef(),
  }) {
    final id = world.createEntity();
    world.transform.add(id, posX: posX, posY: posY, velX: velX, velY: velY);
    world.playerInput.add(id);
    world.abilityInputBuffer.add(id);
    world.abilityCharge.add(id);
    world.activeAbility.add(id);
    world.animState.add(id);
    world.movement.add(id, facing: facing);
    world.jumpState.add(id);
    world.body.add(id, body);
    world.colliderAabb.add(id, collider);
    world.collision.add(id);
    world.cooldown.add(id);
    world.creatureTag.add(id, tags);
    world.faction.add(id, const FactionDef(faction: Faction.player));
    world.health.add(id, health);
    world.damageResistance.add(id, resistance);
    world.invulnerability.add(id);
    world.lastDamage.add(id);
    world.statusImmunity.add(id, statusImmunity);
    world.mana.add(id, mana);
    world.meleeIntent.add(id);
    world.mobilityIntent.add(id);
    world.projectileIntent.add(id);
    world.selfIntent.add(id);
    world.equippedLoadout.add(id, equippedLoadout);
    world.statModifier.add(id);
    world.stamina.add(id, stamina);
    world.collision.grounded[world.collision.indexOf(id)] = grounded;
    return id;
  }

  /// Creates an Enemy entity based on the provided [enemyId].
  ///
  /// Adds common components for all enemies:
  /// - [TransformStore]: Position and velocity.
  /// - [BodyStore]: Physics properties.
  /// - [ColliderAabbStore]: Collision boounding box.
  /// - [CollisionStateStore]: Collision state tracking.
  /// - [CooldownStore]: Ability cooldowns.
  /// - [ProjectileIntentStore]: Projectile intent.
  /// - [CreatureTagStore]: Broad combat classification tags.
  /// - [FactionStore]: Sets faction to [Faction.enemy].
  /// - [HealthStore], [ManaStore], [StaminaStore]: Vital stats.
  /// - [MeleeIntentStore]: Melee strike intent.
  /// - [DamageResistanceStore]: Damage modifiers per type.
  /// - [StatusImmunityStore]: Status effect immunities.
  /// - [StatModifierStore]: Runtime stat modifiers from statuses.
  /// - [EnemyStore]: Identifies the entity as an enemy and stores its type.
  /// - [AnimStateStore]: Animation state computed by [AnimSystem].
  /// - [MeleeEngagementStore]: Engagement state for melee AI.
  /// - [NavIntentStore]: Navigation output for ground enemies.
  /// - [EngagementIntentStore]: Engagement output for melee enemies.
  ///
  /// Adds specific components based on [enemyId]:
  /// - [EnemyId.unocoDemon]: Adds [FlyingEnemySteeringStore] for air movement.
  /// - [EnemyId.grojib]: Adds [SurfaceNavStateStore], [GroundEnemyChaseOffsetStore],
  ///   [NavIntentStore], and [EngagementIntentStore] for ground navigation/engagement.
  EntityId createEnemy({
    required EnemyId enemyId,
    required double posX,
    required double posY,
    required double velX,
    required double velY,
    required Facing facing,
    required BodyDef body,
    required ColliderAabbDef collider,
    required HealthDef health,
    required ManaDef mana,
    required StaminaDef stamina,
    CreatureTagDef tags = const CreatureTagDef(),
    DamageResistanceDef resistance = const DamageResistanceDef(),
    StatusImmunityDef statusImmunity = const StatusImmunityDef(),
  }) {
    final id = world.createEntity();
    world.transform.add(id, posX: posX, posY: posY, velX: velX, velY: velY);
    world.body.add(id, body);
    world.colliderAabb.add(id, collider);
    world.collision.add(id);
    world.cooldown.add(id);
    world.projectileIntent.add(id);
    world.creatureTag.add(id, tags);
    world.faction.add(id, const FactionDef(faction: Faction.enemy));
    world.health.add(id, health);
    world.damageResistance.add(id, resistance);
    world.mana.add(id, mana);
    world.meleeIntent.add(id);
    world.meleeEngagement.add(id);
    world.statModifier.add(id);
    world.stamina.add(id, stamina);
    world.enemy.add(id, EnemyDef(enemyId: enemyId, facing: facing));
    world.activeAbility.add(id);
    world.abilityCharge.add(id);
    world.animState.add(id);
    world.statusImmunity.add(id, statusImmunity);
    if (enemyId == EnemyId.unocoDemon) {
      world.flyingEnemySteering.add(
        id,
        FlyingEnemySteeringDef(rngState: seedFrom(world.seed, id)),
      );
    }
    if (enemyId == EnemyId.grojib) {
      world.surfaceNav.add(id);
      world.groundEnemyChaseOffset.add(
        id,
        GroundEnemyChaseOffsetDef(rngState: seedFrom(world.seed, id)),
      );
      world.navIntent.add(id);
      world.engagementIntent.add(id);
    }
    return id;
  }
}
