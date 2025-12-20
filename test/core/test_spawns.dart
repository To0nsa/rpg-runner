import 'package:walkscape_runner/core/enemies/enemy_id.dart';
import 'package:walkscape_runner/core/ecs/entity_id.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';

// Test-only spawn helpers to keep individual tests focused on behavior.

EntityId spawnFlyingEnemy(
  EcsWorld world, {
  required double posX,
  required double posY,
  double velX = 0.0,
  double velY = 0.0,
  Facing facing = Facing.left,
  BodyDef body = const BodyDef(isKinematic: true, useGravity: false),
  ColliderAabbDef collider = const ColliderAabbDef(halfX: 8, halfY: 8),
  HealthDef health = const HealthDef(hp: 50, hpMax: 50, regenPerSecond: 0),
  ManaDef mana = const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
  StaminaDef stamina = const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
}) {
  return world.createEnemy(
    enemyId: EnemyId.flyingEnemy,
    posX: posX,
    posY: posY,
    velX: velX,
    velY: velY,
    facing: facing,
    body: body,
    collider: collider,
    health: health,
    mana: mana,
    stamina: stamina,
  );
}

EntityId spawnFireWorm(
  EcsWorld world, {
  required double posX,
  required double posY,
  double velX = 0.0,
  double velY = 0.0,
  Facing facing = Facing.left,
  BodyDef body = const BodyDef(isKinematic: true, useGravity: false),
  ColliderAabbDef collider = const ColliderAabbDef(halfX: 8, halfY: 8),
  HealthDef health = const HealthDef(hp: 50, hpMax: 50, regenPerSecond: 0),
  ManaDef mana = const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
  StaminaDef stamina = const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
}) {
  return world.createEnemy(
    enemyId: EnemyId.fireWorm,
    posX: posX,
    posY: posY,
    velX: velX,
    velY: velY,
    facing: facing,
    body: body,
    collider: collider,
    health: health,
    mana: mana,
    stamina: stamina,
  );
}

