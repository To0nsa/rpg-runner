import 'dart:math';

import '../combat/faction.dart';
import '../ecs/entity_id.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/lifetime_store.dart';
import '../ecs/stores/projectile_store.dart';
import '../ecs/stores/spell_origin_store.dart';
import '../ecs/world.dart';
import '../projectiles/projectile_catalog.dart';
import 'spell_catalog.dart';
import 'spell_id.dart';

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

  final len2 = dirX * dirX + dirY * dirY;
  double nx;
  double ny;
  if (len2 <= 1e-12) {
    nx = 1.0;
    ny = 0.0;
  } else {
    final invLen = 1.0 / sqrt(len2);
    nx = dirX * invLen;
    ny = dirY * invLen;
  }

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
      dirX: nx,
      dirY: ny,
      speedUnitsPerSecond: proj.speedUnitsPerSecond,
      damage: spell.stats.damage,
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

