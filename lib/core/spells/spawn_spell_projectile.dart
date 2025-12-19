import 'dart:math';

import '../combat/faction.dart';
import '../ecs/entity_id.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/lifetime_store.dart';
import '../ecs/stores/projectile_store.dart';
import '../ecs/stores/spell_origin_store.dart';
import '../ecs/world.dart';
import '../projectiles/projectile_catalog.dart';
import '../projectiles/projectile_id.dart';
import 'spell_catalog.dart';
import 'spell_id.dart';

// Centralize spell->projectile checks and direction normalization here so
// player/enemy casting cannot drift over time.
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

EntityId _spawnResolvedSpellProjectile(
  EcsWorld world, {
  required ProjectileCatalogDerived projectiles,
  required SpellId spellId,
  required ProjectileId projectileId,
  required Faction faction,
  required EntityId owner,
  required double originX,
  required double originY,
  required double dirX,
  required double dirY,
  required double speedUnitsPerSecond,
  required double damage,
}) {
  final proj = projectiles.base.get(projectileId);
  final halfX = proj.colliderSizeX * 0.5;
  final halfY = proj.colliderSizeY * 0.5;

  final entity = world.createEntity();
  world.transform.add(
    entity,
    posX: originX,
    posY: originY,
    velX: 0.0,
    velY: 0.0,
  );
  world.projectile.add(
    entity,
    ProjectileDef(
      projectileId: projectileId,
      faction: faction,
      owner: owner,
      dirX: dirX,
      dirY: dirY,
      speedUnitsPerSecond: speedUnitsPerSecond,
      damage: damage,
    ),
  );
  world.spellOrigin.add(entity, SpellOriginDef(spellId: spellId));
  world.lifetime.add(
    entity,
    LifetimeDef(ticksLeft: projectiles.lifetimeTicks(projectileId)),
  );

  // Projectiles participate in hit resolution using the same AABB model as actors.
  world.colliderAabb.add(entity, ColliderAabbDef(halfX: halfX, halfY: halfY));

  return entity;
}

/// Spawns a spell projectile from a caster position with a consistent origin
/// offset along the cast direction.
///
/// Call sites should pass the raw direction (e.g. aim vector, target delta) and
/// a normalized fallback (e.g. facing direction). This function normalizes once
/// and guarantees consistent behavior across player/enemy casting.
EntityId? spawnSpellProjectileFromCaster(
  EcsWorld world, {
  required SpellCatalog spells,
  required ProjectileCatalogDerived projectiles,
  required SpellId spellId,
  required Faction faction,
  required EntityId owner,
  required double casterX,
  required double casterY,
  required double originOffset,
  required double dirX,
  required double dirY,
  required double fallbackDirX,
  required double fallbackDirY,
}) {
  final spell = spells.get(spellId);
  final projectileId = spell.projectileId;
  if (projectileId == null) return null;

  final dir = _normalizeDirOrFallback(
    dirX,
    dirY,
    fallbackX: fallbackDirX,
    fallbackY: fallbackDirY,
  );

  final originX = casterX + dir.x * originOffset;
  final originY = casterY + dir.y * originOffset;

  return _spawnResolvedSpellProjectile(
    world,
    projectiles: projectiles,
    spellId: spellId,
    projectileId: projectileId,
    faction: faction,
    owner: owner,
    originX: originX,
    originY: originY,
    dirX: dir.x,
    dirY: dir.y,
    speedUnitsPerSecond: projectiles.base.get(projectileId).speedUnitsPerSecond,
    damage: spell.stats.damage,
  );
}

EntityId? spawnSpellProjectile(
  EcsWorld world, {
  required SpellCatalog spells,
  required ProjectileCatalogDerived projectiles,
  required SpellId spellId,
  required Faction faction,
  required EntityId owner,
  required double originX,
  required double originY,
  required double dirX,
  required double dirY,
}) {
  final spell = spells.get(spellId);
  final projectileId = spell.projectileId;
  if (projectileId == null) return null;

  final dir = _normalizeDirOrFallback(
    dirX,
    dirY,
    fallbackX: 1.0,
    fallbackY: 0.0,
  );

  return _spawnResolvedSpellProjectile(
    world,
    projectiles: projectiles,
    spellId: spellId,
    projectileId: projectileId,
    faction: faction,
    owner: owner,
    originX: originX,
    originY: originY,
    dirX: dir.x,
    dirY: dir.y,
    speedUnitsPerSecond: projectiles.base.get(projectileId).speedUnitsPerSecond,
    damage: spell.stats.damage,
  );
}
