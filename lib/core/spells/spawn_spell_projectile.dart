/// Projectile spawning utilities for spell casting.
///
/// Centralizes direction normalization and projectile entity creation so
/// player and enemy casting behave consistently.
library;

import 'dart:math';

import '../combat/damage_type.dart';
import '../combat/faction.dart';
import '../combat/status/status.dart';
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

/// Epsilon squared for near-zero direction detection.
const _dirEps2 = 1e-12;

/// Normalizes a direction vector, falling back if near-zero.
({double x, double y}) _normalizeDirOrFallback(
  double x,
  double y, {
  required double fallbackX,
  required double fallbackY,
}) {
  final len2 = x * x + y * y;

  // Primary direction too small – try fallback.
  if (len2 <= _dirEps2) {
    final fbLen2 = fallbackX * fallbackX + fallbackY * fallbackY;
    // Fallback also degenerate – default to rightward.
    if (fbLen2 <= _dirEps2) {
      return (x: 1.0, y: 0.0);
    }
    final invLen = 1.0 / sqrt(fbLen2);
    return (x: fallbackX * invLen, y: fallbackY * invLen);
  }

  // Normal case: normalize primary direction.
  final invLen = 1.0 / sqrt(len2);
  return (x: x * invLen, y: y * invLen);
}

/// Internal: creates the projectile entity with all required components.
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
  required DamageType damageType,
  required StatusProfileId statusProfileId,
}) {
  // Lookup base projectile def for collider dimensions.
  final proj = projectiles.base.get(projectileId);
  final halfX = proj.colliderSizeX * 0.5;
  final halfY = proj.colliderSizeY * 0.5;

  // Allocate entity ID.
  final entity = world.createEntity();

  // Position at spawn origin; velocity applied by ProjectileSystem.
  world.transform.add(
    entity,
    posX: originX,
    posY: originY,
    velX: 0.0,
    velY: 0.0,
  );

  // Combat data: direction, speed, faction for hit resolution.
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
      damageType: damageType,
      statusProfileId: statusProfileId,
    ),
  );

  // Track originating spell for FX/scoring.
  world.spellOrigin.add(entity, SpellOriginDef(spellId: spellId));

  // Auto-destroy after catalog-defined lifetime.
  world.lifetime.add(
    entity,
    LifetimeDef(ticksLeft: projectiles.lifetimeTicks(projectileId)),
  );

  // AABB for collision detection against actors.
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
  // Overrides (Phase 4)
  // Overrides (Phase 4)
  ProjectileId? overrideProjectileId,
  int? overrideDamage100,
  DamageType? overrideDamageType,
  StatusProfileId? overrideStatusProfileId, // TODO: List<WeaponProc>?
}) {
  // Bail early if spell doesn't spawn a projectile.
  final spell = spells.get(spellId);
  final projectileId = overrideProjectileId ?? spell.projectileId;
  if (projectileId == null) return null;

  // Normalize aim; use fallback (e.g. facing) if aim is zero.
  final dir = _normalizeDirOrFallback(
    dirX,
    dirY,
    fallbackX: fallbackDirX,
    fallbackY: fallbackDirY,
  );

  // Offset spawn along direction so projectile starts outside caster.
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
    damage: overrideDamage100 != null ? overrideDamage100 / 100.0 : spell.stats.damage,
    damageType: overrideDamageType ?? spell.stats.damageType,
    statusProfileId: overrideStatusProfileId ?? spell.stats.statusProfileId,
  );

}

/// Spawns a spell projectile at an explicit origin position.
///
/// Use this when the spawn point is already computed. Direction is normalized
/// internally; falls back to rightward (1, 0) if near-zero.
///
/// Returns `null` if the spell has no associated projectile.
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
  // Bail early if spell doesn't spawn a projectile.
  final spell = spells.get(spellId);
  final projectileId = spell.projectileId;
  if (projectileId == null) return null;

  // Normalize; default rightward if degenerate.
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
    damageType: spell.stats.damageType,
    statusProfileId: spell.stats.statusProfileId,
  );
}
