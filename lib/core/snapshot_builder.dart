/// Builds immutable render snapshots from ECS world state.
///
/// Decouples snapshot construction from simulation logic. All methods are
/// pure readers—no side effects on [EcsWorld].
library;

import 'dart:math';

import 'ecs/entity_id.dart';
import 'ecs/world.dart';
import 'ecs/stores/restoration_item_store.dart';
import 'collision/static_world_geometry_index.dart';
import 'projectiles/projectile_catalog.dart';
import 'snapshots/enums.dart';
import 'snapshots/entity_render_snapshot.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshots/player_hud_snapshot.dart';
import 'snapshots/static_ground_gap_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
import 'spells/spell_catalog.dart';
import 'spells/spell_id.dart';
import 'tuning/ability_tuning.dart';
import 'tuning/movement_tuning.dart';
import 'tuning/resource_tuning.dart';
import 'util/vec2.dart';

/// Snapshot builder context — holds references needed for snapshot construction.
class SnapshotBuilder {
  SnapshotBuilder({
    required this.world,
    required this.player,
    required this.movement,
    required this.abilities,
    required this.resources,
    required this.spells,
    required this.projectiles,
  });

  final EcsWorld world;
  final EntityId player;
  final MovementTuningDerived movement;
  final AbilityTuningDerived abilities;
  final ResourceTuning resources;
  final SpellCatalog spells;
  final ProjectileCatalogDerived projectiles;

  /// Builds a complete game state snapshot for rendering.
  GameStateSnapshot build({
    required int tick,
    required int seed,
    required double distance,
    required bool paused,
    required bool gameOver,
    required double cameraCenterX,
    required double cameraCenterY,
    required int collectibles,
    required int collectibleScore,
    required List<StaticSolidSnapshot> staticSolids,
    required List<StaticGroundGapSnapshot> groundGaps,
  }) {
    final tuning = movement.base;
    final mi = world.movement.indexOf(player);
    final dashing = world.movement.dashTicksLeft[mi] > 0;
    final onGround = world.collision.grounded[world.collision.indexOf(player)];
    final hi = world.health.indexOf(player);
    final mai = world.mana.indexOf(player);
    final si = world.stamina.indexOf(player);
    final ci = world.cooldown.indexOf(player);

    final stamina = world.stamina.stamina[si];
    final mana = world.mana.mana[mai];
    final projectileManaCost = spells.get(SpellId.iceBolt).stats.manaCost;

    final canAffordJump = stamina >= resources.jumpStaminaCost;
    final canAffordDash = stamina >= resources.dashStaminaCost;
    final canAffordMelee = stamina >= abilities.base.meleeStaminaCost;
    final canAffordProjectile = mana >= projectileManaCost;

    final dashCooldownTicksLeft = world.movement.dashCooldownTicksLeft[mi];
    final meleeCooldownTicksLeft = world.cooldown.meleeCooldownTicksLeft[ci];
    final projectileCooldownTicksLeft = world.cooldown.castCooldownTicksLeft[ci];

    final ti = world.transform.indexOf(player);
    final playerPosX = world.transform.posX[ti];
    final playerPosY = world.transform.posY[ti];
    final playerVelX = world.transform.velX[ti];
    final playerVelY = world.transform.velY[ti];
    final playerFacing = world.movement.facing[mi];

    final AnimKey anim;
    if (dashing) {
      anim = AnimKey.run;
    } else if (!onGround) {
      anim = playerVelY < 0 ? AnimKey.jump : AnimKey.fall;
    } else if (playerVelX.abs() > tuning.minMoveSpeed) {
      anim = AnimKey.run;
    } else {
      anim = AnimKey.idle;
    }

    final playerPos = Vec2(playerPosX, playerPosY);
    final playerVel = Vec2(playerVelX, playerVelY);

    final entities = <EntityRenderSnapshot>[
      EntityRenderSnapshot(
        id: player,
        kind: EntityKind.player,
        pos: playerPos,
        vel: playerVel,
        size: Vec2(tuning.playerRadius * 2, tuning.playerRadius * 2),
        facing: playerFacing,
        anim: anim,
        grounded: onGround,
      ),
    ];

    _addProjectiles(entities);
    _addHitboxes(entities);
    _addCollectibles(entities);
    _addRestorationItems(entities);
    _addEnemies(entities);

    return GameStateSnapshot(
      tick: tick,
      seed: seed,
      distance: distance,
      paused: paused,
      gameOver: gameOver,
      cameraCenterX: cameraCenterX,
      cameraCenterY: cameraCenterY,
      hud: PlayerHudSnapshot(
        hp: world.health.hp[hi],
        hpMax: world.health.hpMax[hi],
        mana: mana,
        manaMax: world.mana.manaMax[mai],
        stamina: stamina,
        staminaMax: world.stamina.staminaMax[si],
        canAffordJump: canAffordJump,
        canAffordDash: canAffordDash,
        canAffordMelee: canAffordMelee,
        canAffordProjectile: canAffordProjectile,
        dashCooldownTicksLeft: dashCooldownTicksLeft,
        dashCooldownTicksTotal: movement.dashCooldownTicks,
        meleeCooldownTicksLeft: meleeCooldownTicksLeft,
        meleeCooldownTicksTotal: abilities.meleeCooldownTicks,
        projectileCooldownTicksLeft: projectileCooldownTicksLeft,
        projectileCooldownTicksTotal: abilities.castCooldownTicks,
        collectibles: collectibles,
        collectibleScore: collectibleScore,
      ),
      entities: entities,
      staticSolids: staticSolids,
      groundGaps: groundGaps,
    );
  }

  void _addProjectiles(List<EntityRenderSnapshot> entities) {
    final projectileStore = world.projectile;
    for (var pi = 0; pi < projectileStore.denseEntities.length; pi += 1) {
      final e = projectileStore.denseEntities[pi];
      if (!world.transform.has(e)) continue;
      final ti = world.transform.indexOf(e);

      final projectileId = projectileStore.projectileId[pi];
      final proj = projectiles.base.get(projectileId);
      final colliderSize = Vec2(proj.colliderSizeX, proj.colliderSizeY);

      final dirX = projectileStore.dirX[pi];
      final dirY = projectileStore.dirY[pi];
      final facing = dirX >= 0 ? Facing.right : Facing.left;
      final rotationRad = atan2(dirY, dirX);

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.projectile,
          pos: Vec2(world.transform.posX[ti], world.transform.posY[ti]),
          vel: Vec2(world.transform.velX[ti], world.transform.velY[ti]),
          size: colliderSize,
          projectileId: projectileId,
          facing: facing,
          rotationRad: rotationRad,
          anim: AnimKey.idle,
          grounded: false,
        ),
      );
    }
  }

  void _addHitboxes(List<EntityRenderSnapshot> entities) {
    final hitboxes = world.hitbox;
    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final e = hitboxes.denseEntities[hi];
      if (!world.transform.has(e)) continue;
      final ti = world.transform.indexOf(e);

      final size = Vec2(hitboxes.halfX[hi] * 2, hitboxes.halfY[hi] * 2);
      final dirX = hitboxes.dirX[hi];
      final dirY = hitboxes.dirY[hi];
      final facing = dirX >= 0 ? Facing.right : Facing.left;
      final rotationRad = atan2(dirY, dirX);

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.trigger,
          pos: Vec2(world.transform.posX[ti], world.transform.posY[ti]),
          size: size,
          facing: facing,
          rotationRad: rotationRad,
          anim: AnimKey.hit,
          grounded: false,
        ),
      );
    }
  }

  void _addCollectibles(List<EntityRenderSnapshot> entities) {
    final collectiblesStore = world.collectible;
    for (var ci = 0; ci < collectiblesStore.denseEntities.length; ci += 1) {
      final e = collectiblesStore.denseEntities[ci];
      if (!world.transform.has(e)) continue;
      final ti = world.transform.indexOf(e);

      Vec2? size;
      if (world.colliderAabb.has(e)) {
        final aabbi = world.colliderAabb.indexOf(e);
        size = Vec2(
          world.colliderAabb.halfX[aabbi] * 2,
          world.colliderAabb.halfY[aabbi] * 2,
        );
      }

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.pickup,
          pos: Vec2(world.transform.posX[ti], world.transform.posY[ti]),
          size: size,
          facing: Facing.right,
          pickupVariant: PickupVariant.collectible,
          rotationRad: pi * 0.25,
          anim: AnimKey.idle,
          grounded: false,
        ),
      );
    }
  }

  void _addRestorationItems(List<EntityRenderSnapshot> entities) {
    final restorationStore = world.restorationItem;
    for (var ri = 0; ri < restorationStore.denseEntities.length; ri += 1) {
      final e = restorationStore.denseEntities[ri];
      if (!world.transform.has(e)) continue;
      final ti = world.transform.indexOf(e);

      Vec2? size;
      if (world.colliderAabb.has(e)) {
        final aabbi = world.colliderAabb.indexOf(e);
        size = Vec2(
          world.colliderAabb.halfX[aabbi] * 2,
          world.colliderAabb.halfY[aabbi] * 2,
        );
      }

      final stat = restorationStore.stat[ri];
      int variant;
      switch (stat) {
        case RestorationStat.health:
          variant = PickupVariant.restorationHealth;
        case RestorationStat.mana:
          variant = PickupVariant.restorationMana;
        case RestorationStat.stamina:
          variant = PickupVariant.restorationStamina;
      }

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.pickup,
          pos: Vec2(world.transform.posX[ti], world.transform.posY[ti]),
          size: size,
          facing: Facing.right,
          pickupVariant: variant,
          rotationRad: pi * 0.25,
          anim: AnimKey.idle,
          grounded: false,
        ),
      );
    }
  }

  void _addEnemies(List<EntityRenderSnapshot> entities) {
    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      if (!world.transform.has(e)) continue;
      final ti = world.transform.indexOf(e);

      Vec2? size;
      if (world.colliderAabb.has(e)) {
        final aabbi = world.colliderAabb.indexOf(e);
        size = Vec2(
          world.colliderAabb.halfX[aabbi] * 2,
          world.colliderAabb.halfY[aabbi] * 2,
        );
      }

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.enemy,
          pos: Vec2(world.transform.posX[ti], world.transform.posY[ti]),
          vel: Vec2(world.transform.velX[ti], world.transform.velY[ti]),
          size: size,
          facing: enemies.facing[ei],
          anim: AnimKey.idle,
          grounded: world.collision.has(e)
              ? world.collision.grounded[world.collision.indexOf(e)]
              : false,
        ),
      );
    }
  }
}

/// Builds static solid snapshots from geometry.
List<StaticSolidSnapshot> buildStaticSolidsSnapshot(
  StaticWorldGeometry geometry,
) {
  return List<StaticSolidSnapshot>.unmodifiable(
    geometry.solids.map(
      (s) => StaticSolidSnapshot(
        minX: s.minX,
        minY: s.minY,
        maxX: s.maxX,
        maxY: s.maxY,
        sides: s.sides,
        oneWayTop: s.oneWayTop,
      ),
    ),
  );
}

/// Builds ground gap snapshots from geometry.
List<StaticGroundGapSnapshot> buildGroundGapsSnapshot(
  StaticWorldGeometry geometry,
) {
  if (geometry.groundGaps.isEmpty) {
    return const <StaticGroundGapSnapshot>[];
  }
  return List<StaticGroundGapSnapshot>.unmodifiable(
    geometry.groundGaps.map(
      (g) => StaticGroundGapSnapshot(minX: g.minX, maxX: g.maxX),
    ),
  );
}
