/// Authoritative, deterministic simulation layer (pure Dart).
///
/// This is the heart of the game—a pure Dart simulation that processes
/// tick-stamped commands, advances physics and AI, and produces immutable
/// snapshots for the renderer/UI. By keeping this layer Flutter/Flame-free,
/// we gain:
/// - **Testability**: Unit tests can run headless at any tick rate.
/// - **Determinism**: Same seed + commands = identical simulation.
/// - **Portability**: Core logic could run on a server for validation.
///
/// ## Architecture Overview
///
/// ```
/// Commands (from input layer)
///         ↓
///    GameCore.applyCommands()
///         ↓
///    GameCore.stepOneTick()
///         ↓
///    [Track streaming → Physics → AI → Combat → Cleanup]
///         ↓
///    GameStateSnapshot (to render layer)
/// ```
///
/// ## Module Dependencies
///
/// [GameCore] orchestrates three extracted modules:
/// - [TrackManager]: Procedural chunk generation, geometry lifecycle.
/// - [SpawnService]: Deterministic entity spawning (enemies, items).
/// - [SnapshotBuilder]: ECS → render snapshot conversion.
///
/// ## ECS System Execution Order
///
/// Systems run in a carefully ordered pipeline each tick:
/// 1. **Track streaming**: Spawn/cull chunks based on camera.
/// 2. **Cooldowns & invulnerability**: Decrement timers.
/// 3. **Enemy AI steering**: Path planning and movement intent.
/// 4. **Player input**: Resolve ability intents (including mobility).
/// 5. **Player movement**: Apply input to velocity.
/// 6. **Mobility execution**: Apply dash/roll state.
/// 7. **Gravity**: Apply gravity to non-kinematic bodies.
/// 8. **Collision**: Resolve static world collisions.
/// 9. **Pickups**: Collect items overlapping player.
/// 10. **Broadphase rebuild**: Update spatial grid for hit detection.
/// 11. **Projectile movement**: Advance existing projectiles.
/// 12. **Strike intents**: Enemies and player queue strikes.
/// 13. **Strike execution**: Spawn hitboxes/projectiles/self abilities.
/// 14. **Hitbox positioning**: Follow owner entities.
/// 15. **Hit resolution**: Detect overlaps, queue damage.
/// 16. **Status ticking**: Apply DoT ticks and queue damage.
/// 17. **Damage middleware**: Apply combat rule edits/cancellations.
/// 18. **Damage application**: Apply queued damage, set invulnerability.
/// 19. **Status application**: Apply on-hit status profiles.
/// 20. **Death handling**: Despawn dead entities, record kills.
/// 21. **Resource regen**: Regenerate mana/stamina.
/// 22. **Lifetime cleanup**: Remove expired entities.
///
/// ## Determinism Contract
///
/// Given identical inputs:
/// - Same [seed] parameter
/// - Same sequence of [Command]s with same tick stamps
/// - Same [tickHz]
///
/// The simulation will produce identical results across runs and platforms.
/// This is achieved by:
/// - Using [DeterministicRng] instead of `dart:math Random`
/// - Fixed-point-style tick math (no frame-rate-dependent dt accumulation)
/// - Deterministic iteration order (entity IDs, not hash-based)
library;

import 'dart:math';

import 'camera/autoscroll_camera.dart';
import 'abilities/ability_catalog.dart';
import 'abilities/ability_def.dart';
import 'combat/middleware/parry_middleware.dart';
import 'collision/static_world_geometry_index.dart';
import 'commands/command.dart';
import 'contracts/render_contract.dart';
import 'ecs/entity_factory.dart';
import 'ecs/entity_id.dart';
import 'ecs/spatial/broadphase_grid.dart';
import 'ecs/spatial/grid_index_2d.dart';
import 'ecs/stores/restoration_item_store.dart';
import 'ecs/systems/collectible_system.dart';
import 'ecs/systems/collision_system.dart';
import 'ecs/systems/cooldown_system.dart';
import 'ecs/systems/damage_middleware_system.dart';
import 'ecs/systems/damage_system.dart';
import 'ecs/systems/active_ability_phase_system.dart';
import 'ecs/systems/death_despawn_system.dart';
import 'ecs/systems/enemy_cast_system.dart';
import 'ecs/systems/enemy_death_state_system.dart';
import 'ecs/systems/enemy_engagement_system.dart';
import 'ecs/systems/flying_enemy_locomotion_system.dart';
import 'ecs/systems/ground_enemy_locomotion_system.dart';
import 'ecs/systems/enemy_navigation_system.dart';
import 'ecs/systems/gravity_system.dart';
import 'ecs/systems/health_despawn_system.dart';
import 'ecs/systems/hitbox_damage_system.dart';
import 'ecs/systems/hitbox_follow_owner_system.dart';
import 'ecs/systems/invulnerability_system.dart';
import 'ecs/systems/lifetime_system.dart';
import 'ecs/systems/melee_strike_system.dart';
import 'ecs/systems/ability_activation_system.dart';
import 'ecs/systems/mobility_system.dart';
import 'ecs/systems/player_movement_system.dart';
import 'ecs/systems/projectile_hit_system.dart';
import 'ecs/systems/projectile_system.dart';
import 'ecs/systems/projectile_world_collision_system.dart';
import 'ecs/systems/projectile_launch_system.dart';
import 'ecs/systems/resource_regen_system.dart';
import 'ecs/systems/restoration_item_system.dart';
import 'ecs/systems/self_ability_system.dart';
import 'ecs/systems/status_system.dart';
import 'ecs/systems/control_lock_system.dart';
import 'ecs/systems/anim/anim_system.dart';
import 'ecs/systems/enemy_cull_system.dart';
import 'ecs/systems/enemy_melee_system.dart';
import 'ecs/world.dart';
import 'enemies/enemy_catalog.dart';
import 'enemies/enemy_id.dart';
import 'events/game_event.dart';
import 'levels/level_definition.dart';
import 'levels/level_id.dart';
import 'levels/level_registry.dart';
import 'navigation/surface_graph_builder.dart';
import 'navigation/surface_navigator.dart';
import 'navigation/surface_pathfinder.dart';
import 'navigation/utils/jump_template.dart';
import 'navigation/utils/trajectory_predictor.dart';
import 'players/player_catalog.dart';
import 'players/player_character_definition.dart';
import 'players/player_character_registry.dart';
import 'projectiles/projectile_catalog.dart';
import 'snapshots/enums.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshot_builder.dart';
import 'spawn_service.dart';
import 'projectiles/projectile_item_catalog.dart';
import 'projectiles/projectile_item_id.dart';
import 'track_manager.dart';
import 'weapons/weapon_catalog.dart';
import 'ecs/stores/combat/equipped_loadout_store.dart';
import 'tuning/camera_tuning.dart';
import 'tuning/collectible_tuning.dart';
import 'tuning/core_tuning.dart';
import 'tuning/flying_enemy_tuning.dart';
import 'tuning/ground_enemy_tuning.dart';
import 'tuning/navigation_tuning.dart';
import 'tuning/physics_tuning.dart';
import 'players/player_tuning.dart';
import 'tuning/restoration_item_tuning.dart';
import 'tuning/score_tuning.dart';
import 'tuning/spatial_grid_tuning.dart';
import 'tuning/track_tuning.dart';
import 'util/tick_math.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GameCore - Main simulation coordinator
// ─────────────────────────────────────────────────────────────────────────────

/// Deterministic game simulation core.
///
/// This class is the central coordinator for the game simulation. It:
/// - Owns the [EcsWorld] and all ECS systems.
/// - Processes player [Command]s each tick.
/// - Steps physics, AI, and combat systems in order.
/// - Produces [GameStateSnapshot]s for the render layer.
/// - Emits [GameEvent]s for UI feedback (run ended, etc.).
///
/// ## Usage
///
/// ```dart
/// final core = GameCore(seed: 42);
/// core.applyCommands([JumpPressedCommand()]);
/// core.stepOneTick();
/// final snapshot = core.buildSnapshot();
/// final events = core.drainEvents();
/// ```
///
/// ## Custom Configuration
///
/// Use [CoreTuning] to customize world/level parameters:
/// ```dart
/// final core = GameCore(
///   seed: 123,
///   tuning: CoreTuning(track: TrackTuning(enabled: false)),
/// );
/// ```
///
/// Use [PlayerCharacterDefinition] to select player-specific tuning + collider:
/// ```dart
/// final core = GameCore(
///   seed: 123,
///   playerCharacter: PlayerCharacterRegistry.eloise,
/// );
/// ```
///
/// Use [LevelDefinition] to select a level configuration:
/// ```dart
/// final core = GameCore(
///   seed: 123,
///   levelDefinition: LevelRegistry.byId(LevelId.defaultLevel),
/// );
/// ```
class GameCore {
  static LevelDefinition _resolveLevelDefinition({
    required CoreTuning tuning,
    required StaticWorldGeometry staticWorldGeometry,
    LevelDefinition? levelDefinition,
  }) {
    if (levelDefinition != null) return levelDefinition;
    final base = LevelRegistry.defaultLevel;
    return LevelDefinition(
      id: base.id,
      patternPool: base.patternPool,
      earlyPatternChunks: base.earlyPatternChunks,
      noEnemyChunks: base.noEnemyChunks,
      themeId: base.themeId,
      tuning: tuning,
      staticWorldGeometry: staticWorldGeometry,
    );
  }

  /// Creates a new game simulation with the given configuration.
  ///
  /// Parameters:
  /// - [seed]: Master RNG seed for deterministic generation.
  /// - [tickHz]: Fixed tick rate (default 60). Higher = smoother but more CPU.
  /// - [tuning]: Aggregate tuning configuration (see [CoreTuning]).
  /// - Catalogs: Entity archetype definitions (spells, enemies, etc.).
  /// - [staticWorldGeometry]: Base level geometry (ground, initial platforms).
  /// - [levelDefinition]: Optional level config. When provided, its tuning,
  ///   static geometry, and pattern pools are used (and [tuning] /
  ///   [staticWorldGeometry] are ignored).
  GameCore({
    required int seed,
    int tickHz = defaultTickHz,
    CoreTuning tuning = const CoreTuning(),
    PlayerCharacterDefinition playerCharacter =
        PlayerCharacterRegistry.defaultCharacter,
    ProjectileItemCatalog projectileItemCatalog = const ProjectileItemCatalog(),
    ProjectileCatalog projectileCatalog = const ProjectileCatalog(),
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
    WeaponCatalog weaponCatalog = const WeaponCatalog(),
    StaticWorldGeometry staticWorldGeometry = const StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: groundTopY * 1.0),
    ),
    LevelDefinition? levelDefinition,
  }) : this._fromLevel(
         seed: seed,
         tickHz: tickHz,
         levelDefinition: _resolveLevelDefinition(
           levelDefinition: levelDefinition,
           tuning: tuning,
           staticWorldGeometry: staticWorldGeometry,
         ),
         projectileItemCatalog: projectileItemCatalog,
         projectileCatalog: projectileCatalog,
         enemyCatalog: enemyCatalog,
         playerCharacter: playerCharacter,
         weaponCatalog: weaponCatalog,
       );

  GameCore._fromLevel({
    required this.seed,
    required this.tickHz,
    required LevelDefinition levelDefinition,
    required ProjectileItemCatalog projectileItemCatalog,
    required ProjectileCatalog projectileCatalog,
    required EnemyCatalog enemyCatalog,
    required PlayerCharacterDefinition playerCharacter,
    required WeaponCatalog weaponCatalog,
  }) : _levelDefinition = levelDefinition,
       _movement = MovementTuningDerived.from(
         playerCharacter.tuning.movement,
         tickHz: tickHz,
       ),
       _physicsTuning = levelDefinition.tuning.physics,
       _resourceTuning = ResourceTuningDerived.from(
         playerCharacter.tuning.resource,
       ),
       _abilities = AbilityTuningDerived.from(
         playerCharacter.tuning.ability,
         tickHz: tickHz,
       ),
       _animTuning = AnimTuningDerived.from(
         playerCharacter.tuning.anim,
         tickHz: tickHz,
       ),
       _combat = CombatTuningDerived.from(
         playerCharacter.tuning.combat,
         tickHz: tickHz,
       ),
       _unocoDemonTuning = UnocoDemonTuningDerived.from(
         levelDefinition.tuning.unocoDemon,
         tickHz: tickHz,
       ),
       _groundEnemyTuning = GroundEnemyTuningDerived.from(
         levelDefinition.tuning.groundEnemy,
         tickHz: tickHz,
       ),
       _navigationTuning = levelDefinition.tuning.navigation,
       _spatialGridTuning = levelDefinition.tuning.spatialGrid,
       _projectileItems = projectileItemCatalog,
       _projectiles = ProjectileCatalogDerived.from(
         projectileCatalog,
         tickHz: tickHz,
       ),
       _enemyCatalog = enemyCatalog,
       _playerCharacter = playerCharacter,
       _weapons = weaponCatalog,
       _scoreTuning = levelDefinition.tuning.score,
       _trackTuning = levelDefinition.tuning.track,
       _collectibleTuning = levelDefinition.tuning.collectible,
       _restorationItemTuning = levelDefinition.tuning.restorationItem {
    _initializeWorld(levelDefinition);
  }

  /// Common initialization shared by all constructors.
  void _initializeWorld(LevelDefinition levelDefinition) {
    final staticWorldGeometry = levelDefinition.staticWorldGeometry;
    final cameraTuning = levelDefinition.tuning.camera;
    // ─── Initialize ECS world and entity factory ───
    _world = EcsWorld(seed: seed);
    _entityFactory = EntityFactory(_world);

    // ─── Initialize all ECS systems ───
    _initializeSystems();

    // ─── Initialize autoscrolling camera ───
    _cameraTuning = CameraTuningDerived.from(cameraTuning, movement: _movement);
    _camera = AutoscrollCamera(
      viewWidth: virtualWidth.toDouble(),
      tuning: _cameraTuning,
      initial: CameraState(
        centerX: virtualWidth * 0.5,
        targetX: virtualWidth * 0.5,
        speedX: 0.0,
      ),
    );

    // ─── Initialize spawn service (needs ECS + catalogs) ───
    _spawnService = SpawnService(
      world: _world,
      entityFactory: _entityFactory,
      enemyCatalog: _enemyCatalog,
      unocoDemonTuning: _unocoDemonTuning,
      movement: _movement,
      collectibleTuning: _collectibleTuning,
      restorationItemTuning: _restorationItemTuning,
      trackTuning: _trackTuning,
      seed: seed,
    );

    // ─── Spawn player entity (must happen before TrackManager) ───
    final effectiveGroundTopY =
        staticWorldGeometry.groundPlane?.topY ?? groundTopY.toDouble();
    _spawnPlayer(effectiveGroundTopY);

    // ─── Initialize track manager (needs player for callbacks) ───
    _trackManager = TrackManager(
      seed: seed,
      trackTuning: _trackTuning,
      collectibleTuning: _collectibleTuning,
      restorationItemTuning: _restorationItemTuning,
      baseGeometry: staticWorldGeometry,
      surfaceGraphBuilder: _surfaceGraphBuilder,
      jumpTemplate: _groundEnemyJumpTemplate,
      enemyNavigationSystem: _enemyNavigationSystem,
      groundEnemyLocomotionSystem: _groundEnemyLocomotionSystem,
      spawnService: _spawnService,
      groundTopY: effectiveGroundTopY,
      patternPool: levelDefinition.patternPool,
      earlyPatternChunks: levelDefinition.earlyPatternChunks,
      noEnemyChunks: levelDefinition.noEnemyChunks,
    );

    // ─── Initialize snapshot builder (needs player entity ID) ───
    _snapshotBuilder = SnapshotBuilder(
      tickHz: tickHz,
      world: _world,
      player: _player,
      movement: _movement,
      abilities: _abilities,
      resources: _resourceTuning,
      projectiles: _projectiles,
      enemyCatalog: _enemyCatalog,
    );
  }

  /// Initializes all ECS systems.
  ///
  /// Systems are stateless processors that operate on component stores.
  /// They're created once at construction and reused every tick.
  void _initializeSystems() {
    // Core movement and physics.
    _movementSystem = PlayerMovementSystem();
    _mobilitySystem = MobilitySystem();
    _collisionSystem = CollisionSystem();
    _cooldownSystem = CooldownSystem();
    _gravitySystem = GravitySystem();

    // Projectile lifecycle.
    _projectileSystem = ProjectileSystem();
    _projectileHitSystem = ProjectileHitSystem();
    _projectileWorldCollisionSystem = ProjectileWorldCollisionSystem();

    // Spatial partitioning for hit detection.
    _broadphaseGrid = BroadphaseGrid(
      index: GridIndex2D(cellSize: _spatialGridTuning.broadphaseCellSize),
    );

    // Hitbox management.
    _hitboxFollowOwnerSystem = HitboxFollowOwnerSystem();
    _lifetimeSystem = LifetimeSystem();

    // Damage pipeline.
    _invulnerabilitySystem = InvulnerabilitySystem();
    _damageMiddlewareSystem = DamageMiddlewareSystem(
      middlewares: [
        ParryMiddleware(
          abilityIds: const <AbilityKey>{
            'eloise.sword_parry',
            'eloise.shield_block',
          },
        ),
      ],
    );
    _damageSystem = DamageSystem(
      invulnerabilityTicksOnHit: _combat.invulnerabilityTicks,
      rngSeed: seed,
    );
    _statusSystem = StatusSystem(tickHz: tickHz);
    _controlLockSystem = ControlLockSystem();
    _activeAbilityPhaseSystem = ActiveAbilityPhaseSystem();
    _healthDespawnSystem = HealthDespawnSystem();
    _enemyDeathStateSystem = EnemyDeathStateSystem(
      tickHz: tickHz,
      enemyCatalog: _enemyCatalog,
    );
    _deathDespawnSystem = DeathDespawnSystem();
    _enemyCullSystem = EnemyCullSystem();
    _animSystem = AnimSystem(
      tickHz: tickHz,
      enemyCatalog: _enemyCatalog,
      playerMovement: _movement,
      playerAnimTuning: _animTuning,
    );

    // Player combat (input → intents).
    _abilityActivationSystem = AbilityActivationSystem(
      tickHz: tickHz,
      inputBufferTicks: _abilities.inputBufferTicks,
      abilities: const AbilityCatalog(),
      weapons: _weapons,
      projectileItems: _projectileItems,
    );
    _hitboxDamageSystem = HitboxDamageSystem();

    // Pickup systems.
    _collectibleSystem = CollectibleSystem();
    _restorationItemSystem = RestorationItemSystem();
    _resourceRegenSystem = ResourceRegenSystem(tickHz: tickHz);

    // Projectile execution.
    _projectileLaunchSystem = ProjectileLaunchSystem(projectiles: _projectiles);
    _selfAbilitySystem = SelfAbilitySystem();
    _meleeStrikeSystem = MeleeStrikeSystem();

    // Navigation infrastructure.
    _surfaceGraphBuilder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: _spatialGridTuning.broadphaseCellSize),
      takeoffSampleMaxStep: _navigationTuning.takeoffSampleMaxStep,
    );
    _groundEnemyJumpTemplate = JumpReachabilityTemplate.build(
      JumpProfile(
        jumpSpeed: _groundEnemyTuning.locomotion.jumpSpeed,
        gravityY: _physicsTuning.gravityY,
        maxAirTicks: _groundEnemyMaxAirTicks(),
        airSpeedX: _groundEnemyTuning.locomotion.speedX,
        dtSeconds: _movement.dtSeconds,
        agentHalfWidth: _enemyCatalog.get(EnemyId.grojib).collider.halfX,
      ),
    );
    _surfacePathfinder = SurfacePathfinder(
      maxExpandedNodes: _navigationTuning.maxExpandedNodes,
      runSpeedX: _groundEnemyTuning.locomotion.speedX,
      edgePenaltySeconds: _navigationTuning.edgePenaltySeconds,
    );
    _surfaceNavigator = SurfaceNavigator(
      pathfinder: _surfacePathfinder,
      repathCooldownTicks: _navigationTuning.repathCooldownTicks,
      surfaceEps: _navigationTuning.surfaceEps,
      takeoffEps: max(
        _navigationTuning.takeoffEpsMin,
        _groundEnemyTuning.locomotion.stopDistanceX,
      ),
    );

    _enemyNavigationSystem = EnemyNavigationSystem(
      surfaceNavigator: _surfaceNavigator,
      trajectoryPredictor: TrajectoryPredictor(
        gravityY: _physicsTuning.gravityY,
        dtSeconds: _movement.dtSeconds,
        maxTicks: 120,
      ),
      chaseTargetDelayTicks:
          _groundEnemyTuning.navigation.chaseTargetDelayTicks,
    );
    _enemyEngagementSystem = EnemyEngagementSystem(
      groundEnemyTuning: _groundEnemyTuning,
    );
    _groundEnemyLocomotionSystem = GroundEnemyLocomotionSystem(
      groundEnemyTuning: _groundEnemyTuning,
    );
    _flyingEnemyLocomotionSystem = FlyingEnemyLocomotionSystem(
      unocoDemonTuning: _unocoDemonTuning,
    );
    _enemyCastSystem = EnemyCastSystem(
      unocoDemonTuning: _unocoDemonTuning,
      enemyCatalog: _enemyCatalog,
      projectileItems: _projectileItems,
      projectiles: _projectiles,
    );
    _enemyMeleeSystem = EnemyMeleeSystem(groundEnemyTuning: _groundEnemyTuning);
  }

  /// Spawns the player entity at the start of a run.
  ///
  /// The player is positioned at [TrackTuning.playerStartX], standing on the
  /// ground. This must be called before [TrackManager] is created because
  /// track manager callbacks reference the player entity.
  void _spawnPlayer(double groundTopY) {
    final spawnX = _trackTuning.playerStartX;
    final playerArchetype = PlayerCatalogDerived.from(
      _playerCharacter.catalog,
      movement: _movement,
      resources: _resourceTuning,
    ).archetype;
    final playerCollider = playerArchetype.collider;

    // Position so collider bottom touches ground.
    final spawnY = groundTopY - (playerCollider.offsetY + playerCollider.halfY);
    _player = _entityFactory.createPlayer(
      posX: spawnX,
      posY: spawnY,
      velX: 0.0,
      velY: 0.0,
      facing: playerArchetype.facing,
      grounded: true,
      body: playerArchetype.body,
      collider: playerCollider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
      tags: playerArchetype.tags,
      resistance: playerArchetype.resistance,
      statusImmunity: playerArchetype.statusImmunity,
      equippedLoadout: EquippedLoadoutDef(
        mask: playerArchetype.loadoutSlotMask,
        mainWeaponId: playerArchetype.weaponId,
        offhandWeaponId: playerArchetype.offhandWeaponId,
        projectileItemId: playerArchetype.projectileItemId,
        abilityProjectileId: _abilityIdForProjectileItem(
          playerArchetype.projectileItemId,
        ),
      ),
    );
  }

  AbilityKey _abilityIdForProjectileItem(ProjectileItemId id) {
    switch (id) {
      case ProjectileItemId.iceBolt:
        return 'eloise.ice_bolt';
      case ProjectileItemId.fireBolt:
        return 'eloise.fire_bolt';
      case ProjectileItemId.thunderBolt:
        return 'eloise.thunder_bolt';
      case ProjectileItemId.throwingKnife:
        return 'eloise.throwing_knife';
      case ProjectileItemId.throwingAxe:
        return 'eloise.throwing_knife';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fields
  // ─────────────────────────────────────────────────────────────────────────

  /// Master RNG seed for deterministic generation.
  ///
  /// The same seed produces identical track layouts, enemy spawns, and

  /// item placements across runs.
  final int seed;

  /// Fixed simulation tick frequency (ticks per second).
  ///
  /// Higher values = smoother physics but more CPU. Default is 60.
  final int tickHz;

  /// Core level configuration for this run.
  final LevelDefinition _levelDefinition;

  // ─── Derived Tunings ───
  // These are pre-computed from base tunings using tickHz.

  final MovementTuningDerived _movement;
  final PhysicsTuning _physicsTuning;
  final ResourceTuningDerived _resourceTuning;
  final AbilityTuningDerived _abilities;
  final AnimTuningDerived _animTuning;
  final CombatTuningDerived _combat;
  final UnocoDemonTuningDerived _unocoDemonTuning;
  final GroundEnemyTuningDerived _groundEnemyTuning;
  final NavigationTuning _navigationTuning;
  final SpatialGridTuning _spatialGridTuning;
  late final CameraTuningDerived _cameraTuning;
  final ScoreTuning _scoreTuning;
  final TrackTuning _trackTuning;
  final CollectibleTuning _collectibleTuning;
  final RestorationItemTuning _restorationItemTuning;

  // ─── Catalogs ───
  // Archetype definitions for entities.

  final ProjectileItemCatalog _projectileItems;
  final ProjectileCatalogDerived _projectiles;
  final EnemyCatalog _enemyCatalog;
  final PlayerCharacterDefinition _playerCharacter;
  final WeaponCatalog _weapons;

  // ─── ECS Core ───

  /// The ECS world containing all component stores.
  late final EcsWorld _world;

  /// Factory for creating complex entities (player, enemies).
  late final EntityFactory _entityFactory;

  /// The player entity ID.
  late EntityId _player;

  // Pending game over delay for death animation.
  int _deathAnimTicksLeft = 0;
  RunEndReason? _pendingRunEndReason;
  DeathInfo? _pendingDeathInfo;

  // ─── ECS Systems ───
  // Stateless processors that operate on component stores.

  late final PlayerMovementSystem _movementSystem;
  late final MobilitySystem _mobilitySystem;
  late final CollisionSystem _collisionSystem;
  late final CooldownSystem _cooldownSystem;
  late final GravitySystem _gravitySystem;
  late final ProjectileSystem _projectileSystem;
  late final ProjectileHitSystem _projectileHitSystem;
  late final ProjectileWorldCollisionSystem _projectileWorldCollisionSystem;
  late final BroadphaseGrid _broadphaseGrid;
  late final HitboxFollowOwnerSystem _hitboxFollowOwnerSystem;
  late final CollectibleSystem _collectibleSystem;
  late final RestorationItemSystem _restorationItemSystem;
  late final LifetimeSystem _lifetimeSystem;
  late final InvulnerabilitySystem _invulnerabilitySystem;
  late final DamageMiddlewareSystem _damageMiddlewareSystem;
  late final DamageSystem _damageSystem;
  late final StatusSystem _statusSystem;
  late final ControlLockSystem _controlLockSystem;
  late final ActiveAbilityPhaseSystem _activeAbilityPhaseSystem;
  late final HealthDespawnSystem _healthDespawnSystem;
  late final EnemyDeathStateSystem _enemyDeathStateSystem;
  late final DeathDespawnSystem _deathDespawnSystem;
  late EnemyNavigationSystem _enemyNavigationSystem;
  late EnemyEngagementSystem _enemyEngagementSystem;
  late GroundEnemyLocomotionSystem _groundEnemyLocomotionSystem;
  late FlyingEnemyLocomotionSystem _flyingEnemyLocomotionSystem;
  late EnemyCastSystem _enemyCastSystem;
  late EnemyMeleeSystem _enemyMeleeSystem;
  late final SurfaceGraphBuilder _surfaceGraphBuilder;
  late final JumpReachabilityTemplate _groundEnemyJumpTemplate;
  late final SurfacePathfinder _surfacePathfinder;
  late final SurfaceNavigator _surfaceNavigator;
  late final AbilityActivationSystem _abilityActivationSystem;
  late final SelfAbilitySystem _selfAbilitySystem;
  late final MeleeStrikeSystem _meleeStrikeSystem;
  late final ProjectileLaunchSystem _projectileLaunchSystem;
  late final HitboxDamageSystem _hitboxDamageSystem;
  late final ResourceRegenSystem _resourceRegenSystem;
  late final AnimSystem _animSystem;
  late final EnemyCullSystem _enemyCullSystem;

  // ─── Modular Services ───
  // Extracted modules for specific responsibilities.

  /// Entity spawning with deterministic placement.
  late final SpawnService _spawnService;

  /// Track streaming, geometry lifecycle, navigation updates.
  late final TrackManager _trackManager;

  /// ECS → render snapshot conversion.
  late SnapshotBuilder _snapshotBuilder;

  // ─── Camera ───

  /// Autoscrolling camera that follows and pushes the player.
  late final AutoscrollCamera _camera;

  // ─── Event Queue ───

  /// Pending events to be consumed by UI (drained each frame).
  final List<GameEvent> _events = <GameEvent>[];

  // ─── Scratch/Tracking State ───

  /// Scratch list for killed enemies (reused to avoid allocation).
  final List<EnemyId> _killedEnemiesScratch = <EnemyId>[];

  /// Kill counts per enemy type (indexed by [EnemyId.index]).
  final List<int> _enemyKillCounts = List<int>.filled(EnemyId.values.length, 0);

  // ─── Simulation State ───

  /// Current simulation tick (increments each [stepOneTick]).
  int tick = 0;

  /// Whether simulation is paused (commands still apply, time doesn't advance).
  bool paused = false;

  /// Whether the run has ended (simulation is frozen permanently).
  bool gameOver = false;

  /// Total distance traveled (world units, not meters).
  double distance = 0;

  /// Number of collectibles picked up this run.
  int collectibles = 0;

  /// Total score from collectibles.
  int collectibleScore = 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Public Accessors
  // ─────────────────────────────────────────────────────────────────────────

  /// Level identifier for this run (stable across sessions).
  LevelId get levelId => _levelDefinition.id;

  /// Optional render theme identifier for this run.
  String? get themeId => _levelDefinition.themeId;

  /// Score tuning for UI display and leaderboard calculation.
  ScoreTuning get scoreTuning => _scoreTuning;

  /// Enemy catalog for render-side animation loading.
  EnemyCatalog get enemyCatalog => _enemyCatalog;

  /// Current static world geometry (base + streamed chunks).
  StaticWorldGeometry get staticWorldGeometry => _trackManager.staticGeometry;

  /// Player X position in world coordinates.
  double get playerPosX =>
      _world.transform.posX[_world.transform.indexOf(_player)];

  /// Player Y position in world coordinates.
  double get playerPosY =>
      _world.transform.posY[_world.transform.indexOf(_player)];

  /// Sets player position (for tests or teleportation).
  void setPlayerPosXY(double x, double y) =>
      _world.transform.setPosXY(_player, x, y);

  /// Player X velocity (positive = moving right).
  double get playerVelX =>
      _world.transform.velX[_world.transform.indexOf(_player)];

  /// Player Y velocity (positive = moving down).
  double get playerVelY =>
      _world.transform.velY[_world.transform.indexOf(_player)];

  /// Sets player velocity (for tests or knockback effects).
  void setPlayerVelXY(double x, double y) =>
      _world.transform.setVelXY(_player, x, y);

  /// Whether the player is currently on the ground.
  bool get playerGrounded =>
      _world.collision.grounded[_world.collision.indexOf(_player)];

  /// Player facing direction (left or right).
  Facing get playerFacing =>
      _world.movement.facing[_world.movement.indexOf(_player)];

  /// Sets player facing direction.
  set playerFacing(Facing value) {
    _world.movement.facing[_world.movement.indexOf(_player)] = value;
  }

  /// Remaining projectile cooldown ticks.
  /// Remaining projectile cooldown ticks.
  int get playerProjectileCooldownTicksLeft =>
      _world.cooldown.getTicksLeft(_player, CooldownGroup.projectile);

  /// Remaining melee strike cooldown ticks.
  int get playerMeleeCooldownTicksLeft =>
      _world.cooldown.getTicksLeft(_player, CooldownGroup.primary);

  // ─────────────────────────────────────────────────────────────────────────
  // Command Processing
  // ─────────────────────────────────────────────────────────────────────────

  /// Applies all commands scheduled for the current tick.
  ///
  /// Commands are the only way external code can influence the simulation.
  /// Each command type maps to a specific player input flag or value:
  ///
  /// - [MoveAxisCommand]: Sets horizontal movement axis (-1 to 1).
  /// - [JumpPressedCommand]: Triggers a jump attempt.
  /// - [DashPressedCommand]: Triggers a dash attempt.
  /// - [StrikePressedCommand]: Triggers an strike attempt.
  /// - [SecondaryPressedCommand]: Triggers an off-hand ability attempt.
  /// - [ProjectileAimDirCommand]: Sets projectile aim direction.
  /// - [MeleeAimDirCommand]: Sets melee strike direction.
  /// - [ProjectilePressedCommand]: Triggers the projectile slot attempt.
  /// - [BonusPressedCommand]: Triggers a bonus-slot ability attempt.
  ///
  /// Commands are processed before [stepOneTick] to ensure inputs are
  /// available when systems read them.
  void applyCommands(List<Command> commands) {
    // Reset all input flags to their default state.
    _world.playerInput.resetTickInputs(_player);
    final inputIndex = _world.playerInput.indexOf(_player);
    final movementIndex = _world.movement.indexOf(_player);

    for (final command in commands) {
      switch (command) {
        // Movement axis: -1 (left) to +1 (right).
        case MoveAxisCommand(:final axis):
          final clamped = axis.clamp(-1.0, 1.0);
          _world.playerInput.moveAxis[inputIndex] = clamped;
          // Update facing direction unless dashing (locked during dash).
          if (_world.movement.dashTicksLeft[movementIndex] == 0) {
            if (clamped < 0) {
              playerFacing = Facing.left;
            } else if (clamped > 0) {
              playerFacing = Facing.right;
            }
          }

        // Jump: Consumed by AbilityActivationSystem (mobility), executed by PlayerMovementSystem.
        case JumpPressedCommand():
          _world.playerInput.jumpPressed[inputIndex] = true;

        // Dash: Consumed by AbilityActivationSystem (mobility).
        case DashPressedCommand():
          _world.playerInput.dashPressed[inputIndex] = true;

        // Strike: Consumed by AbilityActivationSystem.
        case StrikePressedCommand():
          _world.playerInput.strikePressed[inputIndex] = true;
          _world.playerInput.hasAbilitySlotPressed[inputIndex] = true;
          _world.playerInput.lastAbilitySlotPressed[inputIndex] =
              AbilitySlot.primary;

        // Secondary: Consumed by AbilityActivationSystem.
        case SecondaryPressedCommand():
          _world.playerInput.secondaryPressed[inputIndex] = true;
          _world.playerInput.hasAbilitySlotPressed[inputIndex] = true;
          _world.playerInput.lastAbilitySlotPressed[inputIndex] =
              AbilitySlot.secondary;

        // Projectile aim: Direction vector for projectile abilities.
        case ProjectileAimDirCommand(:final x, :final y):
          _world.playerInput.projectileAimDirX[inputIndex] = x;
          _world.playerInput.projectileAimDirY[inputIndex] = y;

        // Melee aim: Direction vector for melee strikes.
        case MeleeAimDirCommand(:final x, :final y):
          _world.playerInput.meleeAimDirX[inputIndex] = x;
          _world.playerInput.meleeAimDirY[inputIndex] = y;

        // Clear projectile aim: Resets to no-aim state.
        case ClearProjectileAimDirCommand():
          _world.playerInput.projectileAimDirX[inputIndex] = 0;
          _world.playerInput.projectileAimDirY[inputIndex] = 0;

        // Clear melee aim: Resets to no-aim state.
        case ClearMeleeAimDirCommand():
          _world.playerInput.meleeAimDirX[inputIndex] = 0;
          _world.playerInput.meleeAimDirY[inputIndex] = 0;

        // Projectile slot: unified input for spells or throws.
        case ProjectilePressedCommand():
          _world.playerInput.projectilePressed[inputIndex] = true;
          _world.playerInput.hasAbilitySlotPressed[inputIndex] = true;
          _world.playerInput.lastAbilitySlotPressed[inputIndex] =
              AbilitySlot.projectile;

        // Bonus slot input.
        case BonusPressedCommand():
          _world.playerInput.bonusPressed[inputIndex] = true;
          _world.playerInput.hasAbilitySlotPressed[inputIndex] = true;
          _world.playerInput.lastAbilitySlotPressed[inputIndex] =
              AbilitySlot.bonus;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Simulation Tick
  // ─────────────────────────────────────────────────────────────────────────

  /// Advances the simulation by exactly one fixed tick.
  ///
  /// This is the main simulation loop. It executes all ECS systems in a
  /// carefully ordered pipeline to ensure correct behavior:
  ///
  /// 1. **Track streaming**: Generate/cull chunks, spawn enemies.
  /// 2. **Cooldowns**: Decrement ability and invulnerability timers.
  /// 3. **Enemy AI**: Compute paths and movement intentions.
  /// 4. **Player input**: Resolve ability intents (including mobility).
  /// 5. **Player movement**: Apply input to velocity.
  /// 6. **Mobility execution**: Apply dash/roll state.
  /// 7. **Gravity**: Apply gravitational acceleration.
  /// 8. **Collision**: Resolve against static world geometry.
  /// 9. **Death checks**: Detect fall-into-gap and fell-behind-camera.
  /// 10. **Camera update**: Advance autoscroll position.
  /// 11. **Pickups**: Process collectible and restoration item collection.
  /// 12. **Broadphase**: Rebuild spatial grid for hit detection.
  /// 13. **Projectiles**: Move existing projectiles.
  /// 14. **Strike intents**: Queue enemy and player strikes.
  /// 15. **Strike execution**: Spawn hitboxes/projectiles/self abilities from intents.
  /// 16. **Hitbox positioning**: Update hitbox positions from owners.
  /// 17. **Hit detection**: Check projectile and hitbox overlaps.
  /// 18. **Status ticking**: Apply DoT ticks and queue damage.
  /// 19. **Damage middleware**: Apply combat rule edits/cancellations.
  /// 20. **Damage application**: Apply queued damage events.
  /// 21. **Status application**: Apply on-hit status profiles.
  /// 22. **Death handling**: Despawn dead entities, record kills.
  /// 23. **Resource regen**: Regenerate mana and stamina.
  /// 24. **Animation**: Compute per-entity anim key + frame.
  /// 25. **Cleanup**: Remove entities past their lifetime.
  ///
  /// If the run ends during this tick (player death, fell into gap, etc.),
  /// a [RunEndedEvent] is emitted and the simulation freezes.
  void stepOneTick() {
    // Don't advance if paused or game already over.
    if (paused || gameOver) return;

    if (_deathAnimTicksLeft > 0) {
      tick += 1;
      // Update animations during death anim freeze.
      _animSystem.step(_world, player: _player, currentTick: tick);
      _deathAnimTicksLeft -= 1;
      if (_deathAnimTicksLeft <= 0) {
        _endRun(
          _pendingRunEndReason ?? RunEndReason.playerDied,
          deathInfo: _pendingDeathInfo,
        );
      }
      return;
    }

    tick += 1;

    // Cache ground Y once per tick (ground plane doesn't change mid-tick).
    final effectiveGroundTopY =
        staticWorldGeometry.groundPlane?.topY ?? groundTopY.toDouble();

    // ─── Phase 1: World generation ───
    _stepTrackManager(effectiveGroundTopY);

    // ─── Phase 2: Timer decrements ───
    _cooldownSystem.step(_world);
    _invulnerabilitySystem.step(_world);

    // ─── Phase 2.5: Control lock refresh ───
    // Must run before any gameplay systems that check locks.
    _controlLockSystem.step(_world, currentTick: tick);

    // ─── Phase 2.75: Active ability phase update ───
    _activeAbilityPhaseSystem.step(_world, currentTick: tick);

    // ─── Phase 3: AI, input, and movement ───
    _enemyNavigationSystem.step(_world, player: _player, currentTick: tick);
    _enemyEngagementSystem.step(_world, player: _player, currentTick: tick);
    _groundEnemyLocomotionSystem.step(
      _world,
      player: _player,
      dtSeconds: _movement.dtSeconds,
      currentTick: tick,
    );
    _flyingEnemyLocomotionSystem.step(
      _world,
      player: _player,
      groundTopY: effectiveGroundTopY,
      dtSeconds: _movement.dtSeconds,
      currentTick: tick,
    );

    _abilityActivationSystem.step(_world, player: _player, currentTick: tick);
    _movementSystem.step(
      _world,
      _movement,
      resources: _resourceTuning,
      currentTick: tick,
    );
    _mobilitySystem.step(_world, _movement, currentTick: tick);
    _gravitySystem.step(_world, _movement, physics: _physicsTuning);
    _collisionSystem.step(
      _world,
      _movement,
      staticWorld: _trackManager.staticIndex,
    );

    // ─── Phase 4: Distance tracking ───
    // Only count forward movement (positive X velocity).
    distance += max(0.0, playerVelX) * _movement.dtSeconds;

    // ─── Phase 5: Death condition checks ───
    if (_checkFellIntoGap(effectiveGroundTopY)) {
      _endRun(RunEndReason.fellIntoGap);
      return;
    }

    _camera.updateTick(dtSeconds: _movement.dtSeconds, playerX: playerPosX);
    if (_checkFellBehindCamera()) {
      _endRun(RunEndReason.fellBehindCamera);
      return;
    }

    // ─── Phase 6: Pickup collection ───
    _collectibleSystem.step(
      _world,
      player: _player,
      cameraLeft: _camera.left(),
      tuning: _collectibleTuning,
      onCollected: (value) {
        collectibles += 1;
        collectibleScore += value;
      },
    );
    _restorationItemSystem.step(
      _world,
      player: _player,
      cameraLeft: _camera.left(),
      tuning: _restorationItemTuning,
    );

    // ─── Phase 7: Spatial grid rebuild ───
    // Must happen before hit detection to ensure accurate overlaps.
    _broadphaseGrid.rebuild(_world);

    // ─── Phase 8: Projectile movement ───
    // Move existing projectiles before spawning new ones.
    _projectileSystem.step(_world, _movement);

    // ─── Phase 9: Strike intent writing ───
    // Enemy intent writing only.
    // Player intents are written at commit-time in Phase 3 (AbilityActivationSystem),
    // then executed later via stamped executeTick. Keep ordering explicit for tie-breaks.
    _enemyCastSystem.step(_world, player: _player, currentTick: tick);
    _enemyMeleeSystem.step(_world, player: _player, currentTick: tick);

    // ─── Phase 10: Strike execution ───
    _selfAbilitySystem.step(_world, currentTick: tick);
    // Convert intents into actual hitboxes/projectiles.
    // Self abilities first so buffs/blocks/i-frames can affect spawns & downstream combat deterministically.
    _meleeStrikeSystem.step(_world, currentTick: tick);
    _projectileLaunchSystem.step(_world, currentTick: tick);

    // ─── Phase 11: Hitbox positioning ───
    // Update hitbox transforms to follow their owner entities.
    _hitboxFollowOwnerSystem.step(_world);

    // ─── Phase 12: Hit resolution ───
    // Detect overlaps and queue damage events.
    _projectileHitSystem.step(
      _world,
      _broadphaseGrid,
      currentTick: tick,
      queueHitEvent: (event) => _events.add(event),
    );
    _hitboxDamageSystem.step(_world, _broadphaseGrid, currentTick: tick);
    _projectileWorldCollisionSystem.step(_world);
    // ─── Phase 13: Status + damage ───
    _statusSystem.tickExisting(_world);
    _damageMiddlewareSystem.step(_world, currentTick: tick);
    _damageSystem.step(
      _world,
      currentTick: tick,
      queueStatus: _statusSystem.queue,
    );
    _statusSystem.applyQueued(_world, currentTick: tick);

    // ─── Phase 14: Death handling ───
    _killedEnemiesScratch.clear();
    _enemyCullSystem.step(
      _world,
      cameraLeft: _camera.left(),
      groundTopY: effectiveGroundTopY,
      tuning: _trackTuning,
    );
    _enemyDeathStateSystem.step(
      _world,
      currentTick: tick,
      outEnemiesKilled: _killedEnemiesScratch,
    );
    _deathDespawnSystem.step(_world, currentTick: tick);
    _healthDespawnSystem.step(_world, player: _player);
    if (_killedEnemiesScratch.isNotEmpty) {
      _recordEnemyKills(_killedEnemiesScratch);
    }
    if (_isPlayerDead()) {
      if (_deathAnimTicksLeft <= 0) {
        _pendingRunEndReason = RunEndReason.playerDied;
        _pendingDeathInfo = _buildDeathInfo();
        if (_animTuning.deathAnimTicks <= 0) {
          _endRun(_pendingRunEndReason!, deathInfo: _pendingDeathInfo);
        } else {
          _deathAnimTicksLeft = _animTuning.deathAnimTicks;
        }
      }
      return;
    }

    // ─── Phase 15: Resource regeneration ───
    _resourceRegenSystem.step(_world);

    // ─── Phase 16: Animation ───
    _animSystem.step(_world, player: _player, currentTick: tick);

    // ─── Phase 17: Cleanup ───
    _lifetimeSystem.step(_world);
  }

  /// Steps the track manager and handles enemy spawning callbacks.
  ///
  /// This is extracted from [stepOneTick] to keep the main loop readable.
  void _stepTrackManager(double effectiveGroundTopY) {
    _trackManager.step(
      cameraLeft: _camera.left(),
      cameraRight: _camera.right(),
      spawnEnemy: (enemyId, x) {
        // Route spawn requests to the appropriate SpawnService method.
        switch (enemyId) {
          case EnemyId.unocoDemon:
            _spawnService.spawnUnocoDemon(
              spawnX: x,
              groundTopY: effectiveGroundTopY,
            );
          case EnemyId.grojib:
            _spawnService.spawnGroundEnemy(
              spawnX: x,
              groundTopY: effectiveGroundTopY,
            );
        }
      },
      lowestResourceStat: _lowestResourceStat,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Run End Handling
  // ─────────────────────────────────────────────────────────────────────────

  /// Ends the current run and emits a [RunEndedEvent].
  ///
  /// After this call, [gameOver] is true and [stepOneTick] will no-op.
  void _endRun(RunEndReason reason, {DeathInfo? deathInfo}) {
    gameOver = true;
    paused = true;
    _events.add(
      RunEndedEvent(
        tick: tick,
        distance: distance,
        reason: reason,
        stats: _buildRunEndStats(),
        deathInfo: deathInfo,
      ),
    );
  }

  /// Manually ends the run (e.g., from pause menu).
  ///
  /// Does nothing if the game is already over.
  void giveUp() {
    if (gameOver) return;
    _endRun(RunEndReason.gaveUp);
  }

  /// Records enemy kills for score calculation.
  void _recordEnemyKills(List<EnemyId> killedEnemies) {
    for (final enemyId in killedEnemies) {
      final index = enemyId.index;
      if (index >= 0 && index < _enemyKillCounts.length) {
        _enemyKillCounts[index] += 1;
      }
    }
  }

  /// Builds run statistics for the end-of-run event.
  RunEndStats _buildRunEndStats() => RunEndStats(
    collectibles: collectibles,
    collectibleScore: collectibleScore,
    enemyKillCounts: List<int>.unmodifiable(_enemyKillCounts),
  );

  /// Checks if the player's HP has reached zero.
  bool _isPlayerDead() {
    final hi = _world.health.tryIndexOf(_player);
    if (hi == null) return false;
    return _world.health.hp[hi] <= 0;
  }

  /// Builds death info for the run-ended event.
  ///
  /// This provides details about what killed the player (enemy type,
  /// projectile type, etc.) for death screen messaging.
  DeathInfo? _buildDeathInfo() {
    final li = _world.lastDamage.tryIndexOf(_player);
    if (li == null) return null;

    final kind = _world.lastDamage.kind[li];
    if (kind == DeathSourceKind.unknown) return null;

    return DeathInfo(
      kind: kind,
      enemyId: _world.lastDamage.hasEnemyId[li]
          ? _world.lastDamage.enemyId[li]
          : null,
      projectileId: _world.lastDamage.hasProjectileId[li]
          ? _world.lastDamage.projectileId[li]
          : null,
      projectileItemId: _world.lastDamage.hasProjectileItemId[li]
          ? _world.lastDamage.projectileItemId[li]
          : null,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Death Condition Checks
  // ─────────────────────────────────────────────────────────────────────────

  /// Checks if the player has fallen behind the camera's left edge.
  ///
  /// This is a "soft" death—the player can still be on solid ground but
  /// has failed to keep up with the autoscrolling camera.
  bool _checkFellBehindCamera() {
    if (!(_world.transform.has(_player) && _world.colliderAabb.has(_player))) {
      return false;
    }

    final ti = _world.transform.indexOf(_player);
    final ai = _world.colliderAabb.indexOf(_player);
    final centerX = _world.transform.posX[ti] + _world.colliderAabb.offsetX[ai];
    final right = centerX + _world.colliderAabb.halfX[ai];

    // Player's right edge must stay ahead of camera's left edge.
    return right < _camera.left();
  }

  /// Checks if the player has fallen into a ground gap (pit).
  ///
  /// The kill threshold is set well below ground level to give visual
  /// feedback of falling before the death triggers. Configured via
  /// [TrackTuning.gapKillOffsetY].
  bool _checkFellIntoGap(double groundTopY) {
    if (!(_world.transform.has(_player) && _world.colliderAabb.has(_player))) {
      return false;
    }

    final ti = _world.transform.indexOf(_player);
    final ai = _world.colliderAabb.indexOf(_player);
    final bottomY =
        _world.transform.posY[ti] +
        _world.colliderAabb.offsetY[ai] +
        _world.colliderAabb.halfY[ai];

    return bottomY > groundTopY + _trackTuning.gapKillOffsetY;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Resource Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the player's most depleted resource stat.
  ///
  /// Used by restoration item spawning to bias item type toward what
  /// the player needs most. Compares ratios (current/max) to handle
  /// resources with different maximum values fairly.
  ///
  /// **Tie-breaking priority**: When ratios are equal, the first resource
  /// checked wins: health > mana > stamina. This is intentional—health
  /// is prioritized as the most critical survival resource.
  RestorationStat _lowestResourceStat() {
    final hi = _world.health.tryIndexOf(_player);
    final mi = _world.mana.tryIndexOf(_player);
    final si = _world.stamina.tryIndexOf(_player);
    if (hi == null || mi == null || si == null) {
      return RestorationStat.health;
    }

    // Start with health as baseline.
    var best = RestorationStat.health;
    var bestValue = _world.health.hp[hi];
    var bestMax = _world.health.hpMax[hi];

    // Compare mana ratio.
    final mana = _world.mana.mana[mi];
    final manaMax = _world.mana.manaMax[mi];
    if (_ratioLess(mana, manaMax, bestValue, bestMax)) {
      best = RestorationStat.mana;
      bestValue = mana;
      bestMax = manaMax;
    }

    // Compare stamina ratio.
    final stamina = _world.stamina.stamina[si];
    final staminaMax = _world.stamina.staminaMax[si];
    if (_ratioLess(stamina, staminaMax, bestValue, bestMax)) {
      best = RestorationStat.stamina;
    }

    return best;
  }

  /// Compares two ratios without division: (valueA / maxA) < (valueB / maxB).
  ///
  /// Cross-multiplies to avoid division: valueA * maxB < valueB * maxA.
  bool _ratioLess(int valueA, int maxA, int valueB, int maxB) {
    if (maxA <= 0) return false; // Invalid ratio A, can't be less.
    if (maxB <= 0) return true; // Invalid ratio B, A wins by default.
    return valueA * maxB < valueB * maxA;
  }

  /// Computes the maximum air time (in ticks) for ground enemy jumps.
  ///
  /// Based on projectile motion: time = 2 * jumpSpeed / gravity.
  /// Multiplied by 1.5 for safety margin (accounts for landing tolerance).
  int _groundEnemyMaxAirTicks() {
    final gravity = _physicsTuning.gravityY;
    if (gravity <= 0) {
      // No gravity means infinite air time; cap at 1 second.
      return ticksFromSecondsCeil(1.0, tickHz);
    }
    final jumpSpeed = _groundEnemyTuning.locomotion.jumpSpeed.abs();
    final baseAirSeconds = (2.0 * jumpSpeed) / gravity;
    return ticksFromSecondsCeil(baseAirSeconds * 1.5, tickHz);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Events & Snapshots
  // ─────────────────────────────────────────────────────────────────────────

  /// Drains and returns all pending game events.
  ///
  /// Events are produced during [stepOneTick] (e.g., [RunEndedEvent]).
  /// The UI layer should call this after each tick to process events.
  ///
  /// Returns an empty list if no events are pending (avoids allocation).
  List<GameEvent> drainEvents() {
    if (_events.isEmpty) return const <GameEvent>[];
    final drained = List<GameEvent>.unmodifiable(_events);
    _events.clear();
    return drained;
  }

  /// Builds an immutable snapshot for render/UI consumption.
  ///
  /// The snapshot contains everything needed to render a single frame:
  /// - Entity positions, velocities, and animations
  /// - Player HUD data (HP, mana, stamina, cooldowns)
  /// - Static geometry (platforms, ground gaps)
  /// - Camera position
  ///
  /// Snapshots are immutable and safe to pass to async render code.
  GameStateSnapshot buildSnapshot() {
    return _snapshotBuilder.build(
      tick: tick,
      seed: seed,
      levelId: levelId,
      themeId: themeId,
      distance: distance,
      paused: paused,
      gameOver: gameOver,
      cameraCenterX: _camera.state.centerX,
      cameraCenterY: cameraFixedY,
      collectibles: collectibles,
      collectibleScore: collectibleScore,
      staticSolids: _trackManager.staticSolidsSnapshot,
      groundGaps: _trackManager.staticGroundGapsSnapshot,
    );
  }
}
