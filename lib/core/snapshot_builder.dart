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
import 'ecs/stores/combat/equipped_loadout_store.dart';
import 'ecs/stores/restoration_item_store.dart';
import 'levels/level_id.dart';
import 'projectiles/projectile_catalog.dart';
import 'enemies/enemy_catalog.dart';
import 'snapshots/enums.dart';
import 'snapshots/entity_render_snapshot.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshots/player_hud_snapshot.dart';
import 'snapshots/static_ground_gap_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
import 'players/player_tuning.dart';
import 'util/vec2.dart';
import 'abilities/ability_catalog.dart';
import 'abilities/ability_def.dart';
import 'util/fixed_math.dart';
import 'util/tick_math.dart';

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
  /// - [tickHz]: Fixed tick rate for converting seconds to ticks.
  /// - [world]: The ECS world containing all entity component data.
  /// - [player]: Entity ID of the player (used to query player-specific stores).
  /// - [movement]: Derived movement tuning (dash cooldown ticks, etc.).
  /// - [abilities]: Derived ability tuning (melee/cast cooldown ticks).
  /// - [resources]: Resource costs (jump/dash stamina, etc.).
  /// - [projectiles]: Projectile catalog for collider sizes.
  /// - [enemyCatalog]: Enemy catalog for render metadata (hit windows, art facing).
  SnapshotBuilder({
    required this.tickHz,
    required this.world,
    required this.player,
    required this.movement,
    required this.abilities,
    required this.resources,
    required this.projectiles,
    required this.enemyCatalog,
  });

  /// Tick rate (ticks per second) for converting seconds to ticks.
  final int tickHz;

  /// The ECS world containing all game entity data.
  final EcsWorld world;

  /// Entity ID of the player character.
  final EntityId player;

  /// Derived movement tuning (pre-computed tick-based values).
  final MovementTuningDerived movement;

  /// Derived ability tuning (cooldown durations in ticks).
  final AbilityTuningDerived abilities;

  /// Resource tuning (stamina/mana costs for actions).
  final ResourceTuningDerived resources;

  /// Projectile catalog for collider dimensions.
  final ProjectileCatalogDerived projectiles;

  /// Enemy catalog for render metadata (art facing direction).
  final EnemyCatalog enemyCatalog;

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
    final mi = world.movement.indexOf(player);
    final onGround = world.collision.grounded[world.collision.indexOf(player)];
    final hi = world.health.indexOf(player);
    final mai = world.mana.indexOf(player);
    final si = world.stamina.indexOf(player);

    final li = world.equippedLoadout.indexOf(player);

    // ─── Read current resource values ───
    final stamina = world.stamina.stamina[si];
    final mana = world.mana.mana[mai];
    final loadout = world.equippedLoadout;
    final loadoutMask = loadout.mask[li];

    final projectileAbilityId = loadout.abilityProjectileId[li];
    final projectileAbility = AbilityCatalog.tryGet(projectileAbilityId);
    final projectileManaCost = projectileAbility?.manaCost ?? 0;
    final projectileStaminaCost = projectileAbility?.staminaCost ?? 0;
    final hasProjectileSlot = (loadoutMask & LoadoutSlotMask.projectile) != 0;

    final mobilityAbilityId = loadout.abilityMobilityId[li];
    final mobilityAbility = AbilityCatalog.tryGet(mobilityAbilityId);
    final dashStaminaCost =
        mobilityAbility?.staminaCost ?? resources.dashStaminaCost100;

    final jumpAbilityId = loadout.abilityJumpId[li];
    final jumpAbility = AbilityCatalog.tryGet(jumpAbilityId);
    final jumpStaminaCost =
        jumpAbility?.staminaCost ?? resources.jumpStaminaCost100;

    final meleeAbilityId = loadout.abilityPrimaryId[li];
    final meleeAbility = AbilityCatalog.tryGet(meleeAbilityId);
    final meleeStaminaCost =
        meleeAbility?.staminaCost ??
        toFixed100(abilities.base.meleeStaminaCost);

    final meleeInputMode = _inputModeFor(meleeAbility);
    final projectileInputMode = _inputModeFor(projectileAbility);

    // ─── Compute affordability flags ───
    // These tell the UI whether action buttons should appear enabled.
    final canAffordJump = stamina >= jumpStaminaCost;
    final canAffordDash = stamina >= dashStaminaCost;
    final canAffordMelee = stamina >= meleeStaminaCost;
    final canAffordProjectile =
        hasProjectileSlot &&
        stamina >= projectileStaminaCost &&
        mana >= projectileManaCost;

    // ─── Read cooldown timers ───
    final dashCooldownTicksLeft = world.cooldown.getTicksLeft(
      player,
      CooldownGroup.mobility,
    );
    final dashCooldownTicksTotal = mobilityAbility == null
        ? movement.dashCooldownTicks
        : _scaleAbilityTicks(mobilityAbility.cooldownTicks);
    final meleeCooldownTicksLeft = world.cooldown.getTicksLeft(
      player,
      CooldownGroup.primary,
    );
    final projectileCooldownTicksLeft = world.cooldown.getTicksLeft(
      player,
      CooldownGroup.projectile,
    );
    final projectileCooldownTicksTotal = projectileAbility == null
        ? abilities.castCooldownTicks
        : _scaleAbilityTicks(projectileAbility.cooldownTicks);
    final meleeCooldownTicksTotal = meleeAbility == null
        ? abilities.meleeCooldownTicks
        : _scaleAbilityTicks(meleeAbility.cooldownTicks);

    // ─── Read player transform ───
    final ti = world.transform.indexOf(player);
    final playerPosX = world.transform.posX[ti];
    final playerPosY = world.transform.posY[ti];
    final playerVelX = world.transform.velX[ti];
    final playerVelY = world.transform.velY[ti];
    final playerFacing = world.movement.facing[mi];
    final animState = world.animState;
    final AnimKey anim;
    final int playerAnimFrame;
    if (animState.has(player)) {
      final ai = animState.indexOf(player);
      anim = animState.anim[ai];
      playerAnimFrame = animState.animFrame[ai];
    } else {
      anim = AnimKey.idle;
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
        hp: fromFixed100(world.health.hp[hi]),
        hpMax: fromFixed100(world.health.hpMax[hi]),
        mana: fromFixed100(mana),
        manaMax: fromFixed100(world.mana.manaMax[mai]),
        stamina: fromFixed100(stamina),
        staminaMax: fromFixed100(world.stamina.staminaMax[si]),
        canAffordJump: canAffordJump,
        canAffordDash: canAffordDash,
        canAffordMelee: canAffordMelee,
        canAffordProjectile: canAffordProjectile,
        dashCooldownTicksLeft: dashCooldownTicksLeft,
        dashCooldownTicksTotal: dashCooldownTicksTotal,
        meleeCooldownTicksLeft: meleeCooldownTicksLeft,
        meleeCooldownTicksTotal: meleeCooldownTicksTotal,
        projectileCooldownTicksLeft: projectileCooldownTicksLeft,
        projectileCooldownTicksTotal: projectileCooldownTicksTotal,
        meleeInputMode: meleeInputMode,
        projectileInputMode: projectileInputMode,
        collectibles: collectibles,
        collectibleScore: collectibleScore,
      ),
      entities: entities,
      staticSolids: staticSolids,
      groundGaps: groundGaps,
    );
  }

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (tickHz == _abilityTickHz) return ticks;
    final seconds = ticks / _abilityTickHz;
    return ticksFromSecondsCeil(seconds, tickHz);
  }

  AbilityInputMode _inputModeFor(AbilityDef? ability) {
    final targeting = ability?.targetingModel;
    if (targeting == null) return AbilityInputMode.holdAimRelease;
    return targeting == TargetingModel.none
        ? AbilityInputMode.tap
        : AbilityInputMode.holdAimRelease;
  }

  static const int _abilityTickHz = 60;

  // ───────────────────────────────────────────────────────────────────────────
  // Private Entity Collectors
  // ───────────────────────────────────────────────────────────────────────────

  /// Appends projectile entity snapshots to [entities].
  ///
  /// Iterates the projectile component store and creates render snapshots
  /// with position, velocity, facing direction, and rotation angle.
  void _addProjectiles(
    List<EntityRenderSnapshot> entities, {
    required int tick,
  }) {
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

  /// Appends active hitbox (melee strike) snapshots to [entities].
  ///
  /// Hitboxes are short-lived trigger volumes spawned by melee strikes.
  /// They render as debug overlays or strike effects.
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
  void _addCollectibles(
    List<EntityRenderSnapshot> entities, {
    required int tick,
  }) {
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
  void _addRestorationItems(
    List<EntityRenderSnapshot> entities, {
    required int tick,
  }) {
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
  /// Animation is read from [AnimStateStore], pre-computed by [AnimSystem].
  void _addEnemies(List<EntityRenderSnapshot> entities, {required int tick}) {
    final enemies = world.enemy;
    final animStore = world.animState;

    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      if (!world.transform.has(e)) continue;
      final ti = world.transform.indexOf(e);
      final enemyId = enemies.enemyId[ei];
      final enemyArchetype = enemyCatalog.get(enemyId);

      Vec2? size;
      if (world.colliderAabb.has(e)) {
        final aabbi = world.colliderAabb.indexOf(e);
        size = Vec2(
          world.colliderAabb.halfX[aabbi] * 2,
          world.colliderAabb.halfY[aabbi] * 2,
        );
      }

      final grounded = world.collision.has(e)
          ? world.collision.grounded[world.collision.indexOf(e)]
          : false;

      // Read pre-computed animation from AnimStateStore.
      final AnimKey anim;
      final int animFrame;
      if (animStore.has(e)) {
        final ai = animStore.indexOf(e);
        anim = animStore.anim[ai];
        animFrame = animStore.animFrame[ai];
      } else {
        // Fallback if no anim component (shouldn't happen).
        anim = AnimKey.idle;
        animFrame = tick;
      }

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.enemy,
          pos: Vec2(world.transform.posX[ti], world.transform.posY[ti]),
          vel: Vec2(world.transform.velX[ti], world.transform.velY[ti]),
          size: size,
          enemyId: enemyId,
          facing: enemies.facing[ei],
          artFacingDir: enemyArchetype.artFacingDir,
          anim: anim,
          grounded: grounded,
          animFrame: animFrame,
        ),
      );
    }
  }
}
