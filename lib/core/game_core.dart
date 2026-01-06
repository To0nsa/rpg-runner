// Authoritative, deterministic simulation layer (pure Dart).
//
// This is the "truth" of the game: it applies tick-stamped commands, advances
// the simulation by fixed ticks, and produces snapshots/events for the
// renderer/UI. It must not import Flutter or Flame.
import 'dart:math';

import 'commands/command.dart';
import 'camera/autoscroll_camera.dart';
import 'collision/static_world_geometry_index.dart';
import 'contracts/render_contract.dart';
import 'ecs/entity_id.dart';
import 'ecs/entity_factory.dart';
import 'ecs/hit/aabb_hit_utils.dart';
import 'ecs/spatial/broadphase_grid.dart';
import 'ecs/spatial/grid_index_2d.dart';
import 'ecs/systems/collision_system.dart';
import 'ecs/systems/collectible_system.dart';
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
import 'ecs/systems/restoration_item_system.dart';
import 'ecs/stores/body_store.dart';
import 'ecs/stores/collider_aabb_store.dart';
import 'ecs/stores/collectible_store.dart';
import 'ecs/stores/restoration_item_store.dart';
import 'ecs/world.dart';
import 'enemies/enemy_catalog.dart';
import 'enemies/enemy_id.dart';
import 'events/game_event.dart';
import 'math/vec2.dart';
import 'navigation/jump_template.dart';
import 'navigation/nav_tolerances.dart';
import 'navigation/surface_graph.dart';
import 'navigation/surface_graph_builder.dart';
import 'navigation/surface_navigator.dart';
import 'navigation/surface_pathfinder.dart';
import 'navigation/surface_spatial_index.dart';
import 'players/player_catalog.dart';
import 'snapshots/enums.dart';
import 'snapshots/entity_render_snapshot.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshots/player_hud_snapshot.dart';
import 'snapshots/static_ground_gap_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
import 'projectiles/projectile_catalog.dart';
import 'spells/spell_catalog.dart';
import 'spells/spell_id.dart';
import 'track/track_streamer.dart';
import 'tuning/ability_tuning.dart';
import 'tuning/combat_tuning.dart';
import 'tuning/flying_enemy_tuning.dart';
import 'tuning/ground_enemy_tuning.dart';
import 'tuning/movement_tuning.dart';
import 'tuning/navigation_tuning.dart';
import 'tuning/physics_tuning.dart';
import 'tuning/resource_tuning.dart';
import 'tuning/score_tuning.dart';
import 'tuning/camera_tuning.dart';
import 'tuning/collectible_tuning.dart';
import 'tuning/restoration_item_tuning.dart';
import 'tuning/spatial_grid_tuning.dart';
import 'tuning/track_tuning.dart';
import 'util/deterministic_rng.dart';
import 'util/tick_math.dart';

/// Minimal placeholder `GameCore` used to validate architecture wiring.
///
/// This will be replaced by the full ECS/systems implementation in later
/// milestones. The core invariants remain: fixed ticks, command-driven input,
/// deterministic state updates, snapshot output.
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
    RestorationItemTuning restorationItemTuning =
        const RestorationItemTuning(),
    ScoreTuning scoreTuning = const ScoreTuning(),
    SpellCatalog spellCatalog = const SpellCatalog(),
    ProjectileCatalog projectileCatalog = const ProjectileCatalog(),
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
    PlayerCatalog playerCatalog = const PlayerCatalog(),
    StaticWorldGeometry staticWorldGeometry = const StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: groundTopY * 1.0),
    ),
  }) : _movement = MovementTuningDerived.from(movementTuning, tickHz: tickHz),
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
       _baseStaticWorldGeometry = staticWorldGeometry,
       _scoreTuning = scoreTuning,
       _trackTuning = trackTuning,
       _collectibleTuning = collectibleTuning,
       _restorationItemTuning = restorationItemTuning {
    _world = EcsWorld(seed: seed);
    _entityFactory = EntityFactory(_world);
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
    );
    _cameraTuning = CameraTuningDerived.from(
      cameraTuning,
      movement: _movement,
    );
    _camera = AutoscrollCamera(
      viewWidth: virtualWidth.toDouble(),
      tuning: _cameraTuning,
      initial: CameraState(
        centerX: virtualWidth * 0.5,
        targetX: virtualWidth * 0.5,
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
        (_staticWorldGeometry.groundPlane?.topY ?? groundTopY.toDouble()) -
        (playerCollider.offsetY + playerCollider.halfY);
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

    // Milestone 12: stream deterministic chunks (static solids + enemy spawns).
    // Track streaming is controlled by `trackTuning.enabled`. When enabled, the
    // streamed solids are merged on top of the provided base geometry.
    if (_trackTuning.enabled) {
      final effectiveGroundTopY =
          _staticWorldGeometry.groundPlane?.topY ?? groundTopY.toDouble();
      _trackStreamer = TrackStreamer(
        seed: seed,
        tuning: _trackTuning,
        groundTopY: effectiveGroundTopY,
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
    final flyingEnemy = _entityFactory.createEnemy(
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
    return _entityFactory.createEnemy(
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

  EntityId _spawnCollectibleAt(double x, double y) {
    final half = _collectibleTuning.collectibleSize * 0.5;
    final entity = _world.createEntity();
    _world.transform.add(entity, posX: x, posY: y, velX: 0.0, velY: 0.0);
    _world.colliderAabb.add(
      entity,
      ColliderAabbDef(halfX: half, halfY: half),
    );
    _world.collectible.add(
      entity,
      CollectibleDef(value: _collectibleTuning.valuePerCollectible),
    );
    return entity;
  }

  EntityId _spawnRestorationItemAt(
    double x,
    double y,
    RestorationStat stat,
  ) {
    final half = _restorationItemTuning.itemSize * 0.5;
    final entity = _world.createEntity();
    _world.transform.add(entity, posX: x, posY: y, velX: 0.0, velY: 0.0);
    _world.colliderAabb.add(
      entity,
      ColliderAabbDef(halfX: half, halfY: half),
    );
    _world.restorationItem.add(
      entity,
      RestorationItemDef(stat: stat),
    );
    return entity;
  }

  void _spawnCollectiblesForChunk(int chunkIndex, double chunkStartX) {
    final tuning = _collectibleTuning;
    if (!tuning.enabled) return;
    if (chunkIndex < tuning.spawnStartChunkIndex) return;
    if (tuning.maxPerChunk <= 0) return;

    final graph = _surfaceGraph;
    final spatialIndex = _surfaceSpatialIndex;
    if (graph == null || spatialIndex == null || graph.surfaces.isEmpty) {
      return;
    }

    final minX = chunkStartX + tuning.chunkEdgeMarginX;
    final maxX = chunkStartX + _trackTuning.chunkWidth - tuning.chunkEdgeMarginX;
    if (maxX <= minX) return;

    var rngState = seedFrom(seed, chunkIndex ^ 0xC011EC7);
    rngState = nextUint32(rngState);
    final countRange = tuning.maxPerChunk - tuning.minPerChunk + 1;
    final targetCount = tuning.minPerChunk + (rngState % countRange);
    if (targetCount <= 0) return;

    _collectibleSpawnXs.clear();
    final halfSize = tuning.collectibleSize * 0.5;
    final maxAttempts = tuning.maxAttemptsPerChunk;
    for (var attempt = 0;
        attempt < maxAttempts && _collectibleSpawnXs.length < targetCount;
        attempt += 1) {
      rngState = nextUint32(rngState);
      var x = rangeDouble(rngState, minX, maxX);
      x = _snapToGrid(x, _trackTuning.gridSnap);
      if (x < minX || x > maxX) continue;

      if (tuning.minSpacingX > 0.0) {
        var spaced = true;
        for (final prevX in _collectibleSpawnXs) {
          if ((prevX - x).abs() < tuning.minSpacingX) {
            spaced = false;
            break;
          }
        }
        if (!spaced) continue;
      }

      final surfaceY = _highestSurfaceYAtX(x);
      if (surfaceY == null) continue;
      final centerY = surfaceY - tuning.surfaceClearanceY - halfSize;
      if (_overlapsAnySolid(
        centerX: x,
        centerY: centerY,
        halfSize: halfSize,
        margin: tuning.noSpawnMargin,
      )) {
        continue;
      }

      _spawnCollectibleAt(x, centerY);
      _collectibleSpawnXs.add(x);
    }
  }

  void _spawnRestorationItemForChunk(int chunkIndex, double chunkStartX) {
    final tuning = _restorationItemTuning;
    if (!tuning.enabled) return;
    if (chunkIndex < tuning.spawnStartChunkIndex) return;
    if (tuning.spawnEveryChunks <= 0) return;

    final phase = seedFrom(seed, 0xA17E5A7) % tuning.spawnEveryChunks;
    if ((chunkIndex - phase) % tuning.spawnEveryChunks != 0) return;

    final graph = _surfaceGraph;
    final spatialIndex = _surfaceSpatialIndex;
    if (graph == null || spatialIndex == null || graph.surfaces.isEmpty) {
      return;
    }

    final minX = chunkStartX + tuning.chunkEdgeMarginX;
    final maxX = chunkStartX + _trackTuning.chunkWidth - tuning.chunkEdgeMarginX;
    if (maxX <= minX) return;

    final stat = _lowestResourceStat();
    var rngState = seedFrom(seed, chunkIndex ^ 0xA57A11);
    final halfSize = tuning.itemSize * 0.5;
    for (var attempt = 0; attempt < tuning.maxAttemptsPerSpawn; attempt += 1) {
      rngState = nextUint32(rngState);
      var x = rangeDouble(rngState, minX, maxX);
      x = _snapToGrid(x, _trackTuning.gridSnap);
      if (x < minX || x > maxX) continue;

      final surfaceY = _highestSurfaceYAtX(x);
      if (surfaceY == null) continue;
      final centerY = surfaceY - tuning.surfaceClearanceY - halfSize;
      if (_overlapsAnySolid(
        centerX: x,
        centerY: centerY,
        halfSize: halfSize,
        margin: tuning.noSpawnMargin,
      )) {
        continue;
      }
      if (_overlapsAnyCollectible(
        centerX: x,
        centerY: centerY,
        halfSize: halfSize,
        margin: tuning.noSpawnMargin,
      )) {
        continue;
      }

      _spawnRestorationItemAt(x, centerY, stat);
      return;
    }
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
  late List<StaticGroundGapSnapshot> _staticGroundGapsSnapshot;

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
  late final SurfaceGraphBuilder _surfaceGraphBuilder;
  late final JumpReachabilityTemplate _groundEnemyJumpTemplate;
  int _surfaceGraphVersion = 0;

  TrackStreamer? _trackStreamer;

  late final EcsWorld _world;
  late final EntityFactory _entityFactory;
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
  late final AutoscrollCamera _camera;

  final List<GameEvent> _events = <GameEvent>[];
  final List<EnemyId> _killedEnemiesScratch = <EnemyId>[];
  final List<int> _enemyKillCounts =
      List<int>.filled(EnemyId.values.length, 0);
  final List<int> _surfaceQueryCandidates = <int>[];
  final List<double> _collectibleSpawnXs = <double>[];

  SurfaceGraph? _surfaceGraph;
  SurfaceSpatialIndex? _surfaceSpatialIndex;
  double _surfaceMinY = 0.0;
  double _surfaceMaxY = 0.0;

  /// Current simulation tick.
  int tick = 0;

  /// Whether simulation should advance.
  bool paused = false;

  /// Whether the run has ended (simulation is frozen).
  bool gameOver = false;

  ScoreTuning get scoreTuning => _scoreTuning;

  /// Run progression metric (placeholder).
  double distance = 0;

  /// Collected collectibles (placeholder for V0).
  int collectibles = 0;

  /// Collectible score value (not yet applied to run score).
  int collectibleScore = 0;

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
    _collisionSystem.step(_world, _movement, staticWorld: _staticWorldIndex);

    distance += max(0.0, playerVelX) * _movement.dtSeconds;

    if (_checkFellIntoGap(effectiveGroundTopY)) {
      gameOver = true;
      paused = true;
      _events.add(
        RunEndedEvent(
          tick: tick,
          distance: distance,
          reason: RunEndReason.fellIntoGap,
          stats: _buildRunEndStats(),
        ),
      );
      return;
    }

    _camera.updateTick(dtSeconds: _movement.dtSeconds, playerX: playerPosX);
    if (_checkFellBehindCamera()) {
      gameOver = true;
      paused = true;
      _events.add(
        RunEndedEvent(
          tick: tick,
          distance: distance,
          reason: RunEndReason.fellBehindCamera,
          stats: _buildRunEndStats(),
        ),
      );
      return;
    }

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
    _damageSystem.step(_world, currentTick: tick);
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
      final deathInfo = _buildDeathInfo();
      gameOver = true;
      paused = true;
      _events.add(
        RunEndedEvent(
          tick: tick,
          distance: distance,
          reason: RunEndReason.playerDied,
          stats: _buildRunEndStats(),
          deathInfo: deathInfo,
        ),
      );
      return;
    }
    _resourceRegenSystem.step(_world, dtSeconds: _movement.dtSeconds);

    // Cleanup last so effect entities get their full last tick to act.
    _lifetimeSystem.step(_world);
  }

  void _recordEnemyKills(List<EnemyId> killedEnemies) {
    for (final enemyId in killedEnemies) {
      final index = enemyId.index;
      if (index < 0 || index >= _enemyKillCounts.length) continue;
      _enemyKillCounts[index] += 1;
    }
  }

  RunEndStats _buildRunEndStats() => RunEndStats(
    collectibles: collectibles,
    collectibleScore: collectibleScore,
    enemyKillCounts: List<int>.unmodifiable(_enemyKillCounts),
  );

  void giveUp() {
    if (gameOver) return;
    gameOver = true;
    paused = true;
    _events.add(
      RunEndedEvent(
        tick: tick,
        distance: distance,
        reason: RunEndReason.gaveUp,
        stats: _buildRunEndStats(),
      ),
    );
  }

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
    final bottomY =
        _world.transform.posY[ti] +
        _world.colliderAabb.offsetY[ai] +
        _world.colliderAabb.halfY[ai];
    return bottomY > groundTopY + gapKillOffsetY;
  }

  void _trackStreamerStep() {
    final streamer = _trackStreamer;
    if (streamer == null) return;

    final result = streamer.step(
      cameraLeft: _camera.left(),
      cameraRight: _camera.right(),
      spawnEnemy: (enemyId, x) {
        final effectiveGroundTopY =
          _staticWorldGeometry.groundPlane?.topY ?? groundTopY.toDouble();
        switch (enemyId) {
          case EnemyId.flyingEnemy:
            _spawnFlyingEnemy(spawnX: x, groundTopY: effectiveGroundTopY);
          case EnemyId.groundEnemy:
            _spawnGroundEnemy(spawnX: x, groundTopY: effectiveGroundTopY);
        }
      },
    );

    if (!result.changed) return;

    // Rebuild collision index only when geometry changes (spawn/cull).
    final combinedSolids = <StaticSolid>[
      ..._baseStaticWorldGeometry.solids,
      ...streamer.dynamicSolids,
    ];
    final combinedSegments = <StaticGroundSegment>[
      ..._baseStaticWorldGeometry.groundSegments,
      ...streamer.dynamicGroundSegments,
    ];
    final combinedGaps = <StaticGroundGap>[
      ..._baseStaticWorldGeometry.groundGaps,
      ...streamer.dynamicGroundGaps,
    ];
    _setStaticWorldGeometry(
      StaticWorldGeometry(
        groundPlane: _baseStaticWorldGeometry.groundPlane,
        groundSegments: List<StaticGroundSegment>.unmodifiable(
          combinedSegments,
        ),
        solids: List<StaticSolid>.unmodifiable(combinedSolids),
        groundGaps: List<StaticGroundGap>.unmodifiable(combinedGaps),
      ),
    );

    if (result.spawnedChunks.isNotEmpty) {
      for (final chunk in result.spawnedChunks) {
        if (_collectibleTuning.enabled) {
          _spawnCollectiblesForChunk(chunk.index, chunk.startX);
        }
        if (_restorationItemTuning.enabled) {
          _spawnRestorationItemForChunk(chunk.index, chunk.startX);
        }
      }
    }
  }

  void _setStaticWorldGeometry(StaticWorldGeometry geometry) {
    _staticWorldGeometry = geometry;
    _staticWorldIndex = StaticWorldGeometryIndex.from(geometry);
    _staticSolidsSnapshot = _buildStaticSolidsSnapshot(geometry);
    _staticGroundGapsSnapshot = _buildGroundGapsSnapshot(geometry);
    _rebuildSurfaceGraph();
  }

  void _rebuildSurfaceGraph() {
    _surfaceGraphVersion += 1;
    final result = _surfaceGraphBuilder.build(
      geometry: _staticWorldGeometry,
      jumpTemplate: _groundEnemyJumpTemplate,
    );
    _surfaceGraph = result.graph;
    _surfaceSpatialIndex = result.spatialIndex;
    _surfaceMinY = 0.0;
    _surfaceMaxY = 0.0;
    if (result.graph.surfaces.isNotEmpty) {
      var minY = result.graph.surfaces.first.yTop;
      var maxY = minY;
      for (var i = 1; i < result.graph.surfaces.length; i += 1) {
        final y = result.graph.surfaces[i].yTop;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
      _surfaceMinY = minY;
      _surfaceMaxY = maxY;
    }
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

  double _snapToGrid(double x, double grid) {
    if (grid <= 0) return x;
    return (x / grid).roundToDouble() * grid;
  }

  double? _highestSurfaceYAtX(double x) {
    final graph = _surfaceGraph;
    final spatialIndex = _surfaceSpatialIndex;
    if (graph == null || spatialIndex == null || graph.surfaces.isEmpty) {
      return null;
    }

    final minY = _surfaceMinY - navSpatialEps;
    final maxY = _surfaceMaxY + navSpatialEps;
    _surfaceQueryCandidates.clear();
    spatialIndex.queryAabb(
      minX: x - navSpatialEps,
      minY: minY,
      maxX: x + navSpatialEps,
      maxY: maxY,
      outSurfaceIndices: _surfaceQueryCandidates,
    );

    double? bestY;
    int? bestId;
    for (final i in _surfaceQueryCandidates) {
      final s = graph.surfaces[i];
      if (x < s.xMin - navGeomEps || x > s.xMax + navGeomEps) continue;
      if (bestY == null || s.yTop < bestY - navTieEps) {
        bestY = s.yTop;
        bestId = s.id;
      } else if ((s.yTop - bestY).abs() <= navTieEps && s.id < bestId!) {
        bestY = s.yTop;
        bestId = s.id;
      }
    }

    return bestY;
  }

  bool _overlapsAnySolid({
    required double centerX,
    required double centerY,
    required double halfSize,
    required double margin,
  }) {
    if (_staticWorldGeometry.solids.isEmpty) return false;

    final minX = centerX - halfSize - margin;
    final maxX = centerX + halfSize + margin;
    final minY = centerY - halfSize - margin;
    final maxY = centerY + halfSize + margin;

    for (final solid in _staticWorldGeometry.solids) {
      final overlaps = aabbOverlapsMinMax(
        aMinX: minX,
        aMaxX: maxX,
        aMinY: minY,
        aMaxY: maxY,
        bMinX: solid.minX,
        bMaxX: solid.maxX,
        bMinY: solid.minY,
        bMaxY: solid.maxY,
      );
      if (overlaps) return true;
    }
    return false;
  }

  bool _overlapsAnyCollectible({
    required double centerX,
    required double centerY,
    required double halfSize,
    required double margin,
  }) {
    final collectibles = _world.collectible;
    if (collectibles.denseEntities.isEmpty) return false;

    final minX = centerX - halfSize - margin;
    final maxX = centerX + halfSize + margin;
    final minY = centerY - halfSize - margin;
    final maxY = centerY + halfSize + margin;

    for (var ci = 0; ci < collectibles.denseEntities.length; ci += 1) {
      final e = collectibles.denseEntities[ci];
      if (!(_world.transform.has(e) && _world.colliderAabb.has(e))) continue;
      final ti = _world.transform.indexOf(e);
      final ai = _world.colliderAabb.indexOf(e);
      final cx = _world.transform.posX[ti] + _world.colliderAabb.offsetX[ai];
      final cy = _world.transform.posY[ti] + _world.colliderAabb.offsetY[ai];
      final overlaps = aabbOverlapsMinMax(
        aMinX: minX,
        aMaxX: maxX,
        aMinY: minY,
        aMaxY: maxY,
        bMinX: cx - _world.colliderAabb.halfX[ai],
        bMaxX: cx + _world.colliderAabb.halfX[ai],
        bMinY: cy - _world.colliderAabb.halfY[ai],
        bMaxY: cy + _world.colliderAabb.halfY[ai],
      );
      if (overlaps) return true;
    }

    return false;
  }

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

  bool _ratioLess(
    double valueA,
    double maxA,
    double valueB,
    double maxB,
  ) {
    if (maxA <= 0) return false;
    if (maxB <= 0) return true;
    return valueA * maxB < valueB * maxA;
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

  static List<StaticGroundGapSnapshot> _buildGroundGapsSnapshot(
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

    final collectiblesStore = _world.collectible;
    for (var ci = 0; ci < collectiblesStore.denseEntities.length; ci += 1) {
      final e = collectiblesStore.denseEntities[ci];
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
          kind: EntityKind.pickup,
          pos: Vec2(_world.transform.posX[ti], _world.transform.posY[ti]),
          size: size,
          facing: Facing.right,
          pickupVariant: PickupVariant.collectible,
          rotationRad: pi * 0.25,
          anim: AnimKey.idle,
          grounded: false,
        ),
      );
    }

    final restorationStore = _world.restorationItem;
    for (var ri = 0; ri < restorationStore.denseEntities.length; ri += 1) {
      final e = restorationStore.denseEntities[ri];
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
          pos: Vec2(_world.transform.posX[ti], _world.transform.posY[ti]),
          size: size,
          facing: Facing.right,
          pickupVariant: variant,
          rotationRad: pi * 0.25,
          anim: AnimKey.idle,
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
      cameraCenterY: cameraFixedY,
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
        collectibles: collectibles,
        collectibleScore: collectibleScore,
      ),
      entities: entities,
      staticSolids: _staticSolidsSnapshot,
      groundGaps: _staticGroundGapsSnapshot,
    );
  }
}
