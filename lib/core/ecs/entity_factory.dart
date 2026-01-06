import '../combat/faction.dart';
import '../enemies/enemy_id.dart';
import '../snapshots/enums.dart';
import '../util/deterministic_rng.dart';
import 'entity_id.dart';
import 'stores/body_store.dart';
import 'stores/collider_aabb_store.dart';
import 'stores/enemy_store.dart';
import 'stores/faction_store.dart';
import 'stores/flying_enemy_steering_store.dart';
import 'stores/ground_enemy_chase_offset_store.dart';
import 'stores/health_store.dart';
import 'stores/mana_store.dart';
import 'stores/stamina_store.dart';
import 'world.dart';

/// Factory for creating complex entities composed of multiple components.
class EntityFactory {
  EntityFactory(this.world);

  final EcsWorld world;

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
    // Player-only invulnerability window (i-frames) after taking damage.
    world.invulnerability.add(id);
    world.lastDamage.add(id);
    world.mana.add(id, mana);
    world.meleeIntent.add(id);
    world.stamina.add(id, stamina);
    world.collision.grounded[world.collision.indexOf(id)] = grounded;
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
