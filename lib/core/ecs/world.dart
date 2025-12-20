import '../snapshots/enums.dart';
import '../combat/faction.dart';
import 'entity_id.dart';
import 'stores/body_store.dart';
import 'stores/collider_aabb_store.dart';
import 'stores/collision_state_store.dart';
import 'stores/cooldown_store.dart';
import 'stores/cast_intent_store.dart';
import 'stores/gravity_control_store.dart';
import 'stores/flying_enemy_steering_store.dart';
import 'stores/ground_enemy_locomotion_store.dart';
import 'stores/faction_store.dart';
import 'stores/enemy_store.dart';
import 'stores/health_store.dart';
import 'stores/hit_once_store.dart';
import 'stores/hitbox_store.dart';
import 'stores/invulnerability_store.dart';
import 'stores/lifetime_store.dart';
import 'stores/mana_store.dart';
import 'stores/melee_intent_store.dart';
import 'stores/movement_store.dart';
import 'stores/player_input_store.dart';
import 'stores/projectile_store.dart';
import 'stores/spell_origin_store.dart';
import 'stores/stamina_store.dart';
import 'stores/transform_store.dart';
import '../enemies/enemy_id.dart';
import '../util/deterministic_rng.dart';

/// Minimal ECS world container (V0).
///
/// Entity IDs are monotonic and never reused.
class EcsWorld {
  EcsWorld({int seed = 0}) : seed = seed;

  /// Seed used for deterministic RNG in the core.
  final int seed;

  EntityId _nextEntityId = 1;

  final TransformStore transform = TransformStore();
  final PlayerInputStore playerInput = PlayerInputStore();
  final MovementStore movement = MovementStore();
  final BodyStore body = BodyStore();
  final ColliderAabbStore colliderAabb = ColliderAabbStore();
  final CollisionStateStore collision = CollisionStateStore();
  final CooldownStore cooldown = CooldownStore();
  final CastIntentStore castIntent = CastIntentStore();
  final GravityControlStore gravityControl = GravityControlStore();
  final FactionStore faction = FactionStore();
  final HealthStore health = HealthStore();
  final InvulnerabilityStore invulnerability = InvulnerabilityStore();
  final ManaStore mana = ManaStore();
  final MeleeIntentStore meleeIntent = MeleeIntentStore();
  final StaminaStore stamina = StaminaStore();
  final ProjectileStore projectile = ProjectileStore();
  final HitboxStore hitbox = HitboxStore();
  final HitOnceStore hitOnce = HitOnceStore();
  final LifetimeStore lifetime = LifetimeStore();
  final SpellOriginStore spellOrigin = SpellOriginStore();
  final EnemyStore enemy = EnemyStore();
  final FlyingEnemySteeringStore flyingEnemySteering = FlyingEnemySteeringStore();
  final GroundEnemyLocomotionStore groundEnemyLocomotion =
      GroundEnemyLocomotionStore();

  EntityId createEntity() {
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
      groundEnemyLocomotion.add(id);
    }
    return id;
  }

  void destroyEntity(EntityId entity) {
    transform.removeEntity(entity);
    playerInput.removeEntity(entity);
    movement.removeEntity(entity);
    body.removeEntity(entity);
    colliderAabb.removeEntity(entity);
    collision.removeEntity(entity);
    cooldown.removeEntity(entity);
    castIntent.removeEntity(entity);
    gravityControl.removeEntity(entity);
    faction.removeEntity(entity);
    health.removeEntity(entity);
    invulnerability.removeEntity(entity);
    mana.removeEntity(entity);
    meleeIntent.removeEntity(entity);
    stamina.removeEntity(entity);
    projectile.removeEntity(entity);
    hitbox.removeEntity(entity);
    hitOnce.removeEntity(entity);
    lifetime.removeEntity(entity);
    spellOrigin.removeEntity(entity);
    enemy.removeEntity(entity);
    flyingEnemySteering.removeEntity(entity);
    groundEnemyLocomotion.removeEntity(entity);
  }
}
