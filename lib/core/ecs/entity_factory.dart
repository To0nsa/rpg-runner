import '../combat/faction.dart';
import '../enemies/enemy_id.dart';
import '../snapshots/enums.dart';
import '../util/deterministic_rng.dart';
import 'entity_id.dart';
import 'stores/body_store.dart';
import 'stores/collider_aabb_store.dart';
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
  /// - [MovementStore]: Handles movement logic and facing direction.
  /// - [BodyStore]: Physics body properties (mass, friction, etc.).
  /// - [ColliderAabbStore]: Axis-aligned bounding box for collision detection.
  /// - [CollisionStateStore]: Tracks current collision state.
  /// - [CooldownStore]: Manages ability cooldowns.
  /// - [CastIntentStore]: Tracks intent to cast spells.
  /// - [FactionStore]: Sets the faction to [Faction.player].
  /// - [HealthStore]: Health points and max health.
  /// - [InvulnerabilityStore]: Grants temporary invulnerability after damage.
  /// - [LastDamageStore]: Tracks the last source of damage for UI/effects.
  /// - [ManaStore]: Mana points and max mana.
  /// - [MeleeIntentStore]: Tracks intent to perform melee attacks.
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
  }) {
    final id = world.createEntity();
    world.transform.add(id, posX: posX, posY: posY, velX: velX, velY: velY);
    world.playerInput.add(id);
    world.movement.add(id, facing: facing);
    world.body.add(id, body);
    world.colliderAabb.add(id, collider);
    world.collision.add(id);
    world.cooldown.add(id);
    world.castIntent.add(id);
    world.faction.add(id, const FactionDef(faction: Faction.player));
    world.health.add(id, health);
    world.invulnerability.add(id);
    world.lastDamage.add(id);
    world.mana.add(id, mana);
    world.meleeIntent.add(id);
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
  /// - [CastIntentStore]: Spell casting intent.
  /// - [FactionStore]: Sets faction to [Faction.enemy].
  /// - [HealthStore], [ManaStore], [StaminaStore]: Vital stats.
  /// - [MeleeIntentStore]: Melee attack intent.
  /// - [EnemyStore]: Identifies the entity as an enemy and stores its type.
  ///
  /// Adds specific components based on [enemyId]:
  /// - [EnemyId.flyingEnemy]: Adds [FlyingEnemySteeringStore] for air movement.
  /// - [EnemyId.groundEnemy]: Adds [SurfaceNavStateStore] and [GroundEnemyChaseOffsetStore]
  ///   for ground-based navigation and chasing behavior.
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
  }) {
    final id = world.createEntity();
    world.transform.add(id, posX: posX, posY: posY, velX: velX, velY: velY);
    world.body.add(id, body);
    world.colliderAabb.add(id, collider);
    world.collision.add(id);
    world.cooldown.add(id);
    world.castIntent.add(id);
    world.faction.add(id, const FactionDef(faction: Faction.enemy));
    world.health.add(id, health);
    world.mana.add(id, mana);
    world.meleeIntent.add(id);
    world.stamina.add(id, stamina);
    world.enemy.add(id, EnemyDef(enemyId: enemyId, facing: facing));
    if (enemyId == EnemyId.flyingEnemy) {
      world.flyingEnemySteering.add(
        id,
        FlyingEnemySteeringDef(rngState: seedFrom(world.seed, id)),
      );
    }
    if (enemyId == EnemyId.groundEnemy) {
      world.surfaceNav.add(id);
      world.groundEnemyChaseOffset.add(
        id,
        GroundEnemyChaseOffsetDef(rngState: seedFrom(world.seed, id)),
      );
    }
    return id;
  }
}
