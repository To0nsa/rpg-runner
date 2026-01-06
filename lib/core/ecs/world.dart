import '../snapshots/enums.dart';
import '../combat/faction.dart';
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
import '../enemies/enemy_id.dart';
import '../util/deterministic_rng.dart';

/// Minimal ECS world container (V0).
///
/// Entity IDs are recycled to limit memory growth.
class EcsWorld {
  EcsWorld({int seed = 0}) : seed = seed;

  /// Seed used for deterministic RNG in the core.
  final int seed;

  EntityId _nextEntityId = 1;
  final List<EntityId> _freeIds = <EntityId>[];
  final List<SparseSet> _stores = <SparseSet>[];

  T _register<T extends SparseSet>(T store) {
    _stores.add(store);
    return store;
  }

  late final TransformStore transform = _register(TransformStore());
  late final PlayerInputStore playerInput = _register(PlayerInputStore());
  late final MovementStore movement = _register(MovementStore());
  late final BodyStore body = _register(BodyStore());
  late final ColliderAabbStore colliderAabb = _register(ColliderAabbStore());
  late final CollisionStateStore collision = _register(CollisionStateStore());
  late final CooldownStore cooldown = _register(CooldownStore());
  late final CastIntentStore castIntent = _register(CastIntentStore());
  late final CollectibleStore collectible = _register(CollectibleStore());
  late final RestorationItemStore restorationItem = _register(RestorationItemStore());
  late final GravityControlStore gravityControl = _register(GravityControlStore());
  late final FactionStore faction = _register(FactionStore());
  late final HealthStore health = _register(HealthStore());
  late final InvulnerabilityStore invulnerability = _register(InvulnerabilityStore());
  late final LastDamageStore lastDamage = _register(LastDamageStore());
  late final ManaStore mana = _register(ManaStore());
  late final MeleeIntentStore meleeIntent = _register(MeleeIntentStore());
  late final StaminaStore stamina = _register(StaminaStore());
  late final ProjectileStore projectile = _register(ProjectileStore());
  late final HitboxStore hitbox = _register(HitboxStore());
  late final HitOnceStore hitOnce = _register(HitOnceStore());
  late final LifetimeStore lifetime = _register(LifetimeStore());
  late final SpellOriginStore spellOrigin = _register(SpellOriginStore());
  late final SurfaceNavStateStore surfaceNav = _register(SurfaceNavStateStore());
  late final EnemyStore enemy = _register(EnemyStore());
  late final FlyingEnemySteeringStore flyingEnemySteering = _register(FlyingEnemySteeringStore());
  late final GroundEnemyChaseOffsetStore groundEnemyChaseOffset =
      _register(GroundEnemyChaseOffsetStore());

  EntityId createEntity() {
    if (_freeIds.isNotEmpty) {
      return _freeIds.removeLast();
    }
    final id = _nextEntityId;
    _nextEntityId += 1;
    return id;
  }

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
    final id = createEntity();
    transform.add(id, posX: posX, posY: posY, velX: velX, velY: velY);
    playerInput.add(id);
    movement.add(id, facing: facing);
    this.body.add(id, body);
    colliderAabb.add(id, collider);
    collision.add(id);
    cooldown.add(id);
    castIntent.add(id);
    faction.add(id, const FactionDef(faction: Faction.player));
    this.health.add(id, health);
    // Player-only invulnerability window (i-frames) after taking damage.
    invulnerability.add(id);
    lastDamage.add(id);
    this.mana.add(id, mana);
    meleeIntent.add(id);
    this.stamina.add(id, stamina);
    collision.grounded[collision.indexOf(id)] = grounded;
    return id;
  }

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
    final id = createEntity();
    transform.add(id, posX: posX, posY: posY, velX: velX, velY: velY);
    this.body.add(id, body);
    colliderAabb.add(id, collider);
    collision.add(id);
    cooldown.add(id);
    castIntent.add(id);
    faction.add(id, const FactionDef(faction: Faction.enemy));
    this.health.add(id, health);
    // Intentionally no `InvulnerabilityStore`: invulnerability is player-only in V0.
    this.mana.add(id, mana);
    meleeIntent.add(id);
    this.stamina.add(id, stamina);
    enemy.add(id, EnemyDef(enemyId: enemyId, facing: facing));
    if (enemyId == EnemyId.flyingEnemy) {
      flyingEnemySteering.add(
        id,
        FlyingEnemySteeringDef(rngState: seedFrom(seed, id)),
      );
    }
    if (enemyId == EnemyId.groundEnemy) {
      surfaceNav.add(id);
      groundEnemyChaseOffset.add(
        id,
        GroundEnemyChaseOffsetDef(rngState: seedFrom(seed, id)),
      );
    }
    return id;
  }

  void destroyEntity(EntityId entity) {
    for (final store in _stores) {
      store.removeEntity(entity);
    }
    _freeIds.add(entity);
  }
}
