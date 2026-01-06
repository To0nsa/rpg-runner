import 'entity_id.dart';
import 'sparse_set.dart';
import 'stores/body_store.dart';
import 'stores/collider_aabb_store.dart';
import 'stores/collision_state_store.dart';
import 'stores/cooldown_store.dart';
import 'stores/cast_intent_store.dart';
import 'stores/collectible_store.dart';
import 'stores/gravity_control_store.dart';
import 'stores/flying_enemy_steering_store.dart';
import 'stores/faction_store.dart';
import 'stores/enemy_store.dart';
import 'stores/ground_enemy_chase_offset_store.dart';
import 'stores/health_store.dart';
import 'stores/hit_once_store.dart';
import 'stores/hitbox_store.dart';
import 'stores/invulnerability_store.dart';
import 'stores/last_damage_store.dart';
import 'stores/lifetime_store.dart';
import 'stores/mana_store.dart';
import 'stores/melee_intent_store.dart';
import 'stores/movement_store.dart';
import 'stores/player_input_store.dart';
import 'stores/projectile_store.dart';
import 'stores/restoration_item_store.dart';
import 'stores/spell_origin_store.dart';
import 'stores/stamina_store.dart';
import 'stores/surface_nav_state_store.dart';
import 'stores/transform_store.dart';

/// Minimal Entity Component System (ECS) world container.
///
/// The [EcsWorld] is the central hub of the ECS architecture. It manages the
/// creation and destruction of entities ([EntityId]) and acts as a registry
/// for all Component Stores.
///
/// Design philosophy:
/// - **Structure-of-Arrays (SoA):** Data is stored in parallel arrays within each
///   [SparseSet] component store, rather than as objects on the entity.
/// - **Composition over Inheritance:** Game objects are defined by the collection
///   of components they possess.
/// - **Pooling:** Entity IDs are recycled to keep memory usage compact and predictable.
///
/// To add functionality to the game, Systems (logic) query this World for Entities
/// with specific components and operate on them.
class EcsWorld {
  /// Creates a new ECS World with an optional [seed] for deterministic behavior.
  EcsWorld({int seed = 0}) : seed = seed;

  /// Seed used for deterministic RNG in the core, passed to components that need it.
  final int seed;

  /// Counter for generating new unique Entity IDs.
  EntityId _nextEntityId = 1;

  /// Pool of recycled Entity IDs available for reuse.
  final List<EntityId> _freeIds = <EntityId>[];

  /// Fast lookup set for recycled IDs to prevent double-freeing.
  final Set<EntityId> _freeIdsSet = <EntityId>{};

  /// Registry of all registered component stores.
  final List<SparseSet> _stores = <SparseSet>[];

  /// Helper to register a store with the world so it receives lifecycle events (like entity destruction).
  T _register<T extends SparseSet>(T store) {
    _stores.add(store);
    return store;
  }

  // --- Component Stores ---
  // Each store manages a specific type of data for entities.

  /// Stores position (x, y) and velocity (vx, vy).
  late final TransformStore transform = _register(TransformStore());

  /// Helper components for handling user input events.
  late final PlayerInputStore playerInput = _register(PlayerInputStore());

  /// Logic and state for movement, including facing direction.
  late final MovementStore movement = _register(MovementStore());

  /// Physics properties like mass, friction, and restitution.
  late final BodyStore body = _register(BodyStore());

  /// Axis-Aligned Bounding Box (AABB) for collision detection.
  late final ColliderAabbStore colliderAabb = _register(ColliderAabbStore());

  /// Runtime state of collisions (e.g., is grounded, wall contact).
  late final CollisionStateStore collision = _register(CollisionStateStore());

  /// Generic cooldown timer for abilities or actions.
  late final CooldownStore cooldown = _register(CooldownStore());

  /// Tracks the player's intent to cast a spell (button presses).
  late final CastIntentStore castIntent = _register(CastIntentStore());

  /// Marks an entity as a collectible item (e.g., coin, power-up).
  late final CollectibleStore collectible = _register(CollectibleStore());

  /// Defines an item that restores stats (health/mana) when collected.
  late final RestorationItemStore restorationItem = _register(RestorationItemStore());

  /// Allows an entity to control or defy gravity.
  late final GravityControlStore gravityControl = _register(GravityControlStore());

  /// Defines which faction (Player, Enemy, Neutral) an entity belongs to.
  late final FactionStore faction = _register(FactionStore());

  /// Manages Health Points (HP) and max HP.
  late final HealthStore health = _register(HealthStore());

  /// Grants temporary invulnerability (i-frames).
  late final InvulnerabilityStore invulnerability = _register(InvulnerabilityStore());

  /// Records the last entity/source that dealt damage to this entity.
  late final LastDamageStore lastDamage = _register(LastDamageStore());

  /// Manages Mana Points (MP) and max MP.
  late final ManaStore mana = _register(ManaStore());

  /// Tracks the player's intent to perform a melee attack.
  late final MeleeIntentStore meleeIntent = _register(MeleeIntentStore());

  /// Manages Stamina Points (SP) and max SP.
  late final StaminaStore stamina = _register(StaminaStore());

  /// Marks an entity as a projectile and defines its properties.
  late final ProjectileStore projectile = _register(ProjectileStore());

  /// Defines an area that deals damage or effects on contact.
  late final HitboxStore hitbox = _register(HitboxStore());

  /// Ensures a hitbox only affects a target once per interaction.
  late final HitOnceStore hitOnce = _register(HitOnceStore());

  /// Despawns entities after a set duration.
  late final LifetimeStore lifetime = _register(LifetimeStore());

  /// Links a spell effect back to its caster or origin point.
  late final SpellOriginStore spellOrigin = _register(SpellOriginStore());

  /// State for ground enemies navigating terrain (jumping gaps/walls).
  late final SurfaceNavStateStore surfaceNav = _register(SurfaceNavStateStore());

  /// Identifies an entity as a specific type of enemy.
  late final EnemyStore enemy = _register(EnemyStore());

  /// Steering behaviors for flying enemies.
  late final FlyingEnemySteeringStore flyingEnemySteering = _register(FlyingEnemySteeringStore());

  /// AI state for ground enemies to create offset chasing behaviors.
  late final GroundEnemyChaseOffsetStore groundEnemyChaseOffset =
      _register(GroundEnemyChaseOffsetStore());

  /// Allocates a new [EntityId].
  ///
  /// Prefers reusing ID from the free pool if available; otherwise increments the counter.
  EntityId createEntity() {
    if (_freeIds.isNotEmpty) {
      final id = _freeIds.removeLast();
      _freeIdsSet.remove(id);
      return id;
    }
    final id = _nextEntityId;
    _nextEntityId += 1;
    return id;
  }

  /// Destroys [entity], removing it from all component stores.
  ///
  /// The ID is returned to the free pool for future reuse.
  /// Does nothing if the entity is already destroyed/free.
  void destroyEntity(EntityId entity) {
    if (_freeIdsSet.contains(entity)) {
      return;
    }
    for (final store in _stores) {
      store.removeEntity(entity);
    }
    _freeIds.add(entity);
    _freeIdsSet.add(entity);
  }
}
