import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/ecs/systems/ai_target_system.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/enemy_engagement_system.dart';
import 'package:runner_core/ecs/stores/enemies/melee_engagement_store.dart';
import 'package:runner_core/ecs/systems/terrain_enemy_navigation_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/navigation/terrain_surface_navigator.dart';
import 'package:runner_core/navigation/terrain_surface_pathfinder.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';
import 'package:runner_core/npcs/npc_navigation_profiles.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/navigation/bounded_terrain_graph.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';

void main() {
  test(
    'direct melee pursuit stops momentum and resumes when the target leaves',
    () {
      final bundle = _bundle(_floorGeometry(version: 1));
      final fixture = _worldOnGraph(
        bundle,
        enemyBodyX: 200 * 1024,
        playerBodyX: 230 * 1024,
      );
      final world = fixture.world;
      final tuning = GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(),
        tickHz: 60,
      );
      final navigation = _system(() => bundle);
      final engagement = EnemyEngagementSystem(groundEnemyTuning: tuning);
      final locomotion = GroundEnemyLocomotionSystem(groundEnemyTuning: tuning);
      final transform = world.transform.indexOf(fixture.enemy);
      world.transform.velX[transform] = tuning.locomotion.speedX;
      void step(int tick) {
        navigation.step(world, player: fixture.player, currentTick: tick);
        engagement.step(world, player: fixture.player, currentTick: tick);
        locomotion.step(
          world,
          player: fixture.player,
          currentTick: tick,
          dtSeconds: 1 / 60,
        );
      }

      step(1);
      expect(world.transform.velX[transform], 0);
      expect(world.transform.velY[transform], 0);
      _setSupport(
        world,
        entity: fixture.player,
        bundle: bundle,
        graph: bundle.grojibGraph,
        surface: bundle.surfaceSet.surfaces.single,
        desiredBodyXTicks: 500 * 1024,
      );
      step(2);
      expect(world.transform.velX[transform], greaterThan(0));
    },
  );
  test('bounded graph removes jumps whose landing leaves the owning chunk', () {
    final graph = _bundle(_jumpGeometry()).grojibGraph;
    expect(
      graph.edges.any((e) => e.kind == TerrainSurfaceEdgeKind.jump),
      isTrue,
    );
    final bounded = restrictTerrainGraph(
      graph,
      TerrainHorizontalBounds(minXTicks: 0, maxXTicks: 250 * 1024),
    );
    expect(identical(bounded.surfaceSet, graph.surfaceSet), isTrue);
    expect(
      bounded.edges.any((e) => e.kind == TerrainSurfaceEdgeKind.jump),
      isFalse,
    );
    expect(bounded.eligibility.where((e) => e), hasLength(1));
  });
  test(
    'NPC pursuit clamps goals to its chunk with its actual terrain profile',
    () {
      final bundle = TerrainRuntimeBundle.build(
        geometry: _floorGeometry(version: 1),
        groundEnemyProfiles: [
          ...buildDefaultGroundEnemyTerrainGraphProfiles(),
          ...buildNpcNavigationProfiles(
            tickHz: 60,
            physics: const PhysicsTuning(),
          ),
        ],
      );
      final fixture = _worldOnGraph(
        bundle,
        enemyBodyX: 550 * 1024,
        playerBodyX: 50 * 1024,
      );
      final world = fixture.world;
      final npc = EntityFactory(world).createNpc(
        npcId: NpcId.warrior,
        posX: 150,
        posY: 50,
        chunkStartX: 100,
        chunkEndX: 300,
      );
      final contact = const NpcCatalog().terrainContactProfile(NpcId.warrior);
      world.worldContactCapsule.add(npc, contact.capsule);
      world.terrainTraversalProfile.add(npc, contact.traversal);
      world.terrainContact.add(npc);
      final graph =
          bundle.graphPublication[npcNavigationProfileKey(NpcId.warrior)];
      _setSupport(
        world,
        entity: npc,
        bundle: bundle,
        graph: graph,
        surface: bundle.surfaceSet.surfaces.single,
        desiredBodyXTicks: 150 * 1024,
      );
      world.aiTarget.configure(
        npc,
        targetPolicy: AiTargetPolicy.nearestOpponent,
        candidates: [fixture.enemy],
        playerFallback: false,
      );
      AiTargetSystem().step(world, player: fixture.player);
      final system = _system(() => bundle);
      system.step(world, player: fixture.player, currentTick: 1);
      final nav = world.navIntent.indexOf(npc);
      expect(world.navIntent.hasPlan[nav], isTrue);
      expect(world.navIntent.desiredX[nav], 285);
      expect(graph.buildProfile.radiusTicks, contact.capsule.radiusTicks);
      world.transform.posX[world.transform.indexOf(fixture.enemy)] = 20;
      system.step(world, player: fixture.player, currentTick: 2);
      expect(world.navIntent.desiredX[nav], 115);
    },
  );
  test('ground pursuit derives stationary enemy support without adding dynamic contacts', () {
    final bundle = TerrainRuntimeBundle.build(
      geometry: _floorGeometry(version: 1),
      groundEnemyProfiles: [
        ...buildDefaultGroundEnemyTerrainGraphProfiles(),
        ...buildNpcNavigationProfiles(
          tickHz: 60,
          physics: const PhysicsTuning(),
        ),
      ],
    );
    final fixture = _worldOnGraph(
      bundle,
      enemyBodyX: 100 * 1024,
      playerBodyX: 50 * 1024,
    );
    const catalog = EnemyCatalog();
    final archetype = catalog.get(EnemyId.derf);
    final contact = catalog.terrainContactProfile(EnemyId.derf);
    final placement = TerrainSpawnPlacementResolver.forGeometry(bundle.geometry)
        .resolve(
          TerrainSpawnPlacementRequest(
            profile: TerrainEnemySpawnPlacementProfile.fromCatalog(
              catalog: catalog,
              enemyId: EnemyId.derf,
              facing: Facing.left,
            ),
            desiredBodyCenter: TerrainPoint(400 * 1024, 170 * 1024),
            supportSelection: TerrainSpawnSupportSelection.obstacleTop,
            requestedSupportYTicks: 100 * 1024,
          ),
        );
    expect(placement.accepted, isTrue, reason: placement.diagnostic);
    final body = placement.bodyCenter!;
    final world = fixture.world;
    final attacker = EntityFactory(world).createNpc(
      npcId: NpcId.warrior,
      posX: 100,
      posY: 0,
      chunkStartX: 0,
      chunkEndX: 600,
    );
    final npcProfile = const NpcCatalog().terrainContactProfile(NpcId.warrior);
    world.worldContactCapsule.add(attacker, npcProfile.capsule);
    world.terrainTraversalProfile.add(attacker, npcProfile.traversal);
    world.terrainContact.add(attacker);
    _setSupport(
      world,
      entity: attacker,
      bundle: bundle,
      graph: bundle.graphPublication[npcNavigationProfileKey(NpcId.warrior)],
      surface: bundle.surfaceSet.surfaces.single,
      desiredBodyXTicks: 100 * 1024,
    );
    final target = EntityFactory(world).createEnemy(
      enemyId: EnemyId.derf,
      posX: body.xTicks / 1024,
      posY: body.yTicks / 1024,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: archetype.body,
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
    );
    world.worldContactCapsule.add(target, contact.capsule);
    world.terrainTraversalProfile.add(target, contact.traversal);
    world.aiTarget.configure(
      attacker,
      targetPolicy: AiTargetPolicy.nearestOpponent,
      candidates: [target],
      playerFallback: false,
    );
    AiTargetSystem().step(world, player: fixture.player);
    _system(() => bundle).step(world, player: fixture.player, currentTick: 1);
    final nav = world.navIntent.indexOf(attacker);
    expect(world.navIntent.hasPlan[nav], isTrue);
    expect(world.navIntent.desiredX[nav], 400);
    expect(world.terrainContact.has(target), isFalse);
    expect(
      world.transform.posY[world.transform.indexOf(target)],
      body.yTicks / 1024,
    );
  });

  test('different selected actors keep independent paths and release cleanly', () {
    final bundle = _bundle(_floorGeometry(version: 1));
    final a = _worldOnGraph(
      bundle,
      enemyBodyX: 300 * terrainPhysicsTicksPerWorldUnit,
      playerBodyX: 50 * terrainPhysicsTicksPerWorldUnit,
    );
    final b = _worldOnGraph(
      bundle,
      ecsWorld: a.world,
      enemyBodyX: 300 * terrainPhysicsTicksPerWorldUnit,
      playerBodyX: 550 * terrainPhysicsTicksPerWorldUnit,
    );
    final world = a.world;
    final player = world.createEntity();
    world.transform.add(player, posX: 400, posY: 0, velX: 0, velY: 0);
    for (final fixture in [a, b]) {
      world.aiTarget.configure(
        fixture.enemy,
        targetPolicy: AiTargetPolicy.nearestOpponent,
        candidates: [fixture.player],
        playerFallback: false,
      );
    }
    AiTargetSystem().step(world, player: player);
    final system = _system(() => bundle);
    system.step(world, player: player, currentTick: 1);
    expect(world.navIntent.navTargetX[world.navIntent.indexOf(a.enemy)], 50);
    expect(world.navIntent.navTargetX[world.navIntent.indexOf(b.enemy)], 550);
    world.aiTarget.removeEntity(a.enemy);
    // Ordinary pursuit of b.player must replace the previous encounter target.
    system.step(world, player: b.player, currentTick: 2);
    expect(world.navIntent.navTargetX[world.navIntent.indexOf(a.enemy)], 550);
    expect(
      world.surfaceNav.targetEntity[world.surfaceNav.indexOf(a.enemy)],
      b.player,
    );
    world.aiTarget.configure(
      b.enemy,
      targetPolicy: AiTargetPolicy.nearestOpponent,
      candidates: [],
      playerFallback: false,
    );
    system.step(world, player: b.player, currentTick: 3);
    expect(world.navIntent.hasPlan[world.navIntent.indexOf(b.enemy)], isFalse);
    expect(
      world.navIntent.canWalkDirectlyToTarget[world.navIntent.indexOf(b.enemy)],
      isFalse,
    );
    expect(
      world.surfaceNav.targetEntity[world.surfaceNav.indexOf(b.enemy)],
      isNull,
    );
  });
  group('terrain enemy navigation system', () {
    test(
      'routes same-chain pursuit and invalidates state by bundle version',
      () {
        var bundle = _bundle(_floorGeometry(version: 1));
        final fixture = _worldOnGraph(
          bundle,
          enemyBodyX: 100 * terrainPhysicsTicksPerWorldUnit,
          playerBodyX: 400 * terrainPhysicsTicksPerWorldUnit,
        );
        final system = _system(() => bundle);

        system.step(fixture.world, player: fixture.player, currentTick: 1);

        final intentIndex = fixture.world.navIntent.indexOf(fixture.enemy);
        final navIndex = fixture.world.surfaceNav.indexOf(fixture.enemy);
        expect(fixture.world.navIntent.hasPlan[intentIndex], isTrue);
        expect(
          fixture.world.navIntent.canWalkDirectlyToTarget[intentIndex],
          isTrue,
        );
        expect(
          fixture.world.navIntent.desiredX[intentIndex],
          closeTo(400, 1e-9),
        );
        expect(
          fixture.world.surfaceNav.terrainState[navIndex].bundleVersion,
          1,
        );
        expect(system.lastNavigatedEnemyCount, 1);

        final staleState = fixture.world.surfaceNav.terrainState[navIndex]
          ..activeEdgeIndex = 0
          ..pathCursor = 1
          ..pathEdges.add(0);
        bundle = _bundle(_floorGeometry(version: 2));
        _setSupport(
          fixture.world,
          entity: fixture.player,
          bundle: bundle,
          graph: bundle.grojibGraph,
          surface: bundle.surfaceSet.surfaces.single,
          desiredBodyXTicks: 400 * terrainPhysicsTicksPerWorldUnit,
        );
        _setSupport(
          fixture.world,
          entity: fixture.enemy,
          bundle: bundle,
          graph: bundle.grojibGraph,
          surface: bundle.surfaceSet.surfaces.single,
          desiredBodyXTicks: 100 * terrainPhysicsTicksPerWorldUnit,
        );

        system.step(fixture.world, player: fixture.player, currentTick: 2);

        expect(staleState.bundleVersion, 2);
        expect(staleState.activeEdgeIndex, -1);
        expect(staleState.pathEdges, isEmpty);
      },
    );

    test('publishes jump timing for terrain-backed locomotion', () {
      var bundle = _bundle(_jumpGeometry());
      final graph = bundle.grojibGraph;
      final jumpEdgeIndex = graph.edges.indexWhere(
        (edge) => edge.kind == TerrainSurfaceEdgeKind.jump,
      );
      expect(jumpEdgeIndex, isNonNegative);
      final sourceIndex = _sourceIndexForEdge(graph, jumpEdgeIndex);
      final edge = graph.edges[jumpEdgeIndex];
      final fixture = _worldOnGraph(
        bundle,
        enemySurface: graph.surfaces[sourceIndex],
        playerSurface: graph.surfaces[edge.to],
        enemyBodyX: edge.takeoffPoint.xTicks,
        playerBodyX: edge.landingPoint.xTicks,
      );
      final system = _system(() => bundle);

      system.step(fixture.world, player: fixture.player, currentTick: 1);

      final intentIndex = fixture.world.navIntent.indexOf(fixture.enemy);
      expect(fixture.world.navIntent.jumpNow[intentIndex], isTrue);
      expect(fixture.world.navIntent.hasPlan[intentIndex], isTrue);
      expect(
        fixture.world.navIntent.canWalkDirectlyToTarget[intentIndex],
        isFalse,
      );
      expect(
        fixture.world.navIntent.hasActiveJumpTraversal[intentIndex],
        isTrue,
      );
      expect(
        fixture.world.navIntent.activeJumpTravelTicks[intentIndex],
        edge.travelTicks,
      );

      final movement = MovementTuningDerived.from(
        eloiseCharacter.tuning.movement,
        tickHz: 60,
      );
      final locomotion = GroundEnemyLocomotionSystem(
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          const GroundEnemyTuning(),
          tickHz: 60,
        ),
      );
      fixture.world.meleeEngagement.state[fixture.world.meleeEngagement.indexOf(
            fixture.enemy,
          )] =
          MeleeEngagementState.strike;
      locomotion.step(
        fixture.world,
        player: fixture.player,
        dtSeconds: movement.dtSeconds,
        currentTick: 1,
      );

      final transformIndex = fixture.world.transform.indexOf(fixture.enemy);
      expect(fixture.world.transform.velY[transformIndex], lessThan(0));
      expect(
        fixture.world.transform.velX[transformIndex] * edge.commitDirectionX,
        greaterThan(0),
      );
      expect(
        fixture.world.terrainContact.grounded[fixture.world.terrainContact
            .indexOf(fixture.enemy)],
        isFalse,
      );

      final launchedVelocity = fixture.world.transform.velX[transformIndex];
      bundle = bundle.withGeometryVersion(bundle.version + 1);
      system.step(fixture.world, player: fixture.player, currentTick: 2);
      expect(fixture.world.navIntent.hasPlan[intentIndex], isFalse);
      expect(
        fixture.world.navIntent.hasActiveJumpTraversal[intentIndex],
        isTrue,
      );
      expect(
        fixture
            .world
            .surfaceNav
            .terrainState[fixture.world.surfaceNav.indexOf(fixture.enemy)]
            .activeEdgeIndex,
        -1,
      );
      locomotion.step(
        fixture.world,
        player: fixture.player,
        dtSeconds: movement.dtSeconds,
        currentTick: 2,
      );
      expect(fixture.world.transform.velX[transformIndex], launchedVelocity);

      _setSupport(
        fixture.world,
        entity: fixture.enemy,
        bundle: bundle,
        graph: bundle.grojibGraph,
        surface: bundle.surfaceSet.surfaceById(graph.surfaces[edge.to].id)!,
        desiredBodyXTicks: edge.landingPoint.xTicks,
      );
      system.step(fixture.world, player: fixture.player, currentTick: 3);
      expect(
        fixture.world.navIntent.hasActiveJumpTraversal[intentIndex],
        isFalse,
      );
    });
  });
}

TerrainEnemyNavigationSystem _system(TerrainRuntimeBundle Function() bundle) =>
    TerrainEnemyNavigationSystem(
      runtimeBundle: bundle,
      navigator: TerrainSurfaceNavigator(
        pathfinder: TerrainSurfacePathfinder(maxExpandedNodes: 128),
      ),
      physics: const PhysicsTuning(),
      dtSeconds: 1 / 60,
    );

({EcsWorld world, int player, int enemy}) _worldOnGraph(
  TerrainRuntimeBundle bundle, {
  EcsWorld? ecsWorld,
  TerrainNavigationSurface? enemySurface,
  TerrainNavigationSurface? playerSurface,
  required int enemyBodyX,
  required int playerBodyX,
}) {
  final world = ecsWorld ?? EcsWorld(seed: 7);
  const catalog = EnemyCatalog();
  final contact = catalog.terrainContactProfile(EnemyId.grojib);
  final archetype = catalog.get(EnemyId.grojib);
  final player = world.createEntity();
  world.transform.add(player, posX: 0, posY: 0, velX: 0, velY: 0);
  world.body.add(player, archetype.body);
  world.worldContactCapsule.add(player, contact.capsule);
  world.terrainTraversalProfile.add(player, contact.traversal);
  world.terrainContact.add(player);

  final enemy = EntityFactory(world).createEnemy(
    enemyId: EnemyId.grojib,
    posX: 0,
    posY: 0,
    velX: 0,
    velY: 0,
    facing: Facing.right,
    artFacing: archetype.artFacingDir,
    body: archetype.body,
    collider: archetype.collider,
    health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond100: 0),
    mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
    stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  );
  world.worldContactCapsule.add(enemy, contact.capsule);
  world.terrainTraversalProfile.add(enemy, contact.traversal);
  world.terrainContact.add(enemy);

  _setSupport(
    world,
    entity: player,
    bundle: bundle,
    graph: bundle.grojibGraph,
    surface: playerSurface ?? bundle.surfaceSet.surfaces.single,
    desiredBodyXTicks: playerBodyX,
  );
  _setSupport(
    world,
    entity: enemy,
    bundle: bundle,
    graph: bundle.grojibGraph,
    surface: enemySurface ?? bundle.surfaceSet.surfaces.single,
    desiredBodyXTicks: enemyBodyX,
  );
  return (world: world, player: player, enemy: enemy);
}

void _setSupport(
  EcsWorld world, {
  required int entity,
  required TerrainRuntimeBundle bundle,
  required TerrainSurfaceGraph graph,
  required TerrainNavigationSurface surface,
  required int desiredBodyXTicks,
}) {
  final profile = graph.buildProfile;
  final capsule = profile.capsuleForDirection(1);
  final capsuleX = desiredBodyXTicks + capsule.resolvedOffsetXTicks;
  final supportY = surface.yAtXTicks(
    capsuleX.clamp(surface.xMinTicks, surface.xMaxTicks),
  );
  final query = TerrainPlacementQuery(
    geometry: bundle.geometry,
    terrainIndex: bundle.edgeIndex,
    surfaceIndex: bundle.surfaceIndex,
  );
  final placement = query.resolveGrounded(
    TerrainGroundPlacementRequest(
      desiredBodyCenterXTicks: desiredBodyXTicks,
      minimumSupportYTicks: supportY,
      maximumSupportYTicks: supportY,
      capsule: capsule,
      traversalProfile: profile.traversalProfile,
      supportRequirement: profile.supportRequirement,
      intendedSupportEdgeId: surface.id,
      allowSameSupportClamp: true,
      expectedGeometryVersion: bundle.version,
    ),
  );
  expect(placement.isValid, isTrue, reason: placement.validity.name);
  final body = placement.bodyCenter!;
  final transformIndex = world.transform.indexOf(entity);
  world.transform.posX[transformIndex] =
      body.xTicks / terrainPhysicsTicksPerWorldUnit;
  world.transform.posY[transformIndex] =
      body.yTicks / terrainPhysicsTicksPerWorldUnit;
  world.terrainContact.setSupport(
    entity,
    edge: bundle.geometry.edgeById[surface.id]!,
    pointXTicks: placement.supportPoint!.xTicks,
    pointYTicks: placement.supportPoint!.yTicks,
    geometryVersion: bundle.version,
    currentTick: 0,
  );
}

int _sourceIndexForEdge(TerrainSurfaceGraph graph, int edgeIndex) {
  for (var source = 0; source < graph.surfaces.length; source++) {
    if (edgeIndex >= graph.edgeOffsets[source] &&
        edgeIndex < graph.edgeOffsets[source + 1]) {
      return source;
    }
  }
  throw StateError('Jump edge has no CSR source row.');
}

TerrainRuntimeBundle _bundle(TerrainGeometry geometry) =>
    TerrainRuntimeBundle.build(
      geometry: geometry,
      groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
    );

TerrainGeometry _floorGeometry({required int version}) =>
    const TerrainCompiler().compile(<TerrainPolygonInput>[
      TerrainPolygonInput.fromWorld(
        sourcePath: 'test/navigation-floor',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'test',
          shapeId: 'floor',
        ),
        vertices: <(double, double)>[
          (0, 100),
          (600, 100),
          (600, 160),
          (0, 160),
        ],
      ),
    ], geometryVersion: version);

TerrainGeometry _jumpGeometry() => const TerrainCompiler().compile(
  <TerrainPolygonInput>[
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/navigation-jump-left',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: 'left',
      ),
      vertices: <(double, double)>[(0, 180), (220, 180), (220, 240), (0, 240)],
    ),
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/navigation-jump-right',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: 'right',
      ),
      vertices: <(double, double)>[
        (300, 180),
        (560, 180),
        (560, 240),
        (300, 240),
      ],
    ),
  ],
  geometryVersion: 1,
);
