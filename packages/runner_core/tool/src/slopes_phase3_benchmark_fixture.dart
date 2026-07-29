import 'dart:math' as math;

import 'package:runner_core/collision/static_world_geometry_index.dart';
import 'package:runner_core/collision/terrain/terrain_capsule_controller.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/collision/terrain/upright_capsule.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/flying_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_graph_builder.dart';
import 'package:runner_core/navigation/terrain_surface_navigator.dart';
import 'package:runner_core/navigation/terrain_surface_pathfinder.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/navigation/terrain_trajectory_predictor.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_archetype.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';

const int slopesPhase3RepresentativeEdgeCount = 1280;
const int slopesPhase3HardStreamEdgeCount = 5120;
const int slopesPhase3ChunkCount = 5;
const int slopesPhase3PathfinderExpansionLimit = 512;

/// Reusable, deterministic geometry and graph inputs for the Phase 3 report.
final class SlopesPhase3BenchmarkFixture {
  SlopesPhase3BenchmarkFixture._({
    required this.geometry,
    required this.profiles,
    required this.stack,
    required this.bundle,
  });

  factory SlopesPhase3BenchmarkFixture.build({
    required int edgeCount,
    required bool sloped,
    int geometryVersion = 31,
  }) {
    final geometry = buildSlopesPhase3BenchmarkGeometry(
      edgeCount: edgeCount,
      sloped: sloped,
      geometryVersion: geometryVersion,
    );
    final profiles = buildDefaultGroundEnemyTerrainGraphProfiles();
    final stack = buildSlopesPhase3SurfaceStack(geometry);
    final builder = TerrainSurfaceGraphBuilder(
      placementQuery: stack.placementQuery,
    );
    final bundle = TerrainRuntimeBundle.build(
      geometry: geometry,
      groundEnemyProfiles: profiles,
    );
    // Exercise the independently constructed graph builder during fixture
    // validation so benchmark inputs cannot hide a mismatched graph profile.
    final probe = builder.build(profiles.first);
    if (probe.profileKey != profiles.first.profileKey ||
        probe.geometryVersion != geometryVersion) {
      throw StateError('Phase 3 graph probe did not use the requested input.');
    }
    final bundleStack = SlopesPhase3SurfaceStack(
      edgeIndex: bundle.edgeIndex,
      surfaceSet: bundle.surfaceSet,
      surfaceIndex: bundle.surfaceIndex,
      placementQuery: TerrainPlacementQuery(
        geometry: bundle.geometry,
        terrainIndex: bundle.edgeIndex,
        surfaceIndex: bundle.surfaceIndex,
      ),
    );
    return SlopesPhase3BenchmarkFixture._(
      geometry: geometry,
      profiles: profiles,
      stack: bundleStack,
      bundle: bundle,
    );
  }

  final TerrainGeometry geometry;
  final List<TerrainSurfaceGraphBuildProfile> profiles;
  final SlopesPhase3SurfaceStack stack;
  final TerrainRuntimeBundle bundle;

  int get nodeCount => bundle.surfaceSet.surfaces.length;
  int get graphEdgeCount =>
      bundle.grojibGraph.edges.length + bundle.hashashGraph.edges.length;
}

final class SlopesPhase3SurfaceStack {
  const SlopesPhase3SurfaceStack({
    required this.edgeIndex,
    required this.surfaceSet,
    required this.surfaceIndex,
    required this.placementQuery,
  });

  final TerrainEdgeIndex edgeIndex;
  final TerrainSurfaceSet surfaceSet;
  final TerrainSurfaceSpatialIndex surfaceIndex;
  final TerrainPlacementQuery placementQuery;
}

SlopesPhase3SurfaceStack buildSlopesPhase3SurfaceStack(
  TerrainGeometry geometry,
) {
  final edgeIndex = TerrainEdgeIndex(edges: geometry.edges);
  final surfaceSet = const TerrainSurfaceExtractor().extract(geometry);
  final surfaceIndex = TerrainSurfaceSpatialIndex(surfaceSet: surfaceSet);
  return SlopesPhase3SurfaceStack(
    edgeIndex: edgeIndex,
    surfaceSet: surfaceSet,
    surfaceIndex: surfaceIndex,
    placementQuery: TerrainPlacementQuery(
      geometry: geometry,
      terrainIndex: edgeIndex,
      surfaceIndex: surfaceIndex,
    ),
  );
}

TerrainGeometry buildSlopesPhase3BenchmarkGeometry({
  required int edgeCount,
  required bool sloped,
  required int geometryVersion,
}) {
  if (edgeCount != slopesPhase3RepresentativeEdgeCount &&
      edgeCount != slopesPhase3HardStreamEdgeCount) {
    throw ArgumentError.value(
      edgeCount,
      'edgeCount',
      'Expected the representative or hard-stream edge count.',
    );
  }
  final inputs = <TerrainPolygonInput>[
    _groundPolygon(sloped: sloped),
    TerrainPolygonInput.fromWorld(
      sourcePath: 'benchmark/phase3/chunk_1/jump-lower',
      identity: TerrainSourceIdentity(
        chunkIndex: 1,
        chunkKey: 'phase3_1',
        shapeId: 'jump-lower',
      ),
      vertices: const <(double, double)>[
        (1800, 1130),
        (2200, 1110),
        (2200, 1140),
        (1800, 1140),
      ],
      surfaceKind: 'benchmark',
    ),
    _rectangle(
      shapeId: 'jump-upper',
      minX: 2040,
      minY: 1060,
      maxX: 2160,
      maxY: 1090,
      chunkIndex: 1,
    ),
    _rectangle(
      shapeId: 'flight-blocker',
      minX: 580,
      minY: 260,
      maxX: 660,
      maxY: 650,
      chunkIndex: 2,
    ),
  ];
  final remainingEdges = edgeCount - inputs.length * 4;
  if (remainingEdges < 0 || remainingEdges % 4 != 0) {
    throw StateError('Phase 3 fixture edge count cannot be partitioned.');
  }
  for (var index = 0; index < remainingEdges ~/ 4; index += 1) {
    final x = 500000.0 + index * 512;
    final y = 20000.0 + (index % slopesPhase3ChunkCount) * 160;
    inputs.add(
      TerrainPolygonInput.fromWorld(
        sourcePath:
            'benchmark/phase3/chunk_${index % slopesPhase3ChunkCount}/'
            'filler_${index.toString().padLeft(4, '0')}',
        identity: TerrainSourceIdentity(
          chunkIndex: index % slopesPhase3ChunkCount,
          chunkKey: 'phase3_${index % slopesPhase3ChunkCount}',
          shapeId: 'filler_${index.toString().padLeft(4, '0')}',
        ),
        // These edges represent non-walkable walls/terrain detail in the
        // active stream. Keeping them steeper than Hashash's 60-degree limit
        // exercises collision/index capacity without inventing hundreds of
        // artificial jump origins in the graph timing fixture.
        vertices: <(double, double)>[
          (x, y),
          (x + 1, y - 2),
          (x + 1, y + 14),
          (x, y + 16),
        ],
        surfaceKind: 'benchmark',
      ),
    );
  }
  final geometry = const TerrainCompiler().compile(
    inputs,
    geometryVersion: geometryVersion,
  );
  if (geometry.edges.length != edgeCount) {
    throw StateError(
      'Phase 3 fixture compiled ${geometry.edges.length} of $edgeCount edges.',
    );
  }
  return geometry;
}

TerrainPolygonInput _groundPolygon({required bool sloped}) {
  final topEndY = sloped ? 675.0 : 900.0;
  return TerrainPolygonInput.fromWorld(
    sourcePath: 'benchmark/phase3/chunk_0/mixed-ground',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'phase3_0',
      shapeId: 'mixed-ground',
    ),
    vertices: <(double, double)>[
      (-200, 900),
      (1600, topEndY),
      (1600, 1300),
      (-200, 1300),
    ],
    surfaceKind: 'benchmark',
  );
}

TerrainPolygonInput _rectangle({
  required String shapeId,
  required double minX,
  required double minY,
  required double maxX,
  required double maxY,
  required int chunkIndex,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'benchmark/phase3/chunk_$chunkIndex/$shapeId',
  identity: TerrainSourceIdentity(
    chunkIndex: chunkIndex,
    chunkKey: 'phase3_$chunkIndex',
    shapeId: shapeId,
  ),
  vertices: <(double, double)>[
    (minX, minY),
    (maxX, minY),
    (maxX, maxY),
    (minX, maxY),
  ],
  surfaceKind: 'benchmark',
);

/// One warmed dynamic-body controller probe with caller-owned output.
final class SlopesPhase3ControllerCase {
  SlopesPhase3ControllerCase._({
    required this.name,
    required this.controller,
    required this.capsule,
    required this.request,
    required this.support,
    required this.beganGrounded,
  });

  factory SlopesPhase3ControllerCase.supported({
    required SlopesPhase3BenchmarkFixture fixture,
    required EnemyId enemyId,
  }) {
    final enemy = const EnemyCatalog().terrainContactProfile(enemyId);
    final support = fixture.geometry.edges.firstWhere(
      (edge) =>
          edge.id.shapeId == 'mixed-ground' && edge.outwardNormal.yTicks < 0,
    );
    final capsule = _supportedCapsule(
      support,
      radiusTicks: enemy.capsule.radiusTicks,
      verticalHalfSegmentTicks: enemy.capsule.verticalHalfSegmentTicks,
      centerXWorld: enemyId == EnemyId.grojib ? 200 : 700,
    );
    return SlopesPhase3ControllerCase._(
      name: '${enemyId.name}-supported-slope',
      controller: TerrainCapsuleController(
        geometry: fixture.geometry,
        index: fixture.stack.edgeIndex,
        profile: enemy.traversal,
      ),
      capsule: capsule,
      request: TerrainMotionRequest(
        displacementXTicks: 4 * terrainPhysicsTicksPerWorldUnit,
        displacementYTicks: 0,
        gravityYTicks: 256,
        mode: TerrainMotionMode.groundedSurface,
      ),
      support: support,
      beganGrounded: true,
    );
  }

  factory SlopesPhase3ControllerCase.flyingBlocked({
    required SlopesPhase3BenchmarkFixture fixture,
  }) {
    final enemy = const EnemyCatalog().terrainContactProfile(
      EnemyId.unocoDemon,
    );
    return SlopesPhase3ControllerCase._(
      name: 'unoco-blocked-flight',
      controller: TerrainCapsuleController(
        geometry: fixture.geometry,
        index: fixture.stack.edgeIndex,
        profile: enemy.traversal,
      ),
      capsule: UprightCapsule(
        center: TerrainPoint(
          physicsCoordinateToTicks(540),
          physicsCoordinateToTicks(422),
        ),
        radiusTicks: enemy.capsule.radiusTicks,
        verticalHalfSegmentTicks: enemy.capsule.verticalHalfSegmentTicks,
      ),
      request: TerrainMotionRequest(
        displacementXTicks: 80 * terrainPhysicsTicksPerWorldUnit,
        displacementYTicks: 0,
        mode: TerrainMotionMode.worldSpace,
      ),
      support: null,
      beganGrounded: false,
    );
  }

  final String name;
  final TerrainCapsuleController controller;
  final UprightCapsule capsule;
  final TerrainMotionRequest request;
  final TerrainEdge? support;
  final bool beganGrounded;
  final TerrainCapsuleMotionResult result = TerrainCapsuleMotionResult();

  void run() {
    controller.move(
      capsule: capsule,
      request: request,
      beganGrounded: beganGrounded,
      priorSupportEdgeId: support?.id,
      priorSupportGeometryVersion: support == null
          ? -1
          : controller.geometry.version,
      lastValidCapsuleCenterXTicks: capsule.center.xTicks,
      lastValidCapsuleCenterYTicks: capsule.center.yTicks,
      out: result,
    );
  }
}

UprightCapsule _supportedCapsule(
  TerrainEdge edge, {
  required int radiusTicks,
  required int verticalHalfSegmentTicks,
  required double centerXWorld,
}) {
  final centerX = physicsCoordinateToTicks(centerXWorld);
  final normalX = edge.dyTicks;
  final normalY = -edge.dxTicks;
  final edgeLength = _integerSqrt(
    edge.dxTicks * edge.dxTicks + edge.dyTicks * edge.dyTicks,
  );
  final extent = (radiusTicks + terrainCollisionSkinTicks) * edgeLength;
  final lineConstant =
      normalX * edge.start.xTicks + normalY * edge.start.yTicks + extent;
  final bottomCircleCenterY = _roundedDivide(
    lineConstant - normalX * centerX,
    normalY,
  );
  return UprightCapsule(
    center: TerrainPoint(
      centerX,
      bottomCircleCenterY - verticalHalfSegmentTicks,
    ),
    radiusTicks: radiusTicks,
    verticalHalfSegmentTicks: verticalHalfSegmentTicks,
  );
}

/// Reused A*, placement, and trajectory probes over one graph publication.
final class SlopesPhase3NavigationHarness {
  SlopesPhase3NavigationHarness._({
    required this.fixture,
    required this.graph,
    required this.sourceIndex,
    required this.edgeIndex,
    required this.entity,
    required this.target,
    required this.navigator,
    required this.predictor,
    required this.prediction,
  });

  factory SlopesPhase3NavigationHarness.build(
    SlopesPhase3BenchmarkFixture fixture,
  ) {
    final graph = fixture.bundle.hashashGraph;
    var sourceIndex = -1;
    var edgeIndex = -1;
    for (var source = 0; source < graph.surfaces.length; source += 1) {
      for (
        var index = graph.edgeOffsets[source];
        index < graph.edgeOffsets[source + 1];
        index += 1
      ) {
        if (graph.edges[index].kind == TerrainSurfaceEdgeKind.jump) {
          sourceIndex = source;
          edgeIndex = index;
          break;
        }
      }
      if (edgeIndex >= 0) break;
    }
    if (sourceIndex < 0 || edgeIndex < 0) {
      throw StateError('Phase 3 fixture emitted no Hashash jump edge.');
    }
    final edge = graph.edges[edgeIndex];
    final profile = graph.buildProfile;
    final entity = _actorOnSurface(
      fixture,
      graph.surfaces[sourceIndex],
      profile,
      edge.takeoffPoint.xTicks,
    );
    final target = _actorOnSurface(
      fixture,
      graph.surfaces[edge.to],
      profile,
      edge.landingPoint.xTicks,
    );
    final jump = profile.jumpTemplate.profile;
    return SlopesPhase3NavigationHarness._(
      fixture: fixture,
      graph: graph,
      sourceIndex: sourceIndex,
      edgeIndex: edgeIndex,
      entity: entity,
      target: target,
      navigator: TerrainSurfaceNavigator(
        pathfinder: TerrainSurfacePathfinder(
          maxExpandedNodes: slopesPhase3PathfinderExpansionLimit,
        ),
      ),
      predictor: TerrainTrajectoryPredictor(
        placementQuery: fixture.stack.placementQuery,
        traversalProfile: profile.traversalProfile,
        supportRequirement: profile.supportRequirement,
        dtSeconds: jump.dtSeconds,
        maxTicks: jump.maxAirTicks,
      ),
      prediction: TerrainLandingPrediction(),
    );
  }

  final SlopesPhase3BenchmarkFixture fixture;
  final TerrainSurfaceGraph graph;
  final int sourceIndex;
  final int edgeIndex;
  final TerrainSurfaceNavigationActorSnapshot entity;
  final TerrainSurfaceNavigationActorSnapshot target;
  final TerrainSurfaceNavigator navigator;
  final TerrainTrajectoryPredictor predictor;
  final TerrainLandingPrediction prediction;
  final TerrainSurfaceNavigatorState steadyState =
      TerrainSurfaceNavigatorState();
  final TerrainSurfaceNavigatorState repathState =
      TerrainSurfaceNavigatorState();

  int get lastExpandedNodeCount => navigator.pathfinder.lastExpandedNodeCount;
  int get pathCapacity => repathState.pathEdges.length;

  void warm() {
    runRepath();
    runTrajectory();
    runSteadyState();
  }

  void runRepath() {
    repathState
      ..invalidateForBundle(fixture.bundle.version)
      ..repathTicksLeft = 0;
    navigator.update(
      state: repathState,
      graph: graph,
      placementQuery: fixture.stack.placementQuery,
      bundleVersion: fixture.bundle.version,
      entity: entity,
      target: target,
    );
  }

  void runSteadyState() {
    if (steadyState.bundleVersion != fixture.bundle.version) {
      navigator.update(
        state: steadyState,
        graph: graph,
        placementQuery: fixture.stack.placementQuery,
        bundleVersion: fixture.bundle.version,
        entity: entity,
        target: target,
      );
    }
    steadyState.repathTicksLeft = 1000000;
    navigator.update(
      state: steadyState,
      graph: graph,
      placementQuery: fixture.stack.placementQuery,
      bundleVersion: fixture.bundle.version,
      entity: entity,
      target: target,
    );
  }

  void runTrajectory() {
    final edge = graph.edges[edgeIndex];
    final jump = graph.buildProfile.jumpTemplate.profile;
    final landed = predictor.predictLanding(
      startBodyCenter: edge.takeoffPoint,
      capsule: graph.buildProfile.capsuleForDirection(edge.commitDirectionX),
      velocityX: edge.commitDirectionX * jump.airSpeedX,
      velocityY: -jump.jumpSpeed,
      gravityY: jump.gravityY,
      maximumFallSpeed: 20000,
      out: prediction,
    );
    if (!landed) {
      throw StateError('Phase 3 trajectory probe did not land.');
    }
  }
}

TerrainSurfaceNavigationActorSnapshot _actorOnSurface(
  SlopesPhase3BenchmarkFixture fixture,
  TerrainNavigationSurface surface,
  TerrainSurfaceGraphBuildProfile profile,
  int desiredBodyXTicks,
) {
  final capsule = profile.capsuleForDirection(1);
  final capsuleX = desiredBodyXTicks + capsule.resolvedOffsetXTicks;
  final supportY = surface.yAtXTicks(
    capsuleX.clamp(surface.xMinTicks, surface.xMaxTicks),
  );
  final placement = fixture.stack.placementQuery.resolveGrounded(
    TerrainGroundPlacementRequest(
      desiredBodyCenterXTicks: desiredBodyXTicks,
      minimumSupportYTicks: supportY,
      maximumSupportYTicks: supportY,
      capsule: capsule,
      traversalProfile: profile.traversalProfile,
      supportRequirement: profile.supportRequirement,
      intendedSupportEdgeId: surface.id,
      allowSameSupportClamp: true,
      expectedGeometryVersion: fixture.geometry.version,
    ),
  );
  if (!placement.isValid || placement.bodyCenter == null) {
    throw StateError('Phase 3 navigation actor placement failed.');
  }
  return TerrainSurfaceNavigationActorSnapshot(
    bodyCenter: placement.bodyCenter!,
    capsule: capsule,
    traversalProfile: profile.traversalProfile,
    supportRequirement: profile.supportRequirement,
    grounded: true,
    priorSupportEdgeId: surface.id,
    priorSupportGeometryVersion: fixture.geometry.version,
  );
}

/// Isolated Phase 3 ECS tick containing the frozen mixed-enemy actor counts.
final class SlopesPhase3MixedEnemyHarness {
  SlopesPhase3MixedEnemyHarness._({
    required this.world,
    required this.player,
    required this.groundEnemies,
    required this.flyingEnemies,
    required this.derfs,
    required this.authority,
    required this.movement,
    required this.groundLocomotion,
    required this.flyingLocomotion,
  });

  factory SlopesPhase3MixedEnemyHarness.build(TerrainGeometry geometry) {
    final world = EcsWorld(seed: 0x3E71);
    final factory = EntityFactory(world);
    final movement = MovementTuningDerived.from(
      eloiseCharacter.tuning.movement,
      tickHz: 60,
    );
    final playerArchetype = _playerArchetype(movement);
    final player = factory.createPlayer(
      posX: 1400,
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
    const catalog = EnemyCatalog();
    final groundEnemies = <int>[];
    final flyingEnemies = <int>[];
    final derfs = <int>[];

    int spawn(EnemyId id, double x, double y) {
      final archetype = catalog.get(id);
      return factory.createEnemy(
        enemyId: id,
        posX: x,
        posY: y,
        velX: 0,
        velY: 0,
        facing: Facing.right,
        artFacing: archetype.artFacingDir,
        body: archetype.body,
        collider: archetype.collider,
        health: archetype.health,
        mana: archetype.mana,
        stamina: archetype.stamina,
        tags: archetype.tags,
        resistance: archetype.resistance,
        statusImmunity: archetype.statusImmunity,
      );
    }

    for (var index = 0; index < 8; index += 1) {
      groundEnemies.add(spawn(EnemyId.grojib, 80 + index * 45, 700));
      groundEnemies.add(spawn(EnemyId.hashash, 480 + index * 45, 650));
    }
    for (var index = 0; index < 4; index += 1) {
      flyingEnemies.add(spawn(EnemyId.unocoDemon, 1000 + index * 100, 350));
      derfs.add(spawn(EnemyId.derf, 900 + index * 80, 500));
    }
    final authority = TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: playerArchetype.terrainTraversalProfile,
    );
    authority.initializePlayer(
      world,
      player: player,
      archetype: playerArchetype,
    );
    world.body.enabled[world.body.indexOf(player)] = false;
    return SlopesPhase3MixedEnemyHarness._(
      world: world,
      player: player,
      groundEnemies: groundEnemies,
      flyingEnemies: flyingEnemies,
      derfs: derfs,
      authority: authority,
      movement: movement,
      groundLocomotion: GroundEnemyLocomotionSystem(
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          const GroundEnemyTuning(),
          tickHz: 60,
        ),
      ),
      flyingLocomotion: FlyingEnemyLocomotionSystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(
          const UnocoDemonTuning(),
          tickHz: 60,
        ),
        worldMotionAuthority: authority,
      ),
    );
  }

  final EcsWorld world;
  final int player;
  final List<int> groundEnemies;
  final List<int> flyingEnemies;
  final List<int> derfs;
  final TerrainMultiBodyWorldMotionAuthority authority;
  final MovementTuningDerived movement;
  final GroundEnemyLocomotionSystem groundLocomotion;
  final FlyingEnemyLocomotionSystem flyingLocomotion;
  final GravitySystem _gravity = GravitySystem();
  final FlyingClearanceSteeringOutput _clearanceOutput =
      FlyingClearanceSteeringOutput();
  int tick = 0;

  int get lastIntegratedBodyCount => authority.lastIntegratedBodyCount;

  int get candidateCount {
    var total = 0;
    for (final entity in groundEnemies) {
      final index = world.terrainContact.tryIndexOf(entity);
      if (index != null) total += world.terrainContact.candidateCount[index];
    }
    for (final entity in flyingEnemies) {
      final index = world.terrainContact.tryIndexOf(entity);
      if (index != null) total += world.terrainContact.candidateCount[index];
    }
    return total;
  }

  int writeCandidateCounts(List<int> out, int offset) {
    var cursor = offset;
    for (final entity in groundEnemies) {
      final index = world.terrainContact.tryIndexOf(entity);
      if (index != null) {
        out[cursor] = world.terrainContact.candidateCount[index];
        cursor += 1;
      }
    }
    for (final entity in flyingEnemies) {
      final index = world.terrainContact.tryIndexOf(entity);
      if (index != null) {
        out[cursor] = world.terrainContact.candidateCount[index];
        cursor += 1;
      }
    }
    return cursor;
  }

  int get maxContactIterations {
    var maximum = 0;
    for (final entity in groundEnemies) {
      final index = world.terrainContact.tryIndexOf(entity);
      if (index != null) {
        maximum = math.max(
          maximum,
          world.terrainContact.contactIterations[index],
        );
      }
    }
    for (final entity in flyingEnemies) {
      final index = world.terrainContact.tryIndexOf(entity);
      if (index != null) {
        maximum = math.max(
          maximum,
          world.terrainContact.contactIterations[index],
        );
      }
    }
    return maximum;
  }

  int get maxRecoveryIterations {
    var maximum = 0;
    for (final entity in groundEnemies) {
      final index = world.terrainContact.tryIndexOf(entity);
      if (index != null) {
        maximum = math.max(
          maximum,
          world.terrainContact.recoveryIterations[index],
        );
      }
    }
    for (final entity in flyingEnemies) {
      final index = world.terrainContact.tryIndexOf(entity);
      if (index != null) {
        maximum = math.max(
          maximum,
          world.terrainContact.recoveryIterations[index],
        );
      }
    }
    return maximum;
  }

  int get clearanceSelectionCount {
    var count = 0;
    for (final enemy in flyingEnemies) {
      final index = world.flyingEnemySteering.indexOf(enemy);
      if (world.flyingEnemySteering.clearanceCandidateId[index] > 0) {
        count += 1;
      }
    }
    return count;
  }

  int get clearanceProbeCandidateId => _clearanceOutput.candidateId;

  /// Runs the fixed four-candidate Unoco blocker preview without moving it.
  void runFlyingClearanceProbe() {
    final enemy = flyingEnemies.first;
    final transformIndex = world.transform.indexOf(enemy);
    world.transform.posX[transformIndex] = 571.75;
    world.transform.posY[transformIndex] = 420;
    authority.resolveFlyingClearanceSteering(
      world,
      enemy,
      directVelocityX: 180,
      directVelocityY: 0,
      targetBodyX: 800,
      targetBodyY: 200,
      blockerNormalXTicks: -terrainDirectionScale,
      blockerNormalYTicks: 0,
      previewTicks: 6,
      tickHz: 60,
      out: _clearanceOutput,
    );
  }

  void runTick() {
    tick += 1;
    authority.prepareTick(world, player: player, currentTick: tick);
    for (final enemy in groundEnemies) {
      final navIndex = world.navIntent.indexOf(enemy);
      world.navIntent.desiredX[navIndex] = 1400;
      world.navIntent.jumpNow[navIndex] = false;
      world.navIntent.hasPlan[navIndex] = false;
      world.navIntent.commitMoveDirX[navIndex] = 0;
      world.navIntent.hasSafeSurface[navIndex] = false;
      final engagementIndex = world.engagementIntent.indexOf(enemy);
      world.engagementIntent.desiredTargetX[engagementIndex] = 1400;
      world.engagementIntent.speedScale[engagementIndex] = 1;
      world.engagementIntent.arrivalSlowRadiusX[engagementIndex] = 0;
      world.engagementIntent.stateSpeedMul[engagementIndex] = 1;
    }
    groundLocomotion.step(
      world,
      player: player,
      dtSeconds: movement.dtSeconds,
      currentTick: tick,
    );
    flyingLocomotion.step(
      world,
      player: player,
      groundTopY: 900,
      dtSeconds: movement.dtSeconds,
      currentTick: tick,
    );
    _gravity.step(world, movement, physics: const PhysicsTuning());
    authority.step(
      world,
      player: player,
      movement: movement,
      legacyStaticWorld: _legacyWorld,
      fixedPointPilotEnabled: false,
      fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
      currentTick: tick,
    );
  }
}

PlayerArchetype _playerArchetype(MovementTuningDerived movement) =>
    PlayerCatalogDerived.from(
      eloiseCharacter.catalog,
      movement: movement,
      resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
    ).archetype;

TerrainTraversalProfile buildSlopesPhase3PlayerProfile() => _playerArchetype(
  MovementTuningDerived.from(eloiseCharacter.tuning.movement, tickHz: 60),
).terrainTraversalProfile;

final StaticWorldGeometryIndex _legacyWorld = StaticWorldGeometryIndex.from(
  const StaticWorldGeometry(groundPlane: StaticGroundPlane(topY: 2000)),
);

int _roundedDivide(int numerator, int denominator) {
  final negative = (numerator < 0) != (denominator < 0);
  final quotient =
      (numerator.abs() + denominator.abs() ~/ 2) ~/ denominator.abs();
  return negative ? -quotient : quotient;
}

int _integerSqrt(int value) {
  if (value < 2) return value;
  var estimate = 1 << ((value.bitLength + 1) >> 1);
  while (true) {
    final next = (estimate + value ~/ estimate) >> 1;
    if (next >= estimate) return estimate;
    estimate = next;
  }
}
