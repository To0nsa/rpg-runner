/// Projectile spawning utilities for ranged weapons.
///
/// Similar to spell projectile spawning, but does not use [SpellId] or mana.
library;

import 'dart:math';

import '../combat/damage_type.dart';
import '../combat/faction.dart';
import '../combat/status/status.dart';
import '../ecs/entity_id.dart';
import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/lifetime_store.dart';
import '../ecs/stores/projectile_store.dart';
import '../ecs/world.dart';
import '../projectiles/projectile_catalog.dart';
import '../projectiles/projectile_id.dart';

/// Epsilon squared for near-zero direction detection.
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

EntityId spawnRangedWeaponProjectileFromCaster(
  EcsWorld world, {
  required ProjectileCatalogDerived projectiles,
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
  required DamageType damageType,
  required StatusProfileId statusProfileId,
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

  // Position and initial velocity.
  final initialVelX = dir.x * speedUnitsPerSecond;
  final initialVelY = dir.y * speedUnitsPerSecond;
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
      damage: damage100 / 100.0,
      damageType: damageType,
      statusProfileId: statusProfileId,
      usePhysics: ballistic,
    ),
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

