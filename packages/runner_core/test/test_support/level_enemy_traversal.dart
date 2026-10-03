import 'dart:math' as math;

import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/enemy_engagement_system.dart';
import 'package:runner_core/ecs/systems/flying_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/terrain_enemy_navigation_system.dart';
import 'package:runner_core/ecs/systems/water_immersion_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/navigation/terrain_surface_navigator.dart';
import 'package:runner_core/navigation/terrain_surface_pathfinder.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:runner_core/navigation/utils/jump_template.dart';
import 'package:runner_core/navigation/utils/standability.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/connected_chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:test/test.dart';

const _tickHz = 60;

/// Registers real-motion pursuit checks; stationary enemies are not supported.
///
/// Omit [chunkCount] only for a non-looping authored assembly. All other routes
/// need an explicit finite horizon. Each seed shares immutable terrain between
/// actors, but every actor gets fresh ECS, navigation, and movement state.
void testLevelEnemyTraversal({
  required LevelId levelId,
  required List<int> seeds,
  required List<EnemyId> enemyIds,
  int? chunkCount,
}) {
  if (seeds.isEmpty || enemyIds.isEmpty) {
    throw ArgumentError('Traversal coverage needs seeds and enemy IDs.');
  }
  for (final seed in seeds) {
    group('${levelId.name} traversal seed=$seed', () {
      late LevelTraversalRoute route;
      setUpAll(() {
        route = LevelTraversalRoute.scheduled(
          level: LevelRegistry.byId(levelId),
          seed: seed,
          chunkCount: chunkCount,
        );
      });
      for (final enemyId in enemyIds) {
        test('${enemyId.name} reaches every chunk exit', () {
          final harness = EnemyTraversalHarness(route, enemyId);
          expect(harness.traverse(), isNull);
          expect(harness.enemyX, greaterThanOrEqualTo(harness.finishX));
          expect(
            harness.visitedChunks,
            containsAll(List.generate(route.keys.length, (index) => index)),
          );
        }, timeout: const Timeout(Duration(minutes: 5)));
      }
    });
  }
}

/// Finite terrain itinerary using the supplied level's tuning and chunk width.
/// Only the scheduled constructor proves production chunk composition; explicit
/// chunks are useful for seam regressions and positive/negative controls.
class LevelTraversalRoute {
  /// Captures the production selector through [chunkCount] chunks, or through
  /// the first complete non-looping assembly before its final section repeats.
  /// The next selected chunk supplies terrain for the chase target beyond the
  /// finish boundary; it is excluded from [keys] and the tested route length.
  factory LevelTraversalRoute.scheduled({
    required LevelDefinition level,
    required int seed,
    int? chunkCount,
    StagedTerrainCatalog? catalog,
  }) {
    final assembly = level.assembly;
    if (chunkCount != null && chunkCount <= 0) {
      throw ArgumentError.value(chunkCount, 'chunkCount', 'Must be positive.');
    }
    if (chunkCount == null && (assembly == null || assembly.loopSegments)) {
      throw ArgumentError(
        'Level ${level.identity.value} needs an explicit '
        'chunkCount for its endless/looping route.',
      );
    }
    final terrainCatalog = catalog ?? _generatedCatalog;
    final source = ConnectedChunkPatternSource.forLevel(
      level: level,
      catalog: terrainCatalog,
    );
    final keys = <String>[];
    if (chunkCount != null) {
      for (var index = 0; index < chunkCount; index++) {
        keys.add(
          source.explainSelection(seed: seed, chunkIndex: index).chunk.chunkKey,
        );
      }
    } else {
      final maxChunks = assembly!.segments.fold<int>(
        0,
        (count, segment) => count + segment.maxChunkCount,
      );
      var completedAssembly = false;
      for (var index = 0; index <= maxChunks; index++) {
        final selection = source.explainSelection(
          seed: seed,
          chunkIndex: index,
        );
        if (selection.assembly!.repeatsFinalSegment) {
          completedAssembly = true;
          break;
        }
        keys.add(selection.chunk.chunkKey);
      }
      if (!completedAssembly) {
        throw StateError(
          'Level ${level.identity.value} did not finish its '
          'assembly within $maxChunks chunks.',
        );
      }
    }
    if (level.firstChunkKey != null && keys.first != level.firstChunkKey) {
      throw StateError(
        'Selected route does not begin at ${level.firstChunkKey}.',
      );
    }
    return LevelTraversalRoute.chunks(
      level: level,
      seed: seed,
      chunkKeys: keys,
      continuationChunkKey: source
          .explainSelection(seed: seed, chunkIndex: keys.length)
          .chunk
          .chunkKey,
      catalog: terrainCatalog,
    );
  }

  /// Uses exact chunk keys without selection/seam compatibility guarantees.
  /// Geometry must still match the level's width; order is never repaired.
  /// [continuationChunkKey] must supply a suitable target beyond the last chunk
  /// without replacing any of its geometry. It does not extend the finish.
  LevelTraversalRoute.chunks({
    required this.level,
    required this.seed,
    required Iterable<String> chunkKeys,
    required this.continuationChunkKey,
    StagedTerrainCatalog? catalog,
  }) : keys = List.unmodifiable(chunkKeys),
       catalog = catalog ?? _generatedCatalog {
    if (keys.isEmpty) {
      throw ArgumentError('Traversal needs at least one chunk.');
    }
    for (final key in [...keys, continuationChunkKey]) {
      if (this.catalog.requireChunk(key).width.toDouble() != width) {
        throw ArgumentError(
          'Chunk $key does not match the level width $width.',
        );
      }
    }
    _graphProfiles = _buildGraphProfiles(level);
  }

  static final _generatedCatalog = StagedTerrainArtifactCatalog(
    artifact: stagedAuthoredTerrain,
  );
  final LevelDefinition level;
  final StagedTerrainCatalog catalog;
  final int seed;
  final List<String> keys;
  final String continuationChunkKey;
  late final List<TerrainSurfaceGraphBuildProfile> _graphProfiles;
  final _candidates = <int, StagedTerrainStreamCandidate>{};
  double get width => level.tuning.track.chunkWidth;

  // Keep one chunk behind and two ahead, including real cross-chunk seams.
  // Each actor retains its position and velocity across publication changes.
  StagedTerrainStreamCandidate candidate(int index) =>
      _candidates.putIfAbsent(index, () {
        return const StagedTerrainStreamCandidateBuilder().buildFromBindings(
          bindings: [
            for (
              var i = math.max(0, index - 1);
              i <= math.min(keys.length, index + 2);
              i++
            )
              catalog.bind(
                chunkKey: i == keys.length ? continuationChunkKey : keys[i],
                chunkIndex: i,
                worldOriginXTicks: physicsCoordinateToTicks(i * width),
              ),
          ],
          geometryVersion: index + 1,
          groundEnemyProfiles: _graphProfiles,
        );
      });
}

List<TerrainSurfaceGraphBuildProfile> _buildGraphProfiles(
  LevelDefinition level,
) {
  final locomotion = level.tuning.groundEnemy.locomotion;
  final physics = level.tuning.physics;
  final airSeconds = physics.gravityY <= 0
      ? 1.0
      : 2 * locomotion.jumpSpeed.abs() / physics.gravityY;
  const catalog = EnemyCatalog();
  return buildGroundEnemyTerrainGraphProfiles(
    enemyCatalog: catalog,
    jumpTemplatesById: {
      for (final id in groundNavigatingEnemyIds)
        id: JumpReachabilityTemplate.build(
          JumpProfile(
            jumpSpeed: locomotion.jumpSpeed,
            gravityY: physics.gravityY,
            maxAirTicks: physics.gravityY <= 0
                ? _tickHz
                : (airSeconds * 1.5 * _tickHz).ceil(),
            airSpeedX: locomotion.speedX,
            dtSeconds: 1 / _tickHz,
            agentHalfWidth: catalog.get(id).collider.halfX,
            agentHalfHeight: catalog.get(id).collider.halfY,
            requiredSupportFraction: groundEnemySupportFraction,
            collideCeilings: catalog
                .terrainContactProfile(id)
                .traversal
                .collideCeilings,
            collideLeftWalls: catalog
                .terrainContactProfile(id)
                .traversal
                .collideLeftWalls,
            collideRightWalls: catalog
                .terrainContactProfile(id)
                .traversal
                .collideRightWalls,
          ),
        ),
    },
    locomotionSpeedTicksPerSecond: physicsCoordinateToTicks(locomotion.speedX),
    simulationTicksPerSecond: _tickHz,
  );
}

/// Exercises pursuit without combat, despawning, or teleport escape shortcuts.
/// Only the player target is repositioned; the enemy must traverse continuously.
class EnemyTraversalHarness {
  /// Budgets are simulation ticks at 60 Hz, not wall-clock time. Arrival is the
  /// intermediate waypoint tolerance in world units; it never moves the finish.
  /// Its default includes Unoco's 90-unit stand-off plus 20-unit slack.
  /// Defaults allow ten seconds without progress and thirty seconds per chunk.
  EnemyTraversalHarness(
    this.route,
    this.enemyId, {
    this.stallTicks = 10 * _tickHz,
    this.ticksPerChunk = 30 * _tickHz,
    this.arrivalDistance = 128,
  }) {
    if (![
      EnemyId.grojib,
      EnemyId.hashash,
      EnemyId.unocoDemon,
    ].contains(enemyId)) {
      throw ArgumentError.value(
        enemyId,
        'enemyId',
        'Requires a supported mobile enemy; Derf is stationary.',
      );
    }
    if (stallTicks <= 0 ||
        ticksPerChunk <= 0 ||
        !arrivalDistance.isFinite ||
        arrivalDistance <= 0 ||
        arrivalDistance >= route.width / 2) {
      throw ArgumentError(
        'Use positive tick budgets and an arrival distance '
        'smaller than half a chunk.',
      );
    }
    world = EcsWorld(seed: route.seed);
    movement = MovementTuningDerived.from(
      eloiseCharacter.tuning.movement,
      tickHz: _tickHz,
    );
    final playerArchetype = PlayerCatalogDerived.from(
      eloiseCharacter.catalog,
      movement: movement,
      resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
    ).archetype;
    player = EntityFactory(world).createPlayer(
      posX: level.tuning.track.playerStartX,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: playerArchetype.facing,
      grounded: false,
      body: playerArchetype.body,
      collider: playerArchetype.collider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
    );
    authority = TerrainMultiBodyWorldMotionAuthority.fromStagedCandidate(
      candidate: route.candidate(0),
      playerProfile: playerArchetype.terrainTraversalProfile,
    );
    authority.initializePlayer(
      world,
      player: player,
      archetype: playerArchetype,
    );
    // The clearance-checked target is stationary between waypoints; only the
    // enemy participates in motion integration.
    world.body.enabled[world.body.indexOf(player)] = false;
    final archetype = const EnemyCatalog().get(enemyId);
    enemy = EntityFactory(world).createEnemy(
      enemyId: enemyId,
      posX: level.tuning.track.playerStartX,
      posY: enemyId == EnemyId.unocoDemon
          ? level.groundTopY - level.tuning.unocoDemon.unocoDemonHoverOffsetY
          : level.groundTopY -
                archetype.collider.offsetY -
                archetype.collider.halfY,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      artFacing: archetype.artFacingDir,
      body: archetype.body,
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
    );
    final tuning = GroundEnemyTuningDerived.from(
      level.tuning.groundEnemy,
      tickHz: _tickHz,
    );
    final navigationTuning = level.tuning.navigation;
    navigation = TerrainEnemyNavigationSystem(
      runtimeBundle: () => authority.terrainRuntimeBundle,
      navigator: TerrainSurfaceNavigator(
        pathfinder: TerrainSurfacePathfinder(
          maxExpandedNodes: navigationTuning.maxExpandedNodes,
          edgePenaltyCostUnits:
              (navigationTuning.edgePenaltySeconds *
                      terrainNavigationCostUnitsPerSecond)
                  .round(),
        ),
        repathCooldownTicks: navigationTuning.repathCooldownTicks,
        takeoffToleranceTicks: physicsCoordinateToTicks(
          math.max(
            navigationTuning.takeoffEpsMin,
            tuning.locomotion.stopDistanceX,
          ),
        ),
      ),
      physics: level.tuning.physics,
      dtSeconds: movement.dtSeconds,
    );
    engagement = EnemyEngagementSystem(groundEnemyTuning: tuning);
    groundLocomotion = GroundEnemyLocomotionSystem(groundEnemyTuning: tuning);
    flyingLocomotion = FlyingEnemyLocomotionSystem(
      unocoDemonTuning: UnocoDemonTuningDerived.from(
        level.tuning.unocoDemon,
        tickHz: _tickHz,
      ),
      worldMotionAuthority: authority,
    );
  }

  final LevelTraversalRoute route;
  final int stallTicks;
  final int ticksPerChunk;
  final double arrivalDistance;
  LevelDefinition get level => route.level;
  final EnemyId enemyId;
  late final EcsWorld world;
  late final int player;
  late final int enemy;
  late final MovementTuningDerived movement;
  late final TerrainMultiBodyWorldMotionAuthority authority;
  late final TerrainEnemyNavigationSystem navigation;
  late final EnemyEngagementSystem engagement;
  late final GroundEnemyLocomotionSystem groundLocomotion;
  late final FlyingEnemyLocomotionSystem flyingLocomotion;
  final gravity = GravitySystem();
  final water = WaterImmersionSystem();
  final visitedChunks = <int>{};
  final _trace = <String>[];
  String? _lastTraceState;
  bool _started = false;
  int tick = 0;
  int windowIndex = 0;
  int targetChunk = 0;
  double get enemyX => world.transform.posX[world.transform.indexOf(enemy)];
  double get enemyY => world.transform.posY[world.transform.indexOf(enemy)];
  double get targetX => world.transform.posX[world.transform.indexOf(player)];

  /// Absolute world-space boundary after the last tested chunk, independent
  /// of chase-target placement and intermediate waypoint tolerance.
  double get finishX => route.keys.length * route.width;

  /// Runs once; null means the enemy crossed [finishX], visited every tested
  /// chunk and (for ground enemies) reached grounded/swimming support there.
  /// Failure includes the exact route, tuning, location, graph and motion trace.
  String? traverse() {
    if (_started) {
      throw StateError('Create a fresh harness for each traversal.');
    }
    _started = true;
    var bestX = enemyX;
    var lastProgressTick = 0;
    final maxTicks = route.keys.length * ticksPerChunk;
    for (tick = 1; tick <= maxTicks; tick++) {
      final chunk = (enemyX / route.width).floor().clamp(
        0,
        route.keys.length - 1,
      );
      visitedChunks.add(chunk);
      if (chunk > windowIndex) {
        windowIndex = chunk;
        authority.queueStagedTerrainCandidate(route.candidate(chunk));
      }
      authority.prepareTick(world, player: player, currentTick: tick);
      _placeCurrentTarget();
      if (enemyX >= targetX - arrivalDistance &&
          targetChunk < route.keys.length - 1) {
        targetChunk++;
        _placeCurrentTarget();
      }
      water.step(world, authority.waterRegions);
      if (enemyId == EnemyId.unocoDemon) {
        flyingLocomotion.step(
          world,
          player: player,
          groundTopY: level.groundTopY,
          dtSeconds: movement.dtSeconds,
          currentTick: tick,
        );
      } else {
        navigation.step(
          world,
          player: player,
          currentTick: tick,
          waterRegions: authority.waterRegions,
        );
        engagement.step(world, player: player, currentTick: tick);
        groundLocomotion.step(
          world,
          player: player,
          dtSeconds: movement.dtSeconds,
          currentTick: tick,
        );
      }
      gravity.step(world, movement, physics: level.tuning.physics);
      authority.step(
        world,
        player: player,
        movement: movement,
        fixedPointPilotEnabled: level.tuning.physics.fixedPointPilot.enabled,
        fixedPointSubpixelScale:
            level.tuning.physics.fixedPointPilot.subpixelScale,
        currentTick: tick,
      );
      water.step(world, authority.waterRegions);
      _recordTrace();
      if (enemyY >
          level.resolveKillPlaneY(
            fallbackOffsetY: level.tuning.track.gapKillOffsetY,
          )) {
        return _diagnostic('fell below kill plane');
      }
      final contact = world.terrainContact.indexOf(enemy);
      if (targetChunk == route.keys.length - 1 &&
          enemyX >= finishX &&
          (enemyId == EnemyId.unocoDemon ||
              world.terrainContact.grounded[contact] ||
              world.swimState.isSwimming(enemy))) {
        if (visitedChunks.length != route.keys.length) {
          return _diagnostic('reached the exit without visiting every chunk');
        }
        return null;
      }
      if (enemyX >= bestX + 4) {
        bestX = enemyX;
        lastProgressTick = tick;
      }
      if (tick - lastProgressTick >= stallTicks) {
        return _diagnostic('no forward progress for $stallTicks ticks');
      }
    }
    return _diagnostic('exceeded $maxTicks tick budget');
  }

  void _placeCurrentTarget() {
    if (targetChunk < route.keys.length - 1) {
      _placeTarget((targetChunk + 1) * route.width - 32);
      return;
    }
    // Keep the target far enough beyond the finish for real stand-off behavior.
    // Backward placement probes may never pull it back onto the tested route.
    final flying = level.tuning.unocoDemon;
    final standOff = enemyId == EnemyId.unocoDemon
        ? flying.unocoDemonDesiredRangeMax + flying.unocoDemonHoldSlack
        : level.tuning.groundEnemy.combat.meleeRangeX;
    final minimumX = finishX + math.max(arrivalDistance, standOff) + 32;
    _placeTarget(
      math.max(finishX + route.width / 2, minimumX),
      minimumX: minimumX,
    );
  }

  void _placeTarget(double x, {double? minimumX}) {
    final bundle = authority.terrainRuntimeBundle;
    final ci = world.worldContactCapsule.indexOf(player);
    final capsule = world.worldContactCapsule;
    final query = TerrainPlacementQuery(
      geometry: bundle.geometry,
      terrainIndex: bundle.edgeIndex,
      surfaceIndex: bundle.surfaceIndex,
    );
    TerrainPlacementResult? placement;
    final failures = <String>[];
    // The nominal endpoint can land on a prefab corner. Move the target along
    // the exit area until its full capsule has a legal foothold and clearance.
    // A continuation can have a gap at its midpoint. Search farther forward
    // for final-target support while keeping the tested finish fixed.
    final offsets = [
      0,
      -16,
      16,
      32,
      48,
      64,
      80,
      96,
      if (minimumX != null)
        for (var forward = 32; forward <= 256; forward += 16) -forward,
    ];
    for (final offset in offsets) {
      if (minimumX != null && x - offset < minimumX) continue;
      if (minimumX != null && x - offset > finishX + route.width - 32) {
        continue;
      }
      for (final surface in bundle.surfaceSet.surfaces) {
        final capsuleX =
            physicsCoordinateToTicks(x - offset) + capsule.offsetXTicks[ci];
        if (capsuleX < surface.xMinTicks || capsuleX > surface.xMaxTicks) {
          continue;
        }
        final candidate = query.resolveGrounded(
          TerrainGroundPlacementRequest(
            desiredBodyCenterXTicks: physicsCoordinateToTicks(x - offset),
            minimumSupportYTicks: physicsCoordinateToTicks(-1024),
            maximumSupportYTicks: physicsCoordinateToTicks(1024),
            capsule: TerrainPlacementCapsule(
              radiusTicks: capsule.radiusTicks[ci],
              verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks[ci],
              resolvedOffsetXTicks: capsule.offsetXTicks[ci],
              offsetYTicks: capsule.offsetYTicks[ci],
            ),
            traversalProfile: world
                .terrainTraversalProfile
                .profile[world.terrainTraversalProfile.indexOf(player)],
            supportRequirement: const TerrainSupportRequirement.groundedSpawn(),
            intendedSupportEdgeId: surface.id,
            expectedGeometryVersion: bundle.version,
          ),
        );
        if (candidate.isValid && enemyId != EnemyId.unocoDemon) {
          final profile = enemyId == EnemyId.grojib
              ? bundle.grojibGraph.buildProfile
              : bundle.hashashGraph.buildProfile;
          final enemyPlacement = query.resolveGrounded(
            TerrainGroundPlacementRequest(
              desiredBodyCenterXTicks: candidate.bodyCenter!.xTicks,
              minimumSupportYTicks: physicsCoordinateToTicks(-1024),
              maximumSupportYTicks: physicsCoordinateToTicks(1024),
              capsule: profile.capsuleForDirection(1),
              traversalProfile: profile.traversalProfile,
              supportRequirement: profile.supportRequirement,
              intendedSupportEdgeId: surface.id,
              expectedGeometryVersion: bundle.version,
            ),
          );
          if (!enemyPlacement.isValid) continue;
        }
        failures.add(
          '${x - offset}: ${surface.id} ${candidate.validity.name} blocker=${candidate.blockingEdgeId}',
        );
        if (candidate.isValid &&
            (placement == null ||
                candidate.bodyCenter!.yTicks < placement.bodyCenter!.yTicks)) {
          placement = candidate;
        }
      }
      if (placement != null) break;
    }
    if (placement == null) {
      fail(
        _diagnostic(
          'no valid target in exit area at x=$x; ${failures.join('; ')}',
        ),
      );
    }
    authority.beginBodyTeleport(world, player);
    final ti = world.transform.indexOf(player);
    world.transform.posX[ti] =
        placement.bodyCenter!.xTicks / terrainPhysicsTicksPerWorldUnit;
    world.transform.posY[ti] =
        placement.bodyCenter!.yTicks / terrainPhysicsTicksPerWorldUnit;
    world.transform.velX[ti] = 0;
    world.transform.velY[ti] = 0;
    world.terrainContact.setSupport(
      player,
      edge: bundle.geometry.edgeById[placement.supportEdgeId]!,
      pointXTicks: placement.supportPoint!.xTicks,
      pointYTicks: placement.supportPoint!.yTicks,
      geometryVersion: bundle.version,
      currentTick: tick,
    );
  }

  String _diagnostic(String reason) {
    final chunk = (enemyX / route.width).floor().clamp(
      0,
      route.keys.length - 1,
    );
    final ci = world.terrainContact.tryIndexOf(enemy);
    final ni = world.navIntent.tryIndexOf(enemy);
    final locomotion = level.tuning.groundEnemy.locomotion;
    final flying = level.tuning.unocoDemon;
    final archetype = const EnemyCatalog().get(enemyId);
    final profile = const EnemyCatalog().terrainContactProfile(enemyId);
    final capabilities = enemyId == EnemyId.unocoDemon
        ? 'flightSpeedX=${flying.unocoDemonMaxSpeedX} '
              'flightSpeedY=${flying.unocoDemonMaxSpeedY}'
        : 'speedX=${locomotion.speedX} jumpSpeed=${locomotion.jumpSpeed} '
              'gravityY=${level.tuning.physics.gravityY} '
              'maxSlopeDegrees=${profile.traversal.maxWalkableSlopeAngleUnits / terrainSlopeAngleUnitsPerDegree}';
    return 'level=${level.identity.value} ${enemyId.name} seed=${route.seed}: $reason; '
        'chunk=${chunk + 1}/${route.keys.length} ${route.keys[chunk]}, '
        'x=${enemyX.toStringAsFixed(2)} y=${enemyY.toStringAsFixed(2)}, '
        'localX=${(enemyX - chunk * route.width).toStringAsFixed(2)}, tick=$tick, '
        'grounded=${ci == null ? false : world.terrainContact.grounded[ci]}, '
        'support=${ci == null ? null : world.terrainContact.supportEdgeId[ci]}, '
        'hasPlan=${ni == null ? null : world.navIntent.hasPlan[ni]}, '
        'targetX=${targetX.toStringAsFixed(2)}, '
        'targetChunk=${targetChunk + 1} ${route.keys[targetChunk]}, '
        'routeLength=${route.keys.length * route.width}, '
        'finishX=$finishX continuation=${route.continuationChunkKey}, '
        '$capabilities colliderHalfSize=${archetype.collider.halfX},${archetype.collider.halfY}, '
        'arrivalDistance=$arrivalDistance stallTicks=$stallTicks ticksPerChunk=$ticksPerChunk\n'
        'route=${route.keys.join(' -> ')}\n${_graphDiagnostic()}\n${_trace.join('\n')}';
  }

  String _graphDiagnostic() {
    final ni = world.surfaceNav.tryIndexOf(enemy);
    if (ni == null) return '';
    final state = world.surfaceNav.terrainState[ni];
    final graph = enemyId == EnemyId.grojib
        ? authority.terrainRuntimeBundle.grojibGraph
        : authority.terrainRuntimeBundle.hashashGraph;
    final reached = <int>{};
    final queue = <int>[
      if (state.currentSurfaceIndex >= 0) state.currentSurfaceIndex,
    ];
    for (var i = 0; i < queue.length; i++) {
      final node = queue[i];
      if (!reached.add(node)) continue;
      for (
        var e = graph.edgeOffsets[node];
        e < graph.edgeOffsets[node + 1];
        e++
      ) {
        if (!reached.contains(graph.edges[e].to)) queue.add(graph.edges[e].to);
      }
    }
    return 'graph current=${state.currentSurfaceIndex} target=${state.targetSurfaceIndex} '
        'reachable=${reached.contains(state.targetSurfaceIndex)} '
        'nodes=${reached.length}/${graph.surfaces.length}';
  }

  void _recordTrace() {
    final ni = world.surfaceNav.tryIndexOf(enemy);
    if (ni == null) {
      if (tick != 1 && tick % _tickHz != 0) return;
      final ti = world.transform.indexOf(enemy);
      _trace.add(
        't=$tick p=(${enemyX.toStringAsFixed(2)},${enemyY.toStringAsFixed(2)}) '
        'v=(${world.transform.velX[ti].toStringAsFixed(2)},${world.transform.velY[ti].toStringAsFixed(2)})',
      );
      if (_trace.length > 32) _trace.removeAt(0);
      return;
    }
    final state = world.surfaceNav.terrainState[ni];
    final graph = enemyId == EnemyId.grojib
        ? authority.terrainRuntimeBundle.grojibGraph
        : authority.terrainRuntimeBundle.hashashGraph;
    final edgeIndex = state.activeEdgeIndex >= 0
        ? state.activeEdgeIndex
        : state.pathCursor < state.pathEdges.length
        ? state.pathEdges[state.pathCursor]
        : -1;
    final edge = edgeIndex >= 0 ? graph.edges[edgeIndex] : null;
    final ci = world.terrainContact.indexOf(enemy);
    final intent = world.navIntent.indexOf(enemy);
    final ti = world.transform.indexOf(enemy);
    final support = world.terrainContact.supportEdgeId[ci];
    final key =
        '${state.bundleVersion}/$support/$edgeIndex/${state.activeEdgeIndex}/'
        '${world.navIntent.jumpNow[intent]}/${world.terrainContact.grounded[ci]}';
    if (key == _lastTraceState && tick % 60 != 0) return;
    _lastTraceState = key;
    final transition = edge == null
        ? 'none'
        : '${edge.kind.name}#$edgeIndex '
              'takeoff=(${edge.takeoffPoint.xTicks / terrainPhysicsTicksPerWorldUnit},${edge.takeoffPoint.yTicks / terrainPhysicsTicksPerWorldUnit}) '
              'landing=(${edge.landingPoint.xTicks / terrainPhysicsTicksPerWorldUnit},${edge.landingPoint.yTicks / terrainPhysicsTicksPerWorldUnit}) '
              'travel=${edge.travelTicks} to=${graph.surfaces[edge.to].id}';
    _trace.add(
      't=$tick p=(${enemyX.toStringAsFixed(2)},${enemyY.toStringAsFixed(2)}) '
      'v=(${world.transform.velX[ti].toStringAsFixed(2)},${world.transform.velY[ti].toStringAsFixed(2)}) '
      'support=$support plan=${world.navIntent.hasPlan[intent]} '
      'jump=${world.navIntent.jumpNow[intent]} active=${state.activeEdgeIndex} '
      'desired=${world.navIntent.desiredX[intent].toStringAsFixed(2)} '
      'walls=${world.terrainContact.hitLeft[ci]}/${world.terrainContact.hitRight[ci]} '
      '$transition',
    );
    if (_trace.length > 32) _trace.removeAt(0);
  }
}
