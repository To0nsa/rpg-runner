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
/// 4. **Player movement**: Apply input to velocity.
/// 5. **Gravity**: Apply gravity to non-kinematic bodies.
/// 6. **Collision**: Resolve static world collisions.
/// 7. **Pickups**: Collect items overlapping player.
/// 8. **Broadphase rebuild**: Update spatial grid for hit detection.
/// 9. **Projectile movement**: Advance existing projectiles.
/// 10. **Attack intents**: Enemies and player queue attacks.
/// 11. **Attack execution**: Spawn hitboxes and projectiles.
/// 12. **Hitbox positioning**: Follow owner entities.
/// 13. **Hit resolution**: Detect overlaps, queue damage.
/// 14. **Damage application**: Apply queued damage, set invulnerability.
/// 15. **Death handling**: Despawn dead entities, record kills.
/// 16. **Resource regen**: Regenerate mana/stamina.
/// 17. **Lifetime cleanup**: Remove expired entities.
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
import 'ecs/systems/damage_system.dart';
import 'ecs/systems/enemy_system.dart';
import 'ecs/systems/gravity_system.dart';
import 'ecs/systems/health_despawn_system.dart';
import 'ecs/systems/hitbox_damage_system.dart';
import 'ecs/systems/hitbox_follow_owner_system.dart';
import 'ecs/systems/invulnerability_system.dart';
import 'ecs/systems/lifetime_system.dart';
import 'ecs/systems/melee_attack_system.dart';
import 'ecs/systems/player_cast_system.dart';
import 'ecs/systems/player_melee_system.dart';
import 'ecs/systems/player_movement_system.dart';
import 'ecs/systems/projectile_hit_system.dart';
import 'ecs/systems/projectile_system.dart';
import 'ecs/systems/resource_regen_system.dart';
import 'ecs/systems/restoration_item_system.dart';
import 'ecs/systems/spell_cast_system.dart';
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
import 'projectiles/projectile_catalog.dart';
import 'snapshots/enums.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshot_builder.dart';
import 'spawn_service.dart';
import 'spells/spell_catalog.dart';
import 'track_manager.dart';
import 'tuning/ability_tuning.dart';
import 'tuning/camera_tuning.dart';
import 'tuning/collectible_tuning.dart';
import 'tuning/combat_tuning.dart';
import 'tuning/core_tuning.dart';
import 'tuning/flying_enemy_tuning.dart';
import 'tuning/ground_enemy_tuning.dart';
import 'tuning/movement_tuning.dart';
import 'tuning/navigation_tuning.dart';
import 'tuning/physics_tuning.dart';
import 'tuning/resource_tuning.dart';
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
  /// Use [CoreTuning] to customize game parameters:
  /// ```dart
  /// final core = GameCore(
  ///   seed: 123,
  ///   tuning: CoreTuning(
  ///     movement: MovementTuning(jumpSpeed: 600),
  ///     track: TrackTuning(enabled: false),
  ///   ),
  /// );
  /// ```
  ///
  /// Use [LevelDefinition] to select a level configuration:
  /// ```dart
  /// final core = GameCore(
  ///   seed: 123,
  ///   levelDefinition: LevelRegistry.byId(LevelId.v0Default),
  /// );
  /// ```
///
/// For backward compatibility, [GameCore.withTunings] accepts individual
/// tuning parameters:
/// ```dart
/// final core = GameCore.withTunings(
///   seed: 123,
///   movementTuning: MovementTuning(jumpSpeed: 600),
///   trackTuning: TrackTuning(enabled: false),
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
  ///
  /// For backward compatibility with existing code that passes individual
  /// tuning parameters, use [GameCore.withTunings] instead.
  GameCore({
    required int seed,
    int tickHz = defaultTickHz,
    CoreTuning tuning = const CoreTuning(),
    SpellCatalog spellCatalog = const SpellCatalog(),
    ProjectileCatalog projectileCatalog = const ProjectileCatalog(),
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
    PlayerCatalog playerCatalog = const PlayerCatalog(),
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
         spellCatalog: spellCatalog,
         projectileCatalog: projectileCatalog,
         enemyCatalog: enemyCatalog,
         playerCatalog: playerCatalog,
       );

  GameCore._fromLevel({
    required this.seed,
    required this.tickHz,
    required LevelDefinition levelDefinition,
    required SpellCatalog spellCatalog,
    required ProjectileCatalog projectileCatalog,
    required EnemyCatalog enemyCatalog,
    required PlayerCatalog playerCatalog,
  }) : _levelDefinition = levelDefinition,
       _movement = MovementTuningDerived.from(
         levelDefinition.tuning.movement,
         tickHz: tickHz,
       ),
       _physicsTuning = levelDefinition.tuning.physics,
       _resourceTuning = levelDefinition.tuning.resource,
       _abilities = AbilityTuningDerived.from(
         levelDefinition.tuning.ability,
         tickHz: tickHz,
       ),
       _combat = CombatTuningDerived.from(
         levelDefinition.tuning.combat,
         tickHz: tickHz,
       ),
       _flyingEnemyTuning = FlyingEnemyTuningDerived.from(
         levelDefinition.tuning.flyingEnemy,
         tickHz: tickHz,
       ),
       _groundEnemyTuning = GroundEnemyTuningDerived.from(
         levelDefinition.tuning.groundEnemy,
         tickHz: tickHz,
       ),
       _navigationTuning = levelDefinition.tuning.navigation,
       _spatialGridTuning = levelDefinition.tuning.spatialGrid,
       _spells = spellCatalog,
       _projectiles = ProjectileCatalogDerived.from(
         projectileCatalog,
         tickHz: tickHz,
       ),
       _enemyCatalog = enemyCatalog,
       _playerCatalog = playerCatalog,
       _scoreTuning = levelDefinition.tuning.score,
       _trackTuning = levelDefinition.tuning.track,
       _collectibleTuning = levelDefinition.tuning.collectible,
       _restorationItemTuning = levelDefinition.tuning.restorationItem {
    _initializeWorld(levelDefinition);
  }

  /// Creates a game simulation with individual tuning parameters.
  ///
  /// This factory provides backward compatibility for code that passes
  /// individual tuning objects. Prefer the default constructor with
  /// [CoreTuning] for new code.
  ///
  /// Example:
  /// ```dart
  /// final core = GameCore.withTunings(
  ///   seed: 123,
  ///   movementTuning: MovementTuning(jumpSpeed: 600),
  ///   trackTuning: TrackTuning(enabled: false),
  /// );
  /// ```
  factory GameCore.withTunings({
    required int seed,
    int tickHz = defaultTickHz,
    PhysicsTuning physicsTuning = const PhysicsTuning(),
    MovementTuning movementTuning = const MovementTuning(),
    ResourceTuning resourceTuning = const ResourceTuning(),
    AbilityTuning abilityTuning = const AbilityTuning(),
    CombatTuning combatTuning = const CombatTuning(),
    FlyingEnemyTuning flyingEnemyTuning = const FlyingEnemyTuning(),
    GroundEnemyTuning groundEnemyTuning = const GroundEnemyTuning(),
    NavigationTuning navigationTuning = const NavigationTuning(),
    SpatialGridTuning spatialGridTuning = const SpatialGridTuning(),
    CameraTuning cameraTuning = const CameraTuning(),
    TrackTuning trackTuning = const TrackTuning(),
    CollectibleTuning collectibleTuning = const CollectibleTuning(),
    RestorationItemTuning restorationItemTuning = const RestorationItemTuning(),
    ScoreTuning scoreTuning = const ScoreTuning(),
    SpellCatalog spellCatalog = const SpellCatalog(),
    ProjectileCatalog projectileCatalog = const ProjectileCatalog(),
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
    PlayerCatalog playerCatalog = const PlayerCatalog(),
    StaticWorldGeometry staticWorldGeometry = const StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: groundTopY * 1.0),
    ),
  }) {
    return GameCore(
      seed: seed,
      tickHz: tickHz,
      tuning: CoreTuning(
        physics: physicsTuning,
        movement: movementTuning,
        resource: resourceTuning,
        ability: abilityTuning,
        combat: combatTuning,
        flyingEnemy: flyingEnemyTuning,
        groundEnemy: groundEnemyTuning,
        navigation: navigationTuning,
        spatialGrid: spatialGridTuning,
        camera: cameraTuning,
        track: trackTuning,
        collectible: collectibleTuning,
        restorationItem: restorationItemTuning,
        score: scoreTuning,
      ),
      spellCatalog: spellCatalog,
      projectileCatalog: projectileCatalog,
      enemyCatalog: enemyCatalog,
      playerCatalog: playerCatalog,
      staticWorldGeometry: staticWorldGeometry,
    );
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
      flyingEnemyTuning: _flyingEnemyTuning,
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
      enemySystem: _enemySystem,
      spawnService: _spawnService,
      groundTopY: effectiveGroundTopY,
      patternPool: levelDefinition.patternPool,
      earlyPatternChunks: levelDefinition.earlyPatternChunks,
      noEnemyChunks: levelDefinition.noEnemyChunks,
    );

    // ─── Initialize snapshot builder (needs player entity ID) ───
    _snapshotBuilder = SnapshotBuilder(
      world: _world,
      player: _player,
      movement: _movement,
      abilities: _abilities,
      resources: _resourceTuning,
      spells: _spells,
      projectiles: _projectiles,
    );
  }

  /// Initializes all ECS systems.
  ///
  /// Systems are stateless processors that operate on component stores.
  /// They're created once at construction and reused every tick.
  void _initializeSystems() {
    // Core movement and physics.
    _movementSystem = PlayerMovementSystem();
    _collisionSystem = CollisionSystem();
    _cooldownSystem = CooldownSystem();
    _gravitySystem = GravitySystem();

    // Projectile lifecycle.
    _projectileSystem = ProjectileSystem();
    _projectileHitSystem = ProjectileHitSystem();

    // Spatial partitioning for hit detection.
    _broadphaseGrid = BroadphaseGrid(
      index: GridIndex2D(cellSize: _spatialGridTuning.broadphaseCellSize),
    );

    // Hitbox management.
    _hitboxFollowOwnerSystem = HitboxFollowOwnerSystem();
    _lifetimeSystem = LifetimeSystem();

    // Damage pipeline.
    _invulnerabilitySystem = InvulnerabilitySystem();
    _damageSystem = DamageSystem(
      invulnerabilityTicksOnHit: _combat.invulnerabilityTicks,
    );
    _healthDespawnSystem = HealthDespawnSystem();

    // Player combat.
    _meleeSystem = PlayerMeleeSystem(
      abilities: _abilities,
      movement: _movement,
    );
    _hitboxDamageSystem = HitboxDamageSystem();

    // Pickup systems.
    _collectibleSystem = CollectibleSystem();
    _restorationItemSystem = RestorationItemSystem();
    _resourceRegenSystem = ResourceRegenSystem();

    // Spell/cast systems.
    _castSystem = PlayerCastSystem(abilities: _abilities, movement: _movement);
    _spellCastSystem = SpellCastSystem(
      spells: _spells,
      projectiles: _projectiles,
    );
    _meleeAttackSystem = MeleeAttackSystem();

    // Navigation infrastructure.
    _surfaceGraphBuilder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: _spatialGridTuning.broadphaseCellSize),
      takeoffSampleMaxStep: _navigationTuning.takeoffSampleMaxStep,
    );
    _groundEnemyJumpTemplate = JumpReachabilityTemplate.build(
      JumpProfile(
        jumpSpeed: _groundEnemyTuning.base.groundEnemyJumpSpeed,
        gravityY: _physicsTuning.gravityY,
        maxAirTicks: _groundEnemyMaxAirTicks(),
        airSpeedX: _groundEnemyTuning.base.groundEnemySpeedX,
        dtSeconds: _movement.dtSeconds,
        agentHalfWidth: _enemyCatalog.get(EnemyId.groundEnemy).collider.halfX,
      ),
    );
    _surfacePathfinder = SurfacePathfinder(
      maxExpandedNodes: _navigationTuning.maxExpandedNodes,
      runSpeedX: _groundEnemyTuning.base.groundEnemySpeedX,
      edgePenaltySeconds: _navigationTuning.edgePenaltySeconds,
    );
    _surfaceNavigator = SurfaceNavigator(
      pathfinder: _surfacePathfinder,
      repathCooldownTicks: _navigationTuning.repathCooldownTicks,
      surfaceEps: _navigationTuning.surfaceEps,
      takeoffEps: max(
        _navigationTuning.takeoffEpsMin,
        _groundEnemyTuning.base.groundEnemyStopDistanceX,
      ),
    );

    // Enemy AI system (depends on navigation).
    _enemySystem = EnemySystem(
      flyingEnemyTuning: _flyingEnemyTuning,
      groundEnemyTuning: _groundEnemyTuning,
      surfaceNavigator: _surfaceNavigator,
      spells: _spells,
      projectiles: _projectiles,
      trajectoryPredictor: TrajectoryPredictor(
        gravityY: _physicsTuning.gravityY,
        dtSeconds: _movement.dtSeconds,
        maxTicks: 120,
      ),
    );
  }

  /// Spawns the player entity at the start of a run.
  ///
  /// The player is positioned at [TrackTuning.playerStartX], standing on the
  /// ground. This must be called before [TrackManager] is created because
  /// track manager callbacks reference the player entity.
  void _spawnPlayer(double groundTopY) {
    final spawnX = _trackTuning.playerStartX;
    final playerArchetype = PlayerCatalogDerived.from(
      _playerCatalog,
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
    );
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
  final ResourceTuning _resourceTuning;
  final AbilityTuningDerived _abilities;
  final CombatTuningDerived _combat;
  final FlyingEnemyTuningDerived _flyingEnemyTuning;
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

  final SpellCatalog _spells;
  final ProjectileCatalogDerived _projectiles;
  final EnemyCatalog _enemyCatalog;
  final PlayerCatalog _playerCatalog;

  // ─── ECS Core ───

  /// The ECS world containing all component stores.
  late final EcsWorld _world;

  /// Factory for creating complex entities (player, enemies).
  late final EntityFactory _entityFactory;

  /// The player entity ID.
  late EntityId _player;

  // ─── ECS Systems ───
  // Stateless processors that operate on component stores.

  late final PlayerMovementSystem _movementSystem;
  late final CollisionSystem _collisionSystem;
  late final CooldownSystem _cooldownSystem;
  late final GravitySystem _gravitySystem;
  late final ProjectileSystem _projectileSystem;
  late final ProjectileHitSystem _projectileHitSystem;
  late final BroadphaseGrid _broadphaseGrid;
  late final HitboxFollowOwnerSystem _hitboxFollowOwnerSystem;
  late final CollectibleSystem _collectibleSystem;
  late final RestorationItemSystem _restorationItemSystem;
  late final LifetimeSystem _lifetimeSystem;
  late final InvulnerabilitySystem _invulnerabilitySystem;
  late final DamageSystem _damageSystem;
  late final HealthDespawnSystem _healthDespawnSystem;
  late EnemySystem _enemySystem;
  late final SurfaceGraphBuilder _surfaceGraphBuilder;
  late final JumpReachabilityTemplate _groundEnemyJumpTemplate;
  late final SurfacePathfinder _surfacePathfinder;
  late final SurfaceNavigator _surfaceNavigator;
  late final PlayerMeleeSystem _meleeSystem;
  late final MeleeAttackSystem _meleeAttackSystem;
  late final HitboxDamageSystem _hitboxDamageSystem;
  late final ResourceRegenSystem _resourceRegenSystem;
  late final PlayerCastSystem _castSystem;
  late final SpellCastSystem _spellCastSystem;

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

  /// Remaining cast (projectile) cooldown ticks.
  int get playerCastCooldownTicksLeft =>
      _world.cooldown.castCooldownTicksLeft[_world.cooldown.indexOf(_player)];

  /// Remaining melee attack cooldown ticks.
  int get playerMeleeCooldownTicksLeft =>
      _world.cooldown.meleeCooldownTicksLeft[_world.cooldown.indexOf(_player)];

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
  /// - [AttackPressedCommand]: Triggers an attack attempt.
  /// - [ProjectileAimDirCommand]: Sets projectile aim direction.
  /// - [MeleeAimDirCommand]: Sets melee attack direction.
  /// - [CastPressedCommand]: Triggers a spell cast attempt.
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

        // Jump: Consumed by PlayerMovementSystem.
        case JumpPressedCommand():
          _world.playerInput.jumpPressed[inputIndex] = true;

        // Dash: Consumed by PlayerMovementSystem.
        case DashPressedCommand():
          _world.playerInput.dashPressed[inputIndex] = true;

        // Attack: Consumed by PlayerMeleeSystem.
        case AttackPressedCommand():
          _world.playerInput.attackPressed[inputIndex] = true;

        // Projectile aim: Direction vector for ranged attacks.
        case ProjectileAimDirCommand(:final x, :final y):
          _world.playerInput.projectileAimDirX[inputIndex] = x;
          _world.playerInput.projectileAimDirY[inputIndex] = y;

        // Melee aim: Direction vector for melee attacks.
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

        // Cast: Consumed by PlayerCastSystem for spell casting.
        case CastPressedCommand():
          _world.playerInput.castPressed[inputIndex] = true;
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
  /// 4. **Player movement**: Apply input to velocity.
  /// 5. **Gravity**: Apply gravitational acceleration.
  /// 6. **Collision**: Resolve against static world geometry.
  /// 7. **Death checks**: Detect fall-into-gap and fell-behind-camera.
  /// 8. **Camera update**: Advance autoscroll position.
  /// 9. **Pickups**: Process collectible and restoration item collection.
  /// 10. **Broadphase**: Rebuild spatial grid for hit detection.
  /// 11. **Projectiles**: Move existing projectiles.
  /// 12. **Attack intents**: Queue enemy and player attacks.
  /// 13. **Attack execution**: Spawn hitboxes and projectiles from intents.
  /// 14. **Hitbox positioning**: Update hitbox positions from owners.
  /// 15. **Hit detection**: Check projectile and hitbox overlaps.
  /// 16. **Damage application**: Apply queued damage events.
  /// 17. **Death handling**: Despawn dead entities, record kills.
  /// 18. **Resource regen**: Regenerate mana and stamina.
  /// 19. **Cleanup**: Remove entities past their lifetime.
  ///
  /// If the run ends during this tick (player death, fell into gap, etc.),
  /// a [RunEndedEvent] is emitted and the simulation freezes.
  void stepOneTick() {
    // Don't advance if paused or game already over.
    if (paused || gameOver) return;

    tick += 1;

    // Cache ground Y once per tick (ground plane doesn't change mid-tick).
    final effectiveGroundTopY =
        staticWorldGeometry.groundPlane?.topY ?? groundTopY.toDouble();

    // ─── Phase 1: World generation ───
    _stepTrackManager(effectiveGroundTopY);

    // ─── Phase 2: Timer decrements ───
    _cooldownSystem.step(_world);
    _invulnerabilitySystem.step(_world);

    // ─── Phase 3: AI and movement ───
    _enemySystem.stepSteering(
      _world,
      player: _player,
      groundTopY: effectiveGroundTopY,
      dtSeconds: _movement.dtSeconds,
    );

    _movementSystem.step(_world, _movement, resources: _resourceTuning);
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

    // ─── Phase 9: Attack intent writing ───
    // Enemies first, then player (order matters for fairness).
    _enemySystem.stepAttacks(_world, player: _player, currentTick: tick);
    _castSystem.step(_world, player: _player, currentTick: tick);
    _meleeSystem.step(_world, player: _player, currentTick: tick);

    // ─── Phase 10: Attack execution ───
    // Convert intents into actual hitboxes and projectiles.
    _spellCastSystem.step(_world, currentTick: tick);
    _meleeAttackSystem.step(_world, currentTick: tick);

    // ─── Phase 11: Hitbox positioning ───
    // Update hitbox transforms to follow their owner entities.
    _hitboxFollowOwnerSystem.step(_world);

    // ─── Phase 12: Hit resolution ───
    // Detect overlaps and queue damage events.
    _projectileHitSystem.step(_world, _damageSystem.queue, _broadphaseGrid);
    _hitboxDamageSystem.step(_world, _damageSystem.queue, _broadphaseGrid);
    _damageSystem.step(_world, currentTick: tick);

    // ─── Phase 13: Death handling ───
    _killedEnemiesScratch.clear();
    _healthDespawnSystem.step(
      _world,
      player: _player,
      outEnemiesKilled: _killedEnemiesScratch,
    );
    if (_killedEnemiesScratch.isNotEmpty) {
      _recordEnemyKills(_killedEnemiesScratch);
    }
    if (_isPlayerDead()) {
      _endRun(RunEndReason.playerDied, deathInfo: _buildDeathInfo());
      return;
    }

    // ─── Phase 14: Resource regeneration ───
    _resourceRegenSystem.step(_world, dtSeconds: _movement.dtSeconds);

    // ─── Phase 15: Cleanup ───
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
          case EnemyId.flyingEnemy:
            _spawnService.spawnFlyingEnemy(
              spawnX: x,
              groundTopY: effectiveGroundTopY,
            );
          case EnemyId.groundEnemy:
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
    return _world.health.hp[hi] <= 0.0;
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
      spellId: _world.lastDamage.hasSpellId[li]
          ? _world.lastDamage.spellId[li]
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
  bool _ratioLess(double valueA, double maxA, double valueB, double maxB) {
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
    final jumpSpeed = _groundEnemyTuning.base.groundEnemyJumpSpeed.abs();
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
