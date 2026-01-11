/// Builds immutable render snapshots from ECS world state.
///
/// This module decouples snapshot construction from simulation logic,
/// providing a clean separation between the game's internal state (ECS)
/// and the data consumed by the rendering layer.
///
/// All methods are pure readers—no side effects on [EcsWorld].
///
/// ## Architecture
///
/// The render layer never reads ECS directly. Instead, [GameCore] calls
/// [SnapshotBuilder.build] once per tick to produce a [GameStateSnapshot],
/// which is an immutable, self-contained description of everything needed
/// to draw a single frame.
///
/// ## Key Types
///
/// - [SnapshotBuilder] — Stateful builder holding ECS and tuning references.
/// - [GameStateSnapshot] — Complete frame data (entities, HUD, geometry).
/// - [EntityRenderSnapshot] — Per-entity render info (position, animation, etc.).
/// - [PlayerHudSnapshot] — Player resource bars, cooldowns, affordability flags.
library;

import 'dart:math';

import 'ecs/entity_id.dart';
import 'ecs/world.dart';
import 'ecs/stores/restoration_item_store.dart';
import 'levels/level_id.dart';
import 'projectiles/projectile_catalog.dart';
import 'snapshots/enums.dart';
import 'snapshots/entity_render_snapshot.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshots/player_hud_snapshot.dart';
import 'snapshots/static_ground_gap_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
import 'spells/spell_catalog.dart';
import 'spells/spell_id.dart';
import 'tuning/player/player_ability_tuning.dart';
import 'tuning/player/player_anim_tuning.dart';
import 'tuning/player/player_movement_tuning.dart';
import 'tuning/player/player_resource_tuning.dart';
import 'util/vec2.dart';
import 'weapons/ranged_weapon_catalog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SnapshotBuilder
// ─────────────────────────────────────────────────────────────────────────────

/// Constructs [GameStateSnapshot] instances from ECS world state.
///
/// Holds references to the ECS world and all tuning data needed to compute
/// derived values (e.g., cooldown progress, affordability flags).
///
/// Usage:
/// ```dart
/// final builder = SnapshotBuilder(world: ..., player: ..., ...);
/// final snapshot = builder.build(tick: 42, ...);
/// ```
class SnapshotBuilder {
  /// Creates a snapshot builder with the given dependencies.
  ///
  /// - [world]: The ECS world containing all entity component data.
  /// - [player]: Entity ID of the player (used to query player-specific stores).
  /// - [movement]: Derived movement tuning (dash cooldown ticks, etc.).
  /// - [abilities]: Derived ability tuning (melee/cast cooldown ticks).
  /// - [animTuning]: Derived animation tuning (hit/cast/attack/spawn windows).
  /// - [resources]: Resource costs (jump/dash stamina, etc.).
  /// - [spells]: Spell catalog for querying spell stats (mana costs).
  /// - [projectiles]: Projectile catalog for collider sizes.
  /// - [rangedWeapons]: Ranged weapon catalog (cooldowns/ammo costs).
  SnapshotBuilder({
    required this.world,
    required this.player,
    required this.movement,
    required this.abilities,
    required this.animTuning,
    required this.resources,
    required this.spells,
    required this.projectiles,
    required this.rangedWeapons,
  });

  /// The ECS world containing all game entity data.
  final EcsWorld world;

  /// Entity ID of the player character.
  final EntityId player;

  /// Derived movement tuning (pre-computed tick-based values).
  final MovementTuningDerived movement;

  /// Derived ability tuning (cooldown durations in ticks).
  final AbilityTuningDerived abilities;

  /// Derived animation tuning (one-shot windows in ticks).
  final AnimTuningDerived animTuning;

  /// Resource tuning (stamina/mana costs for actions).
  final ResourceTuning resources;

  /// Spell catalog for looking up spell stats.
  final SpellCatalog spells;

  /// Projectile catalog for collider dimensions.
  final ProjectileCatalogDerived projectiles;

  /// Ranged weapon catalog for cooldown totals and ammo costs.
  final RangedWeaponCatalogDerived rangedWeapons;

  // ───────────────────────────────────────────────────────────────────────────
  // Public API
  // ───────────────────────────────────────────────────────────────────────────

  /// Builds a complete [GameStateSnapshot] for the current tick.
  ///
  /// This method reads from multiple ECS component stores to assemble:
  /// - Player state (position, velocity, animation, facing direction)
  /// - HUD data (HP, mana, stamina, cooldowns, affordability)
  /// - All entity render snapshots (player, enemies, projectiles, pickups)
  /// - Static geometry (platforms, ground gaps)
  ///
  /// Parameters:
  /// - [tick]: Current simulation tick number.
  /// - [seed]: RNG seed for this run (stored for replay/debug).
  /// - [levelId]: Level identifier for this run (stored for replay/debug).
  /// - [themeId]: Optional render theme identifier (stored for debug/UI).
  /// - [distance]: Total distance traveled (world units).
  /// - [paused]: Whether the game is currently paused.
  /// - [gameOver]: Whether the run has ended.
  /// - [cameraCenterX], [cameraCenterY]: Camera focus point (world coords).
  /// - [collectibles]: Number of collectibles picked up this run.
  /// - [collectibleScore]: Total score from collectibles.
  /// - [staticSolids]: Pre-built list of platform snapshots.
  /// - [groundGaps]: Pre-built list of ground gap snapshots.
  GameStateSnapshot build({
    required int tick,
    required int seed,
    required LevelId levelId,
    required String? themeId,
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
    // ─── Query player component indices ───
    final tuning = movement.base;
    final mi = world.movement.indexOf(player);
    final dashTicksLeft = world.movement.dashTicksLeft[mi];
    final dashing = dashTicksLeft > 0;
    final onGround = world.collision.grounded[world.collision.indexOf(player)];
    final hi = world.health.indexOf(player);
    final mai = world.mana.indexOf(player);
    final si = world.stamina.indexOf(player);
    final ci = world.cooldown.indexOf(player);
    final rwi = world.equippedRangedWeapon.indexOf(player);
    final ami = world.ammo.indexOf(player);

    // ─── Read current resource values ───
    final stamina = world.stamina.stamina[si];
    final mana = world.mana.mana[mai];
    final projectileManaCost = spells.get(SpellId.iceBolt).stats.manaCost;
    final rangedWeaponId = world.equippedRangedWeapon.weaponId[rwi];
    final rangedWeaponDef = rangedWeapons.base.get(rangedWeaponId);
    final rangedAmmo =
        world.ammo.countForIndex(ami, rangedWeaponDef.ammoType);

    // ─── Compute affordability flags ───
    // These tell the UI whether action buttons should appear enabled.
    final canAffordJump = stamina >= resources.jumpStaminaCost;
    final canAffordDash = stamina >= resources.dashStaminaCost;
    final canAffordMelee = stamina >= abilities.base.meleeStaminaCost;
    final canAffordProjectile = mana >= projectileManaCost;
    final canAffordRangedWeapon =
        stamina >= rangedWeaponDef.staminaCost &&
        rangedAmmo >= rangedWeaponDef.ammoCost;

    // ─── Read cooldown timers ───
    final dashCooldownTicksLeft = world.movement.dashCooldownTicksLeft[mi];
    final meleeCooldownTicksLeft = world.cooldown.meleeCooldownTicksLeft[ci];
    final projectileCooldownTicksLeft =
        world.cooldown.castCooldownTicksLeft[ci];
    final rangedWeaponCooldownTicksLeft =
        world.cooldown.rangedWeaponCooldownTicksLeft[ci];
    final rangedWeaponCooldownTicksTotal =
        rangedWeapons.cooldownTicks(rangedWeaponId);

    // ─── Read player transform ───
    final ti = world.transform.indexOf(player);
    final playerPosX = world.transform.posX[ti];
    final playerPosY = world.transform.posY[ti];
    final playerVelX = world.transform.velX[ti];
    final playerVelY = world.transform.velY[ti];
    final playerFacing = world.movement.facing[mi];
    final playerHp = world.health.hp[hi];
    final actionAnimIndex = world.actionAnim.tryIndexOf(player);
    final lastMeleeTick = actionAnimIndex == null
        ? -1
        : world.actionAnim.lastMeleeTick[actionAnimIndex];
    final lastCastTick = actionAnimIndex == null
        ? -1
        : world.actionAnim.lastCastTick[actionAnimIndex];

    final lastDamageTick = world.lastDamage.has(player)
        ? world.lastDamage.tick[world.lastDamage.indexOf(player)]
        : -1;

    // ─── Determine player animation ───
    // Priority: death > hit > attack/cast > dash > airborne > moving > idle/spawn
    final AnimKey anim;
    final showHit =
        animTuning.hitAnimTicks > 0 &&
        lastDamageTick >= 0 &&
        (tick - lastDamageTick) < animTuning.hitAnimTicks;
    final showAttack =
        animTuning.attackAnimTicks > 0 &&
        lastMeleeTick >= 0 &&
        (tick - lastMeleeTick) < animTuning.attackAnimTicks;
    final showCast =
        animTuning.castAnimTicks > 0 &&
        lastCastTick >= 0 &&
        (tick - lastCastTick) < animTuning.castAnimTicks;

    if (playerHp <= 0) {
      anim = AnimKey.death;
    } else if (showHit) {
      anim = AnimKey.hit;
    } else if (showAttack) {
      anim = AnimKey.attack;
    } else if (showCast) {
      anim = AnimKey.cast;
    } else if (dashing) {
      anim = AnimKey.dash;
    } else if (!onGround) {
      anim = playerVelY < 0 ? AnimKey.jump : AnimKey.fall;
    } else if (playerVelX.abs() > tuning.minMoveSpeed) {
      anim = AnimKey.run;
    } else if (animTuning.spawnAnimTicks > 0 &&
        tick < animTuning.spawnAnimTicks) {
      anim = AnimKey.spawn;
    } else {
      anim = AnimKey.idle;
    }

    final int playerAnimFrame;
    switch (anim) {
      case AnimKey.attack:
        playerAnimFrame = lastMeleeTick >= 0 ? tick - lastMeleeTick : tick;
      case AnimKey.cast:
        playerAnimFrame = lastCastTick >= 0 ? tick - lastCastTick : tick;
      case AnimKey.hit:
        playerAnimFrame = lastDamageTick >= 0 ? tick - lastDamageTick : tick;
      case AnimKey.death:
        playerAnimFrame = lastDamageTick >= 0 ? tick - lastDamageTick : tick;
      case AnimKey.dash:
        playerAnimFrame = max(0, movement.dashDurationTicks - dashTicksLeft);
      default:
        playerAnimFrame = tick;
    }

    final playerPos = Vec2(playerPosX, playerPosY);
    final playerVel = Vec2(playerVelX, playerVelY);

    Vec2? playerSize;
    if (world.colliderAabb.has(player)) {
      final aabbi = world.colliderAabb.indexOf(player);
      playerSize = Vec2(
        world.colliderAabb.halfX[aabbi] * 2,
        world.colliderAabb.halfY[aabbi] * 2,
      );
    }

    // ─── Build entity list (player first) ───
    final entities = <EntityRenderSnapshot>[
      EntityRenderSnapshot(
        id: player,
        kind: EntityKind.player,
        pos: playerPos,
        vel: playerVel,
        size: playerSize,
        facing: playerFacing,
        anim: anim,
        grounded: onGround,
        animFrame: playerAnimFrame,
      ),
    ];

    // Append all other renderable entities.
    _addProjectiles(entities, tick: tick);
    _addHitboxes(entities, tick: tick);
    _addCollectibles(entities, tick: tick);
    _addRestorationItems(entities, tick: tick);
    _addEnemies(entities, tick: tick);

    // ─── Assemble final snapshot ───
    return GameStateSnapshot(
      tick: tick,
      seed: seed,
      levelId: levelId,
      themeId: themeId,
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
        canAffordRangedWeapon: canAffordRangedWeapon,
        dashCooldownTicksLeft: dashCooldownTicksLeft,
        dashCooldownTicksTotal: movement.dashCooldownTicks,
        meleeCooldownTicksLeft: meleeCooldownTicksLeft,
        meleeCooldownTicksTotal: abilities.meleeCooldownTicks,
        projectileCooldownTicksLeft: projectileCooldownTicksLeft,
        projectileCooldownTicksTotal: abilities.castCooldownTicks,
        rangedWeaponCooldownTicksLeft: rangedWeaponCooldownTicksLeft,
        rangedWeaponCooldownTicksTotal: rangedWeaponCooldownTicksTotal,
        rangedAmmo: rangedAmmo,
        collectibles: collectibles,
        collectibleScore: collectibleScore,
      ),
      entities: entities,
      staticSolids: staticSolids,
      groundGaps: groundGaps,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Private Entity Collectors
  // ───────────────────────────────────────────────────────────────────────────

  /// Appends projectile entity snapshots to [entities].
  ///
  /// Iterates the projectile component store and creates render snapshots
  /// with position, velocity, facing direction, and rotation angle.
  void _addProjectiles(List<EntityRenderSnapshot> entities, {required int tick}) {
    final projectileStore = world.projectile;
    for (var pi = 0; pi < projectileStore.denseEntities.length; pi += 1) {
      final e = projectileStore.denseEntities[pi];
      if (!world.transform.has(e)) continue;
      final ti = world.transform.indexOf(e);

      // Look up projectile definition for collider size.
      final projectileId = projectileStore.projectileId[pi];
      final proj = projectiles.base.get(projectileId);
      final colliderSize = Vec2(proj.colliderSizeX, proj.colliderSizeY);

      // Compute facing and rotation from direction vector.
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
          animFrame: tick,
        ),
      );
    }
  }

  /// Appends active hitbox (melee attack) snapshots to [entities].
  ///
  /// Hitboxes are short-lived trigger volumes spawned by melee attacks.
  /// They render as debug overlays or attack effects.
  void _addHitboxes(List<EntityRenderSnapshot> entities, {required int tick}) {
    final hitboxes = world.hitbox;
    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final e = hitboxes.denseEntities[hi];
      if (!world.transform.has(e)) continue;
      final ti = world.transform.indexOf(e);

      // Hitbox size is stored as half-extents; double for full size.
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
          animFrame: tick,
        ),
      );
    }
  }

  /// Appends collectible (score pickup) snapshots to [entities].
  ///
  /// Collectibles are small pickups that grant score when collected.
  void _addCollectibles(List<EntityRenderSnapshot> entities, {required int tick}) {
    final collectiblesStore = world.collectible;
    for (var ci = 0; ci < collectiblesStore.denseEntities.length; ci += 1) {
      final e = collectiblesStore.denseEntities[ci];
      if (!world.transform.has(e)) continue;
      final ti = world.transform.indexOf(e);

      // Size comes from AABB collider if present.
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
          rotationRad: pi * 0.25, // 45° tilt for visual interest
          anim: AnimKey.idle,
          grounded: false,
          animFrame: tick,
        ),
      );
    }
  }

  /// Appends restoration item (health/mana/stamina orb) snapshots to [entities].
  ///
  /// Restoration items restore a specific resource when picked up.
  /// The [pickupVariant] field tells the renderer which sprite to use.
  void _addRestorationItems(List<EntityRenderSnapshot> entities, {required int tick}) {
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

      // Map restoration stat enum to pickup variant for rendering.
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
          animFrame: tick,
        ),
      );
    }
  }

  /// Appends enemy entity snapshots to [entities].
  ///
  /// Enemies have position, velocity, facing direction, and grounded state.
  /// The renderer uses this to select appropriate sprites and animations.
  void _addEnemies(List<EntityRenderSnapshot> entities, {required int tick}) {
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
          animFrame: tick,
        ),
      );
    }
  }
}
