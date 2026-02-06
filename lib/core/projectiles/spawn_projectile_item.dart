/// Projectile spawning utilities for projectile slot items.
library;

import 'dart:math';

import '../combat/damage_type.dart';
import '../combat/faction.dart';
import '../ecs/entity_id.dart';
import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/lifetime_store.dart';
import '../ecs/stores/projectile_item_origin_store.dart';
import '../ecs/stores/projectile_store.dart';
import '../ecs/world.dart';
import '../projectiles/projectile_catalog.dart';
import '../projectiles/projectile_id.dart';
import '../projectiles/projectile_item_id.dart';
import '../weapons/weapon_proc.dart';

const _dirEps2 = 1e-12;

({double x, double y}) _normalizeDirOrFallback(
  double x,
  double y, {
  required double fallbackX,
  required double fallbackY,
}) {
  final len2 = x * x + y * y;
  if (len2 <= _dirEps2) {
    final fbLen2 = fallbackX * fallbackX + fallbackY * fallbackY;
    if (fbLen2 <= _dirEps2) {
      return (x: 1.0, y: 0.0);
    }
    final invLen = 1.0 / sqrt(fbLen2);
    return (x: fallbackX * invLen, y: fallbackY * invLen);
  }

  final invLen = 1.0 / sqrt(len2);
  return (x: x * invLen, y: y * invLen);
}

EntityId spawnProjectileItemFromCaster(
  EcsWorld world, {
  required ProjectileCatalogDerived projectiles,
  required ProjectileItemId projectileItemId,
  required ProjectileId projectileId,
  required Faction faction,
  required EntityId owner,
  required double casterX,
  required double casterY,
  required double originOffset,
  required double dirX,
  required double dirY,
  required double fallbackDirX,
  required double fallbackDirY,
  required int damage100,
  required int critChanceBp,
  required DamageType damageType,
  List<WeaponProc> procs = const <WeaponProc>[],
  required bool ballistic,
  required double gravityScale,
}) {
  final proj = projectiles.base.get(projectileId);
  final speedUnitsPerSecond = proj.speedUnitsPerSecond;

  final dir = _normalizeDirOrFallback(
    dirX,
    dirY,
    fallbackX: fallbackDirX,
    fallbackY: fallbackDirY,
  );

  final originX = casterX + dir.x * originOffset;
  final originY = casterY + dir.y * originOffset;

  final entity = world.createEntity();

  final initialVelX = ballistic ? dir.x * speedUnitsPerSecond : 0.0;
  final initialVelY = ballistic ? dir.y * speedUnitsPerSecond : 0.0;

  world.transform.add(
    entity,
    posX: originX,
    posY: originY,
    velX: initialVelX,
    velY: initialVelY,
  );

  world.projectile.add(
    entity,
    ProjectileDef(
      projectileId: projectileId,
      faction: faction,
      owner: owner,
      dirX: dir.x,
      dirY: dir.y,
      speedUnitsPerSecond: speedUnitsPerSecond,
      damage100: damage100,
      critChanceBp: critChanceBp,
      damageType: damageType,
      procs: procs,
      usePhysics: ballistic,
    ),
  );

  world.projectileItemOrigin.add(
    entity,
    ProjectileItemOriginDef(projectileItemId: projectileItemId),
  );

  world.lifetime.add(
    entity,
    LifetimeDef(ticksLeft: projectiles.lifetimeTicks(projectileId)),
  );

  world.colliderAabb.add(
    entity,
    ColliderAabbDef(
      halfX: proj.colliderSizeX * 0.5,
      halfY: proj.colliderSizeY * 0.5,
    ),
  );

  if (ballistic) {
    world.body.add(
      entity,
      BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: gravityScale,
        sideMask: BodyDef.sideLeft | BodyDef.sideRight,
      ),
    );
    world.collision.add(entity);
  }

  return entity;
}
