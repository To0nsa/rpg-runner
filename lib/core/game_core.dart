/// Authoritative, deterministic simulation layer (pure Dart).
///
/// Applies tick-stamped commands, advances the simulation by fixed ticks, and
/// produces snapshots/events for the renderer/UI. Must not import Flutter/Flame.
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
/// Coordinates ECS systems, processes commands, and produces snapshots.
/// Does not depend on Flutter/Flame - pure Dart for testability.
class GameCore {
  GameCore({
    required this.seed,
    this.tickHz = defaultTickHz,
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
  })  : _movement = MovementTuningDerived.from(movementTuning, tickHz: tickHz),
        _physicsTuning = physicsTuning,
        _resourceTuning = resourceTuning,
        _abilities = AbilityTuningDerived.from(abilityTuning, tickHz: tickHz),
        _combat = CombatTuningDerived.from(combatTuning, tickHz: tickHz),
        _flyingEnemyTuning = FlyingEnemyTuningDerived.from(
          flyingEnemyTuning,
          tickHz: tickHz,
        ),
        _groundEnemyTuning = GroundEnemyTuningDerived.from(
          groundEnemyTuning,
          tickHz: tickHz,
        ),
        _navigationTuning = navigationTuning,
        _spatialGridTuning = spatialGridTuning,
        _spells = spellCatalog,
        _projectiles = ProjectileCatalogDerived.from(
          projectileCatalog,
          tickHz: tickHz,
        ),
        _enemyCatalog = enemyCatalog,
        _playerCatalog = playerCatalog,
        _scoreTuning = scoreTuning,
        _trackTuning = trackTuning,
        _collectibleTuning = collectibleTuning,
        _restorationItemTuning = restorationItemTuning {
    // Initialize ECS world and factory.
    _world = EcsWorld(seed: seed);
    _entityFactory = EntityFactory(_world);

    // Initialize systems.
    _initializeSystems();

    // Initialize camera.
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

    // Initialize spawn service.
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

    // Initialize track manager.
    final effectiveGroundTopY =
        staticWorldGeometry.groundPlane?.topY ?? groundTopY.toDouble();

    // Spawn player first (needed by snapshot builder and track manager callbacks).
    _spawnPlayer(effectiveGroundTopY);

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
    );

    // Initialize snapshot builder (after player spawn).
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

  void _initializeSystems() {
    _movementSystem = PlayerMovementSystem();
    _collisionSystem = CollisionSystem();
    _cooldownSystem = CooldownSystem();
    _gravitySystem = GravitySystem();
    _projectileSystem = ProjectileSystem();
    _projectileHitSystem = ProjectileHitSystem();
    _broadphaseGrid = BroadphaseGrid(
      index: GridIndex2D(cellSize: _spatialGridTuning.broadphaseCellSize),
    );
    _hitboxFollowOwnerSystem = HitboxFollowOwnerSystem();
    _lifetimeSystem = LifetimeSystem();
    _invulnerabilitySystem = InvulnerabilitySystem();
    _damageSystem = DamageSystem(
      invulnerabilityTicksOnHit: _combat.invulnerabilityTicks,
    );
    _healthDespawnSystem = HealthDespawnSystem();
    _meleeSystem = PlayerMeleeSystem(
      abilities: _abilities,
      movement: _movement,
    );
    _hitboxDamageSystem = HitboxDamageSystem();
    _collectibleSystem = CollectibleSystem();
    _restorationItemSystem = RestorationItemSystem();
    _resourceRegenSystem = ResourceRegenSystem();
    _castSystem = PlayerCastSystem(abilities: _abilities, movement: _movement);
    _spellCastSystem = SpellCastSystem(
      spells: _spells,
      projectiles: _projectiles,
    );
    _meleeAttackSystem = MeleeAttackSystem();
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

  void _spawnPlayer(double groundTopY) {
    const spawnX = 400.0;
    final playerArchetype = PlayerCatalogDerived.from(
      _playerCatalog,
      movement: _movement,
      resources: _resourceTuning,
    ).archetype;
    final playerCollider = playerArchetype.collider;
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

  /// Seed used for deterministic generation/RNG.
  final int seed;

  /// Fixed simulation tick frequency.
  final int tickHz;

  // Derived tunings.
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
  final SpellCatalog _spells;
  final ProjectileCatalogDerived _projectiles;
  final EnemyCatalog _enemyCatalog;
  final PlayerCatalog _playerCatalog;

  // ECS core.
  late final EcsWorld _world;
  late final EntityFactory _entityFactory;
  late EntityId _player;

  // Systems.
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

  // Modular services.
  late final SpawnService _spawnService;
  late final TrackManager _trackManager;
  late SnapshotBuilder _snapshotBuilder;

  // Camera.
  late final AutoscrollCamera _camera;

  // Event queue.
  final List<GameEvent> _events = <GameEvent>[];

  // Scratch/tracking state.
  final List<EnemyId> _killedEnemiesScratch = <EnemyId>[];
  final List<int> _enemyKillCounts = List<int>.filled(EnemyId.values.length, 0);

  /// Current simulation tick.
  int tick = 0;

  /// Whether simulation should advance.
  bool paused = false;

  /// Whether the run has ended (simulation is frozen).
  bool gameOver = false;

  /// Run progression metric.
  double distance = 0;

  /// Collected collectibles count.
  int collectibles = 0;

  /// Collectible score value.
  int collectibleScore = 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Public accessors
  // ─────────────────────────────────────────────────────────────────────────

  ScoreTuning get scoreTuning => _scoreTuning;

  StaticWorldGeometry get staticWorldGeometry => _trackManager.staticGeometry;

  double get playerPosX =>
      _world.transform.posX[_world.transform.indexOf(_player)];
  double get playerPosY =>
      _world.transform.posY[_world.transform.indexOf(_player)];

  void setPlayerPosXY(double x, double y) =>
      _world.transform.setPosXY(_player, x, y);

  double get playerVelX =>
      _world.transform.velX[_world.transform.indexOf(_player)];
  double get playerVelY =>
      _world.transform.velY[_world.transform.indexOf(_player)];

  void setPlayerVelXY(double x, double y) =>
      _world.transform.setVelXY(_player, x, y);

  bool get playerGrounded =>
      _world.collision.grounded[_world.collision.indexOf(_player)];

  Facing get playerFacing =>
      _world.movement.facing[_world.movement.indexOf(_player)];
  set playerFacing(Facing value) {
    _world.movement.facing[_world.movement.indexOf(_player)] = value;
  }

  int get playerCastCooldownTicksLeft =>
      _world.cooldown.castCooldownTicksLeft[_world.cooldown.indexOf(_player)];

  int get playerMeleeCooldownTicksLeft =>
      _world.cooldown.meleeCooldownTicksLeft[_world.cooldown.indexOf(_player)];

  // ─────────────────────────────────────────────────────────────────────────
  // Command processing
  // ─────────────────────────────────────────────────────────────────────────

  /// Applies all commands scheduled for the current tick.
  void applyCommands(List<Command> commands) {
    _world.playerInput.resetTickInputs(_player);
    final inputIndex = _world.playerInput.indexOf(_player);
    final movementIndex = _world.movement.indexOf(_player);

    for (final command in commands) {
      switch (command) {
        case MoveAxisCommand(:final axis):
          final clamped = axis.clamp(-1.0, 1.0);
          _world.playerInput.moveAxis[inputIndex] = clamped;
          if (_world.movement.dashTicksLeft[movementIndex] == 0) {
            if (clamped < 0) {
              playerFacing = Facing.left;
            } else if (clamped > 0) {
              playerFacing = Facing.right;
            }
          }
        case JumpPressedCommand():
          _world.playerInput.jumpPressed[inputIndex] = true;
        case DashPressedCommand():
          _world.playerInput.dashPressed[inputIndex] = true;
        case AttackPressedCommand():
          _world.playerInput.attackPressed[inputIndex] = true;
        case ProjectileAimDirCommand(:final x, :final y):
          _world.playerInput.projectileAimDirX[inputIndex] = x;
          _world.playerInput.projectileAimDirY[inputIndex] = y;
        case MeleeAimDirCommand(:final x, :final y):
          _world.playerInput.meleeAimDirX[inputIndex] = x;
          _world.playerInput.meleeAimDirY[inputIndex] = y;
        case ClearProjectileAimDirCommand():
          _world.playerInput.projectileAimDirX[inputIndex] = 0;
          _world.playerInput.projectileAimDirY[inputIndex] = 0;
        case ClearMeleeAimDirCommand():
          _world.playerInput.meleeAimDirX[inputIndex] = 0;
          _world.playerInput.meleeAimDirY[inputIndex] = 0;
        case CastPressedCommand():
          _world.playerInput.castPressed[inputIndex] = true;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Simulation tick
  // ─────────────────────────────────────────────────────────────────────────

  /// Advances the simulation by exactly one fixed tick.
  void stepOneTick() {
    if (paused || gameOver) return;

    tick += 1;

    // Track streaming (geometry + enemy spawns).
    _stepTrackManager();

    // Core systems.
    _cooldownSystem.step(_world);
    _invulnerabilitySystem.step(_world);

    final effectiveGroundTopY =
        staticWorldGeometry.groundPlane?.topY ?? groundTopY.toDouble();
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

    distance += max(0.0, playerVelX) * _movement.dtSeconds;

    // Check death conditions.
    if (_checkFellIntoGap(effectiveGroundTopY)) {
      _endRun(RunEndReason.fellIntoGap);
      return;
    }

    _camera.updateTick(dtSeconds: _movement.dtSeconds, playerX: playerPosX);
    if (_checkFellBehindCamera()) {
      _endRun(RunEndReason.fellBehindCamera);
      return;
    }

    // Pickup systems.
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

    // Rebuild broadphase for hit detection.
    _broadphaseGrid.rebuild(_world);

    // Move existing projectiles before spawning new ones.
    _projectileSystem.step(_world, _movement);

    // Intent writers (enemy then player).
    _enemySystem.stepAttacks(_world, player: _player, currentTick: tick);
    _castSystem.step(_world, player: _player, currentTick: tick);
    _meleeSystem.step(_world, player: _player, currentTick: tick);

    // Execute intents.
    _spellCastSystem.step(_world, currentTick: tick);
    _meleeAttackSystem.step(_world, currentTick: tick);

    // Position hitboxes from owner + offset.
    _hitboxFollowOwnerSystem.step(_world);

    // Resolve hits.
    _projectileHitSystem.step(_world, _damageSystem.queue, _broadphaseGrid);
    _hitboxDamageSystem.step(_world, _damageSystem.queue, _broadphaseGrid);
    _damageSystem.step(_world, currentTick: tick);

    // Handle deaths.
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

    _resourceRegenSystem.step(_world, dtSeconds: _movement.dtSeconds);

    // Cleanup.
    _lifetimeSystem.step(_world);
  }

  void _stepTrackManager() {
    final effectiveGroundTopY =
        staticWorldGeometry.groundPlane?.topY ?? groundTopY.toDouble();

    _trackManager.step(
      cameraLeft: _camera.left(),
      cameraRight: _camera.right(),
      spawnEnemy: (enemyId, x) {
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
  // Run end handling
  // ─────────────────────────────────────────────────────────────────────────

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

  void giveUp() {
    if (gameOver) return;
    _endRun(RunEndReason.gaveUp);
  }

  void _recordEnemyKills(List<EnemyId> killedEnemies) {
    for (final enemyId in killedEnemies) {
      final index = enemyId.index;
      if (index >= 0 && index < _enemyKillCounts.length) {
        _enemyKillCounts[index] += 1;
      }
    }
  }

  RunEndStats _buildRunEndStats() => RunEndStats(
        collectibles: collectibles,
        collectibleScore: collectibleScore,
        enemyKillCounts: List<int>.unmodifiable(_enemyKillCounts),
      );

  bool _isPlayerDead() {
    final hi = _world.health.tryIndexOf(_player);
    if (hi == null) return false;
    return _world.health.hp[hi] <= 0.0;
  }

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
  // Death condition checks
  // ─────────────────────────────────────────────────────────────────────────

  bool _checkFellBehindCamera() {
    if (!(_world.transform.has(_player) && _world.colliderAabb.has(_player))) {
      return false;
    }

    final ti = _world.transform.indexOf(_player);
    final ai = _world.colliderAabb.indexOf(_player);
    final centerX = _world.transform.posX[ti] + _world.colliderAabb.offsetX[ai];
    final right = centerX + _world.colliderAabb.halfX[ai];
    return right < _camera.left();
  }

  bool _checkFellIntoGap(double groundTopY) {
    if (!(_world.transform.has(_player) && _world.colliderAabb.has(_player))) {
      return false;
    }

    const gapKillOffsetY = 400.0;
    final ti = _world.transform.indexOf(_player);
    final ai = _world.colliderAabb.indexOf(_player);
    final bottomY = _world.transform.posY[ti] +
        _world.colliderAabb.offsetY[ai] +
        _world.colliderAabb.halfY[ai];
    return bottomY > groundTopY + gapKillOffsetY;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Resource helpers
  // ─────────────────────────────────────────────────────────────────────────

  RestorationStat _lowestResourceStat() {
    final hi = _world.health.tryIndexOf(_player);
    final mi = _world.mana.tryIndexOf(_player);
    final si = _world.stamina.tryIndexOf(_player);
    if (hi == null || mi == null || si == null) {
      return RestorationStat.health;
    }

    var best = RestorationStat.health;
    var bestValue = _world.health.hp[hi];
    var bestMax = _world.health.hpMax[hi];

    final mana = _world.mana.mana[mi];
    final manaMax = _world.mana.manaMax[mi];
    if (_ratioLess(mana, manaMax, bestValue, bestMax)) {
      best = RestorationStat.mana;
      bestValue = mana;
      bestMax = manaMax;
    }

    final stamina = _world.stamina.stamina[si];
    final staminaMax = _world.stamina.staminaMax[si];
    if (_ratioLess(stamina, staminaMax, bestValue, bestMax)) {
      best = RestorationStat.stamina;
    }

    return best;
  }

  bool _ratioLess(double valueA, double maxA, double valueB, double maxB) {
    if (maxA <= 0) return false;
    if (maxB <= 0) return true;
    return valueA * maxB < valueB * maxA;
  }

  int _groundEnemyMaxAirTicks() {
    final gravity = _physicsTuning.gravityY;
    if (gravity <= 0) {
      return ticksFromSecondsCeil(1.0, tickHz);
    }
    final jumpSpeed = _groundEnemyTuning.base.groundEnemyJumpSpeed.abs();
    final baseAirSeconds = (2.0 * jumpSpeed) / gravity;
    return ticksFromSecondsCeil(baseAirSeconds * 1.5, tickHz);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Events & Snapshots
  // ─────────────────────────────────────────────────────────────────────────

  List<GameEvent> drainEvents() {
    if (_events.isEmpty) return const <GameEvent>[];
    final drained = List<GameEvent>.unmodifiable(_events);
    _events.clear();
    return drained;
  }

  /// Builds an immutable snapshot for render/UI consumption.
  GameStateSnapshot buildSnapshot() {
    // Update snapshot builder player reference (in case it changed).
    _snapshotBuilder = SnapshotBuilder(
      world: _world,
      player: _player,
      movement: _movement,
      abilities: _abilities,
      resources: _resourceTuning,
      spells: _spells,
      projectiles: _projectiles,
    );

    return _snapshotBuilder.build(
      tick: tick,
      seed: seed,
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
