// Authoritative, deterministic simulation layer (pure Dart).
//
// This is the "truth" of the game: it applies tick-stamped commands, advances
// the simulation by fixed ticks, and produces snapshots/events for the
// renderer/UI. It must not import Flutter or Flame.
import 'dart:math';

import 'commands/command.dart';
import 'camera/v0_autoscroll_camera.dart';
import 'collision/static_world_geometry.dart';
import 'collision/static_world_geometry_index.dart';
import 'contracts/v0_render_contract.dart';
import 'ecs/entity_id.dart';
import 'ecs/spatial/broadphase_grid.dart';
import 'ecs/spatial/grid_index_2d.dart';
import 'ecs/systems/collision_system.dart';
import 'ecs/systems/cooldown_system.dart';
import 'ecs/systems/gravity_system.dart';
import 'ecs/systems/player_cast_system.dart';
import 'ecs/systems/spell_cast_system.dart';
import 'ecs/systems/damage_system.dart';
import 'ecs/systems/health_despawn_system.dart';
import 'ecs/systems/enemy_system.dart';
import 'ecs/systems/hitbox_damage_system.dart';
import 'ecs/systems/hitbox_follow_owner_system.dart';
import 'ecs/systems/invulnerability_system.dart';
import 'ecs/systems/lifetime_system.dart';
import 'ecs/systems/player_melee_system.dart';
import 'ecs/systems/melee_attack_system.dart';
import 'ecs/systems/player_movement_system.dart';
import 'ecs/systems/projectile_system.dart';
import 'ecs/systems/projectile_hit_system.dart';
import 'ecs/systems/resource_regen_system.dart';
import 'ecs/stores/body_store.dart';
import 'ecs/world.dart';
import 'enemies/enemy_catalog.dart';
import 'enemies/enemy_id.dart';
import 'events/game_event.dart';
import 'math/vec2.dart';
import 'navigation/jump_template.dart';
import 'navigation/surface_graph_builder.dart';
import 'navigation/surface_navigator.dart';
import 'navigation/surface_pathfinder.dart';
import 'players/player_catalog.dart';
import 'snapshots/enums.dart';
import 'snapshots/entity_render_snapshot.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshots/player_hud_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
import 'projectiles/projectile_catalog.dart';
import 'spells/spell_catalog.dart';
import 'spells/spell_id.dart';
import 'track/v0_track_streamer.dart';
import 'tuning/v0_ability_tuning.dart';
import 'tuning/v0_combat_tuning.dart';
import 'tuning/v0_flying_enemy_tuning.dart';
import 'tuning/v0_ground_enemy_tuning.dart';
import 'tuning/v0_movement_tuning.dart';
import 'tuning/v0_navigation_tuning.dart';
import 'tuning/v0_physics_tuning.dart';
import 'tuning/v0_resource_tuning.dart';
import 'tuning/v0_score_tuning.dart';
import 'tuning/v0_camera_tuning.dart';
import 'tuning/v0_spatial_grid_tuning.dart';
import 'tuning/v0_track_tuning.dart';
import 'util/tick_math.dart';

/// Minimal placeholder `GameCore` used to validate architecture wiring.
///
/// This will be replaced by the full ECS/systems implementation in later
/// milestones. The core invariants remain: fixed ticks, command-driven input,
/// deterministic state updates, snapshot output.
class GameCore {
  GameCore({
    required this.seed,
    this.tickHz = v0DefaultTickHz,
    V0PhysicsTuning physicsTuning = const V0PhysicsTuning(),
    V0MovementTuning movementTuning = const V0MovementTuning(),
    V0ResourceTuning resourceTuning = const V0ResourceTuning(),
    V0AbilityTuning abilityTuning = const V0AbilityTuning(),
    V0CombatTuning combatTuning = const V0CombatTuning(),
    V0FlyingEnemyTuning flyingEnemyTuning = const V0FlyingEnemyTuning(),
    V0GroundEnemyTuning groundEnemyTuning = const V0GroundEnemyTuning(),
    V0NavigationTuning navigationTuning = const V0NavigationTuning(),
    V0SpatialGridTuning spatialGridTuning = const V0SpatialGridTuning(),
    V0CameraTuning cameraTuning = const V0CameraTuning(),
    V0TrackTuning trackTuning = const V0TrackTuning(),
    V0ScoreTuning scoreTuning = const V0ScoreTuning(),
    SpellCatalog spellCatalog = const SpellCatalog(),
    ProjectileCatalog projectileCatalog = const ProjectileCatalog(),
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
    PlayerCatalog playerCatalog = const PlayerCatalog(),
    StaticWorldGeometry staticWorldGeometry = const StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: v0GroundTopY * 1.0),
    ),
  }) : _movement = V0MovementTuningDerived.from(movementTuning, tickHz: tickHz),
       _physicsTuning = physicsTuning,
       _resourceTuning = resourceTuning,
       _abilities = V0AbilityTuningDerived.from(abilityTuning, tickHz: tickHz),
       _combat = V0CombatTuningDerived.from(combatTuning, tickHz: tickHz),
       _flyingEnemyTuning = V0FlyingEnemyTuningDerived.from(
         flyingEnemyTuning,
         tickHz: tickHz,
       ),
       _groundEnemyTuning = V0GroundEnemyTuningDerived.from(
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
       _baseStaticWorldGeometry = staticWorldGeometry,
       _scoreTuning = scoreTuning,
       _trackTuning = trackTuning {
    _world = EcsWorld(seed: seed);
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
    );
    _cameraTuning = V0CameraTuningDerived.from(
      cameraTuning,
      movement: _movement,
    );
    _camera = V0AutoscrollCamera(
      viewWidth: v0VirtualWidth.toDouble(),
      tuning: _cameraTuning,
      initial: V0CameraState(
        centerX: v0VirtualWidth * 0.5,
        targetX: v0VirtualWidth * 0.5,
        speedX: 0.0,
      ),
    );

    _setStaticWorldGeometry(_baseStaticWorldGeometry);

    final spawnX = 400.0;
    final playerArchetype = PlayerCatalogDerived.from(
      _playerCatalog,
      movement: _movement,
      resources: _resourceTuning,
    ).archetype;
    final playerCollider = playerArchetype.collider;
    final spawnY =
        (_staticWorldGeometry.groundPlane?.topY ?? v0GroundTopY.toDouble()) -
        (playerCollider.offsetY + playerCollider.halfY);
    _player = _world.createPlayer(
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

    // Milestone 12: stream deterministic chunks (static solids + enemy spawns).
    // Track streaming is controlled by `trackTuning.enabled`. When enabled, the
    // streamed solids are merged on top of the provided base geometry.
    if (_trackTuning.enabled) {
      final groundTopY =
          _staticWorldGeometry.groundPlane?.topY ?? v0GroundTopY.toDouble();
      _trackStreamer = V0TrackStreamer(
        seed: seed,
        tuning: _trackTuning,
        groundTopY: groundTopY,
      );
      _trackStreamerStep();
    }
  }

  EntityId _spawnFlyingEnemy({
    required double spawnX,
    required double groundTopY,
  }) {
    // Enemy spawn stats come from a centralized catalog so these hardcoded spawns
    // don't diverge from future deterministic spawning rules.
    final archetype = _enemyCatalog.get(EnemyId.flyingEnemy);
    final flyingEnemy = _world.createEnemy(
      enemyId: EnemyId.flyingEnemy,
      posX: spawnX,
      posY: groundTopY - _flyingEnemyTuning.base.flyingEnemyHoverOffsetY,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      body: archetype.body,
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
    );

    // Avoid immediate spawn-tick casting (keeps early-game tests stable).
    _world.cooldown.castCooldownTicksLeft[_world.cooldown.indexOf(
          flyingEnemy,
        )] =
        _flyingEnemyTuning.flyingEnemyCastCooldownTicks;

    return flyingEnemy;
  }

  EntityId _spawnGroundEnemy({
    required double spawnX,
    required double groundTopY,
  }) {
    final archetype = _enemyCatalog.get(EnemyId.groundEnemy);

    // GroundEnemy uses the archetype, but clamps should stay aligned with the
    // current movement tuning.
    return _world.createEnemy(
      enemyId: EnemyId.groundEnemy,
      posX: spawnX,
      posY: groundTopY - archetype.collider.halfY,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      body: BodyDef(
        enabled: archetype.body.enabled,
        isKinematic: archetype.body.isKinematic,
        useGravity: archetype.body.useGravity,
        ignoreCeilings: archetype.body.ignoreCeilings,
        topOnlyGround: archetype.body.topOnlyGround,
        gravityScale: archetype.body.gravityScale,
        maxVelX: _movement.base.maxVelX,
        maxVelY: _movement.base.maxVelY,
        sideMask: archetype.body.sideMask,
      ),
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
    );
  }

  /// Seed used for deterministic generation/RNG.
  final int seed;

  /// Fixed simulation tick frequency.
  final int tickHz;

  /// Base static world geometry for this run/session (hand-authored seed state).
  final StaticWorldGeometry _baseStaticWorldGeometry;

  /// Current static world geometry (base + any streamed chunk solids).
  StaticWorldGeometry get staticWorldGeometry => _staticWorldGeometry;
  late StaticWorldGeometry _staticWorldGeometry;
  late StaticWorldGeometryIndex _staticWorldIndex;
  late List<StaticSolidSnapshot> _staticSolidsSnapshot;

  final V0MovementTuningDerived _movement;
  final V0PhysicsTuning _physicsTuning;
  final V0ResourceTuning _resourceTuning;
  final V0AbilityTuningDerived _abilities;
  final V0CombatTuningDerived _combat;
  final V0FlyingEnemyTuningDerived _flyingEnemyTuning;
  final V0GroundEnemyTuningDerived _groundEnemyTuning;
  final V0NavigationTuning _navigationTuning;
  final V0SpatialGridTuning _spatialGridTuning;
  late final V0CameraTuningDerived _cameraTuning;
  final V0ScoreTuning _scoreTuning;
  final V0TrackTuning _trackTuning;
  final SpellCatalog _spells;
  final ProjectileCatalogDerived _projectiles;
  final EnemyCatalog _enemyCatalog;
  final PlayerCatalog _playerCatalog;
  late final SurfaceGraphBuilder _surfaceGraphBuilder;
  late final JumpReachabilityTemplate _groundEnemyJumpTemplate;
  int _surfaceGraphVersion = 0;

  V0TrackStreamer? _trackStreamer;

  late final EcsWorld _world;
  late final PlayerMovementSystem _movementSystem;
  late final CollisionSystem _collisionSystem;
  late final CooldownSystem _cooldownSystem;
  late final GravitySystem _gravitySystem;
  late final ProjectileSystem _projectileSystem;
  late final ProjectileHitSystem _projectileHitSystem;
  late final BroadphaseGrid _broadphaseGrid;
  late final HitboxFollowOwnerSystem _hitboxFollowOwnerSystem;
  late final LifetimeSystem _lifetimeSystem;
  late final InvulnerabilitySystem _invulnerabilitySystem;
  late final DamageSystem _damageSystem;
  late final HealthDespawnSystem _healthDespawnSystem;
  late final EnemySystem _enemySystem;
  late final SurfacePathfinder _surfacePathfinder;
  late final SurfaceNavigator _surfaceNavigator;
  late final PlayerMeleeSystem _meleeSystem;
  late final MeleeAttackSystem _meleeAttackSystem;
  late final HitboxDamageSystem _hitboxDamageSystem;
  late final ResourceRegenSystem _resourceRegenSystem;
  late final PlayerCastSystem _castSystem;
  late final SpellCastSystem _spellCastSystem;
  late final EntityId _player;
  late final V0AutoscrollCamera _camera;

  final List<GameEvent> _events = <GameEvent>[];
  final List<EnemyId> _killedEnemiesScratch = <EnemyId>[];

  /// Current simulation tick.
  int tick = 0;

  /// Whether simulation should advance.
  bool paused = false;

  /// Whether the run has ended (simulation is frozen).
  bool gameOver = false;

  /// Run progression metric (placeholder).
  double distance = 0;

  /// Run score (authoritative).
  int score = 0;

  /// Collected coins (placeholder for V0).
  int coins = 0;

  int _timeScoreAcc = 0;

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

  /// Applies all commands scheduled for the current tick.
  ///
  /// In the final architecture, commands are the only mechanism for the UI to
  /// influence the simulation.
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
          break;
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

  /// Advances the simulation by exactly one fixed tick.
  void stepOneTick() {
    if (paused || gameOver) return;

    tick += 1;

    _trackStreamerStep();

    _cooldownSystem.step(_world);
    _invulnerabilitySystem.step(_world);

    final groundTopY =
        staticWorldGeometry.groundPlane?.topY ?? v0GroundTopY.toDouble();
    _enemySystem.stepSteering(
      _world,
      player: _player,
      groundTopY: groundTopY,
      dtSeconds: _movement.dtSeconds,
    );

    _movementSystem.step(_world, _movement, resources: _resourceTuning);
    _gravitySystem.step(_world, _movement, physics: _physicsTuning);
    _collisionSystem.step(_world, _movement, staticWorld: _staticWorldIndex);

    distance += max(0.0, playerVelX) * _movement.dtSeconds;

    _camera.updateTick(dtSeconds: _movement.dtSeconds, playerX: playerPosX);
    if (_checkFellBehindCamera()) {
      gameOver = true;
      paused = true;
      _events.add(
        RunEndedEvent(
          tick: tick,
          distance: distance,
          reason: RunEndReason.fellBehindCamera,
        ),
      );
      return;
    }

    _applyTimeScore();

    // Rebuild broadphase after movement/collision so damageable target positions
    // are final for the tick before any hit queries run.
    _broadphaseGrid.rebuild(_world);

    // Move already-existing projectiles before spawning new ones so newly spawned
    // projectiles remain at their spawn positions until the next tick.
    _projectileSystem.step(_world, _movement);

    // IMPORTANT (determinism): intent writers run in a fixed order (enemy first,
    // then player), and shared execution consumes only intents stamped for this tick.
    _enemySystem.stepAttacks(_world, player: _player, currentTick: tick);
    _castSystem.step(_world, player: _player, currentTick: tick);
    _meleeSystem.step(_world, player: _player, currentTick: tick);

    // Execute intents after all writers have run.
    _spellCastSystem.step(_world, currentTick: tick);
    _meleeAttackSystem.step(_world, currentTick: tick);

    // Position hitboxes from their owner + offset so spawn-time positions are
    // consistent and don't drift (single source of truth is `HitboxStore.offset`).
    _hitboxFollowOwnerSystem.step(_world);

    // Resolve hits after all attacks have been spawned so both newly spawned
    // projectiles and hitboxes can hit on their spawn tick.
    _projectileHitSystem.step(_world, _damageSystem.queue, _broadphaseGrid);
    _hitboxDamageSystem.step(_world, _damageSystem.queue, _broadphaseGrid);
    _damageSystem.step(_world);
    _killedEnemiesScratch.clear();
    _healthDespawnSystem.step(
      _world,
      player: _player,
      outEnemiesKilled: _killedEnemiesScratch,
    );
    if (_killedEnemiesScratch.isNotEmpty) {
      _applyEnemyKillScores(_killedEnemiesScratch);
    }
    _resourceRegenSystem.step(_world, dtSeconds: _movement.dtSeconds);

    // Cleanup last so effect entities get their full last tick to act.
    _lifetimeSystem.step(_world);
  }

  void _applyTimeScore() {
    final perSecond = _scoreTuning.timeScorePerSecond;
    if (perSecond <= 0) return;

    _timeScoreAcc += perSecond;
    if (_timeScoreAcc < tickHz) return;

    final add = _timeScoreAcc ~/ tickHz;
    if (add <= 0) return;
    score += add;
    _timeScoreAcc -= add * tickHz;
  }

  void _applyEnemyKillScores(List<EnemyId> killedEnemies) {
    for (final enemyId in killedEnemies) {
      switch (enemyId) {
        case EnemyId.groundEnemy:
          score += _scoreTuning.groundEnemyKillScore;
        case EnemyId.flyingEnemy:
          score += _scoreTuning.flyingEnemyKillScore;
      }
    }
  }

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

  void _trackStreamerStep() {
    final streamer = _trackStreamer;
    if (streamer == null) return;

    final changed = streamer.step(
      cameraLeft: _camera.left(),
      cameraRight: _camera.right(),
      spawnEnemy: (enemyId, x) {
        final groundTopY =
            _staticWorldGeometry.groundPlane?.topY ?? v0GroundTopY.toDouble();
        switch (enemyId) {
          case EnemyId.flyingEnemy:
            _spawnFlyingEnemy(spawnX: x, groundTopY: groundTopY);
          case EnemyId.groundEnemy:
            _spawnGroundEnemy(spawnX: x, groundTopY: groundTopY);
        }
      },
    );

    if (!changed) return;

    // Rebuild collision index only when geometry changes (spawn/cull).
    final combinedSolids = <StaticSolid>[
      ..._baseStaticWorldGeometry.solids,
      ...streamer.dynamicSolids,
    ];
    _setStaticWorldGeometry(
      StaticWorldGeometry(
        groundPlane: _baseStaticWorldGeometry.groundPlane,
        solids: List<StaticSolid>.unmodifiable(combinedSolids),
      ),
    );
  }

  void _setStaticWorldGeometry(StaticWorldGeometry geometry) {
    _staticWorldGeometry = geometry;
    _staticWorldIndex = StaticWorldGeometryIndex.from(geometry);
    _staticSolidsSnapshot = _buildStaticSolidsSnapshot(geometry);
    _rebuildSurfaceGraph();
  }

  void _rebuildSurfaceGraph() {
    _surfaceGraphVersion += 1;
    final result = _surfaceGraphBuilder.build(
      geometry: _staticWorldGeometry,
      jumpTemplate: _groundEnemyJumpTemplate,
    );
    _enemySystem.setSurfaceGraph(
      graph: result.graph,
      spatialIndex: result.spatialIndex,
      graphVersion: _surfaceGraphVersion,
    );
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

  static List<StaticSolidSnapshot> _buildStaticSolidsSnapshot(
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

  List<GameEvent> drainEvents() {
    if (_events.isEmpty) return const <GameEvent>[];
    final drained = List<GameEvent>.unmodifiable(_events);
    _events.clear();
    return drained;
  }

  /// Builds an immutable snapshot for render/UI consumption.
  GameStateSnapshot buildSnapshot() {
    final tuning = _movement.base;
    final mi = _world.movement.indexOf(_player);
    final dashing = _world.movement.dashTicksLeft[mi] > 0;
    final onGround =
        _world.collision.grounded[_world.collision.indexOf(_player)];
    final hi = _world.health.indexOf(_player);
    final mai = _world.mana.indexOf(_player);
    final si = _world.stamina.indexOf(_player);
    final ci = _world.cooldown.indexOf(_player);

    final stamina = _world.stamina.stamina[si];
    final mana = _world.mana.mana[mai];
    final projectileManaCost = _spells.get(SpellId.iceBolt).stats.manaCost;

    final canAffordJump = stamina >= _resourceTuning.jumpStaminaCost;
    final canAffordDash = stamina >= _resourceTuning.dashStaminaCost;
    final canAffordMelee = stamina >= _abilities.base.meleeStaminaCost;
    final canAffordProjectile = mana >= projectileManaCost;

    final dashCooldownTicksLeft = _world.movement.dashCooldownTicksLeft[mi];
    final meleeCooldownTicksLeft = _world.cooldown.meleeCooldownTicksLeft[ci];
    final projectileCooldownTicksLeft =
        _world.cooldown.castCooldownTicksLeft[ci];

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
        id: _player,
        kind: EntityKind.player,
        pos: playerPos,
        vel: playerVel,
        size: Vec2(tuning.playerRadius * 2, tuning.playerRadius * 2),
        facing: playerFacing,
        anim: anim,
        grounded: onGround,
      ),
    ];

    final projectileStore = _world.projectile;
    for (var pi = 0; pi < projectileStore.denseEntities.length; pi += 1) {
      final e = projectileStore.denseEntities[pi];
      if (!(_world.transform.has(e))) continue;
      final ti = _world.transform.indexOf(e);

      final projectileId = projectileStore.projectileId[pi];
      final proj = _projectiles.base.get(projectileId);
      final colliderSize = Vec2(proj.colliderSizeX, proj.colliderSizeY);

      final dirX = projectileStore.dirX[pi];
      final dirY = projectileStore.dirY[pi];
      final facing = dirX >= 0 ? Facing.right : Facing.left;
      final rotationRad = atan2(dirY, dirX);

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.projectile,
          pos: Vec2(_world.transform.posX[ti], _world.transform.posY[ti]),
          vel: Vec2(_world.transform.velX[ti], _world.transform.velY[ti]),
          size: colliderSize,
          projectileId: projectileId,
          facing: facing,
          rotationRad: rotationRad,
          anim: AnimKey.idle,
          grounded: false,
        ),
      );
    }

    final hitboxes = _world.hitbox;
    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final e = hitboxes.denseEntities[hi];
      if (!(_world.transform.has(e))) continue;
      final ti = _world.transform.indexOf(e);

      final size = Vec2(hitboxes.halfX[hi] * 2, hitboxes.halfY[hi] * 2);
      final dirX = hitboxes.dirX[hi];
      final dirY = hitboxes.dirY[hi];
      final facing = dirX >= 0 ? Facing.right : Facing.left;
      final rotationRad = atan2(dirY, dirX);

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.trigger,
          pos: Vec2(_world.transform.posX[ti], _world.transform.posY[ti]),
          size: size,
          facing: facing,
          rotationRad: rotationRad,
          anim: AnimKey.hit,
          grounded: false,
        ),
      );
    }

    final enemies = _world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      if (!(_world.transform.has(e))) continue;
      final ti = _world.transform.indexOf(e);

      Vec2? size;
      if (_world.colliderAabb.has(e)) {
        final aabbi = _world.colliderAabb.indexOf(e);
        size = Vec2(
          _world.colliderAabb.halfX[aabbi] * 2,
          _world.colliderAabb.halfY[aabbi] * 2,
        );
      }

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.enemy,
          pos: Vec2(_world.transform.posX[ti], _world.transform.posY[ti]),
          vel: Vec2(_world.transform.velX[ti], _world.transform.velY[ti]),
          size: size,
          facing: enemies.facing[ei],
          anim: AnimKey.idle,
          grounded: _world.collision.has(e)
              ? _world.collision.grounded[_world.collision.indexOf(e)]
              : false,
        ),
      );
    }

    return GameStateSnapshot(
      tick: tick,
      seed: seed,
      distance: distance,
      paused: paused,
      gameOver: gameOver,
      cameraCenterX: _camera.state.centerX,
      cameraCenterY: v0CameraFixedY,
      hud: PlayerHudSnapshot(
        hp: _world.health.hp[hi],
        hpMax: _world.health.hpMax[hi],
        mana: mana,
        manaMax: _world.mana.manaMax[mai],
        stamina: stamina,
        staminaMax: _world.stamina.staminaMax[si],
        canAffordJump: canAffordJump,
        canAffordDash: canAffordDash,
        canAffordMelee: canAffordMelee,
        canAffordProjectile: canAffordProjectile,
        dashCooldownTicksLeft: dashCooldownTicksLeft,
        dashCooldownTicksTotal: _movement.dashCooldownTicks,
        meleeCooldownTicksLeft: meleeCooldownTicksLeft,
        meleeCooldownTicksTotal: _abilities.meleeCooldownTicks,
        projectileCooldownTicksLeft: projectileCooldownTicksLeft,
        projectileCooldownTicksTotal: _abilities.castCooldownTicks,
        score: score,
        coins: coins,
      ),
      entities: entities,
      staticSolids: _staticSolidsSnapshot,
    );
  }
}
